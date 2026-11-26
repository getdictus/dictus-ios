// DictusCore/Tests/DictusCoreTests/AdaptiveTouchStatusTests.swift
import CoreGraphics
import XCTest
@testable import DictusCore

/// The one-line summary of what Adaptive touch learned (#1081), as the keyboard logs it at each
/// appearance and the Debug export writes it.
final class AdaptiveTouchStatusTests: XCTestCase {
    private static let keys = SpatialDecoderTests.keys(SpatialDecoderTests.qwerty)
    private static let rows = SpatialDecoderTests.qwerty.map(Array.init)

    /// `sessions` sessions of the same ten words, every tap `dy` keycaps below its key centre.
    private func learn(_ touch: AdaptiveTouch, sessions: Int, dy: CGFloat = 0.25) {
        for _ in 0..<sessions {
            touch.beginSession()
            var text = ""
            for word in ["the", "quick", "brown", "fox", "jumps", "over", "lazy", "dogs", "with", "might"] {
                for c in word {
                    text.append(c)
                    let centre = Self.keys.centres[c] ?? .zero
                    touch.typed(String(c), at: CGPoint(x: centre.x, y: centre.y + dy * 54), slid: false, keys: Self.keys)
                }
                touch.finish(before: text)
                text += " "
            }
        }
    }

    // MARK: - Summary

    func testAnEmptyModelSaysNothingWasLearned() {
        let status = AdaptiveTouchStatus(model: AdaptiveTouchModel())
        XCTAssertNil(status.context)
        XCTAssertNil(status.maxShift)
        XCTAssertEqual(status.logFields, "labelled=0 sessions=0 profile=no active=no promotions=0 maxShift=0")
    }

    func testBelowTheGateItHasAProfileButIsNotActive() throws {
        var model = AdaptiveTouchModel()
        let c = model.ensureContext(geometry: 7, regime: 0)
        model.contexts[c].learning = true
        model.contexts[c].sessions = 2
        for _ in 0..<150 { model.add(context: c, slot: 0, x: 0, y: 0.2, weight: 1) }
        model.promote(context: c, groups: [0, 0, 1])

        let status = AdaptiveTouchStatus(model: model)
        XCTAssertEqual(status.context, c)
        XCTAssertEqual(status.labelled, 150)
        XCTAssertEqual(status.sessions, 2)
        XCTAssertTrue(status.profile)
        XCTAssertFalse(status.active, "150 taps over 2 sessions is under the 400 and 3 the gate asks")
        XCTAssertEqual(status.promotions, 1)
        XCTAssertEqual(try XCTUnwrap(status.maxShift).keycaps, AdaptiveTouchModel.step, accuracy: 1e-6,
                       "one promotion moves an offset by a step")
        XCTAssertTrue(status.logFields.hasPrefix("labelled=150 sessions=2 profile=yes active=no promotions=1 maxShift=0.050@slot"))
    }

    func testAnEligibleModelReadsActiveAsTheDecoderDoes() throws {
        let touch = AdaptiveTouch(storage: .memory, defaults: nil)
        learn(touch, sessions: 12)
        XCTAssertNotNil(touch.personalKeys(for: Self.keys), "the decoder reads a profile")
        let geometry = try XCTUnwrap(touch.geometry)

        let status = AdaptiveTouchStatus(model: touch.model, geometry: geometry.key, letters: [geometry.key: geometry.letters])
        XCTAssertTrue(status.active)
        XCTAssertEqual(status.active, touch.isActive)
        XCTAssertTrue(status.profile)
        XCTAssertGreaterThanOrEqual(status.labelled, UInt32(AdaptiveTouchModel.activeTaps))
        XCTAssertGreaterThanOrEqual(status.sessions, UInt16(AdaptiveTouchModel.activeSessions))
        XCTAssertGreaterThan(status.promotions, 0)
        let shift = try XCTUnwrap(status.maxShift)
        XCTAssertGreaterThan(shift.keycaps, 0.05, "every tap landed a quarter key low")
        XCTAssertLessThanOrEqual(shift.keycaps, AdaptiveTouchModel.bound * Float(2).squareRoot())
        XCTAssertEqual(shift.letter, geometry.letters[shift.slot], "the key is named on its own geometry")
        XCTAssertTrue(status.logFields.contains("active=yes"))
        XCTAssertTrue(status.logFields.hasSuffix("@\(geometry.letters[shift.slot])"))
    }

