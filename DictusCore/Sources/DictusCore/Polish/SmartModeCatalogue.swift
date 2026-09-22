// DictusCore/Sources/DictusCore/Polish/SmartModeCatalogue.swift
// The Smart Modes this build ships (issue #79).
import Foundation

/// The catalogue of Smart Modes.
///
/// ### v1 ships two families, and Email is not one of them
///
/// **List** moves the text along the structure axis, **Translate → X** along the
/// language axis. **Structured** joined the structure axis in #523, with a licence
/// neither of the other two carries: it rewrites the speaker's sentences rather than
/// reshaping them, which is why it is a row of its own rather than a rendering option
/// on List. Summary was cut in the design session because List already synthesises;
/// #571 reopens that on the grounds that List synthesises into *actions*.
///
/// **SMS was cut in that same session, and #572 falsified the reason.** The cut read:
/// the free polish already produces natural conversational text — that is literally
/// the ADR 0003 `natural` contract — so an SMS mode would be the one paid mode whose
/// output is indistinguishable from the free one. The premise is that the free polish
/// produces something sendable, and **four months in which the maintainer sent no
/// message at all with Dictus is the measurement that says otherwise**: ADR 0003
/// forbids removing a repetition, removing a filler and substituting a synonym, so by
/// construction it produces clean speech, which is not written register. `Message`
/// ships as that row, on a third axis — not structure, not language, but **register**
/// — and with the one licence nothing else here carries: it may delete.
///
/// **Email is conditional and absent from this build.** Two independent
/// implementations fail the same way — they invent greetings and sign-offs the user
/// never dictated, with names the model cannot know — and #79 makes Email's
/// inclusion conditional on the harness showing it can change register and structure
/// while inventing neither. That validation is separate work. When it passes, Email
/// is a row in `builtIns` and a prompt file; nothing else has to move.
///
/// ### The list is data
///
/// Built-in rows are constructed here rather than persisted, so a prompt fix ships
/// with the binary instead of being frozen on every device that ever armed the mode.
/// What persists is the user's part: which mode is armed, and which are pinned
/// (`SmartModeStore`). Custom modes (#269) become a second source merged into `all`.
public enum SmartModeCatalogue {

    // MARK: - Identifiers

    /// Identifier of the bullet mode, displayed as "List" / "Liste" since
    /// 2026-08-27. Stable — it is the session-cache key component and what a metrics
    /// event records, so the rename deliberately did **not** touch it: no persisted
    /// armed mode is invalidated and no pinned order is lost.
    public static let notesIdentifier = "notes"

    /// Identifier of the long-form mode, displayed as "Structured" / "Structuré"
    /// (#523). A wire value from the day it ships, for the reason above: it keys the
    /// session cache, the metrics event and the per-dictation App Group snapshot.
    public static let structuredIdentifier = "structured"

    /// Identifier of the register mode, displayed as "Message" (#572). A wire value
    /// from the day it ships, for the reason above: it keys the session cache, the
    /// metrics event and the per-dictation App Group snapshot.
    public static let messageIdentifier = "message"

    /// Identifier of the gist mode, displayed as "Summary" / "Résumé" (#571). A wire
    /// value from the day it ships, for the reason above: it keys the session cache,
    /// the metrics event and the per-dictation App Group snapshot.
    public static let summaryIdentifier = "summary"

    /// Identifier of the Translate mode targeting `language`.
    public static func translateIdentifier(target: SupportedLanguage) -> String {
        "translate.\(target.rawValue)"
    }

    // MARK: - The rows

