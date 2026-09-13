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

/// A market is "hot" when its leader's latest tick swung by at least this
/// many percentage points — calibrated against the live catalog so the pulse
/// stays rare (only a genuine mover crosses it), per the glow rule.
const int _kHotDeltaThreshold = 5;

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
    final catalogFixtureIds = matchTrendingCatalog
        .where(
          (item) =>
              item.enabled &&
              (item.kind == TrendingTileKind.match ||
                  item.kind == TrendingTileKind.predict),
        )
        .map((item) => item.sourceId)
        .toList(growable: false);

    // Paint the curated feature tiles as soon as their known IDs resolve. The
    // wider sport scan can include sizeable bundled ESPN snapshots, and should
    // not hold the first Trends row in a skeleton state while it completes.
    final initialCatalogFixtures = await cubit.resolveCatalogFixtures(
      catalogFixtureIds,
    );
    if (!mounted) return;
    setState(() {
      _catalogFixtures = initialCatalogFixtures;
      _fixtureScanRunning = false;
    });

    // PredictionCubit merges each sport result into its current fixture
    // snapshot. Keep these catalog-scoped loads ordered so concurrent
    // completions cannot replace fixtures added by another sport.
    for (final sport in matchTrendingSports) {
      await cubit.loadSport(sport);
    }
    final catalogFixtures = await cubit.resolveCatalogFixtures(
      catalogFixtureIds,
    );
    if (!mounted) return;
    setState(() {
      _catalogFixtures = {..._catalogFixtures, ...catalogFixtures};
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
                  gap: 10,
                  rowGap: 14,
                  rowHeightFactor: 1.05,
                  minRowHeight: 150,
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
            isFavorite: predictionState.isFavoriteMatch(match),
            onTap: () => widget.onOpenMatch(match),
          );
        }
        final prediction = predictionState.predictionSummaryForMatch(match.id);
        final quiz = predictionState.quizzes.values
            .where((quiz) => quiz.matchId == match.id)
            .firstOrNull;
        return _TrendingPredictCard(
          match: match,
          leagueLabel:
              predictionState.leagueFor(match.leagueId)?.shortCode ??
              match.leagueId.toUpperCase(),
          hasPrediction: prediction != null,
          potentialXp: quiz?.maxReward ?? match.rewardXp,
          volumeOz: seededMatchVolumeOz(match.id),
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
    required this.isFavorite,
    required this.onTap,
  });

  final SportMatch match;
  final String leagueLabel;
  final int potentialXp;
  final int volumeOz;

  /// Whether one of the player's followed clubs is in this fixture — it takes
  /// over the tile's corner tag (LIVE still wins).
  final bool isFavorite;
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
    final scoreOrTime = live ? detail : centerLabel;
    final contextLabel = live
        ? centerLabel
        : finished
        ? leagueLabel
        : detail;
    final statusTag = live
        ? 'LIVE MATCH'
        : isFavorite
        ? 'YOUR CLUB'
        : finished
        ? 'FINISHED'
        : 'UPCOMING';
    final footerLabel = live
        ? 'IN PLAY'
        : finished
        ? 'FULL TIME'
        : '+${potentialXp > 0 ? potentialXp : 50} XP MISSION';

    return _TrendSignalShell(
      semanticsLabel:
          '${match.home.name} versus ${match.away.name}, $scoreOrTime',
      accent: live ? Cyber.success : module.accent,
      tag: statusTag,
      live: live,
      scoreboard: true,
      hardElevated: true,
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 30, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _TeamLockup(
                      team: match.home,
                      sport: match.sport,
                      competition: match.leagueId,
                    ),
                  ),
                  SizedBox(
                    width: 88,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          scoreOrTime,
                          maxLines: 1,
                          style:
                              Cyber.display(
                                live || finished ? 23 : 19,
                                color: live ? Cyber.success : Colors.white,
                                letterSpacing: 0.5,
                              ).copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          contextLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.label(
                            10,
                            color: Cyber.muted,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _TeamLockup(
                      team: match.away,
                      sport: match.sport,
                      competition: match.leagueId,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          CyberTelemetryFooter(
            key: ValueKey('trending-match-footer-${match.id}'),
            leading: footerLabel,
            trailing: 'VOL ${formatOzCompact(volumeOz)} OZ',
            leadingColor: live ? Cyber.success : Cyber.cyan,
            leadingIcon: module.icon,
            leadingIconColor: module.accent,
          ),
        ],
      ),
    );
  }
}

