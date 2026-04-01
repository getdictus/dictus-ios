---
status: complete
phase: 17-bug-fixes
source: [17-01-SUMMARY.md, 17-02-SUMMARY.md]
started: 2026-03-27T22:00:00Z
updated: 2026-03-27T22:30:00Z
---

## Current Test

[testing complete]

## Tests

### 1. DI ne reste plus bloquée sur REC après stop
expected: Lance une dictée depuis le clavier. La Dynamic Island affiche l'état REC. Arrête l'enregistrement. La DI passe à transcription puis standby. Elle ne reste jamais bloquée sur "REC" après l'arrêt.
result: pass

### 2. DI récupère après un cancel
expected: Lance une dictée puis annule-la (swipe down ou tap cancel). La Dynamic Island revient à l'état standby. Elle ne reste pas bloquée sur "REC".
result: pass

### 3. Chaîne rapide stop + re-record
expected: Lance une dictée, arrête-la, puis relance immédiatement une autre dictée avant que la première finisse de transcrire. La Dynamic Island transite correctement entre les états sans se bloquer. Le second enregistrement fonctionne normalement.
result: pass

### 4. Export logs rapide
expected: Va dans Réglages > Exporter les logs. Tape export. Le spinner apparaît brièvement (moins de 2 secondes) et la share sheet s'ouvre avec le fichier de logs. Pas d'attente longue.
result: pass

### 5. Logs exportés = 7 derniers jours uniquement
expected: Après export des logs, ouvre le fichier. Il ne devrait pas contenir d'entrées de plus de 7 jours. Les entrées récentes de la session d'aujourd'hui sont présentes avec timestamps.
result: pass

### 6. Durée d'export dans les logs
expected: Après export, vérifie les dernières lignes du fichier exporté. Il devrait y avoir une entrée "logExportCompleted" montrant la durée en ms et la taille en bytes.
result: pass

## Summary

total: 6
passed: 6
issues: 0
pending: 0
skipped: 0

## Gaps

[none yet]
