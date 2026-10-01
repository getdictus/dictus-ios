// DictusCore/Sources/DictusCore/Polish/Prompts/SmartModeNotesExamples.swift
// List's worked examples and counter-example in every Apple FM language (#573, #587 step 2).
import Foundation

/// Step 2 of #587 decision 5, applied to `List` and rewritten for #573's shape.
///
/// ### Why the examples carry the shape
///
/// #587 measured that the model takes the worked examples, not the rules, as its
/// template: their language first (#585), and their shape with it (#523's bullet per
/// sentence, copied from the one English example). Before #573 every set here taught
/// **infinitive tasks**, and one taught a single bullet for a one-idea input, while the
/// rules asked for every point. That is the gap #573 closes, so the sets are rewritten
/// whole, all fifteen, rather than patched: a rule the examples contradict is a rule
/// the model does not follow.
///
/// ### What every set has to keep
///
/// - **The same three blocks**, in this order: a dictation mixing actions and statements
///   with a self-correction (a sale on Sunday), a dictation of statements only (a concert
///   last night), and the counter-example (plants in a hall).
/// - **The shape of decision 2**: a title made of the input's own words, the language's
///   colon (`Titre :` in French, `Title:` elsewhere, `：` in Chinese and Japanese), then
///   `- ` lines, flat. The suite asserts it on every set.
/// - **Decision 1 on both sides**: the actions come out in the infinitive (or the
///   language's citation form of a task), the statements come out as statements. The
///   statements-only example has no task at all, which is what a dictation with no action
///   in it has to look like.
/// - **No person named**, for the #414 reason `SmartModeNotesPrompt` records: this is the
///   mode on which a worked example's bullet was measured reaching a user's document.
/// - **Off-domain content**: a sale, a concert, house plants. A line copied from here
///   reads as obviously not the user's, which is the defence #414 measured: severity, not
///   rate.
///
/// Machine-translated by the agent that wrote #573, from the French and English
/// originals. A native speaker may find the others stiff; they are measured for the
/// output language and the shape, not for style.
///
/// Keys are `NLLanguage` base subtags, the 15 languages `SystemLanguageModel` listed on
/// 2026-09-21. `zh` is Simplified, and a `zh-Hant` transcript gets it.
enum SmartModeNotesExamples {

    typealias Set = SmartModeNotesPrompt.ExampleSet

