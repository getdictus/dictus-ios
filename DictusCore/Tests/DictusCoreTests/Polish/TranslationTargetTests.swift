// DictusCore/Tests/DictusCoreTests/Polish/TranslationTargetTests.swift
// The 25 Translate targets, their codes, their modes and their prompts (issue #622).
import XCTest
import CryptoKit
@testable import DictusCore

/// The target list the #622 brief fixes, and what the catalogue builds from it.
///
/// The four built-in modes are the part of this file that guards a promise: "same
/// identifiers, same behaviour, no migration". Their prompts are pinned by hash to the
/// strings they shipped with before #622, so a change to the shared builder that moved
/// one byte of them fails here instead of on a device.
final class TranslationTargetTests: XCTestCase {

    // MARK: - The list

    func testTheListIsTheTwentyFiveLanguagesTheBriefMeasuredLessMalay() {
        XCTAssertEqual(
            Set(TranslationTarget.all.map(\.code)),
            ["ar", "da", "de", "en", "es", "fi", "fr", "he", "hi", "id", "it", "ja", "ko", "nb",
             "nl", "pl", "pt", "ru", "sv", "th", "tr", "uk", "vi", "zh-Hans", "zh-Hant"]
        )
        XCTAssertEqual(TranslationTarget.all.count, 25, "a code appears twice")
        XCTAssertEqual(TranslationTarget.additional.count, 21)
        XCTAssertEqual(TranslationTarget.builtIns.map(\.code), ["fr", "en", "es", "de"])
    }

    /// Apple's Apple Intelligence list for the 27.0 releases has 16 languages; the nine
    /// targets outside it are the ones with no fallback.
    func testExactlyTheNineTargetsOutsideAppleFMHaveNoFallback() {
        XCTAssertEqual(
            Set(TranslationTarget.all.filter { !$0.hasModelFallback }.map(\.code)),
            ["ar", "fi", "he", "hi", "id", "pl", "ru", "th", "uk"]
        )
        XCTAssertEqual(TranslationTarget.all.filter(\.hasModelFallback).count, 16)
    }

    /// Malay left the targets on the maintainer's decision of 2026-11-21. The framework
    /// writes it, and writes it differently from Indonesian (`minit`/`menit`,
    /// `kerana`/`karena`, `boleh`/`bisa`, six French sentences each, macOS 27.0); it is
    /// `NLLanguageRecognizer` that read all twelve outputs as `id` at 1.000. The output-
    /// language check therefore cannot tell a Malay answer from an Indonesian one, and a
    /// target ships only with a measured pass on that check. Indonesian stays: it reads
    /// as itself.
    func testMalayIsNotATargetBecauseTheLanguageCheckReadsItAsIndonesian() {
        XCTAssertNil(TranslationTarget(code: "ms"))
        XCTAssertFalse(TranslationTarget.all.contains { $0.code == "ms" })
        XCTAssertNil(SmartModeCatalogue.translateTarget(ofIdentifier: "translate.ms"))
        XCTAssertNil(SmartModeCatalogue.mode(withIdentifier: "translate.ms"))
        XCTAssertFalse(PolishGuardrail.matches(read: "id", expected: "ms"), "the ms→id exception is gone")
        XCTAssertNotNil(TranslationTarget(code: "id"))
    }

    func testOnlyTheFourDictationLanguagesAreBuiltIn() {
        XCTAssertEqual(TranslationTarget.builtIns.compactMap(\.builtIn), SupportedLanguage.allCases)
        XCTAssertTrue(TranslationTarget.additional.allSatisfy { $0.builtIn == nil })
        for language in SupportedLanguage.allCases {
            XCTAssertEqual(TranslationTarget(language).code, language.rawValue)
        }
    }