    func testMaxShiftIsTheLongestOffsetWithItsKey() throws {
        var model = AdaptiveTouchModel()
        let c = model.ensureContext(geometry: 9, regime: 0)
        model.contexts[c].learning = true
        model.contexts[c].hasSnapshot = true
        // Slot 2 moves 0.1 right and 0.2 down (0.224 keycaps); slot 5 0.21 left (0.21).
        model.snapshot[(c * AdaptiveTouchModel.slotLimit + 2) * 2] = 0.1
        model.snapshot[(c * AdaptiveTouchModel.slotLimit + 2) * 2 + 1] = 0.2
        model.snapshot[(c * AdaptiveTouchModel.slotLimit + 5) * 2] = -0.21

        let unnamed = try XCTUnwrap(AdaptiveTouchStatus(model: model).maxShift)
        XCTAssertEqual(unnamed.slot, 2)
        XCTAssertEqual(unnamed.keycaps, (0.01 + 0.04 as Float).squareRoot(), accuracy: 1e-6)
        XCTAssertNil(unnamed.letter)
        XCTAssertTrue(AdaptiveTouchStatus(model: model).logFields.hasSuffix("maxShift=0.224@slot2"))

        let named = AdaptiveTouchStatus(model: model, letters: [9: Array("qwertyuiop")])
        XCTAssertEqual(named.maxShift?.letter, "e")
        XCTAssertTrue(named.logFields.hasSuffix("maxShift=0.224@e"))
        XCTAssertNil(AdaptiveTouchStatus(model: model, letters: [8: Array("qwertyuiop")]).maxShift?.letter,
                     "another geometry's letters name nothing")

        model.contexts[c].hasSnapshot = false
        XCTAssertNil(AdaptiveTouchStatus(model: model).maxShift, "no snapshot, no shift")
    }

    func testTheCurrentGeometrysLearningContextIsSummarized() {
        var model = AdaptiveTouchModel()
        let other = model.ensureContext(geometry: 1, regime: 0)
        model.contexts[other].learning = true
        for _ in 0..<10 { model.add(context: other, slot: 0, x: 0, y: 0, weight: 1) }
        let here = model.ensureContext(geometry: 2, regime: 0)
        model.contexts[here].learning = true
        for _ in 0..<3 { model.add(context: here, slot: 0, x: 0, y: 0, weight: 1) }
        let resting = model.ensureContext(geometry: 2, regime: 1)
        for _ in 0..<50 { model.add(context: resting, slot: 0, x: 0, y: 0, weight: 1) }

        XCTAssertEqual(AdaptiveTouchStatus(model: model, geometry: 2).labelled, 3, "the learning regime, not the resting one")
        XCTAssertEqual(AdaptiveTouchStatus(model: model, geometry: 1).labelled, 10)
        XCTAssertEqual(AdaptiveTouchStatus(model: model, geometry: 3).labelled, 3,
                       "an unknown geometry falls back to the most recently used learning context")
    }

    func testAModelLearnedBeforeAResetReadsAsEmpty() {
        let touch = AdaptiveTouch(storage: .memory, defaults: nil)
        learn(touch, sessions: 2)
        XCTAssertGreaterThan(AdaptiveTouchStatus(model: touch.model).labelled, 0)
        XCTAssertEqual(AdaptiveTouchStatus(model: touch.model, resetAt: 10).labelled, 0)
    }

    // MARK: - Stored file

    func testTheStoredFileIsReadAsTheKeyboardLoadsIt() {
        let touch = AdaptiveTouch(storage: .memory, defaults: nil)
        learn(touch, sessions: 2)
        let data = touch.model.serialized()

        XCTAssertEqual(AdaptiveTouchStatus.stored(data: nil, resetAt: 0).0, .none)
        XCTAssertEqual(AdaptiveTouchStatus.stored(data: Data([1, 2, 3]), resetAt: 0).0, .unreadable)
        XCTAssertEqual(AdaptiveTouchStatus.stored(data: data, resetAt: 10).0, .stale)
        let (stored, status) = AdaptiveTouchStatus.stored(data: data, resetAt: 0)
        XCTAssertEqual(stored, .yes)
        XCTAssertEqual(status, AdaptiveTouchStatus(model: touch.model))
    }

