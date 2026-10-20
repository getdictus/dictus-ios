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
///   with a self-correction and a reason (a sale on Sunday), an announced recap of things
///   already done (a weekend in the garden), and the counter-example (plants in a hall).
///   The recap replaced a concert after the first device round (2026-10-01): an opening
///   sentence announcing the list made the model promote the first point to title, and
///   past facts came back as tasks. The recap shows both answers at once: the title
///   sums up the announcement, every past fact stays past with its subject.
/// - **The shape of decision 2, as amended**: a title that sums up the list, the language's
///   colon (`Titre :` in French, `Title:` elsewhere, `：` in Chinese and Japanese), then
///   `- ` lines, flat. The suite asserts it on every set.
/// - **Decision 1 on both sides**: the actions come out in the infinitive (or the
///   language's citation form of a task), the statements come out as statements. The
///   recap has no task at all, which is what a dictation with no action in it has to look
///   like, and its past facts keep their tense and subject.
/// - **No person named**, for the #414 reason `SmartModeNotesPrompt` records: this is the
///   mode on which a worked example's bullet was measured reaching a user's document.
/// - **Off-domain content**: a sale, a garden, house plants. A line copied from here
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
            statementsInput: "bon je te raconte ce qu'on a fait au jardin ce week-end euh on a taillé la haie, on a planté les tomates, le voisin nous a prêté sa tondeuse, et franchement c'était agréable",
            statementsOutput: "Ce qu'on a fait au jardin ce week-end :\n- On a taillé la haie\n- On a planté les tomates\n- Le voisin nous a prêté sa tondeuse\n- C'était agréable",
            counterInput: "faut que j'arrose les plantes du hall avant de partir, et le ficus a perdu des feuilles",
            counterTranslated: "Hall plants: / - Water them before leaving / - The ficus has lost leaves",
            counterTask: "Plantes du hall : / - Les arroser avant de partir / - Soigner le ficus",
            counterInvented: "Plantes du hall : / - Les arroser avant de partir / - Le ficus a perdu des feuilles / - Acheter un arrosoir",
            counterGeneric: "À faire : / - Les arroser avant de partir / - Le ficus a perdu des feuilles",
            counterRight: "Plantes du hall :\n- Les arroser avant de partir\n- Le ficus a perdu des feuilles"
        ),
        "en": Set(
            mixedInput: "okay so for sunday's yard sale uh I need to bring the boxes up from the basement and sort the books, oh and the pitch is paid, it's fifteen euros, no sorry ten euros, and uh I have to get some change because a lot of people pay cash",
            mixedOutput: "Sunday's yard sale:\n- Bring the boxes up from the basement\n- Sort the books\n- The pitch is paid: 10 euros\n- Get some change: a lot of people pay cash",
            statementsInput: "so let me tell you what we did in the garden this weekend uh we trimmed the hedge, we planted the tomatoes, the neighbour lent us his mower, and honestly it was nice",
            statementsOutput: "What we did in the garden this weekend:\n- We trimmed the hedge\n- We planted the tomatoes\n- The neighbour lent us his mower\n- It was nice",
            counterInput: "I have to water the hall plants before leaving, and the ficus has lost some leaves",
            counterTranslated: "Plantes du hall : / - Les arroser avant de partir / - Le ficus a perdu des feuilles",
            counterTask: "Hall plants: / - Water them before leaving / - Treat the ficus",
            counterInvented: "Hall plants: / - Water them before leaving / - The ficus has lost some leaves / - Buy a watering can",
            counterGeneric: "To do: / - Water them before leaving / - The ficus has lost some leaves",
            counterRight: "Hall plants:\n- Water them before leaving\n- The ficus has lost some leaves"
        ),
        "de": Set(
            mixedInput: "also ähm für den Flohmarkt am Sonntag muss ich die Kartons aus dem Keller holen und die Bücher sortieren, ach und der Stand ist bezahlt, das sind fünfzehn Euro, nein Entschuldigung zehn Euro, und ähm ich muss Wechselgeld besorgen, weil viele bar zahlen",
            mixedOutput: "Flohmarkt am Sonntag:\n- Kartons aus dem Keller holen\n- Bücher sortieren\n- Der Stand ist bezahlt: 10 Euro\n- Wechselgeld besorgen: viele zahlen bar",
            statementsInput: "also ich erzähl dir, was wir am Wochenende im Garten gemacht haben, ähm wir haben die Hecke geschnitten, wir haben die Tomaten gepflanzt, der Nachbar hat uns seinen Rasenmäher geliehen, und ehrlich gesagt war es schön",
            statementsOutput: "Was wir am Wochenende im Garten gemacht haben:\n- Wir haben die Hecke geschnitten\n- Wir haben die Tomaten gepflanzt\n- Der Nachbar hat uns seinen Rasenmäher geliehen\n- Es war schön",
            counterInput: "ich muss die Pflanzen im Flur gießen bevor ich gehe, und der Ficus hat Blätter verloren",
            counterTranslated: "Hallway plants: / - Water them before leaving / - The ficus has lost leaves",
            counterTask: "Pflanzen im Flur: / - Vor dem Gehen gießen / - Den Ficus behandeln",
            counterInvented: "Pflanzen im Flur: / - Vor dem Gehen gießen / - Der Ficus hat Blätter verloren / - Eine Gießkanne kaufen",
            counterGeneric: "Zu erledigen: / - Vor dem Gehen gießen / - Der Ficus hat Blätter verloren",
            counterRight: "Pflanzen im Flur:\n- Vor dem Gehen gießen\n- Der Ficus hat Blätter verloren"
        ),
        "es": Set(
            mixedInput: "bueno eh para el mercadillo del domingo tengo que sacar las cajas del sótano y ordenar los libros, ah y el puesto está pagado, son quince euros, no perdón diez euros, y eh tengo que llevar cambio porque mucha gente paga en efectivo",
            mixedOutput: "Mercadillo del domingo:\n- Sacar las cajas del sótano\n- Ordenar los libros\n- El puesto está pagado: 10 euros\n- Llevar cambio: mucha gente paga en efectivo",
            statementsInput: "bueno te cuento lo que hicimos en el jardín este fin de semana eh podamos el seto, plantamos los tomates, el vecino nos prestó su cortacésped, y la verdad es que fue agradable",
            statementsOutput: "Lo que hicimos en el jardín este fin de semana:\n- Podamos el seto\n- Plantamos los tomates\n- El vecino nos prestó su cortacésped\n- Fue agradable",
            counterInput: "tengo que regar las plantas del vestíbulo antes de irme, y el ficus ha perdido hojas",
            counterTranslated: "Lobby plants: / - Water them before leaving / - The ficus has lost leaves",
            counterTask: "Plantas del vestíbulo: / - Regarlas antes de irme / - Curar el ficus",
            counterInvented: "Plantas del vestíbulo: / - Regarlas antes de irme / - El ficus ha perdido hojas / - Comprar una regadera",
            counterGeneric: "Por hacer: / - Regarlas antes de irme / - El ficus ha perdido hojas",
            counterRight: "Plantas del vestíbulo:\n- Regarlas antes de irme\n- El ficus ha perdido hojas"
        ),
        "it": Set(
            mixedInput: "allora ehm per il mercatino di domenica devo tirare fuori gli scatoloni dalla cantina e riordinare i libri, ah e il posto è pagato, sono quindici euro, no scusa dieci euro, e ehm devo procurarmi degli spiccioli perché molti pagano in contanti",
            mixedOutput: "Mercatino di domenica:\n- Tirare fuori gli scatoloni dalla cantina\n- Riordinare i libri\n- Il posto è pagato: 10 euro\n- Procurarsi degli spiccioli: molti pagano in contanti",
            statementsInput: "allora ti racconto cosa abbiamo fatto in giardino questo fine settimana ehm abbiamo potato la siepe, abbiamo piantato i pomodori, il vicino ci ha prestato il tosaerba, e onestamente è stato piacevole",
            statementsOutput: "Cosa abbiamo fatto in giardino questo fine settimana:\n- Abbiamo potato la siepe\n- Abbiamo piantato i pomodori\n- Il vicino ci ha prestato il tosaerba\n- È stato piacevole",
            counterInput: "devo annaffiare le piante dell'ingresso prima di andare via, e il ficus ha perso delle foglie",
            counterTranslated: "Hallway plants: / - Water them before leaving / - The ficus has lost some leaves",
            counterTask: "Piante dell'ingresso: / - Annaffiarle prima di andare via / - Curare il ficus",
            counterInvented: "Piante dell'ingresso: / - Annaffiarle prima di andare via / - Il ficus ha perso delle foglie / - Comprare un annaffiatoio",
            counterGeneric: "Da fare: / - Annaffiarle prima di andare via / - Il ficus ha perso delle foglie",
            counterRight: "Piante dell'ingresso:\n- Annaffiarle prima di andare via\n- Il ficus ha perso delle foglie"
        ),
        "pt": Set(
            mixedInput: "então é para o bazar de domingo preciso tirar as caixas do porão e separar os livros, ah e a barraca está paga, são quinze euros, não desculpa dez euros, e é preciso levar troco porque muita gente paga em dinheiro",
            mixedOutput: "Bazar de domingo:\n- Tirar as caixas do porão\n- Separar os livros\n- A barraca está paga: 10 euros\n- Levar troco: muita gente paga em dinheiro",
            statementsInput: "então vou te contar o que a gente fez no jardim neste fim de semana é a gente podou a cerca viva, a gente plantou os tomates, o vizinho emprestou o cortador de grama, e sinceramente foi agradável",
            statementsOutput: "O que a gente fez no jardim neste fim de semana:\n- A gente podou a cerca viva\n- A gente plantou os tomates\n- O vizinho emprestou o cortador de grama\n- Foi agradável",
            counterInput: "preciso regar as plantas do hall antes de sair, e o fícus perdeu algumas folhas",
            counterTranslated: "Hall plants: / - Water them before leaving / - The ficus has lost some leaves",
            counterTask: "Plantas do hall: / - Regá-las antes de sair / - Tratar o fícus",
            counterInvented: "Plantas do hall: / - Regá-las antes de sair / - O fícus perdeu algumas folhas / - Comprar um regador",
            counterGeneric: "A fazer: / - Regá-las antes de sair / - O fícus perdeu algumas folhas",
            counterRight: "Plantas do hall:\n- Regá-las antes de sair\n- O fícus perdeu algumas folhas"
        ),
        "nl": Set(
            mixedInput: "dus eh voor de rommelmarkt van zondag moet ik de dozen uit de kelder halen en de boeken sorteren, o en de standplaats is betaald, dat is vijftien euro, nee sorry tien euro, en eh ik moet wisselgeld regelen want veel mensen betalen contant",
            mixedOutput: "Rommelmarkt van zondag:\n- De dozen uit de kelder halen\n- De boeken sorteren\n- De standplaats is betaald: 10 euro\n- Wisselgeld regelen: veel mensen betalen contant",
            statementsInput: "dus ik vertel je wat we dit weekend in de tuin hebben gedaan eh we hebben de heg gesnoeid, we hebben de tomaten geplant, de buurman heeft ons zijn grasmaaier geleend, en eerlijk gezegd was het fijn",
            statementsOutput: "Wat we dit weekend in de tuin hebben gedaan:\n- We hebben de heg gesnoeid\n- We hebben de tomaten geplant\n- De buurman heeft ons zijn grasmaaier geleend\n- Het was fijn",
            counterInput: "ik moet de planten in de hal water geven voordat ik vertrek, en de ficus heeft bladeren verloren",
            counterTranslated: "Hall plants: / - Water them before leaving / - The ficus has lost leaves",
            counterTask: "Planten in de hal: / - Water geven voordat ik vertrek / - De ficus behandelen",
            counterInvented: "Planten in de hal: / - Water geven voordat ik vertrek / - De ficus heeft bladeren verloren / - Een gieter kopen",
            counterGeneric: "Te doen: / - Water geven voordat ik vertrek / - De ficus heeft bladeren verloren",
            counterRight: "Planten in de hal:\n- Water geven voordat ik vertrek\n- De ficus heeft bladeren verloren"
        ),
        "da": Set(
            mixedInput: "altså øh til loppemarkedet på søndag skal jeg hente kasserne i kælderen og sortere bøgerne, nå ja og standpladsen er betalt, det er femten euro, nej undskyld ti euro, og øh jeg skal skaffe byttepenge fordi mange betaler kontant",
            mixedOutput: "Loppemarkedet på søndag:\n- Hente kasserne i kælderen\n- Sortere bøgerne\n- Standpladsen er betalt: 10 euro\n- Skaffe byttepenge: mange betaler kontant",
            statementsInput: "altså jeg fortæller dig hvad vi lavede i haven i weekenden øh vi klippede hækken, vi plantede tomaterne, naboen lånte os sin plæneklipper, og ærligt talt var det hyggeligt",
            statementsOutput: "Hvad vi lavede i haven i weekenden:\n- Vi klippede hækken\n- Vi plantede tomaterne\n- Naboen lånte os sin plæneklipper\n- Det var hyggeligt",
            counterInput: "jeg skal vande planterne i entreen inden jeg går, og ficussen har tabt nogle blade",
            counterTranslated: "Hall plants: / - Water them before leaving / - The ficus has lost some leaves",
            counterTask: "Planterne i entreen: / - Vande dem inden jeg går / - Behandle ficussen",
            counterInvented: "Planterne i entreen: / - Vande dem inden jeg går / - Ficussen har tabt nogle blade / - Købe en vandkande",
            counterGeneric: "At gøre: / - Vande dem inden jeg går / - Ficussen har tabt nogle blade",
            counterRight: "Planterne i entreen:\n- Vande dem inden jeg går\n- Ficussen har tabt nogle blade"
        ),
        "nb": Set(
            mixedInput: "altså eh til loppemarkedet på søndag må jeg hente eskene i kjelleren og sortere bøkene, å ja og standplassen er betalt, det er femten euro, nei unnskyld ti euro, og eh jeg må skaffe vekslepenger fordi mange betaler kontant",
            mixedOutput: "Loppemarkedet på søndag:\n- Hente eskene i kjelleren\n- Sortere bøkene\n- Standplassen er betalt: 10 euro\n- Skaffe vekslepenger: mange betaler kontant",
            statementsInput: "altså jeg forteller deg hva vi gjorde i hagen i helgen eh vi klippet hekken, vi plantet tomatene, naboen lånte oss gressklipperen sin, og ærlig talt var det koselig",
            statementsOutput: "Hva vi gjorde i hagen i helgen:\n- Vi klippet hekken\n- Vi plantet tomatene\n- Naboen lånte oss gressklipperen sin\n- Det var koselig",
            counterInput: "jeg må vanne plantene i gangen før jeg drar, og fikusen har mistet noen blader",
            counterTranslated: "Hallway plants: / - Water them before leaving / - The ficus has lost some leaves",
            counterTask: "Plantene i gangen: / - Vanne dem før jeg drar / - Behandle fikusen",
            counterInvented: "Plantene i gangen: / - Vanne dem før jeg drar / - Fikusen har mistet noen blader / - Kjøpe en vannkanne",
            counterGeneric: "Å gjøre: / - Vanne dem før jeg drar / - Fikusen har mistet noen blader",
            counterRight: "Plantene i gangen:\n- Vanne dem før jeg drar\n- Fikusen har mistet noen blader"
        ),
        "sv": Set(
            mixedInput: "alltså eh inför loppisen på söndag måste jag hämta kartongerna i källaren och sortera böckerna, åh och platsen är betald, det är femton euro, nej förlåt tio euro, och eh jag måste fixa växelpengar för många betalar kontant",
            mixedOutput: "Loppisen på söndag:\n- Hämta kartongerna i källaren\n- Sortera böckerna\n- Platsen är betald: 10 euro\n- Fixa växelpengar: många betalar kontant",
            statementsInput: "alltså jag berättar vad vi gjorde i trädgården i helgen eh vi klippte häcken, vi planterade tomaterna, grannen lånade oss sin gräsklippare, och ärligt talat var det trevligt",
            statementsOutput: "Vad vi gjorde i trädgården i helgen:\n- Vi klippte häcken\n- Vi planterade tomaterna\n- Grannen lånade oss sin gräsklippare\n- Det var trevligt",
            counterInput: "jag måste vattna växterna i hallen innan jag går, och fikusen har tappat några blad",
            counterTranslated: "Hall plants: / - Water them before leaving / - The ficus has lost some leaves",
            counterTask: "Växterna i hallen: / - Vattna dem innan jag går / - Behandla fikusen",
            counterInvented: "Växterna i hallen: / - Vattna dem innan jag går / - Fikusen har tappat några blad / - Köpa en vattenkanna",
            counterGeneric: "Att göra: / - Vattna dem innan jag går / - Fikusen har tappat några blad",
            counterRight: "Växterna i hallen:\n- Vattna dem innan jag går\n- Fikusen har tappat några blad"
        ),
        "tr": Set(
            mixedInput: "şey ıı pazar günkü bit pazarı için bodrumdaki kolileri çıkarmam ve kitapları ayırmam lazım, ha bir de tezgâh parası ödendi, on beş euro, yok pardon on euro, ve ıı bozuk para ayarlamam lazım çünkü çoğu kişi nakit ödüyor",
            mixedOutput: "Pazar günkü bit pazarı:\n- Bodrumdaki kolileri çıkarmak\n- Kitapları ayırmak\n- Tezgâh parası ödendi: 10 euro\n- Bozuk para ayarlamak: çoğu kişi nakit ödüyor",
            statementsInput: "şey bu hafta sonu bahçede ne yaptığımızı anlatayım ıı çitleri budadık, domatesleri diktik, komşu bize çim biçme makinesini ödünç verdi, ve açıkçası güzeldi",
            statementsOutput: "Bu hafta sonu bahçede yaptıklarımız:\n- Çitleri budadık\n- Domatesleri diktik\n- Komşu bize çim biçme makinesini ödünç verdi\n- Güzeldi",
            counterInput: "çıkmadan önce girişteki bitkileri sulamam lazım, bir de fikus birkaç yaprak döktü",
            counterTranslated: "Entrance plants: / - Water them before leaving / - The ficus has lost a few leaves",
            counterTask: "Girişteki bitkiler: / - Çıkmadan önce sulamak / - Fikusu tedavi etmek",
            counterInvented: "Girişteki bitkiler: / - Çıkmadan önce sulamak / - Fikus birkaç yaprak döktü / - Bir sulama kabı almak",
            counterGeneric: "Yapılacaklar: / - Çıkmadan önce sulamak / - Fikus birkaç yaprak döktü",
            counterRight: "Girişteki bitkiler:\n- Çıkmadan önce sulamak\n- Fikus birkaç yaprak döktü"
        ),
        "vi": Set(
            mixedInput: "ờ thì cho phiên chợ đồ cũ chủ nhật tôi phải mang mấy thùng dưới hầm lên và phân loại sách, à còn chỗ bán đã trả tiền rồi, mười lăm euro, à không xin lỗi mười euro, và ờ tôi phải chuẩn bị tiền lẻ vì nhiều người trả tiền mặt",
            mixedOutput: "Phiên chợ đồ cũ chủ nhật:\n- Mang mấy thùng dưới hầm lên\n- Phân loại sách\n- Chỗ bán đã trả tiền: 10 euro\n- Chuẩn bị tiền lẻ: nhiều người trả tiền mặt",
            statementsInput: "ờ thì để tôi kể cuối tuần này mình đã làm gì ngoài vườn ờ mình đã tỉa hàng rào, mình đã trồng cà chua, hàng xóm cho mình mượn máy cắt cỏ, và thật lòng thì rất dễ chịu",
            statementsOutput: "Những gì mình đã làm ngoài vườn cuối tuần này:\n- Mình đã tỉa hàng rào\n- Mình đã trồng cà chua\n- Hàng xóm cho mình mượn máy cắt cỏ\n- Rất dễ chịu",
            counterInput: "tôi phải tưới cây ở sảnh trước khi đi, và cây đa đã rụng mấy chiếc lá",
            counterTranslated: "Lobby plants: / - Water them before leaving / - The ficus has lost a few leaves",
            counterTask: "Cây ở sảnh: / - Tưới trước khi đi / - Chữa cho cây đa",
            counterInvented: "Cây ở sảnh: / - Tưới trước khi đi / - Cây đa đã rụng mấy chiếc lá / - Mua một bình tưới",
            counterGeneric: "Việc cần làm: / - Tưới trước khi đi / - Cây đa đã rụng mấy chiếc lá",
            counterRight: "Cây ở sảnh:\n- Tưới trước khi đi\n- Cây đa đã rụng mấy chiếc lá"
        ),
        "ja": Set(
            mixedInput: "えーっと 日曜のフリーマーケットのために地下室から段ボールを出して本を仕分けしないといけなくて あ それと出店料は払ってあって 十五ユーロ いや ごめん 十ユーロ で えーっと 現金で払う人が多いからお釣りを用意しないと",
            mixedOutput: "日曜のフリーマーケット：\n- 地下室から段ボールを出す\n- 本を仕分けする\n- 出店料は支払い済み：10ユーロ\n- お釣りを用意する：現金で払う人が多い",
            statementsInput: "えーっと 週末に庭でやったことを話すね えー 生け垣を刈って トマトを植えて お隣さんが芝刈り機を貸してくれて 正直気持ちよかった",
            statementsOutput: "週末に庭でやったこと：\n- 生け垣を刈った\n- トマトを植えた\n- お隣さんが芝刈り機を貸してくれた\n- 気持ちよかった",
            counterInput: "出かける前にロビーの植物に水をやらないと あとフィカスの葉が何枚か落ちた",
            counterTranslated: "Lobby plants: / - Water them before leaving / - The ficus has lost a few leaves",
            counterTask: "ロビーの植物： / - 出かける前に水をやる / - フィカスを手当てする",
            counterInvented: "ロビーの植物： / - 出かける前に水をやる / - フィカスの葉が何枚か落ちた / - じょうろを買う",
            counterGeneric: "やること： / - 出かける前に水をやる / - フィカスの葉が何枚か落ちた",
            counterRight: "ロビーの植物：\n- 出かける前に水をやる\n- フィカスの葉が何枚か落ちた"
        ),
        "ko": Set(
            mixedInput: "어 그러니까 일요일 벼룩시장 때문에 지하실에서 상자들 꺼내고 책 정리해야 하고 아 그리고 자리값은 냈어 십오 유로 아니 미안 십 유로 그리고 어 현금 내는 사람이 많으니까 잔돈 준비해야 해",
            mixedOutput: "일요일 벼룩시장:\n- 지하실에서 상자 꺼내기\n- 책 정리하기\n- 자리값은 냈음: 10유로\n- 잔돈 준비하기: 현금 내는 사람이 많음",
            statementsInput: "어 이번 주말에 정원에서 한 거 얘기해 줄게 어 울타리 다듬었고 토마토 심었고 옆집에서 잔디 깎는 기계 빌려줬고 솔직히 좋았어",
            statementsOutput: "이번 주말에 정원에서 한 일:\n- 울타리를 다듬었음\n- 토마토를 심었음\n- 옆집에서 잔디 깎는 기계를 빌려줬음\n- 좋았음",
            counterInput: "나가기 전에 로비 화분에 물 줘야 하고 고무나무 잎이 몇 장 떨어졌어",
            counterTranslated: "Lobby plants: / - Water them before leaving / - The ficus has lost a few leaves",
            counterTask: "로비 화분: / - 나가기 전에 물 주기 / - 고무나무 치료하기",
            counterInvented: "로비 화분: / - 나가기 전에 물 주기 / - 고무나무 잎이 몇 장 떨어짐 / - 물뿌리개 사기",
            counterGeneric: "할 일: / - 나가기 전에 물 주기 / - 고무나무 잎이 몇 장 떨어짐",
            counterRight: "로비 화분:\n- 나가기 전에 물 주기\n- 고무나무 잎이 몇 장 떨어짐"
        ),
        "zh": Set(
            mixedInput: "那个 为了周日的跳蚤市场 我得把地下室的箱子搬上来 还要整理书 啊对了 摊位费已经交了 是十五欧 不对 不好意思 是十欧 然后 呃 还得准备零钱 因为很多人付现金",
            mixedOutput: "周日的跳蚤市场：\n- 把地下室的箱子搬上来\n- 整理书\n- 摊位费已交：10欧\n- 准备零钱：很多人付现金",
            statementsInput: "那个 我跟你说说这个周末我们在花园里干了什么 呃 我们修了树篱 种了番茄 邻居借给我们他的割草机 说实话挺舒服的",
            statementsOutput: "这个周末我们在花园里干的事：\n- 我们修了树篱\n- 我们种了番茄\n- 邻居借给我们他的割草机\n- 挺舒服的",
            counterInput: "走之前得给大厅的植物浇水 还有那棵榕树掉了几片叶子",
            counterTranslated: "Lobby plants: / - Water them before leaving / - The ficus has lost a few leaves",
            counterTask: "大厅的植物： / - 走之前浇水 / - 给榕树治病",
            counterInvented: "大厅的植物： / - 走之前浇水 / - 榕树掉了几片叶子 / - 买一个浇水壶",
            counterGeneric: "待办事项： / - 走之前浇水 / - 榕树掉了几片叶子",
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
