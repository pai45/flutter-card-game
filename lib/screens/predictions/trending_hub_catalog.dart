import '../../models/sport_match.dart';
import '../../widgets/cyber/cyber_widgets.dart';

enum TrendingTileKind { match, future, pick, predict, game }

class TrendingTileConfig {
  const TrendingTileConfig({
    required this.id,
    required this.kind,
    required this.sourceId,
    required this.span,
    this.sport,
    this.enabled = true,
  });

  final String id;
  final TrendingTileKind kind;
  final String sourceId;
  final CyberBentoSpan span;
  final Sport? sport;
  final bool enabled;
}

const matchTrendingCatalog = <TrendingTileConfig>[
  TrendingTileConfig(
    id: 'trend-live-epl',
    kind: TrendingTileKind.match,
    sourceId: 'epl_cfc_new',
    sport: Sport.football,
    span: CyberBentoSpan.wide,
  ),
  TrendingTileConfig(
    id: 'trend-world-cup-future',
    kind: TrendingTileKind.future,
    sourceId: 'fifa_2026_winner',
    sport: Sport.football,
    span: CyberBentoSpan.square,
  ),
  TrendingTileConfig(
    id: 'trend-arsenal-predict',
    kind: TrendingTileKind.predict,
    sourceId: 'epl_mu_ars',
    sport: Sport.football,
    span: CyberBentoSpan.square,
  ),
  TrendingTileConfig(
    id: 'trend-liverpool-pick',
    kind: TrendingTileKind.pick,
    sourceId: 'epl_liv_mc_winner',
    sport: Sport.football,
    span: CyberBentoSpan.square,
  ),
  TrendingTileConfig(
    id: 'trend-wnba-predict',
    kind: TrendingTileKind.predict,
    sourceId: 'wnba_demo_dal_phx',
    sport: Sport.basketball,
    span: CyberBentoSpan.square,
  ),
  TrendingTileConfig(
    id: 'trend-live-cricket',
    kind: TrendingTileKind.match,
    sourceId: '1496576',
    sport: Sport.cricket,
    span: CyberBentoSpan.wide,
  ),
  TrendingTileConfig(
    id: 'trend-ipl-future',
    kind: TrendingTileKind.future,
    sourceId: 'ipl_2026_winner',
    sport: Sport.cricket,
    span: CyberBentoSpan.square,
  ),
  TrendingTileConfig(
    id: 'trend-ipl-sixes-pick',
    kind: TrendingTileKind.pick,
    sourceId: 'ipl_sixes_over_12_5',
    sport: Sport.cricket,
    span: CyberBentoSpan.square,
  ),
  TrendingTileConfig(
    id: 'trend-wimbledon-predict',
    kind: TrendingTileKind.predict,
    sourceId: 'wimbledon_mens_final_26',
    sport: Sport.tennis,
    span: CyberBentoSpan.wide,
  ),
  TrendingTileConfig(
    id: 'trend-man-utd-pick',
    kind: TrendingTileKind.pick,
    sourceId: 'epl_mu_over_1_5',
    sport: Sport.football,
    span: CyberBentoSpan.square,
  ),
  TrendingTileConfig(
    id: 'trend-belgian-gp-future',
    kind: TrendingTileKind.future,
    sourceId: 'f1_belgian_gp_winner',
    sport: Sport.motorsport,
    span: CyberBentoSpan.square,
  ),
];

const gamesTrendingCatalog = <TrendingTileConfig>[
  TrendingTileConfig(
    id: 'trend-game-pitch-duel',
    kind: TrendingTileKind.game,
    sourceId: 'pitch-duel',
    sport: Sport.football,
    span: CyberBentoSpan.tall,
  ),
  TrendingTileConfig(
    id: 'trend-game-penalty',
    kind: TrendingTileKind.game,
    sourceId: 'penalty-shootout',
    sport: Sport.football,
    span: CyberBentoSpan.tall,
  ),
  TrendingTileConfig(
    id: 'trend-game-football-chess',
    kind: TrendingTileKind.game,
    sourceId: 'football-chess',
    sport: Sport.football,
    span: CyberBentoSpan.tall,
  ),
  TrendingTileConfig(
    id: 'trend-game-football-quiz',
    kind: TrendingTileKind.game,
    sourceId: 'football-quiz',
    sport: Sport.football,
    span: CyberBentoSpan.square,
  ),
  TrendingTileConfig(
    id: 'trend-game-football-bingo',
    kind: TrendingTileKind.game,
    sourceId: 'football-bingo',
    sport: Sport.football,
    span: CyberBentoSpan.square,
  ),
  TrendingTileConfig(
    id: 'trend-game-guess-player',
    kind: TrendingTileKind.game,
    sourceId: 'guess-player',
    sport: Sport.football,
    span: CyberBentoSpan.wide,
  ),
  TrendingTileConfig(
    id: 'trend-game-final-over',
    kind: TrendingTileKind.game,
    sourceId: 'final-over',
    sport: Sport.cricket,
    span: CyberBentoSpan.wide,
  ),
  TrendingTileConfig(
    id: 'trend-game-hoop-duel',
    kind: TrendingTileKind.game,
    sourceId: 'hoop-duel',
    sport: Sport.basketball,
    span: CyberBentoSpan.square,
  ),
  TrendingTileConfig(
    id: 'trend-game-grand-prix',
    kind: TrendingTileKind.game,
    sourceId: 'grand-prix-dash',
    sport: Sport.motorsport,
    span: CyberBentoSpan.square,
  ),
  TrendingTileConfig(
    id: 'trend-game-tennis-rally',
    kind: TrendingTileKind.game,
    sourceId: 'tennis-rally',
    sport: Sport.tennis,
    span: CyberBentoSpan.wide,
  ),
];

Set<Sport> get matchTrendingSports => {
  for (final item in matchTrendingCatalog)
    if (item.enabled && item.sport != null) item.sport!,
};
