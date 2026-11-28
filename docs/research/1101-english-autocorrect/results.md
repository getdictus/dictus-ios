# #1101 results: 58 English sentences on five keyboards

Written by `score_1101.py` from `out/*/texts.tsv` (method in the [README](README.md)). Build 43 is v2.0.2, the last App Store build before #993/#995; build 47 is the TestFlight build named in the task, which already has them.

## Totals

| | Apple | build 43 | build 47 | develop, off | develop, spatial |
|---|---:|---:|---:|---:|---:|
| Sentences | 58 | 58 | 58 | 58 | 58 |
| **Sentences exactly right** (case ignored) | 51 | 18 | 35 | 35 | 42 |
| Words | 417 | 417 | 417 | 417 | 417 |
| Words typed wrong | 73 | 73 | 73 | 73 | 73 |
| **Typed wrong, fixed** | 68 | 32 | 54 | 54 | 61 |
| Typed wrong, missed (left as typed) | 4 | 21 | 17 | 17 | 11 |
| **Wrongly changed** (broken + miscorrected) | 3 | 29 | 9 | 9 | 8 |
| …broken (typed right, changed) | 2 | 9 | 7 | 7 | 7 |
| …miscorrected (typed wrong, changed to another wrong word) | 1 | 20 | 2 | 2 | 1 |
| …of the wrongly changed, right after a user typo | 0 | 1 | 0 | 0 | 0 |
| Wrong words in the final text | 7 | 50 | 26 | 26 | 19 |
| …of which right after a user typo (counted apart) | 0 | 3 | 2 | 2 | 2 |
| Casing: `i`, `i'm`, `i'll`... left lowercase mid-sentence (of 9) | 0 | 9 | 8 | 8 | 8 |
| Casing: names and brands written with a capital (of 22) | 14 | 1 | 1 | 1 | 1 |

## Per failure family: words right / words in the family (wrongly changed)

| family | words | Apple | build 43 | build 47 | develop, off | develop, spatial |
|---|---:|---|---|---|---|---|
| Pierre's device journal | 4 | 4 (0) | 3 (1) | 3 (0) | 3 (0) | 3 (0) |
| after a name or brand | 14 | 14 (0) | 13 (1) | 14 (0) | 14 (0) | 14 (0) |
| contraction | 14 | 14 (0) | 14 (0) | 14 (0) | 14 (0) | 14 (0) |
| contraction, real word typed | 13 | 13 (0) | 2 (0) | 5 (0) | 5 (0) | 5 (0) |
| doubled letter | 3 | 1 (0) | 1 (1) | 2 (0) | 2 (0) | 3 (0) |
| missed letter | 3 | 2 (0) | 1 (2) | 1 (1) | 1 (1) | 3 (0) |
| name or brand | 22 | 21 (1) | 17 (5) | 18 (4) | 18 (4) | 18 (4) |
| neighbour key | 12 | 12 (0) | 7 (1) | 8 (0) | 8 (0) | 12 (0) |
| no apostrophe | 23 | 23 (0) | 12 (0) | 15 (0) | 15 (0) | 15 (0) |
| real word that looks like a contraction | 8 | 7 (1) | 8 (0) | 8 (0) | 8 (0) | 8 (0) |
| sentence start | 58 | 56 (1) | 46 (5) | 51 (1) | 51 (1) | 52 (1) |
| short word with a slip | 19 | 18 (1) | 6 (2) | 11 (0) | 11 (0) | 15 (0) |
| single letter | 18 | 18 (0) | 18 (0) | 18 (0) | 18 (0) | 18 (0) |
| slang / shorthand | 13 | 13 (0) | 10 (3) | 12 (1) | 12 (1) | 12 (1) |
| swapped letters | 21 | 19 (1) | 3 (15) | 18 (1) | 18 (1) | 18 (1) |
| typo list pair | 7 | 7 (0) | 5 (0) | 7 (0) | 7 (0) | 7 (0) |

