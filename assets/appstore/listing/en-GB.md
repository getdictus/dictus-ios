# App Store listing, en-GB, 2.0.0 (draft)

Draft for issue #643. **Nothing here is in App Store Connect.** It is staged on the 2.0.0 version by hand (or `asc`) once Pierre approves it, together with the screenshots.

Read from App Store Connect on 2026-10-03 (version 1.9.0, `READY_FOR_SALE`, en-GB): the description, keywords and promotional text quoted under "Current" below. The subtitle was not read back from App Store Connect; the issue gives it as `Private, offline dictation`.

Limits checked with `python3` (characters; keywords counted in UTF-8 bytes): see the table at the end.

## Name

`Dictus: AI Voice Keyboard` (unchanged, 25/30)

## Subtitle

- Current: `Private, offline dictation` (26/30)
- **Proposed: `Private dictation, voice notes`** (30/30)

Why: the 2.0.0 story leads with voice notes (#620/#637), and the subtitle is indexed for search. "Offline" moves to the keywords and stays in the first lines of the description. The name already carries "AI", "Voice" and "Keyboard", so repeating them here would waste indexed space.

Alternative if "offline" must stay visible in search results: `Offline dictation, voice notes` (30/30).

## Promotional text

Can change at any time without a submission. For launch week:

> New: Dictus Pro. Smart Modes turn what you say into a message, a list or a translation, and voice messages you share are transcribed straight into your keyboard.

## Keywords

- Current: `speech to text,transcription,whisper,open source,transcribe,stt,french,german,spanish,notes,mic`
- **Proposed:** `speech to text,transcription,voice message,summary,rewrite,translate,whisper,open source,stt,french`

What changed and why:

- Added the Pro use cases from the issue: `voice message`, `summary`, `rewrite`, `translate`.
- Dropped `notes` and `voice` (now in the subtitle), and `mic` and `transcribe`. Apple matches word stems loosely, so `transcription` should still cover `transcribe`. This is an assumption: Apple does not document its stemming.
- Dropped `german` and `spanish`, kept `french`. **No ranking data was read for this draft.** If App Store Connect analytics show search traffic from `german` or `spanish`, put them back in place of `rewrite` or `stt`.
- No competitor or messaging-app names (WhatsApp, Telegram): guideline 2.3.7 forbids trademarks in keywords.

## Description

```
Dictus is a voice keyboard that types what you say. Tap the mic, speak, and your words appear in any app. Speech recognition runs on your iPhone, even with no connection.

NEW IN 2.0: DICTUS PRO

Read voice messages without leaving the chat. Share a voice message or an audio file to Dictus. It is transcribed on your iPhone, and the transcript waits in your keyboard, back in the conversation you are replying to. Read it, then insert it with one tap.

Turn your voice into the right text with Smart Modes. Hold the mic and pick a mode before you speak:
- Message: the short, clean text you would have typed
- List: your ideas as concise bullet points
- Structured: a long dictation as clear paragraphs
- Summary: the gist of what you said
- Translate: into French, English, German or Spanish

Smart Modes run on your iPhone with Apple Intelligence (iPhone 15 Pro or later, iOS 26 or later). Your words are not sent to a server.

Pro also keeps a history of your dictations and lets you add your own vocabulary, such as names and technical terms.

Try Pro free for 14 days. Nothing to subscribe to and nothing renews: when the 14 days end, Dictus goes back to the free version and asks if you want to keep Pro. Your history and vocabulary are kept. The trial is offered on iPhones that can run Smart Modes.

A REAL KEYBOARD, IN YOUR LANGUAGE

Dictus is a complete keyboard, not just a mic button. AZERTY, QWERTY and QWERTZ layouts, with autocorrect and suggestions in French, English, German and Spanish. Type when you want, talk when you do not.

DICTATION IN 40+ LANGUAGES

Dictation works in more than 40 languages at good or fair quality, and close to 100 with the Whisper models, where quality varies by language. Parakeet, the default model, transcribes 25 European languages and detects which one you are speaking. Every model tells you which languages it handles well before you download it.

PRIVATE, OFFLINE, OPEN SOURCE

Speech recognition happens on your device. No account, no tracking, no analytics. Dictate on a plane, in the underground, anywhere.

Dictus is open source (MIT licence). Anyone can read the code and check these privacy claims.

github.com/getdictus/dictus-ios

CHOOSE YOUR MODEL

Pick the model that fits your iPhone, from compact and fast to most accurate. Download once, use it offline, stored on your device.

Dictus collects no data. Privacy policy: getdictus.com/privacy
```

### Facts to re-check before staging

Each sentence above makes a claim the build has to back. These were checked against the code on 2026-10-03; re-check them at the 2.0.0 cut, because nothing re-reads them later (#488's lesson).

| Claim | Source |
|---|---|
| Five Smart Modes: Message, List, Structured, Summary, Translate | `SmartModeCatalogue.builtIns`, `SmartModeDisplayName.swift` |
| Translate targets: French, English, German, Spanish | `SupportedLanguage.allCases` |
| Apple Intelligence: iPhone 15 Pro or later, iOS 26 or later | #79 ("Pro gating"); to confirm against Apple's current device list |
| 14-day reverse trial, nothing renews, data kept, no trial on ineligible devices | #593 decisions 1, 2 and the acceptance list |
| Voice notes: share sheet, transcript in the keyboard, one-tap insert | #620, #637 (PR #638) |
| 40+ languages at good or fair quality (Whisper good 25 + fair 19, plus Maltese via Parakeet = 45); Parakeet 25 European languages; Whisper close to 100 | `ModelLanguageSupport.swift` (`whisperTierGroups`, `parakeetV3`), #488; also screenshot 6 |
| Keyboard: 4 languages, 3 layouts | `SupportedLanguage.swift`, `KeyboardLayouts.swift` |
| "Pro also keeps a history … vocabulary" | `ProFeature`; the issue keeps both out of the screenshots and allows them here |

### Checklist from the issue

- [x] Description: Pro section (Smart Modes, voice notes in the keyboard, vocabulary, history)
- [x] Description: reverse trial (#593)
- [x] Description: Apple Intelligence requirement for Smart Modes (App Review guideline 2.3.2: make clear what needs a purchase, and on which devices)
- [x] Keywords re-balanced toward Pro use cases (ranking impact not measured, see above)
- [x] Subtitle re-checked against the 2.0.0 story
- [x] Promotional text for launch week
- [ ] fr-FR localization: out of scope for this run (decision 3, English only until the design is approved)

## Length check

| Field | Limit | Length |
|---|---|---|
| Name | 30 | 25 |
| Subtitle (proposed) | 30 | 30 |
| Subtitle (alternative) | 30 | 30 |
| Promotional text | 170 | 161 |
| Keywords (bytes) | 100 | 99 |
| Description | 4000 | 2408 |
