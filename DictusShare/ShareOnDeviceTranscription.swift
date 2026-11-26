// DictusShare/ShareOnDeviceTranscription.swift
// A shared voice note transcribed inside the share extension when DictusApp is closed (#1056).
import DictusCore
import Foundation
import os
import UIKit

/// A shared voice note transcribed inside the share extension, when DictusApp did not take
/// it (closed, or suspended).
///
/// Before this, a note nobody took opened Dictus on it, or ended on "Open Dictus, your
/// voice note is waiting": transcription needed the app's engine. Now, when the device can
/// transcribe the note on its own (`VoiceNoteRoute`), the extension does, from the file
/// (no microphone), with Apple's on-device recognizer (`OnDeviceRecognizer`:
/// `SpeechTranscriber`, model checked installed, never a server). Then it does what the
/// app does after a transcription, where an extension can: the custom vocabulary, the
/// History entry (Pro rules unchanged, `TranscriptionHistoryStore.append` decides, writes
/// coordinated across processes since #1067), the keyboard delivery that puts the text in
/// the keyboard, and a result file DictusApp adopts on its next run instead of
/// transcribing again. What stays with the app: the Live Activity, the card, the Smart
/// Mode, which the app runs when it adopts the note.
///
/// Taken from #992's spike (`origin/spike/dictus-in-keyboard-dictation`) with its review
/// applied: no keyboard setting, the language rule of `VoiceNoteRoute`, the 5-minute cap,
/// and a note is reported done only once its result file is written (otherwise the claim
/// is released and the app transcribes it, as before).
@MainActor
enum ShareOnDeviceTranscription {

    struct Decision {
        let route: VoiceNoteRoute
        let recognizer: OnDeviceRecognizer?
    }

    /// How one batch ended.
    enum Outcome: Equatable {
        /// Every note is transcribed.
        case done(count: Int)
        /// Some notes (possibly none) are transcribed; the rest take today's route.
        case fellBack(transcribed: Int, reason: FallbackReason)
    }

    enum FallbackReason: Equatable {
        /// The decoded note is longer than `VoiceNoteRoute.extensionCap` (its container did
        /// not state its length, so the route could not know before decoding).
        case overExtensionCap(seconds: Int)
        /// Anything else: the log names the step.
        case failed
    }

    /// The route for drops the app did not take, decided once for the batch.
    static func route(for drops: [VoiceNoteDrop]) async -> Decision {
        OnDeviceSpeechLog.component = "VoiceNoteShare"
        OnDeviceSpeechLog.instanceID = "extension"
        let recognizer = OnDeviceRecognizerFactory.make()
        // Nil when the recognizer is not available here at all (and, on a Debug
        // simulator, when no host helper answers).
        let supported = await recognizer?.supportedLocaleIdentifiers()
        let system = VoiceNoteSpeechAssetPlan.System(
            majorVersion: AppleEngineAvailability.majorVersion(of: UIDevice.current.systemVersion),
            speechTranscriberAvailable: supported != nil,
            supportedLocales: supported ?? []
        )
        let settings = VoiceNoteSettings.load()
        let keyboard = SupportedLanguage.active
        let longest = drops.compactMap(\.durationSeconds).max().map(TimeInterval.init)
        func decide(modelInstalled: Bool?) -> VoiceNoteRoute {
            VoiceNoteRoute.decide(.init(appTookIt: false, system: system, voiceNoteLanguage: settings.language,
                                        keyboardLanguage: keyboard, modelInstalled: modelInstalled,
                                        longestKnownSeconds: longest))
        }
        var route = decide(modelInstalled: nil)
        var installed: Bool?
        // The only step that asks Apple's asset inventory, and only when it decides.
        if case .openApp(.modelNotInstalled(let code)) = route, let recognizer {
            installed = await recognizer.hasModelInstalled(languageCode: code)
            route = decide(modelInstalled: installed)
        }
        let voiceNoteLanguageLog: String
        switch settings.language {
        case .autoDetect: voiceNoteLanguageLog = "auto"
        case .fixed(let language): voiceNoteLanguageLog = language.rawValue
        }
        let why: String
        switch route {
        case .appTookIt: why = "appTookIt"
        case .shareExtension(let code, let source): why = "lang=\(code) source=\(source.rawValue)"
        case .openApp(let reason): why = "reason=\(reason.logName)"
        }
        log("route", "route=\(route.logName) \(why) engine=\(recognizer?.engineName ?? "none") voiceNoteLanguage=\(voiceNoteLanguageLog) keyboard=\(keyboard.rawValue) ios=\(system.majorVersion) speechTranscriberAvailable=\(system.speechTranscriberAvailable) installed=\(installed.map(String.init) ?? "notAsked") count=\(drops.count) longestKnownSeconds=\(longest.map { String(Int($0)) } ?? "unknown") cap=\(Int(VoiceNoteRoute.extensionCap)) \(memory())")
        return Decision(route: route, recognizer: recognizer)
    }

