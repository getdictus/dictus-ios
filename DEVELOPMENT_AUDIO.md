# Architecture Audio — Dictus

Guide technique du pipeline audio de Dictus : capture, transcription, et comment ajouter un nouveau moteur STT.

## Vue d'ensemble

```
┌─────────────────────┐     Darwin notif      ┌─────────────────────────┐
│  DictusKeyboard     │ ──────────────────────>│  DictationCoordinator   │
│  (extension clavier)│ <──────────────────────│  (orchestrateur)        │
│                     │     App Group (status,  │                         │
│                     │     waveform, result)   │  ┌───────────────────┐  │
└─────────────────────┘                        │  │ UnifiedAudioEngine│  │
                                               │  │ (AVAudioEngine)   │  │
                                               │  └───────────────────┘  │
                                               │  ┌───────────────────┐  │
                                               │  │TranscriptionService│ │
                                               │  │ (routeur STT)     │  │
                                               │  └───────┬───────────┘  │
                                               └──────────┼──────────────┘
                                                          │
                                          ┌───────────────┼───────────────┐
                                          │               │               │
                                    ┌─────▼─────┐  ┌─────▼─────┐  ┌─────▼─────┐
                                    │WhisperKit │  │ Parakeet  │  │  Future   │
                                    │Engine     │  │ Engine    │  │  Engine   │
                                    └───────────┘  └───────────┘  └───────────┘
```

## Les 4 fichiers du pipeline

| Fichier | Rôle | Dépendances |
|---------|------|-------------|
| `UnifiedAudioEngine.swift` | Capture audio (AVAudioEngine natif) | AVFoundation, DictusCore |
| `TranscriptionService.swift` | Routage STT + post-processing | WhisperKit, DictusCore |
| `SpeechModelProtocol.swift` | Protocol + WhisperKitEngine adapter | WhisperKit |
| `ParakeetEngine.swift` | Adapter Parakeet/FluidAudio | FluidAudio |

### UnifiedAudioEngine — La capture audio

**Localisation** : `DictusApp/Audio/UnifiedAudioEngine.swift`

Moteur audio unique basé sur `AVAudioEngine` natif d'Apple. Zéro dépendance vers WhisperKit ou tout autre SDK de transcription.

**Pourquoi natif ?** La transcription (WhisperKit, Parakeet) accepte un simple `[Float]` en 16kHz mono via `transcribe(audioArray:)`. Pas besoin de l'AudioProcessor de WhisperKit pour capturer — un AVAudioEngine standard fait le même travail en ~100ms de démarrage.

#### Pipeline audio

```
Micro (48kHz stéréo)
  → AVAudioEngine.inputNode (hardware format)
  → installTap(onBus: 0, bufferSize: 4096)
  → AVAudioConverter (48kHz → 16kHz mono Float32)
  → processBuffer() : calcul RMS energy + sample gating
  → audioSamples: [Float]  (accumulé seulement si isRecording=true)
```

#### États du moteur

```
                  warmUp()              startRecording()
    STOPPED ──────────────> IDLE ─────────────────────> RECORDING
       ▲                     │                              │
       │                     │ (engine tourne,              │ (engine tourne,
       │                     │  samples ignorés,            │  samples accumulés,
       │                     │  heartbeat actif)            │  waveform envoyé)
       │                     │                              │
       │    deactivateSession()         collectSamples()    │
       └─────────────────────┴<─────────────────────────────┘
                                    (engine reste vivant)
```