    /// The recogniser's codes, which the output check is keyed on. A wrong one rejects
    /// every translation into the language, so the four that differ from a plain
    /// two-letter guess are named one by one.
    func testTheRecognizerCodesAreTheOnesNLLanguageUses() {
        XCTAssertEqual(TranslationTarget(code: "zh-Hans")?.recognizerCode, "zh-Hans")
        XCTAssertEqual(TranslationTarget(code: "zh-Hant")?.recognizerCode, "zh-Hant")
        XCTAssertEqual(TranslationTarget(code: "nb")?.recognizerCode, "nb", "Bokmål, not the `no` macrolanguage")
        XCTAssertEqual(TranslationTarget(code: "pt")?.recognizerCode, "pt", "not pt-BR")
        XCTAssertEqual(TranslationTarget(code: "zh-Hans")?.frameworkIdentifier, "zh-Hans")
        XCTAssertEqual(TranslationTarget(code: "pt")?.frameworkIdentifier, "pt")
    }

    func testAnUnknownCodeIsNoTarget() {
        XCTAssertNil(TranslationTarget(code: "klingon"))
        XCTAssertNil(TranslationTarget(code: "zh"), "Chinese is two targets, one per script")
        XCTAssertNil(TranslationTarget(code: ""))
    }

    // MARK: - Names

    /// Names come from the system, so French reads French names with no catalogue entry.
    func testNamesComeFromTheSystemInTheUILanguage() {
        let french = Locale(identifier: "fr")
        XCTAssertEqual(TranslationTarget(code: "pt")?.localizedName(in: french), "portugais")
        XCTAssertEqual(TranslationTarget(code: "zh-Hant")?.localizedName(in: french), "chinois traditionnel")
        XCTAssertEqual(TranslationTarget(code: "pt")?.localizedName(in: Locale(identifier: "en")), "Portuguese")
    }

    func testThePromptNameReadsAsSomethingToTranslateInto() {
        XCTAssertEqual(TranslationTarget.english.englishName, "English")
        XCTAssertEqual(TranslationTarget.french.englishName, "French")
        XCTAssertEqual(TranslationTarget(code: "pt")?.englishName, "Portuguese")
        XCTAssertEqual(TranslationTarget(code: "zh-Hans")?.englishName, "Chinese (Simplified)")
        XCTAssertEqual(TranslationTarget(code: "zh-Hant")?.englishName, "Chinese (Traditional)")
        XCTAssertEqual(TranslationTarget(code: "nb")?.englishName, "Norwegian Bokmål")
    }

    /// The badge is what tells two pinned translations apart on an 18 pt disc, so no
    /// two targets may share one — the two Chinese scripts above all.
    func testEveryTargetHasItsOwnShortCode() {
        let codes = TranslationTarget.all.map(\.shortCode)
        XCTAssertEqual(Set(codes).count, codes.count)
        XCTAssertEqual(TranslationTarget.english.shortCode, "EN")
        XCTAssertEqual(TranslationTarget(code: "pt")?.shortCode, "PT")
        XCTAssertEqual(TranslationTarget(code: "zh-Hans")?.shortCode, "简")
        XCTAssertEqual(TranslationTarget(code: "zh-Hant")?.shortCode, "繁")
        XCTAssertTrue(codes.allSatisfy { $0.count <= 2 }, "a badge wider than two characters does not fit the disc")
    }

    // MARK: - The four built-in modes are unchanged

    func testTheBuiltInsAreStillExactlyTheEightModes() {
        XCTAssertEqual(
            SmartModeCatalogue.builtIns.map(\.id),
            ["structured", "notes", "message", "summary", "translate.fr", "translate.en", "translate.es", "translate.de"]
        )
    }

