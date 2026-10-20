# Dictus Pro: purchase, hub and trial

- **ID:** `pro.subscription`
- **Tier:** Pro
- **Targets:** DictusApp + DictusCore
- **Screens:** `app.pro.hub`, `app.paywall` (not captured), `app.pro.trial-announcement` (not captured) — see [screens.md](screens.md)

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

- **Not drivable in the simulator:** a purchase. StoreKit logs `subscriptionError action=loadProducts error=empty result` without a StoreKit configuration in the scheme.
- With `paywallVisible = false` the paywall, the trial screens and `dictus://open?intent=pro` are unreachable in any build; the hub shown here is the Debug-forced one.
- Do not set `dictus.proActive`: `SubscriptionManager` resets it at launch.
