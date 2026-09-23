// DictusCore/Sources/DictusCore/Polish/Prompts/SmartModeStructuredExamples.swift
import Foundation

/// The two worked examples `SmartModeStructuredPrompt` shows, one set per Apple FM
/// language (#587, decision 5 step 2).
///
/// ### Why one set per language
///
/// The model reads the examples as the template, their language included. With one
/// French and one English example, the short prompt translated a Danish dictation into
/// English 3 of 3 and a French one once in 72, always into the language of the last
/// example; #571 measured the same mechanism at 28 of 40 on `Résumé` and 0 of 40 once
/// both examples were in the transcript's language. So the rules stay one English text
/// and only these two examples change with the language.
///
/// ### What every set must keep (#587, decisions 4 and 7)
///
/// - **The same two examples, translated**, not rewritten per language: a prose
///   dictation that stays prose, and a genuine enumeration — the speaker counts off
///   three things — that becomes a short list inside a paragraph. That contrast is
///   decision 7's whole demonstration.
/// - **No example acts out a risky rule.** No sentence about the speaker's memory
///   (#581's leak), no heading, no person named, and content off-domain — a bike, a
///   trip — so a copied line reads as not the speaker's.
/// - **The input stays spoken** (hesitations, a self-correction, a trailing hedge) and
///   the output written, in that language's own conventions.
///
/// The sets were machine-translated from the French and English originals by the agent
/// that wrote the prompt. They have not been read by a native speaker of any language
/// but those two.
///
/// Keys are `NLLanguage` codes, the namespace the transcript's detected language comes
/// in; Chinese has two sets because Simplified and Traditional are two codes there.
struct SmartModeStructuredExamples: Equatable {

    /// A rambling dictation with a self-correction and a hedge, which stays prose.
    let proseInput: String
    let proseOutput: String
    /// A dictation that enumerates three things, which becomes a short list.
    let enumerationInput: String
    let enumerationOutput: String

    /// The mixed pair the prompt was first measured with (C1 in
    /// `docs/research/587-structured-rewrite/`): French prose, English enumeration.
    /// Sent when the transcript's language is unknown or has no set of its own.
    static let fallback = SmartModeStructuredExamples(
        proseInput: french.proseInput, proseOutput: french.proseOutput,
        enumerationInput: english.enumerationInput, enumerationOutput: english.enumerationOutput
    )

    static let byLanguage: [String: SmartModeStructuredExamples] = [
        "fr": french, "en": english, "de": german, "es": spanish, "it": italian,
        "pt": portuguese, "nl": dutch, "da": danish, "nb": norwegian, "sv": swedish,
        "tr": turkish, "vi": vietnamese, "ja": japanese, "ko": korean,
        "zh-Hans": simplifiedChinese, "zh-Hant": traditionalChinese
    ]

    // MARK: - The sets

    static let french = SmartModeStructuredExamples(
        proseInput: "bon alors en fait euh le vélo il est réparé, enfin la roue arrière, le frein je l'ai pas encore changé. et du coup je pense que je le reprends samedi parce que le magasin ferme tôt en semaine, enfin je crois",
        proseOutput: "Le vélo est réparé, du moins la roue arrière : je n'ai pas encore changé le frein.\n\nJe pense le reprendre samedi, parce que le magasin ferme tôt en semaine, je crois.",
        enumerationInput: "alors pour le voyage il me faut encore trois trucs, euh les passeports, le chargeur de l'appareil photo et les billets pour le ferry, et l'hôtel je l'ai réservé hier donc c'est bon",
        enumerationOutput: "Pour le voyage, il me faut encore trois choses :\n- les passeports\n- le chargeur de l'appareil photo\n- les billets pour le ferry\n\nJ'ai réservé l'hôtel hier, donc c'est fait."
    )

    static let english = SmartModeStructuredExamples(
        proseInput: "ok so um the bike is fixed, well the back wheel, the brake I haven't changed it yet. and so I think I'll pick it up on saturday because the shop closes early on weekdays, I think anyway",
        proseOutput: "The bike is fixed, at least the back wheel: I haven't changed the brake yet.\n\nI think I'll pick it up on Saturday, because the shop closes early on weekdays, I think.",
        enumerationInput: "so for the trip I still need three things, uh the passports, the charger for the camera and the tickets for the ferry, and I booked the hotel yesterday so that's done",
        enumerationOutput: "For the trip, I still need three things:\n- the passports\n- the camera charger\n- the ferry tickets\n\nI booked the hotel yesterday, so that's done."
    )

