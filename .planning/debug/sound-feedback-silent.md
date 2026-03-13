---
status: diagnosed
trigger: "SoundFeedbackService produces zero sound — neither preview buttons nor recording lifecycle sounds play any audio"
created: 2026-03-13T00:00:00Z
updated: 2026-03-13T00:00:00Z
---

## Current Focus

hypothesis: Bundle.main.url(forResource:withExtension:) returns nil because WAV files are inside a "Sounds/" subdirectory (folder reference in Xcode) but the lookup does not specify subdirectory
test: Verified Xcode project.pbxproj uses folder reference (lastKnownFileType = folder), confirmed WAV files exist on disk at Dictus/Sounds/
expecting: With folder reference, files are copied into bundle as Sounds/electronic_01a.wav, not at root level
next_action: Return diagnosis with fix

## Symptoms

expected: Sounds play on preview button tap and during recording lifecycle (start/stop/cancel)
actual: Zero sound output, zero [sound] log entries in debug logs
errors: None (silent failure — guard returns early when Bundle.main.url returns nil)
reproduction: Tap any preview speaker button in SoundSettingsView, or start/stop a recording
started: Since SoundFeedbackService was implemented

## Eliminated

(none needed — root cause found on first hypothesis)

## Evidence

- timestamp: 2026-03-13
  checked: WAV files on disk
  found: 29 WAV files exist at /Users/pierreviviere/dev/dictus/Dictus/Sounds/*.wav
  implication: Files exist, not a missing asset issue

- timestamp: 2026-03-13
  checked: Xcode project.pbxproj Sounds reference
  found: |
    AA1000F4 = {isa = PBXFileReference; lastKnownFileType = folder; name = Sounds; path = Dictus/Sounds; sourceTree = SOURCE_ROOT}
    This is a FOLDER REFERENCE (lastKnownFileType = folder), not individual file references.
    It IS included in DictusApp target's Resources build phase (AA600003).
  implication: Folder references copy the entire directory into the bundle, preserving the directory structure. Files end up at AppBundle/Sounds/electronic_01a.wav, not AppBundle/electronic_01a.wav.

- timestamp: 2026-03-13
  checked: SoundFeedbackService.play() line 63
  found: |
    Bundle.main.url(forResource: soundName, withExtension: "wav")
    No subdirectory parameter specified. This searches the bundle ROOT only.
  implication: Returns nil for every sound file because files are in the Sounds/ subdirectory. The guard silently returns without playing.

- timestamp: 2026-03-13
  checked: SoundFeedbackService error handling
  found: |
    Lines 63-65: guard let url = Bundle.main.url(...) else { return }
    Silent return — no logging when file lookup fails.
    This explains zero [sound] log entries: the service never gets past the Bundle lookup.
  implication: The service was written with intentionally silent failures, making this bug invisible in logs.

- timestamp: 2026-03-13
  checked: DictationCoordinator sound calls
  found: |
    Line 262: SoundFeedbackService.playRecordStart() — called correctly
    Line 401, 460: SoundFeedbackService.playRecordStop() — called correctly
    Line 526: SoundFeedbackService.playRecordCancel() — called correctly
  implication: The calls are wired correctly. The issue is purely the Bundle lookup failure.

- timestamp: 2026-03-13
  checked: SoundSettingsView preview button
  found: |
    Line 102: SoundFeedbackService.play(selection.wrappedValue)
    Calls play() directly (bypasses isEnabled check), same Bundle.main.url issue.
  implication: Even the direct preview path fails because of the same root cause.

## Resolution

root_cause: |
  The Sounds directory is added to the Xcode project as a FOLDER REFERENCE
  (lastKnownFileType = folder in project.pbxproj). This means the entire directory
  structure is preserved in the app bundle: files end up at AppBundle/Sounds/electronic_01a.wav.

  However, SoundFeedbackService.play() calls:
    Bundle.main.url(forResource: soundName, withExtension: "wav")

  Without the `subdirectory: "Sounds"` parameter, this searches only the bundle ROOT,
  finds nothing, and silently returns (no logging).

  This affects ALL sound playback: preview buttons, record start, record stop, and cancel.

fix: |
  **Fix 1 (required): Add subdirectory parameter to Bundle lookup**

  In SoundFeedbackService.swift line 63, change:
  ```swift
  guard let url = Bundle.main.url(forResource: soundName, withExtension: "wav") else {
  ```
  to:
  ```swift
  guard let url = Bundle.main.url(forResource: soundName, withExtension: "wav", subdirectory: "Sounds") else {
  ```

  **Fix 2 (recommended): Add debug logging for failed lookups**

  After the guard statement, add a print/log so future bundle issues are visible:
  ```swift
  guard let url = Bundle.main.url(forResource: soundName, withExtension: "wav", subdirectory: "Sounds") else {
      #if DEBUG
      print("[SoundFeedback] WAV not found in bundle: \(soundName).wav")
      #endif
      return
  }
  ```

verification: Not yet verified (diagnosis only)
files_changed: []
