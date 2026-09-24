// DictusCore/Tests/DictusCoreTests/Polish/PolishLostWordsTests.swift
import XCTest
@testable import DictusCore

/// The lost-word check (#575): one test group per row of the brief's table, then the
/// licences the Natural contract grants, then where the check runs at all.
///
/// The device and harness outputs are verbatim from #575 and from
/// `docs/research/575-normal-polish-damage/`. Rows 2 and 3 no longer reproduce on the
/// Mac since macOS 27, so these strings are the only place the check meets them
/// before a device replay.
final class PolishLostWordsTests: XCTestCase {

    private func lost(_ raw: String, _ polished: String, language: String? = "fr") -> [String] {
        PolishLostWords.lostWords(polished: polished, raw: raw, languageCode: language)
    }

    // MARK: - Row 1: a dictated word replaced by a different word → refused

    /// Row 2 of #575, device 2026-09-17: the D4 dictation, `preneur` → `prêt`.
    func testIdiomReplacedByAnotherWordIsRefused() {
        let raw = "Yo les gars, vous savez comment on peut voir les limites d'usage du modèle Astra. "
            + "Parce que ce matin j'ai voulu le tester et visiblement j'ai atteint les limites. "
            + "Mais quand je vais voir dans les dans les settings utilisation de ChatGPT, je vois juste "
            + "l'usage global, je vois pas l'usage par modèle. Si vous avez l'info les gars, je suis preneur."
        let polished = "Yo les gars, vous savez comment on peut voir les limites d'usage du modèle Astra ? "
            + "Parce que ce matin, j'ai voulu le tester et visiblement, j'ai atteint les limites. "
            + "Mais quand je vais voir dans les settings utilisation de ChatGPT, je vois juste "
            + "l'usage global, je vois pas l'usage par modèle. Si vous avez l'info, les gars, je suis prêt."
        XCTAssertEqual(lost(raw, polished), ["preneur"])
    }

    /// Row 3, harness 2026-09-17: both substitutions the fixture produced.
    func testFixedIdiomDestroyedIsRefused() {
        let raw = "Merci beaucoup pour hier, c'était vraiment cool. Je te revaudrai ça promis. "
            + "On se capte la semaine prochaine pour le reste."
        XCTAssertEqual(lost(raw, "Merci beaucoup pour hier, c'était vraiment cool. Je te reviendrai ça, promis. "
                            + "On se capte la semaine prochaine pour le reste."), ["revaudrai"])
        XCTAssertEqual(lost(raw, "Merci beaucoup pour hier, c'était vraiment cool. Je te revoilà ça, promis. "
                            + "On se capte la semaine prochaine pour le reste."), ["revaudrai"])
    }

    /// Row 5: `on se capte` → `on se voit` / `on se retrouve`.
    func testSlangVerbReplacedIsRefused() {
        let raw = "Merci beaucoup pour hier, c'était vraiment cool. Je te revaudrai ça promis. "
            + "On se capte la semaine prochaine pour le reste."
        for replacement in ["voit", "retrouve"] {
            let polished = "Merci beaucoup pour hier, c'était vraiment cool. Je te revaudrai ça, promis. "
                + "On se \(replacement) la semaine prochaine pour le reste."
            XCTAssertEqual(lost(raw, polished), ["capte"], replacement)
        }
    }

    /// A familiar synonym is a different word, whatever its register: the brief's
    /// allow-list carries anglicisms and contractions, not slang. Measured on the Mac:
    /// `pourrais` → `peux` 8/10 on the auto route.
    func testFamiliarSynonymIsRefused() {
        XCTAssertEqual(lost("j'ai bossé sur le projet toute la journée",
                            "J'ai travaillé sur le projet toute la journée."), ["bosse"])
        XCTAssertEqual(lost("Est-ce que tu pourrais m'envoyer le devis avant vendredi s'il te plaît ?",
                            "Est-ce que tu peux m'envoyer le devis avant vendredi, s'il te plaît ?"),
                       ["pourrais"])
    }

    // MARK: - Row 2: a meaning-bearing word deleted → refused

