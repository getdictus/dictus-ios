// DictusCore/Tests/DictusCoreTests/Polish/TranslationTargetGuardrailTests.swift
// The output-language check on a correct translation into each new target (issue #622).
import XCTest
@testable import DictusCore

/// #622's acceptance item: "each shipped target has a measured pass on the language
/// check, short and long input".
///
/// ### Where the sentences come from
///
/// Every sentence below is **what Apple's Translation framework wrote**, not a
/// translation written for the test: macOS 27.0, Apple Intelligence on, `.highFidelity`,
/// `TranslationSession(installedSource: fr, target: <code>)`, run on 2026-11-21. The
/// French inputs were `Je suis en retard, j'arrive dans quinze minutes.` (short) and
/// `Je t'envoie le document ce soir, on en reparle demain matin si tu veux.` (long).
/// So the check is measured on the text it will actually be handed in the keyboard.
///
/// ### Why a pass is not enough on its own
///
/// Below 12 characters, or under the confidence floor, the check passes without reading
/// anything. A target whose sentences all passed that way would prove nothing, so each
/// target is also checked to **refuse** its own translation when a different language is
/// expected. That is what shows the recogniser read the text, and read it as this code.
final class TranslationTargetGuardrailTests: XCTestCase {

    /// (code, short, long), as the framework wrote them.
    private let measured: [(String, String, String)] = [
        ("ar", "أنا متأخر، سأصل خلال خمس عشرة دقيقة.",
         "سأرسل لك الوثيقة الليلة، وسنتحدث عنها مرة أخرى غدًا صباحًا إذا أردت."),
        ("da", "Jeg er forsinket, jeg ankommer om femten minutter.",
         "Jeg sender dig dokumentet i aften, vi taler om det igen i morgen tidlig, hvis du vil."),
        ("fi", "Olen myöhässä, saavun viidentoista minuutin kuluttua.",
         "Lähetän sinulle asiakirjan tänä iltana, puhumme siitä uudelleen huomenna aamulla, jos haluat."),
        ("he", "אני מאחר, אני מגיע בעוד חמש עשרה דקות.",
         "אשלח לך את המסמך הערב, נדבר עליו שוב מחר בבוקר אם תרצה."),
        ("hi", "मैं देर से आ रहा हूँ, मैं पंद्रह मिनट में पहुँचूँगा।",
         "मैं तुम्हें यह दस्तावेज़ आज रात भेज रहा हूँ, अगर तुम चाहो तो हम कल सुबह इसके बारे में फिर बात करेंगे।"),
        ("id", "Saya terlambat, saya sampai dalam lima belas menit.",
         "Saya akan mengirimkan dokumennya kepadamu malam ini, kita akan membicarakannya lagi besok pagi jika kamu mau."),
        ("it", "Sono in ritardo, arrivo tra quindici minuti.",
         "Ti invio il documento stasera, ne parliamo domani mattina se vuoi."),
        ("ja", "遅れています、15分後に到着します。",
         "今夜その文書を送ります。もしよければ、明日の朝また話しましょう。"),
        ("ko", "늦었어요, 15분 후에 도착할게요.",
         "오늘 저녁에 문서를 보내줄게, 원하면 내일 아침에 다시 얘기하자."),
        ("ms", "Saya terlambat, saya akan tiba dalam lima belas minit.",
         "Saya akan menghantar dokumen itu kepada anda malam ini, kita boleh membincangkannya lagi esok pagi jika anda mahu."),
        ("nb", "Jeg er forsinket, jeg kommer om femten minutter.",
         "Jeg sender deg dokumentet i kveld, vi snakkes om det i morgen tidlig hvis du vil."),
        ("nl", "Ik ben te laat, ik kom over vijftien minuten aan.",
         "Ik stuur je het document vanavond, we praten er morgenochtend nog eens over als je wilt."),
        ("pl", "Jestem spóźniony, przyjadę za piętnaście minut.",
         "Wyślę ci dokument dziś wieczorem, omówimy go jutro rano, jeśli chcesz."),
        ("pt", "Estou atrasado, chego em quinze minutos.",
         "Eu te envio o documento esta noite, conversamos sobre isso amanhã de manhã se você quiser."),
        ("ru", "Я опоздал, прибуду через пятнадцать минут.",
         "Я отправлю тебе документ сегодня вечером, поговорим о нём завтра утром, если хочешь."),
        ("sv", "Jag är försenad, jag kommer om femton minuter.",
         "Jag skickar dokumentet till dig ikväll, vi pratar om det imorgon bitti om du vill."),
        ("th", "ฉันสายมา ฉันจะมาถึงในอีกสิบห้านาที",
         "ฉันจะส่งเอกสารให้คุณคืนนี้ เราคุยกันเรื่องนี้อีกพรุ่งนี้เช้าถ้าคุณต้องการ"),
        ("tr", "Geç kaldım, on beş dakika içinde varacağım.",
         "Sana bu akşam belgeyi göndereceğim, istersen yarın sabah tekrar konuşuruz."),
        ("uk", "Я запізнююсь, приїду за п'ятнадцять хвилин.",
         "Я надішлю тобі документ сьогодні ввечері, поговоримо про нього завтра вранці, якщо хочеш."),
        ("vi", "Tôi đến muộn, tôi sẽ đến trong mười lăm phút nữa.",
         "Tôi sẽ gửi cho bạn tài liệu tối nay, chúng ta sẽ nói lại vào sáng mai nếu bạn muốn."),
        ("zh-Hans", "我迟到了，我十五分钟后到。",
         "我今晚把文件发给你，如果你愿意，我们明天早上再谈。"),
        ("zh-Hant", "我遲到了，十五分鐘後到。",
         "我今晚把文件發給你，如果你願意，我們明天早上再談。")
    ]

