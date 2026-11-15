| engine | pipeline | language | WER clean clips | WER clips with a tail | invented endings (tails) | WER clips cut in a word | invented endings (cuts) |
|---|---|---|---|---|---|---|---|
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | all | 1.9 % | 2.0 % | 0/100 | 2.4 % | 20/65 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | de | 0.0 % | 0.0 % | 0/20 | 0.5 % | 2/13 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | en | 0.7 % | 0.7 % | 0/20 | 1.1 % | 3/13 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | es | 0.4 % | 0.4 % | 0/20 | 1.3 % | 4/13 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | fr | 3.2 % | 3.7 % | 0/25 | 3.1 % | 7/16 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | zh | 4.3 % | 4.1 % | 0/15 | 4.8 % | 4/10 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | all | 1.9 % | 2.0 % | 0/100 | 2.4 % | 20/65 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | de | 0.0 % | 0.0 % | 0/20 | 0.5 % | 2/13 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | en | 0.7 % | 0.7 % | 0/20 | 1.1 % | 3/13 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | es | 0.4 % | 0.4 % | 0/20 | 1.3 % | 4/13 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | fr | 3.2 % | 3.7 % | 0/25 | 3.1 % | 7/16 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | zh | 4.3 % | 4.1 % | 0/15 | 4.8 % | 4/10 |
| openai_whisper-small_216MB | trim | all | 8.1 % | 7.5 % | 0/100 | 9.1 % | 31/65 |
| openai_whisper-small_216MB | trim | de | 1.2 % | 1.2 % | 0/20 | 4.0 % | 6/13 |
| openai_whisper-small_216MB | trim | en | 1.1 % | 1.1 % | 0/20 | 2.8 % | 6/13 |
| openai_whisper-small_216MB | trim | es | 0.7 % | 0.9 % | 0/20 | 2.1 % | 4/13 |
| openai_whisper-small_216MB | trim | fr | 4.3 % | 4.5 % | 0/25 | 5.9 % | 8/16 |
| openai_whisper-small_216MB | trim | zh | 25.3 % | 22.9 % | 0/15 | 24.0 % | 7/10 |
| openai_whisper-small_216MB | trim+past-audio | all | 8.1 % | 7.5 % | 0/100 | 9.1 % | 31/65 |
| openai_whisper-small_216MB | trim+past-audio | de | 1.2 % | 1.2 % | 0/20 | 4.0 % | 6/13 |
| openai_whisper-small_216MB | trim+past-audio | en | 1.1 % | 1.1 % | 0/20 | 2.8 % | 6/13 |
| openai_whisper-small_216MB | trim+past-audio | es | 0.7 % | 0.9 % | 0/20 | 2.1 % | 4/13 |
| openai_whisper-small_216MB | trim+past-audio | fr | 4.3 % | 4.5 % | 0/25 | 5.9 % | 8/16 |
| openai_whisper-small_216MB | trim+past-audio | zh | 25.3 % | 22.9 % | 0/15 | 24.0 % | 7/10 |

