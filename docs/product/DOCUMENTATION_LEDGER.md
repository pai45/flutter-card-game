# Product Documentation Ledger

This is the append-only change ledger for canonical product documentation.
Every request that creates or updates product documentation adds one dated row.
Use one row per coherent request, not one row per file.

| Date | Area | Change type | Status | Summary | Affected documentation | Code/tests verified |
|---|---|---|---|---|---|---|
| 2026-08-09 | Whole app | Overhaul | BUILT / PROTOTYPE / PLANNED | Reorganized the product library; documented all 18 Games-tab entries; added progression, streak, achievement, social, economy, collection, support, and design coverage; corrected current behavior; archived superseded root documents. | `README.md`, `games/`, `systems/`, `design/`, `DOCUMENT_TEMPLATE.md` | App navigation and Games registry; progression, streak, achievement, storage, picks, prediction, referral, friends, daily-mystery and game-mode sources; targeted tests listed on feature pages; refreshed stale catalog coverage to include racing cards |
| 2026-08-11 | Onboarding / achievements | Feedback adjustment | BUILT | Suppressed the Treasury global achievement reveal so the one-time 1,000-coin welcome animation remains the sole first-run reward moment; the badge still unlocks and is recorded as celebrated. | `systems/achievements.md`, `systems/profile-onboarding-and-settings.md` | `lib/blocs/achievement/achievement_celebration_controller.dart`; `test/achievement_celebration_controller_test.dart`; targeted Flutter analyze and onboarding/celebration tests |
| 2026-08-15 | Cricket Quiz | Content correction | BUILT | Replaced every fictional score and arithmetic scenario with audit-backed factual cricket trivia while retaining the 2,000-question ladder, mode coverage, and rewards. | `games/cricket-quiz.md` | `tool/generate_cricket_quiz.dart`; `tool/verify_quiz_bank.dart`; `test/quiz_cubit_test.dart`; targeted quiz tests and Flutter analyze |

## Ledger Rules

- Append new entries; do not rewrite historical rows to make later behavior
  appear older.
- Use the implementation date in `YYYY-MM-DD` form.
- Include the affected page or folder and the code/tests used to verify claims.
- A new game, feature, design rule, economy rule, navigation path, or planned
  scope change must update its page and this ledger in the same change.
- Update the main product index when coverage, navigation, or cross-feature
  behavior changes.
