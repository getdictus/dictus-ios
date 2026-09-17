// DictusCore/Tests/DictusCoreTests/Polish/SmartModeCatalogueTests.swift
// The Smart Mode catalogue and the record type it is made of (issue #79).
import XCTest
@testable import DictusCore

final class SmartModeCatalogueTests: XCTestCase {

    // MARK: - The rows

    func testCatalogueShipsNotesAndOneTranslateEntryPerSupportedLanguage() {
        XCTAssertEqual(SmartModeCatalogue.builtIns.count, 3 + SupportedLanguage.allCases.count)
        XCTAssertTrue(SmartModeCatalogue.builtIns.contains { $0.id == "notes" })
        XCTAssertTrue(SmartModeCatalogue.builtIns.contains { $0.id == "structured" })
        XCTAssertTrue(SmartModeCatalogue.builtIns.contains { $0.id == "message" })
        for language in SupportedLanguage.allCases {
            XCTAssertTrue(
                SmartModeCatalogue.builtIns.contains { $0.id == "translate.\(language.rawValue)" },
                "no translate entry for \(language.rawValue)"
            )
        }
    }

    /// Email is conditional on harness validation and does not ship in this build.
    /// The assertion is here so that adding it is a deliberate act rather than a
    /// drive-by.
    func testEmailDoesNotShip() {
        XCTAssertFalse(SmartModeCatalogue.builtIns.contains { $0.id.contains("email") })
    }

