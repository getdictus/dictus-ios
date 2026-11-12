# Dictus Pro: purchase, hub and trial

- **ID:** `pro.subscription`
- **Tier:** Pro
- **Targets:** DictusApp + DictusCore
- **Screens:** `app.pro.hub`, `app.paywall`, `app.pro.trial-announcement` — see [screens.md](screens.md)

## Sub-features

- `pro.hub`: Dictus Pro hub, for the running trial, subscribers and lifetime owners (#216, #913): the large hero (glowing icon tile, « Dictus Pro », « Votre voix, sans limites »), the four large cards with « Activé » / « Désactivé » and a chevron, each pushing its feature screen (with its own bar and `BackButton`), and the cross floating top left (`proHub.close`, no navigation bar). During the trial the cards are followed by « Plus que N jours d’essai gratuit » with the end date, then « Continuer avec Dictus Pro » (`proHub.continueToOffers`), which opens the paywall in a full-screen cover; its cross returns to the hub. Subscriber and lifetime: the membership card, nothing to sell.
- `pro.paywall`: The paywall, for Free (no trial) and the end of the trial, and the offers the trial hub opens; one screen with no scroll down to an iPhone SE (#913). No navigation bar: the cross floats top left (`paywall.close`). The large hero at the top (icon tile and « Dictus Pro », no tagline; a smaller tile on an iPhone SE, the same geometry as the hub so the logo does not move when the hub opens it), the headline, four checkmark lines (informational: no chevron, not tappable), yearly and lifetime as radio rows, the monthly behind « Voir toutes les formules » (inserted without animation), then the pinned footer: « Continuer avec Dictus Pro », the billed price line, « Restaurer les achats · Saisir un code », « Conditions d’utilisation · Confidentialité ». The content spreads over the height (no gap above the CTA on a tall iPhone). The lifetime scope line under the rows always keeps its height and shows by opacity while « À vie » is selected, so selecting a plan moves nothing; its ⓘ opens the full sentence. Selecting a plan animates only the radio, the card border and the price line.
- `pro.restore`: Restore purchases.
- `pro.redeem-code`: « Saisir un code » / « Redeem a code », under Restore purchases (#787): opens Apple's offer code sheet. Shown wherever plans are sold, like Restore.
- `pro.trial`: A 14-day trial announced at the end of onboarding.
- `pro.trial-end`: End-of-trial paywall (the paywall only, no hub), one screen since #913: « Votre essai est terminé », a one-line recap (« En 14 jours : 6 638 mots dictés, 1 h 22 min gagnées », each value left out at zero), the plans, « Garder Dictus Pro » and « Continuer gratuitement ».
- `pro.demo`: « Voir la démonstration » on each Pro feature's page.

## How to get to it (user POV)

1. Dictus → Réglages → Dictus Pro (once Pro is on sale): the paywall for Free and after the trial, the Pro hub during the trial and for subscribers.
2. Choose a plan; or start the trial offered at the end of onboarding.

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/launch.sh --skip-onboarding
.claude/skills/verify-dictus-ios/scripts/drive.sh set-default dictus.debugProEntitlementForced -bool YES
.claude/skills/verify-dictus-ios/scripts/drive.sh tab Réglages
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Dictus Pro, Pro actif"
.claude/skills/verify-dictus-ios/scripts/evidence.sh pro-hub
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-id proHub.close
```

Trial hub, then the paywall it opens (#913):

```bash
# Réglages → Developer → « Forget the trial (Keychain, mirror, counters, paywall) », then « Start a fresh 14-day trial »
.claude/skills/verify-dictus-ios/scripts/drive.sh tab Réglages
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Dictus Pro, Pro · 14 jours restants"
.claude/skills/verify-dictus-ios/scripts/evidence.sh pro-hub-trial
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-id proHub.continueToOffers   # on an iPhone SE, scroll the hub first
.claude/skills/verify-dictus-ios/scripts/evidence.sh pro-hub-offers
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-id paywall.close              # back to the hub
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-id proHub.close
```

Trial states can be forced from Réglages → Developer → « Reverse trial (#593) » (Debug builds).

## Gotchas

- **Prices need simslim's `store` category.** On the slimmed device `launch.sh` creates, `loadProducts` fails with « Impossible de communiquer avec une application d'aide » (StoreKit's daemon is disabled) and the paywall's buy button stays at « … ». `simslim on <udid> --keep com.apple.remindd --except store` (reboots the device, keeps the install) brings the prices back: on 2026-10-22 an iPhone 17 / iOS 26.5 device showed Yearly $39.99 and Lifetime $79.99 (US storefront). That proves the paywall renders its plans, not that App Store Connect serves the real prices to a French account: that stays a device check.
- **Not driven in the simulator:** a purchase or a restore.
- **Redeem a code (#787):** on the paywall (Free, or the offers opened from the trial hub), `drive.sh tap-id paywall.redeemCode`, in the pinned footer: no scroll. With simslim's `store` category on, Apple's sheet opens (« Activer l'offre » / « Redeem Offer », a Code field, Continuer); its cross sits at about (363, 100) pt and closing logs `storeKit action=offerCodeSheetClosed details=result=success`. On the default slimmed device the sheet cannot open and the log says `subscriptionError action=offerCodeRedemption error=Impossible de communiquer avec une application d’aide.` Redeeming a code is not driven: it needs a sandbox offer code from App Store Connect on an iPhone. Captures: `docs/agents/evidence/787/`.
- **Trial states (#593):** the end-of-onboarding announcement raises itself (`proTrial action=announcementShown details=kind=newUser`). Réglages → Developer → « Reverse trial (#593) » drives the rest: « Move to the last 2 days » (Home card, Settings badge and the keyboard panel's « Pro · 2 days left » pill), « End the trial now » (end-of-trial paywall, one screen since #913; seed `dictus.dictationTally` in the App Group with `{"<yyyy-MM-dd>": {words, audioSeconds}}` for the recap line to show), « Forget the trial » + « Forget What's new » then relaunch (What's new, then `kind=existingUser`).
- **An ineligible device cannot be simulated.** `SmartModeAvailability.deviceIsCapable` reads Apple Intelligence availability, which a simulator takes from the host Mac: a device created as `iPad-Pro--11-inch-` (A12X, `iPad8,1`) still reports capable and shows every promotion. The ineligible branch is covered by `ProTrialTests.testAnIneligibleDeviceNeverStartsATrialAndIsNeverPromotedTo` and the `deviceCanRunSmartModes: false` cases of `OnboardingStepTests` and `WhatsNewTests`; the device check stays on the iPad.
- **Reinstall over an ended trial (#837):** the Keychain record survives `xcrun simctl uninstall`, the App Group does not. Seed with « End the trial now », uninstall, reinstall, `set-default dictus.onboardingStep -string completion`, tap `onboarding.primary`: the **ordinary** paywall opens, no « essai terminé », no recap. Log: `proTrial action=restoredEndedBeforeInstall` at launch, then `endOfTrialPaywallShown details=framing=standard`. Closing it (cross or « Continuer gratuitement ») shows the monthly offer once, as the end-of-trial paywall does; the same ordinary paywall opened from Réglages or Home never does. An install that lived through its trial still logs `framing=trialEnded`.
- Do not set `dictus.proActive`: `SubscriptionManager` resets it at launch.
- **The four paywall entry points (#279)** show together only for a non-subscriber with no running trial: « End the trial now », then « Continuer gratuitement ». Home Pro card, Home locked « Historique » hint, Réglages → Dictus Pro, and the keyboard panel's « Dictus Pro » pill (☰ held, left of the gear). The pill opens `dictus://open?source=keyboard&intent=pro`: the log shows `<KBD> … openDictusApp details=intent=pro` then `<APP> … keyboardProIntent`. Captures of all four in FR, EN and iPad: `docs/agents/screens/279/`.
- **English device:** `drive.sh full-access` and `select-keyboard` look for French system labels. On `--lang en` they are « Allow Full Access », « Allow » / « Don’t Allow », « Next keyboard » and « Dictus, Multiple languages ».
- **iPad (`iPad-Pro--11-inch-`):** Dictus runs in a 375×667 iPhone compatibility window, and `axe describe-ui` reports frames in that window, so `axe tap --label` lands in the wrong place: scale by 1194/667 and centre horizontally. In Safari the Dictus bar sits under the system shortcut bar, about 66 pt below `inputView`'s top, so `kbd` offsets miss it. The pill opens Dictus as a window over Safari, and Safari's keyboard covers the paywall's plans until Dictus is brought forward.
- **One screen (#913):** the paywall and the hub switch to the compact hero and tighter spacing when the screen is under 700 pt tall (iPhone SE: about 650 pt under the status bar). Fit measured on iPhone 17 Pro Max, iPhone 17 and iPhone SE (3rd generation), FR/EN/DE/ES, light and dark. Known limit: on an iPhone SE, the offers opened from the trial hub with all three plans shown and « À vie » selected scroll a little (the days-left line takes the room).
- **Same hero on hub and paywall (#913):** measured hero frame, hub → offers: iPhone 17 Pro Max y = 70.0 on both, « Dictus Pro » bottom 214.1 on both; iPhone SE y = 22.0, bottom 104.0. Plan switching measured with the headline's frame (unchanged through Annuel → À vie → Annuel). Recordings: `docs/agents/evidence/913/plan-switch-iphone17promax.mp4`, `plan-switch-iphonese.mp4`.
- **Label taps on an iPhone 17 Pro Max (2026-11-11):** `axe tap --label` on the Home Pro card (« Dictus Pro, 4 fonctionnalités actives ») did not open it there, while the same tap works on an iPhone SE. Open the hub from Réglages, or tap the centre of the element's frame.
- **Captures (#913):** the current screens are in `docs/agents/evidence/913/`: `after-free-light-iphone17promax-fr.png`, `after-free-light-iphonese-fr.png`, `after-trial-ended-light-iphone17promax-fr.png`, `after-trial-ended-light-iphonese-fr.png`, `after-hero-trial-hub-iphone17promax-fr.png`, `after-hero-trial-offers-iphone17promax-fr.png` (and `-iphonese-`), `after-hub-forced-pro-light-iphone17promax-fr.png`, `after-hub-pushed-vocabulary-iphone17promax-fr.png`. The copies in `docs/agents/screens/` (`app.paywall.png`, `app.paywall.trial-ended.png`, `app.pro.hub.png`) still show the first #913 layout (small wordmark in the bar) and are to be re-captured.
