// DictusCore/Tests/DictusCoreTests/Polish/SmartModeCatalogueTests.swift
// The Smart Mode catalogue and the record type it is made of (issue #79).
import XCTest
@testable import DictusCore

final class SmartModeCatalogueTests: XCTestCase {

    // MARK: - The rows

    func testCatalogueShipsNotesAndOneTranslateEntryPerSupportedLanguage() {
        XCTAssertEqual(SmartModeCatalogue.builtIns.count, 4 + SupportedLanguage.allCases.count)
        XCTAssertTrue(SmartModeCatalogue.builtIns.contains { $0.id == "notes" })
        XCTAssertTrue(SmartModeCatalogue.builtIns.contains { $0.id == "structured" })
        XCTAssertTrue(SmartModeCatalogue.builtIns.contains { $0.id == "message" })
        XCTAssertTrue(SmartModeCatalogue.builtIns.contains { $0.id == "summary" })
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
        XCTAssertEqual(SmartModeCatalogue.structured.floorBehaviour, .insertRawText)
    }

    /// The rule that stops this mode collapsing into List on the input where they
    /// would otherwise meet — free-form rambling, the primary use case (decision 5).
    /// Stated in the prompt because that is the only place the model reads it.
    func testStructuredPromptKeepsTheSpeakersGrammaticalPerson() {
        let instructions = SmartModeCatalogue.structured.prompt.instructions
        XCTAssertTrue(instructions.contains("Keep their grammatical person, tense and tone"))
        XCTAssertTrue(instructions.contains("never a task list"))
    }

    /// Decision 7's hard bar: the one thing the reference drops and Dictus keeps.
    ///
    /// Since #587 the rule is conditioned on the transcript and quotes **no** phrasing:
    /// the four it used to name were one of the two sources PR #583 measured leaking
    /// into outputs that said nothing of the kind. `PolishIncompleteness` is the
    /// backstop; `SmartModeStructuredPromptTests` asserts no example shows one either.
    func testStructuredPromptKeepsASpeakerFlaggedIncompleteness() {
        let instructions = SmartModeCatalogue.structured.prompt.instructions
        XCTAssertTrue(instructions.contains("If the transcript itself says that something is missing"))
        XCTAssertTrue(instructions.contains("keep that sentence in their words"))
        XCTAssertFalse(instructions.contains("j'ai oublié un truc"))
        XCTAssertFalse(instructions.contains("ça m'échappe"))
    }

    /// Decision 6: a heading is a promotion of the speaker's own opening words, never
    /// an invention. Both reference headings are exactly that.
    func testStructuredPromptForbidsAnInventedTitle() {
        let instructions = SmartModeCatalogue.structured.prompt.instructions
        XCTAssertTrue(instructions.contains("no fact, name, date, conclusion, title or closing sentence"))
        XCTAssertTrue(instructions.contains("A short heading is allowed only when their own first words"))
    }

    /// Decision 4 with measurement A behind it: median 0.93 is not a summary.
    func testStructuredPromptForbidsSummarising() {
        XCTAssertTrue(SmartModeCatalogue.structured.prompt.instructions.contains("Never summarise"))
    }

    /// Decision 7 of #587: a list only when the speaker enumerates, and never one
    /// bullet per sentence — the shape the device returned on 2026-09-20.
    func testStructuredPromptAllowsAListOnlyOnARealEnumeration() {
        let instructions = SmartModeCatalogue.structured.prompt.instructions
        XCTAssertTrue(instructions.contains("Use a list only when they enumerate separate items themselves"))
        XCTAssertTrue(instructions.contains("Never one bullet per sentence"))
    }

    /// Decision 5 step 2: the mode carries one example set per Apple FM language, and
    /// the rules stay one English text. The sets themselves are pinned in
    /// `SmartModeStructuredPromptTests`.
    func testStructuredCarriesAnExampleSetPerLanguage() {
        let prompt = SmartModeCatalogue.structured.prompt
        XCTAssertEqual(prompt.localizedInstructions?.count, 16)
        XCTAssertEqual(prompt.instructions(forTranscriptLanguage: "da"),
                       SmartModeStructuredPrompt.localizedInstructions()["da"])
        XCTAssertEqual(prompt.instructions(forTranscriptLanguage: "cs"), prompt.instructions)
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
        XCTAssertTrue(instructions.contains("1. Write in the language of the transcript, whatever it is"))
        XCTAssertTrue(instructions.contains("Never translate, not even partly"))
    }