    func testIdentifiersAreUnique() {
        let ids = SmartModeCatalogue.builtIns.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEveryModeHasANameAnIconAndAPrompt() {
        for mode in SmartModeCatalogue.builtIns {
            XCTAssertFalse(mode.displayName.isEmpty, mode.id)
            XCTAssertFalse(mode.icon.isEmpty, mode.id)
            XCTAssertFalse(mode.prompt.instructions.isEmpty, mode.id)
            XCTAssertFalse(mode.prompt.userInstruction.isEmpty, mode.id)
            XCTAssertFalse(mode.prompt.outputMarker.isEmpty, mode.id)
        }
    }

    /// Translation targets are not filtered by keyboard language: the spoken
    /// language is unknown until the user speaks, so every target is always offered.
    func testTranslationTargetsAreNotFilteredByKeyboardLanguage() {
        AppGroup.defaults.set(SupportedLanguage.french.rawValue, forKey: SharedKeys.language)
        defer { AppGroup.defaults.removeObject(forKey: SharedKeys.language) }
        XCTAssertNotNil(SmartModeCatalogue.mode(withIdentifier: "translate.fr"))
    }

    // MARK: - Contracts

    /// The whole reason a mode carries its own contract: the ADR 0003 band starts at
    /// 0.5 and Notes condenses well below that.
    func testNotesWidensTheLengthFloorBelowTheFaithfulPolishBand() {
        let notes = SmartModeCatalogue.notes.contract
        XCTAssertLessThan(notes.minimumLengthRatio, PolishAcceptanceContract.natural.minimumLengthRatio)
        XCTAssertEqual(notes.outputLanguage, .sameAsInput)
    }

    func testEachTranslateModeExpectsItsOwnTargetLanguage() {
        for language in SupportedLanguage.allCases {
            let mode = SmartModeCatalogue.translate(to: language)
            XCTAssertEqual(mode.contract.outputLanguage, .fixed(language))
        }
    }

    /// The translate prompt names its target in English, and only its target: a
    /// prompt that named two languages would be one the model could choose between.
    func testTranslatePromptNamesItsTarget() {
        let english = SmartModeCatalogue.translate(to: .english)
        XCTAssertTrue(english.prompt.instructions.contains("English"))
        XCTAssertTrue(english.prompt.userInstruction.contains("English"))
        let german = SmartModeCatalogue.translate(to: .german)
        XCTAssertTrue(german.prompt.instructions.contains("German"))
        XCTAssertFalse(german.prompt.userInstruction.contains("English"))
    }

    /// One English-written prompt per mode, instructing the model to answer in the
    /// language of the input — the #239 pattern, not one prompt per language.
    func testNotesPromptIsWrittenOnceAndKeepsTheInputLanguage() {
        let instructions = SmartModeCatalogue.notes.prompt.instructions
        XCTAssertTrue(instructions.contains("OUTPUT LANGUAGE: the language of the input"))
        XCTAssertTrue(instructions.contains("NEVER translate"))
    }

    /// The one rule Translate exists to hold, checked where a model actually reads
    /// it: in the worked examples, not in the prose.
    ///
    /// The example block used to be constant while the target varied, so the
    /// "→ English" instructions demonstrated an English input producing a French
    /// output — the rule being broken, in context, inside the prompt meant to
    /// enforce it. Found reviewing PR #389.
    func testTranslateExamplesOnlyEverOutputTheTargetLanguage() {
        // The counter-example's RIGHT output, one per language. Literals rather
        // than a call into the prompt's own helpers: a test that asks the code
        // under test what it should say cannot catch the code saying it in the
        // wrong language.
        let rightOutputs: [SupportedLanguage: String] = [
            .french: "Je peux pas venir ce soir, désolé.",
            .english: "I can't come tonight, sorry.",
            .spanish: "No puedo ir esta noche, lo siento.",
            .german: "Ich kann heute Abend nicht kommen, sorry."
        ]

        for target in SupportedLanguage.allCases {
            let instructions = SmartModeCatalogue.translate(to: target).prompt.instructions

            guard let expected = rightOutputs[target] else {
                XCTFail("No expected RIGHT output recorded for \(target)")
                continue
            }
            XCTAssertTrue(
                instructions.contains(expected),
                "The \(target) prompt does not show its own language in the RIGHT example"
            )

            for (language, output) in rightOutputs where language != target {
                XCTAssertFalse(
                    instructions.contains(output),
                    "The \(target) prompt demonstrates a \(language) output"
                )
            }

            // And the inputs are never already in the target: an example whose
            // input needs no translation demonstrates rule 8, not translation.
            XCTAssertFalse(
                instructions.contains("INPUT: \(expected)"),
                "The \(target) prompt uses a \(target) input, which needs no translating"
            )
        }
    }

    // MARK: - The record travels

    func testRecordSurvivesAJSONRoundTrip() throws {
        let original = SmartModeCatalogue.translate(to: .spanish).pinned(true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SmartMode.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.contract.outputLanguage, .fixed(.spanish))
        XCTAssertTrue(decoded.isPinned)
    }

    func testOutputLanguageEncodesAsAFlatMarker() throws {
        func encoded(_ value: PolishOutputLanguage) throws -> String {
            String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        }
        XCTAssertEqual(try encoded(.polishTarget), "\"polishTarget\"")
        XCTAssertEqual(try encoded(.sameAsInput), "\"sameAsInput\"")
        XCTAssertEqual(try encoded(.fixed(.german)), "\"de\"")
    }

    func testUnrecognisedOutputLanguageThrowsRatherThanGuessing() {
        XCTAssertThrowsError(try PolishOutputLanguage(storedValue: "klingon"))
    }

    func testUnknownIdentifierResolvesToNoMode() {
        XCTAssertNil(SmartModeCatalogue.mode(withIdentifier: "translate.klingon"))
        XCTAssertNil(SmartModeCatalogue.mode(withIdentifier: ""))
    }

    // MARK: - The pill badge

    /// A glyph names Notes. It cannot name a *target*, so every Translate row wears
    /// its own language code — this is the assertion that fails the day someone gives
    /// Translate a shared badge again and → EN and → ES become the same mark.
    func testEveryTranslateModeCarriesItsOwnTargetCodeOnTheBadge() {
        for language in SupportedLanguage.allCases {
            let mode = SmartModeCatalogue.translate(to: language)
            XCTAssertEqual(mode.badge, .text(language.shortCode), "wrong badge for \(language.rawValue)")
            XCTAssertEqual(mode.icon, "globe", "the fan row still uses the glyph")
        }

        let badges = SupportedLanguage.allCases.map { SmartModeCatalogue.translate(to: $0).badge }
        XCTAssertEqual(Set(badges.map(String.init(describing:))).count, badges.count)
    }

    func testNotesKeepsItsGlyphOnTheBadge() {
        XCTAssertEqual(SmartModeCatalogue.notes.badge, .symbol("list.bullet"))
    }

    /// A mode written by an older build has no badge key. It must decode to the glyph
    /// that build drew rather than throwing — `KeyboardPolishCoordinator` turns a
    /// throw here into "no mode armed", which for a translation inserts the
    /// untranslated text.
    func testABadgelessRecordDecodesToItsIcon() throws {
        let encoded = try JSONEncoder().encode(SmartModeCatalogue.notes)
        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        json.removeValue(forKey: "badge")

        let decoded = try JSONDecoder().decode(
            SmartMode.self, from: JSONSerialization.data(withJSONObject: json)
        )
        XCTAssertEqual(decoded.badge, .symbol("list.bullet"))
    }

    // MARK: - The 2026-08-27 rename

    /// Display name only. The identifier is the session-cache key, what a metrics
    /// event records, and what every persisted armed mode and pinned list refers to
    /// — renaming it would invalidate all three on every device that ever armed the
    /// mode, for a label change.
    func testTheBulletModeKeepsItsIdentifierAfterTheRename() {
        XCTAssertEqual(SmartModeCatalogue.notesIdentifier, "notes")
        XCTAssertEqual(SmartModeCatalogue.notes.id, "notes")
        XCTAssertEqual(SmartModeCatalogue.mode(withIdentifier: "notes")?.id, "notes")
    }

    /// English here, because DictusCore ships no string catalog and its strings are
    /// the log form and the fallback. "Liste" is the surfaces' business.
    func testTheBulletModeIsNamedList() {
        XCTAssertEqual(SmartModeCatalogue.notes.displayName, "List")
    }

    /// The seed names every mode by identifier, so the 2026-08-27 rename left a fresh
    /// install pinning exactly what it pinned before. #523 added a third row to the
    /// front of it — the free slot, not List's.
    func testTheDefaultPinsAreUnchangedByTheRename() {
        XCTAssertEqual(
            SmartModeCatalogue.defaultPinnedIdentifiers,
            ["structured", "notes", "translate.en"]
        )
    }

    /// A seed longer than the fan can hold would be silently truncated by
    /// `SmartModeStore.pinnedModes`, which is a fan the user never chose.
    func testTheSeedFitsTheFan() {
        XCTAssertLessThanOrEqual(
            SmartModeCatalogue.defaultPinnedIdentifiers.count,
            SmartModeCatalogue.maximumPinnedModes
        )
    }

    /// The rows a non-subscriber is promised (#404). Resolved from the seed rather
    /// than from the store, because a non-subscriber cannot reach the mode list to
    /// arrange anything.
    func testTheDefaultPinnedModesResolveToTheSeedInOrder() {
        XCTAssertEqual(
            SmartModeCatalogue.defaultPinnedModes.map(\.id),
            SmartModeCatalogue.defaultPinnedIdentifiers
        )
    }

    /// And there are at least enough of them to fill the slots the upgrade fan has
    /// left after Normal and Dictus Pro take one each, so that fan never draws a gap.
    ///
    /// It used to be an equality. #523 made the seed three long against two slots, so
    /// the upgrade fan now shows the first two — Structured and List — and the
    /// language axis falls off the bottom of the **non-subscriber's** promise. That is
    /// a consequence of the seed order, recorded here rather than left to be
    /// rediscovered from a screenshot.
    func testTheSeedFillsTheUpgradeFansModeSlots() {
        XCTAssertGreaterThanOrEqual(
            SmartModeCatalogue.defaultPinnedModes.count, SmartModeFanLayout.maximumEntries - 2
        )
    }

    // MARK: - Structured (#523)

    /// The identifier is a wire value from the day it ships: it keys the session
    /// cache, the metrics event and the per-dictation App Group snapshot.
    func testStructuredKeepsItsIdentifierAndName() {
        XCTAssertEqual(SmartModeCatalogue.structuredIdentifier, "structured")
        XCTAssertEqual(SmartModeCatalogue.structured.id, "structured")
        XCTAssertEqual(SmartModeCatalogue.structured.displayName, "Structured")
        XCTAssertEqual(SmartModeCatalogue.mode(withIdentifier: "structured")?.id, "structured")
    }

    /// The badge needs no override: a paragraph glyph names this mode on its own,
    /// which is not true of a globe (#79).
    func testStructuredBadgeIsItsIcon() {
        XCTAssertEqual(SmartModeCatalogue.structured.icon, "text.alignleft")
        XCTAssertEqual(SmartModeCatalogue.structured.badge, .symbol("text.alignleft"))
    }

    /// Decision 8, and the one band in this file that is a measurement rather than a
    /// judgement call: the reference outputs of 2026-08-27 run 0.57…1.00 of their
    /// input's length, median 0.93. The floor clears the worst of them with margin.
    func testStructuredBandIsSizedFromTheMeasuredReference() {
        let contract = SmartModeCatalogue.structured.contract
        XCTAssertEqual(contract.minimumLengthRatio, 0.4)
        XCTAssertEqual(contract.maximumLengthRatio, 1.5)
        XCTAssertLessThan(contract.minimumLengthRatio, 0.57)
        // It is not a summarising mode: its floor stays well above List's, which is
        // sized for a three-bullet synthesis of a two-minute dictation.
        XCTAssertGreaterThan(contract.minimumLengthRatio, SmartModeCatalogue.notes.contract.minimumLengthRatio)
    }

    /// Decisions 9 and 10. Grounded because the mode rewrites in the speaker's own
    /// language and may add nothing; unaligned because it may promote its opening
    /// words into a heading, which is a rewritten head by construction (#466).
    func testStructuredIsGroundedAndNeverTranslates() {
        let contract = SmartModeCatalogue.structured.contract
        XCTAssertEqual(contract.outputLanguage, .sameAsInput)
        XCTAssertTrue(contract.requiresGroundedNames)
        XCTAssertFalse(contract.requiresAlignedPrefix)
        XCTAssertEqual(SmartModeCatalogue.structured.overflowBehaviour, .insertRawText)
    }

    /// The rule that stops this mode collapsing into List on the input where they
    /// would otherwise meet — free-form rambling, the primary use case (decision 5).
    /// Stated in the prompt because that is the only place the model reads it.
    func testStructuredPromptKeepsTheSpeakersGrammaticalPerson() {
        let instructions = SmartModeCatalogue.structured.prompt.instructions
        XCTAssertTrue(instructions.contains("KEEP THE SPEAKER'S GRAMMATICAL PERSON"))
        XCTAssertTrue(instructions.contains("infinitive"))
    }

    /// Decision 7's hard bar: the one thing the reference drops and Dictus keeps.
    func testStructuredPromptKeepsASpeakerFlaggedIncompleteness() {
        let instructions = SmartModeCatalogue.structured.prompt.instructions
        XCTAssertTrue(instructions.contains("j'ai oublié un truc"))
        XCTAssertTrue(instructions.contains("KEEP IT"))
    }

    /// Decision 6: a heading is a promotion of the speaker's own opening words, never
    /// an invention. Both reference headings are exactly that.
    func testStructuredPromptForbidsAnInventedTitle() {
        let instructions = SmartModeCatalogue.structured.prompt.instructions
        XCTAssertTrue(instructions.contains("Never invent a title"))
    }

    /// Decision 4 with measurement A behind it: median 0.93 is not a summary.
    func testStructuredPromptForbidsSummarising() {
        XCTAssertTrue(SmartModeCatalogue.structured.prompt.instructions.contains("Do NOT summarise"))
    }

    /// The #414 copying finding, pinned: every example in this prompt is neutralised
    /// together, so no example names a person. A test cannot read intent, but it can
    /// hold the one property that makes a copied line survivable — that the reader
    /// recognises it as not theirs.
    func testStructuredPromptNamesNoPersonInAnyExample() {
        let instructions = SmartModeCatalogue.structured.prompt.instructions
        for name in ["Sophie", "Julien", "Thomas", "Sarah", "Marie", "Paul"] {
            XCTAssertFalse(instructions.contains(name), "the prompt names \(name)")
        }
    }

    /// The one lever the mode has, pinned so an edit cannot quietly remove it.
    ///
    /// #437 measured the system prompt at **zero** line breaks over 144 outputs across
    /// five arms, and this mode reproduced that: 0 breaks in 27 accepted outputs while
    /// the instruction sat in the rules alone. Moving it into the user turn is what
    /// produces a break at all, and the mode's whole want is paragraphs.
    func testStructuredAsksForParagraphsInTheUserTurn() {
        let framing = PolishTask.smart(SmartModeCatalogue.structured).userTurn(raw: "x")
        XCTAssertTrue(framing.contains("break it into paragraphs"))
        XCTAssertTrue(framing.lowercased().contains("output only"))
    }

    /// The #239 pattern, same as every other mode: one English prompt, answering in
    /// the input's language.
    func testStructuredPromptIsWrittenOnceAndKeepsTheInputLanguage() {
        let instructions = SmartModeCatalogue.structured.prompt.instructions
        XCTAssertTrue(instructions.contains("OUTPUT LANGUAGE: the language of the input"))
        XCTAssertTrue(instructions.contains("NEVER translate"))
    }

    // MARK: - Message (#572)

    /// The identifier is a wire value from the day it ships: it keys the session
    /// cache, the metrics event and the per-dictation App Group snapshot.
    func testMessageKeepsItsIdentifierAndName() {
        XCTAssertEqual(SmartModeCatalogue.messageIdentifier, "message")
        XCTAssertEqual(SmartModeCatalogue.message.id, "message")
        XCTAssertEqual(SmartModeCatalogue.message.displayName, "Message")
        XCTAssertEqual(SmartModeCatalogue.mode(withIdentifier: "message")?.id, "message")
    }

    /// Decision 3's floor, and its ceiling as amended.
    ///
    /// The floor is the widest in the repo and is the only thing bounding the
    /// deletion licence. The ceiling was locked at 1.0 and ships at **1.1**: the
    /// guardrail's ratio counts the blank lines decision 6 requires, so 1.00 refused
    /// 10 of the 12 blocked outputs in a 32-output run while accepting 19 of the 20
    /// that came back as one paragraph. This assertion is deliberately an equality
    /// so that restoring 1.00 is one line here and one line in the catalogue.
    func testMessageBandIsTheWidestFloorAndTheTightestCeiling() {
        let contract = SmartModeCatalogue.message.contract
        XCTAssertEqual(contract.minimumLengthRatio, 0.2)
        XCTAssertEqual(contract.maximumLengthRatio, 1.1)
        // It may cut where Structured may not: its floor sits below Structured's,
        // which is sized from a reference that never summarises.
        XCTAssertLessThan(contract.minimumLengthRatio,
                          SmartModeCatalogue.structured.contract.minimumLengthRatio)
        // And it is still the tightest ceiling in the catalogue by a wide margin:
        // every other mode may at least half again its input.
        for mode in SmartModeCatalogue.builtIns where mode.id != "message" {
            XCTAssertGreaterThanOrEqual(mode.contract.maximumLengthRatio, 1.5, mode.id)
        }
    }

    /// Grounded because the mode rewrites in the speaker's own language and may add
    /// nothing (#414); unaligned because it may drop the opening entirely, which is
    /// rule 3 and would make #466's check measure a licence rather than a defect.
    func testMessageIsGroundedAndNeverTranslates() {
        let contract = SmartModeCatalogue.message.contract
        XCTAssertEqual(contract.outputLanguage, .sameAsInput)
        XCTAssertTrue(contract.requiresGroundedNames)
        XCTAssertFalse(contract.requiresAlignedPrefix)
        XCTAssertEqual(SmartModeCatalogue.message.overflowBehaviour, .insertRawText)
    }

    /// **The genre trap, pinned.** PR #388 measured an email framing producing a
    /// literal `[Votre Nom]` under a prompt that banned it by name, and the
    /// competitor's own `chat` preset produced a sign-off under a line forbidding
    /// sign-offs (2026-09-17). Both `SmartModeNotesPrompt` and
    /// `SmartModeStructuredPrompt` answer that by never naming their artefact. This
    /// mode is the one nearest the fire, so the ban is executable rather than a
    /// paragraph: neither the prompt nor the user turn may say what the output is.
    func testMessagePromptNeverNamesItsOwnGenre() {
        let mode = SmartModeCatalogue.message
        let framing = PolishTask.smart(mode).userTurn(raw: "x")
        for text in [mode.prompt.instructions, framing] {
            for noun in ["message", "SMS", "text message", "chat", "email", "e-mail"] {
                XCTAssertFalse(text.lowercased().contains(noun.lowercased()),
                               "the model is shown the word \(noun)")
            }
        }
        // And the user-facing name, which the model never sees, still is that word.
        XCTAssertEqual(mode.displayName, "Message")
    }

    /// Decision 6, and the position is the measurement. #437 put the system prompt
    /// at 0 line breaks over 144 outputs; #523 reproduced it at 0 in 27 and only the
    /// user turn produced any. The block shape is this mode's whole output contract,
    /// so it ships in the one position that works.
    func testMessageAsksForBlocksInTheUserTurn() {
        let framing = PolishTask.smart(SmartModeCatalogue.message).userTurn(raw: "x")
        XCTAssertTrue(framing.contains("short blocks"))
        XCTAssertTrue(framing.contains("blank line"))
        XCTAssertTrue(framing.lowercased().contains("output only"))
    }

    /// Decision 6's other half: `?` and `!` carry meaning a period does not, so they
    /// stay and the period goes.
    func testMessagePromptForbidsClosingABlockWithAPeriod() {
        let instructions = SmartModeCatalogue.message.prompt.instructions
        XCTAssertTrue(instructions.contains("Never close a block with a period"))
    }

    /// Decision 1. The register is mirrored and never chosen, and that is wider than
    /// `tu`/`vous` — the corpus logs Normal polish lifting `comment tu vas` to
    /// `comment vas-tu` as a defect, not as an improvement (#439).
    func testMessagePromptMirrorsTheRegisterRatherThanChoosingOne() {
        let instructions = SmartModeCatalogue.message.prompt.instructions
        XCTAssertTrue(instructions.contains("MIRROR THE REGISTER YOU HEARD"))
        XCTAssertTrue(instructions.contains("more formal"))
    }

    /// The licence that makes this mode a row of its own: it deletes whole clauses,
    /// where `Structured` is explicitly forbidden from cutting substance.
    func testMessagePromptCarriesTheDeletionLicenceStructuredGaveUp() {
        XCTAssertTrue(SmartModeCatalogue.message.prompt.instructions.contains("CUT, and not only fillers"))
        XCTAssertTrue(SmartModeCatalogue.structured.prompt.instructions.contains("Do NOT summarise"))
    }

    /// Decisions 2 and 7: a dictated emoji is the speaker's content; an invented one
    /// is an addition, and this mode has no addition licence.
    func testMessagePromptKeepsADictatedEmojiAndInventsNone() {
        let instructions = SmartModeCatalogue.message.prompt.instructions
        XCTAssertTrue(instructions.contains("Keep an emoji the speaker dictated"))
        XCTAssertTrue(instructions.contains("Never add one"))
    }

    /// Bar 2, the hard one, stated where the model reads it. It is the failure that
    /// cut Email to #269, and it is measured on outputs as well — see
    /// `docs/research/572-message/runs/`.
    func testMessagePromptForbidsAnInventedOpeningClosingNameOrPlaceholder() {
        let instructions = SmartModeCatalogue.message.prompt.instructions
        XCTAssertTrue(instructions.contains("Do NOT open or close with a line the speaker did not say"))
        XCTAssertTrue(instructions.contains("Do NOT write anyone's name unless the speaker said it"))
        XCTAssertTrue(instructions.contains("bracketed placeholder"))
    }

    /// **The device round's repair, pinned — bar 3's three edits.**
    ///
    /// Seven dictations on iOS 27.0 on 2026-09-17 passed bars 1, 2 and 4 and failed
    /// bar 3 as one family: the model deleted the relational layer — the addressee's
    /// name, a term of endearment twice, a courtesy opener, a sign-off — every one of
    /// them dictated, while losing no fact anywhere. Rule 3's only open-ended cut
    /// target was also its only one without a counter-example, which is #414's finding
    /// from another angle. These three assertions are the repair, and a later edit
    /// that removes any of them puts the failure straight back.
    func testMessagePromptProtectsTheRelationalLayer() {
        let instructions = SmartModeCatalogue.message.prompt.instructions
        // 1. Rule 3's open clause is bounded: the person is never an aside.
        XCTAssertTrue(instructions.contains("NEVER THE PERSON"))
        XCTAssertTrue(instructions.contains("how they open and how they close"))
        // 2. A counter-example carries it, because a rule in prose alone does not hold.
        XCTAssertTrue(instructions.contains("cut how the speaker addressed the person"))
        // 3. And the same counter-example holds rule 4's line, which the round also
        //    broke: a spoken negation came back with its `ne` restored.
        XCTAssertTrue(instructions.contains("put back a negation the speaker did not say"))
    }

    /// The round's third defect: one output came back with every internal comma gone,
    /// the model having generalised rule 2's terminal-period ban into "no
    /// punctuation". So the inside of a block is now stated positively rather than
    /// left as the absence of a ban.
    func testMessagePromptStatesWhatSurvivesInsideABlock() {
        let instructions = SmartModeCatalogue.message.prompt.instructions
        XCTAssertTrue(instructions.contains("Everything inside a block keeps its normal punctuation"))
        XCTAssertTrue(instructions.contains("stripped the commas inside the blocks"))
    }

    /// Decision 4's soft rule: kept by default, and deliberately not a hard bar the
    /// corpus fails an output on — the one divergence from #523 decision 7.
    func testMessagePromptKeepsASpeakerFlaggedIncompletenessByDefault() {
        XCTAssertTrue(SmartModeCatalogue.message.prompt.instructions.contains("j'ai oublié un truc"))
    }

    /// The #414 copying finding, pinned as `Structured` pins it: a copied line has to
    /// be recognisable as not the user's. **No person is named anywhere.**
    ///
    /// The second half of this test was `no example prints a greeting or a sign-off`
    /// until the device round of 2026-09-17, and that round inverted the risk. Bar 2
    /// held at 0 invented openers in 7 outputs; bar 3 failed, and it failed *by
    /// deletion* — the addressee's name, a term of endearment twice, a courtesy
    /// opener and a sign-off, every one of them dictated. So one example now prints an
    /// opener and a closing, because they are in its own input and keeping them is the
    /// lesson. What stays banned is the **formal** furniture that appears in no
    /// example's input and that nobody dictating a message says: those are the lines
    /// PR #388 measured an email framing inventing.
    func testMessagePromptNamesNoPersonAndPrintsNoInventedFormalOpener() {
        let instructions = SmartModeCatalogue.message.prompt.instructions
        for name in ["Sophie", "Julien", "Thomas", "Sarah", "Marie", "Paul", "Manu"] {
            XCTAssertFalse(instructions.contains(name), "the prompt names \(name)")
        }
        // The example blocks are everything after the first "INPUT:" line. The
        // FORBIDDEN block above it has to be able to say these words; an example
        // must never print one as output. `Bonjour` and `À bientôt` are on this list
        // and `Coucou toi` is not, and that is the distinction the device round drew:
        // the formal opener nobody dictated against the familiar one they did.
        guard let examplesStart = instructions.range(of: "INPUT:") else {
            XCTFail("the prompt no longer carries a worked example")
            return
        }
        let examples = instructions[examplesStart.lowerBound...]
        for greeting in ["Bonjour", "Cordialement", "Bonne journée", "Bien à", "Best regards", "À bientôt"] {
            XCTAssertFalse(examples.contains(greeting), "an example prints \(greeting)")
        }
    }

    /// The #239 pattern, same as every other mode: one English prompt, answering in
    /// the input's language. The 2026-09-17 competitor run is the measurement of what
    /// omitting this block costs — 10 of 11 engine outputs in English on French.
    func testMessagePromptIsWrittenOnceAndKeepsTheInputLanguage() {
        let instructions = SmartModeCatalogue.message.prompt.instructions
        XCTAssertTrue(instructions.contains("OUTPUT LANGUAGE: the language of the input"))
        XCTAssertTrue(instructions.contains("NEVER translate"))
    }

    /// Every character of a system prompt is taken off the dictation that still fits
    /// (`PolishContextBudget`), so the budget is pinned rather than left to drift.
    ///
    /// #572 invited this to be *"the first prompt in this repo written tight"*, on the
    /// ground that a message is short input. **Two device rounds on 2026-09-17 took
    /// that away**, and this assertion is where the cost is visible: it shipped at
    /// 4 841 characters, round 1 bought 995 against bar 3, and round 2 bought 810 more
    /// against bar 4 — the language carve-out that stops the model translating the
    /// speaker's own greeting, and the short-input example that stops it inventing a
    /// line when it finds nothing left to cut.
    ///
    /// At 6 646 it is by some way the longest prompt in the repo and refuses at
    /// **3 743** characters of speech, against `Structured`'s 4 130 — measured by
    /// binary-searching `PolishContextBudget.fit`, not interpolated. That is roughly
    /// 700 spoken words **in one message**, so this is the one mode in the catalogue
    /// whose ceiling nobody meets, and the overflow branch returns the speaker's own
    /// words regardless.
    ///
    /// The bound stays a few hundred characters above today's value so the next
    /// addition is a decision rather than a drift. **Which paragraphs of these prompts
    /// actually do work is #573 part 3**, across all five modes at once rather than
    /// this one by eye — and at this length that question is now owed.
    func testMessagePromptStaysWithinItsStatedBudget() {
        let message = SmartModeCatalogue.message.prompt.instructions.count
        XCTAssertLessThan(message, 6_900, "the prompt grew past what the doc comment claims")
    }
}
