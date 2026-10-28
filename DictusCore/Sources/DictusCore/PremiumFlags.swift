// DictusCore/Sources/DictusCore/PremiumFlags.swift
import Foundation

/// Compile-time visibility flags for premium UI (issue #236).
///
/// WHY a compile-time constant instead of remote config:
/// when it was introduced no Pro feature existed (#79) and App Store Connect setup
/// was pending (#215), so the paywall would have rendered with empty prices. A
/// single `static let` was enough to hide every entry point (Home banner, Settings Pro section, locked rows, the
/// keyboard panel's Pro pill) while keeping all subscription code compiled and
/// intact. A build's readiness to sell is a property of the build, not a runtime
/// toggle.
///
/// WHY it lives in DictusCore rather than beside `SubscriptionManager`:
/// entry points exist in both DictusApp and DictusKeyboard. It started as an
/// `internal` constant in the app target, which the keyboard extension cannot
/// see — so the panel added in #241 shipped a Pro pill that ignored the flag
/// entirely. One flag gating two targets belongs in the shared framework.
///
/// Re-enabled for 2.0.0 (#279): Smart Modes (#79) is the first real Pro feature and
/// the App Store Connect setup (#215) is done. Flipping it back to `false` hides
/// the surfaces that read it (the four above, the paywall's offers, the trial's
/// screens) and stops new trials, without touching subscription code; a paid
/// entitlement is read the same way either side of the flag.
///
/// WHY an enum with no cases: a caseless enum can never be instantiated,
/// making it a pure namespace for static constants (common Swift pattern).
public enum PremiumFlags {
    /// Controls whether users can see and reach the paywall.
    /// `false` = the app looks like there is no subscription at all.
    public static let paywallVisible = true

    #if DEBUG
    /// Debug-only: report the user as a Pro subscriber whatever StoreKit says (#460).
    ///
    /// ### Why it exists
    ///
    /// #460 makes the keyboard's Smart Mode surface *absent* whenever `paywallVisible` is
    /// false, and that hides it from the maintainer too. Smart Modes are still being
    /// built and still need device testing, so the fix would otherwise block the work
    /// it exists to protect. This is the way back in, and it is a hard requirement of
    /// that change rather than a convenience.
    ///
    /// ### Why it lives here
    ///
    /// Beside the flag it opposes. `paywallVisible` decides what may be *sold*; this
    /// decides what the user is *entitled to*, and reading them a screen apart is how
    /// the two get confused. They are not symmetrical and must not be used as if they
    /// were: turning this on does not open the paywall or any of the surfaces gated on
    /// `paywallVisible` — it grants the entitlement those surfaces would have sold.
    ///
    /// ### Why the App Group and not a `static let`
    ///
    /// Two processes have to agree. The fan lives in the keyboard extension and the
    /// toggle that flips this lives in the app, so a per-process constant would grant
    /// entitlement on one side of the App Group and refuse it on the other — which is
    /// #401, already paid for once. A stored value also means the maintainer flips it
    /// on device instead of rebuilding.
    ///
    /// ### Why it cannot ship
    ///
    /// The whole property is `#if DEBUG`, so the Release binary contains neither it nor
    /// the key below nor the branch in `ProStatusManager.isProActiveStatic` that reads
    /// it. There is no runtime path to a forced entitlement in a build a user can install.
    ///
    /// Consulted in exactly one place — `ProStatusManager.isProActiveStatic`, which is
    /// what `FeatureGate.isProActive` and the keyboard's toolbar both already read. One
    /// source of truth for entitlement; no surface gets its own force path.
    public static var debugProEntitlementForced: Bool {
        get { AppGroup.defaults.bool(forKey: SharedKeys.debugProEntitlementForced) }
        set {
            AppGroup.defaults.set(newValue, forKey: SharedKeys.debugProEntitlementForced)
            // The reader is another process — same reason `ProStatusManager.setProActive`
            // synchronises.
            AppGroup.defaults.synchronize()
        }
    }
    #endif
}
