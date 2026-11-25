# Key-target model against today's hit test, every set (#949)

Output of `tools/keyboard-bench/key_targets.sh --udid <udid>` on develop `2e280b7f`, default parameters (`sx=0.25,sy=0.25,core=0.25,w=1,floor=0.1`), iPhone 17 simulator, iOS 27.2, 2026-11-17. Times in microseconds. Read with [README.md](README.md).

### committed

| lang | letter taps | wrong letters, today | wrong letters, model | fixed | **broken** | letter changed | wrong words, today | wrong words, model |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| fr | 669 | 13 | 6 | 8 | **1** | 9 (1.3%) | 9 of 152 | 9 of 152 |
| en | 629 | 21 | 12 | 9 | **0** | 9 (1.4%) | 9 of 157 | 7 of 157 |

Pick time per tap (µs) and trie nodes visited:

| lang | taps | today p50 | model p50 | model p95 | model max | nodes p50 | nodes p95 | nodes max |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| fr | 821 | 0.2 | 0.6 | 16.7 | 89.3 | 0 | 821 | 3214 |
| en | 786 | 0.4 | 0.7 | 13.5 | 32.2 | 0 | 626 | 1671 |

Top-row dead bands (#954): 2 of 1607 taps land in one. The real keyboard types nothing for them today; the model types the intended letter for 2 of them.
- en sentence 11 tap 2 at x 120.70: `e`, replay grid `r`, model `e`
- en sentence 13 tap 36 at x 120.19: `r`, replay grid `e`, model `r`

Broken taps (today right, model wrong):

- fr sentence 15 tap 32: `d` typed `s`

### held-out

| lang | letter taps | wrong letters, today | wrong letters, model | fixed | **broken** | letter changed | wrong words, today | wrong words, model |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| fr | 6690 | 199 | 91 | 116 | **8** | 125 (1.9%) | 144 of 1520 | 137 of 1520 |
| en | 6290 | 190 | 92 | 107 | **9** | 119 (1.9%) | 72 of 1570 | 50 of 1570 |

Pick time per tap (µs) and trie nodes visited:

| lang | taps | today p50 | model p50 | model p95 | model max | nodes p50 | nodes p95 | nodes max |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| fr | 8210 | 0.2 | 0.5 | 14.5 | 56.0 | 0 | 772 | 3941 |
| en | 7860 | 0.3 | 0.7 | 14.0 | 80.8 | 0 | 626 | 2913 |

Top-row dead bands (#954): 10 of 16070 taps land in one. The real keyboard types nothing for them today; the model types the intended letter for 9 of them.
- fr sentence 66 tap 7 at x 120.84: `e`, replay grid `r`, model `e`
- fr sentence 78 tap 11 at x 120.55: `e`, replay grid `none`, model `e`
- fr sentence 132 tap 14 at x 120.28: `r`, replay grid `e`, model `r`
- fr sentence 153 tap 7 at x 40.44: `a`, replay grid `z`, model `a`
- fr sentence 187 tap 20 at x 321.21: `o`, replay grid `i`, model `i`
- en sentence 2 tap 26 at x 120.67: `e`, replay grid `r`, model `e`
- en sentence 4 tap 24 at x 120.47: `e`, replay grid `e`, model `e`
- en sentence 88 tap 1 at x 120.45: `e`, replay grid `e`, model `e`
- en sentence 123 tap 12 at x 321.51: `o`, replay grid `i`, model `o`
- en sentence 186 tap 26 at x 321.71: `o`, replay grid `o`, model `o`

Broken taps (today right, model wrong):

- fr sentence 34 tap 9: `c` typed `v`
- fr sentence 36 tap 14: `e` typed `d`
- fr sentence 42 tap 0: `o` typed `l`
- fr sentence 52 tap 38: `i` typed `o`
- fr sentence 102 tap 36: `i` typed `o`
- fr sentence 114 tap 3: `f` typed `c`
- fr sentence 184 tap 33: `t` typed `r`
- fr sentence 197 tap 18: `b` typed `v`
- en sentence 7 tap 4: `y` typed `t`
- en sentence 29 tap 12: `r` typed `t`
- en sentence 35 tap 5: `n` typed `m`
- en sentence 51 tap 35: `y` typed `t`
- en sentence 113 tap 21: `l` typed `k`
- en sentence 144 tap 18: `e` typed `s`
- en sentence 180 tap 26: `u` typed `i`
- en sentence 182 tap 4: `u` typed `i`
- en sentence 199 tap 17: `e` typed `r`

### sloppy

| lang | letter taps | wrong letters, today | wrong letters, model | fixed | **broken** | letter changed | wrong words, today | wrong words, model |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| fr | 3345 | 495 | 345 | 161 | **11** | 177 (5.3%) | 244 of 760 | 227 of 760 |
| en | 3145 | 425 | 293 | 155 | **23** | 187 (5.9%) | 204 of 785 | 191 of 785 |

Pick time per tap (µs) and trie nodes visited:

| lang | taps | today p50 | model p50 | model p95 | model max | nodes p50 | nodes p95 | nodes max |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| fr | 4105 | 0.2 | 0.7 | 17.1 | 58.8 | 0 | 937 | 3941 |
| en | 3930 | 0.4 | 1.1 | 16.8 | 53.9 | 0 | 816 | 2913 |

Top-row dead bands (#954): 15 of 8035 taps land in one. The real keyboard types nothing for them today; the model types the intended letter for 11 of them.
- fr sentence 23 tap 2 at x 120.72: `r`, replay grid `r`, model `r`
- fr sentence 29 tap 25 at x 240.91: `u`, replay grid `y`, model `u`
- fr sentence 43 tap 43 at x 321.57: `i`, replay grid `i`, model `o`
- fr sentence 48 tap 11 at x 120.40: `r`, replay grid `e`, model `e`
- fr sentence 52 tap 29 at x 321.66: `i`, replay grid `none`, model `o`
- fr sentence 55 tap 30 at x 120.70: `e`, replay grid `r`, model `e`
- fr sentence 91 tap 9 at x 321.54: `o`, replay grid `i`, model `o`
- fr sentence 92 tap 9 at x 321.14: `i`, replay grid `i`, model `i`
- en sentence 16 tap 31 at x 120.56: `e`, replay grid `none`, model `e`
- en sentence 30 tap 24 at x 241.01: `y`, replay grid `y`, model `u`
- en sentence 51 tap 19 at x 120.21: `e`, replay grid `e`, model `e`
- en sentence 55 tap 28 at x 321.35: `o`, replay grid `i`, model `o`
- en sentence 60 tap 28 at x 120.46: `e`, replay grid `e`, model `e`
- en sentence 81 tap 34 at x 40.39: `w`, replay grid `w`, model `w`
- en sentence 92 tap 2 at x 240.93: `u`, replay grid `y`, model `u`

Broken taps (today right, model wrong):

- fr sentence 6 tap 9: `q` typed `s`
- fr sentence 19 tap 5: `d` typed `s`
- fr sentence 34 tap 5: `u` typed `i`
- fr sentence 43 tap 43: `i` typed `o`
- fr sentence 55 tap 29: `i` typed `o`
- fr sentence 58 tap 6: `o` typed `l`
- fr sentence 59 tap 37: `f` typed `d`
- fr sentence 62 tap 8: `t` typed `g`
- fr sentence 79 tap 48: `n` typed `b`
- fr sentence 99 tap 37: `f` typed `c`
- fr sentence 99 tap 38: `i` typed `o`
- en sentence 0 tap 3: `m` typed `n`
- en sentence 2 tap 31: `t` typed `r`
- en sentence 14 tap 5: `e` typed `w`
- en sentence 14 tap 20: `o` typed `l`
- en sentence 16 tap 29: `t` typed `y`
- en sentence 25 tap 22: `n` typed `m`
- en sentence 30 tap 13: `t` typed `g`
- en sentence 30 tap 24: `y` typed `u`
- en sentence 31 tap 33: `i` typed `j`
- en sentence 32 tap 22: `v` typed `b`
- en sentence 41 tap 13: `u` typed `i`
- en sentence 47 tap 4: `y` typed `t`
- en sentence 51 tap 33: `i` typed `o`
- en sentence 58 tap 26: `k` typed `l`
- en sentence 62 tap 17: `o` typed `i`
- en sentence 64 tap 32: `u` typed `i`
- en sentence 65 tap 4: `w` typed `s`
- en sentence 70 tap 4: `i` typed `o`
- en sentence 76 tap 32: `r` typed `d`
- en sentence 83 tap 7: `f` typed `c`
- en sentence 84 tap 18: `e` typed `r`
- en sentence 97 tap 6: `l` typed `p`
- en sentence 97 tap 25: `d` typed `s`

### rare

| lang | letter taps | wrong letters, today | wrong letters, model | fixed | **broken** | letter changed | wrong words, today | wrong words, model |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| fr | 1745 | 55 | 37 | 21 | **3** | 24 (1.4%) | 105 of 455 | 104 of 455 |
| en | 1565 | 53 | 49 | 16 | **12** | 28 (1.8%) | 91 of 425 | 90 of 425 |

Pick time per tap (µs) and trie nodes visited:

| lang | taps | today p50 | model p50 | model p95 | model max | nodes p50 | nodes p95 | nodes max |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| fr | 2200 | 0.3 | 0.5 | 12.4 | 43.2 | 0 | 522 | 2669 |
| en | 1990 | 0.4 | 0.7 | 12.5 | 38.4 | 0 | 547 | 1660 |

Top-row dead bands (#954): 3 of 4190 taps land in one. The real keyboard types nothing for them today; the model types the intended letter for 1 of them.
- en sentence 5 tap 3 at x 120.67: `e`, replay grid `r`, model `e`
- en sentence 5 tap 9 at x 321.30: `o`, replay grid `i`, model `i`
- en sentence 85 tap 21 at x 321.79: `o`, replay grid `o`, model `k`

Broken taps (today right, model wrong):

- fr sentence 31 tap 3: `z` typed `a`
- fr sentence 64 tap 4: `y` typed `u`
- fr sentence 87 tap 3: `x` typed `c`
- en sentence 12 tap 4: `x` typed `c`
- en sentence 21 tap 17: `k` typed `l`
- en sentence 25 tap 19: `x` typed `c`
- en sentence 29 tap 1: `o` typed `i`
- en sentence 32 tap 3: `i` typed `u`
- en sentence 40 tap 16: `j` typed `i`
- en sentence 47 tap 5: `o` typed `i`
- en sentence 77 tap 14: `u` typed `i`
- en sentence 78 tap 8: `u` typed `i`
- en sentence 85 tap 21: `o` typed `k`
- en sentence 86 tap 1: `u` typed `i`
- en sentence 87 tap 14: `p` typed `l`

