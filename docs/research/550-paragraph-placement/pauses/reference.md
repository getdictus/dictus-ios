# The reference, and how it was collected

The speaker was shown the five Dictus-polished texts with numbered sentences and asked
one question: after which sentence do you want a blank line. He was shown no silence
data, no candidate breaks and no measurement of any kind. The audio had already been
analysed at that point and the result was withheld on purpose.

His answer, verbatim, 2026-09-12:

```
A : 2
B : 1
C : 2
D : 1,5
E : 1
```

Six breaks over sixteen sentence boundaries.

## Why the reference had to come first

Deriving the rule from the pauses and then declaring that the pauses mark the paragraphs
validates the hypothesis with the signal that produced it. #437 records what happens when
a bar moves after the numbers are in. The reference is the bar here, so it was collected
before anything was shown.

## The register split

Declared by the maintainer in his first message, before the audio was touched:

> pour les textes A et B, je suis parti des textes qu'on avait déjà utilisés dans l'IQ au
> début pour Typeless, version avec pause

against C, D and E, which he recorded as natural dictation. A and B are read aloud from
text written earlier; C, D and E are composed while speaking. The split is not a post-hoc
stratification, and it is the split the measurement turns on.

## Source files

Audio, not committed. SHA-256:

```
6fc69eba4afc74f098f47426af2f78fefd3f9cf897fed0cc7354710decd6322f  Texte A - Pause.m4a
e37a96843f4376bb4c8d11742f85d2f5bb0a2cf0197d894d9646c8b1a6e88738  Texte B - Pause.m4a
8a7f8aea8f616bb8b57b8ff7c75902053b3f8d7f7024fc66751433a010b5ce3b  Test C.m4a
51304b9f399f921b36229fe609166dcdb7afaf2e0beb61183ee228c93f357225  Test D.m4a
1cece2a4df52a3bfead6345a0aeb9460dcf58463e252ac0f33750623c2a0d742  Test E.m4a
```

Transcriptions: `dictus-polish-debug-20260912-001017.json`, events 209 to 213, exported
from the app's Polish debug log. Reproduced in `transcripts.md`.
