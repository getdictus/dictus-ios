# Dictus Pro: purchase, hub and trial

- **ID:** `pro.subscription`
- **Tier:** Pro
- **Targets:** DictusApp + DictusCore
- **Screens:** `app.pro.hub`, `app.paywall`, `app.pro.trial-announcement` — see [screens.md](screens.md)

## Sub-features

- `pro.hub`: Dictus Pro hub: the four Pro features with their state and settings.
- `pro.paywall`: Three plans to buy Pro.
- `pro.restore`: Restore purchases.
- `pro.trial`: A 14-day trial announced at the end of onboarding.
- `pro.trial-end`: End-of-trial paywall.
- `pro.demo`: « Voir la démonstration » on each Pro feature's page.

## How to get to it (user POV)

1. Dictus → Réglages → Dictus Pro (once Pro is on sale).
2. Choose a plan; or start the trial offered at the end of onboarding.

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/launch.sh --skip-onboarding
.claude/skills/verify-dictus-ios/scripts/drive.sh set-default dictus.debugProEntitlementForced -bool YES
.claude/skills/verify-dictus-ios/scripts/drive.sh tab Réglages
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Dictus Pro, Pro actif"
.claude/skills/verify-dictus-ios/scripts/evidence.sh pro-hub
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-id xmark
```

Trial states can be forced from Réglages → Developer → « Reverse trial (#593) » (Debug builds).

## Gotchas

- **Prices need simslim's `store` category.** On the slimmed device `launch.sh` creates, `loadProducts` fails with « Impossible de communiquer avec une application d'aide » (StoreKit's daemon is disabled) and the paywall's buy button stays at « … ». `simslim on <udid> --keep com.apple.remindd --except store` (reboots the device, keeps the install) brings the prices back: on 2026-10-22 an iPhone 17 / iOS 26.5 device showed Yearly $39.99 and Lifetime $79.99 (US storefront). That proves the paywall renders its plans, not that App Store Connect serves the real prices to a French account: that stays a device check.
- **Not driven in the simulator:** a purchase or a restore.
- **Trial states (#593):** the end-of-onboarding announcement raises itself (`proTrial action=announcementShown details=kind=newUser`). Réglages → Developer → « Reverse trial (#593) » drives the rest: « Move to the last 2 days » (Home card, Settings badge and the keyboard panel's « Pro · 2 days left » pill), « End the trial now » (end-of-trial paywall, recap then offers), « Forget the trial » + « Forget What's new » then relaunch (What's new, then `kind=existingUser`).
- **An ineligible device cannot be simulated.** `SmartModeAvailability.deviceIsCapable` reads Apple Intelligence availability, which a simulator takes from the host Mac: a device created as `iPad-Pro--11-inch-` (A12X, `iPad8,1`) still reports capable and shows every promotion. The ineligible branch is covered by `ProTrialTests.testAnIneligibleDeviceNeverStartsATrialAndIsNeverPromotedTo` and the `deviceCanRunSmartModes: false` cases of `OnboardingStepTests` and `WhatsNewTests`; the device check stays on the iPad.
- Do not set `dictus.proActive`: `SubscriptionManager` resets it at launch.