    static let byLanguage: [String: Set] = [
        "fr": Set(
            mixedInput: "bon alors pour le vide-grenier de dimanche euh il faut que je descende les cartons de la cave et que je trie les livres, ah et l'emplacement est payé, c'est quinze euros, non pardon dix euros, et euh faut que je prévoie de la monnaie parce que beaucoup paient en liquide",
            mixedOutput: "Vide-grenier de dimanche :\n- Descendre les cartons de la cave\n- Trier les livres\n- L'emplacement est payé : 10 euros\n- Prévoir de la monnaie : beaucoup paient en liquide",
            statementsInput: "alors le concert d'hier soir euh c'était vraiment bien, la salle était pleine, le son était un peu fort au début mais après ça s'est arrangé, et ils ont joué presque deux heures",
            statementsOutput: "Concert d'hier soir :\n- C'était vraiment bien\n- La salle était pleine\n- Le son était un peu fort au début, puis ça s'est arrangé\n- Ils ont joué presque deux heures",
            counterInput: "faut que j'arrose les plantes du hall avant de partir, et le ficus a perdu des feuilles",
            counterTranslated: "Hall plants: / - Water them before leaving / - The ficus has lost leaves",
            counterTask: "Plantes du hall : / - Les arroser avant de partir / - Soigner le ficus",
            counterInvented: "Plantes du hall : / - Les arroser avant de partir / - Le ficus a perdu des feuilles / - Acheter un arrosoir",
            counterRight: "Plantes du hall :\n- Les arroser avant de partir\n- Le ficus a perdu des feuilles"
        ),
        "en": Set(
            mixedInput: "okay so for sunday's yard sale uh I need to bring the boxes up from the basement and sort the books, oh and the pitch is paid, it's fifteen euros, no sorry ten euros, and uh I have to get some change because a lot of people pay cash",
            mixedOutput: "Sunday's yard sale:\n- Bring the boxes up from the basement\n- Sort the books\n- The pitch is paid: 10 euros\n- Get some change: a lot of people pay cash",
            statementsInput: "so last night's concert uh it was really good, the venue was packed, the sound was a bit loud at first but then it got better, and they played for almost two hours",
            statementsOutput: "Last night's concert:\n- It was really good\n- The venue was packed\n- The sound was a bit loud at first, then it got better\n- They played for almost two hours",
            counterInput: "I have to water the hall plants before leaving, and the ficus has lost some leaves",
            counterTranslated: "Plantes du hall : / - Les arroser avant de partir / - Le ficus a perdu des feuilles",
            counterTask: "Hall plants: / - Water them before leaving / - Treat the ficus",
            counterInvented: "Hall plants: / - Water them before leaving / - The ficus has lost some leaves / - Buy a watering can",
            counterRight: "Hall plants:\n- Water them before leaving\n- The ficus has lost some leaves"
        ),
        "de": Set(
            mixedInput: "also ähm für den Flohmarkt am Sonntag muss ich die Kartons aus dem Keller holen und die Bücher sortieren, ach und der Stand ist bezahlt, das sind fünfzehn Euro, nein Entschuldigung zehn Euro, und ähm ich muss Wechselgeld besorgen, weil viele bar zahlen",
            mixedOutput: "Flohmarkt am Sonntag:\n- Kartons aus dem Keller holen\n- Bücher sortieren\n- Der Stand ist bezahlt: 10 Euro\n- Wechselgeld besorgen: viele zahlen bar",
            statementsInput: "also das Konzert gestern Abend ähm das war richtig gut, der Saal war voll, der Sound war am Anfang ein bisschen laut aber dann wurde es besser, und sie haben fast zwei Stunden gespielt",
            statementsOutput: "Konzert gestern Abend:\n- Es war richtig gut\n- Der Saal war voll\n- Der Sound war am Anfang etwas laut, dann wurde es besser\n- Sie haben fast zwei Stunden gespielt",
            counterInput: "ich muss die Pflanzen im Flur gießen bevor ich gehe, und der Ficus hat Blätter verloren",
            counterTranslated: "Hallway plants: / - Water them before leaving / - The ficus has lost leaves",
            counterTask: "Pflanzen im Flur: / - Vor dem Gehen gießen / - Den Ficus behandeln",
            counterInvented: "Pflanzen im Flur: / - Vor dem Gehen gießen / - Der Ficus hat Blätter verloren / - Eine Gießkanne kaufen",
            counterRight: "Pflanzen im Flur:\n- Vor dem Gehen gießen\n- Der Ficus hat Blätter verloren"
        ),
        "es": Set(
            mixedInput: "bueno eh para el mercadillo del domingo tengo que sacar las cajas del sótano y ordenar los libros, ah y el puesto está pagado, son quince euros, no perdón diez euros, y eh tengo que llevar cambio porque mucha gente paga en efectivo",
            mixedOutput: "Mercadillo del domingo:\n- Sacar las cajas del sótano\n- Ordenar los libros\n- El puesto está pagado: 10 euros\n- Llevar cambio: mucha gente paga en efectivo",
            statementsInput: "pues el concierto de anoche eh estuvo muy bien, la sala estaba llena, el sonido estaba un poco alto al principio pero luego mejoró, y tocaron casi dos horas",
            statementsOutput: "Concierto de anoche:\n- Estuvo muy bien\n- La sala estaba llena\n- El sonido estaba un poco alto al principio, luego mejoró\n- Tocaron casi dos horas",
            counterInput: "tengo que regar las plantas del vestíbulo antes de irme, y el ficus ha perdido hojas",
            counterTranslated: "Lobby plants: / - Water them before leaving / - The ficus has lost leaves",
            counterTask: "Plantas del vestíbulo: / - Regarlas antes de irme / - Curar el ficus",
            counterInvented: "Plantas del vestíbulo: / - Regarlas antes de irme / - El ficus ha perdido hojas / - Comprar una regadera",
            counterRight: "Plantas del vestíbulo:\n- Regarlas antes de irme\n- El ficus ha perdido hojas"
        ),
        "it": Set(
            mixedInput: "allora ehm per il mercatino di domenica devo tirare fuori gli scatoloni dalla cantina e riordinare i libri, ah e il posto è pagato, sono quindici euro, no scusa dieci euro, e ehm devo procurarmi degli spiccioli perché molti pagano in contanti",
            mixedOutput: "Mercatino di domenica:\n- Tirare fuori gli scatoloni dalla cantina\n- Riordinare i libri\n- Il posto è pagato: 10 euro\n- Procurarsi degli spiccioli: molti pagano in contanti",
            statementsInput: "allora il concerto di ieri sera ehm è stato davvero bello, la sala era piena, l'audio era un po' alto all'inizio ma poi è migliorato, e hanno suonato quasi due ore",
            statementsOutput: "Concerto di ieri sera:\n- È stato davvero bello\n- La sala era piena\n- L'audio era un po' alto all'inizio, poi è migliorato\n- Hanno suonato quasi due ore",
            counterInput: "devo annaffiare le piante dell'ingresso prima di andare via, e il ficus ha perso delle foglie",
            counterTranslated: "Hallway plants: / - Water them before leaving / - The ficus has lost some leaves",
            counterTask: "Piante dell'ingresso: / - Annaffiarle prima di andare via / - Curare il ficus",
            counterInvented: "Piante dell'ingresso: / - Annaffiarle prima di andare via / - Il ficus ha perso delle foglie / - Comprare un annaffiatoio",
            counterRight: "Piante dell'ingresso:\n- Annaffiarle prima di andare via\n- Il ficus ha perso delle foglie"
        ),
        "pt": Set(
            mixedInput: "então é para o bazar de domingo preciso tirar as caixas do porão e separar os livros, ah e a barraca está paga, são quinze euros, não desculpa dez euros, e é preciso levar troco porque muita gente paga em dinheiro",
            mixedOutput: "Bazar de domingo:\n- Tirar as caixas do porão\n- Separar os livros\n- A barraca está paga: 10 euros\n- Levar troco: muita gente paga em dinheiro",
            statementsInput: "então o show de ontem à noite é foi muito bom, a casa estava cheia, o som estava um pouco alto no começo mas depois melhorou, e eles tocaram quase duas horas",
            statementsOutput: "Show de ontem à noite:\n- Foi muito bom\n- A casa estava cheia\n- O som estava um pouco alto no começo, depois melhorou\n- Eles tocaram quase duas horas",
            counterInput: "preciso regar as plantas do hall antes de sair, e o fícus perdeu algumas folhas",
            counterTranslated: "Hall plants: / - Water them before leaving / - The ficus has lost some leaves",
            counterTask: "Plantas do hall: / - Regá-las antes de sair / - Tratar o fícus",
            counterInvented: "Plantas do hall: / - Regá-las antes de sair / - O fícus perdeu algumas folhas / - Comprar um regador",
            counterRight: "Plantas do hall:\n- Regá-las antes de sair\n- O fícus perdeu algumas folhas"
        ),
        "nl": Set(
            mixedInput: "dus eh voor de rommelmarkt van zondag moet ik de dozen uit de kelder halen en de boeken sorteren, o en de standplaats is betaald, dat is vijftien euro, nee sorry tien euro, en eh ik moet wisselgeld regelen want veel mensen betalen contant",
            mixedOutput: "Rommelmarkt van zondag:\n- De dozen uit de kelder halen\n- De boeken sorteren\n- De standplaats is betaald: 10 euro\n- Wisselgeld regelen: veel mensen betalen contant",
            statementsInput: "dus het concert van gisteravond eh dat was echt goed, de zaal zat vol, het geluid was in het begin een beetje hard maar daarna werd het beter, en ze hebben bijna twee uur gespeeld",
            statementsOutput: "Concert van gisteravond:\n- Het was echt goed\n- De zaal zat vol\n- Het geluid was in het begin wat hard, daarna werd het beter\n- Ze hebben bijna twee uur gespeeld",
            counterInput: "ik moet de planten in de hal water geven voordat ik vertrek, en de ficus heeft bladeren verloren",
            counterTranslated: "Hall plants: / - Water them before leaving / - The ficus has lost leaves",
            counterTask: "Planten in de hal: / - Water geven voordat ik vertrek / - De ficus behandelen",
            counterInvented: "Planten in de hal: / - Water geven voordat ik vertrek / - De ficus heeft bladeren verloren / - Een gieter kopen",
            counterRight: "Planten in de hal:\n- Water geven voordat ik vertrek\n- De ficus heeft bladeren verloren"
        ),
        "da": Set(
            mixedInput: "altså øh til loppemarkedet på søndag skal jeg hente kasserne i kælderen og sortere bøgerne, nå ja og standpladsen er betalt, det er femten euro, nej undskyld ti euro, og øh jeg skal skaffe byttepenge fordi mange betaler kontant",
            mixedOutput: "Loppemarkedet på søndag:\n- Hente kasserne i kælderen\n- Sortere bøgerne\n- Standpladsen er betalt: 10 euro\n- Skaffe byttepenge: mange betaler kontant",
            statementsInput: "altså koncerten i går aftes øh den var virkelig god, salen var fuld, lyden var lidt høj i starten men så blev den bedre, og de spillede næsten to timer",
            statementsOutput: "Koncerten i går aftes:\n- Den var virkelig god\n- Salen var fuld\n- Lyden var lidt høj i starten, så blev den bedre\n- De spillede næsten to timer",
            counterInput: "jeg skal vande planterne i entreen inden jeg går, og ficussen har tabt nogle blade",
            counterTranslated: "Hall plants: / - Water them before leaving / - The ficus has lost some leaves",
            counterTask: "Planterne i entreen: / - Vande dem inden jeg går / - Behandle ficussen",
            counterInvented: "Planterne i entreen: / - Vande dem inden jeg går / - Ficussen har tabt nogle blade / - Købe en vandkande",
            counterRight: "Planterne i entreen:\n- Vande dem inden jeg går\n- Ficussen har tabt nogle blade"
        ),
        "nb": Set(
            mixedInput: "altså eh til loppemarkedet på søndag må jeg hente eskene i kjelleren og sortere bøkene, å ja og standplassen er betalt, det er femten euro, nei unnskyld ti euro, og eh jeg må skaffe vekslepenger fordi mange betaler kontant",
            mixedOutput: "Loppemarkedet på søndag:\n- Hente eskene i kjelleren\n- Sortere bøkene\n- Standplassen er betalt: 10 euro\n- Skaffe vekslepenger: mange betaler kontant",
            statementsInput: "altså konserten i går kveld eh den var veldig bra, salen var full, lyden var litt høy i starten men så ble den bedre, og de spilte nesten to timer",
            statementsOutput: "Konserten i går kveld:\n- Den var veldig bra\n- Salen var full\n- Lyden var litt høy i starten, så ble den bedre\n- De spilte nesten to timer",
            counterInput: "jeg må vanne plantene i gangen før jeg drar, og fikusen har mistet noen blader",
            counterTranslated: "Hallway plants: / - Water them before leaving / - The ficus has lost some leaves",
            counterTask: "Plantene i gangen: / - Vanne dem før jeg drar / - Behandle fikusen",
            counterInvented: "Plantene i gangen: / - Vanne dem før jeg drar / - Fikusen har mistet noen blader / - Kjøpe en vannkanne",
            counterRight: "Plantene i gangen:\n- Vanne dem før jeg drar\n- Fikusen har mistet noen blader"
        ),
        "sv": Set(
            mixedInput: "alltså eh inför loppisen på söndag måste jag hämta kartongerna i källaren och sortera böckerna, åh och platsen är betald, det är femton euro, nej förlåt tio euro, och eh jag måste fixa växelpengar för många betalar kontant",
            mixedOutput: "Loppisen på söndag:\n- Hämta kartongerna i källaren\n- Sortera böckerna\n- Platsen är betald: 10 euro\n- Fixa växelpengar: många betalar kontant",
            statementsInput: "alltså konserten i går kväll eh den var riktigt bra, salongen var full, ljudet var lite högt i början men sen blev det bättre, och de spelade nästan två timmar",
            statementsOutput: "Konserten i går kväll:\n- Den var riktigt bra\n- Salongen var full\n- Ljudet var lite högt i början, sen blev det bättre\n- De spelade nästan två timmar",
            counterInput: "jag måste vattna växterna i hallen innan jag går, och fikusen har tappat några blad",
            counterTranslated: "Hall plants: / - Water them before leaving / - The ficus has lost some leaves",
            counterTask: "Växterna i hallen: / - Vattna dem innan jag går / - Behandla fikusen",
            counterInvented: "Växterna i hallen: / - Vattna dem innan jag går / - Fikusen har tappat några blad / - Köpa en vattenkanna",
            counterRight: "Växterna i hallen:\n- Vattna dem innan jag går\n- Fikusen har tappat några blad"
        ),
        "tr": Set(
            mixedInput: "şey ıı pazar günkü bit pazarı için bodrumdaki kolileri çıkarmam ve kitapları ayırmam lazım, ha bir de tezgâh parası ödendi, on beş euro, yok pardon on euro, ve ıı bozuk para ayarlamam lazım çünkü çoğu kişi nakit ödüyor",
            mixedOutput: "Pazar günkü bit pazarı:\n- Bodrumdaki kolileri çıkarmak\n- Kitapları ayırmak\n- Tezgâh parası ödendi: 10 euro\n- Bozuk para ayarlamak: çoğu kişi nakit ödüyor",
            statementsInput: "şey dün akşamki konser ıı gerçekten çok iyiydi, salon doluydu, ses başta biraz yüksekti ama sonra düzeldi, ve neredeyse iki saat çaldılar",
            statementsOutput: "Dün akşamki konser:\n- Gerçekten çok iyiydi\n- Salon doluydu\n- Ses başta biraz yüksekti, sonra düzeldi\n- Neredeyse iki saat çaldılar",
            counterInput: "çıkmadan önce girişteki bitkileri sulamam lazım, bir de fikus birkaç yaprak döktü",
            counterTranslated: "Entrance plants: / - Water them before leaving / - The ficus has lost a few leaves",
            counterTask: "Girişteki bitkiler: / - Çıkmadan önce sulamak / - Fikusu tedavi etmek",
            counterInvented: "Girişteki bitkiler: / - Çıkmadan önce sulamak / - Fikus birkaç yaprak döktü / - Bir sulama kabı almak",
            counterRight: "Girişteki bitkiler:\n- Çıkmadan önce sulamak\n- Fikus birkaç yaprak döktü"
        ),
        "vi": Set(
            mixedInput: "ờ thì cho phiên chợ đồ cũ chủ nhật tôi phải mang mấy thùng dưới hầm lên và phân loại sách, à còn chỗ bán đã trả tiền rồi, mười lăm euro, à không xin lỗi mười euro, và ờ tôi phải chuẩn bị tiền lẻ vì nhiều người trả tiền mặt",
            mixedOutput: "Phiên chợ đồ cũ chủ nhật:\n- Mang mấy thùng dưới hầm lên\n- Phân loại sách\n- Chỗ bán đã trả tiền: 10 euro\n- Chuẩn bị tiền lẻ: nhiều người trả tiền mặt",
            statementsInput: "ờ thì buổi hòa nhạc tối qua ờ hay thật sự, khán phòng kín chỗ, âm thanh lúc đầu hơi to nhưng sau đó ổn hơn, và họ chơi gần hai tiếng",
            statementsOutput: "Buổi hòa nhạc tối qua:\n- Hay thật sự\n- Khán phòng kín chỗ\n- Âm thanh lúc đầu hơi to, sau đó ổn hơn\n- Họ chơi gần hai tiếng",
            counterInput: "tôi phải tưới cây ở sảnh trước khi đi, và cây đa đã rụng mấy chiếc lá",
            counterTranslated: "Lobby plants: / - Water them before leaving / - The ficus has lost a few leaves",
            counterTask: "Cây ở sảnh: / - Tưới trước khi đi / - Chữa cho cây đa",
            counterInvented: "Cây ở sảnh: / - Tưới trước khi đi / - Cây đa đã rụng mấy chiếc lá / - Mua một bình tưới",
            counterRight: "Cây ở sảnh:\n- Tưới trước khi đi\n- Cây đa đã rụng mấy chiếc lá"
        ),
        "ja": Set(
            mixedInput: "えーっと 日曜のフリーマーケットのために地下室から段ボールを出して本を仕分けしないといけなくて あ それと出店料は払ってあって 十五ユーロ いや ごめん 十ユーロ で えーっと 現金で払う人が多いからお釣りを用意しないと",
            mixedOutput: "日曜のフリーマーケット：\n- 地下室から段ボールを出す\n- 本を仕分けする\n- 出店料は支払い済み：10ユーロ\n- お釣りを用意する：現金で払う人が多い",
            statementsInput: "えっと 昨日の夜のコンサート えー 本当によかった 会場は満員で 音は最初ちょっと大きかったけど そのあとよくなって ほぼ二時間演奏してた",
            statementsOutput: "昨日の夜のコンサート：\n- 本当によかった\n- 会場は満員だった\n- 音は最初少し大きかったが、そのあとよくなった\n- ほぼ二時間演奏していた",
            counterInput: "出かける前にロビーの植物に水をやらないと あとフィカスの葉が何枚か落ちた",
            counterTranslated: "Lobby plants: / - Water them before leaving / - The ficus has lost a few leaves",
            counterTask: "ロビーの植物： / - 出かける前に水をやる / - フィカスを手当てする",
            counterInvented: "ロビーの植物： / - 出かける前に水をやる / - フィカスの葉が何枚か落ちた / - じょうろを買う",
            counterRight: "ロビーの植物：\n- 出かける前に水をやる\n- フィカスの葉が何枚か落ちた"
        ),
        "ko": Set(
            mixedInput: "어 그러니까 일요일 벼룩시장 때문에 지하실에서 상자들 꺼내고 책 정리해야 하고 아 그리고 자리값은 냈어 십오 유로 아니 미안 십 유로 그리고 어 현금 내는 사람이 많으니까 잔돈 준비해야 해",
            mixedOutput: "일요일 벼룩시장:\n- 지하실에서 상자 꺼내기\n- 책 정리하기\n- 자리값은 냈음: 10유로\n- 잔돈 준비하기: 현금 내는 사람이 많음",
            statementsInput: "어 어젯밤 콘서트 어 진짜 좋았어 공연장은 꽉 찼고 소리가 처음엔 좀 컸는데 나중엔 괜찮아졌고 거의 두 시간 동안 연주했어",
            statementsOutput: "어젯밤 콘서트:\n- 진짜 좋았음\n- 공연장은 꽉 찼음\n- 소리가 처음엔 좀 컸다가 나중엔 괜찮아짐\n- 거의 두 시간 동안 연주함",
            counterInput: "나가기 전에 로비 화분에 물 줘야 하고 고무나무 잎이 몇 장 떨어졌어",
            counterTranslated: "Lobby plants: / - Water them before leaving / - The ficus has lost a few leaves",
            counterTask: "로비 화분: / - 나가기 전에 물 주기 / - 고무나무 치료하기",
            counterInvented: "로비 화분: / - 나가기 전에 물 주기 / - 고무나무 잎이 몇 장 떨어짐 / - 물뿌리개 사기",
            counterRight: "로비 화분:\n- 나가기 전에 물 주기\n- 고무나무 잎이 몇 장 떨어짐"
        ),
        "zh": Set(
            mixedInput: "那个 为了周日的跳蚤市场 我得把地下室的箱子搬上来 还要整理书 啊对了 摊位费已经交了 是十五欧 不对 不好意思 是十欧 然后 呃 还得准备零钱 因为很多人付现金",
            mixedOutput: "周日的跳蚤市场：\n- 把地下室的箱子搬上来\n- 整理书\n- 摊位费已交：10欧\n- 准备零钱：很多人付现金",
            statementsInput: "那个 昨晚的音乐会 呃 真的很好 场子坐满了 声音一开始有点大 后来好了 他们演了差不多两个小时",
            statementsOutput: "昨晚的音乐会：\n- 真的很好\n- 场子坐满了\n- 声音一开始有点大，后来好了\n- 他们演了差不多两个小时",
            counterInput: "走之前得给大厅的植物浇水 还有那棵榕树掉了几片叶子",
            counterTranslated: "Lobby plants: / - Water them before leaving / - The ficus has lost a few leaves",
            counterTask: "大厅的植物： / - 走之前浇水 / - 给榕树治病",
            counterInvented: "大厅的植物： / - 走之前浇水 / - 榕树掉了几片叶子 / - 买一个浇水壶",
            counterRight: "大厅的植物：\n- 走之前浇水\n- 榕树掉了几片叶子"
        )
    ]

    /// The set for a transcript in `languageCode` (an `NLLanguage` raw value such as
    /// `de`, `zh-Hans`, `pt-BR`), or nil when the table has none.
    static func set(forLanguageCode languageCode: String) -> Set? {
        let base = languageCode.split(separator: "-").first.map { String($0).lowercased() } ?? ""
        return byLanguage[base]
    }
}
