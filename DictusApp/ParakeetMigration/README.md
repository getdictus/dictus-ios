# ParakeetMigration: remove before the 2.0.0 cut

`JointDecisionv3.mlmodelc` is copied into the DictusApp bundle (folder reference,
DictusApp target only) for **1.8.3**, the release that moves Dictus from FluidAudio
0.12 to 0.15.7 (#558).

FluidAudio 0.15 loads Parakeet v3 with this joint instead of `JointDecision.mlmodelc`,
so every install that downloaded Parakeet before 1.8.3 lacks it. At launch,
`ParakeetCacheRepair` copies it from the bundle into the FluidAudio cache, which makes
the first launch after the update work offline with no download.

Source: `FluidInference/parakeet-tdt-0.6b-v3-coreml`, revision `7dd20fe`, 12 658 756
bytes, every file checked against the repository's SHA-256 (LFS) or git blob hash.

**Removal plan (before 2.0.0 is cut):**

1. Delete this folder.
2. Delete its two entries in `Dictus.xcodeproj/project.pbxproj` (the folder reference
   and its line in the DictusApp Resources phase).
3. Empty `ParakeetCacheRepair.bundledModelBundles`.

Nothing else changes. A user who updates from a pre-1.8.3 build straight to 2.0.0 then
goes through layer 1: `ModelManager` fetches the missing joint through
`ModelRepoDownloader`, with progress on the model card.
