# Phase 22 Plan 02: Submission Preparation

All texts below are ready to copy-paste into App Store Connect.

---

## Full Access Justification

> Paste in: App Store Connect > TestFlight > Test Information > Full Access Justification

```
Dictus is an on-device speech-to-text keyboard. Full Access is required to access the device microphone for voice dictation. All speech recognition runs locally on-device via Apple CoreML (WhisperKit). No keystroke data, audio, or transcription is transmitted off-device. The keyboard provides full typing functionality without Full Access; only the dictation feature requires it.
```

---

## App Store Connect Description -- French

> Paste in: App Store Connect > TestFlight > Test Information > Beta App Description (French localization)

```
Dictus est un clavier iOS gratuit et open source qui ajoute la dictee vocale a toutes vos applications. La reconnaissance vocale fonctionne entierement sur votre appareil grace a WhisperKit (Apple CoreML) -- pas de serveur, pas de compte, pas d'abonnement.

Fonctionnalites :
- Clavier AZERTY / QWERTY complet
- Dictee vocale hors ligne (modeles tiny, base, small)
- Moteur Parakeet en alternative
- Suggestions et correction automatique
- Design iOS 26 Liquid Glass

Version beta 1.3 : nouveau clavier UIKit avec zero zones mortes, feedback haptique, sons de touches, et curseur trackpad via la barre d'espace.
```

---

## App Store Connect Description -- English

> Paste in: App Store Connect > TestFlight > Test Information > Beta App Description (English)

```
Dictus is a free, open-source iOS keyboard that adds voice dictation to any app. Speech recognition runs entirely on-device via WhisperKit (Apple CoreML) -- no server, no account, no subscription.

Features:
- Full AZERTY / QWERTY keyboard layout
- Offline voice dictation (tiny, base, small models)
- Parakeet engine alternative
- Suggestions and autocorrect
- iOS 26 Liquid Glass design

Beta 1.3: New UIKit keyboard with zero dead zones, haptic feedback, key sounds, and spacebar trackpad cursor.
```

---

## Xcode Archive + Upload Instructions

1. In Xcode, select the **"DictusApp"** scheme
2. Set destination to **"Any iOS Device (arm64)"** (not a simulator)
3. **Product > Archive** (Cmd+Shift+B won't work -- must use Archive)
4. Wait for build to complete -- Organizer window opens automatically
5. Select the new archive in the list
6. Click **"Distribute App"**
7. Choose **"App Store Connect" > "Upload"**
8. Follow signing prompts (automatic signing should resolve)
9. Wait for upload to complete
10. Go to **App Store Connect** (appstoreconnect.apple.com)
11. Navigate to **"My Apps" > "Dictus" > "TestFlight"**
12. Wait 5-15 minutes for the build to finish processing
13. Under **"External Testing"**, click **(+)** to create a group named **"Public Beta"**
14. Add the processed build to this group
15. Fill in **Test Information:**
    - Beta App Description: paste the English description above
    - Feedback Email: your Apple ID email
    - Full Access Justification: paste the justification text above
16. Click **"Submit for Beta App Review"** (review takes 24-48 hours)
17. After approval, go to the **"Public Beta"** group > **Testers** tab
18. Click **"Create Public Link"**
19. Select **"Open to Anyone"**
20. Set Tester Limit to **250**
21. Copy the public TestFlight URL (format: `https://testflight.apple.com/join/XXXXX`)
22. Share this URL with Claude for README update (Task 3)