## Sentence by sentence

Wrong words in **bold**. `typed` is what the typist pressed.

| # | expected | typed | Apple | build 43 | build 47 | develop, off | develop, spatial |
|---:|---|---|---|---|---|---|---|
| 1 | i don't think i'm gonna make it tonight | i dont think im gonna make it tonight | ✓ | ✓ | ✓ | ✓ | ✓ |
| 2 | can't wait to see you guys this weekend | cant wait to see you guys this weekend | ✓ | ✓ | ✓ | ✓ | ✓ |
| 3 | you're gonna love the new taylor swift album | youre gonna love the new taylor swift album | ✓ | ✓ | ✓ | ✓ | ✓ |
| 4 | i'll be there in like ten minutes | ill be there in like ten minutes | ✓ | **Ill** be there in like ten minutes | ✓ | ✓ | ✓ |
| 5 | my grandma is ill so i'm staying home | my grandma is ill so im staying home | My grandma is **I’ll** so I’m staying home | ✓ | ✓ | ✓ | ✓ |
| 6 | it's raining so we're taking an uber | its raining so were taking an uber | ✓ | **Its** raining so **were** taking an uber | It's raining so **were** taking an uber | It's raining so **were** taking an uber | It's raining so **were** taking an uber |
| 7 | the dog hurt its paw at the park | the dog hurt its paw at the parl | ✓ | ✓ | ✓ | ✓ | ✓ |
| 8 | we were at chipotle when you called | we were at chipotle whne you called | ✓ | We were at chipotle **wine** you called | ✓ | ✓ | ✓ |
| 9 | lol that was the funniest thing ever | lol that was the funniest thign ever | ✓ | Lol that was the funniest **thigh** ever | ✓ | ✓ | ✓ |
| 10 | tbh i didn't even like the movie | tbh i didnt even like the moive | ✓ | **Thu** i didn't even like the **move** | ✓ | ✓ | ✓ |
| 11 | can you venmo me for the pizza | can you venmo me for the pizza | ✓ | Can you **banjo** me for the pizza | Can you **venom** me for the pizza | Can you **venom** me for the pizza | Can you **venom** me for the pizza |
| 12 | she said she would text me back | she siad she would text me back | ✓ | She **size** she would text me back | ✓ | ✓ | ✓ |
| 13 | i have to go to target after work | i hvae to go ro target after work | ✓ | I **hvac** to go **ro** target after work | I have to go **ro** target after work | I have to go **ro** target after work | ✓ |
| 14 | what time does the game start tomorrow | what time does the game strat tommorow | What time does the game **strat** tomorrow | What time does the game **strat** tomorrow | What time does the game **strat** tomorrow | What time does the game **strat** tomorrow | What time does the game **strat** tomorrow |
| 15 | i really appreciate it thank you so much | i realy appreciate it thank you so much | ✓ | I **realy** appreciate it thank you so much | ✓ | ✓ | ✓ |
| 16 | that's definitely the best pizza in town | thats definitly the best pizza in town | ✓ | ✓ | ✓ | ✓ | ✓ |
| 17 | my coworker jaxon said the meeting got moved | my coworker jaxon said the meetign got moved | ✓ | My **coworkers** **jax** **on** said the meeting got moved | My **coworkers** **jax** **on** said the meeting got moved | My **coworkers** **jax** **on** said the meeting got moved | My **coworkers** **jax** **on** said the meeting got moved |
| 18 | kayla is coming over later with her sister | kayla is comming over later with her sister | ✓ | Kayla is **comming** over later with her sister | ✓ | ✓ | ✓ |
| 19 | did you see what brandon posted on instagram | did you see what brandon posted on instagram | ✓ | ✓ | ✓ | ✓ | ✓ |
| 20 | ok i'll call you when i get home | ok ill call you when i get hime | ✓ | Ok **ill** call you when i get home | ✓ | ✓ | ✓ |
| 21 | are u still at the gym | are u still at the gym | ✓ | ✓ | ✓ | ✓ | ✓ |
| 22 | i'm so tired i could sleep for days | im so tirwd i could sleep for days | ✓ | ✓ | ✓ | ✓ | ✓ |
| 23 | we should get coffee at starbucks before class | we shoudl get coffee at starbucks before class | ✓ | ✓ | ✓ | ✓ | ✓ |
| 24 | he's not answering his phone again | hes not answering his phonr again | ✓ | ✓ | ✓ | ✓ | ✓ |
| 25 | is it ok if i bring my friend | is it ok if i brign my freind | ✓ | Is it ok if i **being** my **freund** | ✓ | ✓ | ✓ |
| 26 | that's so weird i never got the email | thats so wierd i never got the email | ✓ | That's so **wierd** i never got the email | ✓ | ✓ | ✓ |
| 27 | let's grab lunch at noon tomorrow | lets grab lunch at noon tomorrow | ✓ | **Lets** grab lunch at noon tomorrow | **Lets** grab lunch at noon tomorrow | **Lets** grab lunch at noon tomorrow | **Lets** grab lunch at noon tomorrow |
| 28 | he lets his kids stay up late | he lets his kids stay up late | ✓ | ✓ | ✓ | ✓ | ✓ |
| 29 | i won't be able to make it sorry | i wont be able to make it sorry | ✓ | I **wont** be able to make it sorry | I **wont** be able to make it sorry | I **wont** be able to make it sorry | I **wont** be able to make it sorry |
| 30 | i'd love to come but i have work | id love to come but i have work | ✓ | **Id** love to come but i have work | **Id** love to come but i have work | **Id** love to come but i have work | **Id** love to come but i have work |
| 31 | we'll see how it goes next week | well see how it goes next week | ✓ | **Well** see how it goes next week | **Well** see how it goes next week | **Well** see how it goes next week | **Well** see how it goes next week |
| 32 | well that went better than expected | well that went better than expectd | ✓ | Well that went better than **expects** | Well that went better than **expects** | Well that went better than **expects** | ✓ |
| 33 | omg did you hear about the new iphone | omg did you hear about the new iphpne | ✓ | Omg did you hear about the new **phone** | ✓ | ✓ | ✓ |
| 34 | idk what he wants for his birthday | idk what he wnats for his birthday | ✓ | **Idl** what he **whats** for his birthday | **Idl** what he **whats** for his birthday | **Idl** what he **whats** for his birthday | **Idl** what he **whats** for his birthday |
| 35 | a lot of people were there last night | a lot of peopel were there last nigth | ✓ | A lot of people were there last **ninth** | ✓ | ✓ | ✓ |
| 36 | i was gonna say the same thing | i was gonna say hte same thing | ✓ | I was gonna say **gte** same thing | ✓ | ✓ | ✓ |
| 37 | can you send me the address again | can yoi send me the address again | ✓ | ✓ | ✓ | ✓ | ✓ |
| 38 | my mom wants us to come for thanksgiving | my mon wants us to come for thanksgiving | ✓ | My **mon** wants us to come for thanksgiving | My **mon** wants us to come for thanksgiving | My **mon** wants us to come for thanksgiving | ✓ |
| 39 | the package from amazon should arrive friday | the pacakge from amazon should arrive friday | ✓ | The **passive** from amazon should arrive friday | ✓ | ✓ | ✓ |
| 40 | ngl that test was really hard | ngl that test was reallly hard | Ngl that test was **reallly** hard | **Nfl** that test was really hard | ✓ | ✓ | ✓ |
| 41 | where are you guys sitting | wher are you guys sitting | **Wher** are you guys sitting | **Sher** are you guys sitting | **Wher** are you guys sitting | **Wher** are you guys sitting | ✓ |
| 42 | just got out of the shower be right there | just got out of the shoqer be right there | ✓ | ✓ | ✓ | ✓ | ✓ |
| 43 | i think it's in the top drawer | i think its in the top drawer | ✓ | I think **its** in the top drawer | I think **its** in the top drawer | I think **its** in the top drawer | I think **its** in the top drawer |
| 44 | is netflix down for you too | is netflix down for yuo too | ✓ | Is netflix down for **yup** too | ✓ | ✓ | ✓ |
| 45 | sounds good see you at six | sounds good see you st six | ✓ | Sounds good see you **st** six | Sounds good see you **st** six | Sounds good see you **st** six | ✓ |
| 46 | they're already at the restaurant waiting | theyre already at the restaurant waiting | ✓ | ✓ | ✓ | ✓ | ✓ |
| 47 | i just can't believe it's already december | i just cant belive its already december | ✓ | I just can't **belive** **its** already december | I just can't believe **its** already december | I just can't believe **its** already december | I just can't believe **its** already december |
| 48 | my brother mike is in town this week | my brother mike is jn town thsi week | ✓ | My brother mike is **jn** town **thai** week | My brother mike is **jn** town this week | My brother mike is **jn** town this week | ✓ |
| 49 | do you want to watch something on hulu | do you want to watch somethign on hulu | ✓ | Do you want to watch **somethin** on **july** | Do you want to watch something on **july** | Do you want to watch something on **july** | Do you want to watch something on **july** |
| 50 | thanks for the ride last night | thansk for the ride last night | ✓ | **Thank** for the ride last night | ✓ | ✓ | ✓ |
| 51 | k see you there in a bit | k see you there in a bit | ✓ | ✓ | ✓ | ✓ | ✓ |
| 52 | i didn't know you were coming too | i didnt know you were cominf too | ✓ | ✓ | ✓ | ✓ | ✓ |
| 53 | the food at that place was so good | the food at that place was so goood | The food at that place was so **goood** | The food at that place was so **blood** | The food at that place was so **goood** | The food at that place was so **goood** | ✓ |
| 54 | ur sister just texted me | ur sister just texted me | ✓ | Ur sister just **tested** me | Ur sister just **tested** me | Ur sister just **tested** me | Ur sister just **tested** me |
| 55 | why are you up so early | hwy are you up so early | **Hey** are you up so early | **Hwy** are you up so early | **Hwy** are you up so early | **Hwy** are you up so early | **Hwy** are you up so early |
| 56 | we're going to coachella with priya and dev | were going to coachella with priya and dev | We’re going to Coachella with **Oriya** and dev | **Were** going to coachella with **prius** and dev | **Were** going to coachella with **prima** and dev | **Were** going to coachella with **prima** and dev | **Were** going to coachella with **prima** and dev |
| 57 | i'm afraid that you're correct on this | im afraid thzg youre correct on tgis | ✓ | ✓ | ✓ | ✓ | ✓ |
| 58 | hope you're doing well my friend | hope youre doidn well my ftiend | ✓ | Hope you're **doin** well my friend | Hope you're **doidn** well my friend | Hope you're **doidn** well my friend | Hope you're **doidn** well my friend |

