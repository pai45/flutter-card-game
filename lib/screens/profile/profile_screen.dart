import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/prediction/prediction_state.dart';
import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../models/match.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/landing_bottom_navigation.dart';
import '../../widgets/player_level_badge.dart';
import '../deck/all_cards_screen.dart';
import '../deck/deck_builder_screen.dart';
import '../how_to_play/how_to_play_screen.dart';
import '../shop/shop_screen.dart' show CoinIcon;

/// PROFILE tab — player identity, balances, a combined record across the two
/// game modes (predictions + the card game), and entry points to the card-game
/// utilities that left the global nav (deck builder, all cards, how to play).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberPlainBackground(child: SizedBox.expand()),
          ),
          SafeArea(
            child: BlocBuilder<GameBloc, GameState>(
              builder: (context, game) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _IdentityCard(game: game),
                    const SizedBox(height: 14),
                    _BalancesRow(coins: game.coins),
                    const SizedBox(height: 14),
                    _StatsGrid(game: game),
                    const SizedBox(height: 14),
                    SectionLabel(label: 'CARD GAME'),
                    const SizedBox(height: 10),
                    _LinkTile(
                      icon: Icons.dashboard_customize,
                      label: 'DECK BUILDER',
                      onTap: () => _push(
                        context,
                        (nav) => DeckBuilderScreen(onNavigate: nav),
                      ),
                    ),
                    _LinkTile(
                      icon: Icons.style,
                      label: 'ALL CARDS',
                      onTap: () => _push(
                        context,
                        (nav) => AllCardsScreen(onNavigate: nav),
                      ),
                    ),
                    _LinkTile(
                      icon: Icons.menu_book,
                      label: 'HOW TO PLAY',
                      onTap: () => _push(
                        context,
                        (nav) => HowToPlayScreen(onNavigate: nav),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: LandingBottomNavigation(
        selectedIndex: 3,
        onNavigate: onNavigate,
      ),
    );
  }

  void _push(
    BuildContext context,
    Widget Function(ValueChanged<AppSection>) builder,
  ) {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => builder((_) => navigator.pop())),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      glow: true,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: Cyber.panelGradient(Cyber.cyan),
              border: Border.all(color: Cyber.cyan.withValues(alpha: 0.6)),
            ),
            child: const Icon(Icons.person, color: Cyber.cyan, size: 34),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PLAYER', style: Cyber.display(20, letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(
                  'LVL ${game.progression.playerLevel} · ${game.progression.totalXP} XP',
                  style: Cyber.label(11, color: Cyber.muted, letterSpacing: 1),
                ),
              ],
            ),
          ),
          PlayerLevelBadge(progression: game.progression),
        ],
      ),
    );
  }
}

class _BalancesRow extends StatelessWidget {
  const _BalancesRow({required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BalanceTile(
            icon: CoinIcon(size: 22),
            label: 'COINS',
            value: '$coins',
            accent: Cyber.gold,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BalanceTile(
            icon: const Icon(
              Icons.change_history,
              color: Cyber.violet,
              size: 22,
            ),
            label: 'GEMS',
            value: '0',
            accent: Cyber.violet,
          ),
        ),
      ],
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final Widget icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: accent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Cyber.display(
                  18,
                  letterSpacing: 0.5,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              Text(
                label,
                style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final wins = game.matchHistory.where(_isWin).length;
    final played = game.matchHistory.length;
    return BlocBuilder<PredictionCubit, PredictionState>(
      builder: (context, pred) {
        return Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'PREDICTIONS',
                value: '${pred.predictionsMade}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: 'CORRECT',
                value: '${pred.correctPredictions}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(label: 'DUEL W/P', value: '$wins/$played'),
            ),
          ],
        );
      },
    );
  }

  static bool _isWin(MatchHistoryEntry e) {
    if (e.playerScore != e.opponentScore) {
      return e.playerScore > e.opponentScore;
    }
    return (e.penaltyPlayerScore ?? 0) > (e.penaltyOpponentScore ?? 0);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.5),
        border: Border.all(color: Cyber.line),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Cyber.display(
              20,
              letterSpacing: 0.5,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Cyber.panel.withValues(alpha: 0.5),
            border: Border.all(color: Cyber.line),
          ),
          child: Row(
            children: [
              Icon(icon, color: Cyber.cyan, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: Cyber.label(12, letterSpacing: 1)),
              ),
              const Icon(Icons.chevron_right, color: Cyber.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
