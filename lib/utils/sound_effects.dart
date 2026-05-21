/// Sound effect identifiers for the game.
///
/// These are the Flutter equivalent of the spec's `useSoundEffect('...')`
/// hooks. Audio is not wired up yet - [playSound] is an intentional no-op
/// placeholder so gameplay code can call it today and a real audio backend
/// (e.g. `audioplayers`/`just_audio`) can be slotted in later.
enum SoundEffect {
  cardSelect, // on card selection
  cardSlam, // on round result reveal
  goal, // on goal outcome
  redCard, // on red card event
  coinFlip, // on toss animation
  matchWin, // on victory screen
}

/// Stub sound hook. Wire real playback here in the future.
void playSound(SoundEffect effect) {
  // no-op: future audio implementation hook
}