    func testTheMeasuredSetCoversEveryNewTarget() {
        XCTAssertEqual(measured.map(\.0), TranslationTarget.additional.map(\.code))
    }

    /// The acceptance item itself: a correct translation, short and long, is accepted.
    func testACorrectTranslationIntoEachNewTargetIsAccepted() throws {
        for (code, short, long) in measured {
            let target = try XCTUnwrap(TranslationTarget(code: code))
            XCTAssertGreaterThanOrEqual(short.count, 12, "\(code)'s short sentence would pass unread")
            XCTAssertTrue(PolishGuardrail.detectedLanguageMatches(polished: short, translationTarget: target),
                          "the short \(code) translation is refused")
            XCTAssertTrue(PolishGuardrail.detectedLanguageMatches(polished: long, translationTarget: target),
                          "the long \(code) translation is refused")
        }
    }

    /// The same sentences refused when French is expected: the check read them, rather
    /// than passing them unread. French is the input language of every measured pair,
    /// so this is also the "forgot to translate" direction turned around.
    func testEachNewTargetsTranslationIsReadAndNotPassedThrough() throws {
        for (code, short, long) in measured {
            XCTAssertFalse(PolishGuardrail.detectedLanguageMatches(polished: short, translationTarget: .french),
                           "\(code)'s short sentence passed a French check unread")
            XCTAssertFalse(PolishGuardrail.detectedLanguageMatches(polished: long, translationTarget: .french),
                           "\(code)'s long sentence passed a French check unread")
        }
    }

    /// The code mapping, where a wrong one would be silent: each Chinese script is told
    /// from the other, and `zh` would have matched neither.
    func testTheTwoChineseScriptsAreToldApart() throws {
        let simplified = try XCTUnwrap(TranslationTarget(code: "zh-Hans"))
        let traditional = try XCTUnwrap(TranslationTarget(code: "zh-Hant"))
        let simplifiedText = "我今晚把文件发给你，如果你愿意，我们明天早上再谈。"
        let traditionalText = "我今晚把文件發給你，如果你願意，我們明天早上再談。"
        XCTAssertTrue(PolishGuardrail.detectedLanguageMatches(polished: simplifiedText, translationTarget: simplified))
        XCTAssertFalse(PolishGuardrail.detectedLanguageMatches(polished: simplifiedText, translationTarget: traditional))
        XCTAssertTrue(PolishGuardrail.detectedLanguageMatches(polished: traditionalText, translationTarget: traditional))
        XCTAssertFalse(PolishGuardrail.detectedLanguageMatches(polished: traditionalText, translationTarget: simplified))
        XCTAssertFalse(PolishGuardrail.matches(read: "zh-Hans", expected: "zh"))
    }