    static let german = SmartModeStructuredExamples(
        proseInput: "also ähm das Fahrrad ist repariert, also das Hinterrad, die Bremse hab ich noch nicht gewechselt. und dann denk ich, ich hol es am Samstag ab, weil der Laden unter der Woche früh zumacht, glaub ich jedenfalls",
        proseOutput: "Das Fahrrad ist repariert, zumindest das Hinterrad: Die Bremse habe ich noch nicht gewechselt.\n\nIch denke, ich hole es am Samstag ab, weil der Laden unter der Woche früh schließt, glaube ich.",
        enumerationInput: "also für die Reise brauch ich noch drei Sachen, äh die Pässe, das Ladegerät für die Kamera und die Tickets für die Fähre, und das Hotel hab ich gestern gebucht, das ist also erledigt",
        enumerationOutput: "Für die Reise brauche ich noch drei Dinge:\n- die Pässe\n- das Ladegerät für die Kamera\n- die Tickets für die Fähre\n\nDas Hotel habe ich gestern gebucht, das ist also erledigt."
    )

    static let spanish = SmartModeStructuredExamples(
        proseInput: "bueno pues eh la bici ya está arreglada, bueno la rueda de atrás, el freno todavía no lo he cambiado. y entonces creo que la recojo el sábado porque la tienda cierra pronto entre semana, bueno eso creo",
        proseOutput: "La bici ya está arreglada, al menos la rueda de atrás: todavía no he cambiado el freno.\n\nCreo que la recogeré el sábado, porque la tienda cierra pronto entre semana, creo.",
        enumerationInput: "entonces para el viaje todavía me faltan tres cosas, eh los pasaportes, el cargador de la cámara y los billetes del ferri, y el hotel lo reservé ayer así que eso ya está",
        enumerationOutput: "Para el viaje, todavía me faltan tres cosas:\n- los pasaportes\n- el cargador de la cámara\n- los billetes del ferri\n\nReservé el hotel ayer, así que eso ya está."
    )

    static let italian = SmartModeStructuredExamples(
        proseInput: "allora ehm la bici è riparata, cioè la ruota posteriore, il freno non l'ho ancora cambiato. e quindi penso che la ritiro sabato perché il negozio chiude presto durante la settimana, almeno credo",
        proseOutput: "La bici è riparata, almeno la ruota posteriore: il freno non l'ho ancora cambiato.\n\nPenso di ritirarla sabato, perché il negozio chiude presto durante la settimana, credo.",
        enumerationInput: "allora per il viaggio mi servono ancora tre cose, ehm i passaporti, il caricatore della macchina fotografica e i biglietti per il traghetto, e l'hotel l'ho prenotato ieri quindi è fatto",
        enumerationOutput: "Per il viaggio mi servono ancora tre cose:\n- i passaporti\n- il caricatore della macchina fotografica\n- i biglietti per il traghetto\n\nHo prenotato l'hotel ieri, quindi è fatto."
    )

    static let portuguese = SmartModeStructuredExamples(
        proseInput: "então é a bicicleta está consertada, quer dizer a roda de trás, o freio eu ainda não troquei. e aí acho que vou buscar no sábado porque a loja fecha cedo durante a semana, pelo menos eu acho",
        proseOutput: "A bicicleta está consertada, pelo menos a roda de trás: ainda não troquei o freio.\n\nAcho que vou buscá-la no sábado, porque a loja fecha cedo durante a semana, eu acho.",
        enumerationInput: "então pra viagem ainda preciso de três coisas, é os passaportes, o carregador da câmera e as passagens do ferry, e o hotel eu reservei ontem então isso já está feito",
        enumerationOutput: "Para a viagem, ainda preciso de três coisas:\n- os passaportes\n- o carregador da câmera\n- as passagens do ferry\n\nReservei o hotel ontem, então isso já está feito."
    )

    static let dutch = SmartModeStructuredExamples(
        proseInput: "nou eh de fiets is gerepareerd, nou ja het achterwiel, de rem heb ik nog niet vervangen. en dus denk ik dat ik hem zaterdag ophaal omdat de winkel doordeweeks vroeg dichtgaat, denk ik tenminste",
        proseOutput: "De fiets is gerepareerd, in elk geval het achterwiel: de rem heb ik nog niet vervangen.\n\nIk denk dat ik hem zaterdag ophaal, omdat de winkel doordeweeks vroeg dichtgaat, denk ik.",
        enumerationInput: "dus voor de reis heb ik nog drie dingen nodig, eh de paspoorten, de oplader van de camera en de kaartjes voor de veerboot, en het hotel heb ik gisteren geboekt dus dat is geregeld",
        enumerationOutput: "Voor de reis heb ik nog drie dingen nodig:\n- de paspoorten\n- de oplader van de camera\n- de kaartjes voor de veerboot\n\nHet hotel heb ik gisteren geboekt, dus dat is geregeld."
    )

