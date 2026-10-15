import '../../models/sport_match.dart';
import '../../models/unlock_progress.dart';
import '../../widgets/cyber/cyber_widgets.dart';

class GamesTrendingTileConfig {
  const GamesTrendingTileConfig({
    required this.id,
    required this.sourceId,
    required this.span,
    this.sport,
    this.enabled = true,
  });

  final String id;
  final String sourceId;
  final CyberBentoSpan span;
  final Sport? sport;
  final bool enabled;
}

/// A tile is shown only when enabled and, for a sport-tagged tile, its sport
/// is open to this player (locked sports never leak into TRENDING).
bool gamesTrendingTileVisible(
  GamesTrendingTileConfig item,
  UnlockProgress unlocks,
) =>
    item.enabled &&
    (item.sport == null || unlocks.isSportUnlocked(item.sport!));

const gamesTrendingCatalog = <GamesTrendingTileConfig>[
  GamesTrendingTileConfig(
    id: 'trend-game-pitch-duel',
    sourceId: 'pitch-duel',
    sport: Sport.football,
    span: CyberBentoSpan.square,
  ),
  GamesTrendingTileConfig(
    id: 'trend-game-penalty',
    sourceId: 'penalty-shootout',
    sport: Sport.football,
    span: CyberBentoSpan.square,
  ),
  GamesTrendingTileConfig(
    id: 'trend-game-football-chess',
    sourceId: 'football-chess',
    sport: Sport.football,
    span: CyberBentoSpan.tall,
  ),
  GamesTrendingTileConfig(
    id: 'trend-game-football-quiz',
    sourceId: 'football-quiz',
    sport: Sport.football,
    span: CyberBentoSpan.square,
  ),
  GamesTrendingTileConfig(
    id: 'trend-game-football-bingo',
    sourceId: 'football-bingo',
    sport: Sport.football,
    span: CyberBentoSpan.square,
  ),
  GamesTrendingTileConfig(
    id: 'trend-game-guess-player',
    sourceId: 'guess-player',
    sport: Sport.football,
    span: CyberBentoSpan.wide,
  ),
  GamesTrendingTileConfig(
    id: 'trend-game-final-over',
    sourceId: 'final-over',
    sport: Sport.cricket,
    span: CyberBentoSpan.wide,
  ),
  GamesTrendingTileConfig(
    id: 'trend-game-hoop-duel',
    sourceId: 'hoop-duel',
    sport: Sport.basketball,
    span: CyberBentoSpan.square,
  ),
  GamesTrendingTileConfig(
    id: 'trend-game-grand-prix',
    sourceId: 'grand-prix-dash',
    sport: Sport.motorsport,
    span: CyberBentoSpan.square,
  ),
  GamesTrendingTileConfig(
    id: 'trend-game-tennis-rally',
    sourceId: 'tennis-rally',
    sport: Sport.tennis,
    span: CyberBentoSpan.wide,
  ),
];
