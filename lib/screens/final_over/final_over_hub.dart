import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/final_over/final_over_cubit.dart';
import '../../blocs/final_over/final_over_state.dart';
import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../config/theme.dart';
import '../../models/final_over.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/player_level_badge.dart';
import '../match_history/match_history_pages.dart';
import 'final_over_deck_builder_screen.dart';
import 'final_over_match_screen.dart';

/// The Final Over lobby. Tier selection, primary CTA, and secondary links.
class FinalOverHub extends StatelessWidget {
  const FinalOverHub({required this.onExit, super.key});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      buildWhen: (p, c) =>
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
            if (!state.loaded) {
              return const Scaffold(
                backgroundColor: Cyber.bg,
                body: Center(
                  child: CircularProgressIndicator(color: Cyber.gold),
                ),
              );
            }
            final ready = gameState.finalOverDeckReady;
            return Scaffold(
              backgroundColor: Cyber.bg,
              appBar: ReactHeaderBar(
                title: 'FINAL OVER',
                subtitle: '// SIX-BALL CHASE',
                showTitle: false,
                onBack: onExit,
                rightSlot: PlayerLevelBadge(progression: gameState.progression),
              ),
              body: CyberBackground(
                animated: true,
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const CyberSlideUpFadeIn(child: _PitchStatusBar()),
                            const SizedBox(height: 14),
                            CyberSlideUpFadeIn(
                              delay: const Duration(milliseconds: 80),
                              child: _HeroRow(tier: state.tier),
                            ),
                            const SizedBox(height: 18),
                            CyberSlideUpFadeIn(
                              delay: const Duration(milliseconds: 160),
                              child: _RecordPanel(stats: state.stats),
                            ),
                            const SizedBox(height: 20),
                            const SectionLabel(label: 'CHASE TIER'),
                            const SizedBox(height: 10),
                            CyberSlideUpFadeIn(
                              delay: const Duration(milliseconds: 240),
                              child: _TierPicker(selected: state.tier),
                            ),
                            const SizedBox(height: 22),
                            CyberSlideUpFadeIn(
                              delay: const Duration(milliseconds: 320),
                              child: HudCtaButton(
                                label: ready ? 'TAKE GUARD' : 'BUILD SQUAD',
                                icon: Icons.sports_cricket_rounded,
                                accent: Cyber.gold,
                                helper: ready
                                    ? '${state.tier.label} // TARGET ${state.tier.range}'
                                    : 'PICK 3 OWNED BATTERS TO CHASE',
                                onTap: () => ready
                                    ? _startMatch(context, gameState)
                                    : _openDeckBuilder(context),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: CyberDealtCard(
                                    index: 0,
                                    child: CyberCtaButton(
                                      label: 'Cricket Deck',
                                      clip: false,
                                      onPressed: () =>
                                          _openDeckBuilder(context),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: CyberDealtCard(
                                    index: 1,
                                    child: CyberCtaButton(
                                      label: 'Match History',
                                      clip: false,
                                      onPressed: () => showMatchHistoryArchive(
                                        context,
                                        gameState.matchHistory,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openDeckBuilder(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FinalOverDeckBuilderScreen(onBack: () => Navigator.of(context).pop()),
      ),
    );
  }

  void _startMatch(BuildContext context, GameState gameState) {
    final cubit = context.read<FinalOverCubit>();
    final batsmanIds =
        gameState.deckFinalOverBatsmen.map((card) => card.id).toList();
    final config = cubit.buildMatch(batsmanIds: batsmanIds);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
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

class _PitchStatusBar extends StatelessWidget {
  const _PitchStatusBar();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Cyber.lime,
          boxShadow: Cyber.glow(Cyber.lime, alpha: 0.8, blur: 8),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'SYS://FINAL_OVER v1.0.0 — PITCH READY',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Cyber.label(8.5, color: Cyber.muted, letterSpacing: 1.4),
        ),
      ),
    ],
  );
}

class _HeroRow extends StatelessWidget {
  const _HeroRow({required this.tier});
  final FinalOverTier tier;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CyberPulse(
        period: const Duration(milliseconds: 2200),
        builder: (context, t) => Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Cyber.panel,
            border: Border.all(
              color: Cyber.gold.withValues(alpha: 0.4 + 0.35 * t),
              width: 1.6,
            ),
          ),
          child: const Icon(
            Icons.sports_cricket_rounded,
            color: Cyber.gold,
            size: 26,
          ),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FINAL OVER',
              style: Cyber.display(24, color: Colors.white, letterSpacing: 2),
            ),
            const SizedBox(height: 4),
            Text(
              'SIX BALLS. TWO WICKETS. ONE CHASE.',
              style: Cyber.label(8.5, color: Cyber.muted, letterSpacing: 1.4),
            ),
            const SizedBox(height: 8),
            CyberChip(label: tier.blurb, color: Cyber.gold),
          ],
        ),
      ),
    ],
  );
}

class _RecordPanel extends StatelessWidget {
  const _RecordPanel({required this.stats});
  final FinalOverStats stats;

  @override
  Widget build(BuildContext context) => CyberPanel(
    accent: Cyber.gold,
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
            18,
            color: Colors.white,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Cyber.label(7.5, color: Cyber.muted, letterSpacing: 1),
        ),
      ],
    ),
  );
}

class _TierPicker extends StatelessWidget {
  const _TierPicker({required this.selected});
  final FinalOverTier selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final tier in FinalOverTier.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () {
                playSound(SoundEffect.uiTap);
                HapticFeedback.selectionClick();
                context.read<FinalOverCubit>().selectTier(tier);
              },
              child: ClipPath(
                clipper: const HudChamferClipper(bigCut: 10, smallCut: 3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: tier == selected
                        ? Cyber.gold.withValues(alpha: 0.16)
                        : Cyber.panel.withValues(alpha: 0.8),
                    border: Border.all(
                      color: tier == selected
                          ? Cyber.gold.withValues(alpha: 0.9)
                          : Cyber.border,
                      width: tier == selected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        tier.label,
                        style: Cyber.display(
                          12,
                          color: tier == selected ? Cyber.gold : Cyber.muted,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tier.range,
                        style: Cyber.label(
                          8,
                          color: Cyber.muted,
                          letterSpacing: 1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (tier != FinalOverTier.values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