    /// List: bullets, synthesised, filler removed, in the speaker's own language.
    ///
    /// **Named `Notes` until 2026-08-27**, when the maintainer renamed the label —
    /// and only the label. `Notes` names an intention and reads equally well as
    /// "well formatted long dictation", which is the behaviour #437 is investigating
    /// for *Normal* polish and which this mode deliberately is not. `List` names the
    /// output shape: a user reading it in the fan knows what will land in their
    /// document. It also under-promises rather than over-promises, which matters in
    /// the space where #414 lives.
    ///
    /// English here because DictusCore ships no string catalog — the same rule
    /// `SmartModeUnavailableReason.englishDescription` states. The surfaces localise
    /// it, keyed on the identifier; see `SmartModeDisplayName.swift` in each UI
    /// target.
    ///
    /// The `0.1` floor is what makes this mode possible at all: the ADR 0003 band
    /// starts at `0.5`, and a good three-bullet synthesis of a two-minute dictation
    /// is nowhere near half the input's length. It is a judgement call sized against
    /// what the transformation does, not a measurement — the first thing to revisit
    /// if the harness shows the mode rejecting its own good output.
    public static let notes = SmartMode(
        id: notesIdentifier,
        displayName: "List",
        icon: "list.bullet",
        prompt: SmartModePrompt(
            instructions: SmartModeNotesPrompt.instructions(),
            userInstruction: SmartModeNotesPrompt.userInstruction,
            outputMarker: SmartModeNotesPrompt.outputMarker
        ),
        contract: PolishAcceptanceContract(
            minimumLengthRatio: 0.1,
            maximumLengthRatio: 2.0,
            outputLanguage: .sameAsInput,
            // The mode #414 was found on. Its prompt carries a worked example whose
            // bullet — `- Appeler Sophie avant : elle a les données de décembre` —
            // reached an accepted output on a dictation naming neither Sophie nor
            // December. Every prompt in the repo carries examples, so this is the
            // mode where the check earns its keep first, not only.
            requiresGroundedNames: true,
            // This mode's whole job is to restructure. It condenses a rambling
            // dictation into bullets that synthesise, so the first bullet need not
            // come from the first sentence and the prefix check (#466) would be
            // measuring something the mode is licensed to break.
            requiresAlignedPrefix: false
        ),
        // The mode built for a long rambling dictation is the one that walks users
        // into the context ceiling, so a refusal there costs the whole text. The
        // floor is the same words in the same language, merely not restructured.
        // Since #580 the same answer covers a guardrail rejection, which discards the
        // engine's output whole and so cannot put a half-transformation in the field.
        floorBehaviour: .insertRawText
    )

