// DictusCore/Tests/DictusCoreTests/ModelWarmthTests.swift
import XCTest
@testable import DictusCore

/// The signal the readiness gate was missing: whether a model has ever produced an inference
/// in THIS installation of Dictus (#542).
///
/// The whole value of this type is that it says "no" in the two situations the App Group
/// cannot see — a reinstall, which keeps App Group storage and throws away the Core ML cache,
/// and an OS update, which throws the cache away without touching the bundle container. Those
/// are the two cases these tests are mostly about.
final class ModelWarmthTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "ModelWarmthTests"

    private let turbo = "openai_whisper-large-v3-v20240930_turbo_632MB"
    private let parakeet = "parakeet-tdt-0.6b-v3-coreml"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Install identity

    /// The shape on a physical device. The component before `Dictus.app` is the container
    /// UUID, and iOS mints a fresh one at every install.
    func testIdentityOnDeviceIsTheContainerUUIDAndTheOSVersion() {
        let components = [
            "/", "private", "var", "containers", "Bundle", "Application",
            "1E5F0B24-0000-4000-8000-000000000001", "Dictus.app"
        ]
        XCTAssertEqual(
            ModelWarmth.installIdentity(bundlePathComponents: components, systemVersion: "26.6.1"),
            "1E5F0B24-0000-4000-8000-000000000001|26.6.1"
        )
    }

    /// THE POINT OF THE WHOLE FILE: the keyboard extension lives inside the app bundle, so it
    /// reads the same identity with no hand-off, no Darwin notification and no second key.
    func testTheKeyboardExtensionReadsTheSameIdentityAsTheApp() {
        let base = [
            "/", "private", "var", "containers", "Bundle", "Application",
            "1E5F0B24-0000-4000-8000-000000000001"
        ]
        let app = ModelWarmth.installIdentity(
            bundlePathComponents: base + ["Dictus.app"], systemVersion: "26.6.1"
        )
        let keyboard = ModelWarmth.installIdentity(
            bundlePathComponents: base + ["Dictus.app", "PlugIns", "DictusKeyboard.appex"],
            systemVersion: "26.6.1"
        )
        XCTAssertEqual(app, keyboard)
        XCTAssertNotNil(app)
    }

    /// The simulator's path carries a second UUID, for the device, further up. Taking the
    /// FIRST `.app` and the component before it is what keeps that one out of the identity.
    func testTheSimulatorPathResolvesToTheBundleUUIDNotTheDeviceUUID() {
        let components = [
            "/", "Users", "someone", "Library", "Developer", "CoreSimulator", "Devices",
            "AAAAAAAA-0000-4000-8000-00000000000A", "data", "Containers", "Bundle",
            "Application", "BBBBBBBB-0000-4000-8000-00000000000B", "Dictus.app"
        ]
        XCTAssertEqual(
            ModelWarmth.installIdentity(bundlePathComponents: components, systemVersion: "26.0"),
            "BBBBBBBB-0000-4000-8000-00000000000B|26.0"
        )
    }

    func testAPathWithNoAppComponentHasNoIdentity() {
        XCTAssertNil(
            ModelWarmth.installIdentity(bundlePathComponents: ["/", "tmp"], systemVersion: "26.6.1")
        )
        XCTAssertNil(
            ModelWarmth.installIdentity(bundlePathComponents: [], systemVersion: "26.6.1")
        )
    }

    /// A `.app` with nothing above it names no container, so it names no install.
    func testAnAppAtTheRootHasNoIdentity() {
        XCTAssertNil(
            ModelWarmth.installIdentity(bundlePathComponents: ["Dictus.app"], systemVersion: "26.6.1")
        )
    }

    // MARK: - The record

    func testAModelIsColdUntilSomethingRecordsItWarm() {
        XCTAssertFalse(ModelWarmth.isWarm(turbo, identity: "install-1", defaults: defaults))
        ModelWarmth.markWarm(turbo, identity: "install-1", defaults: defaults)
        XCTAssertTrue(ModelWarmth.isWarm(turbo, identity: "install-1", defaults: defaults))
    }

    /// A reinstall keeps App Group storage and throws the Core ML cache away. This is the
    /// exact divergence that made `modelReady` and `modelLoadState` lie, and the reason the
    /// record is keyed rather than a plain Bool.
    func testAReinstallMakesAPreviouslyWarmModelColdAgain() {
        ModelWarmth.markWarm(turbo, identity: "install-1", defaults: defaults)
        XCTAssertFalse(ModelWarmth.isWarm(turbo, identity: "install-2", defaults: defaults))
    }

    /// An OS update invalidates the compiled artefacts without touching the bundle container,
    /// which is why the version is part of the key and not merely logged alongside it.
    func testAnOSUpdateAloneMakesAModelColdAgain() {
        let before = ModelWarmth.installIdentity(
            bundlePathComponents: ["/", "Bundle", "Application", "UUID", "Dictus.app"],
            systemVersion: "26.6.1"
        )
        let after = ModelWarmth.installIdentity(
            bundlePathComponents: ["/", "Bundle", "Application", "UUID", "Dictus.app"],
            systemVersion: "26.7"
        )
        ModelWarmth.markWarm(turbo, identity: before, defaults: defaults)
        XCTAssertTrue(ModelWarmth.isWarm(turbo, identity: before, defaults: defaults))
        XCTAssertFalse(ModelWarmth.isWarm(turbo, identity: after, defaults: defaults))
    }

    func testWarmthIsPerModel() {
        ModelWarmth.markWarm(turbo, identity: "install-1", defaults: defaults)
        XCTAssertFalse(ModelWarmth.isWarm(parakeet, identity: "install-1", defaults: defaults))
    }

    /// Decision 9: a fresh download starts from a fresh cache, so the record has to go with
    /// the files. And it takes only its own model with it.
    func testClearingOneModelLeavesTheOthersWarm() {
        ModelWarmth.markWarm(turbo, identity: "install-1", defaults: defaults)
        ModelWarmth.markWarm(parakeet, identity: "install-1", defaults: defaults)
        ModelWarmth.clear(turbo, defaults: defaults)
        XCTAssertFalse(ModelWarmth.isWarm(turbo, identity: "install-1", defaults: defaults))
        XCTAssertTrue(ModelWarmth.isWarm(parakeet, identity: "install-1", defaults: defaults))
    }

    func testMarkingWarmTwiceIsIdempotent() {
        ModelWarmth.markWarm(turbo, identity: "install-1", defaults: defaults)
        ModelWarmth.markWarm(turbo, identity: "install-1", defaults: defaults)
        XCTAssertEqual(ModelWarmth.record(in: defaults), [turbo: "install-1"])
    }

    /// A claim can only be made for an install that can be named, so nothing is written.
    /// Paired with the read below, which is the half that matters.
    func testAnUnknownIdentityWritesNothing() {
        ModelWarmth.markWarm(turbo, identity: nil, defaults: defaults)
        XCTAssertTrue(ModelWarmth.record(in: defaults).isEmpty)
    }

    /// NIL MEANS "COULD NOT ASK", NOT "NO". Answering `false` would put a preparation screen
    /// in front of every dictation forever, and the screen's own instruction — return and tap
    /// again — leads straight back to it. Degrading to the pre-#542 behaviour is bounded; a
    /// loop the user cannot leave is not.
    func testAnUnknownIdentityReadsAsWarmRatherThanLockingTheUserOut() {
        XCTAssertTrue(ModelWarmth.isWarm(turbo, identity: nil, defaults: defaults))
    }

    // MARK: - The live reader both call sites use

    func testTheActiveModelIsTheOneAskedAbout() {
        let components = ["/", "Bundle", "Application", "UUID", "Dictus.app"]
        defaults.set(turbo, forKey: SharedKeys.activeModel)

        XCTAssertFalse(ModelWarmth.isActiveModelWarm(
            defaults: defaults, bundlePathComponents: components, systemVersion: "26.6.1"
        ))

        // Warming a DIFFERENT model must not answer for the active one.
        ModelWarmth.markWarm(
            parakeet,
            identity: ModelWarmth.installIdentity(
                bundlePathComponents: components, systemVersion: "26.6.1"
            ),
            defaults: defaults
        )
        XCTAssertFalse(ModelWarmth.isActiveModelWarm(
            defaults: defaults, bundlePathComponents: components, systemVersion: "26.6.1"
        ))

        ModelWarmth.markWarm(
            turbo,
            identity: ModelWarmth.installIdentity(
                bundlePathComponents: components, systemVersion: "26.6.1"
            ),
            defaults: defaults
        )
        XCTAssertTrue(ModelWarmth.isActiveModelWarm(
            defaults: defaults, bundlePathComponents: components, systemVersion: "26.6.1"
        ))
    }

    /// No active model is the "no model downloaded" case, which `RecordTapRouting` asks about
    /// one question earlier and hands to the coordinator to word for itself. It must not be
    /// turned into a preparation screen for a model that does not exist.
    func testNoActiveModelIsNotReportedAsCold() {
        XCTAssertTrue(ModelWarmth.isActiveModelWarm(
            defaults: defaults,
            bundlePathComponents: ["/", "Bundle", "Application", "UUID", "Dictus.app"],
            systemVersion: "26.6.1"
        ))
    }
}
