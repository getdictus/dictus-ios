# App Store Review Checklist — Dictus v1.2

## Microphone (NSMicrophoneUsageDescription)

- **Usage**: Speech-to-text transcription only
- **Processing**: 100% on-device via WhisperKit (Apple CoreML)
- **No audio is sent to any server** — no network requests at any point
- **Description string**: "Dictus needs microphone access to transcribe your voice."

## Full Access (Keyboard Extension)

- **Required solely for microphone access** from keyboard extension
- iOS blocks microphone in keyboard extensions without Full Access
- **Dictus does NOT access**: network, clipboard content, keystroke data, contacts, location, photos
- `RequestsOpenAccess = true` in DictusKeyboard/Info.plist

## Background Audio (UIBackgroundModes: audio)

- Used to keep the audio session alive during cold start dictation flow
- When iOS kills the app and user taps mic from keyboard, the app launches and starts recording
- The audio session must stay active while user switches back to the keyboard
- **No audio plays in the background** — purely for AVAudioSession continuity

## URL Schemes (LSApplicationQueriesSchemes)

- Used to detect the source app for auto-return after cold start dictation
- Apps queried: WhatsApp, SMS, Telegram, Messenger, Signal, Slack, Discord, Teams, Instagram, Notes
- **No data is sent** to these apps — only `canOpenURL()` check for return navigation

## Privacy Policy

- **URL**: https://www.getdictus.com/en/privacy
- Bilingual: French + English
- Content: detailed and transparent, covers Full Access justification

## Data Collection — App Store Nutrition Label

**"Data Not Collected"**

- No analytics
- No tracking
- No third-party SDKs collecting data
- No advertising
- No user accounts

## Privacy Manifest (PrivacyInfo.xcprivacy)

- Both targets (DictusApp + DictusKeyboard) include Privacy Manifest
- `NSPrivacyTracking`: false
- `NSPrivacyCollectedDataTypes`: empty (Data Not Collected)
- `NSPrivacyAccessedAPITypes`: UserDefaults with reason CA92.1 (App Group container)

## Reviewer Test Instructions

```
Dictus is an iOS keyboard with 100% on-device voice dictation.

Key points for review:

1. MICROPHONE
   The app uses the microphone for speech-to-text transcription only.
   All processing happens on-device via WhisperKit (Apple CoreML).
   No audio is sent to any server.

2. FULL ACCESS (keyboard extension)
   Full Access is required solely for microphone access from the
   keyboard extension. The app does not access the network, clipboard
   content, or keystroke data.

3. BACKGROUND AUDIO
   UIBackgroundModes:audio is used to keep the audio session alive
   when the user switches from the app back to the keyboard during
   cold start dictation. No audio plays in the background.

4. URL SCHEMES (LSApplicationQueriesSchemes)
   Used to detect the source app for auto-return after cold start
   dictation (e.g., returning to WhatsApp after dictating).

5. DATA COLLECTION
   Dictus collects no user data. Privacy Nutrition Label: "Data Not Collected".

To test dictation:
1. Install app > Complete onboarding > Download a model
2. Open any text field (e.g., Notes)
3. Switch to Dictus keyboard (globe button)
4. Tap the microphone button > Speak > Text appears
```
