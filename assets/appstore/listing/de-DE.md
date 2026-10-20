# App Store listing, de-DE, 2.0.0 (draft)

Draft for issue #643, the German wave of the approved English set (`export/de-DE/v15-B/`, slides in the same order). It mirrors `listing/fr-FR.md` and `listing/en-GB.md`; the claims and their sources are the same (see the facts table in `listing/en-GB.md`). **Nothing here is in App Store Connect.**

Register: **du**, Apple's own German convention. German typography („…“ quotes), no em dashes.

**The app has no German localisation** (`Localizable.xcstrings` holds en and fr only), so the screenshots show its English chrome and the description says so in one line. Dictation, the keyboard and its autocorrect do work in German.

**Depends on the 2.0.0 Pro flip**, as the English draft (`PremiumFlags.paywallVisible`, #279).

## Name

**`Dictus: AI Voice Keyboard`** (25/30), the English name, kept as in fr-FR. Its words are indexed for this locale, so none of them is repeated below.

## Subtitle

**`Diktat & Sprachnachrichten`** (26/30)

"Private" does not fit beside the German word for voice messages within 30 characters; privacy moves to the description and slide 6. „Sprachnachrichten“ is the phrase German users type for chat voice notes. No word overlaps the English name.

## Promotional text

> Neu in 2.0: Dictus Pro. Übersetze beim Sprechen und lies Sprachnachrichten aus deinen Chats direkt in der Tastatur. 14 Tage gratis auf iPhones mit Apple Intelligence.

"Apple Intelligence" is load-bearing, as in English: the trial never starts on a device that cannot run Smart Modes (#593 decision 2).

## Keywords

**Proposed:** `tastatur,text,ki,diktieren,transkription,übersetzen,offline,whisper,open source,zusammenfassung`

- **No ranking data was read.** Chosen from the product's vocabulary and the English set's reasoning; nothing from App Store Connect analytics, Apple Ads or an ASO tool was consulted.
- Not repeated, because they are already indexed from the name or the subtitle: `dictus`, `ai`, `voice`, `keyboard`, `diktat`, `sprachnachrichten`.
- `tastatur` and `ki`: the German for the English name's `Keyboard` and `AI`, indexed nowhere else.
- `text` with `diktieren` and the name's `voice` covers "Sprache zu Text"; `transkription` the generic search.
- `übersetzen` for Translate (Pro), `zusammenfassung` for Summary.
- `offline`, `whisper`, `open source`: the technical and privacy terms ("offline" is the word German users type).
- Dropped for length: `sprache` (104 bytes with it).
- No trademarks (guideline 2.3.7).

## Description

Follows the seven V15-B slides, in order and with their headlines. Smart Mode names stay in English because that is how the app shows them in this locale.

```
Sprich, statt zu tippen. Dictus ist eine Tastatur, die schreibt, was du sagst: Tippe auf das Mikrofon, sprich, und deine Worte erscheinen in jeder App. Die Spracherkennung läuft auf deinem iPhone, auch ohne Verbindung.

DIKTIERE IN JEDER APP

Nachrichten, E-Mails, Notizen, Erinnerungen: Überall, wo du schreiben kannst, ist Dictus einen Tipp entfernt. Sprich ganz natürlich, und der Text erscheint dort, wo dein Cursor steht.

ÜBERSETZE BEIM SPRECHEN (PRO)

Smart Modes machen aus deinem Diktat den Text, den du brauchst, bevor er eingefügt wird. Halte das Mikrofon gedrückt, wähle einen Modus und sprich:
- Translate: ins Französische, Englische, Deutsche oder Spanische
- Message: die kurze Nachricht, die du getippt hättest
- List: deine Gedanken als Stichpunkte
- Structured: ein langes Diktat in klaren Absätzen
- Summary: das Wichtigste aus dem, was du gesagt hast

Smart Modes laufen mit Apple Intelligence auf deinem iPhone (iPhone 15 Pro oder neuer, iOS 26 oder neuer). Deine Worte gehen an keinen Server.

SPRACHNACHRICHTEN IN DER TASTATUR LESEN (PRO)

Eine Sprachnachricht, die du gerade nicht anhören kannst? Teile sie aus deiner Chat-App mit Dictus. Sie wird auf deinem iPhone transkribiert, und die Abschrift wartet in der Tastatur, wenn du zum Chat zurückkehrst. Lies sie und füge sie mit einem Tipp ein, wenn du sie zitieren willst.

EINE ECHTE TASTATUR IN DEINER SPRACHE

Dictus ist eine vollständige Tastatur, nicht nur ein Mikrofon-Button. QWERTZ-, QWERTY- und AZERTY-Layouts mit Autokorrektur und Vorschlägen auf Deutsch, Englisch, Französisch und Spanisch. Tippe, wenn du willst, sprich, wenn es dir lieber ist.

DEINE STIMME BLEIBT AUF DEINEM IPHONE

Die Spracherkennung läuft auf dem Gerät. Kein Konto, kein Tracking, keine Nutzungsstatistiken. Diktiere im Flugzeug, in der U-Bahn, überall. Die Modelle liegen auf deinem iPhone: Lade eines einmal herunter und nutze es dann offline, vom kompakten und schnellen bis zum genauesten.

Dictus ist Open Source (MIT-Lizenz). Jeder kann den Code lesen und diese Datenschutzversprechen prüfen: github.com/getdictus/dictus-ios

DIKTIERE IN ÜBER 40 SPRACHEN

Das Diktieren funktioniert in über 40 Sprachen in guter oder ordentlicher Qualität und mit den Whisper-Modellen in fast 100, wobei die Qualität je nach Sprache variiert. Parakeet, das Standardmodell, transkribiert 25 europäische Sprachen und erkennt, welche du sprichst. Jedes Modell zeigt dir vor dem Download, welche Sprachen es gut beherrscht.

Die App selbst ist auf Englisch und Französisch verfügbar; Diktat und Tastatur funktionieren auf Deutsch.

DICTUS PRO

Pro bringt die Smart Modes, Sprachnachrichten in der Tastatur, einen Verlauf deiner Diktate und dein eigenes Vokabular für Namen und Fachbegriffe.

Teste Pro 14 Tage lang kostenlos. Du schließt nichts ab, und nichts verlängert sich: Nach 14 Tagen wechselt Dictus zurück zur kostenlosen Version und fragt dich, ob du Pro behalten möchtest. Dein Verlauf und dein Vokabular bleiben erhalten. Der Test wird auf iPhones angeboten, auf denen Smart Modes laufen können. Diktieren und Tastatur bleiben kostenlos.

Dictus erhebt keine Daten. Datenschutzerklärung: getdictus.com/privacy
```

## Length check

Measured with `python3` (`len()` for characters, UTF-8 bytes for the keywords, where ä, ö, ü, ß, á, é, í, ó, ú, ñ weigh 2):

| Field | Limit | Length |
|---|---|---|
| Name | 30 | 25 |
| Subtitle | 30 | 26 |
| Promotional text | 170 | 166 |
| Keywords (bytes) | 100 | 96 |
| Description | 4000 | 3166 |
