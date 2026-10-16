import 'dart:math' as math;
import 'package:card_game/design_system/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/final_over/final_over_cubit.dart';
import '../../blocs/final_over/final_over_state.dart';
import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../config/theme.dart';
import '../../models/final_over.dart';
import '../../models/progression.dart';
import '../../models/sport_match.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/player_level_badge.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../match_history/match_history_pages.dart';
import 'final_over_deck_builder_screen.dart';
import 'final_over_match_screen.dart';
import 'widgets/final_over_lobby_hero.dart';
import 'widgets/final_over_pixel_play_button.dart';

/// Illustration-first presentation. Existing Cubits still own every game rule.
class FinalOverHub extends StatefulWidget {
  const FinalOverHub({required this.onExit, super.key});
  final VoidCallback onExit;
  @override
  State<FinalOverHub> createState() => _FinalOverHubState();
}

class _FinalOverHubState extends State<FinalOverHub> {
  bool _covered = false;

  @override
  Widget build(BuildContext context) => BlocBuilder<GameBloc, GameState>(
    buildWhen: (p, c) =>
        p.loading != c.loading ||
        p.progression != c.progression ||
        p.matchHistory != c.matchHistory ||
        p.finalOverDeckReady != c.finalOverDeckReady ||
        p.ownedFinalOverKitIds != c.ownedFinalOverKitIds,
    builder: (context, gameState) {
      context.read<FinalOverCubit>().ensureEquippedKitOwned(
        gameState.ownedFinalOverKitIds,
      );
      return BlocBuilder<FinalOverCubit, FinalOverState>(
        builder: (context, state) {
          final ready = gameState.finalOverDeckReady;
          return Scaffold(
            backgroundColor: Cyber.bg,
            appBar: ReactHeaderBar(
              title: 'FINAL OVER',
              showTitle: false,
              onBack: widget.onExit,
              rightSlot: IconButton(
                tooltip: 'Final Over menu',
                onPressed: state.loaded && !gameState.loading
                    ? () => _utilities(gameState, state)
                    : null,
                icon: const Icon(Icons.more_vert, color: Cyber.muted),
              ),
            ),
            body: !state.loaded || gameState.loading
                ? const Center(
                    child: CircularProgressIndicator(color: Cyber.cyan),
                  )
                : SafeArea(
                    top: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Column(
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final scale =
                                      MediaQuery.textScalerOf(
                                        context,
                                      ).scale(16) /
                                      16;
                                  final introHeight =
                                      104 * math.max(1.0, scale);
                                  final heroHeight = math.max(
                                    200.0,
                                    constraints.maxHeight - introHeight,
                                  );
                                  return SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        SizedBox(
                                          height: heroHeight,
                                          child: FinalOverLobbyHero(
                                            paused: _covered,
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.fromLTRB(
                                            24,
                                            0,
                                            24,
                                            12,
                                          ),
                                          child: _LobbyIdentity(),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                              child: FinalOverPixelPlayButton(
                                key: const ValueKey('final-over-play'),
                                label: ready ? 'TAKE GUARD' : 'BUILD SQUAD',
                                onTap: () => ready
                                    ? _startMatch(context, gameState)
                                    : _openDeckBuilder(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          );
        },
      );
    },
  );

  Future<T?> _sheet<T>({required Widget body, required String title}) async {
    setState(() => _covered = true);
    try {
      return await showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .85,
          ),
          child: CyberKitSheet(
            onClose: () => Navigator.of(sheetContext).pop(),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Cyber.display(
                      StatOzTypography.p20,
                      color: AppTheme.whiteColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  body,
                ],
              ),
            ),
            footer: Padding(
              padding: const EdgeInsets.all(16),
              child: CyberActionButton(
                variant: CyberActionVariant.secondary,
                label: 'DONE',
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _covered = false);
    }
  }

  Future<void> _difficulty() async {
    final cubit = context.read<FinalOverCubit>();
    await _sheet<void>(
      title: 'CHOOSE YOUR CHASE',
      body: BlocBuilder<FinalOverCubit, FinalOverState>(
        bloc: cubit,
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final tier in FinalOverTier.values) ...[
              Semantics(
                selected: state.tier == tier,
                child: CyberActionButton(
                  variant: CyberActionVariant.secondary,
                  icon: state.tier == tier ? Icons.check : Icons.chevron_right,
                  label: '${tier.label}  ·  ${tier.range}',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    cubit.selectTier(tier);
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              state.tier.blurb,
              style: Cyber.bodyFor(
                context,
                StatOzTypography.p14,
                color: AppTheme.whiteColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Three overs',
              style: Cyber.bodyFor(
                context,
                StatOzTypography.p14,
                color: Cyber.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _utilities(GameState gameState, FinalOverState state) async {
    final action = await _sheet<String>(
      title: 'FINAL OVER',
      body: Builder(
        builder: (sheetContext) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: PlayerLevelBadge(
                progression: gameState.progression,
                track: ProgressTrack.finalOver,
              ),
            ),
            const SizedBox(height: 24),
            for (final item in [
              ('difficulty', 'Difficulty / ${state.tier.label}'),
              ('deck', 'Cricket Deck'),
              ('history', 'Match History'),
              ('leaderboard', 'Leaderboard'),
            ]) ...[
              CyberActionButton(
                variant: CyberActionVariant.secondary,
                label: item.$2,
                onPressed: () => Navigator.of(sheetContext).pop(item.$1),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'difficulty') {
      await _difficulty();
    } else if (action == 'deck') {
      _openDeckBuilder(context);
    } else if (action == 'history') {
      showGameMatchHistory(
        context,
        gameLabel: 'Final Over',
        history: gameState.matchHistory
            .where((entry) => entry.isFinalOver)
            .toList(growable: false),
        career: _RecordPanel(stats: state.stats),
      );
    } else if (action == 'leaderboard') {
      final navigator = Navigator.of(context);
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => LeaderboardScreen(
            initialType: LeaderboardType.games,
            initialSport: Sport.cricket,
            initialMode: GameMode.featured,
            onClose: navigator.pop,
            onNavigate: (_) => navigator.pop(),
          ),
        ),
      );
    }
  }

  void _openDeckBuilder(BuildContext context) {
    Navigator.of(context).push(
      gamePageRoute<void>(
        builder: (_) => FinalOverDeckBuilderScreen(
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _startMatch(BuildContext context, GameState gameState) {
    final cubit = context.read<FinalOverCubit>();
    final config = cubit.buildMatch(
      batsmanIds: gameState.deckFinalOverBatsmen
          .map((card) => card.id)
          .toList(),
    );
    Navigator.of(context).push(
      gamePageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: FinalOverMatchScreen(
            config: config,
            onExit: () {
              Navigator.of(context).pop();
              cubit.backToLobby();
            },
          ),
        ),
      ),
    );
  }
}

class _LobbyIdentity extends StatelessWidget {
  const _LobbyIdentity();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 20),
    child: LayoutBuilder(
      builder: (context, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'FINAL OVER',
            textAlign: TextAlign.center,
            style: Cyber.display(
              box.maxWidth < 290 ? StatOzTypography.p28 : StatOzTypography.p32,
              color: AppTheme.whiteColor,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Three overs. One chase.',
            textAlign: TextAlign.center,
            style: Cyber.bodyFor(
              context,
              StatOzTypography.p14,
              color: Cyber.muted,
            ),
          ),
        ],
      ),
    ),
  );
}

class _RecordPanel extends StatelessWidget {
  const _RecordPanel({required this.stats});
  final FinalOverStats stats;

  @override
  Widget build(BuildContext context) => CyberPanel(
    accent: Cyber.cyan,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel(label: 'CAREER'),
        const SizedBox(height: 12),
        Row(
          children: [
            _RecordStat('BEST', '${stats.bestScore}'),
            _RecordStat('WON', '${stats.wins}'),
            _RecordStat('WIN RATE', stats.winRate),
            _RecordStat('SIXES', '${stats.sixes}'),
            _RecordStat('BEST ★', '${stats.bestStars}'),
          ],
        ),
      ],
    ),
  );
}

class _RecordStat extends StatelessWidget {
  const _RecordStat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Cyber.display(
            StatOzTypography.p18,
            color: Colors.white,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Cyber.label(
            StatOzTypography.p7_5,
            color: Cyber.muted,
            letterSpacing: 1,
          ),
        ),
      ],
    ),
  );
}
