// DictusCore/Sources/DictusCore/Polish/Prompts/SmartModeSummaryExamples.swift
// The Summary mode's worked examples in every Apple FM language (#571, #587 step 2).
import Foundation

/// Step 2 of #587 decision 5: the worked examples in the transcript's own language.
///
/// ### Why the examples move and the rules do not
///
/// Step 1 — English rules, rule 1 the language rule, one English and one French
/// example — failed on the Mac bench of 2026-09-21: 55 outputs in 130 came back in
/// English across the 13 Apple FM languages that are neither, German and Japanese
/// 10 in 10. The same rules with only the two examples translated gave 0 in 40
/// against 28 in 40 on German, Spanish, Japanese and Chinese. The model takes the
/// examples, not the rules, as the template for the output language, which is what
/// #585 read off the other modes' prompts. So the rules stay one English text and
/// only this table varies.
///
/// ### What every entry is
///
/// The same two scenes in every language — a flat visited near a station, a car at
/// the garage — translated by the agent that wrote #571 from the English and French
/// originals, keeping the spoken style of the input and the first person of the
/// output. Off-domain for this app's users and no person named, for the #414 reason
/// `SmartModeSummaryPrompt` gives. Machine-translated, so a native speaker may find
/// them stiff; they are measured for the output language, not for style.
///
/// Keys are `NLLanguage` base subtags, the 15 languages `SystemLanguageModel` listed
/// on 2026-09-21. `zh` is Simplified; a `zh-Hant` transcript gets the same set, which
/// is the closest the table has rather than a claim that it is right.
enum SmartModeSummaryExamples {

    typealias Example = SmartModeSummaryPrompt.Example

    /// The two scenes in one language, flat first and garage second.
    private static func pair(_ flatInput: String, _ flatOutput: String,
                             _ carInput: String, _ carOutput: String) -> [Example] {
        [Example(input: flatInput, output: flatOutput), Example(input: carInput, output: carOutput)]
    }

