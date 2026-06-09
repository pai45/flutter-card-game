# card_game

A Flutter card-duel and sports-prediction app with a cyber-styled match hub,
deck building, match history, picks, wallet coins, and player progression.

## Feature Notes

- The Matches top bar shows the current win streak beside the coin balance.
- Tapping the streak opens a calendar-style streak screen inspired by the
  match/history UI: a flame hero, monthly event grid, and day-specific tabs for
  `MY MATCHES` and `MY PICKS`.
- The streak screen uses `assets/animations/streak_animation.json`, a cleaned
  Lottie asset with the exported Jitter watermark composition removed.
- Calendar days light up when a duel match or prediction pick exists on that
  date. Match cards open the existing match-history detail screen; pick cards
  open the prediction detail flow.
- Prediction Matches use an animated first-time quiz reveal, then reopen
  submitted predictions as an editable review list before kickoff and a
  read-only vote/result review once matches are live or finished.
- Prediction quizzes include one `2x` and one `1.5x` booster that can be moved
  between answered questions until the fixture locks.
- First-time users must choose a profile avatar before entering the app. The
  avatar options live in `assets/avatar_options/` as WebP images and are saved
  with `SecureGameStorage`.
- Profile and leaderboard avatars use the same avatar option set. Leaderboard
  players are assigned a stable pseudo-random avatar from their player name, so
  each row, podium card, and the user's sticky rank bar share the same portrait
  mapping.

## Getting Started

This project is a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
