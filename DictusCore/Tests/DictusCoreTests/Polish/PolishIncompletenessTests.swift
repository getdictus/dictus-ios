// DictusCore/Tests/DictusCoreTests/Polish/PolishIncompletenessTests.swift
// The narrow fabrication check #587 decision 6 asks for (#581).
import XCTest
@testable import DictusCore

/// `PolishIncompleteness` refuses an output that reports the speaker's memory failing
/// when the transcript never did, and nothing wider.
///
/// Two populations, and both matter as much as each other. The fabrications are the
/// device's own (#581) and #583's macOS 27 round; the legitimate side is rule 7 doing
/// its job (#523 decision 7), a rewrite of a spoken form, and three sentences that
/// look close and are not recall at all. #466 is why the second half is here: a check
/// that refuses the rule it backs up is worse than no check.
final class PolishIncompletenessTests: XCTestCase {

    // MARK: - Fabrications, refused

    /// The device, 2026-09-19 06:56:01Z: 284 characters of ordinary French, and the
    /// output closed on the prompt's own worked example, **verbatim**, and was
    /// inserted. Every other check accepted it.
    func testTheVerbatimDeviceLeakIsRefused() {
        let raw = "En fait je suis sur le mode structuré depuis un petit moment. Donc en fait tous les "
            + "tests que j'ai fait hier, notamment sur les tests un petit peu plus longs, ont "
            + "fonctionné. Donc je pense que je vais pouvoir exporter les logs tels quels. Mais en "
            + "moi ça a l'air d'être plutôt correct."
        let output = "Je suis sur le mode structuré depuis un petit moment.\n\nTous les tests que j'ai "
            + "faits hier ont fonctionné.\n\nJe pense que je vais pouvoir exporter les logs tels "
            + "quels.\n\nIl y avait un autre truc, mais ça m'échappe."
        XCTAssertTrue(PolishIncompleteness.isFabricated(polished: output, raw: raw))
    }

    /// Every closing line the device and #583's macOS 27 round produced, each against a
    /// transcript that says nothing about memory. Paraphrases included: the rule-7
    /// variant #581 proposed generalised the invitation into new sentences, and those
    /// have to be caught too.
    func testEveryObservedFrenchLeakIsRefused() {
        let raw = "Alors point rapide sur le projet, on a basculé la partie abonnement lundi dernier. "
            + "Il reste deux trucs, l'historique et le vocabulaire."
        let leaks = [
            "Il y a un autre truc, mais je ne me souviens pas.",
            "Il y avait un autre problème, mais je ne me souviens pas.",
            "Il y avait un autre truc, mais il m'échappe.",
            "Il y avait une autre chose à vérifier, mais elle m'échappe.",
            "J'ai oublié un truc.",
            "Et puis, il y avait un dernier machin, mais ça m'échappe.",
            "Je vois que la mémoire me manque, et je ne sais pas si j'ai tout retenu.",
            "Et puis, je pense que ma mémoire a échoué sur ce dernier point.",
            "Et là dessus, j'ai du mal à me souvenir de ce qui manquait."
        ]
        for leak in leaks {
            XCTAssertTrue(PolishIncompleteness.isFabricated(polished: "Point rapide sur le projet. " + leak, raw: raw),
                          "not refused: \(leak)")
        }
    }

    /// One fabricated line per language the check covers, each against a transcript in
    /// that language with no memory in it.
    func testAFabricationIsRefusedInEachCoveredLanguage() {
        let cases: [LanguageCase] = [
            LanguageCase(language: "en",
                         raw: "Quick update on the garden, the fence is done and the hedge still needs cutting.",
                         text: "There was one more thing, but I can't remember it."),
            LanguageCase(language: "es",
                         raw: "Un repaso rápido del jardín, la valla está terminada y falta cortar el seto.",
                         text: "Había otra cosa, pero no me acuerdo."),
            LanguageCase(language: "de",
                         raw: "Kurzes Update zum Garten, der Zaun ist fertig und die Hecke muss noch geschnitten werden.",
                         text: "Da war noch etwas, aber es fällt mir nicht ein."),
            LanguageCase(language: "it",
                         raw: "Aggiornamento veloce sul giardino, la recinzione è finita e la siepe va ancora tagliata.",
                         text: "C'era un'altra cosa, ma mi sfugge."),
            LanguageCase(language: "pt",
                         raw: "Atualização rápida sobre o jardim, a cerca está pronta e ainda falta cortar a sebe.",
                         text: "Tinha mais uma coisa, mas não me lembro.")
        ]
        for item in cases {
            XCTAssertTrue(PolishIncompleteness.isFabricated(polished: item.raw + " " + item.text, raw: item.raw),
                          "\(item.language): not refused: \(item.text)")
        }
    }