    static let byLanguage: [String: [Example]] = [
        "en": pair(
            "so I went to see that flat this afternoon, the one near the station, and honestly the pictures were better than the real thing, the kitchen is tiny, like really tiny, and the second bedroom is more of a cupboard, but the light is great and it's quiet, which I didn't expect so close to the trains, and the rent is fair for the area, so I don't know, I think I'm going to ask if they'd drop the price a bit and sleep on it before I decide",
            "I visited the flat near the station: it is smaller than its pictures, but bright, quiet and fairly priced. I'll ask for a lower rent and sleep on it before deciding.",
            "okay so uh this morning I took the car to the garage because for a week now there's been a weird noise when I brake, a kind of squeal, and the mechanic had a look and told me it was the brake pads, that they were completely worn out, so uh they need changing, he can do it on Thursday, so I said fine, I'll drop by Thursday morning before work, and in the meantime I'm going to avoid the motorway",
            "I took the car to the garage: the squeal when I brake comes from worn brake pads. The mechanic changes them on Thursday, so I'll drop by that morning and avoid the motorway until then."
        ),
        "fr": pair(
            "alors cet après-midi je suis allé voir l'appart, celui près de la gare, et franchement les photos étaient mieux que la réalité, la cuisine est minuscule, mais vraiment minuscule, et la deuxième chambre c'est plutôt un placard, mais il y a une super lumière et c'est calme, ce que j'attendais pas si près des voies, et le loyer est correct pour le quartier, donc je sais pas, je pense que je vais demander s'ils peuvent baisser un peu le prix et dormir dessus avant de décider",
            "J'ai visité l'appart près de la gare : il est plus petit que sur les photos, mais lumineux, calme et à un loyer correct. Je vais demander une baisse et dormir dessus avant de décider.",
            "bon alors euh ce matin j'ai emmené la voiture au garage parce que depuis une semaine y a un bruit bizarre quand je freine, un genre de grincement, et en fait le garagiste il a regardé et il m'a dit que c'était les plaquettes, qu'elles étaient complètement usées, donc euh il faut les changer, il peut le faire jeudi, donc je lui ai dit ok, je repasse jeudi matin avant le boulot, et du coup en attendant je vais éviter de prendre l'autoroute",
            "J'ai emmené la voiture au garage : le grincement au freinage vient des plaquettes, qui sont usées. Le garagiste les change jeudi, je repasse jeudi matin et j'évite l'autoroute d'ici là."
        ),
        "de": pair(
            "also ich hab mir heute Nachmittag die Wohnung angeschaut, die beim Bahnhof, und ehrlich gesagt waren die Fotos besser als die Realität, die Küche ist winzig, echt winzig, und das zweite Schlafzimmer ist eher eine Abstellkammer, aber das Licht ist super und es ist ruhig, was ich so nah an den Gleisen nicht erwartet hätte, und die Miete ist fair für die Gegend, also keine Ahnung, ich glaub ich frag mal, ob sie mit dem Preis ein bisschen runtergehen, und schlaf noch mal drüber, bevor ich mich entscheide",
            "Ich habe mir die Wohnung am Bahnhof angesehen: Sie ist kleiner als auf den Fotos, aber hell, ruhig und fair im Preis. Ich frage nach einer niedrigeren Miete und schlafe noch mal drüber, bevor ich entscheide.",
            "also äh heute Morgen hab ich das Auto in die Werkstatt gebracht, weil es seit einer Woche so ein komisches Geräusch beim Bremsen macht, so ein Quietschen, und der Mechaniker hat nachgeschaut und gesagt, das sind die Bremsbeläge, die sind komplett abgefahren, also äh die müssen gewechselt werden, er kann das am Donnerstag machen, also hab ich gesagt okay, ich komm Donnerstag früh vor der Arbeit vorbei, und bis dahin fahr ich lieber nicht auf die Autobahn",
            "Ich habe das Auto in die Werkstatt gebracht: Das Quietschen beim Bremsen kommt von abgefahrenen Bremsbelägen. Sie werden am Donnerstag gewechselt, ich komme morgens vorbei und meide bis dahin die Autobahn."
        ),
        "es": pair(
            "pues esta tarde fui a ver el piso, el que está cerca de la estación, y la verdad es que las fotos eran mejores que la realidad, la cocina es minúscula, pero minúscula de verdad, y el segundo dormitorio es más bien un trastero, pero tiene muy buena luz y es tranquilo, cosa que no esperaba tan cerca de las vías, y el alquiler es razonable para la zona, así que no sé, creo que voy a preguntar si bajan un poco el precio y lo voy a consultar con la almohada antes de decidir",
            "Fui a ver el piso cerca de la estación: es más pequeño que en las fotos, pero luminoso, tranquilo y con un alquiler razonable. Voy a pedir que bajen el precio y lo pensaré antes de decidir.",
            "bueno pues eh esta mañana llevé el coche al taller porque desde hace una semana hace un ruido raro cuando freno, como un chirrido, y el mecánico lo miró y me dijo que eran las pastillas, que estaban completamente gastadas, así que eh hay que cambiarlas, lo puede hacer el jueves, así que le dije vale, paso el jueves por la mañana antes del trabajo, y mientras tanto voy a evitar coger la autopista",
            "Llevé el coche al taller: el chirrido al frenar viene de las pastillas, que están gastadas. El mecánico las cambia el jueves, paso esa mañana y evito la autopista hasta entonces."
        ),
        "it": pair(
            "allora oggi pomeriggio sono andato a vedere l'appartamento, quello vicino alla stazione, e sinceramente le foto erano meglio della realtà, la cucina è minuscola, ma proprio minuscola, e la seconda camera è più che altro uno sgabuzzino, però c'è una luce bellissima ed è tranquillo, cosa che non mi aspettavo così vicino ai binari, e l'affitto è giusto per la zona, quindi non so, credo che chiederò se possono abbassare un po' il prezzo e ci dormirò sopra prima di decidere",
            "Ho visto l'appartamento vicino alla stazione: è più piccolo che in foto, ma luminoso, tranquillo e con un affitto giusto. Chiederò uno sconto e ci dormirò sopra prima di decidere.",
            "allora ehm stamattina ho portato la macchina dal meccanico perché da una settimana fa un rumore strano quando freno, tipo uno stridio, e il meccanico ha guardato e mi ha detto che erano le pastiglie, che erano completamente consumate, quindi ehm vanno cambiate, lo può fare giovedì, allora gli ho detto va bene, passo giovedì mattina prima del lavoro, e intanto evito di prendere l'autostrada",
            "Ho portato la macchina dal meccanico: lo stridio in frenata viene dalle pastiglie consumate. Le cambia giovedì, passo quella mattina e fino ad allora evito l'autostrada."
        ),
        "pt": pair(
            "então hoje à tarde eu fui ver o apartamento, aquele perto da estação, e sinceramente as fotos eram melhores que a realidade, a cozinha é minúscula, minúscula mesmo, e o segundo quarto é mais um armário, mas a luz é ótima e é silencioso, o que eu não esperava tão perto dos trilhos, e o aluguel é justo pra região, então sei lá, acho que vou perguntar se eles baixam um pouco o preço e pensar com calma antes de decidir",
            "Fui ver o apartamento perto da estação: é menor que nas fotos, mas claro, silencioso e com aluguel justo. Vou pedir um desconto e pensar com calma antes de decidir.",
            "então hã hoje de manhã eu levei o carro na oficina porque faz uma semana que ele faz um barulho estranho quando eu freio, tipo um chiado, e o mecânico olhou e me disse que eram as pastilhas, que estavam completamente gastas, então hã tem que trocar, ele pode fazer na quinta, aí eu disse beleza, passo lá quinta de manhã antes do trabalho, e enquanto isso vou evitar pegar a rodovia",
            "Levei o carro na oficina: o chiado ao frear vem das pastilhas gastas. O mecânico troca na quinta, passo lá de manhã e até lá evito a rodovia."
        ),
        "nl": pair(
            "nou ik ben vanmiddag dat appartement gaan bekijken, dat bij het station, en eerlijk gezegd waren de foto's beter dan het echte ding, de keuken is piepklein, echt piepklein, en de tweede slaapkamer is meer een bezemkast, maar het licht is geweldig en het is rustig, wat ik zo dicht bij het spoor niet had verwacht, en de huur is redelijk voor de buurt, dus ik weet het niet, ik denk dat ik ga vragen of ze wat met de prijs willen zakken en er een nachtje over slaap voordat ik beslis",
            "Ik heb het appartement bij het station bekeken: het is kleiner dan op de foto's, maar licht, rustig en redelijk geprijsd. Ik vraag om een lagere huur en slaap er een nachtje over voordat ik beslis.",
            "oké dus eh vanochtend heb ik de auto naar de garage gebracht omdat hij al een week een raar geluid maakt als ik rem, zo'n piepen, en de monteur heeft gekeken en zei dat het de remblokken waren, dat ze helemaal versleten waren, dus eh die moeten vervangen worden, hij kan het donderdag doen, dus ik zei prima, ik kom donderdagochtend voor het werk langs, en ondertussen vermijd ik de snelweg",
            "Ik heb de auto naar de garage gebracht: het piepen bij het remmen komt van versleten remblokken. Ze worden donderdag vervangen, ik kom 's ochtends langs en vermijd tot dan de snelweg."
        ),
        "da": pair(
            "nå jeg var ude og se lejligheden i eftermiddags, den ved stationen, og ærligt talt var billederne bedre end virkeligheden, køkkenet er bittelille, altså virkelig bittelille, og det andet soveværelse er mere et skab, men lyset er fantastisk og det er stille, hvilket jeg ikke havde regnet med så tæt på skinnerne, og huslejen er rimelig for området, så jeg ved ikke, jeg tror jeg vil spørge om de vil gå lidt ned i pris og sove på det før jeg beslutter mig",
            "Jeg så lejligheden ved stationen: den er mindre end på billederne, men lys, stille og rimelig i pris. Jeg spørger om en lavere husleje og sover på det, før jeg beslutter mig.",
            "okay så øh i morges kørte jeg bilen på værkstedet fordi den i en uge har lavet en mærkelig lyd når jeg bremser, sådan en hvinen, og mekanikeren kiggede på det og sagde at det var bremseklodserne, at de var helt slidte, så øh de skal skiftes, han kan gøre det på torsdag, så jeg sagde okay, jeg kommer forbi torsdag morgen før arbejde, og indtil da undgår jeg motorvejen",
            "Jeg kørte bilen på værkstedet: hvinen når jeg bremser kommer fra slidte bremseklodser. De bliver skiftet torsdag, jeg kommer forbi om morgenen og undgår motorvejen indtil da."
        ),
        "nb": pair(
            "ja altså jeg var og så på leiligheten i ettermiddag, den ved stasjonen, og ærlig talt var bildene bedre enn virkeligheten, kjøkkenet er bitte lite, altså skikkelig bitte lite, og det andre soverommet er mer som en bod, men lyset er kjempefint og det er stille, noe jeg ikke hadde forventet så nær skinnene, og husleia er grei for området, så jeg vet ikke, jeg tror jeg skal spørre om de kan gå litt ned i pris og sove på det før jeg bestemmer meg",
            "Jeg så på leiligheten ved stasjonen: den er mindre enn på bildene, men lys, stille og grei i pris. Jeg spør om lavere husleie og sover på det før jeg bestemmer meg.",
            "ok så eh i morges leverte jeg bilen på verkstedet fordi den i en uke har laget en rar lyd når jeg bremser, sånn en hvining, og mekanikeren så på det og sa at det var bremseklossene, at de var helt slitt, så eh de må byttes, han kan gjøre det på torsdag, så jeg sa greit, jeg kommer innom torsdag morgen før jobb, og i mellomtiden holder jeg meg unna motorveien",
            "Jeg leverte bilen på verkstedet: hvinet når jeg bremser kommer fra slitte bremseklosser. De byttes på torsdag, jeg kommer innom om morgenen og holder meg unna motorveien til da."
        ),
        "sv": pair(
            "alltså jag var och tittade på lägenheten i eftermiddags, den vid stationen, och ärligt talat var bilderna bättre än verkligheten, köket är pyttelitet, alltså verkligen pyttelitet, och det andra sovrummet är mer som en garderob, men ljuset är jättefint och det är tyst, vilket jag inte hade trott så nära spåren, och hyran är rimlig för området, så jag vet inte, jag tror jag ska fråga om de kan gå ner lite i pris och sova på saken innan jag bestämmer mig",
            "Jag tittade på lägenheten vid stationen: den är mindre än på bilderna, men ljus, tyst och rimligt prissatt. Jag frågar om lägre hyra och sover på saken innan jag bestämmer mig.",
            "okej så eh i morse lämnade jag bilen på verkstaden för att den i en vecka har låtit konstigt när jag bromsar, typ ett gnissel, och mekanikern tittade och sa att det var bromsbeläggen, att de var helt slitna, så eh de måste bytas, han kan göra det på torsdag, så jag sa okej, jag kommer förbi torsdag morgon före jobbet, och under tiden undviker jag motorvägen",
            "Jag lämnade bilen på verkstaden: gnisslet när jag bromsar kommer från slitna bromsbelägg. De byts på torsdag, jag kommer förbi på morgonen och undviker motorvägen tills dess."
        ),
        "tr": pair(
            "şey bu öğleden sonra şu daireye bakmaya gittim, istasyonun yanındakine, ve açıkçası fotoğraflar gerçeğinden daha iyiydi, mutfak minicik, yani gerçekten minicik, ikinci yatak odası da daha çok bir dolap gibi, ama ışığı harika ve sessiz, raylara bu kadar yakın olduğu için hiç beklemiyordum, kira da bölgeye göre makul, yani bilmiyorum, sanırım fiyatı biraz düşürürler mi diye soracağım ve karar vermeden önce bir gece düşüneceğim",
            "İstasyonun yanındaki daireye baktım: fotoğraflardakinden küçük ama aydınlık, sessiz ve kirası makul. Kirayı biraz düşürmelerini isteyeceğim ve karar vermeden önce bir gece düşüneceğim.",
            "tamam şey bu sabah arabayı servise götürdüm çünkü bir haftadır fren yapınca garip bir ses çıkarıyor, bir tür gıcırtı, usta baktı ve balataların tamamen aşındığını söyledi, yani şey değişmesi lazım, perşembe yapabilirmiş, ben de tamam dedim, perşembe sabahı işten önce uğrarım, bu arada da otoyola çıkmamaya çalışacağım",
            "Arabayı servise götürdüm: frendeki gıcırtı aşınmış balatalardan geliyor. Usta perşembe değiştirecek, o sabah uğrayacağım ve o zamana kadar otoyoldan kaçınacağım."
        ),
        "vi": pair(
            "thì chiều nay tôi đi xem căn hộ, cái gần nhà ga ấy, và nói thật là ảnh đẹp hơn thực tế, bếp thì bé tí, bé tí thật sự, phòng ngủ thứ hai thì giống cái tủ hơn, nhưng ánh sáng rất đẹp và yên tĩnh, điều mà tôi không ngờ khi ở gần đường ray như vậy, còn tiền thuê thì hợp lý so với khu đó, nên tôi cũng không biết nữa, chắc tôi sẽ hỏi xem họ có giảm giá một chút không rồi suy nghĩ thêm một đêm rồi mới quyết định",
            "Tôi đã đi xem căn hộ gần nhà ga: nó nhỏ hơn trong ảnh nhưng sáng, yên tĩnh và giá thuê hợp lý. Tôi sẽ hỏi giảm giá và suy nghĩ thêm một đêm trước khi quyết định.",
            "ừ thì ờ sáng nay tôi mang xe ra gara vì cả tuần nay cứ phanh là có tiếng kêu lạ, kiểu tiếng rít ấy, thợ xem rồi bảo là má phanh, mòn hết rồi, nên ờ phải thay, thứ năm anh ấy làm được, thế là tôi bảo được, sáng thứ năm tôi ghé qua trước khi đi làm, còn trong lúc chờ thì tôi sẽ tránh đi đường cao tốc",
            "Tôi đã mang xe ra gara: tiếng rít khi phanh là do má phanh bị mòn. Thợ sẽ thay vào thứ năm, sáng hôm đó tôi ghé qua và từ giờ đến lúc đó tôi tránh đường cao tốc."
        ),
        "ja": pair(
            "今日の午後、駅の近くのあの部屋を見に行ったんだけど、正直写真のほうが実物より良かった、キッチンがすごく狭くて、本当に狭くて、二つ目の寝室はほとんど物置みたいなんだけど、日当たりはすごく良くて静かで、線路の近くなのに意外だった、家賃もこのあたりにしては妥当だし、うーん、どうしようかな、少し値下げできるか聞いてみて、一晩考えてから決めようと思う",
            "駅近くの部屋を見てきた。写真より狭いけど、明るくて静かで家賃も妥当だ。少し値下げを頼んで、一晩考えてから決める。",
            "えっと、今朝車を修理工場に持っていったんだ、一週間前からブレーキをかけると変な音がして、キーキーっていう音で、それで整備士さんが見てくれて、ブレーキパッドが完全にすり減ってるって言われて、だから、えー、交換しないといけなくて、木曜日にやってくれるって、だからオッケーって言って、木曜の朝、仕事の前に寄ることにした、それまでは高速道路は使わないようにする",
            "車を修理工場に持っていった。ブレーキのキーキー音はすり減ったパッドが原因だ。木曜に交換してもらうので朝に寄り、それまで高速は避ける。"
        ),
        "ko": pair(
            "그러니까 오늘 오후에 그 집 보러 갔었거든, 역 근처에 있는 거, 근데 솔직히 사진이 실물보다 나았어, 부엌이 엄청 작아, 진짜 엄청 작아, 그리고 두 번째 방은 거의 창고 수준인데, 그래도 채광이 정말 좋고 조용해, 선로 바로 옆인데 그건 예상 못 했어, 월세도 그 동네치고는 적당하고, 그래서 모르겠어, 가격을 좀 깎아 줄 수 있는지 물어보고 하룻밤 생각해 본 다음에 결정하려고",
            "역 근처 집을 보고 왔다. 사진보다 작지만 밝고 조용하고 월세도 적당하다. 월세를 좀 깎아 달라고 하고 하룻밤 생각한 뒤에 결정하겠다.",
            "음 그러니까 오늘 아침에 차를 정비소에 맡겼어, 일주일 전부터 브레이크 밟을 때 이상한 소리가 나서, 끼익 하는 소리, 그래서 정비사가 봤는데 브레이크 패드가 완전히 닳았대, 그래서 음 교체해야 한대, 목요일에 해 줄 수 있다고 해서 알겠다고 했어, 목요일 아침 출근 전에 들를 거고, 그때까지는 고속도로는 안 타려고",
            "차를 정비소에 맡겼다. 브레이크 끼익 소리는 닳은 패드 때문이다. 목요일에 교체하니 그날 아침에 들르고, 그때까지 고속도로는 피하겠다."
        ),
        "zh": pair(
            "我今天下午去看了那套房子，就是车站旁边那套，说实话照片比实物好看，厨房特别小，真的特别小，第二个卧室更像个储物间，但是采光特别好，也很安静，离铁轨这么近我都没想到，而且这个地段租金也算合理，所以我也不知道，我想问问他们能不能便宜一点，然后再考虑一晚上再决定",
            "我去看了车站旁边的房子：比照片小，但采光好、安静，租金也合理。我会问问能不能降点房租，考虑一晚再决定。",
            "嗯那个今天早上我把车开到修车厂去了，因为一个星期以来刹车的时候总有个怪声，就是那种吱吱的声音，然后修车师傅看了一下说是刹车片，已经完全磨损了，所以嗯得换，他星期四能弄，所以我就说好，我星期四早上上班前过去，然后在那之前我尽量不上高速",
            "我把车送去了修车厂：刹车时的吱吱声是因为刹车片磨损了。师傅星期四换，我那天早上过去，在那之前不上高速。"
        )
    ]

    /// The set for a transcript in `languageCode` (an `NLLanguage` raw value such as
    /// `de`, `zh-Hans`, `pt-BR`), or nil when the table has none.
    static func examples(forLanguageCode languageCode: String) -> [Example]? {
        let base = languageCode.split(separator: "-").first.map { String($0).lowercased() } ?? ""
        return byLanguage[base]
    }
}