    /// Structured: the long vocal message, rewritten as paragraphs that do not read
    /// as though they were dictated (#523).
    ///
    /// ### Why this is a fourth mode and not `List` rendered as prose
    ///
    /// The two differ by **licence**, not by shape. `SmartModeNotesPrompt` keeps the
    /// speaker's words — *"Do not substitute synonyms"*, *"Keep every fact, number,
    /// date, name and decision exactly as spoken"* — and restructures them into
    /// bullets. This mode rewrites them, which is the whole product and which no
    /// other contract in this repo allows. #437 closed on the measurement that makes
    /// the licence necessary: under a contract that forbids rewriting, Apple FM
    /// cannot place a paragraph break at all.
    ///
    /// The rule that keeps the two apart on the input where they would otherwise
    /// collapse is in the prompt, not here: Structured keeps the speaker's
    /// grammatical person, where `List` produces infinitive tasks. See
    /// `SmartModeStructuredPrompt`.
    ///
    /// ### The band is measured, unusually for this file
    ///
    /// `PolishAcceptanceContract` warns that these bands are judgement calls. This
    /// one is not. The six paired dictations of 2026-08-27 (#437) put the reference
    /// competitor's output at 0.98, 0.93, 1.00, 0.94, **0.57** and 0.87 of its
    /// input's length — median 0.93, and materially shorter only on the pure ramble.
    /// **Structured is not a summarising mode.** The floor clears the worst measured
    /// case with margin; the ceiling is there for runaway generation, which is the
    /// only thing a band catches (PR #388: 0 rejections in 240 calls).
    ///
    /// Grounded, because this mode rewrites in the speaker's own language and the
    /// licence it carries is to reformulate, never to add: rewriting *what was said*
    /// is the product, putting a date or a name in the speaker's mouth is the defect
    /// #414 exists to catch. The prefix check is off for the reason `List` has it
    /// off and then some — the mode may promote its opening words into a heading,
    /// which is precisely a rewritten head (#466).
    public static let structured = SmartMode(
        id: structuredIdentifier,
        displayName: "Structured",
        icon: "text.alignleft",
        prompt: SmartModePrompt(
            instructions: SmartModeStructuredPrompt.instructions(),
            userInstruction: SmartModeStructuredPrompt.userInstruction,
            outputMarker: SmartModeStructuredPrompt.outputMarker,
            // One example set per Apple FM language (#587, decision 5 step 2). Benched
            // at 0 % refused on `check=language` in all 16, against up to 29 % for the
            // prompt this replaces; the rules stay one English text.
            localizedInstructions: SmartModeStructuredPrompt.localizedInstructions()
        ),
        contract: PolishAcceptanceContract(
            minimumLengthRatio: 0.4,
            maximumLengthRatio: 1.5,
            outputLanguage: .sameAsInput,
            requiresGroundedNames: true,
            requiresAlignedPrefix: false,
            // The one mode that keeps a speaker-flagged incompleteness as a hard bar
            // (#523, decision 7), and the one the device caught inventing one: seven
            // outputs closing on a sentence about the speaker's memory, three of them
            // inserted (#581). Rule 7 stays; this refuses the sentence when the
            // transcript never said it (#587, decision 6). See `PolishIncompleteness`.
            refusesFabricatedIncompleteness: true
        ),
        // The mode armed for the longest dictations is the one that meets the context
        // ceiling first — sooner than `List`, because its prompt is longer. The floor
        // is the speaker's own words, unstructured: plainer than what they asked for,
        // and never wrong. Same reasoning `List` carries (#270).
        //
        // This mode is also the one #580 measured being refused by a guardrail — three
        // times in nine device runs, one of them 1,337 characters — and the sentence
        // above is already the answer to that: the words are the speaker's either way.
        floorBehaviour: .insertRawText
    )

