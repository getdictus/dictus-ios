/*
 * App Store screenshot copy, es-ES (issue #643, iteration V15-B, wave 2).
 *
 * Same slides and layout as en-GB and fr-FR. Register: "tú", Apple's own Spanish
 * convention (Spain: "vosotros" in the spoken demo). Spanish typography (¿ ¡,
 * no em dashes). The app has no Spanish localisation, so its chrome in the
 * captures stays English (accepted, #643).
 *
 * The email's first words are the hero's lettering ("GRACIAS POR LAS NOTAS...",
 * art/v15-B/hero-es-ES.png, heroWalk15EsES in art/v15-B/heroWalk15.ts).
 *
 * Translate pair: polish-harness show --mode translate.en on Apple Foundation
 * Models, 2026-10-06. Input es-e: 20 runs in 3 processes, 20/20 identical.
 * Set aside: "está parado" (stopped, and "I'll be" / "I'm" / "I'll arrive"),
 * "pedidme" (ask me for), "Empezad sin mí" (Go / Start without me).
 *
 * Captures: captures/es-ES/ (slide 2's recording panel over Messages, not Reminders: in
 * Reminders the panel sat 51 px lower and its toolbar showed under the email; iPhone 17 Pro Max, iOS 26.5 in Spanish, Dictus
 * keyboard in its Spanish QWERTY, which has no ñ key: ñ is on a long press of n).
 * Slide 5 uses en-GB's three keyboard captures.
 */
window.DICTUS_STRINGS = {
  locale: "es-ES",
  proBadge: "Pro",
  wordmark: "dictus",
  heroArt: { "v15-B": "art/v15-B/hero-es-ES.png" },
  slides: {
    hero: {
      // "en vez de escribir" held together, the break falls after "Habla"
      headline: "Habla en\u00a0vez\u00a0de\u00a0escribir",
    },
    dictate: {
      headline: "Dicta en cualquier app",
      emailToLabel: "Para",
      emailTo: "Sam",
      emailSubject: "Diapositivas para la revisión del jueves",
      emailBody: [
        "Hola, Sam:",
        "Gracias por las notas sobre el borrador. He pasado el presupuesto al final para que lo principal vaya primero, y he añadido las cifras del último trimestre.",
      ],
    },
    smartModes: {
      footnote: "Los Smart Modes necesitan Apple Intelligence",
      beforeLabel: "Has dicho",
      translate: {
        headline: "Traduce mientras hablas",
        // es-e, verbatim.
        before: "Voy a llegar diez minutos tarde, el tren está atascado delante de la estación. No me esperéis y pedid la burrata para mí.",
        modeName: "\u2192 EN",
        // Apple FM output, verbatim (20/20 runs).
        after: [
          "I'll be ten minutes late, the train is stuck in front of the station. Don't wait for me and order the burrata for me.",
        ],
      },
    },
    voiceNotes: {
      headline: "Lee tus audios en el teclado",
      bubbleDuration: "0:24",
      contactName: "Emma",
      chatDay: "Hoy",
      chatSent: "¿Seguimos con la cena en Nonna esta noche?",
      chatPlaceholder: "Mensaje",
    },
    keyboard: {
      headline: "Un teclado de verdad en tu idioma",
      labels: {
        fr: "Francés · AZERTY",
        en: "Inglés · QWERTY",
        de: "Alemán · QWERTZ",
      },
    },
    private: {
      headline: "Tu voz no sale de tu iPhone",
      footnote: "Los modelos viven en tu iPhone. Sin cuenta, código abierto.",
    },
    languages: {
      // 40+: see en-GB.js (Whisper good + fair tiers, plus Maltese with Parakeet).
      headline: "Dicta en más de 40 idiomas",
      footnote: "Casi 100 con Whisper. La calidad varía según el idioma.",
      // Unchanged from en-GB: each greeting is in its own language.
      greetings: [
        ["Hello", "en"], ["Bonjour", "fr"], ["Hallo", "de"], ["Hola", "es"],
        ["Ciao", "it"], ["Olá", "pt"], ["Hej", "sv"], ["Cześć", "pl"],
        ["Привет", "ru"], ["Ahoj", "cs"], ["Γεια σου", "el"], ["Szia", "hu"],
        ["Salut", "ro"], ["Привіт", "uk"], ["नमस्ते", "hi"], ["Labas", "lt"],
        ["こんにちは", "ja"], ["Hei", "fi"], ["Merhaba", "tr"], ["Bonġu", "mt"],
        ["مرحبا", "ar"], ["안녕하세요", "ko"], ["สวัสดี", "th"], ["Bok", "hr"],
      ],
    },
  },
};
