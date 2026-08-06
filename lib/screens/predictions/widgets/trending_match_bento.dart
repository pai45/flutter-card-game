import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/picks/picks_cubit.dart';
import '../../../blocs/picks/picks_state.dart';
import '../../../blocs/prediction/prediction_cubit.dart';
import '../../../blocs/prediction/prediction_state.dart';
import '../../../config/sport_modules.dart';
import '../../../config/theme.dart';
import '../../../models/picks.dart';
import '../../../models/sport_match.dart';
import '../../../utils/prediction_helpers.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/staggered_card_entrance.dart';
import '../../../widgets/team_logo.dart';
import '../trending_hub_catalog.dart';
import 'pick_status_style.dart';

/// The primary title on every MATCH / PREDICT / PICK / FUTURE tile.
///
/// Supporting telemetry remains deliberately compact, but the tappable subject
/// of a tile must stay readable at the app's 15px minimum.
const double _kTrendingTileHeadingSize = 15;

class TrendingMatchesView extends StatefulWidget {
  const TrendingMatchesView({
    required this.onOpenMatch,
    required this.onOpenMarket,
    required this.animateIntro,
    this.onIntroPlayed,
    super.key,
  });

  final ValueChanged<SportMatch> onOpenMatch;
  final ValueChanged<String> onOpenMarket;
  final bool animateIntro;
  final VoidCallback? onIntroPlayed;

  @override
  State<TrendingMatchesView> createState() => _TrendingMatchesViewState();
}

