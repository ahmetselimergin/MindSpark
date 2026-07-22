# Current Progression and Gameplay UI Implementation Plan

## Task 1 — Legacy endless-progress reconciliation

- [x] Add RED domain/controller/widget tests for `{1,2,3}/highest=3` resolving to Level 4.
- [x] Add one pure normalization method at the progress/state boundary.
- [x] Keep gaps, fresh completion, locked routes, score, lives, stars, and schema behavior intact.
- [x] Run focused and full verification; commit.

## Task 2 — Current gameplay visual refresh

- [x] Add a RED empty-cell pixel test proving the board is no longer white.
- [x] Implement the dark blueprint renderer and system typography.
- [x] Add a static circuit backdrop and adjacent gameplay instruction without removing timer, lives, image controls, stuck hint, or banner.
- [x] Preserve 320×568 at 2× text scale.
- [x] Run focused/full tests, analyzer, Android build, and emulator inspection; commit.

## Task 3 — Integration and delivery

- [x] Review the complete diff against current main.
- [x] Re-run analyzer, full tests, debug APK build, and diff check.
- [x] Merge without touching the user's uncommitted iOS/market files.
