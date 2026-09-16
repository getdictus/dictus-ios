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
/// on List. SMS and Summary were cut in the design session: the free polish
/// already produces natural conversational text — that is literally the ADR 0003
/// `natural` contract — so an SMS mode would be the one paid mode whose output is
/// indistinguishable from the free one, and List already synthesises.
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
        overflowBehaviour: .insertRawText
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
            outputMarker: SmartModeStructuredPrompt.outputMarker
        ),
        contract: PolishAcceptanceContract(
            minimumLengthRatio: 0.4,
            maximumLengthRatio: 1.5,
            outputLanguage: .sameAsInput,
            requiresGroundedNames: true,
            requiresAlignedPrefix: false
        ),
        // The mode armed for the longest dictations is the one that meets the context
        // ceiling first — sooner than `List`, because its prompt is longer. The floor
        // is the speaker's own words, unstructured: plainer than what they asked for,
        // and never wrong. Same reasoning `List` carries (#270).
        overflowBehaviour: .insertRawText
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
            // Translation cannot degrade: the floor is the input language, which is
            // the one thing this mode exists to change. Inserting it would be the
            // failure #79 names as the worst available.
            overflowBehaviour: .insertNothing
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
    public static let builtIns: [SmartMode] =
        [structured, notes] + SupportedLanguage.allCases.map { translate(to: $0) }

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
