# Bench corpora for es, de and the typo runs: sources and checks

The Spanish and German bench corpora (`tools/keyboard-bench/corpus/es.txt`, `de.txt`) and
the three typo-run corpora (`corpus/en-typos.txt`, `es-typos.txt`, `de-typos.txt`) were
picked on 2026-11-19. Nobody on the team speaks Spanish or German natively, so no
sentence was written for the bench: each one is an existing sentence by a native speaker,
checked by two independent tools.

## Selection

1. **Source: [Tatoeba](https://tatoeba.org)**, the exports of 2026-11-19
   (`per_language/{spa,deu,eng}/*_sentences_detailed.tsv`, `user_languages.csv`,
   `{spa,deu}-eng_links.tsv`). Licence: [CC BY 2.0 FR](https://creativecommons.org/licenses/by/2.0/fr/);
   each sentence's author is credited in the tables below.
2. **Native author.** Only sentences whose author declares the language at level 5
   (native) in `user_languages.csv`.
3. **Plain and common.** 6 to 10 words (5 to 10 for the typo runs); no digit, quote,
   hyphen or name (`Tom`, `Mary`...); every word among the 5,000 most frequent of the
   language in the [OpenSubtitles 2018 frequency lists](https://github.com/hermitdave/FrequencyWords)
   (MIT; content CC BY-SA 4.0). For es and de, a linked English translation must exist.
4. **Everyday topic.** Picked by hand to match the themes of `fr.txt` and `en.txt`:
   running late, meals, the station, the doctor, keys, the phone, the weather, next week.
   For the typo runs, picked to contain the correct form of as many typo pairs of
   `typos-<lang>.tsv` as possible, then everyday sentences with contractions (en).
5. **Bench form.** Lowercased, punctuation removed (`¿`, `¡`, `?`, `!`, `.`, `,`).
   Accents, `ñ`, umlauts and `ß` are kept; English contractions keep their apostrophe in
   the typo corpus.

## Checks

| Check | Tool | Result |
|---|---|---|
| Grammar and spelling | [LanguageTool](https://languagetool.org) public API (`es`, `de-DE`, `en-US`), original sentence with its punctuation | es 0 flags, de 0, es-typos 0, en-typos 0. de-typos flagged `Und das tu ich auch jetzt noch` (`tu` for `tue`); that sentence was replaced, and its replacement passed. One Spanish sentence, `¿Te apetece un poco de café?`, was flagged by the macOS grammar checker and replaced by `Me gustaría tomar una taza de café.` |
| Spelling | macOS `NSSpellChecker` (spelling and grammar), es and de | 0 flags on the final 40 sentences |
| Sensitivity of the checks | The same two tools on sentences made wrong on purpose | LanguageTool caught `Yo tienes una casa grandes` and `Ich weis noch nicht`, and missed `Las llaves está sobre la mesa`, `Der Zug fahren in zehn Minuten` and `bestellen` for `bestellt`. The macOS checker caught none of the five. So the checks catch spelling and some agreement errors; a sentence passing them is not proven idiomatic. The native authorship is the main guarantee. |

## Spanish bench corpus (corpus/es.txt)

| # | Tatoeba | Author | Sentence | English (linked translation) |
|---:|---|---|---|---|
| 0 | [#1322498](https://tatoeba.org/en/sentences/show/1322498) | Shishir | Puede que llegue un par de minutos tarde. | I might be a few minutes late. |
| 1 | [#857974](https://tatoeba.org/en/sentences/show/857974) | Shishir | Te llamaré mañana por la mañana. | I'll call you up tomorrow morning. |
| 2 | [#1433605](https://tatoeba.org/en/sentences/show/1433605) | Shishir | Mi apartamento está a cinco minutos de la estación. | My apartment is five minutes from the station. |
| 3 | [#623395](https://tatoeba.org/en/sentences/show/623395) | clerval | El tren ya había salido cuando llegué a la estación. | The train had already left when I arrived at the station. |
| 4 | [#4061964](https://tatoeba.org/en/sentences/show/4061964) | Shishir | Casi he terminado de escribir el informe. | I'm almost finished writing the report. |
| 5 | [#867028](https://tatoeba.org/en/sentences/show/867028) | ildefonk | Las llaves están sobre la mesa. | The keys are on the table. |
| 6 | [#1781699](https://tatoeba.org/en/sentences/show/1781699) | Shishir | El médico estará aquí en un minuto. | The doctor will be here in a minute. |
| 7 | [#7965754](https://tatoeba.org/en/sentences/show/7965754) | Seael | Todavía no sé qué haremos el lunes. | I don't yet know what we'll do on Monday. |
| 8 | [#750425](https://tatoeba.org/en/sentences/show/750425) | Shishir | La semana que viene estaré ocupado. | I'll be busy next week. |
| 9 | [#614132](https://tatoeba.org/en/sentences/show/614132) | Leono | ¿Puedes venir a cenar esta noche? | Can you come for dinner tonight? |
| 10 | [#1509822](https://tatoeba.org/en/sentences/show/1509822) | wallebot | Te llamo mañana desde el trabajo. | I'll call you tomorrow from work. |
| 11 | [#1976254](https://tatoeba.org/en/sentences/show/1976254) | Shishir | Tengo intención de ir mañana si hace buen tiempo. | I mean to go tomorrow if the weather is fine. |
| 12 | [#1370371](https://tatoeba.org/en/sentences/show/1370371) | marcelostockle | ¿Nos puede dar una mesa afuera? | Could we have a table outside? |
| 13 | [#602878](https://tatoeba.org/en/sentences/show/602878) | Leono | ¿Qué piensas de la nueva película? | What do you think of the new movie? |
| 14 | [#871002](https://tatoeba.org/en/sentences/show/871002) | Shishir | Tengo que entregar hoy el informe. | I must hand in the report today. |
| 15 | [#587335](https://tatoeba.org/en/sentences/show/587335) | Shishir | Mañana voy a ir a comprar. | Tomorrow I am going shopping. |
| 16 | [#537814](https://tatoeba.org/en/sentences/show/537814) | Shishir | Hoy es el cumpleaños de mi hermana. | Today is my sister's birthday. |
| 17 | [#432176](https://tatoeba.org/en/sentences/show/432176) | Leono | Me gustaría tomar una taza de café. | I would like to have a cup of coffee. |
| 18 | [#504450](https://tatoeba.org/en/sentences/show/504450) | Shishir | Mi madre está ocupada preparando la cena. | My mother is busy cooking supper. |
| 19 | [#535183](https://tatoeba.org/en/sentences/show/535183) | Leono | ¿Podrías darme tu nombre y tu número de teléfono? | Would you tell me your name and phone number? |

## German bench corpus (corpus/de.txt)

| # | Tatoeba | Author | Sentence | English (linked translation) |
|---:|---|---|---|---|
| 0 | [#1388545](https://tatoeba.org/en/sentences/show/1388545) | al_ex_an_der | Ich komme vielleicht ein paar Minuten später. | I might be a few minutes late. |
| 1 | [#608099](https://tatoeba.org/en/sentences/show/608099) | Dejo | Der Zug hatte heute Morgen Verspätung. | The train was late this morning. |
| 2 | [#509887](https://tatoeba.org/en/sentences/show/509887) | Espi | Ich habe einen Tisch für vier Personen bestellt. | I have booked a table for four. |
| 3 | [#631498](https://tatoeba.org/en/sentences/show/631498) | Pfirsichbaeumchen | Ich werde dich morgen früh anrufen. | I'll call you up tomorrow morning. |
| 4 | [#460209](https://tatoeba.org/en/sentences/show/460209) | landano | Der Zug fährt in zehn Minuten. | The train leaves in ten minutes. |
| 5 | [#2728097](https://tatoeba.org/en/sentences/show/2728097) | Pfirsichbaeumchen | Wann muss ich den Bericht abgeben? | When must I turn in the report? |
| 6 | [#466486](https://tatoeba.org/en/sentences/show/466486) | Espi | Willst du mit mir einkaufen gehen? | Will you go shopping with me? |
| 7 | [#2478979](https://tatoeba.org/en/sentences/show/2478979) | al_ex_an_der | Ich weiß noch nicht, was ich machen werde. | I don't know what I'm going to do yet. |
| 8 | [#504670](https://tatoeba.org/en/sentences/show/504670) | Espi | Es scheint, dass ich meine Schlüssel verloren habe. | It seems that I have lost my keys. |
| 9 | [#1808118](https://tatoeba.org/en/sentences/show/1808118) | pne | Ich rufe dich an, wenn ich nach Hause komme. | I'll give you a call when I get home. |
| 10 | [#504339](https://tatoeba.org/en/sentences/show/504339) | Espi | Es ist Zeit für das Abendessen. | It's time for dinner. |
| 11 | [#475503](https://tatoeba.org/en/sentences/show/475503) | Espi | Bitte mach mir doch eine Tasse Kaffee. | Please make me a cup of coffee. |
| 12 | [#446924](https://tatoeba.org/en/sentences/show/446924) | al_ex_an_der | Ruf mich an, falls es regnet. | If it rains, call me. |
| 13 | [#483376](https://tatoeba.org/en/sentences/show/483376) | Espi | Ich liebe es, ins Kino zu gehen. | I love to go to the movies. |
| 14 | [#478426](https://tatoeba.org/en/sentences/show/478426) | Espi | Es ist sehr heiß heute, nicht wahr? | It's very hot today, isn't it? |
| 15 | [#1798578](https://tatoeba.org/en/sentences/show/1798578) | Pfirsichbaeumchen | Wir haben Glück, dass so schönes Wetter ist. | We're lucky that the weather is so nice. |
| 16 | [#604034](https://tatoeba.org/en/sentences/show/604034) | BraveSentry | Sie hat uns zu ihrem Geburtstag eingeladen. | She invited us to her birthday party. |
| 17 | [#758209](https://tatoeba.org/en/sentences/show/758209) | Pfirsichbaeumchen | Sie müssen eine Wohnung in der Stadt finden. | They need to find an apartment in the city. |
| 18 | [#454198](https://tatoeba.org/en/sentences/show/454198) | Pfirsichbaeumchen | Diese Schuhe sind zu groß für mich. | These shoes are too big for me. |
| 19 | [#700013](https://tatoeba.org/en/sentences/show/700013) | Manfredo | Sie müssen bis nächsten Montag im Bett bleiben. | You have to stay in bed until next Monday. |

## English typo run (corpus/en-typos.txt)

| # | Tatoeba | Author | Sentence |
|---:|---|---|---|
| 0 | [#8182177](https://tatoeba.org/en/sentences/show/8182177) | CK | I can't believe you're really in love with me. |
| 1 | [#2276885](https://tatoeba.org/en/sentences/show/2276885) | CK | That's because they don't care. |
| 2 | [#2253976](https://tatoeba.org/en/sentences/show/2253976) | _undertoad | I'll go and get the book tomorrow. |
| 3 | [#450246](https://tatoeba.org/en/sentences/show/450246) | CK | People should do their best. |
| 4 | [#4278474](https://tatoeba.org/en/sentences/show/4278474) | EarlD3 | It's something I'm proud of. |
| 5 | [#2951995](https://tatoeba.org/en/sentences/show/2951995) | CK | I didn't receive your letter until today. |
| 6 | [#7493078](https://tatoeba.org/en/sentences/show/7493078) | CK | Being a prince isn't easy. |
| 7 | [#11503893](https://tatoeba.org/en/sentences/show/11503893) | Amastan | David doesn't have a will. |
| 8 | [#6549891](https://tatoeba.org/en/sentences/show/6549891) | Hybrid | They're definitely up to something. |
| 9 | [#4887838](https://tatoeba.org/en/sentences/show/4887838) | CK | I've got to do it. |
| 10 | [#22523](https://tatoeba.org/en/sentences/show/22523) | CK | Sorry I'm late for the meeting. |
| 11 | [#24209](https://tatoeba.org/en/sentences/show/24209) | CK | I'll give you a call when I get home. |
| 12 | [#19703](https://tatoeba.org/en/sentences/show/19703) | CK | If you don't hurry, you'll miss the train. |
| 13 | [#31118](https://tatoeba.org/en/sentences/show/31118) | CK | We don't have any more bread. |
| 14 | [#1541](https://tatoeba.org/en/sentences/show/1541) | CK | I'm sorry, I can't stay long. |
| 15 | [#26100](https://tatoeba.org/en/sentences/show/26100) | CK | I'll drop you off at the station. |
| 16 | [#37639](https://tatoeba.org/en/sentences/show/37639) | CK | In any case, I'll call you tomorrow. |
| 17 | [#21589](https://tatoeba.org/en/sentences/show/21589) | CK | I'm afraid we're going to be late for school. |
| 18 | [#38388](https://tatoeba.org/en/sentences/show/38388) | CK | I'm sorry, I didn't mean it. |
| 19 | [#31358](https://tatoeba.org/en/sentences/show/31358) | CK | It's time for us to go home. |

## Spanish typo run (corpus/es-typos.txt)

| # | Tatoeba | Author | Sentence |
|---:|---|---|---|
| 0 | [#1926241](https://tatoeba.org/en/sentences/show/1926241) | marcelostockle | Él es tres años más joven que mi papá. |
| 1 | [#10696413](https://tatoeba.org/en/sentences/show/10696413) | Shishir | No sé dónde está mi mamá. |
| 2 | [#1767359](https://tatoeba.org/en/sentences/show/1767359) | marcelostockle | Quiero saber por qué es así. |
| 3 | [#9188727](https://tatoeba.org/en/sentences/show/9188727) | ignacio | Será un día difícil para mí. |
| 4 | [#2311842](https://tatoeba.org/en/sentences/show/2311842) | marcelostockle | Mi familia también vive aquí. |
| 5 | [#1222183](https://tatoeba.org/en/sentences/show/1222183) | marcelostockle | Yo voy ahí cada año. |
| 6 | [#1594263](https://tatoeba.org/en/sentences/show/1594263) | Shishir | Sí, un café, por favor. |
| 7 | [#5650084](https://tatoeba.org/en/sentences/show/5650084) | cueyayotl | ¿Cómo están mamá y papá? |
| 8 | [#640304](https://tatoeba.org/en/sentences/show/640304) | Shishir | Esa película es para niños. |
| 9 | [#11516963](https://tatoeba.org/en/sentences/show/11516963) | adaycito | Nunca había visto un accidente tan terrible. |
| 10 | [#2120706](https://tatoeba.org/en/sentences/show/2120706) | Shishir | Se fue después de mí. |
| 11 | [#3533988](https://tatoeba.org/en/sentences/show/3533988) | marcelostockle | Voy a usar tu teléfono. |
| 12 | [#2152182](https://tatoeba.org/en/sentences/show/2152182) | Shishir | No sé lo que es. |
| 13 | [#2356967](https://tatoeba.org/en/sentences/show/2356967) | hayastan | No sé si él sabe. |
| 14 | [#2933](https://tatoeba.org/en/sentences/show/2933) | Shishir | ¿Me podrías llamar más tarde por favor? |
| 15 | [#503188](https://tatoeba.org/en/sentences/show/503188) | Shishir | ¿A qué hora sale el primer tren? |
| 16 | [#916770](https://tatoeba.org/en/sentences/show/916770) | Shishir | Lo siento, no está en casa. |
| 17 | [#803402](https://tatoeba.org/en/sentences/show/803402) | Shishir | Suelo tomar postre después de cenar. |
| 18 | [#473453](https://tatoeba.org/en/sentences/show/473453) | Shishir | ¿Dónde está la pasta de dientes? |
| 19 | [#330634](https://tatoeba.org/en/sentences/show/330634) | Shishir | Vamos a esperar aquí hasta que él vuelva. |

## German typo run (corpus/de-typos.txt)

| # | Tatoeba | Author | Sentence |
|---:|---|---|---|
| 0 | [#11213719](https://tatoeba.org/en/sentences/show/11213719) | Pfirsichbaeumchen | Es ist schön, dass wir mehr Zeit miteinander verbringen können. |
| 1 | [#12063450](https://tatoeba.org/en/sentences/show/12063450) | mayabe | Vielleicht wäre das gut für sie. |
| 2 | [#12190162](https://tatoeba.org/en/sentences/show/12190162) | Pfirsichbaeumchen | Du wirst über Nacht bleiben müssen. |
| 3 | [#4549775](https://tatoeba.org/en/sentences/show/4549775) | Esperantostern | Wenn ich Geld hätte, würde ich es dir geben. |
| 4 | [#1954496](https://tatoeba.org/en/sentences/show/1954496) | Esperantostern | Je später der Abend, desto schöner die Leute. |
| 5 | [#881922](https://tatoeba.org/en/sentences/show/881922) | Esperantostern | Ich weiß, wie du heißt. |
| 6 | [#1537067](https://tatoeba.org/en/sentences/show/1537067) | Pfirsichbaeumchen | Ich möchte Pilot werden, wenn ich groß bin. |
| 7 | [#2328092](https://tatoeba.org/en/sentences/show/2328092) | Pfirsichbaeumchen | Er ging über die Straße. |
| 8 | [#11372667](https://tatoeba.org/en/sentences/show/11372667) | Yorwba | Mein Handy hat kein Netz. |
| 9 | [#10069898](https://tatoeba.org/en/sentences/show/10069898) | wolfgangth | Ich kam zu spät an. |
| 10 | [#1228348](https://tatoeba.org/en/sentences/show/1228348) | Esperantostern | Um vier Uhr können wir nach Hause gehen. |
| 11 | [#2348666](https://tatoeba.org/en/sentences/show/2348666) | Pfirsichbaeumchen | Müssen wir heute zu Hause bleiben? |
| 12 | [#568375](https://tatoeba.org/en/sentences/show/568375) | Pfirsichbaeumchen | Ich werde ein bisschen später ankommen. |
| 13 | [#454083](https://tatoeba.org/en/sentences/show/454083) | al_ex_an_der | Ich weiß, dass du es schaffen kannst. |
| 14 | [#524910](https://tatoeba.org/en/sentences/show/524910) | Espi | Ich glaube, dass du recht hast. |
| 15 | [#466194](https://tatoeba.org/en/sentences/show/466194) | Espi | Man sagt, dass meine Schwester schön ist. |
| 16 | [#8873124](https://tatoeba.org/en/sentences/show/8873124) | wolfgangth | Es ist gut für uns. |
| 17 | [#432692](https://tatoeba.org/en/sentences/show/432692) | Pfirsichbaeumchen | Ich kann über den Fluss schwimmen. |
| 18 | [#1314641](https://tatoeba.org/en/sentences/show/1314641) | Pfirsichbaeumchen | Es ist an der Zeit. |
| 19 | [#1184244](https://tatoeba.org/en/sentences/show/1184244) | Esperantostern | Ich habe keine Zeit und auch kein Geld. |