    /// Message: what the speaker would have typed, rather than a clean copy of what
    /// they said (#572).
    ///
    /// ### The axis, and why this is not `Structured` for short input
    ///
    /// The two differ by **licence**, not by length. `Structured` rewrites sentences
    /// and is forbidden from cutting substance — its prompt says *do not summarise*
    /// and its floor is 0.4, sized from a measured reference that runs 0.57…1.00 of
    /// its input. This mode rewrites **and deletes**: a restated sentence keeps only
    /// its better version, a spoken self-correction loses the correcting, an aside
    /// that would never have been typed goes. #523 was written around exactly that
    /// licence and its grilling took it away, which is what left it unclaimed.
    ///
    /// ### The band is `0.2 … 1.1`, and the ceiling is an AMENDMENT to decision 3
    ///
    /// The floor is decision 3 unchanged: the widest in the repo, and the only thing
    /// bounding the deletion licence — `List` floors at 0.1, but `List` may not
    /// rewrite a word, so its floor buys structure rather than silence.
    ///
    /// **The ceiling was decided at 1.0 and ships at 1.1, because 1.0 refuses
    /// decision 6.** Decision 3's reason is a licence — *a message is never longer
    /// than what was said* — and the guardrail's ratio is
    /// `polished.count / raw.count`, which counts the blank lines decision 6 puts
    /// between blocks. Measured on the shipping prompt, 32 outputs over the four
    /// fixtures of `docs/research/572-message/corpus.json`:
    ///
    /// | | in blocks | one paragraph |
    /// |---|---|---|
    /// | **Refused on `check=length`** | **10** | 1 |
    /// | Accepted | 2 | 19 |
    ///
    /// Every refusal in that run was `check=length`, and every one of them was an
    /// output that had done what the mode exists to do. A blank line costs one
    /// character against the space it replaces, so a short message laid out in
    /// blocks measures 1.01 to 1.05 of its own transcript while containing no word
    /// the speaker did not say. **A ceiling of 1.00 therefore selects almost
    /// perfectly against the mode's own output shape**, and a refusal never gives
    /// the message back: the user would get either a paragraph — which is what
    /// Normal already produces, #393's bar B — or, since #580, the raw transcript
    /// that `floorBehaviour` inserts in its place.
    ///
    /// 1.1 is the smallest value that clears the worst measured legitimate case
    /// (1.05) with margin. It still refuses expansion in any sense decision 3 meant:
    /// no mode here has a tighter ceiling, and the runaway shape a band exists to
    /// catch is nowhere near it.
    ///
    /// **This is the one place this implementation departs from a locked decision,
    /// and it is one line.** Restoring 1.00 means editing this number and the
    /// matching assertion in `SmartModeCatalogueTests`; the measurement above is
    /// what it would be traded against. The two runs are committed side by side:
    /// `docs/research/572-message/runs/shipping-prompt-ceiling-1.00-32runs.txt` and
    /// `…-1.10-32runs.txt`, same prompt, same fixtures, 21 of 32 accepted against 32.
    ///
    /// Grounded, for the reason `Structured` is: the mode rewrites in the speaker's
    /// own language and may add nothing, so a name in the output that is absent from
    /// the input is the #414 defect and not a translation artefact. The prefix check
    /// is off because this mode **may drop the opening entirely** — that is rule 3,
    /// and #466's check would be measuring a licence rather than a defect.
    public static let message = SmartMode(
        id: messageIdentifier,
        displayName: "Message",
        icon: "bubble.left",
        prompt: SmartModePrompt(
            instructions: SmartModeMessagePrompt.instructions(),
            userInstruction: SmartModeMessagePrompt.userInstruction,
            outputMarker: SmartModeMessagePrompt.outputMarker,
            // A short message keeps its beats on separate lines without the blank
            // line between them — the maintainer's own choice on device, 2026-09-18.
            // See `SmartModePrompt.shortOutputBlockLimit`.
            shortOutputBlockLimit: 100
        ),
        contract: PolishAcceptanceContract(
            minimumLengthRatio: 0.2,
            // 1.1 rather than decision 3's 1.0 — see the doc comment: 1.00 refused
            // 10 of the 12 blocked outputs in a 32-output run, on the blank lines
            // decision 6 requires.
            maximumLengthRatio: 1.1,
            outputLanguage: .sameAsInput,
            requiresGroundedNames: true,
            requiresAlignedPrefix: false,
            // The one contract in the catalogue that moves this, and #572 round 2 is
            // why: at the measured default of 3 content words, every short message
            // this mode exists to serve is skipped untested, and two fabrications went
            // through on 2026-09-17 — one that answered the dictated question, one that
            // replaced a farewell with its opposite. `floor` is untouched at the
            // measured 0.15; only which segments get read changes.
            segmentOverlapThresholds: PolishSegmentOverlapThresholds(
                floor: PolishSegmentOverlapThresholds.default.floor, minimumContentWords: 1
            )
        ),
        // The one mode here whose input is short by construction — what you send to
        // a person — and its context ceiling sits at ≈ 4 032 characters of speech
        // (see `SmartModeMessagePrompt`), so the overflow branch is close to
        // unreachable. That was the whole of this answer until #580.
        //
        // The branch #580 added is not unreachable at all, and it is the one this
        // mode wants most: a guardrail rejection. The contract above runs the
        // grounding check on short input the measured default skips, and
        // `check=length` refused 10 of 32 outputs one notch of ceiling away from the
        // shipped one. A refused message now puts the speaker's own words in the
        // field instead of nothing — plainer than what they asked for, in their own
        // language, and never *wrong* (#270), which is the answer the other two
        // structure modes already give.
        floorBehaviour: .insertRawText
    )

