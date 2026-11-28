// DictusCore/Sources/DictusCore/SpatialDecoder/SwipeBrandList.swift
//
// GENERATED, do not edit by hand: the brand names a swipe reads in each language (#1090).
// Read by `SwipeBrands.names(for:)`.
//
// Source: Wikidata, https://www.wikidata.org, under CC0 1.0
// (https://creativecommons.org/publicdomain/zero/1.0/, https://www.wikidata.org/wiki/Wikidata:Licensing):
// no attribution is required; Réglages › Licences credits it anyway. Query run on 2026-11-27
// against https://query.wikidata.org/sparql (items of the types below with at least 20
// sitelinks, and their English label):
//
//     SELECT ?item ?label ?sl ?type WHERE {
//       VALUES ?type { wd:Q431289 wd:Q4830453 wd:Q891723 wd:Q6881511 wd:Q167037 wd:Q35127 wd:Q620615 wd:Q1668024 wd:Q19967801 }
//       ?item wdt:P31 ?type ; wikibase:sitelinks ?sl .
//       FILTER(?sl >= 20)
//       ?item rdfs:label ?label . FILTER(LANG(?label) = "en")
//     }
//
// The types are brand, business, public company, enterprise, corporation, website, mobile
// app, service on internet and online service. Each label lost its corporate suffix (Inc,
// Corporation, Ltd, AG, SE, SA, plc, Group, Holding, Company, LLC, NV, GmbH, Motor(s),
// Electronics, Airlines), and was kept only as one word of 3 letters or more, not all
// lowercase (a generic word) and not an acronym of 4 capitals or fewer (typed, not swiped).
// The list is its first 100 by sitelinks, plus Samsung and Android, which Pierre asked for
// (2026-11-27) and the cut leaves out.
//
// Per language, a name is kept only where the language's swipe model (`<lang>.hextm`) lacks
// the word, its letters are on the keys, and `CuratedNames` does not already spell it.
// Then rule v3 drops a name that takes the first reading of a dictionary word of model
// cost (-ln P) 15 or less in more than 5 % of that word's typical swipes or more than 15 %
// of its sloppy ones (tuned on the swipe bench's dev sentences, checked on its test
// sentences). Applied offline: the keyboard reads only the names below.
//
// Dropped by rule v3, de (4): Nike, Gucci, Flickr, Lego.
// Dropped by rule v3, en (8): SpaceX, Sony, Boeing, Honda, Mazda, Flickr, Tata, Coursera.
// Dropped by rule v3, es (8): Ford, Audi, Nokia, Pixar, Mac, Fiat, Rolex, Android.
// Dropped by rule v3, fr (7): Ford, Intel, PayPal, Barbie, Reuters, Kia, Android.

extension SwipeBrands {
    /// The brand names each language's swipe reads, best known first.
    static let byLanguage: [String: [String]] = [
        // German: 65 names.
        "de": [
            "Microsoft", "Toyota", "Nintendo", "Amazon", "SpaceX", "Sony", "Nokia", "Wikinews", "Adidas",
            "Forbes", "Honda", "Wikispecies", "Intel", "OpenAI", "Huawei", "PayPal", "Pixar", "Yamaha", "Mac",
            "eBay", "Myspace", "Turkish", "Xiaomi", "Adobe", "Lamborghini", "Nupedia", "Nvidia", "Lenovo",
            "Suzuki", "Mazda", "GitHub", "Kia", "Billboard", "Panasonic", "Siemens", "United", "Gazprom",
            "Motorola", "Oracle", "Hyundai", "Pfizer", "Shell", "Aeroflot", "Ryanair", "Toshiba", "Yandex",
            "Uber", "American", "Baidu", "ExxonMobil", "Alibaba", "Mitsubishi", "Tata", "Cisco", "Volkswagen",
            "Coursera", "Nikon", "Prada", "TotalEnergies", "WorldCat", "PepsiCo", "Rolex", "Singapore",
            "SoundCloud", "Samsung"
        ],
        // English: 61 names.
        "en": [
            "Microsoft", "Toyota", "Nintendo", "Audi", "Nokia", "Skype", "Wikinews", "Adidas", "Forbes",
            "Wikispecies", "Lufthansa", "OpenAI", "Ferrari", "Huawei", "PayPal", "Pixar", "Yamaha", "Porsche",
            "eBay", "Nissan", "Reuters", "Myspace", "Nike", "Turkish", "Xiaomi", "Lamborghini", "Nupedia",
            "Nvidia", "Lenovo", "Suzuki", "GitHub", "Kia", "Panasonic", "Gazprom", "Motorola", "Hyundai",
            "Pfizer", "Aeroflot", "Gucci", "Ryanair", "Toshiba", "Yandex", "Uber", "American", "Baidu",
            "ExxonMobil", "Lego", "Alibaba", "Mitsubishi", "Volkswagen", "Malaysia", "Nikon", "Prada",
            "TotalEnergies", "WorldCat", "Bayer", "PepsiCo", "Rolex", "Singapore", "SoundCloud", "Samsung"
        ],
        // Spanish: 77 names.
        "es": [
            "Google", "Apple", "Microsoft", "Toyota", "Nintendo", "Amazon", "SpaceX", "Sony", "Skype",
            "Wikinews", "Adidas", "Boeing", "Forbes", "Wikispecies", "Intel", "Lufthansa", "OpenAI",
            "Ferrari", "Huawei", "PayPal", "Yamaha", "Barbie", "Nestlé", "Porsche", "eBay", "Nissan",
            "Reuters", "Myspace", "Nike", "Turkish", "Xiaomi", "Lamborghini", "Nupedia", "Nvidia", "Lenovo",
            "Suzuki", "Mazda", "GitHub", "Kia", "Billboard", "Panasonic", "Siemens", "United", "Gazprom",
            "Motorola", "Oracle", "Alphabet", "Hyundai", "Pfizer", "Shell", "Aeroflot", "Gucci", "Ryanair",
            "Toshiba", "Blogger", "Flickr", "Yandex", "Uber", "American", "Baidu", "ExxonMobil", "Alibaba",
            "Mitsubishi", "Volkswagen", "Malaysia", "Coursera", "Jeep", "Nikon", "Prada", "TotalEnergies",
            "Vogue", "WorldCat", "Bayer", "PepsiCo", "Singapore", "SoundCloud", "Samsung"
        ],
        // French: 74 names.
        "fr": [
            "Google", "Apple", "Microsoft", "Toyota", "Nintendo", "Amazon", "SpaceX", "Audi", "Sony", "Nokia",
            "Skype", "Wikinews", "Adidas", "Boeing", "Forbes", "Honda", "Wikispecies", "Lufthansa", "Time",
            "OpenAI", "Ferrari", "Huawei", "Pixar", "Yamaha", "Nestlé", "Porsche", "eBay", "General",
            "Nissan", "Myspace", "Nike", "Turkish", "Xiaomi", "Lamborghini", "Nupedia", "Nvidia", "Lenovo",
            "Suzuki", "Mazda", "GitHub", "Billboard", "Panasonic", "United", "Gazprom", "Motorola", "Hyundai",
            "Pfizer", "Aeroflot", "Gucci", "Ryanair", "Toshiba", "Blogger", "Flickr", "Yandex", "Uber",
            "American", "Baidu", "ExxonMobil", "Lego", "Alibaba", "Mitsubishi", "Cisco", "Volkswagen",
            "Malaysia", "Coursera", "Nikon", "Prada", "TotalEnergies", "WorldCat", "PepsiCo", "Rolex",
            "Singapore", "SoundCloud", "Samsung"
        ]
    ]
}
