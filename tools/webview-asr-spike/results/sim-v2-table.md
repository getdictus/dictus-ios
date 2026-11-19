
### sim-v2-parakeet-v3.jsonl

**parakeet-v3**: load 3598 ms (fetch 702, settle 2000, create 893), wasm heap 819 MB, WebContent at load 1535 MB

| clip | audio s | decode ms (median) | RTF | WER webview | WER native Parakeet | text (webview) |
|---|---|---|---|---|---|---|
| fr-01-spoken-punctuation | 4.4 | 1590 | 0.36 | 10.0% | 20.0% | Salut Camille Je serai en retard ce matin point |
| fr-02-appointment-numbers | 4.8 | 1710 | 0.36 | 23.1% | 23.1% | Le rendez-vous est fixé au 14 mars à 9h30, salle 212. |
| fr-03-shopping | 4.1 | 1503 | 0.37 | 0.0% | 0.0% | Pensez à acheter du pain, des tomates et un peu de fromage en rentrant… |
| fr-04-question-mark | 5.1 | 1864 | 0.36 | 0.0% | 0.0% | Pouvez-vous m'envoyer le compte rendu de la réunion avant ce soir? Poi… |
| fr-long-first15s | 15.0 | 5418 | 0.36 | 120.0% | n/a | Bonjour audience. Petit point sur my journey. This matin, I've reprise… |
| fr-concat-4short | 18.4 | 6574 | 0.36 | 76.0% | n/a | Pense à acheter du pain, des tomates and un peu de fromage en rentrant… |
| fr-long-first60s | 60.0 | 23258 | 0.39 | 177.9% | n/a | This time, I've read the problem of synchronisation after the semaine.… |
| fr-long-01-workday-sync-fix | 71.8 | 27358 | 0.38 | 95.2% | 82.9% | This time, I've repeated the problem of synchronisation after the semi… |

WebContent footprint over the run: max 1547 MB, last 1537 MB

### sim-v2-fastconformer-14288.jsonl

**fastconformer-14288**: load 2652 ms (fetch 122, settle 2000, create 527), wasm heap 512 MB, WebContent at load 493 MB

| clip | audio s | decode ms (median) | RTF | WER webview | WER native Parakeet | text (webview) |
|---|---|---|---|---|---|---|
| fr-01-spoken-punctuation | 4.4 | 382 | 0.09 | 20.0% | 20.0% | Salut, Camille, je serai en retard ce matin. |
| fr-02-appointment-numbers | 4.8 | 404 | 0.08 | 61.5% | 23.1% | Le rendez- vous est fixé au quatorze mars à neuf heures trente, salle … |
| fr-03-shopping | 4.1 | 340 | 0.08 | 7.1% | 0.0% | Penser à acheter du pain, des tomates et un peu de fromage en rentrant… |
| fr-04-question-mark | 5.1 | 400 | 0.08 | 15.4% | 0.0% | le compte rendu de la réunion avant ce soir? Point d'interrogation. |
| fr-long-first15s | 15.0 | 1203 | 0.08 | 10.9% | n/a | Petit point sur ma journée. Ce matin, j'ai repris le problème de synch… |
| fr-concat-4short | 18.4 | 1490 | 0.08 | 28.0% | n/a | Camille, Virgule. Je serai en retard ce matin. Le rendez vous est fixé… |
| fr-long-first60s | 60.0 | 5508 | 0.09 | 7.9% | n/a | à tous petits points sur ma journée. Ce matin, j'ai repris le problème… |
| fr-long-01-workday-sync-fix | 71.8 | 6602 | 0.09 | 6.1% | 82.9% | à tous. Petit point sur ma journée. Ce matin, j'ai repris le problème … |

WebContent footprint over the run: max 820 MB, last 779 MB

### sim-v2-fastconformer-20k.jsonl

**fastconformer-20k**: load 3249 ms (fetch 146, settle 2000, create 990), wasm heap 512 MB, WebContent at load 517 MB

| clip | audio s | decode ms (median) | RTF | WER webview | WER native Parakeet | text (webview) |
|---|---|---|---|---|---|---|
| fr-01-spoken-punctuation | 4.4 | 355 | 0.08 | 30.0% | 20.0% | Je serai en retard ce matin point |
| fr-02-appointment-numbers | 4.8 | 368 | 0.08 | 53.8% | 23.1% | le rendez vous est fixé au quatorze mars à neuf heures trente salles |
| fr-03-shopping | 4.1 | 310 | 0.08 | 7.1% | 0.0% | à acheter du pain, des tomates et un peu de fromage en rentrant. |
| fr-04-question-mark | 5.1 | 392 | 0.08 | 15.4% | 0.0% | Pouvez vous m'envoyer le compte rendu de la réunion avant ce soir? poi… |
| fr-long-first15s | 15.0 | 1180 | 0.08 | 6.5% | n/a | Bonjour à tous petit point sur ma journée. Ce matin j'ai repris le pro… |
| fr-concat-4short | 18.4 | 1394 | 0.08 | 32.0% | n/a | Je serai en retard ce matin. Le rendez vous est fixé au quatorze mars … |
| fr-long-first60s | 60.0 | 5490 | 0.09 | 7.4% | n/a | Bonjour à tous petits points sur ma journée. Ce matin j'ai repris le p… |
| fr-long-01-workday-sync-fix | 71.8 | 6830 | 0.10 | 6.6% | 82.9% | Bonjour à tous petits points sur ma journée. Ce matin j'ai repris le p… |

WebContent footprint over the run: max 816 MB, last 775 MB