    static let danish = SmartModeStructuredExamples(
        proseInput: "altså øh cyklen er lavet, altså baghjulet, bremsen har jeg ikke skiftet endnu. og så tror jeg at jeg henter den på lørdag fordi butikken lukker tidligt på hverdage, tror jeg i hvert fald",
        proseOutput: "Cyklen er lavet, i hvert fald baghjulet: Bremsen har jeg ikke skiftet endnu.\n\nJeg tror, jeg henter den på lørdag, fordi butikken lukker tidligt på hverdage, tror jeg.",
        enumerationInput: "så til turen mangler jeg stadig tre ting, øh passene, opladeren til kameraet og billetterne til færgen, og hotellet bookede jeg i går så det er klaret",
        enumerationOutput: "Til turen mangler jeg stadig tre ting:\n- passene\n- opladeren til kameraet\n- billetterne til færgen\n\nHotellet bookede jeg i går, så det er klaret."
    )

    static let norwegian = SmartModeStructuredExamples(
        proseInput: "altså eh sykkelen er fikset, altså bakhjulet, bremsen har jeg ikke byttet ennå. og så tror jeg at jeg henter den på lørdag fordi butikken stenger tidlig på hverdager, tror jeg i hvert fall",
        proseOutput: "Sykkelen er fikset, i hvert fall bakhjulet: Bremsen har jeg ikke byttet ennå.\n\nJeg tror jeg henter den på lørdag, fordi butikken stenger tidlig på hverdager, tror jeg.",
        enumerationInput: "så til turen trenger jeg fortsatt tre ting, eh passene, laderen til kameraet og billettene til ferja, og hotellet bestilte jeg i går så det er ordnet",
        enumerationOutput: "Til turen trenger jeg fortsatt tre ting:\n- passene\n- laderen til kameraet\n- billettene til ferja\n\nHotellet bestilte jeg i går, så det er ordnet."
    )

    static let swedish = SmartModeStructuredExamples(
        proseInput: "alltså eh cykeln är lagad, alltså bakhjulet, bromsen har jag inte bytt än. och då tror jag att jag hämtar den på lördag eftersom affären stänger tidigt på vardagar, tror jag i alla fall",
        proseOutput: "Cykeln är lagad, åtminstone bakhjulet: Bromsen har jag inte bytt än.\n\nJag tror att jag hämtar den på lördag, eftersom affären stänger tidigt på vardagar, tror jag.",
        enumerationInput: "så till resan behöver jag fortfarande tre saker, eh passen, laddaren till kameran och biljetterna till färjan, och hotellet bokade jag i går så det är klart",
        enumerationOutput: "Till resan behöver jag fortfarande tre saker:\n- passen\n- laddaren till kameran\n- biljetterna till färjan\n\nHotellet bokade jag i går, så det är klart."
    )

    static let turkish = SmartModeStructuredExamples(
        proseInput: "şey ıı bisiklet tamir edildi, yani arka tekerlek, freni daha değiştirmedim. o yüzden sanırım cumartesi alacağım çünkü dükkan hafta içi erken kapanıyor, en azından öyle sanıyorum",
        proseOutput: "Bisiklet tamir edildi, en azından arka tekerlek: Freni henüz değiştirmedim.\n\nSanırım cumartesi alacağım, çünkü dükkan hafta içi erken kapanıyor, sanırım.",
        enumerationInput: "yani gezi için hâlâ üç şeye ihtiyacım var, ıı pasaportlar, fotoğraf makinesinin şarj aleti ve feribot biletleri, oteli de dün ayırttım yani o tamam",
        enumerationOutput: "Gezi için hâlâ üç şeye ihtiyacım var:\n- pasaportlar\n- fotoğraf makinesinin şarj aleti\n- feribot biletleri\n\nOteli dün ayırttım, yani o tamam."
    )