class _TeamLockup extends StatelessWidget {
  const _TeamLockup({
    required this.team,
    required this.sport,
    this.competition,
    this.alignEnd = false,
  });

  final SportTeam team;
  final Sport sport;
  final String? competition;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        TeamLogo(
          team: team,
          width: 40,
          height: 40,
          sport: sport,
          competition: competition,
        ),
        const SizedBox(height: 4),
        Text(
          team.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: Cyber.body(
            _kTrendingTileHeadingSize,
            weight: FontWeight.w800,
            height: 1.05,
          ),
        ),
      ],
    );
  }
}

class _TrendingPredictCard extends StatelessWidget {
  const _TrendingPredictCard({
    required this.match,
    required this.leagueLabel,
    required this.hasPrediction,
    required this.potentialXp,
    required this.volumeOz,
    required this.onTap,
  });

  final SportMatch match;
  final String leagueLabel;
  final bool hasPrediction;
  final int potentialXp;
  final int volumeOz;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final module = sportModuleFor(match.sport);
    return _TrendSignalShell(
      semanticsLabel: 'Predict ${match.home.name} versus ${match.away.name}',
      accent: Cyber.cyan,
      tag: 'PREDICT',
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
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
                        width: 36,
                        height: 36,
                        sport: match.sport,
                        competition: match.leagueId,
                      ),
                      Text('VS', style: Cyber.display(10, color: Cyber.cyan)),
                      TeamLogo(
                        team: match.away,
                        width: 36,
                        height: 36,
                        sport: match.sport,
                        competition: match.leagueId,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '${match.home.shortName} // ${match.away.shortName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.display(
                      _kTrendingTileHeadingSize,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          CyberTelemetryFooter(
            key: ValueKey('trending-predict-footer-${match.id}'),
            leading: hasPrediction
                ? 'ANSWERS LOCKED'
                : '+${potentialXp > 0 ? potentialXp : 50} XP',
            trailing: 'VOL ${formatOzCompact(volumeOz)} OZ',
            leadingColor: hasPrediction ? Cyber.success : Cyber.cyan,
          ),
        ],
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
    final marketAccent = future ? Cyber.gold : Cyber.lime;
    final module = sportModuleFor(sport);
    final leader = market.leadingOutcome;
    final delta = market.latestDeltaFor(leader.id);
    final hot =
        delta != null &&
        delta.abs() >= _kHotDeltaThreshold &&
        !market.isResultKnown;
    return _TrendSignalShell(
      semanticsLabel: market.question,
      // Type tags are navigational chrome, so FUTURE and PICK follow the
      // shared cyan action treatment. Market values retain their own signal
      // colour below.
      accent: Cyber.cyan,
      tag: future ? 'FUTURE' : 'PICK',
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = !tall && constraints.maxHeight < 160;
          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: compact
                      ? const EdgeInsets.fromLTRB(10, 34, 10, 4)
                      : const EdgeInsets.fromLTRB(12, 36, 12, 4),
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
                                color: Cyber.muted,
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
                            ? 2
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
                      if (tall) ...[
                        const SizedBox(height: 16),
                        for (final outcome in market.outcomes.take(4)) ...[
                          _OutcomeSignal(
                            label: outcome.label,
                            value: outcome.probabilityPercent,
                            accent: outcome.id == leader.id
                                ? marketAccent
                                : Cyber.muted,
                          ),
                          const SizedBox(height: 7),
                        ],
                      ] else ...[
                        const Spacer(),
                        if (!compact) ...[
                          Text(
                            leader.label.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Cyber.display(10, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${leader.probabilityPercent}%',
                              style:
                                  Cyber.display(
                                    compact ? 18 : 22,
                                    color: marketAccent,
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
                                child: _DeltaBadge(delta: delta, hot: hot),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              CyberTelemetryFooter(
                key: ValueKey('trending-market-footer-${market.id}'),
                leading: market.isResultKnown ? 'SETTLED' : 'MARKET OPEN',
                trailing: 'VOL ${formatOzCompact(market.volumeOz)} OZ',
                leadingColor: market.isResultKnown ? Cyber.muted : Cyber.cyan,
              ),
            ],
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
        CyberProgressBar(
          value: value / 100,
          accent: accent,
          height: 4,
          radius: 2,
        ),
      ],
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.delta, required this.hot});

  final int delta;
  final bool hot;

  @override
  Widget build(BuildContext context) {
    final color = delta >= 0 ? Cyber.success : Cyber.danger;
    final text = Text(
      '${delta >= 0 ? '+' : ''}$delta',
      style: Cyber.label(
        10,
        color: color,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
    if (!hot) return text;
    return CyberPulse(
      period: const Duration(milliseconds: 900),
      builder: (context, t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10 + 0.06 * t),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4 + 0.35 * t)),
          boxShadow: Cyber.glow(
            color,
            alpha: 0.12 + 0.18 * t,
            blur: 7,
            spread: -3,
          ),
        ),
        child: text,
      ),
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
    this.scoreboard = false,
    this.hardElevated = true,
  });

