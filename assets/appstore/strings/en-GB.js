/*
 * App Store screenshot copy, en-GB (issue #643, design iteration 2).
 *
 * One file per locale. screenshots.html loads strings/<locale>.js from its
 * ?locale= parameter, and captures from captures/<locale>/ (falling back to
 * captures/en-GB/ when a locale has no capture of its own yet).
 *
 * A plain script rather than JSON: the template is opened from file://, where
 * Chromium refuses fetch() but runs a <script src>.
 *
 * Copy rules (#189, #643): one short headline per slide; no em dashes; no
 * unverifiable superlatives ("the only app that…"); dictation = 25+ languages,
 * keyboard = 4 languages and 3 layouts.
 *
 * Every word a floating card shows must be something the product produces.
 * The Smart Mode pairs below are measured with
 *   swift run polish-harness show <fixtures> --mode <id> --runs 3   (Apple FM, Mac)
 * and `after` is shown verbatim. A locale needs its own measured pairs; never
 * translate `after` by hand. Measured on 2026-10-05:
 * - message: 9 English dictations, 3 runs each. None became a clean, punctuated,
 *   stable message: stable outputs stay close to the input and end without
 *   punctuation (the mode writes in texting style); the cleaner outputs appear
 *   in 1 run of 3, and one dictation swapped a fact in 2 runs of 3. The pair
 *   below is the stable one (3/3 identical) that removes the most.
 * - translate.fr: 5/5 runs identical but one word (4/5 "coincé", 1/5 "bloqué").
 *   translate.es was rejected: it rendered "ten minutes" as "quince minutos".
 * - voiceNotes: the transcript comes from the capture, not from here.
 */
window.DICTUS_STRINGS = {
  locale: "en-GB",
  proBadge: "Pro",
  slides: {
    dictate: {
      headline: "Dictate in any app",
    },
    smartModes: {
      footnote: "Smart Modes need Apple Intelligence",
      beforeLabel: "You said",
      // `~text~` is struck through: words the mode removed.
      message: {
        headline: "Speak freely, send it clean",
        before: "So basically I'm going to be late, like twenty minutes, sorry, ~the train is, uh,~ the train is stuck. Start without me and ~I'll, um,~ I'll catch up when I get there.",
        modeName: "Message",
        after: [
          "So basically I'm going to be late, like twenty minutes, sorry",
          "The train is stuck",
          "Start without me and I'll catch up when I get there",
        ],
      },
      translate: {
        headline: "Translate as you speak",
        before: "I'm running about ten minutes late, the train is stuck outside the station. Start without me and order the burrata for me.",
        // The fan's own label for the mode (SmartModeDisplayName.swift).
        modeName: "\u2192 FR",
        after: [
          "Je suis en retard d'environ dix minutes, le train est coincé devant la gare. Commence sans moi et commande la burrata pour moi.",
        ],
      },
    },
    voiceNotes: {
      headline: "Read voice notes in your keyboard",
      bubbleDuration: "0:24",
      // The first name in the conversation header (slide 3).
      contactName: "Emma",
    },
    keyboard: {
      headline: "A real keyboard in your language",
      labels: {
        fr: "Français · AZERTY",
        en: "English · QWERTY",
        de: "Deutsch · QWERTZ",
      },
    },
    private: {
      headline: "Your voice never leaves your iPhone",
      footnote: "The models live on your iPhone. No account, open source.",
    },
    languages: {
      headline: "Dictate in 25+ languages",
      footnote: "Parakeet: 25 European languages. Whisper: close to 100.",
      // Only languages a shipped model transcribes: Parakeet v3's 25, plus Whisper's
      // "good quality" tier (ModelLanguageSupport.swift). No Chinese: Whisper Small
      // marks it imprecise (#409).
      greetings: [
        ["Hello", "en"], ["Bonjour", "fr"], ["Hallo", "de"], ["Hola", "es"],
        ["Ciao", "it"], ["Olá", "pt"], ["Hej", "sv"], ["Cześć", "pl"],
        ["Привет", "ru"], ["Ahoj", "cs"], ["Γεια σου", "el"], ["Szia", "hu"],
        ["Salut", "ro"], ["Hei", "fi"], ["Привіт", "uk"], ["Merhaba", "tr"],
        ["Xin chào", "vi"], ["Halo", "id"], ["こんにちは", "ja"], ["Bok", "hr"],
        ["안녕하세요", "ko"], ["Goedendag", "nl"], ["مرحبا", "ar"], ["Labas", "lt"],
      ],
    },
  },
};
