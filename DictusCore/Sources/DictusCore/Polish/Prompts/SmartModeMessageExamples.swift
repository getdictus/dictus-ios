// DictusCore/Sources/DictusCore/Polish/Prompts/SmartModeMessageExamples.swift
// Message's two worked examples in every Apple FM language (#572, #587 decision 9).
import Foundation

/// Step 2 of #587 decision 5, applied to `Message`.
///
/// ### Why the examples move and nothing else does
///
/// `Message` shipped with two French examples, and #585 is the measurement that makes
/// that a defect rather than a detail: the model reads the examples as the template,
/// their language included. #587 measured step 1 — English rules plus a language rule —
/// failing on `Structuré` (a Danish dictation translated into English, 3 of 3) and on
/// `Résumé` (55 outputs of 130 in English across 13 languages), and step 2 — the same
/// rules with the examples translated — holding at 0 % refused on `check=language` in
/// all 16 Apple FM languages. So this table exists and the rules do not change.
///
/// **Nothing else about `Message` moves in that PR** (decision 9): not a rule, not the
/// `0.2…1.1` band, not the user turn, not the short-block pass. Pierre sends messages
/// with this mode daily, and the French set below is his shipping prompt's two examples
/// **byte for byte**, so a French dictation sends exactly the prompt it sends today.
///
/// ### What every set has to keep
///
/// - **The same two scenes**: a two-beat message about a borrowed lawnmower, which
///   loses its hesitation and its self-correction, and a three-word greeting-question
///   that comes back untouched.
/// - **A borrowed `Hello`** in the second scene, in every language. That example exists
///   to show rule 3: a word the speaker said in another language stays as they said it,
///   and the greeting is not translated into the local one. `note` is the sentence that
///   says so, and it quotes that language's own wrong answer.
/// - **No person named, no greeting or sign-off invented**, for the #414 and #572 bar-2
///   reasons `SmartModeMessagePrompt` gives: an example's content reaches user output,
///   and this is the mode nearest the invented-greeting failure that cut Email.
///
/// Machine-translated by the agent that wrote #587's PR 2, from the French originals,
/// keeping the spoken register of the input. A native speaker may find them stiff; they
/// are measured for the output language, not for style.
///
/// Keys are `NLLanguage` base subtags, the 15 languages `SystemLanguageModel` listed on
/// 2026-09-21. `zh` is Simplified, and a `zh-Hant` transcript gets it: the closest set
/// the table has rather than a claim that it is right.
enum SmartModeMessageExamples {

    typealias Set = SmartModeMessagePrompt.ExampleSet

