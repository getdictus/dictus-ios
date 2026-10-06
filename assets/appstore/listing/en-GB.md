# App Store listing, en-GB, 2.0.0 (draft)

Draft for issue #643, aligned with the V3 screenshots (`export/en-GB/v3/`). **Nothing here is in App Store Connect.** It is staged on the 2.0.0 version by hand (or `asc`) once Pierre approves it, together with the screenshots.

Read from App Store Connect on 2026-10-03 (version 1.9.0, `READY_FOR_SALE`, en-GB): the description, keywords and promotional text marked "Current" below. The current subtitle was not read back from App Store Connect; the issue gives it as `Private, offline dictation`.

Limits checked with `python3` (characters; keywords counted in UTF-8 bytes): see the table at the end.

**Depends on the 2.0.0 Pro flip.** The Pro and trial paragraphs describe the app once `PremiumFlags.paywallVisible` is `true` (#279). It is `false` in the code today, so this copy must not ship on a build where it still is.

## Name

`Dictus: AI Voice Keyboard` (unchanged, 25/30)

## Subtitle

- Current: `Private, offline dictation` (26/30)
- **Chosen: `Private dictation, voice notes`** (30/30)

Why this one:

- **It holds for every user.** Voice notes (#620, slide 3) are Pro but need no Apple Intelligence, so the promise is true on every iPhone that buys Pro. `Private dictation, translation` (also 30) was the other serious candidate after V3 made Translate slide 2; it was set aside because Translate needs Apple Intelligence, which most of the installed base lacks (#79), and because "translation" competes head-on with dedicated translators.
- **It adds new indexed words.** The name already carries "AI", "Voice" and "Keyboard". "Dictation" is the core search term, "notes" combines with "voice" from the name, and "private" carries the main promise.
- **"Offline" is not lost.** It moves to the keywords, the first line of the description, and slide 5.

## Promotional text

Can change at any time without a submission. For launch week (163/170):

> New in 2.0: Dictus Pro. Translate as you speak and read voice messages from your chats right in your keyboard. Free for 14 days on iPhones with Apple Intelligence.

"On iPhones with Apple Intelligence" is not decoration: the trial never starts on a device that cannot run Smart Modes (#593 decision 2), so a bare "free for 14 days" would be untrue there.

## Keywords

- Current: `speech to text,transcription,whisper,open source,transcribe,stt,french,german,spanish,notes,mic`
- **Proposed (100/100 bytes):** `speech,text,transcription,message,translate,translator,audio,offline,whisper,open source,summary,stt`

What changed and why:

- **Added, for Pro:** `message` (Apple combines keywords with the words of the name and subtitle, so with "voice" from the name it covers "voice message"), `translate`, `translator`, `audio` ("audio to text", with `text`), `summary`, `offline`.
- **Split:** `speech to text` became `speech` and `text`. Apple combines single words, and the pair still forms the phrase while freeing bytes. This rests on Apple's documented advice to use single words; Apple does not document how it weighs them.
- **Dropped:** `notes` (now in the subtitle), `transcribe` (assumed covered by `transcription`, since Apple does not document its stemming), `mic`, and `french`, `german`, `spanish`.
- **No ranking data was read for this draft.** Dropping the three language names is the main risk: if App Store Connect analytics show search traffic from them, put them back in place of `translator` or `stt`.
- No competitor or messaging-app names (WhatsApp, Telegram): guideline 2.3.7 forbids trademarks in keywords.

## Description

The sections follow the V3 slide order and headlines.

```
Dictus is a voice keyboard that types what you say. Tap the mic, speak, and your words appear in any app. Speech recognition runs on your iPhone, even with no connection.

DICTATE IN ANY APP

Messages, mail, notes, reminders: wherever you can type, Dictus is one tap away. Speak naturally and your words appear where your cursor is.

TRANSLATE AS YOU SPEAK (PRO)

Smart Modes turn your dictation into the text you need before it is typed. Hold the mic, pick a mode, and speak:
- Translate: into French, English, German or Spanish
- Message: the short text you would have typed
- List: your ideas as bullet points
- Structured: a long dictation as clear paragraphs
- Summary: the gist of what you said

Smart Modes run on your iPhone with Apple Intelligence (iPhone 15 Pro or later, iOS 26 or later). Your words are not sent to a server.

READ VOICE NOTES IN YOUR KEYBOARD (PRO)

Got a voice message you cannot listen to right now? Share it to Dictus from your chat app. It is transcribed on your iPhone, and the transcript waits in your keyboard when you go back to the conversation. Read it, then insert it with one tap if you want to quote it.

A REAL KEYBOARD IN YOUR LANGUAGE

Dictus is a complete keyboard, not just a mic button. AZERTY, QWERTY and QWERTZ layouts, with autocorrect and suggestions in French, English, German and Spanish. Type when you want, talk when you do not.

YOUR VOICE NEVER LEAVES YOUR IPHONE

Speech recognition happens on your device. No account, no tracking, no analytics. Dictate on a plane, in the underground, anywhere. The models live on your iPhone: download one once, then use it offline, from compact and fast to most accurate.

Dictus is open source (MIT licence). Anyone can read the code and check these privacy claims: github.com/getdictus/dictus-ios

DICTATE IN 40+ LANGUAGES

Dictation works in more than 40 languages at good or fair quality, and close to 100 with the Whisper models, where quality varies by language. Parakeet, the default model, transcribes 25 European languages and detects which one you are speaking. Every model tells you which languages it handles well before you download it.

DICTUS PRO

Pro adds Smart Modes, voice notes in your keyboard, a history of your dictations, and your own vocabulary for names and technical terms.

Try Pro free for 14 days. There is nothing to subscribe to and nothing renews: when the 14 days end, Dictus goes back to the free version and asks if you want to keep Pro. Your history and vocabulary are kept. The trial is offered on iPhones that can run Smart Modes. Dictation and the keyboard stay free.

Dictus collects no data. Privacy policy: getdictus.com/privacy
```

### Facts to re-check before staging

Each sentence above makes a claim the build has to back. Checked against the code on 2026-10-05; re-check them at the 2.0.0 cut, because nothing re-reads them later (#488's lesson).

| Claim | Source |
|---|---|
| Five Smart Modes: Translate, Message, List, Structured, Summary | `SmartModeCatalogue.builtIns`, `SmartModeDisplayName.swift` |
| Translate targets: French, English, German, Spanish | `SupportedLanguage.allCases` |
| Apple Intelligence: iPhone 15 Pro or later, iOS 26 or later | #79 ("Pro gating"); **to confirm against Apple's current device list** |
| Pro = Smart Modes, voice notes, history, vocabulary | `ProFeature` (`smartMode`, `voiceNotes`, `history`, `vocabulary`) |
| 14-day reverse trial, nothing renews, data kept, no trial where Smart Modes can never run | `ProTrial.durationDays = 14`, `ProTrialPolicy` (definitive reasons), #593 decisions 1 and 2 |
| Voice notes: share sheet, transcript in the keyboard, one-tap insert | #620, #637, #639 |
| "Dictation and the keyboard stay free" | `ProFeature` gates only the four features above |
| 40+ languages at good or fair quality (Whisper good 25 + fair 19, plus Maltese via Parakeet = 45); Parakeet 25 European; Whisper close to 100 | `ModelLanguageSupport.swift` (`whisperTierGroups`, `parakeetV3`), #488; also slide 6 |
| Keyboard: 4 languages, 3 layouts | `SupportedLanguage.swift`, `KeyboardLayouts.swift` |
| No account, no tracking, no analytics, no data collected | App Privacy "Data Not Collected" (#189, #565) |

### Checklist from the issue

- [x] Description: Pro section (Smart Modes including Translate, voice notes in the keyboard, vocabulary, history)
- [x] Description: reverse trial (#593), with the terms from the code
- [x] Description: Apple Intelligence requirement for Smart Modes (guideline 2.3.2: make clear what needs a purchase, and on which devices)
- [x] Description: order and headlines of the V3 slides
- [x] Keywords re-balanced toward Pro use cases (ranking impact not measured, see above)
- [x] Subtitle chosen, with the reason
- [x] Promotional text for launch week
- [ ] fr-FR localization: after Pierre approves the English set (decision 3)

## Length check

| Field | Limit | Length |
|---|---|---|
| Name | 30 | 25 |
| Subtitle | 30 | 30 |
| Promotional text | 170 | 163 |
| Keywords (bytes) | 100 | 100 |
| Description | 4000 | 2665 |
