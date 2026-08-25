# CrazyGames Web Release Hardening — Smoke Evidence

Date: 2026-08-25
Branch: `feature/crazygames-release-hardening`
Restore point: `main` and `checkpoint/2026-08-18-pre-next-feature` at
`2e41a414d2df9fc735041a6ae89adaa5ad75ef6c`

## Scope and safety

- Work stayed on the feature branch during implementation. The tested Web
  files were subsequently uploaded to CrazyGames and submitted for Basic
  Launch review on 2026-08-25. Build ID:
  `62bf0984-0b03-4efd-aac0-50468ef59359`.
- The existing `build/web` output, Android build artifacts, signing files, and
  release configuration were not overwritten.
- CrazyGames calls remain behind `OS.has_feature("web")`; the Android preset
  contains no CrazyGames SDK or JavaScript bridge injection.
- The final CrazyGames artifact was refreshed in `build/crazygames`; the
  Android regression artifact was written under a new, explicit
  `build/android-regression` path.
- A stale test-only expected card count was updated from 26 to 27 after the
  existing `polish_export_disaster` card made the fixture expectation obsolete.
  No gameplay content or selection behavior changed.

## Toolchain

- Engine: official Godot `4.6.3.stable.official.7d41c59c4` standard editor.
- Official macOS archive SHA-512 verified against the release sums:
  `0155bbc8dcf179edab4ef08e3dbbd4480d7434ab1990cb3fb25517d453b1b65787c7fe6dfc8824b15ff25e1fdcec59e8584f765054106894fee00311868c3964`.
- Matching `4.6.3.stable` Web and Android export templates were used.
- Production exports were made from an isolated staging copy with development
  editor plugins disabled only in that copy. Workspace `project.godot` stayed
  unchanged.

## CrazyGames Web artifact

- Export completed with code 0.
- Upload ZIP: `build/crazygames/king-of-cringe-crazygames-4.6.3.zip`.
- ZIP size: 19,522,027 bytes.
- ZIP SHA-256:
  `496e1b56eeb7fc6810d2c481c5ccbcb2b69f8e60cec53904a4688c35bdfec5e6`.
- Flat archive root, 12 structurally valid files.
- Brotli files for WASM, PCK, and JS each pass `brotli --test`.
- Initial compressed core payload: 7,956,776 bytes (approximately 7.96 MB).
- Local HTTP checks returned 200 for HTML, WASM, and PCK; WASM was served as
  `application/wasm`.
- Headless Chrome with SwiftShader started the real Godot/WASM game and reached
  the bilingual language-selection screen in the intended 9:16 layout. A
  CrazyGames Preview smoke test remains the portal-specific release gate.

## CrazyGames SDK lifecycle

- `node tools/verify_crazygames_web.mjs`: PASS.
- Verified asynchronous replay order:
  `init -> loadingStart -> loadingStop -> gameplayStart`.
- Loading completion and gameplay transitions are idempotent.
- Verified gameplay stop/start transitions and `happytime` forwarding.
- Boot, start menu, offline report, and full-screen panels do not report active
  gameplay; gameplay starts on the playable Action Screen.
- CrazyGames Data Module is the authoritative Web save backend under key
  `king_of_cringe_save_v1`; boot waits for SDK initialization before restore.
- The verifier confirms exact Data Module set/get round-trip. Browser-local
  storage remains a cache/fallback; Android keeps the existing atomic
  `user://save.json` backend unchanged.

## Android regression artifact

- Isolated debug AAB export completed with code 0.
- Regression artifact:
  `build/android-regression/king-of-cringe-android-regression-4.6.3.aab`.
- Size: 30,202,823 bytes.
- SHA-256:
  `98ad8eafb8b23d59defb0ddcaa36b872081433297f39c4cb9e4d84eafc0ff4db`.
- ZIP integrity and `bundletool validate` pass.
- Bundletool manifest evidence: package `com.artuq.KingofCringe`, version name
  `0.1.0`, version code `1`, min SDK `24`, target SDK `36`, ARM64 only.
- This is an unsigned debug regression bundle, not the signed Google Play
  release artifact and not a replacement for the physical-device test.

## Automated regression

- Navigation focus: 17/17 assertions, 0 failures/errors.
- Boot flow: 10/10 assertions, 0 failures/errors; runner reported the known
  orphan-node fixture warnings.
- Card pool count correction: 9/9, 0 failures/errors (`report_558`).
- Focused save/parser suite: 16/16, 0 failures/errors (`report_560`).
- Full suite: 882/882 across 102/102 suites, 0 failures/errors, 0 skipped
  (`report_561`). GdUnit exited 101 only because it counted 881 known orphan
  fixture warnings; XML test results are otherwise green.

## CrazyGames listing materials

- Submission copy, controls, tags and portal field choices are recorded in
  `marketing/crazygames/submission-copy.md`.
- Three covers have the exact mandatory dimensions: landscape 1920×1080,
  portrait 800×1200 and square 800×800. All use the existing app character and
  only the `King of Cringe` title.
- Two silent H.264 preview videos are 14.97 seconds long at 30 fps: landscape
  1920×1080 and portrait 1080×1620. Each is below 1 MB, begins with its matching
  cover, and uses real gameplay screenshots for the remaining frames.
- The built-in `imagegen` path generated the cover artwork from the existing
  app icon as a style/character reference. The Android icon was not changed.

## Submission state and remaining gates

- CrazyGames accepted the submission and reports `Awaiting Review`; the build
  version is marked `Submitted`.
- Commit and push of the feature branch were authorized after submission;
  merging remains a separate review decision.
- If CrazyGames requests changes, submit a new version from this feature line
  and retain the accepted Build ID above as the audit reference.
- Before a later Android release, execute the still-open physical-device smoke
  test; the technical AAB export does not replace it.
