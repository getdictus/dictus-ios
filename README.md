<p align="center">
  <img src="assets/brand/appicon-light.svg" alt="Dictus" width="120" height="120" />
</p>

<h1 align="center">Dictus</h1>

<p align="center">
  Free, open-source iOS keyboard for voice dictation — 100% on-device.
</p>

<p align="center">
  <a href="https://github.com/getdictus/dictus-ios/actions/workflows/ci.yml"><img src="https://github.com/getdictus/dictus-ios/actions/workflows/ci.yml/badge.svg?branch=develop" alt="CI" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT" /></a>
  <img src="https://img.shields.io/badge/platform-iOS%2017%2B-lightgrey.svg" alt="Platform: iOS 17+" />
  <img src="https://img.shields.io/badge/swift-5.9%2B-orange.svg" alt="Swift 5.9+" />
</p>

---

Dictus is a free, open-source iOS keyboard that adds voice dictation to any app. All speech recognition runs on-device via [WhisperKit](https://github.com/argmaxinc/WhisperKit) (Apple CoreML) — no server, no account, no subscription. French-first, with English support.

## Features

- Custom iOS keyboard with full AZERTY / QWERTY layout
- On-device speech recognition powered by WhisperKit (Whisper via CoreML)
- Multiple model sizes (tiny, base, small) to balance speed and accuracy
- Parakeet engine option for alternative transcription
- Works in any app via the keyboard extension
- Cold start audio bridge for seamless dictation from keyboard
- Sound feedback for recording start / stop
- iOS 26 Liquid Glass design

## Requirements

- iOS 17.0+
- iPhone 12 or later (A14 Bionic+)
- Xcode 16+
- ~100-500 MB storage for speech models

## Getting Started

```bash
git clone https://github.com/getdictus/dictus-ios.git
cd dictus
open Dictus.xcodeproj
```

1. Select the **DictusApp** target and pick your device.
2. Build and run (`Cmd + R`).
3. Follow the onboarding flow to download a speech model.
4. Enable the Dictus keyboard: **Settings > General > Keyboard > Keyboards > Add New Keyboard > Dictus**.
5. Allow **Full Access** (required for microphone).

See [DEVELOPMENT.md](DEVELOPMENT.md) for the full development guide.

## Architecture

Dictus is organized into three Xcode targets:

| Target | Role |
|---|---|
| **DictusApp** | Main app — onboarding, settings, model manager |
| **DictusKeyboard** | Keyboard extension — custom keyboard + dictation trigger |
| **DictusCore** | Shared framework — App Group storage, models, preferences |

The app and the keyboard extension communicate through an **App Group** (`group.solutions.pivi.dictus`). WhisperKit runs inside DictusApp (the keyboard extension has a ~50 MB memory limit), and an audio bridge handles cold start scenarios so dictation works seamlessly from the keyboard.

## Beta Testing

Join the beta via TestFlight: **[Install Dictus Beta](https://testflight.apple.com/join/b55atKYX)**

> **Requirements:** iPhone 12 or later, iOS 17.0+

**How to install:**
1. Tap the link above on your iPhone (or scan it with your camera)
2. Install TestFlight from the App Store if you don't have it
3. Open Dictus and follow the onboarding to download a speech model
4. Enable the keyboard: **Settings > General > Keyboard > Keyboards > Add New Keyboard > Dictus**
5. Allow **Full Access** when prompted (required for microphone access)

**Give feedback:**
- Shake your device in Dictus to send feedback via TestFlight
- Or open an issue on [GitHub](https://github.com/getdictus/dictus-ios/issues)

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Privacy

Dictus collects no user data. All speech processing happens on your device. See our [Privacy Policy](https://www.getdictus.com/en/privacy).

## License

MIT — see [LICENSE](LICENSE) for details.

## Acknowledgments

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) by argmaxinc — on-device Whisper inference
- [Parakeet](https://github.com/slingshot-ai/captions-ios) by slingshot-ai — alternative STT engine
