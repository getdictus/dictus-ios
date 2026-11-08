import { missingGlyphs } from "./handLettering";

// THE TEXT INSIDE THE INTRO VIDEOS, per locale (issue #771). One render per language: each
// locale's six videos draw these lines, hand-lettered (handLettering.ts). The headline and the
// subtitle under each video are SwiftUI text, localized by the app, not here.
//
// The cards are laid out line by line, so every multi-line text is given already broken into
// its lines. A translation keeps the English line count and about its width, so the bubble, the
// mail draft and the note keep their size and the loops their timing; the scenes check at load
// that no line overflows its card (introWalk.ts, introMetro.ts, introKeyboard.ts).
//
// To add a language: add its table below, render it (`render.mjs --locale <code>`), and bundle
// its videos and stills (README.md, "Adding a language").

export type IntroStrings = {
  /** scene A, the chat thread: the message received, then her reply, one entry per line */
  walk: { received: string; reply: [string, string, string, string] };
  /** scene B, the mail draft: its subject, then its body, one entry per line */
  metro: { subject: string; body: [string, string, string] };
  /** scene C, the note above the Dictus keyboard */
  keyboard: {
    /** the note's title */
    title: string;
    /** the word typed before the dictation, and the frame each of its letters is hit on (one per letter, on the 5-frame grid, before the mic at 35) */
    word: string; taps: number[];
    /** the dictated paragraph, one entry per line; the first line follows the typed word */
    paragraph: [string, string, string, string];
    /** the three suggestions in the keyboard's top bar after the typed word */
    suggestions: [string, string, string];
    /** the recording overlay's captions */
    listening: string; transcribing: string;
    /** the three letter rows, as `KeyboardLetterRows` gives them for the locale's layout */
    rows: [string, string, string];
  };
};

export const STRINGS = {
  en: {
    walk: { received: "Where are you?", reply: ["On my way, I'll be", "there in ten minutes.", "Can you order me", "a coffee?"] },
    metro: { subject: "Notes from today", body: ["Great meeting this", "morning. Next steps", "for the launch below."] },
    keyboard: {
      title: "Notes",
      word: "Hi", taps: [10, 20],
      paragraph: ["Sam, quick reminder:", "dinner at eight tonight.", "I'll bring dessert, can", "you pick up the bread?"],
      suggestions: ["Hi", "Hey", "Hello"],
      listening: "Listening...", transcribing: "Transcribing...",
      rows: ["qwertyuiop", "asdfghjkl", "zxcvbnm"],
    },
  },
  fr: {
    walk: { received: "Tu es où ?", reply: ["J’arrive, je serai", "là dans dix minutes.", "Tu peux me prendre", "un café ?"] },
    metro: { subject: "Notes du jour", body: ["Très bonne réunion", "ce matin. Prochaines", "étapes ci-dessous."] },
    keyboard: {
      title: "Notes",
      word: "Salut", taps: [5, 10, 15, 20, 25],
      paragraph: ["Sam, petit rappel :", "dîner ce soir à huit heures.", "J’apporte le dessert,", "tu t’occupes du pain ?"],
      suggestions: ["Salut", "Coucou", "Bonjour"],
      listening: "En écoute...", transcribing: "Transcription...",
      rows: ["azertyuiop", "qsdfghjklm", "wxcvbn'"],
    },
  },
} satisfies Record<string, IntroStrings>;

export type Locale = keyof typeof STRINGS;
export const LOCALES = Object.keys(STRINGS) as Locale[];

/** every string of a table, each with where it sits, e.g. `walk.reply[1]` */
const entries = (s: IntroStrings): [string, string][] =>
  Object.entries(s).flatMap(([scene, fields]) => Object.entries(fields).flatMap(([key, v]) =>
    typeof v === "string" ? [[`${scene}.${key}`, v] as [string, string]]
      : (v as unknown[]).flatMap((x, i) => (typeof x === "string" ? [[`${scene}.${key}[${i}]`, x] as [string, string]] : []))));

/**
 * The strings of `locale`. Throws when the locale has no table, or when one of its strings uses a
 * character the hand-lettered alphabet cannot write (it would be drawn as a blank gap): the
 * render stops before drawing a frame, naming each character and where it is.
 */
export const stringsFor = (locale: string): IntroStrings => {
  if (!(locale in STRINGS)) throw new Error(`no intro strings for locale '${locale}' (known: ${LOCALES.join(", ")})`);
  const s: IntroStrings = STRINGS[locale as Locale];
  const problems = entries(s).flatMap(([where, text]) => missingGlyphs(text).map((ch) =>
    `  ${JSON.stringify(ch)} (U+${ch.codePointAt(0)!.toString(16).toUpperCase().padStart(4, "0")}) in ${where}: ${JSON.stringify(text)}`));
  if (problems.length) throw new Error(`intro strings '${locale}' use characters with no hand-lettered glyph (handLettering.ts):\n${problems.join("\n")}`);
  return s;
};