    /// Summary: the gist of a dictation, in prose, in the speaker's person (#571).
    ///
    /// ### The axis, and why this is not `List` without bullets
    ///
    /// The #79 design session cut Summary because *List already synthesises*. True
    /// of the axis, not of the shape: `List` compresses into **actions**, as
    /// infinitive bullets, and a dictation with no action in it gets bullets invented
    /// out of statements. This row compresses into **substance**, as prose, and the
    /// difference is visible in one glance — #393's bar B, the one Email failed.
    ///
    /// ### The band is `0.1 … 0.75`: decision 1's shape, its ceiling raised once
    ///
    /// A band and never a sentence count, proportional to what was said. The floor is
    /// `List`'s, the mode that compresses comparably.
    ///
    /// **The ceiling was 0.6 and is 0.75 since the device round of 2026-09-22**,
    /// approved by the maintainer. That round measured the phone condensing long
    /// dictations to 0.36 and 0.44, far below the Mac's 0.6 to 0.85, and refusing a
    /// good one: a 263-character, three-sentence dictation carrying two negations,
    /// condensed to about 0.72 with both negations kept. A short dense dictation has
    /// little to drop, and 0.6 read that as a failure. 0.75 still refuses a text that
    /// keeps three quarters of its input, which is not what the user who armed this
    /// mode asked for; whether it stays visibly different from Normal (#393 bar B) is
    /// re-measured in `docs/research/571-summary/bars.md` §8.
    ///
    /// **A very short dictation lands on the floor by construction.** The gist of a
    /// one-line dictation is the line, and no faithful rewrite of it is 75 % of its
    /// length. That is the contract working, not a defect: the speaker's own words go
    /// in, which is the answer the other same-language modes give.
    ///
    /// Grounded, for the reason every same-language mode is: condensing is the
    /// licence, adding a figure or a name is the #414 defect. The prefix check is off
    /// because a gist may open on any sentence of the input (#466).
    public static let summary = SmartMode(
        id: summaryIdentifier,
        displayName: "Summary",
        // `text.quote` and not `text.line.3.summary`: the second is an SF Symbols 2025
        // glyph, iOS 26 only, and the mode list is shown on every iOS a Pro user runs
        // (`SettingsView` does not gate it on device capability), so it would draw an
        // empty slot on iOS 17 to 25.
        icon: "text.quote",
        prompt: SmartModePrompt(
            instructions: SmartModeSummaryPrompt.instructions(),
            userInstruction: SmartModeSummaryPrompt.userInstruction,
            outputMarker: SmartModeSummaryPrompt.outputMarker,
            // Step 2 of #587 decision 5 (round 2, 2026-09-22): the examples in the
            // transcript's own language, one prompt per Apple FM language. The
            // `instructions` above is the step-1 fallback. See
            // `SmartModeSummaryExamples` for the measurement behind it.
            localizedInstructions: SmartModeSummaryPrompt.localizedInstructions()
        ),
        contract: PolishAcceptanceContract(
            minimumLengthRatio: 0.1,
            // 0.75 since round 2 (2026-09-22), not decision 1's 0.6: see the doc
            // comment above.
            maximumLengthRatio: 0.75,
            outputLanguage: .sameAsInput,
            requiresGroundedNames: true,
            requiresAlignedPrefix: false
        ),
        // The mode armed for the longest dictations after `Structured`, so it meets
        // the context ceiling and the band's ceiling more than most. Either way the
        // floor is the speaker's own words in their own language: longer than asked
        // for, and never wrong (#270, #580).
        floorBehaviour: .insertRawText
    )