class _TrendingMatchesViewState extends State<TrendingMatchesView> {
  bool _fixtureScanRunning = true;
  bool _introReported = false;
  Map<String, SportMatch> _catalogFixtures = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadConfiguredSports(),
    );
  }

  Future<void> _loadConfiguredSports() async {
    final cubit = context.read<PredictionCubit>();
    // PredictionCubit merges each sport result into its current fixture
    // snapshot. Keep these catalog-scoped loads ordered so concurrent
    // completions cannot replace fixtures added by another sport.
    for (final sport in matchTrendingSports) {
      await cubit.loadSport(sport);
    }
    final catalogFixtures = await cubit.resolveCatalogFixtures(
      matchTrendingCatalog
          .where(
            (item) =>
                item.enabled &&
                (item.kind == TrendingTileKind.match ||
                    item.kind == TrendingTileKind.predict),
          )
          .map((item) => item.sourceId),
    );
    if (!mounted) return;
    setState(() {
      _catalogFixtures = catalogFixtures;
      _fixtureScanRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PredictionCubit, PredictionState>(
      builder: (context, predictionState) {
        return BlocBuilder<PicksCubit, PicksState>(
          builder: (context, picksState) {
            final catalog = matchTrendingCatalog
                .where((item) => item.enabled)
                .toList(growable: false);
            final animate = widget.animateIntro && !_introReported;
            if (animate && catalog.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _introReported) return;
                _introReported = true;
                widget.onIntroPlayed?.call();
              });
            }

            return ListView(
              key: const ValueKey('match-trending-feed'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              children: [
                CyberBentoGrid(
                  rowGap: 20,
                  rowHeightFactor: 0.86,
                  minRowHeight: 136,
                  tiles: [
                    for (var index = 0; index < catalog.length; index++)
                      CyberBentoTile(
                        span: catalog[index].span,
                        child: StaggeredCardEntrance(
                          key: ValueKey(catalog[index].id),
                          index: index,
                          animate: animate,
                          child: _buildTile(
                            catalog[index],
                            predictionState,
                            picksState,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTile(
    TrendingTileConfig config,
    PredictionState predictionState,
    PicksState picksState,
  ) {
    switch (config.kind) {
      case TrendingTileKind.match:
      case TrendingTileKind.predict:
        final match =
            predictionState.fixtures
                .where((fixture) => fixture.id == config.sourceId)
                .firstOrNull ??
            _catalogFixtures[config.sourceId];
        if (match == null) {
          return _fixtureScanRunning
              ? _TrendingSkeleton(span: config.span)
              : _TrendingUnavailable(kind: config.kind);
        }
        if (config.kind == TrendingTileKind.match) {
          final quiz = predictionState.quizzes.values
              .where((quiz) => quiz.matchId == match.id)
              .firstOrNull;
          return _TrendingMatchCard(
            match: match,
            leagueLabel:
                predictionState.leagueFor(match.leagueId)?.shortCode ??
                match.leagueId.toUpperCase(),
            potentialXp: quiz?.maxReward ?? match.rewardXp,
            volumeOz: seededMatchVolumeOz(match.id),
            onTap: () => widget.onOpenMatch(match),
          );
        }
        final prediction = predictionState.predictionSummaryForMatch(match.id);
        return _TrendingPredictCard(
          match: match,
          leagueLabel:
              predictionState.leagueFor(match.leagueId)?.shortCode ??
              match.leagueId.toUpperCase(),
          hasPrediction: prediction != null,
          onTap: () => widget.onOpenMatch(match),
        );
      case TrendingTileKind.future:
      case TrendingTileKind.pick:
        if (picksState.loading) {
          return _TrendingSkeleton(span: config.span);
        }
        final market = picksState.marketFor(config.sourceId);
        if (market == null) {
          return _TrendingUnavailable(kind: config.kind);
        }
        return _TrendingMarketCard(
          market: market,
          kind: config.kind,
          sport: config.sport ?? Sport.football,
          tall: config.span == CyberBentoSpan.tall,
          onTap: () => widget.onOpenMarket(market.id),
        );
      case TrendingTileKind.game:
        return _TrendingUnavailable(kind: config.kind);
    }
  }
}

class _TrendingMatchCard extends StatelessWidget {
  const _TrendingMatchCard({
    required this.match,
    required this.leagueLabel,
    required this.potentialXp,
    required this.volumeOz,
    required this.onTap,
  });

  final SportMatch match;
  final String leagueLabel;
  final int potentialXp;
  final int volumeOz;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final module = sportModuleFor(match.sport);
    final live = match.status == MatchStatus.live;
    final finished = match.status == MatchStatus.finished;
    final centerLabel = live
        ? '${match.liveMinute ?? 0}′'
        : finished
        ? '${match.homeScore ?? '-'} - ${match.awayScore ?? '-'}'
        : _kickoffTime(match.kickoff);
    final detail = live
        ? '${match.homeScore ?? '0'} - ${match.awayScore ?? '0'}'
        : finished
        ? 'FULL TIME'
        : _shortDate(match.kickoff);

    return _TrendSignalShell(
      semanticsLabel:
          '${match.home.name} versus ${match.away.name}, $centerLabel',
      accent: live ? Cyber.success : module.accent,
      tag: live
          ? 'LIVE MATCH'
          : finished
          ? 'RESULT'
          : 'MATCH',
      live: live,
      hardElevated: true,
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 34, 14, 4),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(module.icon, size: 13, color: module.accent),
                      const SizedBox(width: 6),
                      Text(
                        module.shortLabel,
                        style: Cyber.label(
                          10,
                          color: module.accent,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Container(width: 1, height: 9, color: Cyber.line),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          leagueLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.label(
                            10,
                            color: Cyber.muted,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _TeamLockup(team: match.home, sport: match.sport),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              centerLabel,
                              maxLines: 1,
                              style:
                                  Cyber.display(
                                    live ? 17 : 16,
                                    color: live ? Cyber.success : Colors.white,
                                    letterSpacing: 0.3,
                                  ).copyWith(
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              detail,
                              style: Cyber.body(
                                10,
                                color: Cyber.muted,
                                weight: FontWeight.w600,
                                letterSpacing: 0.2,
                                height: 1,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _TeamLockup(
                        team: match.away,
                        sport: match.sport,
                        alignEnd: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _TrendingMatchFooter(
            matchId: match.id,
            potentialXp: potentialXp > 0 ? potentialXp : 50,
            volumeOz: volumeOz,
          ),
        ],
      ),
    );
  }
}

class _TrendingMatchFooter extends StatelessWidget {
  const _TrendingMatchFooter({
    required this.matchId,
    required this.potentialXp,
    required this.volumeOz,
  });

  final String matchId;
  final int potentialXp;
  final int volumeOz;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('trending-match-footer-$matchId'),
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Cyber.bg2,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 320;
          return Row(
            children: [
              const Icon(
                Icons.trending_up_rounded,
                size: 13,
                color: Cyber.success,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  compact ? '+$potentialXp XP' : 'POTENTIAL +$potentialXp XP',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.body(
                    10,
                    color: Cyber.success,
                    weight: FontWeight.w800,
                    letterSpacing: 0.2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'VOL ${formatOzCompact(volumeOz)} OZ',
                maxLines: 1,
                style: Cyber.body(
                  10,
                  color: Cyber.muted,
                  weight: FontWeight.w600,
                  letterSpacing: 0.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TeamLockup extends StatelessWidget {
  const _TeamLockup({
    required this.team,
    required this.sport,
    this.alignEnd = false,
  });

  final SportTeam team;
  final Sport sport;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          TeamLogo(team: team, width: 34, height: 34, sport: sport),
          const SizedBox(height: 4),
          Text(
            team.shortName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.display(_kTrendingTileHeadingSize, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}

class _TrendingPredictCard extends StatelessWidget {
  const _TrendingPredictCard({
    required this.match,
    required this.leagueLabel,
    required this.hasPrediction,
    required this.onTap,
  });

  final SportMatch match;
  final String leagueLabel;
  final bool hasPrediction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final module = sportModuleFor(match.sport);
    return _TrendSignalShell(
      semanticsLabel: 'Predict ${match.home.name} versus ${match.away.name}',
      accent: Cyber.violet,
      tag: 'PREDICT',
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 34, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(module.icon, size: 13, color: module.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    leagueLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.label(
                      10,
                      color: Cyber.muted,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TeamLogo(
                  team: match.home,
                  width: 30,
                  height: 30,
                  sport: match.sport,
                ),
                Text('VS', style: Cyber.display(10, color: Cyber.violet)),
                TeamLogo(
                  team: match.away,
                  width: 30,
                  height: 30,
                  sport: match.sport,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${match.home.shortName} // ${match.away.shortName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.display(
                _kTrendingTileHeadingSize,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasPrediction ? 'ANSWERS LOCKED' : '+XP MISSION OPEN',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.body(
                10,
                color: hasPrediction ? Cyber.success : Cyber.violet,
                weight: FontWeight.w700,
                letterSpacing: 0.2,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingMarketCard extends StatelessWidget {
  const _TrendingMarketCard({
    required this.market,
    required this.kind,
    required this.sport,
    required this.tall,
    required this.onTap,
  });

  final PickMarket market;
  final TrendingTileKind kind;
  final Sport sport;
  final bool tall;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final future = kind == TrendingTileKind.future;
    final accent = future ? Cyber.gold : Cyber.lime;
    final module = sportModuleFor(sport);
    final leader = market.leadingOutcome;
    final delta = market.latestDeltaFor(leader.id);
    return _TrendSignalShell(
      semanticsLabel: market.question,
      accent: accent,
      tag: future ? 'FUTURE' : 'PICK',
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = !tall && constraints.maxHeight < 160;
          return Padding(
            padding: compact
                ? const EdgeInsets.fromLTRB(10, 34, 10, 8)
                : const EdgeInsets.fromLTRB(12, 38, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(module.icon, size: 13, color: module.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        market.leagueLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.label(
                          10,
                          color: accent,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 4 : 8),
                Text(
                  market.question,
                  maxLines: compact
                      ? 1
                      : tall
                      ? 4
                      : 3,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.body(
                    _kTrendingTileHeadingSize,
                    weight: FontWeight.w800,
                    height: 1.12,
                  ),
                ),
                SizedBox(
                  height: compact
                      ? 7
                      : tall
                      ? 16
                      : 12,
                ),
                if (tall) ...[
                  for (final outcome in market.outcomes.take(4)) ...[
                    _OutcomeSignal(
                      label: outcome.label,
                      value: outcome.probabilityPercent,
                      accent: outcome.id == leader.id ? accent : Cyber.muted,
                    ),
                    const SizedBox(height: 7),
                  ],
                ] else ...[
                  Text(
                    leader.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.display(10, letterSpacing: 0.5),
                  ),
                  SizedBox(height: compact ? 2 : 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${leader.probabilityPercent}%',
                        style:
                            Cyber.display(
                              compact ? 18 : 22,
                              color: accent,
                              letterSpacing: 0,
                            ).copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                      if (delta != null) ...[
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '${delta >= 0 ? '+' : ''}$delta',
                            style:
                                Cyber.label(
                                  10,
                                  color: delta >= 0
                                      ? Cyber.success
                                      : Cyber.danger,
                                ).copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                if (!compact) ...[
                  const SizedBox(height: 7),
                  Text(
                    'VOL ${formatOzCompact(market.volumeOz)} OZ',
                    style: Cyber.body(
                      10,
                      color: Cyber.muted,
                      weight: FontWeight.w600,
                      letterSpacing: 0.2,
                      height: 1.1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OutcomeSignal extends StatelessWidget {
  const _OutcomeSignal({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final int value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.label(10, color: accent, letterSpacing: 0.3),
              ),
            ),
            Text(
              '$value%',
              style: Cyber.display(
                10,
                color: accent,
                letterSpacing: 0,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value / 100,
            child: Container(height: 2, color: accent.withValues(alpha: 0.8)),
          ),
        ),
      ],
    );
  }
}

class _TrendSignalShell extends StatelessWidget {
  const _TrendSignalShell({
    required this.semanticsLabel,
    required this.accent,
    required this.tag,
    required this.onTap,
    required this.child,
    this.live = false,
    this.hardElevated = true,
  });

  final String semanticsLabel;
  final Color accent;
  final String tag;
  final VoidCallback onTap;
  final Widget child;
  final bool live;
  final bool hardElevated;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: PressableScale(
        onTap: () {
          playSound(SoundEffect.uiTap);
          HapticFeedback.selectionClick();
          onTap();
        },
        child: CustomPaint(
          painter: _TrendSignalPainter(
            accent: accent,
            hardElevated: hardElevated,
          ),
          child: ClipPath(
            clipper: const _TrendSignalClipper(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Color.alphaBlend(
                    accent.withValues(alpha: 0.045),
                    Cyber.panel,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 14,
                  right: 14,
                  child: Container(
                    height: 2,
                    color: accent.withValues(alpha: 0.8),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 12,
                  child: live
                      ? const _LiveSignalBadge(label: 'LIVE')
                      : Text(
                          tag,
                          style: Cyber.label(
                            10,
                            color: accent,
                            letterSpacing: 0.7,
                          ),
                        ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveSignalBadge extends StatelessWidget {
  const _LiveSignalBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Cyber.success.withValues(alpha: 0.12),
        border: Border.all(color: Cyber.success.withValues(alpha: 0.62)),
        boxShadow: Cyber.glow(Cyber.success, alpha: 0.2, blur: 8, spread: -4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Cyber.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Cyber.label(10, color: Cyber.success, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

class _TrendingSkeleton extends StatelessWidget {
  const _TrendingSkeleton({required this.span});

  final CyberBentoSpan span;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _TrendSignalPainter(
        accent: Cyber.line,
        hardElevated: true,
      ),
      child: ClipPath(
        clipper: const _TrendSignalClipper(),
        child: ColoredBox(
          color: Cyber.panel,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 7,
                  color: Cyber.line.withValues(alpha: 0.65),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  height: 10,
                  color: Cyber.line.withValues(alpha: 0.48),
                ),
                const SizedBox(height: 8),
                FractionallySizedBox(
                  widthFactor: span == CyberBentoSpan.wide ? 0.42 : 0.72,
                  child: Container(
                    height: 8,
                    color: Cyber.line.withValues(alpha: 0.34),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendingUnavailable extends StatelessWidget {
  const _TrendingUnavailable({required this.kind});

  final TrendingTileKind kind;

  @override
  Widget build(BuildContext context) {
    return _TrendSignalShell(
      semanticsLabel: '${kind.name} signal unavailable',
      accent: Cyber.muted,
      tag: kind.name.toUpperCase(),
      onTap: () {},
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.signal_wifi_off_rounded, color: Cyber.muted),
            const SizedBox(height: 8),
            Text(
              'SIGNAL\nUNAVAILABLE',
              textAlign: TextAlign.center,
              style: Cyber.label(
                10,
                color: Cyber.muted,
                letterSpacing: 0.7,
              ).copyWith(height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendSignalClipper extends CustomClipper<Path> {
  const _TrendSignalClipper();

  @override
  Path getClip(Size size) => _trendSignalPath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _TrendSignalPainter extends CustomPainter {
  const _TrendSignalPainter({required this.accent, required this.hardElevated});

  final Color accent;
  final bool hardElevated;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _trendSignalPath(size);
    if (hardElevated) {
      canvas.drawPath(
        path.shift(const Offset(0, 6)),
        Paint()..color = accent.withValues(alpha: 0.22),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = accent.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _TrendSignalPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.hardElevated != hardElevated;
}

Path _trendSignalPath(Size size) {
  const cut = 12.0;
  const notch = 34.0;
  return Path()
    ..moveTo(cut, 0)
    ..lineTo(size.width - notch - 8, 0)
    ..lineTo(size.width - notch, 8)
    ..lineTo(size.width, 8)
    ..lineTo(size.width, size.height - cut)
    ..lineTo(size.width - cut, size.height)
    ..lineTo(8, size.height)
    ..lineTo(0, size.height - 8)
    ..lineTo(0, cut)
    ..close();
}

String _kickoffTime(DateTime kickoff) {
  final local = kickoff.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _shortDate(DateTime kickoff) {
  final formatted = formatKickoffSchedule(kickoff);
  final comma = formatted.indexOf(',');
  return comma == -1
      ? formatted.toUpperCase()
      : formatted.substring(comma + 1).trim().toUpperCase();
}