    /// SHA-256 of `instructions + NUL + userInstruction`, computed on `develop` @ 4ebcf0d4
    /// before #622 touched the builder.
    func testTheFourBuiltInPromptsAreByteForByteTheOnesTheyShippedWith() {
        let shipped = [
            "fr": "ca1afa327a5f06e28d64bd265ca5e2dd23a037e6c480530aad715cd1e49ae479",
            "en": "b453a55375f901c7a438fa1da28e07ad2ac154e6882d47b113fd65458bd9ca3f",
            "es": "2721c50cb5e32914669b723fa55f1b5c1371e2d5c4e7822df4f6cfd0d9ef6f29",
            "de": "0833be338068837d5ce1beb804adb01db25a78044fd3cb8b7e86656081fd2d63"
        ]
        for target in TranslationTarget.builtIns {
            let text = SmartModeTranslatePrompt.instructions(target: target) + "\u{0}"
                + SmartModeTranslatePrompt.userInstruction(target: target)
            let hash = SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(hash, shipped[target.code], "translate.\(target.code)'s prompt moved")
        }
    }

    func testTheFourBuiltInIdentifiersBadgesAndContractsAreUnchanged() throws {
        for language in SupportedLanguage.allCases {
            let mode = SmartModeCatalogue.translate(to: TranslationTarget(language))
            XCTAssertEqual(mode.id, "translate.\(language.rawValue)")
            XCTAssertEqual(mode.displayName, "\u{2192} \(language.shortCode)")
            XCTAssertEqual(mode.badge, .text(language.shortCode))
            XCTAssertEqual(mode.contract.outputLanguage.storedValue, language.rawValue)
        }
    }

    // MARK: - The prompt for a new target

    /// The examples are hand-written in four languages; for any other target they are
    /// left out, so no OUTPUT line can demonstrate the wrong language.
    func testANewTargetsPromptNamesItAndCarriesNoExampleInAnotherLanguage() throws {
        for target in TranslationTarget.additional {
            let prompt = SmartModeTranslatePrompt.instructions(target: target)
            XCTAssertTrue(prompt.contains("OUTPUT LANGUAGE: \(target.englishName)."), target.code)
            XCTAssertFalse(prompt.contains("OUTPUT:"), "\(target.code) carries a worked example")
            XCTAssertFalse(prompt.contains("RIGHT:"), "\(target.code) carries a counter-example")
            XCTAssertFalse(prompt.contains("Hey, I'm running late"), "\(target.code) carries an English output line")
            XCTAssertFalse(prompt.contains("Salut, je suis en retard"), "\(target.code) carries a French output line")
            XCTAssertTrue(prompt.contains("TEXT TRANSFORMATION FUNCTION"))
            XCTAssertEqual(SmartModeTranslatePrompt.userInstruction(target: target),
                           "Translate this text into \(target.englishName). Output only the translation, nothing else.")
        }
    }

    func testTheFourBuiltInsKeepTheirExamplesInTheirOwnLanguage() {
        let prompt = SmartModeTranslatePrompt.instructions(target: .english)
        XCTAssertTrue(prompt.contains("OUTPUT: Hey, I'm running late, I'll be there in fifteen minutes."))
    }

    // MARK: - Modes and identifiers

    func testEveryTargetIsAModeThatResolvesBackToItsTarget() {
        for target in TranslationTarget.all {
            let identifier = SmartModeCatalogue.translateIdentifier(target: target)
            XCTAssertEqual(identifier, "translate.\(target.code)")
            XCTAssertEqual(SmartModeCatalogue.translateTarget(ofIdentifier: identifier), target)
            XCTAssertEqual(SmartModeCatalogue.resolve(identifier: identifier)?.id, identifier)
            XCTAssertEqual(TranslationLanguagePair.translateTarget(of: SmartModeCatalogue.translate(to: target)), target)
            XCTAssertEqual(SmartModeCatalogue.translate(to: target).floorBehaviour, .insertNothing,
                           "translate.\(target.code) must never insert the input language")
        }
        XCTAssertNil(SmartModeCatalogue.translateTarget(ofIdentifier: "notes"))
        XCTAssertNil(SmartModeCatalogue.translateTarget(ofIdentifier: "translate.klingon"))
        XCTAssertNil(SmartModeCatalogue.resolve(identifier: "translate.klingon"))
    }

