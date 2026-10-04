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
 * Every word a floating card shows must be something the product produces:
 * - smartModes.before / after: `after` is the measured output of the shipping
 *   `Message` prompt on Apple Foundation Models for `before`, run through
 *   `swift run polish-harness show … --mode message --runs 3` on 2026-10-04,
 *   identical on all three runs (two blocks, no closing punctuation). A locale
 *   needs its own measured pair; never translate `after` by hand.
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
      headline: "Speak freely, send it clean",
      footnote: "Smart Modes need Apple Intelligence",
      beforeLabel: "You said",
      // `~text~` is struck through: words the mode removed.
      before: "About tomorrow's meeting, ~um,~ I think we should, ~like,~ move it to ten, because, ~uh,~ half the team is still travelling. ~And~ can you, ~um,~ send me the slides before?",
      modeName: "Message",
      after: [
        "About tomorrow's meeting, I think we should move it to ten, because half the team is still travelling",
        "Can you send me the slides before",
      ],
    },
    voiceNotes: {
      headline: "Read voice notes in your keyboard",
      bubbleDuration: "0:24",
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
      footnote: "On-device models · No account · Open source",
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
