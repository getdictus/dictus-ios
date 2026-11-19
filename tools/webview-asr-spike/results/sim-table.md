
### sim-ios26.5-iphone15promax-fresh-page-per-model.jsonl

**fastconformer-14288**: load 2639 ms (fetch 116, settle 2000, create 521), wasm heap 512 MB, WebContent at load 503 MB

| clip | audio s | decode ms (median) | RTF | WER webview | WER native Parakeet | text (webview) |
|---|---|---|---|---|---|---|
| fr-01-spoken-punctuation | 4.4 | 344 | 0.08 | 20.0% | 20.0% | Salut, Camille, je serai en retard ce matin. |
| fr-02-appointment-numbers | 4.8 | 367 | 0.08 | 61.5% | 23.1% | Le rendez- vous est fixé au quatorze mars à neuf heures trente, salle … |
| fr-03-shopping | 4.1 | 314 | 0.08 | 7.1% | 0.0% | Penser à acheter du pain, des tomates et un peu de fromage en rentrant… |
| fr-04-question-mark | 5.1 | 390 | 0.08 | 15.4% | 0.0% | le compte rendu de la réunion avant ce soir? Point d'interrogation. |
| fr-concat-4short | 18.4 | 1418 | 0.08 | 28.0% | n/a | Camille, Virgule. Je serai en retard ce matin. Le rendez vous est fixé… |
| fr-long-first60s | 60.0 | 5274 | 0.09 | 7.9% | n/a | à tous petits points sur ma journée. Ce matin, j'ai repris le problème… |
| fr-long-01-workday-sync-fix | 71.8 | 6466 | 0.09 | 6.1% | 82.9% | à tous. Petit point sur ma journée. Ce matin, j'ai repris le problème … |

WebContent footprint over the run: max 1540 MB, last 1540 MB
**parakeet-v3**: load 3127 ms (fetch 299, settle 2000, create 827), wasm heap 819 MB, WebContent at load 1539 MB

| clip | audio s | decode ms (median) | RTF | WER webview | WER native Parakeet | text (webview) |
|---|---|---|---|---|---|---|
| fr-01-spoken-punctuation | 4.4 | 1546 | 0.35 | 10.0% | 20.0% | Salut Camille Je serai en retard ce matin point |
| fr-02-appointment-numbers | 4.8 | 1674 | 0.35 | 23.1% | 23.1% | Le rendez-vous est fixé au 14 mars à 9h30, salle 212. |
| fr-03-shopping | 4.1 | 1442 | 0.35 | 0.0% | 0.0% | Pensez à acheter du pain, des tomates et un peu de fromage en rentrant… |
| fr-04-question-mark | 5.1 | 1904 | 0.37 | 0.0% | 0.0% | Pouvez-vous m'envoyer le compte rendu de la réunion avant ce soir? Poi… |
| fr-concat-4short | 18.4 | 6254 | 0.34 | 76.0% | n/a | Pense à acheter du pain, des tomates and un peu de fromage en rentrant… |
| fr-long-first60s | 60.0 | 22248 | 0.37 | 177.9% | n/a | This time, I've read the problem of synchronisation after the semaine.… |
| fr-long-01-workday-sync-fix | 71.8 | 27076 | 0.38 | 95.2% | 82.9% | This time, I've repeated the problem of synchronisation after the semi… |

WebContent footprint over the run: max 1570 MB, last 1570 MB
