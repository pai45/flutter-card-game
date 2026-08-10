# Product Documentation Ledger

This is the append-only change ledger for canonical product documentation.
Every request that creates or updates product documentation adds one dated row.
Use one row per coherent request, not one row per file.

| Date | Area | Change type | Status | Summary | Affected documentation | Code/tests verified |
|---|---|---|---|---|---|---|
| 2026-08-09 | Whole app | Overhaul | BUILT / PROTOTYPE / PLANNED | Reorganized the product library; documented all 18 Games-tab entries; added progression, streak, achievement, social, economy, collection, support, and design coverage; corrected current behavior; archived superseded root documents. | `README.md`, `games/`, `systems/`, `design/`, `DOCUMENT_TEMPLATE.md` | App navigation and Games registry; progression, streak, achievement, storage, picks, prediction, referral, friends, daily-mystery and game-mode sources; targeted tests listed on feature pages; refreshed stale catalog coverage to include racing cards |

## Ledger Rules

- Append new entries; do not rewrite historical rows to make later behavior
  appear older.
- Use the implementation date in `YYYY-MM-DD` form.
- Include the affected page or folder and the code/tests used to verify claims.
- A new game, feature, design rule, economy rule, navigation path, or planned
  scope change must update its page and this ledger in the same change.
- Update the main product index when coverage, navigation, or cross-feature
  behavior changes.
