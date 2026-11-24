// DictusShare/ShareOnDeviceTranscription.swift
import DictusCore
import Foundation
import os
import UIKit

/// A shared voice note transcribed inside the share extension, when DictusApp is not
/// running (#992, voice notes without the app).
///
/// Before this, a note nobody took ended on "Open Dictus, your voice note is waiting":
/// transcription needs the app's engine, and only a running app could take the note.
/// Now, when the app did not take it and the device can transcribe it on its own
/// (`VoiceNoteRoute`), the extension does, from the file — no microphone, no web view —
/// with the keyboard's on-device recognizer (`OnDeviceRecognizer`: Apple's
/// `SpeechTranscriber`, model checked installed, never a server). Then it does what the
/// app does after a transcription, where the extension can: the custom vocabulary, the
/// History entry (Pro rules unchanged, `TranscriptionHistoryStore.append` decides), the
/// keyboard delivery that puts the text in the keyboard, and a result file DictusApp
/// adopts on its next run instead of transcribing again. What stays with the app: the
/// Live Activity, the card's Smart Mode, which the app runs when it adopts the note.
@MainActor
enum ShareOnDeviceTranscription {

    struct Decision {
        let route: VoiceNoteRoute
        let recognizer: OnDeviceRecognizer?
        let languageCode: String
    }

    /// The route for drops the app did not take, decided once for the batch.
    static func route() async -> Decision {
        OnDeviceSpeechLog.component = "VoiceNoteShare"
        OnDeviceSpeechLog.instanceID = "shared"
        let recognizer = OnDeviceRecognizerFactory.make()
        let code = languageCode()
        var installed: Bool?
        // Automatic detection: no single language for Apple's transcriber, so `nil`
        // routes to today's "open Dictus".
        if let recognizer, let code { installed = await recognizer.isReadyOnDevice(languageCode: code) }
        let route = VoiceNoteRoute.decide(
            appTookIt: false,
            settingEnabled: InKeyboardDictationRoute.isSettingEnabled(in: AppGroup.defaults),
            systemMajorVersion: AppleEngineAvailability.majorVersion(of: UIDevice.current.systemVersion),
            localeInstalled: installed
        )
        log("route", "route=\(route.rawValue) engine=\(recognizer?.engineName ?? "none") lang=\(code ?? "auto") installed=\(installed.map(String.init) ?? "unknown") \(memory())")
        // `languageCode` is only read on the on-device route, which needs a language.
        return Decision(route: route, recognizer: recognizer, languageCode: code ?? "")
    }

    /// Transcribe every drop here. Returns false at the first one that cannot be done, so
    /// the caller falls back to today's "open Dictus" for the rest.
    static func run(_ drops: [VoiceNoteDrop], storage: VoiceNoteStorage,
                    recognizer: OnDeviceRecognizer, languageCode: String) async -> Bool {
        for drop in drops {
            guard await transcribe(drop, storage: storage, recognizer: recognizer, languageCode: languageCode) else {
                return false
            }
        }
        // A DictusApp that started meanwhile adopts the results now (it listens for this).
        DarwinNotificationCenter.post(DarwinNotificationName.voiceNoteQueued)
        return true
    }

    private static func transcribe(_ drop: VoiceNoteDrop, storage: VoiceNoteStorage,
                                   recognizer: OnDeviceRecognizer, languageCode: String) async -> Bool {
        let started = Date()
        let id = drop.id
        // One owner per note: the app, if it starts now, finds the note taken.
        if let claims = DictationSessionClaim.defaultDirectory {
            let owner = DictationSessionClaim.claim(id.uuidString, as: .shareExtension, in: claims)
            log("claim", "id=\(id.uuidString.prefix(8)) owner=\(owner?.rawValue ?? "unwritable")")
            if owner == .app { return false }
        }
        let peak = MemoryPeak()
        let sampler = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { peak.sample() }
        }
        defer { sampler.invalidate() }

