# Dictus feature map

Every user-facing feature of Dictus iOS, one file each. The **ID is the feature's domain name, not the iOS one**: it names what the user gets, never a target, a view or a framework, so the Android app can reuse the same IDs for the same features. An ID never changes once published; a feature that goes away keeps its ID retired, never reused.

Each file has the same four sections: **Sub-features** (each with its own stable ID), **How to get to it (user POV)**, **Driving it with axe + Argent** (the recipe, with `drive.sh` from `../SKILL.md`), **Gotchas** (including what the simulator cannot show). Screens are mapped in [screens.md](screens.md), which also describes the keyboard top bar's states and transitions.

**Tier.** *Gratuit* is available to everyone. *Pro* is gated by `FeatureGate.isAvailable(_:)` (`DictusCore/Sources/DictusCore/Subscription/ProFeature.swift`): Pro active **and** the feature's own switch. Since #279 `PremiumFlags.paywallVisible` is `true`: a fresh install gets the 14-day trial at the end of onboarding, and Pro is on sale from the Home card, the Settings row and the keyboard panel's pill. A Debug build still reaches every Pro feature without a trial with `drive.sh set-default dictus.debugProEntitlementForced -bool YES`.

| ID | Feature | Tier | Drivable in the simulator |
| --- | --- | --- | --- |
| [`dictation.keyboard`](dictation.keyboard.md) | Dictation from the keyboard | Gratuit | Yes with a model: a real recording of the Mac's mic, transcription, insertion, the undo state (the undo tap itself not driven) |
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

## All IDs

Every ID in this map, in one table: the 18 features first, then their 109 sub-features (in the order of the feature files), then the 53 screens of [screens.md](screens.md) — 180 IDs in all. **Gratuit/Pro** is the tier of the feature the ID belongs to. **Spécifique iOS** is « oui » when the ID has no Android equivalent to compare against: the keyboard-to-app hand-off and Full Access (an iOS keyboard extension cannot record and must ask for Full Access), return to the host app, Apple Intelligence (polish), the Dynamic Island (Live Activity, stopping standby), and the App Group check.