    /// Portuguese is the language #598 saw confused with Spanish. The framework's
    /// Portuguese is refused for a Spanish target and the reverse, so adding it did not
    /// open that hole. The Spanish sentence is a hand-written control, the one line in
    /// this file the framework did not write.
    func testPortugueseAndSpanishStayApart() throws {
        let portuguese = try XCTUnwrap(TranslationTarget(code: "pt"))
        let portugueseText = "Eu te envio o documento esta noite, conversamos sobre isso amanhã de manhã se você quiser."
        let spanishText = "Te envío el documento esta noche, lo hablamos mañana por la mañana si quieres."
        XCTAssertFalse(PolishGuardrail.detectedLanguageMatches(polished: portugueseText, translationTarget: .spanish))
        XCTAssertFalse(PolishGuardrail.detectedLanguageMatches(polished: spanishText, translationTarget: portuguese))
    }

    /// The one exception #622 adds, and its direction. The framework's Malay reads as
    /// `id` at 1.000 on all four measured sentences, so `ms` accepts `id`; Indonesian
    /// is not widened.
    func testMalayAcceptsAnIndonesianReadingAndOnlyMalayDoes() {
        XCTAssertTrue(PolishGuardrail.matches(read: "id", expected: "ms"))
        XCTAssertFalse(PolishGuardrail.matches(read: "ms", expected: "id"))
        XCTAssertFalse(PolishGuardrail.matches(read: "id", expected: "fr"))
    }

    /// Norwegian is stored as `nb`; the Scandinavian set is what lets a Bokmål sentence
    /// the recogniser half-reads as Danish (`nb` 0.807, `da` 0.193) through.
    func testBokmalUsesTheScandinavianSetAndNotTheMacrolanguage() {
        XCTAssertTrue(PolishGuardrail.matches(read: "da", expected: "nb"))
        XCTAssertTrue(PolishGuardrail.matches(read: "nb", expected: "nb"))
    }

    /// Through the pipeline, which is where the check runs: a framework translation
    /// into Portuguese is accepted, the same text handed back untranslated is refused.
    func testThePipelineAcceptsAPortugueseTranslationAndRefusesTheUntranslatedInput() async throws {
        let portuguese = try XCTUnwrap(TranslationTarget(code: "pt"))
        let french = "Je t'envoie le document ce soir, on en reparle demain matin si tu veux."
        let job = PolishJob(task: .smart(SmartModeCatalogue.translate(to: portuguese)),
                            promptLanguage: .french, languageAgnosticPath: false)
        let accepted = await PolishPipeline.transform(
            preprocessed: french,
            engine: FixedTranslation(output: "Eu te envio o documento esta noite, conversamos sobre isso amanhã de manhã se você quiser."),
            job: job
        )
        XCTAssertEqual(accepted.outcome, .success)
        let refused = await PolishPipeline.transform(preprocessed: french, engine: FixedTranslation(output: french), job: job)
        XCTAssertEqual(refused.outcome, .rejectedGuardrail)
        XCTAssertNil(PolishPipeline.resolvedOutput(refused, preprocessed: french, job: job),
                     "a refused translation inserts nothing, never the French")
    }
}

/// An engine that answers one fixed text, standing in for the framework's output.
private struct FixedTranslation: PolishEngineProtocol {
    let identifier = "fixed-translation"
    let output: String
    func polish(raw: String, targetLanguage: SupportedLanguage, task: PolishTask) async throws -> String { output }
}