- **STOPPED** : `engine.isRunning == false`. Prochain enregistrement = cold start.
- **IDLE** : Engine tourne (maintient l'app en background via `UIBackgroundModes:audio`). Les buffers audio sont traités (heartbeat) mais les samples sont ignorés (`isRecordingFlag == false`).
- **RECORDING** : `isRecording == true`. Les samples s'accumulent dans `audioSamples`.

#### Sample gating (fix du bug #38)

Le problème : quand l'engine tourne en idle entre deux enregistrements, les samples audio s'accumulaient indéfiniment (jusqu'à 64M samples = ~1h d'audio inutile en mémoire).

La solution : `isRecordingFlag` est lu depuis l'audio thread dans `processBuffer()`. Quand `false`, les samples sont ignorés. Seuls le heartbeat et l'energy (pour maintenir le background) continuent.

```swift
// Dans processBuffer(), sur l'audio thread :
DispatchQueue.main.async { [weak self] in
    guard let self else { return }
    guard self.isRecording else { return }  // ← GATE
    self.audioSamples.append(contentsOf: samples)
}
```

#### API publique

```swift
// Session & permissions
func configureAudioSession() throws      // .playAndRecord + haptics
func ensureMicrophonePermission() async throws -> Bool

// Cycle de vie
func warmUp() throws                     // démarre en mode idle
func startRecording() throws             // purge + recording (démarre l'engine si besoin)
func collectSamples() -> [Float]         // retourne samples, GARDE l'engine
func stopEngine() -> [Float]             // retourne samples, STOPPE l'engine
func deactivateSession()                 // stoppe + désactive AVAudioSession

// State (tous @Published sauf isEngineRunning)
var isEngineRunning: Bool                // computed : engine.isRunning
var isRecording: Bool                    // user actively recording
var bufferEnergy: [Float]                // waveform visualization
var bufferSeconds: Double                // elapsed time
```

#### Thread safety

Les variables lues/écrites depuis l'audio thread sont marquées `nonisolated(unsafe)` :

| Variable | Thread d'écriture | Justification |
|----------|-------------------|---------------|
| `converter` | main (une seule fois) | Écrit avant installTap, lu après |
| `isRecordingFlag` | main | Bool sur ARM64 = lecture atomique |
| `lastHeartbeatWrite` | audio | Single writer |
| `lastWaveformWrite` | audio | Single writer |
| `audioThreadEnergy` | audio | Single writer |
| `audioThreadSampleCount` | audio | Single writer |

### TranscriptionService — Le routeur STT

**Localisation** : `DictusApp/Audio/TranscriptionService.swift`

Reçoit un `[Float]` et le route vers le bon moteur de transcription.

```swift
// Routing logic (simplifié) :
func transcribe(audioSamples: [Float]) async throws -> String {
    if let engine = activeEngine {
        return try await engine.transcribe(audioSamples: samples, language: lang)
    } else if let whisperKit {
        // fallback direct WhisperKit
        return try await whisperKit.transcribe(audioArray: samples, ...)
    }
}
```

Le moteur actif est injecté par `DictationCoordinator` via :
- `prepare(whisperKit:)` — injecte l'instance WhisperKit (pour le fallback)
- `prepare(engine:)` — injecte un `SpeechModelProtocol` (WhisperKitEngine ou ParakeetEngine)

### SpeechModelProtocol — L'abstraction moteur

**Localisation** : `DictusApp/Audio/SpeechModelProtocol.swift`

```swift
protocol SpeechModelProtocol {
    var engineName: String { get }
    var isReady: Bool { get }
    func prepare(modelIdentifier: String) async throws
    func transcribe(audioSamples: [Float], language: String) async throws -> String
}
```

Chaque moteur STT implémente ce protocol. Aujourd'hui :
- **WhisperKitEngine** : wrapper autour de WhisperKit (dans le même fichier)
- **ParakeetEngine** : wrapper autour de FluidAudio/AsrManager

### DictationCoordinator — L'orchestrateur

**Localisation** : `DictusApp/DictationCoordinator.swift`

Coordonne le tout : réception des signaux clavier (Darwin notifications), gestion du cycle enregistrement/transcription, communication avec le clavier via App Group.

Flux simplifié :

```
Clavier tape micro
  → Darwin notification (ou URL scheme si cold start)
  → DictationCoordinator.startDictation()
      → audioEngine.startRecording()
      → ensureEngineReady()  // charge WhisperKit ou Parakeet si pas prêt

Clavier tape stop
  → Darwin notification
  → DictationCoordinator.stopDictation()
      → samples = audioEngine.collectSamples()
      → text = transcriptionService.transcribe(audioSamples: samples)
      → écrit résultat dans App Group
      → Darwin notification vers clavier
```

---

## Ajouter un nouveau moteur STT

Pour intégrer un nouveau fournisseur (ex: Moonshine, Sherpa-ONNX, un modèle CoreML custom…) :

### 1. Créer l'adapter

Créer `DictusApp/Audio/NouveauMoteurEngine.swift` :

```swift
import Foundation

class NouveauMoteurEngine: SpeechModelProtocol {
    var engineName: String { "NouveauMoteur" }

    private var model: NouveauMoteurSDK?

    var isReady: Bool { model != nil }

    func prepare(modelIdentifier: String) async throws {
        // Télécharger/charger le modèle
        model = try await NouveauMoteurSDK.load(modelIdentifier)
    }

    func transcribe(audioSamples: [Float], language: String) async throws -> String {
        guard let model else { throw TranscriptionError.notReady }
        // L'input est TOUJOURS [Float] 16kHz mono — UnifiedAudioEngine s'en charge
        return try await model.transcribe(audio: audioSamples, lang: language)
    }
}
```

**Important** : Le nouveau moteur reçoit du `[Float]` 16kHz mono. C'est `UnifiedAudioEngine` qui gère la conversion depuis le format hardware. Le moteur STT ne touche jamais à `AVAudioEngine` ni à `AVAudioSession`.

### 2. Ajouter le type de moteur au catalogue

Dans `DictusCore`, ajouter le nouveau type dans l'enum `STTEngine` :

```swift
enum STTEngine: String, Codable {
    case whisperKit
    case parakeet
    case nouveauMoteur  // ← ajouter
}
```

Puis dans `ModelInfo` (le catalogue de modèles), ajouter les entrées :

```swift
ModelInfo(
    identifier: "nouveaumoteur_large-v1",
    displayName: "NouveauMoteur Large v1",
    engine: .nouveauMoteur,
    sizeBytes: 500_000_000,
    // ...
)
```

### 3. Router dans DictationCoordinator

Dans `ensureEngineReady()`, ajouter le case :

```swift
switch engine {
case .parakeet:
    try await ensureParakeetReady(modelName: modelName)
case .whisperKit:
    try await ensureWhisperKitEngineReady(modelName: modelName)
case .nouveauMoteur:
    try await ensureNouveauMoteurReady(modelName: modelName)
}
```

La méthode `ensureNouveauMoteurReady()` suit le même pattern :

```swift
private func ensureNouveauMoteurReady(modelName: String) async throws {
    if currentModelName == modelName, whisperKit == nil { return }

    let task = Task<Void, Error> {
        let engine = NouveauMoteurEngine()
        try await engine.prepare(modelIdentifier: modelName)

        self.whisperKit = nil  // on n'utilise pas WhisperKit
        self.currentModelName = modelName
        transcriptionService.prepare(engine: engine)
    }
    // ... (même pattern initTask que WhisperKit/Parakeet)
}
```

### 4. Checklist

- [ ] Le moteur implémente `SpeechModelProtocol`
- [ ] L'enum `STTEngine` a le nouveau case
- [ ] `ModelInfo` a les entrées du catalogue
- [ ] `ensureEngineReady()` route vers le nouveau moteur
- [ ] Le modèle apparaît dans `ModelManagerView` (si téléchargeable)
- [ ] Aucune modification à `UnifiedAudioEngine` (la capture est agnostique)
- [ ] Aucune modification à `TranscriptionService` (le routing passe par le protocol)

### Ce qu'il ne faut PAS faire

- **Ne pas créer un nouveau moteur audio** : `UnifiedAudioEngine` capture pour tous les moteurs STT. Le format `[Float]` 16kHz mono est universel.
- **Ne pas toucher à AVAudioSession** depuis le moteur STT : c'est `UnifiedAudioEngine` + `DictationCoordinator` qui gèrent la session.
- **Ne pas importer le SDK STT dans UnifiedAudioEngine** : le moteur audio ne connaît pas le moteur de transcription. Le découplage est intentionnel.

---

## Contraintes iOS à connaître

| Contrainte | Impact | Solution dans Dictus |
|------------|--------|---------------------|
| Extension clavier : 50MB RAM max | Pas de modèle STT dans l'extension | L'enregistrement se fait dans DictusApp |
| `setActive(true)` interdit en background | Session audio doit être configurée au foreground | `configureAudioSession()` appelé dans `init()` de DictationCoordinator |
| iOS throttle `DispatchQueue.main.async` en background | Les updates SwiftUI sont retardées | Heartbeat + waveform écrits directement depuis l'audio thread |
| `UIBackgroundModes:audio` nécessite un engine actif | L'app est killed si l'engine s'arrête | L'engine reste en idle entre les enregistrements |
| WhisperKit appelle `setCategory` dans `startRecordingLive` | Conflit de session si options différentes | On utilise les mêmes options : `.defaultToSpeaker, .allowBluetooth` |
| Haptics reset par `setActive(true)` | Vibration ne marche pas | `setAllowHapticsAndSystemSoundsDuringRecording` dans `configureAudioSession()` |
