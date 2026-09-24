// DictusCore/Sources/DictusCore/ModelWarmth.swift
// Whether a model can transcribe *now*, as opposed to merely being on disk (#542).
//
// WHY THIS EXISTS: `SharedKeys.modelReady` and `SharedKeys.modelLoadState` both answer
// questions about the model FILE. Neither can see the Core ML cache, and the Core ML
// cache is what decides whether the next transcription takes one second or four minutes.
// On 2026-09-11 a keyboard dictation read `ready` from the App Group, recorded, went to
// `transcribing`, and was cancelled 30s later with nothing inserted and no history entry:
// the compile had not started when the keyboard looked, because it starts when the app
// launches, which is the same instant the keyboard is handing off.
//
// So the gate needed a signal that survives process death, crosses into the keyboard
// extension, and is false exactly when the Core ML cache is cold.
//
// WHY NOT PROBE THE CACHE DIRECTLY: it means depending on the location and the format of
// an undocumented system cache, and being wrong about it is silent.
//
// WHY NOT `ModelInfo.firstPreparationSeconds`: it is a copy field with deliberate holes —
// Parakeet is nil though it has been measured, Turbo 954MB is nil though it is the
// largest model in the catalogue — so a threshold over it would pass the worst case and
// block the default one. It is a number for a sentence on a screen, not a gate signal.
import Foundation

/// Remembers, across processes and across app launches, which models have actually run an
/// inference in *this* installation of Dictus.
///
/// The record is written when a warm inference completes (`DictationCoordinator`'s
/// `runWarmInference`), which is the first moment anything in this install has proof that
/// the model can produce a result rather than merely be loaded. Everything before that
/// point — the file existing, the weights being resident, `modelLoadState` saying `ready`
/// — is compatible with a multi-minute compile still to come.
public enum ModelWarmth {

    // MARK: - Install identity

    /// What a warmth claim is valid for: this bundle container, on this iOS version.
    ///
    /// WHY THE BUNDLE CONTAINER: iOS gives the app bundle a fresh UUID at every install,
    /// including a reinstall of the same build, and discards the Core ML cache with it.
    /// App Group storage, by contrast, survives a reinstall — which is precisely why the
    /// old signals lied. The keyboard extension lives inside the app bundle, so it reads
    /// the same identity with no coordination, no Darwin notification and no extra key.
    ///
    /// WHY THE iOS VERSION TOO: an OS update also invalidates compiled Core ML artefacts,
    /// and it does it without touching the bundle container.
    ///
    /// - Parameters:
    ///   - bundlePathComponents: `Bundle.main.bundleURL.pathComponents`. From the app that
    ///     ends in `Dictus.app`; from the keyboard, in `DictusKeyboard.appex` two levels
    ///     deeper. Both share the container directory this reads.
    ///   - systemVersion: `UIDevice.current.systemVersion`, passed in so this stays a pure
    ///     function and DictusCore stays free of UIKit.
    /// - Returns: nil when the path has no `.app` component at all, which cannot happen in
    ///   either shipping target. See `isWarm` for what nil is made to mean.
    public static func installIdentity(
        bundlePathComponents: [String],
        systemVersion: String
    ) -> String? {
        // The FIRST `.app`, not the last: the keyboard's path is
        // `…/<uuid>/Dictus.app/PlugIns/DictusKeyboard.appex`, and only the outer one has
        // the container directory as its parent.
        guard let appIndex = bundlePathComponents.firstIndex(where: { $0.hasSuffix(".app") }),
              appIndex > 0 else {
            return nil
        }
        return "\(bundlePathComponents[appIndex - 1])|\(systemVersion)"
    }

    // MARK: - Reading

    /// Whether `model` has completed a warm inference in this install.
    ///
    /// - Parameter identity: the value from `installIdentity`. **Nil answers `true`**, and
    ///   that direction is deliberate: nil means the question could not be asked, not that
    ///   the answer is no. A false "cold" would put a preparation screen in front of every
    ///   dictation forever, and the screen's own instruction — return and tap again — would
    ///   lead straight back to it. Degrading to the behaviour that shipped before this file
    ///   is a bounded cost; a loop the user cannot leave is not.
    public static func isWarm(
        _ model: String,
        identity: String?,
        defaults: UserDefaults = AppGroup.defaults
    ) -> Bool {
        guard let identity else { return true }
        return record(in: defaults)[model] == identity
    }

    /// Whether the model a dictation would actually use is warm, read from live state.
    ///
    /// The one entry point both callers of `RecordTapRouting` use, so the keyboard and the
    /// in-app button cannot disagree about which model they are asking about.
    public static func isActiveModelWarm(
        defaults: UserDefaults = AppGroup.defaults,
        bundlePathComponents: [String] = Bundle.main.bundleURL.pathComponents,
        systemVersion: String
    ) -> Bool {
        guard let model = defaults.string(forKey: SharedKeys.activeModel) else {
            // No active model is not a cold model. It is the "no model downloaded" case,
            // which `RecordTapRouting` hands to the coordinator to word for itself.
            return true
        }
        return isWarm(
            model,
            identity: installIdentity(
                bundlePathComponents: bundlePathComponents,
                systemVersion: systemVersion
            ),
            defaults: defaults
        )
    }

    // MARK: - Writing

    /// Record that `model` has run an inference in this install.
    ///
    /// Idempotent, and cheap enough to call on every warm inference: the load path already
    /// runs at most one per model per process.
    public static func markWarm(
        _ model: String,
        identity: String?,
        defaults: UserDefaults = AppGroup.defaults
    ) {
        guard let identity else { return }
        var current = record(in: defaults)
        guard current[model] != identity else { return }
        current[model] = identity
        write(current, to: defaults)
    }

    /// Forget that `model` is warm.
    ///
    /// Called when its files are re-downloaded (#542, decision 9): a fresh download starts
    /// from a fresh cache, so keeping the record would be a false claim of warmth.
    public static func clear(
        _ model: String,
        defaults: UserDefaults = AppGroup.defaults
    ) {
        var current = record(in: defaults)
        guard current.removeValue(forKey: model) != nil else { return }
        write(current, to: defaults)
    }

    // MARK: - Storage

    /// `[modelIdentifier: installIdentity]`.
    ///
    /// A dictionary rather than one key per model so that clearing, reading and the
    /// cross-install mismatch are all one lookup, and so that stale entries from an older
    /// install cost a few dozen bytes rather than accumulating keys nobody prunes.
    public static func record(in defaults: UserDefaults = AppGroup.defaults) -> [String: String] {
        defaults.dictionary(forKey: SharedKeys.modelWarmth) as? [String: String] ?? [:]
    }

    private static func write(_ record: [String: String], to defaults: UserDefaults) {
        defaults.set(record, forKey: SharedKeys.modelWarmth)
        // The keyboard reads this at the instant of a mic tap, in another process, and a
        // cross-process write can lag a few milliseconds behind. The same `synchronize`
        // every other hand-off boundary in this codebase uses, for the same reason.
        defaults.synchronize()
    }
}