    func testDroppedNegationIsRefused() {
        XCTAssertEqual(lost("je vois pas l'usage par modèle", "Je vois l'usage par modèle."), ["pas"])
        XCTAssertEqual(lost("on l'utilise plus depuis février", "On l'utilise depuis février."), ["plus"])
    }

    func testDroppedNumberIsRefused() {
        XCTAssertEqual(lost("je serai à la gare vers 18h30 avec les billets",
                            "Je serai à la gare avec les billets."), ["18", "30"])
    }

    func testDroppedNameIsRefused() {
        XCTAssertEqual(lost("Salut Manu comment tu vas ?", "Salut, comment tu vas ?"), ["manu"])
    }

    func testDroppedDateIsRefused() {
        XCTAssertEqual(lost("on se voit lundi pour caler la réunion", "On se voit pour caler la réunion."),
                       ["lundi"])
    }

    /// A time-bearing sign-off is not a politeness formula: it says when the two will
    /// next talk.
    func testTimeBearingSignOffIsNotDroppable() {
        XCTAssertEqual(lost("Ok ça marche, à demain.", "Ok, ça marche."), ["demain"])
    }

    /// `à plus` is a sign-off; the `a plus` of *il n'y a plus* is a negation, and the
    /// tokeniser keeps the two apart.
    func testSignOffNeverSwallowsANegation() {
        XCTAssertEqual(lost("il n'y a plus de pain", "Il n'y a de pain."), ["plus"])
    }

    // MARK: - Row 3: register lifted → tolerated

    func testContractionExpandedIsTolerated() {
        XCTAssertEqual(lost("Coucou tu peux me rappeler quand t'as deux minutes",
                            "Coucou, tu peux me rappeler quand tu as deux minutes ?"), [])
    }

    func testAddedNeIsTolerated() {
        XCTAssertEqual(lost("je vois pas l'usage par modèle", "Je ne vois pas l'usage par modèle."), [])
    }

    func testInvertedQuestionIsTolerated() {
        XCTAssertEqual(lost("Salut Manu comment tu vas ?", "Salut Manu, comment vas-tu ?"), [])
    }

    /// Row 4 of #575, device 2026-09-17, all three lifts at once — plus row 1's two
    /// deletions, which the next group tolerates too. This is the output the
    /// maintainer received, and under the 2026-09-24 bar it keeps his meaning.
    func testDeviceRegisterLiftIsTolerated() {
        let raw = "Salut Manu comment tu vas ? Est-ce que tu pourrais checker si tu as bien reçu le mail "
            + "que je t'ai envoyé tout à l'heure s'il te plaît ? Des bisous."
        let polished = "Salut Manu, comment vas-tu ? Est-ce que tu pourrais vérifier si tu as bien reçu "
            + "l'email que je t'ai envoyé tout à l'heure ?"
        XCTAssertEqual(lost(raw, polished), [])
    }

    func testListedAnglicismTranslatedIsTolerated() {
        XCTAssertEqual(lost("je vais checker les settings", "Je vais vérifier les paramètres."), [])
        XCTAssertEqual(lost("faut que je push le commit avant la deadline de today",
                            "Il faut que je pousse le commit avant la date limite d'aujourd'hui."), [])
    }

    /// The pair licenses a translation, not a deletion: `checker` gone with no French
    /// verb in its place is a verb lost.
    func testAnglicismDeletedOutrightIsRefused() {
        XCTAssertEqual(lost("tu pourrais checker le mail", "Tu pourrais le mail ?"), ["checker"])
    }

    // MARK: - Row 4: politeness formula or sign-off dropped → tolerated

    func testPolitenessAndSignOffDroppedAreTolerated() {
        XCTAssertEqual(lost("Est-ce que tu pourrais m'envoyer le devis avant vendredi s'il te plaît ? "
                            + "Merci d'avance, bonne soirée.",
                            "Est-ce que tu pourrais m'envoyer le devis avant vendredi ?"), [])
        XCTAssertEqual(lost("Ok ça marche pour samedi, je ramène les bières. Bises, à plus.",
                            "Ok, ça marche pour samedi, je ramène les bières."), [])
    }

    // MARK: - The contract's other licences

