// DictusCore/Sources/DictusCore/Polish/Prompts/SmartModeNotesExamples.swift
// List's worked examples and counter-example in every Apple FM language (#587 decision 9).
import Foundation

/// Step 2 of #587 decision 5, applied to `List`.
///
/// ### Why only the examples move
///
/// `List`'s prompt carried three French blocks and one English one, which is #585's
/// mechanism sitting in the mode's own file: the model reads the examples as the
/// template, their language included. #587 measured the fix on two other modes — step 1
/// (English rules plus a language rule) failing, step 2 (the same rules with the
/// examples translated) holding at 0 % refused on `check=language` in all 16 Apple FM
/// languages — so this table is that step, and **no rule of `List` is rewritten here**.
/// Its rebuild is #573.
///
/// ### What every set has to keep
///
/// - **The same four blocks**: a meeting-preparation dictation that becomes three
///   bullets, a build-failure dictation that becomes three bullets, a one-idea dictation
///   that becomes exactly one bullet, and the counter-example whose wrong answers are a
///   translation and an invented second bullet.
/// - **Bullets everywhere.** This is the bullet mode (#393), and a translated example
///   that returned prose would teach the model to stop making lists. Every `output`
///   here is `- ` lines, and the suite asserts it.
/// - **No person named**, for the #414 reason `SmartModeNotesPrompt` records: this is
///   the mode on which a worked example's bullet was measured reaching a user's
///   document. The accountant and the missing data stay; nobody is called Sophie.
///
/// Machine-translated by the agent that wrote #587's PR 2, from the French and English
/// originals. The **French set keeps the three French blocks byte for byte** and
/// translates the English one; the **English set keeps the English block** and
/// translates the rest. A native speaker may find the others stiff; they are measured
/// for the output language, not for style.
///
/// Keys are `NLLanguage` base subtags, the 15 languages `SystemLanguageModel` listed on
/// 2026-09-21. `zh` is Simplified, and a `zh-Hant` transcript gets it.
enum SmartModeNotesExamples {

    typealias Set = SmartModeNotesPrompt.ExampleSet

