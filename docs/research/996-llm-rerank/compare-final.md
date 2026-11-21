| run | replay | wrong words, final text | broken | miscorrected | fixed | missed | next word in top 3 | engine ms per space p50 / p95 | per letter p50 / p95 | model ms per space p50 / p95 (n) | per letter p50 / p95 (n) |
|---|---|---:|---:|---:|---:|---:|---:|---|---|---|---|
| fr | off | 3 / 152 | 0 | 0 | 28 | 3 | 17.4% | 0.12 / 0.57 | 0.16 / 0.63 | n/a / n/a (0) | n/a / n/a (0) |
| fr | qwen-w0.01 | 3 / 152 | 0 | 0 | 28 | 3 | 33.3% | 14.01 / 36.35 | 0.15 / 50.26 | 13.87 / 36.15 (142) | 13.57 / 62.23 (218) |
| fr | smollm2-w0.01 | 3 / 152 | 0 | 0 | 28 | 3 | 12.1% | 8.20 / 13.04 | 0.13 / 24.10 | 8.22 / 12.18 (142) | 11.97 / 30.69 (218) |
| en | off | 7 / 157 | 0 | 1 | 13 | 4 | 20.7% | 0.07 / 0.77 | 1.15 / 2.14 | n/a / n/a (0) | n/a / n/a (0) |
| en | qwen-w0.01 | 7 / 157 | 0 | 1 | 13 | 4 | 45.9% | 13.85 / 25.63 | 1.09 / 27.03 | 13.74 / 25.48 (146) | 13.47 / 38.10 (93) |
| en | smollm2-w0.01 | 7 / 157 | 0 | 1 | 13 | 4 | 38.5% | 4.54 / 8.88 | 1.04 / 10.12 | 4.45 / 8.34 (146) | 7.94 / 16.22 (93) |
| en-typos | off | 1 / 129 | 0 | 1 | 36 | 0 | 27.5% | 0.06 / 0.12 | 0.99 / 2.02 | n/a / n/a (0) | n/a / n/a (0) |
| en-typos | qwen-w0.01 | 1 / 129 | 0 | 1 | 36 | 0 | 47.7% | 13.79 / 25.93 | 1.02 / 15.63 | 13.72 / 36.21 (119) | 13.61 / 50.89 (53) |
| en-typos | smollm2-w0.01 | 1 / 129 | 0 | 1 | 36 | 0 | 45.0% | 4.54 / 8.86 | 0.99 / 9.75 | 4.47 / 11.79 (119) | 8.10 / 19.54 (53) |
| es | off | 13 / 141 | 0 | 3 | 29 | 9 | 22.5% | 0.10 / 0.61 | 0.10 / 0.70 | n/a / n/a (0) | n/a / n/a (0) |
| es | qwen-w0.01 | 13 / 141 | 0 | 3 | 29 | 9 | 36.7% | 14.02 / 36.39 | 0.13 / 62.14 | 13.85 / 36.39 (136) | 37.40 / 84.50 (144) |
| es | smollm2-w0.01 | 14 / 141 | 0 | 4 | 28 | 9 | 24.2% | 8.25 / 15.54 | 0.12 / 27.96 | 8.15 / 15.35 (136) | 19.48 / 38.67 (144) |
| de | off | 8 / 141 | 0 | 1 | 16 | 7 | 18.0% | 0.09 / 0.59 | 0.10 / 0.70 | n/a / n/a (0) | n/a / n/a (0) |
| de | qwen-w0.01 | 8 / 141 | 0 | 1 | 16 | 7 | 19.7% | 14.00 / 36.84 | 0.11 / 38.51 | 13.83 / 36.65 (128) | 25.18 / 97.22 (127) |
| de | smollm2-w0.01 | 9 / 141 | 0 | 2 | 15 | 7 | 4.9% | 8.39 / 15.60 | 0.11 / 23.41 | 8.30 / 15.49 (128) | 15.76 / 45.48 (127) |

| typed | before it | Pierre meant | kind | off | qwen-w0.01 | smollm2-w0.01 |
|---|---|---|---|---|---|---|
| `trouce` | Je | trouve | wrong | trouvé ✗ | trouvé ✗ | trouvé ✗ |
| `triuce` | Je | trouve | wrong | trouvé ✗ | trouvé ✗ | trouvé ✗ |
| `trojce` | J'ai | trouvé | guard | trouvé ✓ | trouvé ✓ | trouvé ✓ |
| `trouvr` | Je | trouve | guard | trouve ✓ | trouve ✓ | trouve ✓ |
| `j'aa` | (start) | j'ai | wrong | J'la ✗ | J'as ✗ | J'la ✗ |
| `j'ak` | (start) | j'ai | wrong | J'au ✗ | J'ai ✓ | J'au ✗ |
| `lz` | (start) | la or le | wrong | L'z ✗ | L'z ✗ | L'z ✗ |
| `lnction` | (start) | fonction de saisir | wrong | Onction de saisir ✗ | Onction de saisir ✗ | Onction de saisir ✗ |
| `pasqueil` | (start) | parce qu'il | wrong | Pasque ✗ | Pasque ✗ | Pasque ✗ |
| `j'ainhate` | (start) | j'ai hâte | wrong | J'ainhate ✗ | J'ainhate ✗ | J'ainhate ✗ |
| `j'aintrouve` | (start) | j'ai trouvé | wrong | J'aintrouve ✗ | J'aintrouve ✗ | J'aintrouve ✗ |
| `integté` | (start) | intégré | wrong | Integté ✗ | Integté ✗ | Integté ✗ |
| `fràvhelent` | (start) | franchement | wrong | Fràvhelent ✗ | Fràvhelent ✗ | Fràvhelent ✗ |
| `sôt` | Ils | sont | guard | sont ✓ | sont ✓ | sont ✓ |
| `boir` | (start) | voir | guard | Voir ✓ | Voir ✓ | Voir ✓ |
| `ckavier` | (start) | clavier | guard | Clavier ✓ | Clavier ✓ | Clavier ✓ |
| `interessang` | (start) | intéressant | guard | Intéressant ✓ | Intéressant ✓ | Intéressant ✓ |
| `desagrebale` | (start) | désagréable | guard | Désagréable ✓ | Désagréable ✓ | Désagréable ✓ |
| `oji` | (start) | oui | guard | Oui ✓ | Oui ✓ | Oui ✓ |
| `jusge` | (start) | juste | guard | Juste ✓ | Juste ✓ | Juste ✓ |
| `ma'qje` | (start) | manque | wrong | Ma'que ✗ | Ma'que ✗ | Ma'que ✗ |
| `dizcitd` | (start) | discord | wrong | Discute ✗ | Discute ✗ | Discute ✗ |
| `we` | Bon | we | wrong | de ✗ | de ✗ | de ✗ |
| `honetre` | (start) | honnête | wrong | Monstre ✗ | Contre ✗ | Monstre ✗ |
| `donnequoi` | (start) | donne quoi | guard | Donne quoi ✓ | Donne quoi ✓ | Donne quoi ✓ |
| `sats` | (start) | sais | guard | Sais ✓ | Sais ✓ | Dans ✗ |
| `qur` | Passai | que | wrong | sur ✗ | sur ✗ | sur ✗ |

- off: 0 of 16 non-guard cases right, 11 of 11 guards right
- qwen-w0.01: 1 of 16 non-guard cases right, 11 of 11 guards right
- smollm2-w0.01: 0 of 16 non-guard cases right, 10 of 11 guards right