    /// Transcribe every drop here, in order. Stops at the first one that cannot be done,
    /// so the caller sends that one and the rest down today's route.
    static func run(_ drops: [VoiceNoteDrop], storage: VoiceNoteStorage,
                    recognizer: OnDeviceRecognizer, languageCode: String) async -> Outcome {
        var transcribed = 0
        var outcome = Outcome.done(count: drops.count)
        for drop in drops {
            if let reason = await transcribe(drop, storage: storage, recognizer: recognizer, languageCode: languageCode) {
                outcome = .fellBack(transcribed: transcribed, reason: reason)
                break
            }
            transcribed += 1
        }
        // A DictusApp that started meanwhile adopts the results now (it listens for this),
        // and takes up any note this batch gave back.
        DarwinNotificationCenter.post(DarwinNotificationName.voiceNoteQueued)
        return outcome
    }

    /// Transcribe one drop. Returns nil when it is done, or why it goes back to the app.
    private static func transcribe(_ drop: VoiceNoteDrop, storage: VoiceNoteStorage,
                                   recognizer: OnDeviceRecognizer, languageCode: String) async -> FallbackReason? {
        let started = Date()
        let id = drop.id
        let short = id.uuidString.prefix(8)
        // One owner per note: an app that starts now finds the note taken.
        guard let claims = VoiceNoteClaim.defaultDirectory else {
            log("failed", "id=\(short) step=claim error=noAppGroup")
            return .failed
        }
        let owner = VoiceNoteClaim.claim(id, as: .shareExtension, in: claims)
        log("claim", "id=\(short) owner=\(owner?.rawValue ?? "unwritable")")
        guard owner == .shareExtension else { return .failed }
        // From here, every way out that is not a success gives the note back to the app.
        func giveBack(_ reason: FallbackReason, _ step: String, _ detail: String) -> FallbackReason {
            let released = VoiceNoteClaim.release(id, as: .shareExtension, in: claims)
            log("failed", "id=\(short) step=\(step) \(detail) released=\(released) elapsedMs=\(milliseconds(since: started)) \(memory())")
            return reason
        }

        // The heartbeat the app reads to tell a working extension from a killed one, and
        // the memory peak over the note.
        let peak = MemoryPeak()
        let heartbeat = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated {
                VoiceNoteClaim.touch(id, in: claims)
                peak.sample()
            }
        }
        defer { heartbeat.invalidate() }

        let audio = VoiceNoteInbox.audioURL(of: drop, storage: storage)
        let samples: [Float]
        do {
            // Capped at 5 minutes here: a note whose container stated no length is caught
            // by the decoder, before the whole of it sits in memory.
            samples = try await Task.detached(priority: .userInitiated) {
                try await SharedAudioDecoder.decode(url: audio, maximumDuration: VoiceNoteRoute.extensionCap)
            }.value
        } catch VoiceNoteDecodeError.tooLong(let seconds) {
            log("capHit", "id=\(short) where=decode seconds=\(seconds) cap=\(Int(VoiceNoteRoute.extensionCap))")
            return giveBack(.overExtensionCap(seconds: seconds), "decode", "error=overExtensionCap")
        } catch {
            return giveBack(.failed, "decode", "error=\(error.localizedDescription)")
        }
        let duration = Double(samples.count) / SharedAudioDecoder.sampleRate
        let decodedAt = Date()
        peak.sample()
        log("decoded", "id=\(short) seconds=\(Int(duration)) ms=\(milliseconds(since: started)) \(memory())")