    static let byLanguage: [String: Set] = [
        "fr": Set(
            meetingInput: "alors euh pour la réunion de jeudi il faut que je prépare les chiffres du trimestre et aussi euh le budget marketing et puis faut que j'appelle le comptable avant parce qu'il a les données manquantes",
            meetingOutput: "- Préparer les chiffres du trimestre pour la réunion de jeudi\n- Préparer le budget marketing\n- Appeler le comptable avant : il a les données manquantes",
            buildInput: "bon alors euh le build échoue sur ios vingt-six on pense que c'est le mode swift six et euh je vais d'abord essayer de figer la toolchain et si ça marche pas on revient en arrière sur la dépendance",
            buildOutput: "- Build en échec sur iOS 26, cause suspectée : le mode Swift 6\n- Première tentative : figer la toolchain\n- Solution de repli : revenir en arrière sur la dépendance",
            shortInput: "pense à racheter du café demain matin",
            shortOutput: "- Racheter du café demain matin",
            counterInput: "faut que j'arrose les plantes du hall avant de partir",
            counterTranslated: "- Water the lobby plants before leaving",
            counterInvented: "- Arroser les plantes du hall avant de partir / - Acheter un arrosoir",
            counterRight: "- Arroser les plantes du hall avant de partir"
        ),
        "en": Set(
            meetingInput: "so uh for thursday's meeting I need to prepare the quarter's figures and also uh the marketing budget and then I have to call the accountant first because he has the missing data",
            meetingOutput: "- Prepare the quarter's figures for Thursday's meeting\n- Prepare the marketing budget\n- Call the accountant first: he has the missing data",
            buildInput: "ok so uh the build is failing on ios twenty six we think it's the swift six mode thing and uh I'll try pinning the toolchain first and if that doesn't work we roll back the dependency",
            buildOutput: "- Build failing on iOS 26, suspected cause: Swift 6 mode\n- First attempt: pin the toolchain\n- Fallback: roll back the dependency",
            shortInput: "remember to buy coffee tomorrow morning",
            shortOutput: "- Buy coffee tomorrow morning",
            counterInput: "I have to water the lobby plants before leaving",
            counterTranslated: "- Arroser les plantes du hall avant de partir",
            counterInvented: "- Water the lobby plants before leaving / - Buy a watering can",
            counterRight: "- Water the lobby plants before leaving"
        ),
        "de": Set(
            meetingInput: "also ähm für das Meeting am Donnerstag muss ich die Quartalszahlen vorbereiten und auch ähm das Marketingbudget und dann muss ich vorher den Buchhalter anrufen weil er die fehlenden Daten hat",
            meetingOutput: "- Quartalszahlen für das Meeting am Donnerstag vorbereiten\n- Marketingbudget vorbereiten\n- Vorher den Buchhalter anrufen: er hat die fehlenden Daten",
            buildInput: "also ähm der Build schlägt auf iOS sechsundzwanzig fehl wir denken es liegt am Swift-sechs-Modus und ähm ich probiere zuerst die Toolchain festzupinnen und wenn das nicht klappt nehmen wir die Abhängigkeit zurück",
            buildOutput: "- Build schlägt auf iOS 26 fehl, vermutete Ursache: Swift-6-Modus\n- Erster Versuch: Toolchain festpinnen\n- Rückfalloption: Abhängigkeit zurücknehmen",
            shortInput: "denk dran morgen früh Kaffee zu kaufen",
            shortOutput: "- Morgen früh Kaffee kaufen",
            counterInput: "ich muss die Pflanzen im Flur gießen bevor ich gehe",
            counterTranslated: "- Water the hallway plants before leaving",
            counterInvented: "- Die Pflanzen im Flur gießen bevor ich gehe / - Eine Gießkanne kaufen",
            counterRight: "- Die Pflanzen im Flur gießen bevor ich gehe"
        ),
        "es": Set(
            meetingInput: "bueno eh para la reunión del jueves tengo que preparar las cifras del trimestre y también eh el presupuesto de marketing y luego tengo que llamar al contable antes porque tiene los datos que faltan",
            meetingOutput: "- Preparar las cifras del trimestre para la reunión del jueves\n- Preparar el presupuesto de marketing\n- Llamar antes al contable: tiene los datos que faltan",
            buildInput: "bueno eh la compilación falla en ios veintiséis creemos que es el modo swift seis y eh voy a intentar primero fijar la toolchain y si no funciona revertimos la dependencia",
            buildOutput: "- Compilación fallando en iOS 26, causa sospechada: modo Swift 6\n- Primer intento: fijar la toolchain\n- Alternativa: revertir la dependencia",
            shortInput: "acuérdate de comprar café mañana por la mañana",
            shortOutput: "- Comprar café mañana por la mañana",
            counterInput: "tengo que regar las plantas del vestíbulo antes de irme",
            counterTranslated: "- Water the lobby plants before leaving",
            counterInvented: "- Regar las plantas del vestíbulo antes de irme / - Comprar una regadera",
            counterRight: "- Regar las plantas del vestíbulo antes de irme"
        ),
        "it": Set(
            meetingInput: "allora ehm per la riunione di giovedì devo preparare i numeri del trimestre e anche ehm il budget marketing e poi devo chiamare prima il contabile perché ha i dati mancanti",
            meetingOutput: "- Preparare i numeri del trimestre per la riunione di giovedì\n- Preparare il budget marketing\n- Chiamare prima il contabile: ha i dati mancanti",
            buildInput: "allora ehm la build fallisce su ios ventisei pensiamo sia la modalità swift sei e ehm proverò prima a fissare la toolchain e se non funziona torniamo indietro sulla dipendenza",
            buildOutput: "- Build in errore su iOS 26, causa sospetta: modalità Swift 6\n- Primo tentativo: fissare la toolchain\n- Ripiego: tornare indietro sulla dipendenza",
            shortInput: "ricordati di comprare il caffè domani mattina",
            shortOutput: "- Comprare il caffè domani mattina",
            counterInput: "devo annaffiare le piante dell'ingresso prima di andare via",
            counterTranslated: "- Water the lobby plants before leaving",
            counterInvented: "- Annaffiare le piante dell'ingresso prima di andare via / - Comprare un annaffiatoio",
            counterRight: "- Annaffiare le piante dell'ingresso prima di andare via"
        ),
        "pt": Set(
            meetingInput: "então é para a reunião de quinta preciso preparar os números do trimestre e também é o orçamento de marketing e depois preciso ligar para o contador antes porque ele tem os dados que faltam",
            meetingOutput: "- Preparar os números do trimestre para a reunião de quinta\n- Preparar o orçamento de marketing\n- Ligar antes para o contador: ele tem os dados que faltam",
            buildInput: "então é o build está falhando no ios vinte e seis a gente acha que é o modo swift seis e é vou tentar primeiro fixar a toolchain e se não funcionar a gente reverte a dependência",
            buildOutput: "- Build falhando no iOS 26, causa suspeita: modo Swift 6\n- Primeira tentativa: fixar a toolchain\n- Alternativa: reverter a dependência",
            shortInput: "lembrar de comprar café amanhã de manhã",
            shortOutput: "- Comprar café amanhã de manhã",
            counterInput: "preciso regar as plantas do hall antes de sair",
            counterTranslated: "- Water the lobby plants before leaving",
            counterInvented: "- Regar as plantas do hall antes de sair / - Comprar um regador",
            counterRight: "- Regar as plantas do hall antes de sair"
        ),
        "nl": Set(
            meetingInput: "dus eh voor de vergadering van donderdag moet ik de kwartaalcijfers voorbereiden en ook eh het marketingbudget en dan moet ik eerst de boekhouder bellen want hij heeft de ontbrekende gegevens",
            meetingOutput: "- Kwartaalcijfers voorbereiden voor de vergadering van donderdag\n- Marketingbudget voorbereiden\n- Eerst de boekhouder bellen: hij heeft de ontbrekende gegevens",
            buildInput: "dus eh de build faalt op ios zesentwintig we denken dat het de swift zes modus is en eh ik probeer eerst de toolchain vast te zetten en als dat niet werkt draaien we de dependency terug",
            buildOutput: "- Build faalt op iOS 26, vermoedelijke oorzaak: Swift 6-modus\n- Eerste poging: toolchain vastzetten\n- Terugvaloptie: dependency terugdraaien",
            shortInput: "denk eraan morgenochtend koffie te kopen",
            shortOutput: "- Morgenochtend koffie kopen",
            counterInput: "ik moet de planten in de hal water geven voordat ik vertrek",
            counterTranslated: "- Water the lobby plants before leaving",
            counterInvented: "- De planten in de hal water geven voordat ik vertrek / - Een gieter kopen",
            counterRight: "- De planten in de hal water geven voordat ik vertrek"
        ),
        "da": Set(
            meetingInput: "altså øh til mødet på torsdag skal jeg forberede kvartalstallene og også øh markedsføringsbudgettet og så skal jeg ringe til revisoren først fordi han har de manglende data",
            meetingOutput: "- Forberede kvartalstallene til mødet på torsdag\n- Forberede markedsføringsbudgettet\n- Ringe til revisoren først: han har de manglende data",
            buildInput: "altså øh buildet fejler på ios seksogtyve vi tror det er swift seks tilstanden og øh jeg prøver først at låse toolchainen og hvis det ikke virker ruller vi afhængigheden tilbage",
            buildOutput: "- Build fejler på iOS 26, formodet årsag: Swift 6-tilstand\n- Første forsøg: låse toolchainen\n- Reserveplan: rulle afhængigheden tilbage",
            shortInput: "husk at købe kaffe i morgen tidlig",
            shortOutput: "- Købe kaffe i morgen tidlig",
            counterInput: "jeg skal vande planterne i entreen inden jeg går",
            counterTranslated: "- Water the lobby plants before leaving",
            counterInvented: "- Vande planterne i entreen inden jeg går / - Købe en vandkande",
            counterRight: "- Vande planterne i entreen inden jeg går"
        ),
        "nb": Set(
            meetingInput: "altså eh til møtet på torsdag må jeg forberede kvartalstallene og også eh markedsføringsbudsjettet og så må jeg ringe regnskapsføreren først fordi han har de manglende dataene",
            meetingOutput: "- Forberede kvartalstallene til møtet på torsdag\n- Forberede markedsføringsbudsjettet\n- Ringe regnskapsføreren først: han har de manglende dataene",
            buildInput: "altså eh bygget feiler på ios tjueseks vi tror det er swift seks modusen og eh jeg prøver først å låse toolchainen og hvis det ikke funker ruller vi tilbake avhengigheten",
            buildOutput: "- Bygg feiler på iOS 26, antatt årsak: Swift 6-modus\n- Første forsøk: låse toolchainen\n- Reserveløsning: rulle tilbake avhengigheten",
            shortInput: "husk å kjøpe kaffe i morgen tidlig",
            shortOutput: "- Kjøpe kaffe i morgen tidlig",
            counterInput: "jeg må vanne plantene i gangen før jeg drar",
            counterTranslated: "- Water the lobby plants before leaving",
            counterInvented: "- Vanne plantene i gangen før jeg drar / - Kjøpe en vannkanne",
            counterRight: "- Vanne plantene i gangen før jeg drar"
        ),
        "sv": Set(
            meetingInput: "alltså eh inför mötet på torsdag måste jag förbereda kvartalssiffrorna och också eh marknadsföringsbudgeten och sen måste jag ringa revisorn först för han har de saknade uppgifterna",
            meetingOutput: "- Förbereda kvartalssiffrorna inför mötet på torsdag\n- Förbereda marknadsföringsbudgeten\n- Ringa revisorn först: han har de saknade uppgifterna",
            buildInput: "alltså eh bygget misslyckas på ios tjugosex vi tror att det är swift sex-läget och eh jag testar först att låsa toolchainen och om det inte funkar rullar vi tillbaka beroendet",
            buildOutput: "- Bygget misslyckas på iOS 26, misstänkt orsak: Swift 6-läget\n- Första försöket: låsa toolchainen\n- Reservplan: rulla tillbaka beroendet",
            shortInput: "kom ihåg att köpa kaffe i morgon bitti",
            shortOutput: "- Köpa kaffe i morgon bitti",
            counterInput: "jag måste vattna växterna i hallen innan jag går",
            counterTranslated: "- Water the lobby plants before leaving",
            counterInvented: "- Vattna växterna i hallen innan jag går / - Köpa en vattenkanna",
            counterRight: "- Vattna växterna i hallen innan jag går"
        ),
        "tr": Set(
            meetingInput: "şey ıı perşembe toplantısı için çeyrek rakamlarını hazırlamam lazım bir de ıı pazarlama bütçesini ve öncesinde muhasebeciyi aramam lazım çünkü eksik veriler onda",
            meetingOutput: "- Perşembe toplantısı için çeyrek rakamlarını hazırlamak\n- Pazarlama bütçesini hazırlamak\n- Önce muhasebeciyi aramak: eksik veriler onda",
            buildInput: "şey ıı build ios yirmi altıda hata veriyor swift altı modu olduğunu düşünüyoruz ve ıı önce toolchain'i sabitlemeyi deneyeceğim olmazsa bağımlılığı geri alırız",
            buildOutput: "- Build iOS 26'da hata veriyor, şüphelenilen neden: Swift 6 modu\n- İlk deneme: toolchain'i sabitlemek\n- Yedek plan: bağımlılığı geri almak",
            shortInput: "yarın sabah kahve almayı unutma",
            shortOutput: "- Yarın sabah kahve almak",
            counterInput: "çıkmadan önce girişteki bitkileri sulamam lazım",
            counterTranslated: "- Water the lobby plants before leaving",
            counterInvented: "- Çıkmadan önce girişteki bitkileri sulamak / - Bir sulama kabı almak",
            counterRight: "- Çıkmadan önce girişteki bitkileri sulamak"
        ),
        "vi": Set(
            meetingInput: "ờ thì cho cuộc họp thứ năm tôi phải chuẩn bị số liệu quý và cả ờ ngân sách marketing rồi trước đó phải gọi cho kế toán vì anh ấy có dữ liệu còn thiếu",
            meetingOutput: "- Chuẩn bị số liệu quý cho cuộc họp thứ Năm\n- Chuẩn bị ngân sách marketing\n- Gọi cho kế toán trước: anh ấy có dữ liệu còn thiếu",
            buildInput: "ờ thì bản build lỗi trên ios hai mươi sáu chúng tôi nghĩ là do chế độ swift sáu và ờ tôi sẽ thử ghim toolchain trước nếu không được thì quay lại phiên bản thư viện cũ",
            buildOutput: "- Bản build lỗi trên iOS 26, nguyên nhân nghi ngờ: chế độ Swift 6\n- Thử trước: ghim toolchain\n- Phương án dự phòng: quay lại phiên bản thư viện cũ",
            shortInput: "nhớ mua cà phê vào sáng mai",
            shortOutput: "- Mua cà phê vào sáng mai",
            counterInput: "tôi phải tưới cây ở sảnh trước khi đi",
            counterTranslated: "- Water the lobby plants before leaving",
            counterInvented: "- Tưới cây ở sảnh trước khi đi / - Mua một bình tưới",
            counterRight: "- Tưới cây ở sảnh trước khi đi"
        ),
        "ja": Set(
            meetingInput: "えーっと 木曜の会議のために四半期の数字を用意しないといけなくて あと えーっと マーケティング予算も それから先に経理に電話しないと 足りないデータを持ってるから",
            meetingOutput: "- 木曜の会議のために四半期の数字を用意する\n- マーケティング予算を用意する\n- 先に経理に電話する：足りないデータを持っている",
            buildInput: "えっと ビルドが iOS 26 で落ちてて Swift 6 モードのせいだと思ってて えっと まずツールチェーンを固定してみて だめならライブラリを戻す",
            buildOutput: "- ビルドが iOS 26 で失敗、原因の疑い：Swift 6 モード\n- 最初の試み：ツールチェーンを固定する\n- 代案：ライブラリを元に戻す",
            shortInput: "明日の朝コーヒーを買うのを忘れないように",
            shortOutput: "- 明日の朝コーヒーを買う",
            counterInput: "出かける前にロビーの植物に水をやらないと",
            counterTranslated: "- Water the lobby plants before leaving",
            counterInvented: "- 出かける前にロビーの植物に水をやる / - じょうろを買う",
            counterRight: "- 出かける前にロビーの植物に水をやる"
        ),
        "ko": Set(
            meetingInput: "어 그러니까 목요일 회의 준비로 분기 실적을 정리해야 하고 그리고 어 마케팅 예산도 그리고 그전에 회계사한테 전화해야 해 빠진 데이터를 갖고 있거든",
            meetingOutput: "- 목요일 회의용 분기 실적 정리하기\n- 마케팅 예산 정리하기\n- 먼저 회계사에게 전화하기: 빠진 데이터를 갖고 있음",
            buildInput: "어 빌드가 iOS 26에서 실패하는데 Swift 6 모드 때문인 것 같아 어 일단 툴체인을 고정해 보고 안 되면 의존성을 되돌릴 거야",
            buildOutput: "- 빌드가 iOS 26에서 실패, 의심 원인: Swift 6 모드\n- 첫 시도: 툴체인 고정하기\n- 대안: 의존성 되돌리기",
            shortInput: "내일 아침에 커피 사는 거 잊지 말기",
            shortOutput: "- 내일 아침에 커피 사기",
            counterInput: "나가기 전에 로비 화분에 물 줘야 해",
            counterTranslated: "- Water the lobby plants before leaving",
            counterInvented: "- 나가기 전에 로비 화분에 물 주기 / - 물뿌리개 사기",
            counterRight: "- 나가기 전에 로비 화분에 물 주기"
        ),
        "zh": Set(
            meetingInput: "那个 为了周四的会我得把季度数字准备好 还有 呃 市场预算 然后之前还得给会计打个电话 因为缺的数据在他那儿",
            meetingOutput: "- 为周四的会议准备季度数字\n- 准备市场预算\n- 先给会计打电话：缺的数据在他那儿",
            buildInput: "那个 构建在 iOS 26 上失败了 我们觉得是 Swift 6 模式的问题 呃 我先试试固定工具链 不行的话就把依赖回退",
            buildOutput: "- 构建在 iOS 26 上失败，疑似原因：Swift 6 模式\n- 第一次尝试：固定工具链\n- 备选方案：回退依赖",
            shortInput: "记得明天早上买咖啡",
            shortOutput: "- 明天早上买咖啡",
            counterInput: "走之前得给大厅的植物浇水",
            counterTranslated: "- Water the lobby plants before leaving",
            counterInvented: "- 走之前给大厅的植物浇水 / - 买一个浇水壶",
            counterRight: "- 走之前给大厅的植物浇水"
        )
    ]

    /// The set for a transcript in `languageCode` (an `NLLanguage` raw value such as
    /// `de`, `zh-Hans`, `pt-BR`), or nil when the table has none.
    static func set(forLanguageCode languageCode: String) -> Set? {
        let base = languageCode.split(separator: "-").first.map { String($0).lowercased() } ?? ""
        return byLanguage[base]
    }
}