    /// Rule 6 on a phrase: all ten short-input false refusals of the research detector
    /// were this fold, on the D1 device dictation.
    func testRepeatedPhraseCollapseIsTolerated() {
        XCTAssertEqual(lost("je te tiens au jus dès que dès que... dès que j'ai avancé",
                            "Je te tiens au jus dès que j'ai avancé."), [])
    }

    func testSpokenNumberToDigitsIsTolerated() {
        XCTAssertEqual(lost("rappelle-moi dans deux minutes", "Rappelle-moi dans 2 minutes."), [])
        XCTAssertEqual(lost("rendez-vous à dix-huit heures trente", "Rendez-vous à 18h30."), [])
        XCTAssertEqual(lost("je serai là vers 18h30", "Je serai là vers 18 h 30."), [])
    }

    func testAbbreviationGrownIntoItsFullFormIsTolerated() {
        XCTAssertEqual(lost("t'es dispo ce soir", "Tu es disponible ce soir ?"), [])
    }

    func testSpellingVariantsAreOneWord() {
        XCTAssertEqual(lost("j'essaye de te rappeler", "J'essaie de te rappeler."), [])
    }

    func testJoinedProductNameIsTolerated() {
        XCTAssertEqual(lost("j'ai testé type less hier", "J'ai testé TypeLess hier."), [])
    }

    /// Rule 8 bringing an English clause back into French: the #439 `3-message-draft`
    /// dictation and one of its recorded outputs, verbatim. Every English word goes,
    /// and that is the contract working.
    func testOffLanguageClauseBroughtBackStandsTheCheckDown() {
        let raw = "Je voulais juste te dire pour demain que je ne pourrais pas venir au bureau. "
            + "J'ai un rendez-vous chez le dentiste à 11h and I think that it will déborder. "
            + "Du coup, si tu peux décaler le point d'équipe à l'après-midi, ça m'arrangerait."
        let polished = "Je voulais juste te dire pour demain que je ne pourrais pas venir au bureau. "
            + "J'ai un rendez-vous chez le dentiste à 11h, et je pense que ça va déborder. "
            + "Du coup, si tu peux décaler le point d'équipe à l'après-midi, ça m'arrangerait."
        XCTAssertEqual(lost(raw, polished), [])
    }

    /// The stand-down reads the run's language: a FRENCH clause deleted is a loss.
    func testFrenchClauseDeletedIsStillRefused() {
        XCTAssertEqual(
            lost("je suis arrivé en retard parce que le train était bloqué à Lyon ce matin",
                 "Je suis arrivé en retard ce matin."),
            ["bloque", "etait", "lyon", "parce", "train"]
        )
    }

    // MARK: - Where the check does not read

    func testOtherLanguagesPassUntested() {
        XCTAssertEqual(lost("I'm gonna check the settings", "I will verify the parameters.", language: "en"), [])
        XCTAssertEqual(lost("je suis preneur", "Je suis prêt.", language: nil), [])
    }

    func testLongInputPassesUntested() {
        let filler = String(repeating: "on avance bien sur le projet et tout se passe comme prévu. ", count: 9)
        let raw = filler + "Si vous avez l'info, je suis preneur."
        XCTAssertGreaterThan(raw.count, PolishLostWords.maximumInputCharacters)
        XCTAssertEqual(lost(raw, filler + "Si vous avez l'info, je suis prêt."), [])
        // The same substitution, under the ceiling, is refused.
        XCTAssertEqual(lost("Si vous avez l'info, je suis preneur.", "Si vous avez l'info, je suis prêt."),
                       ["preneur"])
    }

    // MARK: - Through the pipeline

    private let rowTwoRaw = "Si jamais t'as encore des places pour le concert de samedi, je suis preneur."
    private let rowTwoPolished = "Si jamais t'as encore des places pour le concert de samedi, je suis prêt."