        let audio = VoiceNoteInbox.audioURL(of: drop, storage: storage)
        let samples: [Float]
        do {
            samples = try await Task.detached(priority: .userInitiated) {
                try await SharedAudioDecoder.decode(url: audio)
            }.value
        } catch {
            log("failed", "id=\(id.uuidString.prefix(8)) step=decode error=\(error.localizedDescription)")
            return false
        }
        let duration = Double(samples.count) / SharedAudioDecoder.sampleRate
        let decodedAt = Date()
        peak.sample()
        log("decoded", "id=\(id.uuidString.prefix(8)) seconds=\(Int(duration)) ms=\(Int(decodedAt.timeIntervalSince(started) * 1000)) \(memory())")

        let recording = OnDeviceRecording(pcm16: pcm16(samples))
        let engineText: String
        do {
            engineText = try await recognizer.transcribe(recording, languageCode: languageCode,
                                                         contextualStrings: vocabularyTerms())
        } catch {
            log("failed", "id=\(id.uuidString.prefix(8)) step=transcribe error=\(error.localizedDescription) \(memory())")
            return false
        }
        peak.sample()
        // The custom vocabulary, as the app's chunk transcription applies it (#80).
        let transcript = DictationTranscript.corrected(engineText).text
        guard !transcript.isEmpty else {
            log("failed", "id=\(id.uuidString.prefix(8)) step=transcribe error=empty")
            return false
        }

        let policy = VoiceNoteSettings.load().languagePolicy(
            activeModel: AppGroup.defaults.string(forKey: SharedKeys.activeModel) ?? "openai_whisper-small",
            keyboardLanguage: SupportedLanguage.active
        )
        let record = TranscriptionRecord(id: id, text: transcript, policy: policy, duration: duration,
                                         createdAt: drop.receivedAt, source: .sharedFile)
        // Pro rules unchanged: `append` refuses without the History entitlement.
        let saved = TranscriptionHistoryStore.shared.append(record) != nil
        do {
            try VoiceNoteExtensionResult(id: id, transcript: transcript, language: record.language,
                                         durationSeconds: Int(duration.rounded()), savedToHistory: saved,
                                         engine: recognizer.engineName).write(to: storage)
        } catch {
            log("resultWriteFailed", "id=\(id.uuidString.prefix(8)) error=\(error.localizedDescription)")
        }
        // The keyboard shows the text, exactly as after an app transcription.
        if let deliveries = VoiceNoteKeyboardDeliveryStore.appGroup {
            do {
                try deliveries.publish(VoiceNoteKeyboardDelivery(
                    id: id, transcript: transcript, sharedAt: drop.receivedAt, transcribedAt: Date(),
                    language: record.language, durationSeconds: Int(duration.rounded())
                ))
                DarwinNotificationCenter.post(DarwinNotificationName.voiceNoteResultReady)
            } catch {
                log("publishFailed", "id=\(id.uuidString.prefix(8)) error=\(error.localizedDescription)")
            }
        }
        log(
            "finished",
            "id=\(id.uuidString.prefix(8)) seconds=\(Int(duration)) chars=\(transcript.count) savedToHistory=\(saved) decodeMs=\(Int(decodedAt.timeIntervalSince(started) * 1000)) transcribeMs=\(Int(Date().timeIntervalSince(decodedAt) * 1000)) totalMs=\(Int(Date().timeIntervalSince(started) * 1000)) \(peak.summary())"
        )
        return true
    }

    // MARK: - Inputs

    /// The voice note's dictation language, the same policy the app's queue uses.
    private static func languageCode() -> String? {
        let policy = VoiceNoteSettings.load().languagePolicy(
            activeModel: AppGroup.defaults.string(forKey: SharedKeys.activeModel) ?? "openai_whisper-small",
            keyboardLanguage: SupportedLanguage.active
        )
        // Automatic detection: nil, as in the keyboard.
        return policy.sttLanguageCode ?? AppleSpeechLanguage.activeDictationLanguageCode()
    }

    private static func vocabularyTerms() -> [String] {
        guard VocabularyAvailability.isEntitled else { return [] }
        return VocabularyStore.loadEntries().filter(\.isEnabled).map(\.term)
    }

    private static func pcm16(_ samples: [Float]) -> Data {
        var data = Data(count: samples.count * 2)
        data.withUnsafeMutableBytes { raw in
            let out = raw.bindMemory(to: Int16.self)
            for index in samples.indices {
                out[index] = Int16(max(-1, min(1, samples[index])) * 32_767).littleEndian
            }
        }
        return data
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