    /// #587 decision 9: `Liste` carries one example set per Apple FM language, and
    /// nothing else about the mode moves. Its rebuild is #573.
    func testListCarriesAnExampleSetPerLanguage() {
        let prompt = SmartModeCatalogue.notes.prompt
        XCTAssertEqual(prompt.localizedInstructions?.count, 15)
        XCTAssertEqual(prompt.instructions(forTranscriptLanguage: "ja"),
                       SmartModeNotesPrompt.localizedInstructions()["ja"])
        XCTAssertEqual(prompt.instructions(forTranscriptLanguage: "cs"), prompt.instructions)
    }

    /// Every set of both modes is bullets for `Liste` and blocks for `Message`, and
    /// no set loses its mode's shape in translation. #393 is why the first half is a
    /// test: a translated example that came back as prose would have turned the bullet
    /// mode into prose.
    func testEveryListExampleSetStillShowsBullets() {
        for (code, set) in SmartModeNotesExamples.byLanguage {
            for output in [set.meetingOutput, set.buildOutput, set.shortOutput, set.counterRight] {
                XCTAssertTrue(output.hasPrefix("- "), "\(code): an example output is not a bullet")
            }
            XCTAssertEqual(set.meetingOutput.components(separatedBy: "\n- ").count, 3, code)
        }
    }

    /// The two languages whose sets are the originals rather than translations keep
    /// their own text: `Message`'s French pair is what the mode shipped with, which is
    /// what makes a French dictation identical to before (#587 decision 9).
    func testMessageFrenchExamplesAreTheShippingPair() {
        let french = SmartModeMessageExamples.byLanguage["fr"]
        XCTAssertEqual(french?.casualInput.hasPrefix("coucou toi euh j'ai récupéré la tondeuse"), true)
        XCTAssertEqual(french?.greetingInput, "Hello chef, comment tu vas ?")
        XCTAssertEqual(french?.greetingOutput, "Hello chef, comment tu vas ?")
        XCTAssertEqual(SmartModeMessagePrompt.instructions(), SmartModeMessagePrompt.instructions(
            examples: SmartModeMessageExamples.byLanguage["fr"] ?? SmartModeMessagePrompt.defaultExamples
        ))
    }

    /// Both tables hold the same 15 base subtags, so no mode silently covers fewer
    /// languages than the other.
    func testBothTablesCoverTheSameLanguages() {
        let expected: Swift.Set<String> = ["da", "de", "en", "es", "fr", "it", "ja", "ko", "nb",
                                           "nl", "pt", "sv", "tr", "vi", "zh"]
        XCTAssertEqual(Swift.Set(SmartModeNotesExamples.byLanguage.keys), expected)
        XCTAssertEqual(Swift.Set(SmartModeMessageExamples.byLanguage.keys), expected)
        for code in expected {
            XCTAssertNotNil(SmartModeNotesExamples.set(forLanguageCode: code + "-XX"), code)
            XCTAssertNotNil(SmartModeMessageExamples.set(forLanguageCode: code + "-XX"), code)
        }
    }

    /// **The table has to be on the catalogue row, not only in the examples file**
    /// (found by CodeRabbit on PR #597): a mode whose wiring regressed would hand every
    /// non-French transcript the fallback prompt, with the assertion above still green
    /// because the examples themselves never moved.
    ///
    /// Asserted for every mode that carries one, and asserted absent for the modes that
    /// do not: `Traduction` names its target inside its own instructions.
    func testEveryLocalizedModeResolvesItsTableThroughTheCatalogue() {
        let localized = [SmartModeCatalogue.message, SmartModeCatalogue.notes,
                         SmartModeCatalogue.structured, SmartModeCatalogue.summary]
        for mode in localized {
            let prompt = mode.prompt
            XCTAssertGreaterThanOrEqual(prompt.localizedInstructions?.count ?? 0, 15, mode.id)
            for code in ["de", "ja", "pt-BR", "no"] {
                XCTAssertNotEqual(prompt.instructions(forTranscriptLanguage: code), prompt.instructions,
                                  "\(mode.id) sends the fallback for \(code)")
            }
            XCTAssertEqual(prompt.instructions(forTranscriptLanguage: "cs"), prompt.instructions, mode.id)
        }
        let localizedIdentifiers = Swift.Set(localized.map(\.id))
        for mode in SmartModeCatalogue.builtIns where !localizedIdentifiers.contains(mode.id) {
            XCTAssertNil(mode.prompt.localizedInstructions, mode.id)
        }
    }