    /// Natural refuses under its own name, and the user gets the floor — the pre-passed
    /// dictation, typography applied — never the substituted word.
    func testNaturalRefusesAndInsertsTheFloor() async {
        let job = PolishJob(task: .natural, promptLanguage: .french, languageAgnosticPath: false)
        let result = await PolishPipeline.transform(
            preprocessed: rowTwoRaw, engine: CannedOutputEngine(output: rowTwoPolished), job: job
        )
        XCTAssertEqual(result.outcome, .rejectedGuardrail)
        XCTAssertEqual(result.rejectedCheck, .lostWord)
        let inserted = PolishPipeline.resolvedOutput(result, preprocessed: rowTwoRaw, job: job)
        XCTAssertEqual(inserted.map { $0.contains("preneur") }, true)
        XCTAssertEqual(inserted.map { $0.contains("prêt") }, false)
    }

    /// Auto, the route the 2026-09-17 device rows ran on, keys the lexicon on the
    /// input's detected language.
    func testAutoRefusesOnAFrenchDictation() async {
        let result = await PolishPipeline.transform(
            preprocessed: rowTwoRaw, engine: CannedOutputEngine(output: rowTwoPolished),
            job: PolishJob(task: .auto, promptLanguage: .english, languageAgnosticPath: true)
        )
        XCTAssertEqual(result.rejectedCheck, .lostWord)
    }

    func testToleratedOutputIsAccepted() async {
        let result = await PolishPipeline.transform(
            preprocessed: rowTwoRaw,
            engine: CannedOutputEngine(output: "Si jamais tu as encore des places pour le concert de samedi, je suis preneur."),
            job: PolishJob(task: .natural, promptLanguage: .french, languageAgnosticPath: false)
        )
        XCTAssertEqual(result.outcome, .success)
    }

    /// Repair reconstructs words by design and every Smart Mode rewrites on purpose:
    /// neither runs the check.
    func testRepairAndSmartModesDoNotRunTheCheck() async {
        XCTAssertFalse(PolishAcceptanceContract.repair.refusesLostWords)
        for mode in [SmartModeCatalogue.notes, SmartModeCatalogue.structured,
                     SmartModeCatalogue.message, SmartModeCatalogue.summary] {
            XCTAssertFalse(mode.contract.refusesLostWords, mode.id)
            let result = await PolishPipeline.transform(
                preprocessed: rowTwoRaw, engine: CannedOutputEngine(output: rowTwoPolished),
                job: PolishJob(task: .smart(mode), promptLanguage: .french, languageAgnosticPath: false)
            )
            XCTAssertNotEqual(result.rejectedCheck, .lostWord, mode.id)
        }
        let repaired = await PolishPipeline.transform(
            preprocessed: rowTwoRaw, engine: CannedOutputEngine(output: rowTwoPolished),
            job: PolishJob(task: .repair, promptLanguage: .french, languageAgnosticPath: false)
        )
        XCTAssertNotEqual(repaired.rejectedCheck, .lostWord)
    }

    func testOnlyNaturalAndAutoRefuseLostWords() {
        XCTAssertTrue(PolishAcceptanceContract.natural.refusesLostWords)
        XCTAssertTrue(PolishAcceptanceContract.auto.refusesLostWords)
    }

    /// A contract written by a build that never heard of the field decodes with the
    /// check off, like every other check flag.
    func testContractWithoutTheFieldDecodesWithTheCheckOff() throws {
        let json = #"{"minimumLengthRatio":0.5,"maximumLengthRatio":2,"outputLanguage":"sameAsInput"}"#
        let decoded = try JSONDecoder().decode(PolishAcceptanceContract.self, from: Data(json.utf8))
        XCTAssertFalse(decoded.refusesLostWords)
        let roundTripped = try JSONDecoder().decode(
            PolishAcceptanceContract.self, from: JSONEncoder().encode(PolishAcceptanceContract.natural)
        )
        XCTAssertTrue(roundTripped.refusesLostWords)
    }

    func testCheckWireValue() {
        XCTAssertEqual(PolishGuardrail.Check.lostWord.rawValue, "lostWord")
    }
}

/// Returns a fixed string whatever it is handed.
private struct CannedOutputEngine: PolishEngineProtocol {
    let identifier = "canned-output"
    let output: String

    func polish(raw: String, targetLanguage: SupportedLanguage, task: PolishTask) async throws -> String {
        output
    }
}