| ID | Gratuit/Pro | Spécifique iOS |
| --- | --- | --- |
| [`dictation.keyboard`](dictation.keyboard.md) | Gratuit | non |
| [`dictation.in-app`](dictation.in-app.md) | Gratuit | non |
| [`dictation.return-to-app`](dictation.return-to-app.md) | Gratuit | oui |
| [`models.transcription`](models.transcription.md) | Gratuit | non |
| [`polish`](polish.md) | Gratuit | oui |
| [`smart-modes`](smart-modes.md) | Pro | non |
| [`history`](history.md) | Pro | non |
| [`vocabulary`](vocabulary.md) | Pro | non |
| [`voice-notes`](voice-notes.md) | Pro | non |
| [`typing.autocorrect`](typing.autocorrect.md) | Gratuit | non |
| [`typing.learned-words`](typing.learned-words.md) | Gratuit | non |
| [`keyboard.languages`](keyboard.languages.md) | Gratuit | non |
| [`keyboard.emoji`](keyboard.emoji.md) | Gratuit | non |
| [`feedback.sounds-haptics`](feedback.sounds-haptics.md) | Gratuit | non |
| [`live-activity`](live-activity.md) | Gratuit | oui |
| [`onboarding`](onboarding.md) | Gratuit | non |
| [`pro.subscription`](pro.subscription.md) | Pro | non |
| [`diagnostics.logs`](diagnostics.logs.md) | Gratuit | non |
| `dictation.start` | Gratuit | non |
| `dictation.stop` | Gratuit | non |
| `dictation.cancel` | Gratuit | non |
| `dictation.status` | Gratuit | non |
| `dictation.undo-insert` | Gratuit | non |
| `dictation.handoff` | Gratuit | oui |
| `dictation.requires-full-access` | Gratuit | oui |
| `dictation.device-gating` | Gratuit | non |
| `dictation.start-in-app` | Gratuit | non |
| `dictation.copy-last` | Gratuit | non |
| `dictation.download-prompt` | Gratuit | non |
| `dictation.from-widget` | Gratuit | non |
| `return.swipe-back` | Gratuit | oui |
| `return.auto-return` | Gratuit | oui |
| `models.catalogue` | Gratuit | non |
| `models.recommended` | Gratuit | non |
| `models.download` | Gratuit | non |
| `models.select` | Gratuit | non |
| `models.delete` | Gratuit | non |
| `models.retry` | Gratuit | non |
| `models.languages` | Gratuit | non |
| `models.preparation` | Gratuit | non |
| `models.device-gating` | Gratuit | non |
| `polish.toggle` | Gratuit | oui |
| `polish.clean-up` | Gratuit | oui |
| `polish.in-keyboard` | Gratuit | oui |
| `polish.debug` | Gratuit | oui |
| `smart-modes.fan` | Pro | non |
| `smart-modes.structured` | Pro | non |
| `smart-modes.list` | Pro | non |
| `smart-modes.message` | Pro | non |
| `smart-modes.summary` | Pro | non |
| `smart-modes.translate` | Pro | non |
| `smart-modes.pin` | Pro | non |
| `smart-modes.toggle` | Pro | non |
| `history.list` | Pro | non |
| `history.search` | Pro | non |
| `history.delete` | Pro | non |
| `history.detail` | Pro | non |
| `history.clear` | Pro | non |
| `history.toggle` | Pro | non |
| `history.home-entry` | Pro | non |
| `vocabulary.add` | Pro | non |
| `vocabulary.edit` | Pro | non |
| `vocabulary.delete` | Pro | non |
| `vocabulary.reset` | Pro | non |
| `vocabulary.suggestions` | Pro | non |
| `vocabulary.apply` | Pro | non |
| `vocabulary.toggle` | Pro | non |
| `voice-notes.share-in` | Pro | non |
| `voice-notes.transcribe` | Pro | non |
| `voice-notes.after-mode` | Pro | non |
| `voice-notes.language` | Pro | non |
| `voice-notes.reader` | Pro | non |
| `voice-notes.insert` | Pro | non |
| `voice-notes.delete` | Pro | non |
| `voice-notes.toggle` | Pro | non |
| `voice-notes.progress-activity` | Pro | oui |
| `typing.suggestions` | Gratuit | non |
| `typing.autocorrect-on-space` | Gratuit | non |
| `typing.undo-correction` | Gratuit | non |
| `typing.auto-full-stop` | Gratuit | non |
| `typing.accents` | Gratuit | non |
| `typing.dead-keys` | Gratuit | non |
| `typing.autocorrect-toggle` | Gratuit | non |
| `learned-words.learn` | Gratuit | non |
| `learned-words.reset` | Gratuit | non |
| `keyboard.language-switch` | Gratuit | non |
| `keyboard.layout` | Gratuit | non |
| `keyboard.number-row` | Gratuit | non |
| `keyboard.default-page` | Gratuit | non |
| `keyboard.transcription-language` | Gratuit | non |
| `keyboard.open-app` | Gratuit | non |
| `emoji.picker` | Gratuit | non |
| `emoji.recents` | Gratuit | non |
| `emoji.search` | Gratuit | non |
| `emoji.back-to-letters` | Gratuit | non |
| `sounds.toggle` | Gratuit | non |
| `sounds.volume` | Gratuit | non |
| `sounds.per-event` | Gratuit | non |
| `haptics.toggle` | Gratuit | non |
| `live-activity.standby` | Gratuit | oui |
| `live-activity.states` | Gratuit | oui |
| `live-activity.stop-standby` | Gratuit | oui |
| `live-activity.controls` | Gratuit | oui |
| `live-activity.toggle` | Gratuit | oui |
| `onboarding.welcome` | Gratuit | non |
| `onboarding.language` | Gratuit | non |
| `onboarding.keyboard-setup` | Gratuit | oui |
| `onboarding.apple-intelligence` | Gratuit | oui |
| `onboarding.pro-scenes` | Gratuit | non |
| `onboarding.smart-mode-pick` | Gratuit | non |
| `onboarding.model-download` | Gratuit | non |
| `onboarding.microphone` | Gratuit | non |
| `onboarding.first-dictation` | Gratuit | non |
| `onboarding.stop-standby` | Gratuit | oui |
| `onboarding.completion` | Gratuit | non |
| `onboarding.resume` | Gratuit | non |
| `onboarding.whats-new` | Gratuit | non |
| `pro.hub` | Pro | non |
| `pro.paywall` | Pro | non |
| `pro.restore` | Pro | non |
| `pro.trial` | Pro | non |
| `pro.trial-end` | Pro | non |
| `pro.demo` | Pro | non |
| `diagnostics.log-view` | Gratuit | non |
| `diagnostics.log-export` | Gratuit | non |
| `diagnostics.app-group-check` | Gratuit | oui |
| `diagnostics.about` | Gratuit | non |
| `app.onboarding.welcome` | Gratuit | non |
| `app.onboarding.language` | Gratuit | non |
| `app.onboarding.keyboard-setup` | Gratuit | oui |
| `app.onboarding.apple-intelligence` | Gratuit | oui |
| `app.onboarding.smart-modes-scene` | Gratuit | non |
| `app.onboarding.smart-mode-pick` | Gratuit | non |
| `app.onboarding.voice-notes-scene` | Gratuit | non |
| `app.onboarding.vocabulary-scene` | Gratuit | non |
| `app.onboarding.history-scene` | Gratuit | non |
| `app.onboarding.model-preparation` | Gratuit | non |
| `app.onboarding.microphone` | Gratuit | non |
| `app.onboarding.first-dictation` | Gratuit | non |
| `app.onboarding.stop-standby` | Gratuit | oui |
| `app.onboarding.completion` | Gratuit | non |
| `app.whats-new` | Gratuit | non |
| `app.home` | Gratuit | non |
| `app.recording` | Gratuit | non |
| `app.history` | Pro | non |
| `app.history.detail` | Pro | non |
| `app.models` | Gratuit | non |
| `app.models.languages` | Gratuit | non |
| `app.models.loading` | Gratuit | non |
| `app.settings` | Gratuit | non |
| `app.settings.sounds` | Gratuit | non |
| `app.settings.diagnostic` | Gratuit | oui |
| `app.settings.debug-logs` | Gratuit | non |
| `app.settings.licences` | Gratuit | non |
| `app.settings.polish-debug` | Gratuit | oui |
| `app.pro.hub` | Pro | non |
| `app.pro.smart-modes` | Pro | non |
| `app.pro.history` | Pro | non |
| `app.pro.vocabulary` | Pro | non |
| `app.pro.vocabulary.term-editor` | Pro | non |
| `app.pro.voice-notes` | Pro | non |
| `app.paywall` | Pro | non |
| `app.pro.trial-announcement` | Pro | non |
| `app.voice-note.result` | Pro | non |
| `kbd.keys` | Gratuit | non |
| `kbd.no-full-access` | Gratuit | oui |
| `kbd.dictation-error` | Gratuit | non |
| `kbd.recording` | Gratuit | non |
| `kbd.transcribing` | Gratuit | non |
| `kbd.dictation-undo` | Gratuit | non |
| `kbd.numbers` | Gratuit | non |
| `kbd.symbols` | Gratuit | non |
| `kbd.panel` | Gratuit | non |
| `kbd.emoji` | Gratuit | non |
| `kbd.voice-note-reader` | Pro | non |
| `kbd.smart-mode-fan` | Pro | non |
| `kbd.suggestions` | Gratuit | non |
| `sys.settings.full-access` | Gratuit | oui |
| `share.voice-note` | Pro | non |
| `widget.live-activity` | Gratuit | oui |
