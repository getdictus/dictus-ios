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
  // The wordmark of the hero (brand kit: DM Sans 200, lowercase).
  wordmark: "dictus",
  slides: {
    hero: {
      // Options proposed to Pierre (V4): "Speak instead of typing" (kept),
      // "Your voice, typed in any app", "Talk. Dictus types."
      headline: "Speak instead of typing",
      // V9-A: what the giant phone's screen shows being written. The start of slide 2's
      // email, so the two slides tell one story; the caret ends the last line.
      screen: ["Hi Sam,", "Thanks for the notes on the draft."],
    },
    dictate: {
      headline: "Dictate in any app",
      // The generic email compose above the real recording panel (slide 1).
      emailToLabel: "To",
      emailTo: "Sam",
      emailSubject: "Slides for Thursday's review",
      // The last paragraph ends at the caret, where the dictation is going.
      emailBody: [
        "Hi Sam,",
        "Thanks for the notes on the draft. I've moved the budget to the end so the main story comes first, and added the figures from last quarter.",
      ],
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
      // The generic chat above the reader (slide 3): not Apple Messages, not a
      // WhatsApp or Telegram look-alike.
      contactName: "Emma",
      chatDay: "Today",
      chatSent: "Are we still on for dinner at Nonna's tonight?",
      chatPlaceholder: "Message",
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
      // 40+: Whisper's good tier (25) and fair tier (19) in ModelLanguageSupport.swift,
      // plus Maltese, which only Parakeet covers well: 45 at good or fair quality.
      // Written 40+ so the claim survives small catalogue changes. Not "100": the
      // long tail is poor (Bengali about 50% WER), the reason #488 refused it.
      headline: "Dictate in 40+ languages",
      footnote: "Close to 100 with Whisper. Quality varies by language.",
      // Only languages in Whisper's good or fair tier, plus Maltese (Parakeet).
      // No Chinese: Whisper Small marks it imprecise (#409).
      greetings: [
        ["Hello", "en"], ["Bonjour", "fr"], ["Hallo", "de"], ["Hola", "es"],
        ["Ciao", "it"], ["Olá", "pt"], ["Hej", "sv"], ["Cześć", "pl"],
        ["Привет", "ru"], ["Ahoj", "cs"], ["Γεια σου", "el"], ["Szia", "hu"],
        // Ordered so each line of three fits at its size (the bold blue ones are
        // every fourth word: Labas, Bonġu, Bok).
        ["Salut", "ro"], ["Привіт", "uk"], ["नमस्ते", "hi"], ["Labas", "lt"],
        ["こんにちは", "ja"], ["Hei", "fi"], ["Merhaba", "tr"], ["Bonġu", "mt"],
        ["مرحبا", "ar"], ["안녕하세요", "ko"], ["สวัสดี", "th"], ["Bok", "hr"],
      ],
    },
  },
};
