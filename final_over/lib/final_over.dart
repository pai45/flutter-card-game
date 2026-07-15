library;

/// The rules engine. Deterministic, pure Dart, no Flutter or Flame types —
/// this is what the host app builds its own renderer and HUD on top of.
/// [MatchController] stays the only gameplay authority: a renderer may send
/// commands and observe state, but never decides a run, a wicket, or a score.
export 'application/application.dart';
export 'domain/domain.dart';

/// The package's own arcade presentation. Only the standalone build uses this;
/// the host app ships its own screens.
export 'presentation/final_over_game_screen.dart' show FinalOverGameScreen;