    /// The contract crosses the App Group in the armed snapshot. A new target's code
    /// round-trips; an old build reading it would throw, which is the fail-closed answer.
    func testTheContractStoresTheTargetCodeAndReadsItBack() throws {
        for target in TranslationTarget.all {
            let stored = PolishOutputLanguage.fixed(target).storedValue
            XCTAssertEqual(stored, target.code)
            XCTAssertEqual(try PolishOutputLanguage(storedValue: stored), .fixed(target))
        }
        XCTAssertThrowsError(try PolishOutputLanguage(storedValue: "klingon"))

        let mode = SmartModeCatalogue.translate(to: try XCTUnwrap(TranslationTarget(code: "zh-Hant")))
        let decoded = try JSONDecoder().decode(SmartMode.self, from: JSONEncoder().encode(mode))
        XCTAssertEqual(decoded.contract.outputLanguage, mode.contract.outputLanguage)
        XCTAssertEqual(decoded.id, "translate.zh-Hant")
        XCTAssertEqual(decoded.badge, .text("繁"))
    }

    /// Measured on the real framework: a correct Chinese, Japanese or Korean translation
    /// of a French sentence is 0.25 to 0.51 of its length, so those four get a lower
    /// floor. Every other target, the four built-ins included, keeps 0.4.
    func testOnlyTheCompactScriptsGetALowerLengthFloor() {
        for target in TranslationTarget.all {
            let expected = ["ja", "ko", "zh-Hans", "zh-Hant"].contains(target.code) ? 0.15 : 0.4
            XCTAssertEqual(SmartModeCatalogue.translate(to: target).contract.minimumLengthRatio, expected, target.code)
            XCTAssertEqual(SmartModeCatalogue.translate(to: target).contract.maximumLengthRatio, 3.0, target.code)
        }
    }

    /// The measured shortest correct output (zh-Hant, 12 of 48 characters) is accepted;
    /// an output cut to a word is not.
    func testTheChineseFloorAcceptsTheMeasuredTranslationAndRefusesACutOne() throws {
        let contract = SmartModeCatalogue.translate(to: try XCTUnwrap(TranslationTarget(code: "zh-Hant"))).contract
        let input = "Je suis en retard, j'arrive dans quinze minutes."
        XCTAssertTrue(PolishGuardrail.accepts(raw: input, polished: "我遲到了，十五分鐘後到。", contract: contract))
        XCTAssertFalse(PolishGuardrail.accepts(raw: input, polished: "我遲到", contract: contract))
    }

    /// A new target gets no typography post-pass: the rules exist for the four only.
    func testANewTargetGetsNoTypographyAndABuiltInKeepsItsOwn() throws {
        let portuguese = try XCTUnwrap(TranslationTarget(code: "pt"))
        let toPortuguese = PolishJob(task: .smart(SmartModeCatalogue.translate(to: portuguese)),
                                     promptLanguage: .french, languageAgnosticPath: false)
        XCTAssertNil(toPortuguese.typographyLanguage)
        let toGerman = PolishJob(task: .smart(SmartModeCatalogue.translate(to: .german)),
                                 promptLanguage: .french, languageAgnosticPath: false)
        XCTAssertEqual(toGerman.typographyLanguage, .german)
    }

    // MARK: - Language pair

    func testThePairComparesLanguagesNotScripts() throws {
        let traditional = try XCTUnwrap(TranslationTarget(code: "zh-Hant"))
        XCTAssertNil(TranslationLanguagePair(source: "zh", target: traditional),
                     "the framework reads zh → zh-Hant as unsupported, measured 2026-11-21")
        XCTAssertNotNil(TranslationLanguagePair(source: "fr", target: traditional))
        let portuguese = try XCTUnwrap(TranslationTarget(code: "pt"))
        XCTAssertNil(TranslationLanguagePair(source: "pt-BR", target: portuguese))
        XCTAssertNotNil(TranslationLanguagePair(source: "es", target: portuguese))
    }
}
