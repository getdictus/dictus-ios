/*
 * App Store screenshot copy, fr-FR (issue #643, iteration V15-B).
 *
 * The French wave of the approved English set: same slides, same layout, every
 * visible word in French. Copy rules as in en-GB.js, plus French typography:
 * a non-breaking space ( ) before ? ! : ; and inside « », typographic
 * apostrophes (’), no em dashes.
 *
 * Register: "vous" (Pierre, 2026-10-06, final): DictusApp already says it and so
 * does Apple's French copy. The keyboard still says "tu" ("Choisis un mode",
 * visible in the slide 3 capture) until #662; slide 3 is recaptured then.
 *
 * The email (slide 2) is the user's own message to a colleague, so it says
 * "tu" to Sam; its first words are the hero's lettering ("MERCI POUR TES
 * NOTES...", art/v15-B/hero-fr-FR.png, drawn by art/v15-B/heroWalk15.ts).
 *
 * The Translate pair (slide 3) is measured, never translated by hand:
 *   swift run -c release polish-harness show <fixture> --mode translate.en --runs N
 * on Apple Foundation Models (Mac), 2026-10-06. Input `fr-late-e` below: 20 runs
 * in 4 processes, 20/20 byte-identical outputs. Phrasings set aside: "Commencez
 * sans moi" rendered as Start / Go / Go ahead without me across runs, and
 * "bloqué" / "arrêté" as stuck / stopped.
 *
 * Captures: captures/fr-FR/ (iPhone 17 Pro Max, iOS 26.5, system and app in
 * French). The three keyboard captures of slide 5 are en-GB's, through the
 * template's fallback: each layout already shows its own language.
 */
window.DICTUS_STRINGS = {
  locale: "fr-FR",
  proBadge: "Pro",
  wordmark: "dictus",
  // The hero's illustration per art iteration, when the locale has its own lettering.
  heroArt: { "v15-B": "art/v15-B/hero-fr-FR.png" },
  slides: {
    hero: {
      // "au lieu de taper" held together, so the break falls after "Parlez" (as "Speak instead / of typing")
      headline: "Parlez au\u00a0lieu\u00a0de\u00a0taper",
    },
    dictate: {
      headline: "Dictez dans toutes vos apps",
      emailToLabel: "À",
      emailTo: "Sam",
      emailSubject: "Slides pour la revue de jeudi",
      emailBody: [
        "Salut Sam,",
        "Merci pour tes notes sur le brouillon. J’ai mis le budget à la fin pour que l’essentiel passe en premier, et ajouté les chiffres du dernier trimestre.",
      ],
    },
    smartModes: {
      footnote: "Les modes intelligents nécessitent Apple Intelligence",
      beforeLabel: "Vous avez dit",
      translate: {
        headline: "Traduisez en parlant",
        // fr-late-e, verbatim.
        before: "Je vais avoir dix minutes de retard, le train est bloqué devant la gare. Ne m’attendez pas et commandez la burrata pour moi.",
        // The fan's own label for the mode (SmartModeDisplayName.swift).
        modeName: "→ EN",
        // Apple FM output, verbatim (20/20 runs).
        after: [
          "I'll be ten minutes late, the train is stuck in front of the station. Don't wait for me and order the burrata for me.",
        ],
      },
    },
    voiceNotes: {
      headline: "Lisez vos vocaux dans le clavier",
      bubbleDuration: "0:24",
      contactName: "Emma",
      chatDay: "Aujourd’hui",
      chatSent: "On dîne toujours chez Nonna ce soir ?",
      chatPlaceholder: "Message",
    },
    keyboard: {
      headline: "Un vrai clavier dans votre langue",
      // iOS names keyboards in the interface language (Réglages › Claviers: "Anglais (R.-U.)").
      labels: {
        fr: "Français · AZERTY",
        en: "Anglais · QWERTY",
        de: "Allemand · QWERTZ",
      },
    },
    private: {
      headline: "Votre voix reste sur votre iPhone",
      footnote: "Les modèles sont sur votre iPhone. Sans compte, open source.",
    },
    languages: {
      // 40+: see en-GB.js (Whisper good + fair tiers, plus Maltese with Parakeet).
      headline: "Dictez dans plus de 40 langues",
      footnote: "Près de 100 avec Whisper. La qualité varie selon la langue.",
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
