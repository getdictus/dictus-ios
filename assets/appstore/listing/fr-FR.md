# App Store listing, fr-FR, 2.0.0 (draft)

Draft for issue #643, the French wave of the approved English set (`export/fr-FR/v15-B/`, slides in the same order). It mirrors `listing/en-GB.md`; the claims and their sources are the same, re-read below. **Nothing here is in App Store Connect.**

Register: **tu**, decided by Pierre on 2026-10-06 (the keyboard already says "tu"; DictusApp follows in #662). French typography: a non-breaking space (U+00A0) before `: ; ! ?` and inside « », typographic apostrophes, no em dashes.

Limits checked with `python3` (characters; keywords counted in UTF-8 bytes, where an accented letter weighs 2): see the table at the end.

**Depends on the 2.0.0 Pro flip**, as the English draft: the Pro and trial paragraphs describe the app once `PremiumFlags.paywallVisible` is `true` (#279).

## Name

**`Dictus: AI Voice Keyboard`** (25/30), the English name, kept in French (Pierre, 2026-10-06). Its words (`Dictus`, `AI`, `Voice`, `Keyboard`) are indexed for this locale, so none of them is repeated below; their French equivalents are not in the name, which is why `clavier`, `vocal` and `ia` go into the keywords.

## Subtitle

**`Dictée privée, messages vocaux`** (30/30)

The English subtitle, `Private dictation, voice notes`, for the same reasons: it holds for every Pro buyer (voice notes need no Apple Intelligence). No word overlaps the English name, so all four are new indexed words. « Messages vocaux » is the app's own name for the feature (`Voice notes` → `Messages vocaux` in `DictusApp/Localizable.xcstrings`), and the phrase French users type. « Hors ligne » moves to the keywords and the description, as "offline" did.

## Promotional text

For launch week:

> Nouveau dans la 2.0 : Dictus Pro. Traduis en parlant et lis les vocaux de tes discussions dans ton clavier. Gratuit 14 jours sur les iPhone avec Apple Intelligence.

"Sur les iPhone avec Apple Intelligence" is load-bearing, as in English: the trial never starts on a device that cannot run Smart Modes (#593 decision 2).

## Keywords

**Proposed:** `clavier,vocal,transcription,texte,parole,traduction,audio,hors ligne,whisper,résumé,open source,ia`

- **No ranking data was read.** These are chosen from the product's own vocabulary and the English set's reasoning, not from search volumes: nothing from App Store Connect analytics, Apple Ads or a third-party ASO tool was consulted.
- Not repeated, because they are already indexed from the name or the subtitle (Apple combines fields): `dictus`, `ai`, `voice`, `keyboard`, `dictée`, `privée`, `messages`, `vocaux`.
- `clavier`, `vocal` and `ia`: the French for the English name's `Keyboard`, `Voice` and `AI`. With an English name they would otherwise be indexed nowhere, and « clavier vocal », « clavier IA » are the core French searches. `vocal` is kept beside `vocaux` (subtitle) because Apple does not document whether it matches singular and plural.
- `texte` + `parole` + `vocal` cover « parole en texte », « texte vocal »; `transcription` the generic search; `audio` « audio en texte ».
- `traduction` for Translate (Pro); `résumé` for Summary.
- `hors ligne`, `whisper`, `open source`: the English set's technical and privacy terms. « Hors ligne » is the term a French user types, not "offline".
- Dropped to make room for `clavier`, `vocal`, `ia`: `traduire` (assumed covered by `traduction`), `note`, `stt`. Not included: `traducteur`, `micro`, language names (`français`, `anglais`), and no trademarks (guideline 2.3.7).

## Description

Follows the seven V15-B slides, in order and with their headlines.

```
Parle au lieu de taper. Dictus est un clavier qui écrit ce que tu dis : touche le micro, parle, et tes mots s’affichent dans n’importe quelle app. La reconnaissance vocale tourne sur ton iPhone, même sans connexion.

DICTE DANS TOUTES TES APPS

Messages, e-mails, notes, rappels : partout où tu peux écrire, Dictus est à portée de doigt. Parle naturellement, et le texte arrive là où se trouve ton curseur.

TRADUIS EN PARLANT (PRO)

Les modes intelligents transforment ta dictée en texte prêt à envoyer, avant même qu’il soit tapé. Maintiens le micro, choisis un mode, et parle :
- Traduction : vers le français, l’anglais, l’allemand ou l’espagnol
- Message : le message court que tu aurais tapé
- Liste : tes idées sous forme de puces
- Structuré : une longue dictée en paragraphes clairs
- Résumé : l’essentiel de ce que tu as dit

Les modes intelligents tournent sur ton iPhone avec Apple Intelligence (iPhone 15 Pro ou plus récent, iOS 26 ou plus récent). Tes mots ne partent vers aucun serveur.

LIS TES VOCAUX DANS LE CLAVIER (PRO)

Un message vocal que tu ne peux pas écouter tout de suite ? Partage-le vers Dictus depuis ton app de messagerie. Il est transcrit sur ton iPhone, et la transcription t’attend dans le clavier quand tu reviens dans la conversation. Lis-la, puis insère-la d’un geste si tu veux la citer.

UN VRAI CLAVIER DANS TA LANGUE

Dictus est un clavier complet, pas seulement un bouton micro. Dispositions AZERTY, QWERTY et QWERTZ, avec correction automatique et suggestions en français, en anglais, en allemand et en espagnol. Tape quand tu veux, parle quand tu préfères.

TA VOIX RESTE SUR TON IPHONE

La reconnaissance vocale se fait sur l’appareil. Pas de compte, pas de pistage, pas de statistiques d’usage. Dicte en avion, dans le métro, partout. Les modèles sont sur ton iPhone : télécharges-en un une fois, puis utilise-le hors ligne, du plus compact et rapide au plus précis.

Dictus est open source (licence MIT). Chacun peut lire le code et vérifier ces engagements de confidentialité : github.com/getdictus/dictus-ios

DICTE DANS PLUS DE 40 LANGUES

La dictée fonctionne dans plus de 40 langues avec une qualité bonne ou correcte, et dans près de 100 avec les modèles Whisper, où la qualité varie selon la langue. Parakeet, le modèle par défaut, transcrit 25 langues européennes et reconnaît celle que tu parles. Chaque modèle indique les langues qu’il gère bien avant que tu le télécharges.

DICTUS PRO

Pro ajoute les modes intelligents, les messages vocaux dans le clavier, l’historique de tes dictées et ton propre vocabulaire pour les noms et les termes techniques.

Essaie Pro gratuitement pendant 14 jours. Il n’y a rien à souscrire et rien ne se renouvelle : à la fin des 14 jours, Dictus repasse en version gratuite et te demande si tu veux garder Pro. Ton historique et ton vocabulaire sont conservés. L’essai est proposé sur les iPhone capables de faire tourner les modes intelligents. La dictée et le clavier restent gratuits.

Dictus ne collecte aucune donnée. Politique de confidentialité : getdictus.com/privacy
```

### Facts behind the copy

The same claims as `listing/en-GB.md`, with the same sources; re-check them at the 2.0.0 cut.

| Claim | Source |
|---|---|
| Five Smart Modes, French names Message, Liste, Structuré, Résumé, and Translate (shown as `→ EN` etc.) | `SmartModeCatalogue.builtIns`, `DictusKeyboard/Localizable.xcstrings` |
| Translate targets: French, English, German, Spanish | `SupportedLanguage.allCases` |
| Apple Intelligence: iPhone 15 Pro or later, iOS 26 or later | the app's own string `Requires Apple Intelligence (iPhone 15 Pro or later, iOS 26)`; **to confirm against Apple's current device list** |
| Pro = modes intelligents, messages vocaux, historique, vocabulaire | `ProFeature` |
| 14-day reverse trial, nothing to subscribe to, nothing renews, back to free at the end with an offer to keep Pro, data kept, no trial where Smart Modes can never run | `ProTrial.durationDays = 14`, `ProTrialPolicy` (definitive reasons), #593 decisions 1 and 2 |
| 40+ languages at good or fair quality, Parakeet 25 European, Whisper close to 100 | `ModelLanguageSupport.swift`, #488; slide 7 |
| Keyboard: 4 languages, 3 layouts | `SupportedLanguage.swift`, `KeyboardLayouts.swift` |
| No account, no tracking, no analytics, no data collected | App Privacy "Data Not Collected" |

## Length check

Measured with `python3` on this file's fenced and quoted texts (`len()` for characters, `len(s.encode("utf-8"))` for the keyword bytes):

| Field | Limit | Length |
|---|---|---|
| Name | 30 | 25 |
| Subtitle | 30 | 30 |
| Promotional text | 170 | 164 |
| Keywords (bytes) | 100 | 100 |
| Description | 4000 | 3066 |