| engine | pipeline | language | tail | WER (CER zh) | invented endings |
|---|---|---|---|---|---|
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | all | clean | 1.9 % (29/1488) | 0/20 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | all | cut-14s | 0.4 % (1/247) | 0/5 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | all | cut-50% | 2.3 % (17/733) | 4/20 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | all | cut-70% | 2.9 % (30/1039) | 10/20 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | all | cut-90% | 2.4 % (32/1353) | 6/20 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | all | noisy-3s | 1.9 % (29/1488) | 0/20 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | all | noisy-8s | 1.9 % (29/1488) | 0/20 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | all | quiet-3s | 2.0 % (30/1488) | 0/20 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | all | quiet-8s | 2.0 % (30/1488) | 0/20 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | all | zero-3s | 1.9 % (29/1488) | 0/20 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | de | clean | 0.0 % (0/257) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | de | cut-14s | 0.0 % (0/34) | 0/1 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | de | cut-50% | 0.7 % (1/134) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | de | cut-70% | 0.6 % (1/178) | 1/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | de | cut-90% | 0.4 % (1/232) | 1/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | de | noisy-3s | 0.0 % (0/257) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | de | noisy-8s | 0.0 % (0/257) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | de | quiet-3s | 0.0 % (0/257) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | de | quiet-8s | 0.0 % (0/257) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | de | zero-3s | 0.0 % (0/257) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | en | clean | 0.7 % (2/281) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | en | cut-14s | 0.0 % (0/52) | 0/1 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | en | cut-50% | 1.4 % (2/141) | 1/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | en | cut-70% | 1.5 % (3/198) | 2/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | en | cut-90% | 0.8 % (2/258) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | en | noisy-3s | 0.7 % (2/281) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | en | noisy-8s | 0.7 % (2/281) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | en | quiet-3s | 0.7 % (2/281) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | en | quiet-8s | 0.7 % (2/281) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | en | zero-3s | 0.7 % (2/281) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | es | clean | 0.4 % (1/273) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | es | cut-14s | 0.0 % (0/43) | 0/1 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | es | cut-50% | 1.5 % (2/134) | 1/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | es | cut-70% | 1.6 % (3/193) | 2/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | es | cut-90% | 1.2 % (3/252) | 1/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | es | noisy-3s | 0.4 % (1/273) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | es | noisy-8s | 0.4 % (1/273) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | es | quiet-3s | 0.4 % (1/273) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | es | quiet-8s | 0.4 % (1/273) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | es | zero-3s | 0.4 % (1/273) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | fr | clean | 3.2 % (9/278) | 0/5 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | fr | cut-14s | 2.2 % (1/46) | 0/1 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | fr | cut-50% | 2.3 % (3/133) | 1/5 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | fr | cut-70% | 3.6 % (7/192) | 3/5 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | fr | cut-90% | 3.2 % (8/250) | 3/5 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | fr | noisy-3s | 3.6 % (10/278) | 0/5 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | fr | noisy-8s | 3.6 % (10/278) | 0/5 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | fr | quiet-3s | 4.0 % (11/278) | 0/5 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | fr | quiet-8s | 4.0 % (11/278) | 0/5 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | fr | zero-3s | 3.2 % (9/278) | 0/5 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | zh | clean | 4.3 % (17/399) | 0/3 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | zh | cut-14s | 0.0 % (0/72) | 0/1 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | zh | cut-50% | 4.7 % (9/191) | 1/3 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | zh | cut-70% | 5.8 % (16/278) | 2/3 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | zh | cut-90% | 5.0 % (18/361) | 1/3 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | zh | noisy-3s | 4.0 % (16/399) | 0/3 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | zh | noisy-8s | 4.0 % (16/399) | 0/3 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | zh | quiet-3s | 4.0 % (16/399) | 0/3 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | zh | quiet-8s | 4.0 % (16/399) | 0/3 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | zh | zero-3s | 4.3 % (17/399) | 0/3 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | all | clean | 1.9 % (29/1488) | 0/20 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | all | cut-14s | 0.4 % (1/247) | 0/5 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | all | cut-50% | 2.3 % (17/733) | 4/20 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | all | cut-70% | 2.9 % (30/1039) | 10/20 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | all | cut-90% | 2.4 % (32/1353) | 6/20 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | all | noisy-3s | 1.9 % (29/1488) | 0/20 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | all | noisy-8s | 1.9 % (29/1488) | 0/20 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | all | quiet-3s | 2.0 % (30/1488) | 0/20 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | all | quiet-8s | 2.0 % (30/1488) | 0/20 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | all | zero-3s | 1.9 % (29/1488) | 0/20 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | de | clean | 0.0 % (0/257) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | de | cut-14s | 0.0 % (0/34) | 0/1 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | de | cut-50% | 0.7 % (1/134) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | de | cut-70% | 0.6 % (1/178) | 1/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | de | cut-90% | 0.4 % (1/232) | 1/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | de | noisy-3s | 0.0 % (0/257) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | de | noisy-8s | 0.0 % (0/257) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | de | quiet-3s | 0.0 % (0/257) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | de | quiet-8s | 0.0 % (0/257) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | de | zero-3s | 0.0 % (0/257) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | en | clean | 0.7 % (2/281) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | en | cut-14s | 0.0 % (0/52) | 0/1 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | en | cut-50% | 1.4 % (2/141) | 1/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | en | cut-70% | 1.5 % (3/198) | 2/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | en | cut-90% | 0.8 % (2/258) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | en | noisy-3s | 0.7 % (2/281) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | en | noisy-8s | 0.7 % (2/281) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | en | quiet-3s | 0.7 % (2/281) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | en | quiet-8s | 0.7 % (2/281) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | en | zero-3s | 0.7 % (2/281) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | es | clean | 0.4 % (1/273) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | es | cut-14s | 0.0 % (0/43) | 0/1 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | es | cut-50% | 1.5 % (2/134) | 1/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | es | cut-70% | 1.6 % (3/193) | 2/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | es | cut-90% | 1.2 % (3/252) | 1/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | es | noisy-3s | 0.4 % (1/273) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | es | noisy-8s | 0.4 % (1/273) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | es | quiet-3s | 0.4 % (1/273) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | es | quiet-8s | 0.4 % (1/273) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | es | zero-3s | 0.4 % (1/273) | 0/4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | fr | clean | 3.2 % (9/278) | 0/5 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | fr | cut-14s | 2.2 % (1/46) | 0/1 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | fr | cut-50% | 2.3 % (3/133) | 1/5 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | fr | cut-70% | 3.6 % (7/192) | 3/5 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | fr | cut-90% | 3.2 % (8/250) | 3/5 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | fr | noisy-3s | 3.6 % (10/278) | 0/5 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | fr | noisy-8s | 3.6 % (10/278) | 0/5 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | fr | quiet-3s | 4.0 % (11/278) | 0/5 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | fr | quiet-8s | 4.0 % (11/278) | 0/5 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | fr | zero-3s | 3.2 % (9/278) | 0/5 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | zh | clean | 4.3 % (17/399) | 0/3 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | zh | cut-14s | 0.0 % (0/72) | 0/1 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | zh | cut-50% | 4.7 % (9/191) | 1/3 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | zh | cut-70% | 5.8 % (16/278) | 2/3 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | zh | cut-90% | 5.0 % (18/361) | 1/3 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | zh | noisy-3s | 4.0 % (16/399) | 0/3 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | zh | noisy-8s | 4.0 % (16/399) | 0/3 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | zh | quiet-3s | 4.0 % (16/399) | 0/3 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | zh | quiet-8s | 4.0 % (16/399) | 0/3 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | zh | zero-3s | 4.3 % (17/399) | 0/3 |
| openai_whisper-small_216MB | trim | all | clean | 8.1 % (121/1488) | 0/20 |
| openai_whisper-small_216MB | trim | all | cut-14s | 11.0 % (27/245) | 2/5 |
| openai_whisper-small_216MB | trim | all | cut-50% | 9.0 % (66/734) | 11/20 |
| openai_whisper-small_216MB | trim | all | cut-70% | 8.2 % (85/1036) | 9/20 |
| openai_whisper-small_216MB | trim | all | cut-90% | 9.5 % (128/1348) | 9/20 |
| openai_whisper-small_216MB | trim | all | noisy-3s | 6.4 % (95/1488) | 0/20 |
| openai_whisper-small_216MB | trim | all | noisy-8s | 6.4 % (95/1488) | 0/20 |
| openai_whisper-small_216MB | trim | all | quiet-3s | 8.4 % (125/1488) | 0/20 |
| openai_whisper-small_216MB | trim | all | quiet-8s | 8.4 % (125/1488) | 0/20 |
| openai_whisper-small_216MB | trim | all | zero-3s | 8.1 % (121/1488) | 0/20 |
| openai_whisper-small_216MB | trim | de | clean | 1.2 % (3/257) | 0/4 |
| openai_whisper-small_216MB | trim | de | cut-14s | 0.0 % (0/34) | 0/1 |
| openai_whisper-small_216MB | trim | de | cut-50% | 3.8 % (5/132) | 2/4 |
| openai_whisper-small_216MB | trim | de | cut-70% | 2.8 % (5/178) | 2/4 |
| openai_whisper-small_216MB | trim | de | cut-90% | 5.6 % (13/234) | 2/4 |
| openai_whisper-small_216MB | trim | de | noisy-3s | 1.2 % (3/257) | 0/4 |
| openai_whisper-small_216MB | trim | de | noisy-8s | 1.2 % (3/257) | 0/4 |
| openai_whisper-small_216MB | trim | de | quiet-3s | 1.2 % (3/257) | 0/4 |
| openai_whisper-small_216MB | trim | de | quiet-8s | 1.2 % (3/257) | 0/4 |
| openai_whisper-small_216MB | trim | de | zero-3s | 1.2 % (3/257) | 0/4 |
| openai_whisper-small_216MB | trim | en | clean | 1.1 % (3/281) | 0/4 |
| openai_whisper-small_216MB | trim | en | cut-14s | 0.0 % (0/52) | 0/1 |
| openai_whisper-small_216MB | trim | en | cut-50% | 4.2 % (6/143) | 2/4 |
| openai_whisper-small_216MB | trim | en | cut-70% | 2.0 % (4/199) | 2/4 |
| openai_whisper-small_216MB | trim | en | cut-90% | 3.1 % (8/257) | 2/4 |
| openai_whisper-small_216MB | trim | en | noisy-3s | 1.1 % (3/281) | 0/4 |
| openai_whisper-small_216MB | trim | en | noisy-8s | 1.1 % (3/281) | 0/4 |
| openai_whisper-small_216MB | trim | en | quiet-3s | 1.1 % (3/281) | 0/4 |
| openai_whisper-small_216MB | trim | en | quiet-8s | 1.1 % (3/281) | 0/4 |
| openai_whisper-small_216MB | trim | en | zero-3s | 1.1 % (3/281) | 0/4 |
| openai_whisper-small_216MB | trim | es | clean | 0.7 % (2/273) | 0/4 |
| openai_whisper-small_216MB | trim | es | cut-14s | 4.8 % (2/42) | 1/1 |
| openai_whisper-small_216MB | trim | es | cut-50% | 3.8 % (5/133) | 2/4 |
| openai_whisper-small_216MB | trim | es | cut-70% | 2.1 % (4/194) | 1/4 |
| openai_whisper-small_216MB | trim | es | cut-90% | 0.8 % (2/251) | 0/4 |
| openai_whisper-small_216MB | trim | es | noisy-3s | 1.1 % (3/273) | 0/4 |
| openai_whisper-small_216MB | trim | es | noisy-8s | 1.1 % (3/273) | 0/4 |
| openai_whisper-small_216MB | trim | es | quiet-3s | 0.7 % (2/273) | 0/4 |
| openai_whisper-small_216MB | trim | es | quiet-8s | 0.7 % (2/273) | 0/4 |
| openai_whisper-small_216MB | trim | es | zero-3s | 0.7 % (2/273) | 0/4 |
| openai_whisper-small_216MB | trim | fr | clean | 4.3 % (12/278) | 0/5 |
| openai_whisper-small_216MB | trim | fr | cut-14s | 4.3 % (2/46) | 0/1 |
| openai_whisper-small_216MB | trim | fr | cut-50% | 4.5 % (6/132) | 2/5 |
| openai_whisper-small_216MB | trim | fr | cut-70% | 7.0 % (13/187) | 3/5 |
| openai_whisper-small_216MB | trim | fr | cut-90% | 6.0 % (15/248) | 3/5 |
| openai_whisper-small_216MB | trim | fr | noisy-3s | 4.7 % (13/278) | 0/5 |
| openai_whisper-small_216MB | trim | fr | noisy-8s | 4.7 % (13/278) | 0/5 |
| openai_whisper-small_216MB | trim | fr | quiet-3s | 4.3 % (12/278) | 0/5 |
| openai_whisper-small_216MB | trim | fr | quiet-8s | 4.3 % (12/278) | 0/5 |
| openai_whisper-small_216MB | trim | fr | zero-3s | 4.3 % (12/278) | 0/5 |
| openai_whisper-small_216MB | trim | zh | clean | 25.3 % (101/399) | 0/3 |
| openai_whisper-small_216MB | trim | zh | cut-14s | 32.4 % (23/71) | 1/1 |
| openai_whisper-small_216MB | trim | zh | cut-50% | 22.7 % (44/194) | 3/3 |
| openai_whisper-small_216MB | trim | zh | cut-70% | 21.2 % (59/278) | 1/3 |
| openai_whisper-small_216MB | trim | zh | cut-90% | 25.1 % (90/358) | 2/3 |
| openai_whisper-small_216MB | trim | zh | noisy-3s | 18.3 % (73/399) | 0/3 |
| openai_whisper-small_216MB | trim | zh | noisy-8s | 18.3 % (73/399) | 0/3 |
| openai_whisper-small_216MB | trim | zh | quiet-3s | 26.3 % (105/399) | 0/3 |
| openai_whisper-small_216MB | trim | zh | quiet-8s | 26.3 % (105/399) | 0/3 |
| openai_whisper-small_216MB | trim | zh | zero-3s | 25.3 % (101/399) | 0/3 |
| openai_whisper-small_216MB | trim+past-audio | all | clean | 8.1 % (121/1488) | 0/20 |
| openai_whisper-small_216MB | trim+past-audio | all | cut-14s | 11.0 % (27/245) | 2/5 |
| openai_whisper-small_216MB | trim+past-audio | all | cut-50% | 9.0 % (66/734) | 11/20 |
| openai_whisper-small_216MB | trim+past-audio | all | cut-70% | 8.2 % (85/1036) | 9/20 |
| openai_whisper-small_216MB | trim+past-audio | all | cut-90% | 9.5 % (128/1348) | 9/20 |
| openai_whisper-small_216MB | trim+past-audio | all | noisy-3s | 6.4 % (95/1488) | 0/20 |
| openai_whisper-small_216MB | trim+past-audio | all | noisy-8s | 6.4 % (95/1488) | 0/20 |
| openai_whisper-small_216MB | trim+past-audio | all | quiet-3s | 8.4 % (125/1488) | 0/20 |
| openai_whisper-small_216MB | trim+past-audio | all | quiet-8s | 8.4 % (125/1488) | 0/20 |
| openai_whisper-small_216MB | trim+past-audio | all | zero-3s | 8.1 % (121/1488) | 0/20 |
| openai_whisper-small_216MB | trim+past-audio | de | clean | 1.2 % (3/257) | 0/4 |
| openai_whisper-small_216MB | trim+past-audio | de | cut-14s | 0.0 % (0/34) | 0/1 |
| openai_whisper-small_216MB | trim+past-audio | de | cut-50% | 3.8 % (5/132) | 2/4 |
| openai_whisper-small_216MB | trim+past-audio | de | cut-70% | 2.8 % (5/178) | 2/4 |
| openai_whisper-small_216MB | trim+past-audio | de | cut-90% | 5.6 % (13/234) | 2/4 |
| openai_whisper-small_216MB | trim+past-audio | de | noisy-3s | 1.2 % (3/257) | 0/4 |
| openai_whisper-small_216MB | trim+past-audio | de | noisy-8s | 1.2 % (3/257) | 0/4 |
| openai_whisper-small_216MB | trim+past-audio | de | quiet-3s | 1.2 % (3/257) | 0/4 |
| openai_whisper-small_216MB | trim+past-audio | de | quiet-8s | 1.2 % (3/257) | 0/4 |
| openai_whisper-small_216MB | trim+past-audio | de | zero-3s | 1.2 % (3/257) | 0/4 |
| openai_whisper-small_216MB | trim+past-audio | en | clean | 1.1 % (3/281) | 0/4 |
| openai_whisper-small_216MB | trim+past-audio | en | cut-14s | 0.0 % (0/52) | 0/1 |
| openai_whisper-small_216MB | trim+past-audio | en | cut-50% | 4.2 % (6/143) | 2/4 |
| openai_whisper-small_216MB | trim+past-audio | en | cut-70% | 2.0 % (4/199) | 2/4 |
| openai_whisper-small_216MB | trim+past-audio | en | cut-90% | 3.1 % (8/257) | 2/4 |
| openai_whisper-small_216MB | trim+past-audio | en | noisy-3s | 1.1 % (3/281) | 0/4 |
| openai_whisper-small_216MB | trim+past-audio | en | noisy-8s | 1.1 % (3/281) | 0/4 |
| openai_whisper-small_216MB | trim+past-audio | en | quiet-3s | 1.1 % (3/281) | 0/4 |
| openai_whisper-small_216MB | trim+past-audio | en | quiet-8s | 1.1 % (3/281) | 0/4 |
| openai_whisper-small_216MB | trim+past-audio | en | zero-3s | 1.1 % (3/281) | 0/4 |
| openai_whisper-small_216MB | trim+past-audio | es | clean | 0.7 % (2/273) | 0/4 |
| openai_whisper-small_216MB | trim+past-audio | es | cut-14s | 4.8 % (2/42) | 1/1 |
| openai_whisper-small_216MB | trim+past-audio | es | cut-50% | 3.8 % (5/133) | 2/4 |
| openai_whisper-small_216MB | trim+past-audio | es | cut-70% | 2.1 % (4/194) | 1/4 |
| openai_whisper-small_216MB | trim+past-audio | es | cut-90% | 0.8 % (2/251) | 0/4 |
| openai_whisper-small_216MB | trim+past-audio | es | noisy-3s | 1.1 % (3/273) | 0/4 |
| openai_whisper-small_216MB | trim+past-audio | es | noisy-8s | 1.1 % (3/273) | 0/4 |
| openai_whisper-small_216MB | trim+past-audio | es | quiet-3s | 0.7 % (2/273) | 0/4 |
| openai_whisper-small_216MB | trim+past-audio | es | quiet-8s | 0.7 % (2/273) | 0/4 |
| openai_whisper-small_216MB | trim+past-audio | es | zero-3s | 0.7 % (2/273) | 0/4 |
| openai_whisper-small_216MB | trim+past-audio | fr | clean | 4.3 % (12/278) | 0/5 |
| openai_whisper-small_216MB | trim+past-audio | fr | cut-14s | 4.3 % (2/46) | 0/1 |
| openai_whisper-small_216MB | trim+past-audio | fr | cut-50% | 4.5 % (6/132) | 2/5 |
| openai_whisper-small_216MB | trim+past-audio | fr | cut-70% | 7.0 % (13/187) | 3/5 |
| openai_whisper-small_216MB | trim+past-audio | fr | cut-90% | 6.0 % (15/248) | 3/5 |
| openai_whisper-small_216MB | trim+past-audio | fr | noisy-3s | 4.7 % (13/278) | 0/5 |
| openai_whisper-small_216MB | trim+past-audio | fr | noisy-8s | 4.7 % (13/278) | 0/5 |
| openai_whisper-small_216MB | trim+past-audio | fr | quiet-3s | 4.3 % (12/278) | 0/5 |
| openai_whisper-small_216MB | trim+past-audio | fr | quiet-8s | 4.3 % (12/278) | 0/5 |
| openai_whisper-small_216MB | trim+past-audio | fr | zero-3s | 4.3 % (12/278) | 0/5 |
| openai_whisper-small_216MB | trim+past-audio | zh | clean | 25.3 % (101/399) | 0/3 |
| openai_whisper-small_216MB | trim+past-audio | zh | cut-14s | 32.4 % (23/71) | 1/1 |
| openai_whisper-small_216MB | trim+past-audio | zh | cut-50% | 22.7 % (44/194) | 3/3 |
| openai_whisper-small_216MB | trim+past-audio | zh | cut-70% | 21.2 % (59/278) | 1/3 |
| openai_whisper-small_216MB | trim+past-audio | zh | cut-90% | 25.1 % (90/358) | 2/3 |
| openai_whisper-small_216MB | trim+past-audio | zh | noisy-3s | 18.3 % (73/399) | 0/3 |
| openai_whisper-small_216MB | trim+past-audio | zh | noisy-8s | 18.3 % (73/399) | 0/3 |
| openai_whisper-small_216MB | trim+past-audio | zh | quiet-3s | 26.3 % (105/399) | 0/3 |
| openai_whisper-small_216MB | trim+past-audio | zh | quiet-8s | 26.3 % (105/399) | 0/3 |
| openai_whisper-small_216MB | trim+past-audio | zh | zero-3s | 25.3 % (101/399) | 0/3 |