    /// Translate → `target`.
    ///
    /// The band is wide on both sides because translation legitimately changes
    /// length by a lot in either direction — German compounds against English, a
    /// French circumlocution against a Spanish verb — and the check that actually
    /// guards this mode is the language one, not the length one.
    public static func translate(to target: SupportedLanguage) -> SmartMode {
        SmartMode(
            id: translateIdentifier(target: target),
            // Deliberately language-neutral, so one string works in every UI locale
            // and fits a 46 pt fan row. A longer, localised label is the app's to
            // render from the identifier if it wants one.
            displayName: "\u{2192} \(target.shortCode)",
            icon: "globe",
            // The pill badge says "EN", not a globe: a globe cannot tell → EN from
            // → ES, and pinning both is the whole point of pinning three modes.
            badge: .text(target.shortCode),
            prompt: SmartModePrompt(
                instructions: SmartModeTranslatePrompt.instructions(target: target),
                userInstruction: SmartModeTranslatePrompt.userInstruction(target: target),
                outputMarker: SmartModeTranslatePrompt.outputMarker
            ),
            contract: PolishAcceptanceContract(
                minimumLengthRatio: 0.4,
                maximumLengthRatio: 3.0,
                outputLanguage: .fixed(target),
                // A translation localises names: `Londres` becomes `London`,
                // `mars` becomes `March`. Surface identity between output and input
                // is not expected here, so the grounding check would be measuring
                // the wrong thing rather than measuring nothing.
                requiresGroundedNames: false,
                // Same reason, sharper: a translation keeps none of the input's
                // words, so there is no lexical overlap to find at the head or
                // anywhere else (#466).
                requiresAlignedPrefix: false
            ),
            // Translation cannot degrade, for any refusal: the floor is the input
            // language, which is the one thing this mode exists to change. Inserting
            // it would be the failure #79 names as the worst available. #580 widened
            // which outcomes ask this question; it did not change this answer.
            floorBehaviour: .insertNothing
        )
    }

    /// Every mode this build defines, in catalogue order, with no pin state applied.
    ///
    /// Translation targets are the four tested languages — the same set explicit
    /// transcription and the per-language polish prompts are limited to. They are
    /// **not** filtered by the keyboard language: the spoken language is unknown
    /// until the user speaks, so "→ FR" stays offerable on a French keyboard.
    ///
    /// Structured leads the structure-axis pair because it is the mode the
    /// maintainer ranks first for his own use (#523), and this order is what the
    /// app's mode list draws.
    ///
    /// `Message` follows that pair rather than opening the list, even though #572
    /// carries the strongest evidence of the three: the order here groups by axis —
    /// structure, then register, then language — and moving a row to the top would
    /// rearrange a settings list every existing user has already read, which is not
    /// something #572 asked for. **It is deliberately not in
    /// `defaultPinnedIdentifiers` either**: the fan holds three, the seed is full,
    /// and dropping one of the three shipped modes out of a non-subscriber's promise
    /// is a product decision this issue did not take. A user reaches `Message` by
    /// pinning it in the app, like any fourth mode.
    ///
    /// `Summary` (#571) follows `Message` on the same two grounds: appended rather
    /// than inserted, so no row a user has already read moves, and not in the seed,
    /// which is still full.
    public static let builtIns: [SmartMode] =
        [structured, notes, message, summary] + SupportedLanguage.allCases.map { translate(to: $0) }

    /// Every mode, with the user's pin state stamped on each row.
    public static var all: [SmartMode] {
        let pinned = Set(SmartModeStore.pinnedIdentifiers)
        return builtIns.map { $0.pinned(pinned.contains($0.id)) }
    }

    /// The mode with this identifier, or nil when the identifier belongs to no mode
    /// this build ships — an install downgraded from a build with more modes, or a
    /// corrupted value. Nil means Normal, which is the safe answer: the dictation
    /// gets the free polish instead of a transformation nobody can resolve.
    public static func mode(withIdentifier identifier: String) -> SmartMode? {
        all.first { $0.id == identifier }
    }

    /// The modes the user pinned, **in the order they pinned them**, capped at
    /// `maximumPinnedModes`.
    ///
    /// WHY this maps the stored list rather than filtering the catalogue (found
    /// reviewing PR #389): `SmartModeStore.setPinned` states that the order is the
    /// user's and is preserved, and `pinnedIdentifiers` honours it — but filtering
    /// `all` returns catalogue order, so the two disagreed. Pinning
    /// `["translate.de", "notes"]` produced `[notes, translate.de]` here. Block B
    /// builds the long-press fan from this property, so the divergence would have
    /// shipped as a fan that ignores the order the user arranged.
    ///
    /// `compactMap` drops an identifier that belongs to no mode this build ships,
    /// for the same reason `mode(withIdentifier:)` returns nil: a downgrade or a
    /// corrupted value should cost that one entry, not the whole fan.
    public static var pinnedModes: [SmartMode] {
        Array(SmartModeStore.pinnedIdentifiers.compactMap(mode(withIdentifier:)).prefix(maximumPinnedModes))
    }

