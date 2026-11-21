# Real keyboard cases per language: en, es, de (fr for reference)

Compiled 2026-11-19. A register of what real people reported about the Dictus **keyboard**
(autocorrect, predictions, suggestions, swipe, key accuracy, accents, layout,
language-specific typing), in the spirit of #500. The tracker is public: no reviewer
nicknames, tester names, emails or device ids appear here.

## How to read this

Each row says where the case came from. Provenance kinds, from most to least "field":

- **App Store review**: a written customer review, read with `asc reviews` (read-only).
- **TestFlight**: a TestFlight feedback submission, read with `asc testflight feedback list`
  (read-only). The locale shown is the **device locale**, not the language the person typed in.
- **External user (GitHub)**: an issue or comment written by someone outside the project.
- **Tester, via the tracker**: a beta tester report that the maintainer copied into an issue.
- **Maintainer, device use**: the maintainer typing on their own iPhone.
- **Code review / analysis**: found by reading code or data, not by typing. Listed only
  where it is the only evidence for a language, and marked as such. It is not a field case.

"Reported" columns quote or paraphrase the source. Anything inferred is marked *(inference)*.

## Sources: what exists today and what does not

| Channel | Accessible? | What it holds for the keyboard |
|---|---|---|
| App Store written reviews | Yes, `asc reviews --app 6761262378` | 9 written reviews total (5 FRA, 3 USA, 1 DEU), 2026-07-30 to 2026-11-12. One mentions the keyboard: the US review below. |
| App Store ratings without text | Yes, `asc reviews ratings --all` | 14 ratings: FR 7, US 3, CA 1, PE 1, EC 1, DE 1. Ratings without text carry no case. |
| TestFlight feedback | Yes, `asc testflight feedback list` | 32 submissions, 2026-03-27 to 2026-11-14. None reports an autocorrect or prediction error in en, es or de. Five touch the keyboard at all (listed below). Screenshots were not reviewed. |
| In-app feedback (Settings → Send feedback, #565 / PR #939) | **No.** Delivered to a Telegram chat this research cannot read | Merged 2026-11-13. By git tags it shipped in TestFlight builds `build/42` (2026-11-15) and `build/43` (2026-11-17), and **not** in App Store `v2.0.1` (tag 2026-11-15). As of 2026-11-19, no issue in the tracker cites an in-app feedback message as its origin. |
| Email to the maintainer | No | One TestFlight tester (de-DE, 2026-11-07) says they sent feedback by email; its content is not in the tracker. |
| Direct German-speaking contact | Only via what reached the tracker | #152 and #165 say the maintainer has a German speaker who reports on request. One of their reports reached the tracker (#326, below). |
| Issue tracker | Yes | Most cases. Nearly all French cases come from the maintainer's own device use. |

## English

| Source | Typed / reported | What Dictus did | Expected | Category |
|---|---|---|---|---|
| App Store review, USA, 2026-11-11, 4★ | "There is no text swiping with the new keyboard" | No swipe typing | Swipe (glide) typing | swipe missing |
| App Store review, USA, 2026-11-11, 4★ | "the texting AI is kinda weird for predictive text. Doesn't feel as good as the regular one." | Predictions the reviewer found worse than Apple's; no example words given | Predictions as good as Apple's | prediction |
| App Store review, USA, 2026-11-11, 4★ | "I feel like the haptics should be a toggleable option" | Key haptics on, reviewer found no off switch | A haptics toggle | haptics / settings |
| App Store review, USA, 2026-11-11, 4★ | "the color and symbols are very slightly off!" | Key colours and symbols differ slightly from Apple's | Match the system keyboard look | key appearance |
| App Store review, USA, 2026-11-11, 4★ | "I immediately found myself switching back to the regular keyboard and probably only using Dictus' solely for the dictation" | (outcome of the four rows above) | | keyboard abandoned for typing |
| External user (GitHub), [#948](https://github.com/getdictus/dictus-ios/issues/948), 2026-11-14 | "the keyboard doesn't support swipe (glide) typing, so I keep Apple's keyboard as my default and switch to Dictus with 🌐 every time I want to dictate" | No swipe typing | Swipe typing with Dictus's autocorrect and suggestions, with an on/off toggle | swipe missing |
| TestFlight, device locale en-AU, 2026-05-24 | "when you have it accessing the keyboard, it becomes your primary keyboard, and you can't change back to the native keyboard by the looks of it" | Reporter could not find how to switch back to Apple's keyboard | Easy return to the native keyboard | keyboard switching |
| Maintainer, device use, [#272](https://github.com/getdictus/dictus-ios/issues/272), 2026-07-30 | Writing English on an AZERTY keyboard | English dictionary forced its own layout (QWERTY) | English autocorrect with the AZERTY key positions the user knows | layout / language coupling (closed) |

Not English typing cases, recorded so they are not lost:

- The same US review's opening is about dictation for a relative, not the keyboard.
- TestFlight, device locale en-US, 2026-09-29: "Could you kindly add Russian keyboard support." Filed as [#632](https://github.com/getdictus/dictus-ios/issues/632). It is a Russian request from an English-locale device.
- **Measured, not reported:** the #954 simulator bench (`docs/research/954-keyboard-baseline/README.md`, 2026-11-15) replays the same taps on both keyboards: Dictus 9 wrong words of 157 in English, Apple 0. Examples it names: `irving` for `morning`, `finish` for `my`, `bone` for `hour`, `meet` for `need`. These are synthetic taps, not a user's text.

**Count:** 1 App Store review (5 rows), 1 external GitHub issue, 1 TestFlight submission, 1 maintainer case. **No reported case gives an exact English word typed and the wrong English word Dictus produced.** The only exact English word pairs come from the bench.

## Spanish

| Source | Typed / reported | What Dictus did | Expected | Category |
|---|---|---|---|---|
| External user (GitHub), [#89](https://github.com/getdictus/dictus-ios/issues/89), 2026-04-08, TestFlight 1.4 | "I spend my day switching inbound or outbound language between french english and spanish but to change language you need to switch to the app" | No language switch on the keyboard | A language toggle on the keyboard | language switching (shipped in 1.5.0) |
| Tester, via the tracker, [#83](https://github.com/getdictus/dictus-ios/issues/83), 2026-04-08 | "Requested by a user who switches between 3 languages daily" | Spanish not available | Spanish as a language | language support (shipped). Probably the same person as #89 *(inference, same day, same three languages)* |
| Code review / analysis, [#327](https://github.com/getdictus/dictus-ios/issues/327), 2026-08-07 | Not typed by anyone. Found while fixing #321: á, í, ó, ú, ñ absent from the accent-cost table. Device check list named `mas`, `esta`, `ano`, `manana` | (engine gap, not an observed output) | Accent-aware scoring for Spanish | accents (closed) |

App Store: one 5★ rating each from Peru and Ecuador, both without text. No written review in any Spanish-speaking territory.

**Count: zero field cases of Spanish typing quality** (autocorrect, prediction, accents, ñ) from any channel. The two user reports are about language availability and switching, not about what the keyboard writes.

## German

| Source | Typed / reported | What Dictus did | Expected | Category |
|---|---|---|---|---|
| External user (GitHub), [#109](https://github.com/getdictus/dictus-ios/issues/109), 2026-04-13 | "The Keyboard and Autocorrect is not available in German. The Parakeet model works fine in German, but the Keyboard and autocorrect makes things worse." | Before German existed in Dictus, autocorrect from another language degraded typed German *(the issue says no German keyboard existed; which dictionary applied is inference)* | A German keyboard and autocorrect | autocorrect / language support (German shipped in 1.7.0, 2026-05-07) |
| Native German speaker, relayed by the maintainer, [#326 comment](https://github.com/getdictus/dictus-ios/issues/326#issuecomment-5220317485), 2026-08-07 | Umlautersatz (`fuer`, `schoen`, `koennen`) and `ss` for `ß` are spellings Germans type on purpose | Plan was to force-replace them on space | Do not fight deliberate fallback spellings | accents / umlauts. Withdrawn the same day after Apple's German keyboard was seen force-correcting the digraphs ([comment](https://github.com/getdictus/dictus-ios/issues/326#issuecomment-5221761450)); redirected to #334 |
| Maintainer, device use, [#326](https://github.com/getdictus/dictus-ios/issues/326), 2026-08-07 | `fuer`, `schoen` + space | Left as typed (`AUTOCORRECT-SKIP reason=already-valid`) | `für`, `schön` (what Apple does) | accents / umlauts (fixed, PR #330) |
| Code review / analysis, [#334](https://github.com/getdictus/dictus-ios/issues/334), 2026-08-07 | `ware`, `mochte`, `fuhren`, `lauft` + space (from a read of the curation drop list, not from typing) | Force-replaced with `wäre`, `möchte`, `führen`, `läuft` | Left alone: real words (*die Ware*, *ich mochte*, *wir fuhren*); Apple leaves `ware` and `mochte` alone (device test) | autocorrect destroys valid words (open) |
| Maintainer, device use, [#322](https://github.com/getdictus/dictus-ios/issues/322), 2026-08-07 | Shift + long-press `S` | Offered `SS`, inserted two characters | `ẞ`, as iOS does | accents / long-press (closed) |
| Code review / analysis, [#321](https://github.com/getdictus/dictus-ios/issues/321), 2026-08-07 | Flagged by CodeRabbit on the QWERTZ PR: ä, ö, ü, ß absent from the accent-cost table | Engine gap. Device validation of the fix showed `fur` → `für`, `supüe` → `Suppe`, `aöso` → `also`, `schän` → `schön` working | Umlaut-aware scoring | accents (closed) |
| TestFlight, device locale de-AT, 2026-04-15 (also copied into [#116](https://github.com/getdictus/dictus-ios/issues/116#issuecomment-4286848726)) | In Teams, tapping the text field: "the keyboard opens across the entire screen … the keys stretched across the whole screen" | Keyboard rendered full-screen, input field hidden | Normal keyboard height | layout glitch (closed, not language-specific) |
| TestFlight, device locale de-DE, 2026-11-07 | "When I use Dictus as a regular keyboard without dictation, I can type normally, receive word suggestions, and the microphone remains inactive. This works very well." | | | positive, no defect |
| TestFlight, device locale de-DE, 2026-11-09 | "I also like having the keyboard right there so I can quickly fix a misheard word." | | | positive, no defect |

App Store: one written 5★ review (DEU, 2026-11-12) says the reviewer reported "Einige Kleinigkeiten" to the developer. It does not say what they were, and nothing ties them to the keyboard.

The public collection thread [#165](https://github.com/getdictus/dictus-ios/issues/165) (German autocorrect feedback) received zero comments from 2026-05-09 to its closure on 2026-08-07.

**Count:** 1 external GitHub report, 1 relayed native-speaker opinion, 3 TestFlight submissions (1 layout bug, 2 positive), 2 maintainer device cases, 2 code-analysis findings. **No German user has reported an exact word typed and a wrong word produced.** Every exact German word pair above comes from the maintainer or from analysis.

## French (reference)

Almost all of these come from the maintainer's own daily use. That is the contrast with en, es and de: French has a steady stream of exact cases because the person who records them types French.

| Source | Typed | What Dictus did | Expected | Category |
|---|---|---|---|---|
| Maintainer, [#500](https://github.com/getdictus/dictus-ios/issues/500), 2026-09-05 | `il ma` | left as-is | `il m'a` | autocorrect, context |
| Maintainer, [#500](https://github.com/getdictus/dictus-ios/issues/500#issuecomment-5554857157), 2026-09-05 | `comment as tu troubz` | `trouve` | `trouvé` | autocorrect, context |
| Maintainer, [#500](https://github.com/getdictus/dictus-ios/issues/500#issuecomment-5819006544), 2026-09-24 | `ce que tu as dais` | left as-is | `fait` | autocorrect, context |
| Maintainer, [#500](https://github.com/getdictus/dictus-ios/issues/500#issuecomment-5978206720), 2026-10-04 | `vocaux` | `bocaux` | `vocaux` | autocorrect replaces a valid word |
| Maintainer, [#500](https://github.com/getdictus/dictus-ios/issues/500#issuecomment-5978419839), 2026-10-04 | `styke`, `styké` | `style` | `stylé` | autocorrect, accents |
| Maintainer, [#500](https://github.com/getdictus/dictus-ios/issues/500#issuecomment-5982419107), 2026-10-04 | `bien arruves` | `arrives` | `arrivés` | autocorrect, context |
| Maintainer, [#500](https://github.com/getdictus/dictus-ios/issues/500#issuecomment-6021241109), 2026-10-06 | `stylé` | `style` | `stylé` | autocorrect replaces a valid word |
| Maintainer, [#500](https://github.com/getdictus/dictus-ios/issues/500#issuecomment-6556152268), 2026-11-01 | `mok` | `m'ok` | `moi` | autocorrect, key proximity |
| Maintainer, [#500](https://github.com/getdictus/dictus-ios/issues/500#issuecomment-6967388177), 2026-11-17 | `les voczux` | `bocaux` | `vocaux` | autocorrect, frequency beats proximity |
| Maintainer, [#107](https://github.com/getdictus/dictus-ios/issues/107), 2026-04-12 | `je fais`; `Je ne sais pas qui`; `C'est`; `Cest`; `je fzsses` | `je vais`; `que`; `C'et`; `Cet`; `je casses` | unchanged; unchanged; unchanged; `c'est`; *(not stated)* | autocorrect too aggressive, apostrophes (closed) |
| Maintainer, [#113](https://github.com/getdictus/dictus-ios/issues/113), 2026-04-13 | `ccrigé`, `corrife`; `pasnmal` | `corrige`; `pascal` | `corrigé`; `pas mal` | context; glued words (closed) |
| Maintainer, [#222](https://github.com/getdictus/dictus-ios/issues/222), 2026-07-25 | `Cetait`; `J'etais` | `Était`; `Étais` | `C'était`; `J'étais` | apostrophe + accents (closed) |
| Maintainer, [#499](https://github.com/getdictus/dictus-ios/issues/499#issuecomment-6556158636), 2026-11-01 | `Jamaisvi`, `Jamaisbu` | `Jamais` (letters lost) | `Jamais vu` | glued words, missed spacebar |
| Maintainer, [#977](https://github.com/getdictus/dictus-ios/issues/977), 2026-11-19 | `… problème z` | `z` kept | `a` | key proximity, single letter |
| Maintainer, [#501](https://github.com/getdictus/dictus-ios/issues/501), 2026-09-05 | `a` where `à` is meant | never produces `à` | `à` from context, as Apple does | accents, context |
| Maintainer, [#919](https://github.com/getdictus/dictus-ios/issues/919), 2026-11-06 | An email address (first name + gmail) in a chat field | First name accented and capitalised, `gmail` → `Gmail` | Never correct inside an email or URL | autocorrect in addresses (closed) |
| Maintainer, [#872](https://github.com/getdictus/dictus-ios/issues/872), 2026-10-30 | `dictud` | `rictus`; Undo learned the typo | Retyping after a correction is a rejection; learn the final word | learning (closed) |
| Tester, via the tracker, [#872](https://github.com/getdictus/dictus-ios/issues/872), 2026-10-30 | "il comprend pas quand j'essaye d'écrire une deuxième fois un mot, il va toujours le changer" (a 2.0 beta tester who turned the keyboard off) | Re-corrects a retyped word | Keep the retyped word | learning (closed) |
| Testers, via the tracker, [#117](https://github.com/getdictus/dictus-ios/issues/117), 2026-04-14 | "Vu que le layout et la disposition des touches n'est pas tout à fait le même que celui d'Apple, j'ai du mal à taper du texte dessus et je fais beaucoup d'erreurs." ("multiple beta testers") | More typos than on Apple's keyboard | Apple key geometry | key accuracy (closed, vertical fix shipped) |
| Users, via the tracker, [#199](https://github.com/getdictus/dictus-ios/issues/199), 2026-07-05 | First names and proper nouns ("Several users complained") | Corrected into common words | Preserved | autocorrect, proper nouns (closed). Language not stated; French *(inference)* |
| External user, via the tracker, [#608](https://github.com/getdictus/dictus-ios/issues/608), 2026-09-28 | Request for HeliBoard's French QWERTZ layout with direct È/É/À, comma and period | Not offered | That layout | layout request (open) |
| Maintainer, [#114](https://github.com/getdictus/dictus-ios/issues/114#issuecomment-5552200203), 2026-09-05 | "autocorrect and prediction are not relevant enough" | | | prediction, general |

**Count:** about 30 exact cases, all but four from the maintainer. Field sources outside the maintainer: #117 (testers), #872 (one tester), #199 (users, no examples kept), #608 (one user). App Store: 5 FRA written reviews, all 5★, none about the keyboard. TestFlight fr-FR: none about autocorrect; one (2026-10-29, "Léger décalage d'ui on voit pas le début de lettres") names no surface and was not classified.

## Gaps in the register

| Language | App Store reviews | TestFlight | In-app feedback | Tracker | What would collect it |
|---|---|---|---|---|---|
| English | 1 review with keyboard content (swipe, predictions, haptics, look); no exact words | 1 keyboard-switching report; no autocorrect case | Not readable here; not in the App Store build as of 2026-11-19 | #948 (swipe), #272 (maintainer) | A reachable native English typist who records cases in the #500 format; the #954 bench for measured pairs |
| Spanish | No written review (2 ratings without text: PE, EC) | None | Not readable here | Language-switching requests only; #327 is code analysis | A named native Spanish contact; without one there is no data |
| German | 1 review, keyboard not mentioned | 1 layout glitch, 2 positive notes; no autocorrect case | Not readable here | #109 (one general complaint), #326 (one opinion), the rest from the maintainer or analysis | The direct German-speaking contact from #152, asked to record exact cases in the #500 format |
| French | 5 reviews, none about the keyboard | Nothing on autocorrect | Not readable here | #500 and ~20 other issues, mostly maintainer | Already flowing; the bias is that one person types most of it |

What does not exist today:

- **No exact word pair (typed → wrong output) from any user in en, es or de.** Every such pair in those languages comes from the maintainer, from code analysis, or from the #954 bench.
- **No Spanish typing case of any kind.**
- **In-app feedback cannot be read by an agent.** It goes to Telegram, and nothing in the tracker shows it has been triaged into issues yet. A message that names a keyboard case has to be copied into the tracker by hand (without personal details) before any agent can use it.
- **TestFlight screenshots were not reviewed.** Several submissions are mostly a screenshot (one, en-DE, 2026-11-02, has no text at all).
- **Device locale is not the typing language.** A de-DE TestFlight device may type French, and the reverse. No channel records which keyboard language was active, except the debug log when the user attaches it.
- **Public GitHub threads do not collect cases.** #165 got nothing in three months; #152 records that maintainer dogfooding and one named native contact per language are what produce findings.

What would help, from the evidence above:

1. Name one reachable native typist per language (en, es, de), as #152 already recommends, and ask them for cases in the #500 format.
2. Copy every keyboard case that arrives in the in-app feedback chat or by email into #500 or a per-language register, with the exact characters and no personal details.
3. Turn the US review's "predictive text kinda weird" into cases by measuring English next-word prediction with the #954 bench, since the reviewer gave no example words.
