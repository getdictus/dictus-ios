# App Store listing, es-ES, 2.0.0 (draft)

Draft for issue #643, the Spanish wave of the approved English set (`export/es-ES/v15-B/`, slides in the same order). It mirrors `listing/fr-FR.md` and `listing/en-GB.md`; the claims and their sources are the same (see the facts table in `listing/en-GB.md`). **Nothing here is in App Store Connect.**

Register: **tú**, Apple's own Spanish convention. Spanish typography (¿ ¡), no em dashes.

**The app has no Spanish localisation** (`Localizable.xcstrings` holds en and fr only), so the screenshots show its English chrome and the description says so in one line. Dictation, the keyboard and its autocorrect do work in Spanish.

**Depends on the 2.0.0 Pro flip**, as the English draft (`PremiumFlags.paywallVisible`, #279).

## Name

**`Dictus: AI Voice Keyboard`** (25/30), the English name, kept as in fr-FR. Its words are indexed for this locale, so none of them is repeated below.

## Subtitle

**`Dictado privado, notas de voz`** (29/30)

The English subtitle, word for word: «notas de voz» is WhatsApp's own Spanish term. No word overlaps the English name.

## Promotional text

> Novedad en la 2.0: Dictus Pro. Traduce mientras hablas y lee los audios de tus chats en el teclado. Gratis 14 días en iPhone con Apple Intelligence.

"Apple Intelligence" is load-bearing, as in English: the trial never starts on a device that cannot run Smart Modes (#593 decision 2).

## Keywords

**Proposed:** `teclado,dictar,texto,ia,transcripción,traducir,audio,sin conexión,whisper,código abierto,resumen`

- **No ranking data was read.** Chosen from the product's vocabulary and the English set's reasoning; nothing from App Store Connect analytics, Apple Ads or an ASO tool was consulted.
- Not repeated, because they are already indexed from the name or the subtitle: `dictus`, `ai`, `voice`, `keyboard`, `dictado`, `privado`, `notas`, `voz`.
- `teclado` and `ia`: the Spanish for the English name's `Keyboard` and `AI`, indexed nowhere else.
- `dictar` (the verb, beside `dictado`: Apple does not document its stemming), `texto` + `voz` (subtitle) for "voz a texto", `transcripción`, `audio`.
- `traducir` for Translate (Pro), `resumen` for Summary.
- `sin conexión`, `whisper`, `código abierto`: the technical and privacy terms.
- Dropped for length: `traductor` (109 bytes with it).
- No trademarks (guideline 2.3.7).

## Description

Follows the seven V15-B slides, in order and with their headlines. Smart Mode names stay in English because that is how the app shows them in this locale.

```
Habla en vez de escribir. Dictus es un teclado que escribe lo que dices: toca el micrófono, habla y tus palabras aparecen en cualquier app. El reconocimiento de voz funciona en tu iPhone, incluso sin conexión.

DICTA EN CUALQUIER APP

Mensajes, correos, notas, recordatorios: donde puedas escribir, Dictus está a un toque. Habla con naturalidad y el texto aparece donde está tu cursor.

TRADUCE MIENTRAS HABLAS (PRO)

Los Smart Modes convierten tu dictado en el texto que necesitas antes de insertarlo. Mantén pulsado el micrófono, elige un modo y habla:
- Translate: al francés, inglés, alemán o español
- Message: el mensaje corto que habrías escrito
- List: tus ideas en viñetas
- Structured: un dictado largo en párrafos claros
- Summary: lo esencial de lo que has dicho

Los Smart Modes funcionan en tu iPhone con Apple Intelligence (iPhone 15 Pro o posterior, iOS 26 o posterior). Tus palabras no se envían a ningún servidor.

LEE TUS AUDIOS EN EL TECLADO (PRO)

¿Te ha llegado un audio que ahora no puedes escuchar? Compártelo con Dictus desde tu app de mensajería. Se transcribe en tu iPhone, y la transcripción te espera en el teclado cuando vuelves a la conversación. Léela e insértala con un toque si quieres citarla.

UN TECLADO DE VERDAD EN TU IDIOMA

Dictus es un teclado completo, no solo un botón de micrófono. Distribuciones QWERTY, AZERTY y QWERTZ, con autocorrección y sugerencias en español, inglés, francés y alemán. Escribe cuando quieras y habla cuando lo prefieras.

TU VOZ NO SALE DE TU IPHONE

El reconocimiento de voz se hace en el dispositivo. Sin cuenta, sin seguimiento, sin estadísticas de uso. Dicta en el avión, en el metro, en cualquier sitio. Los modelos viven en tu iPhone: descarga uno una vez y úsalo sin conexión, del más compacto y rápido al más preciso.

Dictus es de código abierto (licencia MIT). Cualquiera puede leer el código y comprobar estos compromisos de privacidad: github.com/getdictus/dictus-ios

DICTA EN MÁS DE 40 IDIOMAS

El dictado funciona en más de 40 idiomas con una calidad buena o aceptable, y en casi 100 con los modelos Whisper, donde la calidad varía según el idioma. Parakeet, el modelo predeterminado, transcribe 25 idiomas europeos y detecta cuál estás hablando. Cada modelo te indica qué idiomas maneja bien antes de descargarlo.

La app en sí está disponible en inglés y francés; el dictado y el teclado funcionan en español.

DICTUS PRO

Pro añade los Smart Modes, los audios en el teclado, un historial de tus dictados y tu propio vocabulario para nombres y términos técnicos.

Prueba Pro gratis durante 14 días. No hay nada que contratar y nada se renueva: al cabo de 14 días, Dictus vuelve a la versión gratuita y te pregunta si quieres quedarte con Pro. Tu historial y tu vocabulario se conservan. La prueba se ofrece en los iPhone que pueden usar los Smart Modes. El dictado y el teclado siguen siendo gratis.

Dictus no recopila ningún dato. Política de privacidad: getdictus.com/privacy
```

## Length check

Measured with `python3` (`len()` for characters, UTF-8 bytes for the keywords, where ä, ö, ü, ß, á, é, í, ó, ú, ñ weigh 2):

| Field | Limit | Length |
|---|---|---|
| Name | 30 | 25 |
| Subtitle | 30 | 29 |
| Promotional text | 170 | 148 |
| Keywords (bytes) | 100 | 99 |
| Description | 4000 | 2964 |
