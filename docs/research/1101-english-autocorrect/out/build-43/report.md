# Keyboard measurement: Dictus (replay, 402x216 pt grid)

commit: `fef8360c437824f3d837c3fe232970239e1238aa`

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| en | 58 | 417 | 51 | 12.2% | 3.9% | 3.9% | 0 |

Word errors are a word-level edit distance against the intended sentence; a glued word is a final token that is two consecutive intended words without the space. Ignoring accents leaves the errors that are not a missing accent: with no autocorrect at work, they are the keyboard's wrong keys.

## Taps

| lang | letter taps | wrong letter | of which a stray space | space taps | missed space | missed space landed on |
|---|---:|---:|---:|---:|---:|---|
| en | 1616 | 0 (0.0%) | 0 | 417 | 0 (0.0%) | - |

## Engine time per keystroke (ms)

The suggestion work a letter triggers and the autocorrect a space triggers, run one after the other on the replay's thread. Simulator on a Mac: compare runs with each other, never with a device.

| lang | key | taps | p50 | p95 | max |
|---|---|---:|---:|---:|---:|
| en | letter | 1616 | 1.42 | 2.38 | 98.17 |
| en | space | 417 | 0.08 | 1.09 | 3.52 |

## Autocorrect, per word the space bar committed

| lang | words | typed right, kept | typed wrong, fixed | **broken** (typed right, changed) | missed (typed wrong, kept) | of which accent only | **miscorrected** | glued | glued, split back |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| en | 417 | 335 | 32 | **9** | 21 | 0 | **20** | 0 | 0 |

Wrong autocorrections are the two bold columns. A stray space splits one intended word over two commits; those halves count as typed wrong.

## Every word that did not come out right

| lang | outcome | intended | typed | final |
|---|---|---|---|---|
| en | broken | tbh | Tbh | Thu |
| en | broken | venmo | venmo | banjo |
| en | broken | coworker | coworker | coworkers |
| en | broken | jaxon | jaxon | jax on |
| en | broken | idk | Idk | Idl |
| en | broken | ngl | Ngl | Nfl |
| en | broken | hulu | hulu | july |
| en | broken | texted | texted | tested |
| en | broken | priya | priya | prius |
| en | miscorrected | when | whne | wine |
| en | miscorrected | thing | thign | thigh |
| en | miscorrected | movie | moive | move |
| en | miscorrected | said | siad | size |
| en | miscorrected | have | hvae | hvac |
| en | miscorrected | bring | brign | being |
| en | miscorrected | friend | freind | freund |
| en | miscorrected | expected | expectd | expects |
| en | miscorrected | iphone | iphpne | phone |
| en | miscorrected | wants | wnats | whats |
| en | miscorrected | night | nigth | ninth |
| en | miscorrected | the | hte | gte |
| en | miscorrected | package | pacakge | passive |
| en | miscorrected | where | Wher | Sher |
| en | miscorrected | you | yuo | yup |
| en | miscorrected | this | thsi | thai |
| en | miscorrected | something | somethign | somethin |
| en | miscorrected | thanks | Thansk | Thank |
| en | miscorrected | good | goood | blood |
| en | miscorrected | doing | doidn | doin |
| en | missed | i'll | Ill | Ill |
| en | missed | it's | Its | Its |
| en | missed | we're | were | were |
| en | missed | to | ro | ro |
| en | missed | start | strat | strat |
| en | missed | really | realy | realy |
| en | missed | coming | comming | comming |
| en | missed | i'll | ill | ill |
| en | missed | weird | wierd | wierd |
| en | missed | let's | Lets | Lets |
| en | missed | won't | wont | wont |
| en | missed | i'd | Id | Id |
| en | missed | we'll | Well | Well |
| en | missed | mom | mon | mon |
| en | missed | it's | its | its |
| en | missed | at | st | st |
| en | missed | believe | belive | belive |
| en | missed | it's | its | its |
| en | missed | in | jn | jn |
| en | missed | why | Hwy | Hwy |
| en | missed | we're | Were | Were |

