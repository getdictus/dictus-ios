# Politique de confidentialité — Dictus

*Dernière mise à jour : 14 novembre 2026*

## Résumé

Dictus est un clavier iOS de dictée vocale **100 % hors ligne**. Aucune donnée vocale, aucun texte dicté et aucune frappe ne quittent votre appareil. Jamais.

## Ce que fait Dictus

Dictus convertit votre voix en texte directement sur votre iPhone grâce à WhisperKit (Apple CoreML). Tout le traitement se fait localement, sans connexion internet.

## Pourquoi Dictus demande l'Accès complet

L'extension clavier iOS nécessite l'autorisation « Accès complet » (Full Access) **uniquement** pour accéder au microphone depuis le clavier. Sans cette autorisation, iOS interdit l'accès au micro dans une extension clavier.

Dictus n'utilise **aucune** des autres fonctionnalités rendues possibles par l'Accès complet :
- **Pas d'accès réseau** — aucune requête HTTP, aucun envoi de données
- **Pas de lecture du presse-papiers** — le contenu copié reste privé
- **Pas d'enregistrement des frappes** — seul le texte dicté est inséré
- **Pas d'accès aux contacts, à la localisation ou aux photos**

## Données stockées localement

Les seules données enregistrées sur votre appareil sont :
- **Préférences utilisateur** — langue, modèle sélectionné, réglages (via App Group UserDefaults)
- **Fichiers de modèles** — modèles de reconnaissance vocale téléchargés (WhisperKit CoreML)
- **Journaux de débogage** — logs techniques pour diagnostiquer les problèmes (aucun contenu de transcription). Ils nomment l'application depuis laquelle une dictée a été lancée — par exemple Messages ou WhatsApp — jamais ce qui y a été dicté
- **Journal de diagnostic** — pour chaque dictée, avec ou sans Dictus Pro : le texte produit par la reconnaissance vocale, le texte après votre vocabulaire personnalisé, le texte corrigé, et des mesures techniques (langue, modèle, durées de traitement, résultat). Il sert à diagnostiquer la qualité de la transcription. Il est enregistré dans le conteneur partagé de l'app (App Group), sur votre appareil uniquement. L'app Dictus en efface les entrées de plus de 7 jours à chaque ouverture et chaque fois que vous y revenez (une entrée peut donc rester au-delà de 7 jours tant que l'app n'est pas ouverte) ; l'écran de diagnostic et son export ne montrent jamais que les 7 derniers jours. Vous pouvez le vider à tout moment depuis Réglages > Transcription > Effacer l'historique, qui efface aussi l'historique de dictée, ou depuis l'écran de diagnostic. Il n'est visible et exportable que depuis cet écran masqué, et n'est jamais envoyé
- **Historique de dictée** (Dictus Pro) — vos 200 dernières transcriptions, texte uniquement, jamais l'audio. Rien n'est enregistré sans Dictus Pro actif (essai, abonnement ou achat à vie), et vous pouvez l'effacer à tout moment depuis Réglages > Transcription > Effacer l'historique, même après la fin de Dictus Pro. Ce bouton vide aussi le journal de diagnostic

Ces données ne quittent jamais votre appareil sauf si vous choisissez explicitement d'exporter les logs de débogage ou le journal de diagnostic.

## Collecte de données

**Dictus ne collecte aucune donnée.**

- Pas d'analytiques
- Pas de suivi (tracking)
- Pas de SDK tiers collectant des données
- Pas de publicité

L'étiquette de confidentialité App Store de Dictus est : **« Données non collectées »**.

## Sécurité

Toutes les données restent sur votre appareil. Il n'y a pas de serveur Dictus, pas de base de données cloud, pas de compte utilisateur.

## Contact

Pour toute question relative à la confidentialité :
**pierre@pivi.solutions**

---

# Privacy Policy — Dictus

*Last updated: November 14, 2026*

## Summary

Dictus is an iOS voice dictation keyboard that works **100% offline**. No voice data, no transcribed text, and no keystrokes ever leave your device. Period.

## What Dictus does

Dictus converts your voice to text directly on your iPhone using WhisperKit (Apple CoreML). All processing happens locally, with no internet connection required.

## Why Dictus requests Full Access

The iOS keyboard extension requires "Full Access" permission **solely** to access the microphone from the keyboard. Without this permission, iOS blocks microphone access in keyboard extensions.

Dictus does **not** use any of the other capabilities that Full Access enables:
- **No network access** — no HTTP requests, no data transmission
- **No clipboard reading** — your copied content stays private
- **No keystroke logging** — only dictated text is inserted
- **No access to contacts, location, or photos**

## Data stored locally

The only data saved on your device:
- **User preferences** — language, selected model, settings (via App Group UserDefaults)
- **Model files** — downloaded speech recognition models (WhisperKit CoreML)
- **Debug logs** — technical logs for diagnosing issues (no transcription content). They name the app a dictation was started from — Messages or WhatsApp, for instance — never what was dictated into it
- **Diagnostic journal** — for every dictation, with or without Dictus Pro: the text produced by speech recognition, the text after your custom vocabulary, the polished text, and technical measurements (language, model, processing times, outcome). It is used to diagnose transcription quality. It is stored in the app's shared container (App Group), on your device only. The Dictus app removes entries older than 7 days each time it opens and each time you return to it (so an entry can stay past 7 days while the app is not opened); the diagnostic screen and its export only ever show the last 7 days. You can empty it at any time from Settings > Transcription > Clear history, which also erases the dictation history, or from the diagnostic screen. It is visible and exportable only from that hidden screen, and never sent
- **Dictation history** (Dictus Pro) — your last 200 transcriptions, text only, never the audio. Nothing is stored without active Dictus Pro (trial, subscription or lifetime purchase), and you can erase it at any time from Settings > Transcription > Clear history, including after Dictus Pro ends. That button empties the diagnostic journal too

This data never leaves your device unless you explicitly choose to export the debug logs or the diagnostic journal.

## Data collection

**Dictus collects no data.**

- No analytics
- No tracking
- No third-party SDKs collecting data
- No advertising

Dictus's App Store privacy nutrition label is: **"Data Not Collected"**.

## Security

All data stays on your device. There is no Dictus server, no cloud database, no user account.

## Contact

For any privacy-related questions:
**pierre@pivi.solutions**