  final String semanticsLabel;
  final Color accent;
  final String tag;
  final VoidCallback onTap;
  final Widget child;
  final bool live;
  final bool scoreboard;
  final bool hardElevated;

  @override
  Widget build(BuildContext context) {
    const chromeColor = Cyber.cyan;
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
            accent: chromeColor,
            hardElevated: hardElevated,
            scoreboard: scoreboard,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipPath(
                clipper: _TrendSignalClipper(scoreboard: scoreboard),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Color.alphaBlend(
                        chromeColor.withValues(alpha: 0.08),
                        Cyber.panel,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 14,
                      right: 14,
                      child: Container(
                        height: 2,
                        color: chromeColor.withValues(alpha: 0.8),
                      ),
                    ),
                    if (!scoreboard)
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
              if (scoreboard)
                Positioned(
                  top: 4,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _ScoreboardStatusTag(
                      label: tag,
                      color: accent,
                      live: live,
                    ),
                  ),
                ),
            ],
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

class _ScoreboardStatusTag extends StatelessWidget {
  const _ScoreboardStatusTag({
    required this.label,
    required this.color,
    required this.live,
  });

  final String label;
  final Color color;
  final bool live;

  @override
  Widget build(BuildContext context) {
    if (live) return _LiveSignalBadge(label: label);
    return Text(
      label,
      style: Cyber.label(10, color: color, letterSpacing: 0.7),
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
        accent: Cyber.cyan,
        hardElevated: true,
      ),
      child: ClipPath(
        clipper: const _TrendSignalClipper(),
        child: ColoredBox(
          color: Color.alphaBlend(
            Cyber.cyan.withValues(alpha: 0.08),
            Cyber.panel,
          ),
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
  const _TrendSignalClipper({this.scoreboard = false});

  final bool scoreboard;

  @override
  Path getClip(Size size) => _trendSignalPath(size, scoreboard: scoreboard);

  @override
  bool shouldReclip(covariant _TrendSignalClipper oldClipper) =>
      oldClipper.scoreboard != scoreboard;
}

class _TrendSignalPainter extends CustomPainter {
  const _TrendSignalPainter({
    required this.accent,
    required this.hardElevated,
    this.scoreboard = false,
  });

  final Color accent;
  final bool hardElevated;
  final bool scoreboard;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _trendSignalPath(size, scoreboard: scoreboard);
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
      oldDelegate.accent != accent ||
      oldDelegate.hardElevated != hardElevated ||
      oldDelegate.scoreboard != scoreboard;
}

Path _trendSignalPath(Size size, {required bool scoreboard}) {
  const cut = 12.0;
  const notch = 34.0;
  final path = Path()..moveTo(cut, 0);
  if (scoreboard) {
    final center = size.width / 2;
    const notchHalf = 54.0;
    path
      ..lineTo(center - notchHalf - 8, 0)
      ..lineTo(center - notchHalf, 16)
      ..lineTo(center + notchHalf, 16)
      ..lineTo(center + notchHalf + 8, 0)
      ..lineTo(size.width, 0);
  } else {
    path
      ..lineTo(size.width - notch - 8, 0)
      ..lineTo(size.width - notch, 8)
      ..lineTo(size.width, 8);
  }
  return path
    ..lineTo(size.width, size.height - cut)
    ..lineTo(size.width - cut, size.height)
    ..lineTo(0, size.height)
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