        let recording = OnDeviceRecording(samples: samples)
        let engineText: String
        do {
            engineText = try await recognizer.transcribe(recording, languageCode: languageCode,
                                                         contextualStrings: vocabularyTerms())
        } catch {
            return giveBack(.failed, "transcribe", "error=\(error.localizedDescription)")
        }
        peak.sample()
        // The custom vocabulary, as the app's transcription applies it (#80).
        let transcript = CustomVocabulary.corrected(engineText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { return giveBack(.failed, "transcribe", "error=empty") }
        // An app that took over a claim it read as abandoned transcribes the note itself:
        // nothing from here may land twice.
        guard VoiceNoteClaim.current(id, in: claims) == .shareExtension else {
            log("failed", "id=\(short) step=ownership error=takenOverByApp")
            return .failed
        }

        let durationSeconds = Int(duration.rounded())
        let record = TranscriptionRecord(id: id, text: transcript, language: languageCode,
                                         durationSeconds: durationSeconds, createdAt: drop.receivedAt,
                                         sttProvider: SpeechEngine.apple.rawValue, source: .sharedFile)
        // Pro rules unchanged: `append` refuses without the History entitlement.
        let saved = TranscriptionHistoryStore.shared.append(record) != nil
        do {
            try VoiceNoteExtensionResult(id: id, transcript: transcript, language: languageCode,
                                         durationSeconds: durationSeconds, savedToHistory: saved,
                                         engine: recognizer.engineName).write(to: storage)
        } catch {
            // #992 review: no result, no success. The History entry stays; the app's
            // transcription replaces its text instead of adding a second one.
            return giveBack(.failed, "resultWrite", "error=\(error.localizedDescription) savedToHistory=\(saved)")
        }
        // The keyboard shows the text, exactly as after an app transcription.
        if let deliveries = VoiceNoteKeyboardDeliveryStore.appGroup {
            do {
                try deliveries.publish(VoiceNoteKeyboardDelivery(
                    id: id, transcript: transcript, sharedAt: drop.receivedAt, transcribedAt: Date(),
                    language: languageCode, durationSeconds: durationSeconds
                ))
                DarwinNotificationCenter.post(DarwinNotificationName.voiceNoteResultReady)
            } catch {
                // The note is in the result file, and History when entitled: readable in the app.
                log("publishFailed", "id=\(short) error=\(error.localizedDescription)")
            }
        }
        log(
            "finished",
            "id=\(short) seconds=\(Int(duration)) chars=\(transcript.count) lang=\(languageCode) engine=\(recognizer.engineName) savedToHistory=\(saved) decodeMs=\(Int(decodedAt.timeIntervalSince(started) * 1000)) transcribeMs=\(milliseconds(since: decodedAt)) totalMs=\(milliseconds(since: started)) \(peak.summary())"
        )
        return nil
    }

    // MARK: - Inputs

    private static func vocabularyTerms() -> [String] {
        guard VocabularyAvailability.isEntitled else { return [] }
        return VocabularyStore.loadEntries().filter(\.isEnabled).map(\.term)
    }

    private static func milliseconds(since date: Date) -> Int {
        Int(Date().timeIntervalSince(date) * 1000)
    }

    // MARK: - Log

    static func memory() -> String {
        "footprintKB=\(MemoryFootprint.residentKB()) liveKB=\(MemoryFootprint.liveHeapKB()) availableKB=\(os_proc_available_memory() / 1024)"
    }

    static func log(_ action: String, _ details: String) {
        PersistentLog.log(.diagnosticProbe(component: "VoiceNoteShare", instanceID: "extension", action: action, details: details))
    }
}

/// Peak footprint and lowest headroom over one note, sampled every second.
@MainActor
private final class MemoryPeak {
    private var peakKB = 0
    private var minimumAvailableKB = Int.max
    private var samples = 0

    func sample() {
        peakKB = max(peakKB, MemoryFootprint.residentKB())
        minimumAvailableKB = min(minimumAvailableKB, Int(os_proc_available_memory() / 1024))
        samples += 1
    }

    func summary() -> String {
        "peakFootprintKB=\(peakKB) minAvailableKB=\(minimumAvailableKB == Int.max ? -1 : minimumAvailableKB) samples=\(samples)"
    }
}