✓: the whole sentence is right, case ignored.

## Every word a keyboard got wrong

| keyboard | # | outcome | meant | typed | wrote | after a user typo | families |
|---|---:|---|---|---|---|---|---|
| Apple | 5 | broken | ill | ill | I’ll |  | real word that looks like a contraction |
| Apple | 14 | missed | start | strat | strat |  | swapped letters |
| Apple | 40 | missed | really | reallly | reallly |  | doubled letter |
| Apple | 41 | missed | where | wher | Wher |  | missed letter, sentence start |
| Apple | 53 | missed | good | goood | goood |  | doubled letter |
| Apple | 55 | miscorrected | why | hwy | Hey |  | swapped letters, short word with a slip, sentence start |
| Apple | 56 | broken | priya | priya | Oriya |  | name or brand |
| build 43 | 4 | missed | i'll | ill | Ill |  | contraction, real word typed, no apostrophe, short word with a slip, sentence start |
| build 43 | 6 | missed | it's | its | Its |  | contraction, real word typed, no apostrophe, short word with a slip, sentence start |
| build 43 | 6 | missed | we're | were | were |  | contraction, real word typed, no apostrophe |
| build 43 | 8 | miscorrected | when | whne | wine |  | swapped letters, after a name or brand |
| build 43 | 9 | miscorrected | thing | thign | thigh |  | swapped letters |
| build 43 | 10 | broken | tbh | tbh | Thu |  | slang / shorthand, sentence start |
| build 43 | 10 | miscorrected | movie | moive | move |  | swapped letters |
| build 43 | 11 | broken | venmo | venmo | banjo |  | name or brand |
| build 43 | 12 | miscorrected | said | siad | size |  | swapped letters |
| build 43 | 13 | miscorrected | have | hvae | hvac |  | swapped letters |
| build 43 | 13 | missed | to | ro | ro |  | neighbour key, short word with a slip |
| build 43 | 14 | missed | start | strat | strat |  | swapped letters |
| build 43 | 15 | missed | really | realy | realy |  | typo list pair |
| build 43 | 17 | broken | coworker | coworker | (joined/split) |  |  |
| build 43 | 17 | broken | jaxon | jaxon | (joined/split) |  | name or brand |
| build 43 | 18 | missed | coming | comming | comming |  | doubled letter |
| build 43 | 20 | missed | i'll | ill | ill |  | contraction, real word typed, no apostrophe, short word with a slip |
| build 43 | 25 | miscorrected | bring | brign | being |  | swapped letters |
| build 43 | 25 | miscorrected | friend | freind | freund |  | swapped letters |
| build 43 | 26 | missed | weird | wierd | wierd |  | swapped letters |
| build 43 | 27 | missed | let's | lets | Lets |  | contraction, real word typed, no apostrophe, sentence start |
| build 43 | 29 | missed | won't | wont | wont |  | contraction, real word typed, no apostrophe |
| build 43 | 30 | missed | i'd | id | Id |  | contraction, real word typed, no apostrophe, short word with a slip, sentence start |
| build 43 | 31 | missed | we'll | well | Well |  | contraction, real word typed, no apostrophe, sentence start |
| build 43 | 32 | miscorrected | expected | expectd | expects |  | missed letter |
| build 43 | 33 | miscorrected | iphone | iphpne | phone |  | name or brand, neighbour key |
| build 43 | 34 | broken | idk | idk | Idl |  | slang / shorthand, sentence start |
| build 43 | 34 | miscorrected | wants | wnats | whats |  | swapped letters |
| build 43 | 35 | miscorrected | night | nigth | ninth |  | swapped letters |
| build 43 | 36 | miscorrected | the | hte | gte |  | swapped letters, short word with a slip |
| build 43 | 38 | missed | mom | mon | mon |  | neighbour key, short word with a slip |
| build 43 | 39 | miscorrected | package | pacakge | passive |  | swapped letters |
| build 43 | 40 | broken | ngl | ngl | Nfl |  | slang / shorthand, sentence start |
| build 43 | 41 | miscorrected | where | wher | Sher |  | missed letter, sentence start |
| build 43 | 43 | missed | it's | its | its |  | contraction, real word typed, no apostrophe, short word with a slip |
| build 43 | 44 | miscorrected | you | yuo | yup |  | swapped letters, short word with a slip |
| build 43 | 45 | missed | at | st | st |  | neighbour key, short word with a slip |
| build 43 | 47 | missed | believe | belive | belive | yes | typo list pair |
| build 43 | 47 | missed | it's | its | its | yes | contraction, real word typed, no apostrophe, short word with a slip |
| build 43 | 48 | missed | in | jn | jn |  | neighbour key, short word with a slip |
| build 43 | 48 | miscorrected | this | thsi | thai |  | swapped letters |
| build 43 | 49 | miscorrected | something | somethign | somethin |  | swapped letters |
| build 43 | 49 | broken | hulu | hulu | july |  | name or brand |
| build 43 | 50 | miscorrected | thanks | thansk | Thank |  | swapped letters, sentence start |
| build 43 | 53 | miscorrected | good | goood | blood |  | doubled letter |
| build 43 | 54 | broken | texted | texted | tested |  |  |
| build 43 | 55 | missed | why | hwy | Hwy |  | swapped letters, short word with a slip, sentence start |
| build 43 | 56 | missed | we're | were | Were |  | contraction, real word typed, no apostrophe, sentence start |
| build 43 | 56 | broken | priya | priya | prius |  | name or brand |
| build 43 | 58 | miscorrected | doing | doidn | doin | yes | Pierre's device journal |
| build 47 | 6 | missed | we're | were | were |  | contraction, real word typed, no apostrophe |
| build 47 | 11 | broken | venmo | venmo | venom |  | name or brand |
| build 47 | 13 | missed | to | ro | ro |  | neighbour key, short word with a slip |
| build 47 | 14 | missed | start | strat | strat |  | swapped letters |
| build 47 | 17 | broken | coworker | coworker | (joined/split) |  |  |
| build 47 | 17 | broken | jaxon | jaxon | (joined/split) |  | name or brand |
| build 47 | 27 | missed | let's | lets | Lets |  | contraction, real word typed, no apostrophe, sentence start |
| build 47 | 29 | missed | won't | wont | wont |  | contraction, real word typed, no apostrophe |
| build 47 | 30 | missed | i'd | id | Id |  | contraction, real word typed, no apostrophe, short word with a slip, sentence start |
| build 47 | 31 | missed | we'll | well | Well |  | contraction, real word typed, no apostrophe, sentence start |
| build 47 | 32 | miscorrected | expected | expectd | expects |  | missed letter |
| build 47 | 34 | broken | idk | idk | Idl |  | slang / shorthand, sentence start |
| build 47 | 34 | miscorrected | wants | wnats | whats |  | swapped letters |
| build 47 | 38 | missed | mom | mon | mon |  | neighbour key, short word with a slip |
| build 47 | 41 | missed | where | wher | Wher |  | missed letter, sentence start |
| build 47 | 43 | missed | it's | its | its |  | contraction, real word typed, no apostrophe, short word with a slip |
| build 47 | 45 | missed | at | st | st |  | neighbour key, short word with a slip |
| build 47 | 47 | missed | it's | its | its | yes | contraction, real word typed, no apostrophe, short word with a slip |
| build 47 | 48 | missed | in | jn | jn |  | neighbour key, short word with a slip |
| build 47 | 49 | broken | hulu | hulu | july |  | name or brand |
| build 47 | 53 | missed | good | goood | goood |  | doubled letter |
| build 47 | 54 | broken | texted | texted | tested |  |  |
| build 47 | 55 | missed | why | hwy | Hwy |  | swapped letters, short word with a slip, sentence start |
| build 47 | 56 | missed | we're | were | Were |  | contraction, real word typed, no apostrophe, sentence start |
| build 47 | 56 | broken | priya | priya | prima |  | name or brand |
| build 47 | 58 | missed | doing | doidn | doidn | yes | Pierre's device journal |
| develop, off | 6 | missed | we're | were | were |  | contraction, real word typed, no apostrophe |
| develop, off | 11 | broken | venmo | venmo | venom |  | name or brand |
| develop, off | 13 | missed | to | ro | ro |  | neighbour key, short word with a slip |
| develop, off | 14 | missed | start | strat | strat |  | swapped letters |
| develop, off | 17 | broken | coworker | coworker | (joined/split) |  |  |
| develop, off | 17 | broken | jaxon | jaxon | (joined/split) |  | name or brand |
| develop, off | 27 | missed | let's | lets | Lets |  | contraction, real word typed, no apostrophe, sentence start |
| develop, off | 29 | missed | won't | wont | wont |  | contraction, real word typed, no apostrophe |
| develop, off | 30 | missed | i'd | id | Id |  | contraction, real word typed, no apostrophe, short word with a slip, sentence start |
| develop, off | 31 | missed | we'll | well | Well |  | contraction, real word typed, no apostrophe, sentence start |
| develop, off | 32 | miscorrected | expected | expectd | expects |  | missed letter |
| develop, off | 34 | broken | idk | idk | Idl |  | slang / shorthand, sentence start |
| develop, off | 34 | miscorrected | wants | wnats | whats |  | swapped letters |
| develop, off | 38 | missed | mom | mon | mon |  | neighbour key, short word with a slip |
| develop, off | 41 | missed | where | wher | Wher |  | missed letter, sentence start |
| develop, off | 43 | missed | it's | its | its |  | contraction, real word typed, no apostrophe, short word with a slip |
| develop, off | 45 | missed | at | st | st |  | neighbour key, short word with a slip |
| develop, off | 47 | missed | it's | its | its | yes | contraction, real word typed, no apostrophe, short word with a slip |
| develop, off | 48 | missed | in | jn | jn |  | neighbour key, short word with a slip |
| develop, off | 49 | broken | hulu | hulu | july |  | name or brand |
| develop, off | 53 | missed | good | goood | goood |  | doubled letter |
| develop, off | 54 | broken | texted | texted | tested |  |  |
| develop, off | 55 | missed | why | hwy | Hwy |  | swapped letters, short word with a slip, sentence start |
| develop, off | 56 | missed | we're | were | Were |  | contraction, real word typed, no apostrophe, sentence start |
| develop, off | 56 | broken | priya | priya | prima |  | name or brand |
| develop, off | 58 | missed | doing | doidn | doidn | yes | Pierre's device journal |
| develop, spatial | 6 | missed | we're | were | were |  | contraction, real word typed, no apostrophe |
| develop, spatial | 11 | broken | venmo | venmo | venom |  | name or brand |
| develop, spatial | 14 | missed | start | strat | strat |  | swapped letters |
| develop, spatial | 17 | broken | coworker | coworker | (joined/split) |  |  |
| develop, spatial | 17 | broken | jaxon | jaxon | (joined/split) |  | name or brand |
| develop, spatial | 27 | missed | let's | lets | Lets |  | contraction, real word typed, no apostrophe, sentence start |
| develop, spatial | 29 | missed | won't | wont | wont |  | contraction, real word typed, no apostrophe |
| develop, spatial | 30 | missed | i'd | id | Id |  | contraction, real word typed, no apostrophe, short word with a slip, sentence start |
| develop, spatial | 31 | missed | we'll | well | Well |  | contraction, real word typed, no apostrophe, sentence start |
| develop, spatial | 34 | broken | idk | idk | Idl |  | slang / shorthand, sentence start |
| develop, spatial | 34 | miscorrected | wants | wnats | whats |  | swapped letters |
| develop, spatial | 43 | missed | it's | its | its |  | contraction, real word typed, no apostrophe, short word with a slip |
| develop, spatial | 47 | missed | it's | its | its | yes | contraction, real word typed, no apostrophe, short word with a slip |
| develop, spatial | 49 | broken | hulu | hulu | july |  | name or brand |
| develop, spatial | 54 | broken | texted | texted | tested |  |  |
| develop, spatial | 55 | missed | why | hwy | Hwy |  | swapped letters, short word with a slip, sentence start |
| develop, spatial | 56 | missed | we're | were | Were |  | contraction, real word typed, no apostrophe, sentence start |
| develop, spatial | 56 | broken | priya | priya | prima |  | name or brand |
| develop, spatial | 58 | missed | doing | doidn | doidn | yes | Pierre's device journal |