    /// The language rule in both prompts, and no rule renumbered.
    ///
    /// It names the **input** and nothing else since #587's follow-up: the clause it
    /// replaced forbade "the language of the examples below" while those examples are
    /// the transcript's own language, so a model reading it literally was told to avoid
    /// the language it must write in. Neither prompt may name the examples here again.
    func testBothPromptsCarryTheInputLanguageRule() {
        for instructions in [SmartModeCatalogue.message.prompt.instructions,
                             SmartModeCatalogue.notes.prompt.instructions] {
            XCTAssertFalse(instructions.contains("language of the examples"))
            XCTAssertFalse(instructions.contains("never the examples'"))
        }
        XCTAssertTrue(SmartModeCatalogue.message.prompt.instructions
            .contains("Read it, then write in that language and no other"))
        XCTAssertTrue(SmartModeCatalogue.notes.prompt.instructions
            .contains("the output language always matches the input's"))
        XCTAssertTrue(SmartModeCatalogue.message.prompt.instructions
            .contains("1. Cut what only exists because they were speaking"))
        XCTAssertTrue(SmartModeCatalogue.notes.prompt.instructions
            .contains("1. Write one bullet per idea"))
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
        // every other mode may at least half again its input. `summary` is the one
        // exception, by construction: it is the mode that must shorten (#571), and
        // its own suite pins its ceiling below every other row's.
        for mode in SmartModeCatalogue.builtIns where !["message", "summary"].contains(mode.id) {
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
        XCTAssertEqual(SmartModeCatalogue.message.floorBehaviour, .insertRawText)
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
        XCTAssertTrue(instructions.contains("never close a block with a period"))
    }

    /// Decision 1. The register is mirrored and never chosen, and that is wider than
    /// `tu`/`vous` — the corpus logs Normal polish lifting `comment tu vas` to
    /// `comment vas-tu` as a defect, not as an improvement (#439).
    func testMessagePromptMirrorsTheRegisterRatherThanChoosingOne() {
        let instructions = SmartModeCatalogue.message.prompt.instructions
        XCTAssertTrue(instructions.contains("Mirror their register exactly"))
        XCTAssertTrue(instructions.contains("more formal"))
    }

    /// The licence that makes this mode a row of its own: it deletes whole clauses,
    /// where `Structured` is explicitly forbidden from cutting substance.
    func testMessagePromptCarriesTheDeletionLicenceStructuredGaveUp() {
        XCTAssertTrue(SmartModeCatalogue.message.prompt.instructions.contains("Cut what only exists because they were speaking"))
        XCTAssertTrue(SmartModeCatalogue.structured.prompt.instructions.contains("Never summarise"))
    }

    /// Decisions 2 and 7: a dictated emoji is the speaker's content; an invented one
    /// is an addition, and this mode has no addition licence.
    func testMessagePromptKeepsADictatedEmojiAndInventsNone() {
        let instructions = SmartModeCatalogue.message.prompt.instructions
        XCTAssertTrue(instructions.contains("Keep an emoji they dictated"))
        XCTAssertTrue(instructions.contains("Never add anything they did not say"))
    }

    /// Bar 2, the hard one, stated where the model reads it. It is the failure that
    /// cut Email to #269, and it is measured on outputs as well — see
    /// `docs/research/572-message/runs/`.
    func testMessagePromptForbidsAnInventedOpeningClosingNameOrPlaceholder() {
        let instructions = SmartModeCatalogue.message.prompt.instructions
        XCTAssertTrue(instructions.contains("no greeting, sign-off, name, emoji or fact"))
        XCTAssertTrue(instructions.contains("square brackets"))
    }

    /// **Bar 3, pinned — the relational layer survives the cut.**
    ///
    /// Seven dictations on iOS 27.0 on 2026-09-17 failed bar 3 as one family: the model
    /// deleted the addressee's name, a term of endearment twice, a courtesy opener and
    /// a sign-off — every one of them dictated. Rounds 1 to 4 repaired it with
    /// counter-examples; the round-6 rewrite (2026-09-18) states it once, in rule 2, by
    /// naming each part, and keeps one example that prints an opener and a closing
    /// because they are in its own input. **Holding it without a counter-example is the
    /// rewrite's main bet, and only a device round can settle it** — the Mac harness
    /// barely cuts at all, so it cannot see a deletion either way.
    func testMessagePromptProtectsTheRelationalLayer() {
        let instructions = SmartModeCatalogue.message.prompt.instructions
        // Rule 2: everything said to the person survives, by name — the greeting, the
        // name or pet name, and the closing — and the cut licence stops at a sentence.
        XCTAssertTrue(instructions.contains("the greeting, the name or pet name they used"))
        XCTAssertTrue(instructions.contains("the closing"))
        XCTAssertTrue(instructions.contains("never a sentence they meant"))
        // Rule 3: the spoken negation a round-1 output restored.
        XCTAssertTrue(instructions.contains("\"je sais pas\" stays \"je sais pas\""))
    }

    /// One output came back with every internal comma gone, the model having
    /// generalised the terminal-period ban into "no punctuation"; so the inside of a
    /// block is stated positively. And round 5's long message was cut into blocks in
    /// the middle of its sentences, which the rewrite forbids by name.
    func testMessagePromptStatesWhatSurvivesInsideABlock() {
        let instructions = SmartModeCatalogue.message.prompt.instructions
        XCTAssertTrue(instructions.contains("Normal punctuation inside a block"))
        XCTAssertTrue(instructions.contains("Never split a sentence across two blocks"))
    }

    /// Decision 4's soft rule: kept by default, and deliberately not a hard bar the
    /// corpus fails an output on — the one divergence from #523 decision 7.
    func testMessagePromptKeepsASpeakerFlaggedIncompletenessByDefault() {
        // Stated by its property, not by a liftable sentence: #581 measured
        // `Structuré` copying its own rule-7 example phrasing onto the end of a
        // dictation, and a sentence about the speaker's memory fits any input.
        let instructions = SmartModeCatalogue.message.prompt.instructions
        XCTAssertTrue(instructions.contains("When they say something is missing or unfinished, keep that"))
        XCTAssertFalse(instructions.contains("j'ai oublié un truc"))
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
        XCTAssertTrue(instructions.contains("write in the language of the input"))
        XCTAssertTrue(instructions.contains("Never translate"))
        // The carve-out round 2 needed: four of four borrowed greetings were
        // translated while this block was emphatic and had none.
        XCTAssertTrue(instructions.contains("A word the speaker said in another language"))
    }

    /// Every character of a system prompt is taken off the dictation that still fits
    /// (`PolishContextBudget`), so the budget is pinned rather than left to drift.
    ///
    /// **This bound is the lesson of rounds 1 to 5.** The prompt shipped at 4 841
    /// characters and four device rounds of patches took it to 7 036 — each one a
    /// counter-example or a clause against the last defect, and each moving another
    /// behaviour: round 2's short example taught the model to echo, round 5 put a line
    /// in capitals and swapped a word. Pierre's call on 2026-09-18 was to stop
    /// patching and rewrite it short. The rewrite is **2 925** characters and refuses at
    /// **5 071** characters of speech, binary-searched through `PolishContextBudget.fit`.
    ///
    /// The bound sits a few hundred characters above that so that growing the prompt
    /// again is a decision someone has to argue here, not a drift. Two of the lines the
    /// rewrite first dropped were measured back in on the Mac (see the prompt's doc):
    /// that is the bar for adding anything.
    func testMessagePromptStaysWithinItsStatedBudget() {
        let message = SmartModeCatalogue.message.prompt.instructions.count
        XCTAssertLessThan(message, 3_200, "the prompt grew past what the doc comment claims")
    }
}