    static let vietnamese = SmartModeStructuredExamples(
        proseInput: "ờ thì cái xe đạp sửa xong rồi, à ý là bánh sau, còn cái phanh thì tôi chưa thay. nên chắc thứ bảy tôi sẽ đi lấy vì cửa hàng đóng cửa sớm vào ngày thường, tôi nghĩ vậy",
        proseOutput: "Xe đạp đã sửa xong, ít nhất là bánh sau: tôi chưa thay phanh.\n\nTôi nghĩ tôi sẽ đi lấy xe vào thứ Bảy, vì cửa hàng đóng cửa sớm vào ngày thường, tôi nghĩ vậy.",
        enumerationInput: "vậy cho chuyến đi tôi vẫn cần ba thứ, ờ hộ chiếu, cục sạc máy ảnh và vé phà, còn khách sạn thì tôi đặt hôm qua rồi nên xong rồi",
        enumerationOutput: "Cho chuyến đi, tôi vẫn cần ba thứ:\n- hộ chiếu\n- cục sạc máy ảnh\n- vé phà\n\nTôi đã đặt khách sạn hôm qua, nên việc đó xong rồi."
    )

    static let japanese = SmartModeStructuredExamples(
        proseInput: "えっと、自転車は直ったよ、まあ後輪はね、ブレーキはまだ替えてない。だから土曜日に取りに行くと思う、お店が平日は早く閉まるから、たぶんね",
        proseOutput: "自転車は直った。少なくとも後輪は。ブレーキはまだ替えていない。\n\n土曜日に取りに行くと思う。お店が平日は早く閉まるから、たぶん。",
        enumerationInput: "それで旅行にはまだ三つ必要なんだ、えーと、パスポートと、カメラの充電器と、フェリーのチケット。ホテルは昨日予約したからそれは大丈夫",
        enumerationOutput: "旅行にはまだ三つ必要だ：\n- パスポート\n- カメラの充電器\n- フェリーのチケット\n\nホテルは昨日予約したので、それは済んでいる。"
    )

    static let korean = SmartModeStructuredExamples(
        proseInput: "음 그러니까 자전거는 고쳤어, 뭐 뒷바퀴는, 브레이크는 아직 안 바꿨어. 그래서 토요일에 찾으러 갈 것 같아 가게가 평일엔 일찍 닫으니까, 아마 그럴 거야",
        proseOutput: "자전거는 고쳤어. 적어도 뒷바퀴는 고쳤고, 브레이크는 아직 안 바꿨어.\n\n토요일에 찾으러 갈 것 같아. 가게가 평일엔 일찍 닫으니까, 아마도.",
        enumerationInput: "그래서 여행 가려면 아직 세 가지가 필요해, 어 여권이랑, 카메라 충전기랑, 페리 표, 그리고 호텔은 어제 예약했으니까 그건 됐어",
        enumerationOutput: "여행 가려면 아직 세 가지가 필요해:\n- 여권\n- 카메라 충전기\n- 페리 표\n\n호텔은 어제 예약했으니까 그건 됐어."
    )

    static let simplifiedChinese = SmartModeStructuredExamples(
        proseInput: "嗯那个自行车修好了，就是后轮嘛，刹车我还没换。所以我想周六去取吧，因为店里工作日关门早，我觉得是",
        proseOutput: "自行车修好了，至少后轮修好了：刹车我还没换。\n\n我想周六去取，因为店里工作日关门早，我觉得是这样。",
        enumerationInput: "那个旅行我还需要三样东西，呃护照、相机的充电器还有轮渡的船票，酒店我昨天订好了所以那个没问题",
        enumerationOutput: "旅行我还需要三样东西：\n- 护照\n- 相机的充电器\n- 轮渡的船票\n\n酒店我昨天订好了，所以那个已经搞定了。"
    )

    static let traditionalChinese = SmartModeStructuredExamples(
        proseInput: "嗯那個腳踏車修好了，就是後輪啦，煞車我還沒換。所以我想週六去拿吧，因為店裡平日很早關門，我覺得是",
        proseOutput: "腳踏車修好了，至少後輪修好了：煞車我還沒換。\n\n我想週六去拿，因為店裡平日很早關門，我覺得是這樣。",
        enumerationInput: "那個旅行我還需要三樣東西，呃護照、相機的充電器還有渡輪的船票，飯店我昨天訂好了所以那個沒問題",
        enumerationOutput: "旅行我還需要三樣東西：\n- 護照\n- 相機的充電器\n- 渡輪的船票\n\n飯店我昨天訂好了，所以那個已經搞定了。"
    )
}