Decodes sent shorter than their clip: 0

| engine | pipeline | tail | clip | inserted after the last spoken word | end of text |
|---|---|---|---|---|---|
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | cut-50% | elevenlabs/fr/fr-02-appointment-numbers.wav | 9h30 | Le rendez-vous est fixé au 14 mars à 9h30. |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | cut-50% | elevenlabs/fr/fr-02-appointment-numbers.wav | 9h30 | Le rendez-vous est fixé au 14 mars à 9h30. |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | cut-70% | elevenlabs/fr/fr-02-appointment-numbers.wav | 9h30 | Le rendez-vous est fixé au 14 mars à 9h30, |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | cut-70% | elevenlabs/fr/fr-02-appointment-numbers.wav | 9h30 | Le rendez-vous est fixé au 14 mars à 9h30, |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | cut-90% | elevenlabs/fr/fr-02-appointment-numbers.wav | 9h30 salle 220 | Le rendez-vous est fixé au 14 mars à 9h30, salle 220. |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | cut-90% | elevenlabs/fr/fr-02-appointment-numbers.wav | 9h30 salle 220 | Le rendez-vous est fixé au 14 mars à 9h30, salle 220. |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | cut-70% | elevenlabs/fr/fr-03-shopping.wav | froide | Pensez à acheter du pain, des tomates et un peu de froide. |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | cut-70% | elevenlabs/fr/fr-03-shopping.wav | froide | Pensez à acheter du pain, des tomates et un peu de froide. |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | cut-90% | elevenlabs/fr/fr-03-shopping.wav | rancin | Pensez à acheter du pain, des tomates et un peu de fromage en rancin. |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | cut-90% | elevenlabs/fr/fr-03-shopping.wav | rancin | Pensez à acheter du pain, des tomates et un peu de fromage en rancin. |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | cut-50% | elevenlabs/en/en-03-train-edinburgh.wav | platt | The train from Edinburgh arrives at Platt |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | cut-50% | elevenlabs/en/en-03-train-edinburgh.wav | platt | The train from Edinburgh arrives at Platt |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | cut-70% | elevenlabs/en/en-03-train-edinburgh.wav | 4 | The train from Edinburgh arrives at platform 4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | cut-70% | elevenlabs/en/en-03-train-edinburgh.wav | 4 | The train from Edinburgh arrives at platform 4 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | cut-90% | elevenlabs/de/de-03-shopping-list.wav | ei | Ich habe gerade die Einkaufsliste aktualisiert. Wir brauchen noch Milch und Ei. |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | cut-90% | elevenlabs/de/de-03-shopping-list.wav | ei | Ich habe gerade die Einkaufsliste aktualisiert. Wir brauchen noch Milch und Ei. |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | cut-70% | elevenlabs/es/es-01-arrive-madrid.wav | mar | Hola, Lucía. Llegaré a Madrid el mar |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | cut-70% | elevenlabs/es/es-01-arrive-madrid.wav | mar | Hola, Lucía. Llegaré a Madrid el mar |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | cut-50% | elevenlabs/es/es-02-invoice-total.wav | 248 | La factura total es de $248. |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | cut-50% | elevenlabs/es/es-02-invoice-total.wav | 248 | La factura total es de $248. |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | cut-70% | elevenlabs/es/es-03-water-plants.wav | esto | No te olvides de regar las plantas mientras esto |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | cut-70% | elevenlabs/es/es-03-water-plants.wav | esto | No te olvides de regar las plantas mientras esto |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | cut-50% | elevenlabs/zh/zh-01-meeting-3pm.wav | 3 點 | 明天下午3點 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | cut-50% | elevenlabs/zh/zh-01-meeting-3pm.wav | 3 點 | 明天下午3點 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | cut-70% | elevenlabs/zh/zh-01-meeting-3pm.wav | 會 議 中 | 明天下午3點,我們在三樓的會議中 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | cut-70% | elevenlabs/zh/zh-01-meeting-3pm.wav | 會 議 中 | 明天下午3點,我們在三樓的會議中 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | cut-90% | elevenlabs/zh/zh-01-meeting-3pm.wav | 開 會 | 明天下午3點,我們在三樓的會議室開會 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | cut-90% | elevenlabs/zh/zh-01-meeting-3pm.wav | 開 會 | 明天下午3點,我們在三樓的會議室開會 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | cut-70% | elevenlabs/fr/fr-long-01-workday-sync-fix.wav | recruti le test |  tests auront tourné sur le téléphone de test. Cet après-midi, j'ai aussi recruti le test. |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | cut-70% | elevenlabs/fr/fr-long-01-workday-sync-fix.wav | recruti le test |  tests auront tourné sur le téléphone de test. Cet après-midi, j'ai aussi recruti le test. |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | cut-90% | elevenlabs/fr/fr-long-01-workday-sync-fix.wav | arrivées | o de jeudi et à trier les retours des testeurs. Il y en a une quinzaine qui sont arrivées. |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | cut-90% | elevenlabs/fr/fr-long-01-workday-sync-fix.wav | arrivées | o de jeudi et à trier les retours des testeurs. Il y en a une quinzaine qui sont arrivées. |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | cut-70% | elevenlabs/en/en-long-01-workday-retry-fix.wav | safe | r that, I spent an hour on the settings screen. The toggle for haptic feedback wasn't safe |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | cut-70% | elevenlabs/en/en-long-01-workday-retry-fix.wav | safe | r that, I spent an hour on the settings screen. The toggle for haptic feedback wasn't safe |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | cut-70% | elevenlabs/de/de-long-01-workday-export-fix.wav | nacht | s Donnerstag eine kurze Beschreibung und ich schätze den Aufwand dann neu. Am späten Nacht |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | cut-70% | elevenlabs/de/de-long-01-workday-export-fix.wav | nacht | s Donnerstag eine kurze Beschreibung und ich schätze den Aufwand dann neu. Am späten Nacht |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | cut-90% | elevenlabs/es/es-long-01-workday-reminders-fix.wav | la mañana | e cerrar todo lo pendiente antes del viernes. Mañana quiero dedicar la mañana a la mañana. |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | cut-90% | elevenlabs/es/es-long-01-workday-reminders-fix.wav | la mañana | e cerrar todo lo pendiente antes del viernes. Mañana quiero dedicar la mañana a la mañana. |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim | cut-70% | elevenlabs/zh/zh-long-01-workday-upload-fix.wav | 下 | 推上去的,现在已经在Github上开了合并请求,等小李帮我看一下。 接下来我还整理了一下设置页面的文字有几个说明写的太长在小屏幕的手机上会被截断我都改短了另外下一个测试版本计划在下 |
| openai_whisper-large-v3-v20240930_turbo_632MB | trim+past-audio | cut-70% | elevenlabs/zh/zh-long-01-workday-upload-fix.wav | 下 | 推上去的,现在已经在Github上开了合并请求,等小李帮我看一下。 接下来我还整理了一下设置页面的文字有几个说明写的太长在小屏幕的手机上会被截断我都改短了另外下一个测试版本计划在下 |
| openai_whisper-small_216MB | trim | cut-50% | elevenlabs/fr/fr-02-appointment-numbers.wav | 9h00 | Le rendez-vous est fixé au 14 mars à 9h00. |
| openai_whisper-small_216MB | trim+past-audio | cut-50% | elevenlabs/fr/fr-02-appointment-numbers.wav | 9h00 | Le rendez-vous est fixé au 14 mars à 9h00. |
| openai_whisper-small_216MB | trim | cut-70% | elevenlabs/fr/fr-02-appointment-numbers.wav | 9h30 | Le rendez-vous est fixé au 14 mars à 9h30. |
| openai_whisper-small_216MB | trim+past-audio | cut-70% | elevenlabs/fr/fr-02-appointment-numbers.wav | 9h30 | Le rendez-vous est fixé au 14 mars à 9h30. |
| openai_whisper-small_216MB | trim | cut-90% | elevenlabs/fr/fr-02-appointment-numbers.wav | 9h30 salle 205 | Le rendez-vous est fixé au 14 mars à 9h30, salle 205. |
| openai_whisper-small_216MB | trim+past-audio | cut-90% | elevenlabs/fr/fr-02-appointment-numbers.wav | 9h30 salle 205 | Le rendez-vous est fixé au 14 mars à 9h30, salle 205. |
| openai_whisper-small_216MB | trim | cut-70% | elevenlabs/fr/fr-03-shopping.wav | frappes | Pensez à acheter du pain, des tomates et un peu de frappes. |
| openai_whisper-small_216MB | trim+past-audio | cut-70% | elevenlabs/fr/fr-03-shopping.wav | frappes | Pensez à acheter du pain, des tomates et un peu de frappes. |
| openai_whisper-small_216MB | trim | cut-90% | elevenlabs/fr/fr-03-shopping.wav | rand | Tensez à acheter du pain, des tomates et un peu de fromage en rand. |
| openai_whisper-small_216MB | trim+past-audio | cut-90% | elevenlabs/fr/fr-03-shopping.wav | rand | Tensez à acheter du pain, des tomates et un peu de fromage en rand. |
| openai_whisper-small_216MB | trim | cut-50% | elevenlabs/fr/fr-04-question-mark.wav | à | Pouvez-vous m'envoyer le compte rendu de la réunion à... |
| openai_whisper-small_216MB | trim+past-audio | cut-50% | elevenlabs/fr/fr-04-question-mark.wav | à | Pouvez-vous m'envoyer le compte rendu de la réunion à... |
| openai_whisper-small_216MB | trim | cut-50% | elevenlabs/en/en-03-train-edinburgh.wav | pla | The train from Edinburgh arrives at Pla... |
| openai_whisper-small_216MB | trim+past-audio | cut-50% | elevenlabs/en/en-03-train-edinburgh.wav | pla | The train from Edinburgh arrives at Pla... |
| openai_whisper-small_216MB | trim | cut-70% | elevenlabs/en/en-03-train-edinburgh.wav | 4 | The train from Edinburgh arrives at platform 4. |
| openai_whisper-small_216MB | trim+past-audio | cut-70% | elevenlabs/en/en-03-train-edinburgh.wav | 4 | The train from Edinburgh arrives at platform 4. |
| openai_whisper-small_216MB | trim | cut-90% | elevenlabs/en/en-03-train-edinburgh.wav | 9 | The train from Edinburgh arrives at Platform 4 around 9. |
| openai_whisper-small_216MB | trim+past-audio | cut-90% | elevenlabs/en/en-03-train-edinburgh.wav | 9 | The train from Edinburgh arrives at Platform 4 around 9. |
| openai_whisper-small_216MB | trim | cut-50% | elevenlabs/de/de-01-documents-friday.wav | video machen | Kannst du mir bitte die Unterlagen für das Video machen? |
| openai_whisper-small_216MB | trim+past-audio | cut-50% | elevenlabs/de/de-01-documents-friday.wav | video machen | Kannst du mir bitte die Unterlagen für das Video machen? |
| openai_whisper-small_216MB | trim | cut-70% | elevenlabs/de/de-01-documents-friday.wav | bitte | Kannst du mir bitte die Unterlagen für das Projekt bitte... |
| openai_whisper-small_216MB | trim+past-audio | cut-70% | elevenlabs/de/de-01-documents-friday.wav | bitte | Kannst du mir bitte die Unterlagen für das Projekt bitte... |
| openai_whisper-small_216MB | trim | cut-90% | elevenlabs/de/de-03-shopping-list.wav | eingang | Ich habe gerade die Einkaufsliste aktualisiert. Wir brauchen noch Milch und Eingang. |
| openai_whisper-small_216MB | trim+past-audio | cut-90% | elevenlabs/de/de-03-shopping-list.wav | eingang | Ich habe gerade die Einkaufsliste aktualisiert. Wir brauchen noch Milch und Eingang. |
| openai_whisper-small_216MB | trim | cut-70% | elevenlabs/es/es-01-arrive-madrid.wav | mar | Hola Lucia, llegaré a Madrid el mar... |
| openai_whisper-small_216MB | trim+past-audio | cut-70% | elevenlabs/es/es-01-arrive-madrid.wav | mar | Hola Lucia, llegaré a Madrid el mar... |
| openai_whisper-small_216MB | trim | cut-50% | elevenlabs/es/es-02-invoice-total.wav | 240 | La factura total es de 240... |
| openai_whisper-small_216MB | trim+past-audio | cut-50% | elevenlabs/es/es-02-invoice-total.wav | 240 | La factura total es de 240... |
| openai_whisper-small_216MB | trim | cut-50% | elevenlabs/es/es-03-water-plants.wav | planas | No te olvides de regar las planas. |
| openai_whisper-small_216MB | trim+past-audio | cut-50% | elevenlabs/es/es-03-water-plants.wav | planas | No te olvides de regar las planas. |
| openai_whisper-small_216MB | trim | cut-50% | elevenlabs/zh/zh-01-meeting-3pm.wav | 點 | 明天下午三點 |
| openai_whisper-small_216MB | trim+past-audio | cut-50% | elevenlabs/zh/zh-01-meeting-3pm.wav | 點 | 明天下午三點 |
| openai_whisper-small_216MB | trim | cut-70% | elevenlabs/zh/zh-01-meeting-3pm.wav | 會 議 中 間 | 明天下午三點,我們在三樓的會議中間 |
| openai_whisper-small_216MB | trim+past-audio | cut-70% | elevenlabs/zh/zh-01-meeting-3pm.wav | 會 議 中 間 | 明天下午三點,我們在三樓的會議中間 |
| openai_whisper-small_216MB | trim | cut-90% | elevenlabs/zh/zh-01-meeting-3pm.wav | 開 會 | 明天下午三點,我們在三樓的會議室開會。 |
| openai_whisper-small_216MB | trim+past-audio | cut-90% | elevenlabs/zh/zh-01-meeting-3pm.wav | 開 會 | 明天下午三點,我們在三樓的會議室開會。 |
| openai_whisper-small_216MB | trim | cut-50% | elevenlabs/zh/zh-02-send-file.wav | 我 | 请帮我把这份文件发给我 |
| openai_whisper-small_216MB | trim+past-audio | cut-50% | elevenlabs/zh/zh-02-send-file.wav | 我 | 请帮我把这份文件发给我 |
| openai_whisper-small_216MB | trim | cut-70% | elevenlabs/fr/fr-long-01-workday-sync-fix.wav | réussi à remettre un test | ont tourné sur le téléphone de test. Cet après-midi, j'ai aussi réussi à remettre un test. |
| openai_whisper-small_216MB | trim+past-audio | cut-70% | elevenlabs/fr/fr-long-01-workday-sync-fix.wav | réussi à remettre un test | ont tourné sur le téléphone de test. Cet après-midi, j'ai aussi réussi à remettre un test. |
| openai_whisper-small_216MB | trim | cut-90% | elevenlabs/fr/fr-long-01-workday-sync-fix.wav | arrivées | mo de Judy et à trier les retours des testeurs. Il y en a une quinzaine qui sont arrivées. |
| openai_whisper-small_216MB | trim+past-audio | cut-90% | elevenlabs/fr/fr-long-01-workday-sync-fix.wav | arrivées | mo de Judy et à trier les retours des testeurs. Il y en a une quinzaine qui sont arrivées. |
| openai_whisper-small_216MB | trim | cut-50% | elevenlabs/en/en-long-01-workday-retry-fix.wav | up the new one | ut, and they all pass locally. I pushed the branch around three and opened up the new one. |
| openai_whisper-small_216MB | trim+past-audio | cut-50% | elevenlabs/en/en-long-01-workday-retry-fix.wav | up the new one | ut, and they all pass locally. I pushed the branch around three and opened up the new one. |
| openai_whisper-small_216MB | trim | cut-70% | elevenlabs/en/en-long-01-workday-retry-fix.wav | saved |  that, I spent an hour on the setting screen. The toggle for haptic feedback wasn't saved. |
| openai_whisper-small_216MB | trim+past-audio | cut-70% | elevenlabs/en/en-long-01-workday-retry-fix.wav | saved |  that, I spent an hour on the setting screen. The toggle for haptic feedback wasn't saved. |
| openai_whisper-small_216MB | trim | cut-90% | elevenlabs/en/en-long-01-workday-retry-fix.wav | of the keyboard extension | o the limit again. And in the afternoon, I'll write the release of the keyboard extension. |
| openai_whisper-small_216MB | trim+past-audio | cut-90% | elevenlabs/en/en-long-01-workday-retry-fix.wav | of the keyboard extension | o the limit again. And in the afternoon, I'll write the release of the keyboard extension. |
| openai_whisper-small_216MB | trim | cut-50% | elevenlabs/de/de-long-01-workday-export-fix.wav | vorlage |  Durchsicht leichter wird. Danach habe ich mit Anna über das neue Feature für die Vorlage. |
| openai_whisper-small_216MB | trim+past-audio | cut-50% | elevenlabs/de/de-long-01-workday-export-fix.wav | vorlage |  Durchsicht leichter wird. Danach habe ich mit Anna über das neue Feature für die Vorlage. |
| openai_whisper-small_216MB | trim | cut-70% | elevenlabs/de/de-long-01-workday-export-fix.wav | nacht |  Donnerstag eine kurze Beschreibung und ich schätze den Aufwand dann neu. Am späten Nacht! |
| openai_whisper-small_216MB | trim+past-audio | cut-70% | elevenlabs/de/de-long-01-workday-export-fix.wav | nacht |  Donnerstag eine kurze Beschreibung und ich schätze den Aufwand dann neu. Am späten Nacht! |
| openai_whisper-small_216MB | trim | cut-90% | elevenlabs/de/de-long-01-workday-export-fix.wav | ich noch mal ein bisschen mehr auf dem gerät | nem älteren Gerät und wenn alles passt, kann ich noch mal ein bisschen mehr auf dem Gerät. |
| openai_whisper-small_216MB | trim+past-audio | cut-90% | elevenlabs/de/de-long-01-workday-export-fix.wav | ich noch mal ein bisschen mehr auf dem gerät | nem älteren Gerät und wenn alles passt, kann ich noch mal ein bisschen mehr auf dem Gerät. |
| openai_whisper-small_216MB | trim | cut-14s | elevenlabs/es/es-long-01-workday-reminders-fix.wav | diferente | suario cambia de zona horaria, los recordatorios se programaban con una hora de diferente. |
| openai_whisper-small_216MB | trim+past-audio | cut-14s | elevenlabs/es/es-long-01-workday-reminders-fix.wav | diferente | suario cambia de zona horaria, los recordatorios se programaban con una hora de diferente. |
| openai_whisper-small_216MB | trim | cut-50% | elevenlabs/zh/zh-long-01-workday-upload-fix.wav | 再 加 上 一 个 小 码 | 和其他的改动分开, 这样比较方便检查。修复本身不复杂,大概改了三十行代码, 另外我还加了四个测试。下午我把代码提交了, 最后一个commit是三点左右推上去的,现在再加上一个小码. |
| openai_whisper-small_216MB | trim+past-audio | cut-50% | elevenlabs/zh/zh-long-01-workday-upload-fix.wav | 再 加 上 一 个 小 码 | 和其他的改动分开, 这样比较方便检查。修复本身不复杂,大概改了三十行代码, 另外我还加了四个测试。下午我把代码提交了, 最后一个commit是三点左右推上去的,现在再加上一个小码. |
| openai_whisper-small_216MB | trim | cut-90% | elevenlabs/zh/zh-long-01-workday-upload-fix.wav | 覆 測 試 | 另外下一個測試版本計畫在15號發布所以這週五之前要把剩下的問題都處理完明天上午我打算在一台舊手機上再測試一次看它速度有沒有問題下午要開週會我會把這週的情況匯總一下晚上我還會回覆測試 |
| openai_whisper-small_216MB | trim+past-audio | cut-90% | elevenlabs/zh/zh-long-01-workday-upload-fix.wav | 覆 測 試 | 另外下一個測試版本計畫在15號發布所以這週五之前要把剩下的問題都處理完明天上午我打算在一台舊手機上再測試一次看它速度有沒有問題下午要開週會我會把這週的情況匯總一下晚上我還會回覆測試 |
| openai_whisper-small_216MB | trim | cut-14s | elevenlabs/zh/zh-long-01-workday-upload-fix.wav | 麼 | 大家好,我簡單說一下今天的進展上午我主要在處理上週用戶反饋的那個bug問題是在網路不穩定的時候上傳會失敗但是界面上一直顯示正在上傳用戶不知道發生了什麼 |
| openai_whisper-small_216MB | trim+past-audio | cut-14s | elevenlabs/zh/zh-long-01-workday-upload-fix.wav | 麼 | 大家好,我簡單說一下今天的進展上午我主要在處理上週用戶反饋的那個bug問題是在網路不穩定的時候上傳會失敗但是界面上一直顯示正在上傳用戶不知道發生了什麼 |