    /// How many modes may be pinned to the keyboard's long-press fan.
    ///
    /// **Three, settled in block B on 2026-08-24.** #79 contradicted itself here —
    /// its acceptance criterion said "up to four modes are pinnable", its geometry
    /// paragraph measured four *entries* including Normal, which is three modes —
    /// and block A followed the criterion pending a real fan on a real screen.
    ///
    /// The geometry paragraph won because it is a measurement and the criterion was
    /// a guess. From the real `KeyMetrics` values, per fan row:
    ///
    /// | Entries | standard iPhone (205 pt) | iPhone SE (187 pt) |
    /// |---|---|---|
    /// | 4 (Normal + 3 modes) | 51.2 pt | 46.7 pt |
    /// | 5 (Normal + 4 modes) | 41.0 pt | 37.4 pt |
    ///
    /// Five entries puts the SE row at 37.4 pt, under Apple's 44 pt minimum — and
    /// this target is not a tap on a visible button but a blind release at the end
    /// of a downward drag, under the thumb that is covering the row. Four clears
    /// the minimum on the smallest supported screen.
    ///
    /// Normal has to be one of the four: releasing back on the mic aborts the
    /// gesture, so it is not the way to clear a sticky mode. See
    /// `SmartModeFanLayout`, which owns the arithmetic above.
    ///
    /// A device-dependent cap was considered and rejected: it would make one
    /// setting in the app mean two different things on two phones.
    public static let maximumPinnedModes = 3

    /// What a fresh install has pinned before the user has ever opened the mode list.
    ///
    /// A seed, not a rule: the moment the user pins anything, `SmartModeStore` holds
    /// their list and this stops being consulted.
    ///
    /// **Three since #523**, filling the fan: Structured first because it is the mode
    /// the maintainer arms for the dictations he cares most about, then List, then
    /// "→ EN" — List and "→ EN" being the pair that demonstrates the two axes the
    /// catalogue moves text along. The third slot was free, so nothing was sacrificed
    /// to make room. Whether Structured later *replaces* List in the seed is
    /// deliberately deferred to the maintainer's verdict after living with it; #523
    /// does not reopen List.
    ///
    /// One surface reads this list and cannot show all of it: the **upgrade fan**
    /// (#404) has two mode slots, since Normal and Dictus Pro take one each, so a
    /// non-subscriber now sees Structured and List where they used to see List and
    /// "→ EN". `SmartModeFanLayout.entries` takes the first two, which keeps the fan
    /// an exact promise of what the user would get pinned — it is simply no longer
    /// the whole of it, and the language axis is what falls off the bottom.
    public static let defaultPinnedIdentifiers = [
        structuredIdentifier,
        notesIdentifier,
        translateIdentifier(target: .english)
    ]

    /// The seed above as records, in its own order.
    ///
    /// What the **non-subscriber's** fan shows (#404): since the Dictus Pro row takes a
    /// slot of the four, two mode rows remain, and showing the modes the user would get
    /// pinned on subscribing makes the fan an exact promise rather than a sample. It is
    /// deliberately the seed and not `pinnedModes` — a non-subscriber cannot reach the
    /// mode list to arrange anything, so their stored list is this one anyway, and
    /// reading it through the store would make the promise depend on a value nobody in
    /// that state can have set.
    ///
    /// Resolved through `builtIns` rather than `all`, so it needs no `UserDefaults` read
    /// and stamps no pin flag: nothing in the fan reads that flag.
    public static var defaultPinnedModes: [SmartMode] {
        defaultPinnedIdentifiers.compactMap { identifier in
            builtIns.first { $0.id == identifier }
        }
    }
}
