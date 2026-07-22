# Current Progression and Gameplay UI Implementation Plan

## Task 1 — Legacy endless-progress reconciliation

- [ ] Add RED domain/controller/widget tests for `{1,2,3}/highest=3` resolving to Level 4.
- [ ] Add one pure normalization method at the progress/state boundary.
- [ ] Keep gaps, fresh completion, locked routes, score, lives, stars, and schema behavior intact.
- [ ] Run focused and full verification; commit.

## Task 2 — Current gameplay visual refresh

- [ ] Add a RED empty-cell pixel test proving the board is no longer white.
- [ ] Implement the dark blueprint renderer and system typography.
- [ ] Add a static circuit backdrop and adjacent gameplay instruction without removing timer, lives, image controls, stuck hint, or banner.
- [ ] Preserve 320×568 at 2× text scale.
- [ ] Run focused/full tests, analyzer, Android build, and emulator inspection; commit.

## Task 3 — Integration and delivery

- [ ] Review the complete diff against current main.
- [ ] Re-run analyzer, full tests, debug APK build, and diff check.
- [ ] Merge without touching the user's uncommitted iOS/market files.
