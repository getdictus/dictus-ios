/*
 * App Store screenshot copy, en-GB (issue #643).
 *
 * One file per locale. screenshots.html loads strings/<locale>.js from its
 * ?locale= parameter, and captures from captures/<locale>/ (falling back to
 * captures/en-GB/ when a locale has no capture of its own yet).
 *
 * A plain script rather than JSON: the template is opened from file://, where
 * Chromium refuses fetch() but runs a <script src>.
 *
 * Copy rules (#189, #643): no em dashes, no unverifiable superlatives
 * ("the only app that…"), dictation = 25+ languages, keyboard = 4 languages
 * and 3 layouts.
 */
window.DICTUS_STRINGS = {
  locale: "en-GB",
  proBadge: "Pro",
  slides: {
    dictate: {
      eyebrow: "Voice keyboard",
      headline: "Dictate in any app",
      subtext: "Tap the mic, speak, and your words appear wherever you type.",
    },
    smartModes: {
      eyebrow: "Smart Modes",
      headline: "Turn your voice into the right text",
      subtext: "Pick a mode before you speak: a clean message, a list, a translation. On your iPhone, with Apple Intelligence.",
    },
    voiceNotes: {
      eyebrow: "Voice notes",
      headline: "Read voice messages without leaving the chat",
      subtext: "Share a voice message to Dictus. The transcript waits in your keyboard, ready to insert.",
    },
    keyboard: {
      eyebrow: "FR · EN · DE · ES",
      headline: "A real keyboard, in your language",
      subtext: "AZERTY, QWERTY and QWERTZ, with autocorrect in French, English, German and Spanish.",
      labels: {
        fr: "Français · AZERTY",
        en: "English · QWERTY",
        de: "Deutsch · QWERTZ",
      },
    },
    private: {
      eyebrow: "On-device",
      headline: "Private, offline, open source",
      subtext: "Transcribed on your iPhone, even offline. No account, no servers, and the code is public.",
    },
    languages: {
      eyebrow: "25+ languages",
      headline: "Dictation in 25+ languages",
      subtext: "Parakeet transcribes 25 European languages. Whisper models reach close to a hundred.",
    },
  },
};
