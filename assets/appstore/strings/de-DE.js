/*
 * App Store screenshot copy, de-DE (issue #643, iteration V15-B, wave 2).
 *
 * Same slides and layout as en-GB and fr-FR. Register: "du", Apple's own German
 * convention. German typography (no em dashes). The app has no German
 * localisation, so its chrome in the captures stays English (accepted, #643).
 *
 * The email's first words are the hero's lettering ("DANKE FÜR DIE NOTIZEN...",
 * art/v15-B/hero-de-DE.png, heroWalk15DeDE in art/v15-B/heroWalk15.ts).
 *
 * Translate pair: polish-harness show --mode translate.en on Apple Foundation
 * Models, 2026-10-06. Input de-g: 20 runs in 3 processes, 20/20 identical.
 * Set aside: "steht vor dem Bahnhof" (at / in front of / outside the station
 * across runs, and "Fangt ohne mich an" became "It starts without me").
 *
 * Captures: captures/de-DE/ (slide 2's recording panel over Messages, not Reminders: in
 * Reminders the panel sat 51 px lower and its toolbar showed under the email; iPhone 17 Pro Max, iOS 26.5 in German, Dictus
 * keyboard in QWERTZ). Slide 5 uses en-GB's three keyboard captures.
 */
window.DICTUS_STRINGS = {
  locale: "de-DE",
  proBadge: "Pro",
  wordmark: "dictus",
  heroArt: { "v15-B": "art/v15-B/hero-de-DE.png" },
  slides: {
    hero: {
      headline: "Sprich, statt zu tippen",
    },
    dictate: {
      headline: "Diktiere in jeder App",
      emailToLabel: "An",
      emailTo: "Sam",
      emailSubject: "Folien für das Review am Donnerstag",
      emailBody: [
        "Hallo Sam,",
        "danke für die Notizen zum Entwurf. Ich habe das Budget ans Ende gestellt, damit das Wichtigste zuerst kommt, und die Zahlen aus dem letzten Quartal ergänzt.",
      ],
    },
    smartModes: {
      footnote: "Smart Modes brauchen Apple Intelligence",
      beforeLabel: "Du hast gesagt",
      translate: {
        headline: "Übersetze beim Sprechen",
        // de-g, verbatim.
        before: "Ich bin zehn Minuten zu spät, mein Zug steckt kurz vor dem Bahnhof fest. Wartet nicht auf mich und bestellt die Burrata für mich.",
        modeName: "\u2192 EN",
        // Apple FM output, verbatim (20/20 runs).
        after: [
          "I'm ten minutes late, my train is stuck just before the station. Don't wait for me and order the Burrata for me.",
        ],
      },
    },
    voiceNotes: {
      // Infinitive, as German headlines often are: "Lies Sprachnachrichten ..." runs to three lines
      headline: "Sprachnachrichten in der Tastatur lesen",
      bubbleDuration: "0:24",
      contactName: "Emma",
      chatDay: "Heute",
      chatSent: "Bleibt es heute Abend beim Essen bei Nonna?",
      chatPlaceholder: "Nachricht",
    },
    keyboard: {
      headline: "Eine echte Tastatur in deiner Sprache",
      labels: {
        fr: "Französisch · AZERTY",
        en: "Englisch · QWERTY",
        de: "Deutsch · QWERTZ",
      },
    },
    private: {
      headline: "Deine Stimme bleibt auf deinem iPhone",
      footnote: "Die Modelle liegen auf deinem iPhone. Kein Konto, Open Source.",
    },
    languages: {
      // 40+: see en-GB.js (Whisper good + fair tiers, plus Maltese with Parakeet).
      headline: "Diktiere in über 40 Sprachen",
      footnote: "Fast 100 mit Whisper. Die Qualität variiert je nach Sprache.",
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