    func testTheReportCarriesTheSummaryLineAndEachContext() {
        let touch = AdaptiveTouch(storage: .memory, defaults: nil)
        learn(touch, sessions: 12)
        let report = AdaptiveTouchStatus.report(model: touch.model)
        let lines = report.components(separatedBy: "\n")
        XCTAssertEqual(lines.first, "adaptiveTouchStatus \(AdaptiveTouchStatus(model: touch.model).logFields)")
        XCTAssertTrue(report.contains("inUse=yes"))
        XCTAssertTrue(report.contains("eligible=yes"))
        XCTAssertFalse(report.contains("quick"), "no typed word")
        XCTAssertTrue(AdaptiveTouchStatus.report(model: AdaptiveTouchModel()).contains("nothing learned yet"))
    }

    // MARK: - Naming an exported file's keys

    func testTheGeometryKeyIsRebuiltFromRowsAndPitch() throws {
        let geometry = try XCTUnwrap(AdaptiveTouchGeometry(keys: Self.keys))
        XCTAssertEqual(AdaptiveTouchGeometry.key(rows: Self.rows, width: 160, height: 216), geometry.key)
        let pitch = try XCTUnwrap(AdaptiveTouchGeometry.pitch(of: geometry.key, rows: Self.rows))
        XCTAssertEqual(pitch, CGSize(width: 40, height: 54))
        XCTAssertNil(AdaptiveTouchGeometry.pitch(of: geometry.key, rows: SpatialDecoderTests.azerty.map(Array.init)),
                     "other rows never match")
    }

    func testAShippedLetterPageIsIdentifiedAndNamesTheKeys() throws {
        let touch = AdaptiveTouch(storage: .memory, defaults: nil)
        learn(touch, sessions: 2)
        let geometry = try XCTUnwrap(touch.geometry)
        let match = try XCTUnwrap(AdaptiveTouchGeometry.identify(touch.model)[geometry.key])
        XCTAssertEqual(match.page, "qwerty")
        XCTAssertEqual(match.pitch, CGSize(width: 40, height: 54))
        XCTAssertEqual(match.letters, geometry.letters, "the slots as the keyboard numbered them")
        XCTAssertEqual(AdaptiveTouchGeometry.shippedLetterPages.map(\.name), ["azerty", "qwerty", "qwertz"])
    }

    // MARK: - The keyboard's line

    func testTheRuntimeLineOffReadsTheFileOnReadsMemory() throws {
        let suite = "AdaptiveTouchStatusTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("adaptive-touch.bin")
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
        let settings = KeyboardFeatureSettings(store: defaults, channel: .testBuild)
        settings.spatialAutocorrect = true
        var made = 0
        let runtime = AdaptiveTouchRuntime {
            made += 1
            return AdaptiveTouch(storage: .file(url), defaults: defaults)
        }

        settings.adaptiveTouch = false
        runtime.refresh(settings)
        XCTAssertEqual(runtime.statusEvent(file: url, defaults: defaults).message, "on=false stored=none")
        XCTAssertEqual(made, 0, "off, the line builds no learner")

        settings.adaptiveTouch = true
        runtime.refresh(settings)
        let empty = runtime.statusEvent(file: url, defaults: defaults)
        XCTAssertEqual(empty.message, "on=true labelled=0 sessions=0 profile=no active=no promotions=0 maxShift=0")
        XCTAssertEqual(empty.name, "adaptiveTouchStatus")
        let learner = try XCTUnwrap(runtime.current)
        learn(learner, sessions: 12)
        let on = runtime.statusEvent(file: url, defaults: defaults).message
        XCTAssertTrue(on.hasPrefix("on=true labelled="))
        XCTAssertTrue(on.contains("profile=yes active=yes"))

        // No wait here: the line itself must read the file after the save turning off queued.
        let expected = AdaptiveTouchStatus(model: learner.model).logFields
        settings.adaptiveTouch = false
        runtime.refresh(settings)
        let off = runtime.statusEvent(file: url, defaults: defaults).message
        XCTAssertTrue(off.hasPrefix("on=false stored=yes labelled="), off)
        XCTAssertEqual(off, "on=false stored=yes \(expected)", "the file as the learner just wrote it")
        XCTAssertEqual(made, 1)

        AdaptiveTouchStore.requestReset(defaults: defaults, url: nil)
        XCTAssertEqual(runtime.statusEvent(file: url, defaults: defaults).message, "on=false stored=stale")
    }
}
