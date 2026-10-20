# Dictus feature map

Every user-facing feature of Dictus iOS, one file each. The **ID is the feature's domain name, not the iOS one**: it names what the user gets, never a target, a view or a framework, so the Android app can reuse the same IDs for the same features. An ID never changes once published; a feature that goes away keeps its ID retired, never reused.

Each file has the same four sections: **Sub-features**, **How to get to it (user POV)**, **Driving it with axe + Argent** (the recipe, with `drive.sh` from `../SKILL.md`), **Gotchas** (including what the simulator cannot show). Screens are mapped in [screens.md](screens.md).

**Tier.** *Gratuit* is available to everyone. *Pro* is gated by `FeatureGate.isAvailable(_:)` (`DictusCore/Sources/DictusCore/Subscription/ProFeature.swift`): Pro active **and** the feature's own switch. While `PremiumFlags.paywallVisible = false` nothing Pro can be bought; a Debug build reaches every Pro feature with `drive.sh set-default dictus.debugProEntitlementForced -bool YES`.

| ID | Feature | Tier | Drivable in the simulator |
| --- | --- | --- | --- |
| [`dictation.keyboard`](dictation.keyboard.md) | Dictation from the keyboard | Gratuit | Hand-off up to the no-model failure; not a recording |
| [`dictation.in-app`](dictation.in-app.md) | Dictation inside the app | Gratuit | Home state only; recording = the Mac's mic |
| [`dictation.return-to-app`](dictation.return-to-app.md) | Return to the app you were typing in | Gratuit | Cold start only; return = device |
| [`models.transcription`](models.transcription.md) | Transcription models | Gratuit | Yes (download is real traffic); RAM gates no |
| [`polish`](polish.md) | Polish | Gratuit, needs Apple Intelligence | Toggle only |
| [`smart-modes`](smart-modes.md) | Smart Modes | Pro | Fan and settings; no rewrite (no Apple Intelligence) |
| [`history`](history.md) | History of transcriptions | Pro | Empty state and settings |
| [`vocabulary`](vocabulary.md) | Custom vocabulary | Pro | Yes, except its effect on a transcript |
| [`voice-notes`](voice-notes.md) | Voice notes transcription | Pro | Keyboard reader and settings; no share sheet |
| [`typing.autocorrect`](typing.autocorrect.md) | Autocorrect and suggestions | Gratuit | Yes, keys by coordinate |
| [`typing.learned-words`](typing.learned-words.md) | Learned words | Gratuit | Yes |
| [`keyboard.languages`](keyboard.languages.md) | Keyboard languages and layouts | Gratuit | Yes |
| [`keyboard.emoji`](keyboard.emoji.md) | Emoji | Gratuit | Yes |
| [`feedback.sounds-haptics`](feedback.sounds-haptics.md) | Sounds and haptics | Gratuit | Settings only; no sound, no haptic |
| [`live-activity`](live-activity.md) | Live Activity and Dynamic Island | Gratuit | Not reproduced by this skill |
| [`onboarding`](onboarding.md) | Onboarding and What's new | Gratuit | Every step displayable; download/mic steps not completed |
| [`pro.subscription`](pro.subscription.md) | Dictus Pro: purchase, hub and trial | Pro | Hub (Debug-forced); no purchase |
| [`diagnostics.logs`](diagnostics.logs.md) | Debug logs and diagnostics | Gratuit | Yes |

Out of the map on purpose: the "Developer" section of Réglages (Debug builds only, not a user feature), and in-app feedback, which does not exist in the code today.