    // MARK: - What the speaker said, kept

    /// Rule 7 doing its job — `longform-fr.json`'s fixture 5, the regression test #523
    /// decision 7 makes a hard bar. Refusing this would refuse the one rule this mode
    /// carries against the reference competitor.
    func testRule7DoingItsJobIsKept() {
        let raw = "Et puis la dernière chose c'est de préparer les questions pour l'entretien de mardi "
            + "voilà je crois que c'est tout ah non il y avait un dernier truc ça m'échappe mais ça me reviendra"
        let output = "Enfin, il faut que je prépare les questions pour l'entretien de mardi.\n\n"
            + "Il y avait un dernier truc, ça m'échappe, mais ça me reviendra."
        XCTAssertFalse(PolishIncompleteness.isFabricated(polished: output, raw: raw))
    }

    /// The asymmetry, pinned on the device shape that needs it (2026-09-19 07:03:42Z).
    /// The speaker said `je ne m'en souviens plus`, the mode is licensed to rewrite, and
    /// the model wrote `Je ne me souviens pas`. A symmetric match would call that
    /// invented.
    func testASpokenFormRewrittenIntoTheWrittenOneIsKept() {
        let raw = "Je vais vérifier, je ne m'en souviens plus si le message dans la tourbar était bon ou pas."
        let output = "Je vais vérifier. Je ne me souviens pas si le message dans la barre d'outils était bon."
        XCTAssertFalse(PolishIncompleteness.isFabricated(polished: output, raw: raw))

        let bare = "je sais plus si j'ai envoyé le mail"
        XCTAssertFalse(PolishIncompleteness.isFabricated(
            polished: "Je ne me souviens pas si j'ai envoyé le mail.", raw: bare
        ))
    }

    /// The speaker-said side in every covered language: the sentence is in the input,
    /// in a spoken form, and comes back written.
    func testASpeakerSaidOneIsKeptInEachCoveredLanguage() {
        let cases: [LanguageCase] = [
            LanguageCase(language: "en",
                         raw: "and there was one more thing uh I forget what it was",
                         text: "There was one more thing, but I can't remember what it was."),
            LanguageCase(language: "es",
                         raw: "y había otra cosa pero se me olvidó cuál era",
                         text: "Había otra cosa, pero no me acuerdo de cuál era."),
            LanguageCase(language: "de",
                         raw: "und da war noch was aber ich hab's vergessen",
                         text: "Da war noch etwas, aber es ist mir entfallen."),
            LanguageCase(language: "it",
                         raw: "e c'era un'altra cosa ma non ricordo cosa",
                         text: "C'era un'altra cosa, ma mi sfugge."),
            LanguageCase(language: "pt",
                         raw: "e tinha mais uma coisa mas esqueci o que era",
                         text: "Tinha mais uma coisa, mas não me lembro do que era.")
        ]
        for item in cases {
            XCTAssertFalse(PolishIncompleteness.isFabricated(polished: item.text, raw: item.raw),
                           "\(item.language): refused a sentence the speaker said")
        }
    }

    // MARK: - Narrow on purpose

    /// Three sentences that sit close to the shape and are not a recall failure. The
    /// first is the device dictation of 2026-09-18 20:55:59, where the speaker said
    /// *"et aussi, autre chose qui pourrait être vraiment top"* — a new idea, not a
    /// missing one. Each would be a false refusal in a wider list.
    func testNeighbouringSentencesAreNotIncompleteness() {
        let cases: [(raw: String, output: String)] = [
            ("et aussi autre chose qui pourrait être vraiment top c'est un écran avec tes stats",
             "Il y a autre chose qui pourrait être vraiment top : un écran avec les stats."),
            ("on reviendra là-dessus demain avec l'équipe",
             "Je reviendrai là-dessus demain avec l'équipe."),
            ("alors j'avais oublié de supprimer les logs donc t'as encore les anciennes",
             "J'avais oublié de supprimer les logs, donc tu as encore les anciennes.")
        ]
        for (raw, output) in cases {
            XCTAssertFalse(PolishIncompleteness.reportsRecallFailing(output), "matched: \(output)")
            XCTAssertFalse(PolishIncompleteness.isFabricated(polished: output, raw: raw))
        }
    }