    static let byLanguage: [String: Set] = [
        "fr": Set(
            casualInput: "coucou toi euh j'ai récupéré la tondeuse chez le voisin, je te la ramène demain matin, enfin non demain soir, je sais pas encore à quelle heure, à plus",
            casualOutput: "Coucou toi, j'ai récupéré la tondeuse chez le voisin\n\nJe te la ramène demain soir, je sais pas encore à quelle heure, à plus",
            greetingInput: "Hello chef, comment tu vas ?",
            greetingOutput: "Hello chef, comment tu vas ?",
            note: "That second one comes back whole because every word of it is addressed to the person. \"Salut chef, comment tu vas ?\" would be wrong: it changes their greeting. Answering the question would be wrong too."
        ),
        "en": Set(
            casualInput: "hey you uh I picked up the lawnmower from the neighbour, I'll bring it back tomorrow morning, no wait tomorrow evening, I don't know what time yet, see you",
            casualOutput: "Hey you, I picked up the lawnmower from the neighbour\n\nI'll bring it back tomorrow evening, I don't know what time yet, see you",
            greetingInput: "Hello boss, how are you doing?",
            greetingOutput: "Hello boss, how are you doing?",
            note: "That second one comes back whole because every word of it is addressed to the person. \"Hi boss, how are you doing?\" would be wrong: it changes their greeting. Answering the question would be wrong too."
        ),
        "de": Set(
            casualInput: "hallo du ähm ich hab den Rasenmäher beim Nachbarn abgeholt, ich bring ihn dir morgen früh zurück, also nein morgen Abend, ich weiß noch nicht um wie viel Uhr, bis dann",
            casualOutput: "Hallo du, ich hab den Rasenmäher beim Nachbarn abgeholt\n\nIch bring ihn dir morgen Abend zurück, ich weiß noch nicht um wie viel Uhr, bis dann",
            greetingInput: "Hello Chef, wie geht's dir?",
            greetingOutput: "Hello Chef, wie geht's dir?",
            note: "That second one comes back whole because every word of it is addressed to the person. \"Hallo Chef, wie geht's dir?\" would be wrong: it changes their greeting. Answering the question would be wrong too."
        ),
        "es": Set(
            casualInput: "hola eh he recogido el cortacésped en casa del vecino, te lo devuelvo mañana por la mañana, bueno no mañana por la noche, todavía no sé a qué hora, hasta luego",
            casualOutput: "Hola, he recogido el cortacésped en casa del vecino\n\nTe lo devuelvo mañana por la noche, todavía no sé a qué hora, hasta luego",
            greetingInput: "Hello jefe, ¿qué tal estás?",
            greetingOutput: "Hello jefe, ¿qué tal estás?",
            note: "That second one comes back whole because every word of it is addressed to the person. \"Hola jefe, ¿qué tal estás?\" would be wrong: it changes their greeting. Answering the question would be wrong too."
        ),
        "it": Set(
            casualInput: "ciao ehm ho preso il tosaerba dal vicino, te lo riporto domani mattina, anzi no domani sera, non so ancora a che ora, a dopo",
            casualOutput: "Ciao, ho preso il tosaerba dal vicino\n\nTe lo riporto domani sera, non so ancora a che ora, a dopo",
            greetingInput: "Hello capo, come stai?",
            greetingOutput: "Hello capo, come stai?",
            note: "That second one comes back whole because every word of it is addressed to the person. \"Ciao capo, come stai?\" would be wrong: it changes their greeting. Answering the question would be wrong too."
        ),
        "pt": Set(
            casualInput: "oi é peguei o cortador de grama na casa do vizinho, devolvo pra você amanhã de manhã, quer dizer não amanhã à noite, ainda não sei a que horas, até mais",
            casualOutput: "Oi, peguei o cortador de grama na casa do vizinho\n\nDevolvo pra você amanhã à noite, ainda não sei a que horas, até mais",
            greetingInput: "Hello chefe, como você está?",
            greetingOutput: "Hello chefe, como você está?",
            note: "That second one comes back whole because every word of it is addressed to the person. \"Oi chefe, como você está?\" would be wrong: it changes their greeting. Answering the question would be wrong too."
        ),
        "nl": Set(
            casualInput: "hoi eh ik heb de grasmaaier bij de buren opgehaald, ik breng hem morgenochtend terug, nee wacht morgenavond, ik weet nog niet hoe laat, tot later",
            casualOutput: "Hoi, ik heb de grasmaaier bij de buren opgehaald\n\nIk breng hem morgenavond terug, ik weet nog niet hoe laat, tot later",
            greetingInput: "Hello baas, hoe gaat het met je?",
            greetingOutput: "Hello baas, hoe gaat het met je?",
            note: "That second one comes back whole because every word of it is addressed to the person. \"Hoi baas, hoe gaat het met je?\" would be wrong: it changes their greeting. Answering the question would be wrong too."
        ),
        "da": Set(
            casualInput: "hej dig øh jeg har hentet plæneklipperen hos naboen, jeg kommer med den i morgen tidlig, altså nej i morgen aften, jeg ved ikke hvornår endnu, vi ses",
            casualOutput: "Hej dig, jeg har hentet plæneklipperen hos naboen\n\nJeg kommer med den i morgen aften, jeg ved ikke hvornår endnu, vi ses",
            greetingInput: "Hello chef, hvordan går det med dig?",
            greetingOutput: "Hello chef, hvordan går det med dig?",
            note: "That second one comes back whole because every word of it is addressed to the person. \"Hej chef, hvordan går det med dig?\" would be wrong: it changes their greeting. Answering the question would be wrong too."
        ),
        "nb": Set(
            casualInput: "hei du eh jeg har hentet gressklipperen hos naboen, jeg kommer med den i morgen tidlig, nei forresten i morgen kveld, jeg vet ikke når ennå, vi ses",
            casualOutput: "Hei du, jeg har hentet gressklipperen hos naboen\n\nJeg kommer med den i morgen kveld, jeg vet ikke når ennå, vi ses",
            greetingInput: "Hello sjef, hvordan går det med deg?",
            greetingOutput: "Hello sjef, hvordan går det med deg?",
            note: "That second one comes back whole because every word of it is addressed to the person. \"Hei sjef, hvordan går det med deg?\" would be wrong: it changes their greeting. Answering the question would be wrong too."
        ),
        "sv": Set(
            casualInput: "hej du eh jag har hämtat gräsklipparen hos grannen, jag kommer med den i morgon bitti, nej förresten i morgon kväll, jag vet inte när än, vi hörs",
            casualOutput: "Hej du, jag har hämtat gräsklipparen hos grannen\n\nJag kommer med den i morgon kväll, jag vet inte när än, vi hörs",
            greetingInput: "Hello chefen, hur mår du?",
            greetingOutput: "Hello chefen, hur mår du?",
            note: "That second one comes back whole because every word of it is addressed to the person. \"Hej chefen, hur mår du?\" would be wrong: it changes their greeting. Answering the question would be wrong too."
        ),
        "tr": Set(
            casualInput: "selam ıı çim biçme makinesini komşudan aldım, sana yarın sabah getiririm, yok yarın akşam, saat kaçta bilmiyorum daha, görüşürüz",
            casualOutput: "Selam, çim biçme makinesini komşudan aldım\n\nSana yarın akşam getiririm, saat kaçta bilmiyorum daha, görüşürüz",
            greetingInput: "Hello patron, nasılsın?",
            greetingOutput: "Hello patron, nasılsın?",
            note: "That second one comes back whole because every word of it is addressed to the person. \"Selam patron, nasılsın?\" would be wrong: it changes their greeting. Answering the question would be wrong too."
        ),
        "vi": Set(
            casualInput: "này ờ tôi lấy cái máy cắt cỏ ở nhà hàng xóm rồi, mai sáng tôi mang trả cho bạn, à không mai tối, chưa biết mấy giờ, gặp lại sau nhé",
            casualOutput: "Này, tôi lấy cái máy cắt cỏ ở nhà hàng xóm rồi\n\nMai tối tôi mang trả cho bạn, chưa biết mấy giờ, gặp lại sau nhé",
            greetingInput: "Hello sếp, sếp khỏe không?",
            greetingOutput: "Hello sếp, sếp khỏe không?",
            note: "That second one comes back whole because every word of it is addressed to the person. \"Chào sếp, sếp khỏe không?\" would be wrong: it changes their greeting. Answering the question would be wrong too."
        ),
        "ja": Set(
            casualInput: "やっほー えっと 隣の人から芝刈り機借りてきたよ、明日の朝返すね、あ違う明日の夜、何時かはまだわかんない、じゃあね",
            casualOutput: "やっほー、隣の人から芝刈り機借りてきたよ\n\n明日の夜返すね、何時かはまだわかんない、じゃあね",
            greetingInput: "Hello 部長、元気ですか？",
            greetingOutput: "Hello 部長、元気ですか？",
            note: "That second one comes back whole because every word of it is addressed to the person. \"こんにちは部長、元気ですか？\" would be wrong: it changes their greeting. Answering the question would be wrong too."
        ),
        "ko": Set(
            casualInput: "안녕 음 옆집에서 잔디깎이 가져왔어, 내일 아침에 갖다줄게, 아니 내일 저녁에, 몇 시인지는 아직 몰라, 나중에 봐",
            casualOutput: "안녕, 옆집에서 잔디깎이 가져왔어\n\n내일 저녁에 갖다줄게, 몇 시인지는 아직 몰라, 나중에 봐",
            greetingInput: "Hello 팀장님, 잘 지내세요?",
            greetingOutput: "Hello 팀장님, 잘 지내세요?",
            note: "That second one comes back whole because every word of it is addressed to the person. \"안녕하세요 팀장님, 잘 지내세요?\" would be wrong: it changes their greeting. Answering the question would be wrong too."
        ),
        "zh": Set(
            casualInput: "嗨 那个 我从邻居家把割草机拿回来了，明天早上给你送过去，不对是明天晚上，几点还不知道，回头见",
            casualOutput: "嗨，我从邻居家把割草机拿回来了\n\n明天晚上给你送过去，几点还不知道，回头见",
            greetingInput: "Hello 老大，你最近怎么样？",
            greetingOutput: "Hello 老大，你最近怎么样？",
            note: "That second one comes back whole because every word of it is addressed to the person. \"你好老大，你最近怎么样？\" would be wrong: it changes their greeting. Answering the question would be wrong too."
        )
    ]

    /// The set for a transcript in `languageCode` (an `NLLanguage` raw value such as
    /// `de`, `zh-Hans`, `pt-BR`), or nil when the table has none.
    static func set(forLanguageCode languageCode: String) -> Set? {
        let base = languageCode.split(separator: "-").first.map { String($0).lowercased() } ?? ""
        return byLanguage[base]
    }
}
