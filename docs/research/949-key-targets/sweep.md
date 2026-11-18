# Parameter sweep (#949)

Each row: `key_targets.sh --no-build --sets committed,held-out,rare --model <parameters>`; `sx=0.25,sy=0.25` throughout. **Broken**: taps today's hit test typed right and the model typed wrong. Wrong words are counted after autocorrect. The default is `w=1,floor=0.1,core=0.25`. Read with [README.md](README.md).

| parameters | set | lang | wrong letters, today | wrong letters, model | fixed | broken | wrong words, today | wrong words, model |
|---|---|---|---:|---:|---:|---:|---:|---:|
| `w=1,floor=0.01,core=0.25` | committed | fr |  13  |  8  |  8  |  **3**  |  9 of 152  |  10 of 152  |
| `w=1,floor=0.01,core=0.25` | committed | en |  21  |  14  |  9  |  **2**  |  9 of 157  |  8 of 157  |
| `w=1,floor=0.01,core=0.25` | held-out | fr |  199  |  85  |  126  |  **12**  |  144 of 1520  |  135 of 1520  |
| `w=1,floor=0.01,core=0.25` | held-out | en |  190  |  86  |  124  |  **20**  |  72 of 1570  |  54 of 1570  |
| `w=1,floor=0.01,core=0.25` | rare | fr |  55  |  53  |  25  |  **23**  |  105 of 455  |  106 of 455  |
| `w=1,floor=0.01,core=0.25` | rare | en |  53  |  56  |  21  |  **24**  |  91 of 425  |  95 of 425  |
| `w=1,floor=0.01,core=0.35` | committed | fr |  13  |  7  |  8  |  **2**  |  9 of 152  |  9 of 152  |
| `w=1,floor=0.01,core=0.35` | committed | en |  21  |  14  |  9  |  **2**  |  9 of 157  |  8 of 157  |
| `w=1,floor=0.01,core=0.35` | held-out | fr |  199  |  92  |  118  |  **11**  |  144 of 1520  |  136 of 1520  |
| `w=1,floor=0.01,core=0.35` | held-out | en |  190  |  92  |  116  |  **18**  |  72 of 1570  |  53 of 1570  |
| `w=1,floor=0.01,core=0.35` | rare | fr |  55  |  41  |  25  |  **11**  |  105 of 455  |  106 of 455  |
| `w=1,floor=0.01,core=0.35` | rare | en |  53  |  53  |  18  |  **18**  |  91 of 425  |  91 of 425  |
| `w=0.5,floor=0.01,core=0.25` | committed | fr |  13  |  4  |  9  |  **0**  |  9 of 152  |  9 of 152  |
| `w=0.5,floor=0.01,core=0.25` | committed | en |  21  |  13  |  8  |  **0**  |  9 of 157  |  8 of 157  |
| `w=0.5,floor=0.01,core=0.25` | held-out | fr |  199  |  93  |  111  |  **5**  |  144 of 1520  |  135 of 1520  |
| `w=0.5,floor=0.01,core=0.25` | held-out | en |  190  |  95  |  102  |  **7**  |  72 of 1570  |  50 of 1570  |
| `w=0.5,floor=0.01,core=0.25` | rare | fr |  55  |  38  |  22  |  **5**  |  105 of 455  |  104 of 455  |
| `w=0.5,floor=0.01,core=0.25` | rare | en |  53  |  49  |  14  |  **10**  |  91 of 425  |  91 of 425  |
| `w=1,floor=0.05,core=0.25` | committed | fr |  13  |  7  |  8  |  **2**  |  9 of 152  |  9 of 152  |
| `w=1,floor=0.05,core=0.25` | committed | en |  21  |  14  |  9  |  **2**  |  9 of 157  |  8 of 157  |
| `w=1,floor=0.05,core=0.25` | held-out | fr |  199  |  87  |  121  |  **9**  |  144 of 1520  |  136 of 1520  |
| `w=1,floor=0.05,core=0.25` | held-out | en |  190  |  89  |  117  |  **16**  |  72 of 1570  |  54 of 1570  |
| `w=1,floor=0.05,core=0.25` | rare | fr |  55  |  39  |  23  |  **7**  |  105 of 455  |  104 of 455  |
| `w=1,floor=0.05,core=0.25` | rare | en |  53  |  48  |  19  |  **14**  |  91 of 425  |  90 of 425  |
| `w=1,floor=0.1,core=0.25` | committed | fr |  13  |  6  |  8  |  **1**  |  9 of 152  |  9 of 152  |
| `w=1,floor=0.1,core=0.25` | committed | en |  21  |  12  |  9  |  **0**  |  9 of 157  |  7 of 157  |
| `w=1,floor=0.1,core=0.25` | held-out | fr |  199  |  91  |  116  |  **8**  |  144 of 1520  |  137 of 1520  |
| `w=1,floor=0.1,core=0.25` | held-out | en |  190  |  92  |  107  |  **9**  |  72 of 1570  |  50 of 1570  |
| `w=1,floor=0.1,core=0.25` | rare | fr |  55  |  37  |  21  |  **3**  |  105 of 455  |  104 of 455  |
| `w=1,floor=0.1,core=0.25` | rare | en |  53  |  49  |  16  |  **12**  |  91 of 425  |  90 of 425  |
| `w=0.5,floor=0.1,core=0.25` | committed | fr |  13  |  5  |  8  |  **0**  |  9 of 152  |  9 of 152  |
| `w=0.5,floor=0.1,core=0.25` | committed | en |  21  |  17  |  5  |  **1**  |  9 of 157  |  9 of 157  |
| `w=0.5,floor=0.1,core=0.25` | held-out | fr |  199  |  123  |  80  |  **4**  |  144 of 1520  |  137 of 1520  |
| `w=0.5,floor=0.1,core=0.25` | held-out | en |  190  |  117  |  77  |  **4**  |  72 of 1570  |  57 of 1570  |
| `w=0.5,floor=0.1,core=0.25` | rare | fr |  55  |  35  |  21  |  **1**  |  105 of 455  |  103 of 455  |
| `w=0.5,floor=0.1,core=0.25` | rare | en |  53  |  51  |  9  |  **7**  |  91 of 425  |  92 of 425  |
| `w=1,floor=0.1,core=0.25,ngram=1` | committed | fr |  13  |  6  |  8  |  **1**  |  9 of 152  |  9 of 152  |
| `w=1,floor=0.1,core=0.25,ngram=1` | committed | en |  21  |  12  |  9  |  **0**  |  9 of 157  |  7 of 157  |
| `w=1,floor=0.1,core=0.25,ngram=1` | held-out | fr |  199  |  93  |  115  |  **9**  |  144 of 1520  |  136 of 1520  |
| `w=1,floor=0.1,core=0.25,ngram=1` | held-out | en |  190  |  85  |  112  |  **7**  |  72 of 1570  |  47 of 1570  |
| `w=1,floor=0.1,core=0.25,ngram=1` | rare | fr |  55  |  38  |  21  |  **4**  |  105 of 455  |  104 of 455  |
| `w=1,floor=0.1,core=0.25,ngram=1` | rare | en |  53  |  49  |  16  |  **12**  |  91 of 425  |  90 of 425  |
| `w=1,floor=0.01,core=0.25,ngram=1` | committed | fr |  13  |  8  |  8  |  **3**  |  9 of 152  |  10 of 152  |
| `w=1,floor=0.01,core=0.25,ngram=1` | committed | en |  21  |  14  |  9  |  **2**  |  9 of 157  |  8 of 157  |
| `w=1,floor=0.01,core=0.25,ngram=1` | held-out | fr |  199  |  82  |  129  |  **12**  |  144 of 1520  |  134 of 1520  |
| `w=1,floor=0.01,core=0.25,ngram=1` | held-out | en |  190  |  80  |  124  |  **14**  |  72 of 1570  |  52 of 1570  |
| `w=1,floor=0.01,core=0.25,ngram=1` | rare | fr |  55  |  55  |  25  |  **25**  |  105 of 455  |  107 of 455  |
| `w=1,floor=0.01,core=0.25,ngram=1` | rare | en |  53  |  56  |  21  |  **24**  |  91 of 425  |  95 of 425  |