    /// The accepted hole, pinned so it is a fact rather than a surprise: a language the
    /// check carries no phrases for passes whatever it says.
    func testAnUncoveredLanguagePassesUntested() {
        XCTAssertFalse(PolishIncompleteness.isFabricated(
            polished: "最新の文字起こしです。もう一つあったけど、思い出せない。",
            raw: "最新の文字起こしです。"
        ))
    }

    // MARK: - In the pipeline

    /// `Structuré` refuses under the check's own slug, and the refusal inserts the
    /// speaker's own words rather than nothing (#580).
    func testStructuredRefusesUnderItsOwnSlugAndInsertsTheFloor() async {
        // Long enough that one appended sentence stays inside the 0.4…1.5 band, which
        // is the whole shape: the length check sees nothing wrong with it.
        let raw = "Je vais te partager les logs. Je te laisserai regarder par rapport à l'heure, "
            + "il y en a une dizaine qui sont faits après le dernier message que tu m'as envoyé."
        let job = PolishJob(task: .smart(SmartModeCatalogue.structured),
                            promptLanguage: .french, languageAgnosticPath: false)
        let result = await PolishPipeline.transform(
            preprocessed: raw,
            engine: FixedOutputEngine(output: "Je vais te partager les logs. Il y en a une dizaine "
                                      + "faits après ton dernier message.\n\n"
                                      + "Il y avait un autre truc, mais ça m'échappe."),
            job: job
        )
        XCTAssertEqual(result.outcome, .rejectedGuardrail)
        XCTAssertEqual(result.rejectedCheck, .incompleteness)
        XCTAssertNotNil(PolishPipeline.resolvedOutput(result, preprocessed: raw, job: job))
    }

    /// The same output under `Structuré` with the sentence said, accepted.
    func testStructuredAcceptsTheSentenceWhenTheSpeakerSaidIt() async {
        let raw = "Je te laisserai regarder la dernière transcription, et il y avait un autre truc mais ça m'échappe."
        let result = await PolishPipeline.transform(
            preprocessed: raw,
            engine: FixedOutputEngine(output: "Je te laisserai regarder la dernière transcription.\n\n"
                                      + "Il y avait un autre truc, mais ça m'échappe."),
            job: PolishJob(task: .smart(SmartModeCatalogue.structured),
                           promptLanguage: .french, languageAgnosticPath: false)
        )
        XCTAssertEqual(result.outcome, .success)
    }

    /// Decision 9 keeps `Message` and `Liste` out of this PR, and #571's `Résumé` gets
    /// the default: only `Structuré` turns the check on.
    func testOnlyStructuredTurnsTheCheckOn() {
        for mode in SmartModeCatalogue.builtIns {
            XCTAssertEqual(mode.contract.refusesFabricatedIncompleteness,
                           mode.id == SmartModeCatalogue.structuredIdentifier, mode.id)
        }
        for contract in [PolishAcceptanceContract.natural, .repair, .auto] {
            XCTAssertFalse(contract.refusesFabricatedIncompleteness)
        }
    }

    /// A contract written by a build that never heard of the field decodes to off, and
    /// a round trip keeps `Structuré`'s answer.
    func testTheFieldDecodesOffWhenAbsentAndRoundTrips() throws {
        let json = #"{"minimumLengthRatio":0.4,"maximumLengthRatio":1.5,"outputLanguage":"sameAsInput"}"#
        let old = try JSONDecoder().decode(PolishAcceptanceContract.self, from: Data(json.utf8))
        XCTAssertFalse(old.refusesFabricatedIncompleteness)

        let data = try JSONEncoder().encode(SmartModeCatalogue.structured.contract)
        let decoded = try JSONDecoder().decode(PolishAcceptanceContract.self, from: data)
        XCTAssertTrue(decoded.refusesFabricatedIncompleteness)
    }
}

/// One language's pair: a transcript and a text judged against it.
private struct LanguageCase {
    let language: String
    let raw: String
    let text: String
}

/// Returns one fixed string. Repeated here rather than shared because every other
/// copy in this target is `private` to its file.
private struct FixedOutputEngine: PolishEngineProtocol {
    let identifier = "fixed-output"
    let output: String

    func polish(raw: String,
                targetLanguage: SupportedLanguage,
                task: PolishTask) async throws -> String {
        output
    }
}
