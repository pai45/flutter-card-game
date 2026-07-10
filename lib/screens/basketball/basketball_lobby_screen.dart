import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/basketball/basketball_cubit.dart';
import '../../blocs/basketball/basketball_state.dart';
import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../data/basketball_teams.dart';
import '../../models/basketball.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/player_level_badge.dart';
import '../how_to_play/how_to_play_hub_screen.dart';
import '../match_history/match_history_pages.dart';
import 'basketball_match_screen.dart';

/// Hoop Duel lobby: lifetime court record, the 3-of-4 roster picker with a
/// starter tap, difficulty selector, HOW TO PLAY link and the TIP OFF CTA
/// (the screen's one glow). Selections persist on [BasketballStats].
class BasketballLobbyScreen extends StatelessWidget {
  const BasketballLobbyScreen({
    required this.onNavigate,
    required this.onEditDeck,
    super.key,
  });

  final ValueChanged<AppSection> onNavigate;
  final VoidCallback onEditDeck;

  void _tipOff(BuildContext context, GameState gameState) {
    final cubit = context.read<BasketballCubit>();
    if (!gameState.hoopDuelDeckReady) return;
    cubit.buildMatchFromRoster(
      rosterIds: gameState.deckBasketballPlayers
          .map((card) => card.id)
          .toList(),
      starterId: gameState.deckBasketballStarter!.id,
    );
    playSound(SoundEffect.playMatch);
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: BasketballMatchScreen(
            onExit: navigator.pop,
            onRematch: () {
              navigator.pop();
              _tipOff(context, gameState);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      buildWhen: (p, c) =>
          p.progression != c.progression ||
          p.deckBasketballPlayers != c.deckBasketballPlayers ||
          p.deckBasketballStarter != c.deckBasketballStarter ||
          p.ownedCardIds != c.ownedCardIds ||
          p.matchHistory != c.matchHistory,
      builder: (context, gameState) {
        return BlocBuilder<BasketballCubit, BasketballState>(
          builder: (context, state) {
            return Scaffold(
              backgroundColor: Cyber.bg,
              appBar: ReactHeaderBar(
                title: 'HOOP DUEL',
                subtitle: '// STREET 1-ON-1',
                onBack: () => onNavigate(AppSection.predictions),
                showTitle: false,
                rightSlot: PlayerLevelBadge(progression: gameState.progression),
              ),
              body: CyberBackground(
                animated: true,
                child: SafeArea(
                  top: false,
                  child: state.loading
                      ? const Center(
                          child: CircularProgressIndicator(color: Cyber.gold),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const CyberSlideUpFadeIn(
                                    child: _CourtStatusBar(),
                                  ),
                                  const SizedBox(height: 16),
                                  CyberSlideUpFadeIn(
                                    delay: const Duration(milliseconds: 80),
                                    offset: 24,
                                    child: _HeroRow(stats: state.stats),
                                  ),
                                  const SizedBox(height: 18),
                                  CyberSlideUpFadeIn(
                                    delay: const Duration(milliseconds: 160),
                                    offset: 20,
                                    child: _RecordPanel(stats: state.stats),
                                  ),
                                  const SizedBox(height: 20),
                                  const SectionLabel(label: 'DIFFICULTY'),
                                  const SizedBox(height: 10),
                                  CyberSlideUpFadeIn(
                                    delay: const Duration(milliseconds: 240),
                                    offset: 16,
                                    child: _DifficultyPicker(
                                      selected: state.difficulty,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  CyberSlideUpFadeIn(
                                    delay: const Duration(milliseconds: 320),
                                    offset: 14,
                                    child: Center(
                                      child: HowToPlayButton(
                                        mode: HowToPlayMode.hoopDuel,
                                        accent: Cyber.gold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const SectionLabel(label: 'TEAM JERSEY'),
                                  const SizedBox(height: 10),
                                  CyberSlideUpFadeIn(
                                    delay: const Duration(milliseconds: 360),
                                    offset: 16,
                                    child: _TeamPicker(
                                      selected: state.teamId,
                                      onSelect: (teamId) {
                                        HapticFeedback.selectionClick();
                                        playSound(SoundEffect.uiTap);
                                        context
                                            .read<BasketballCubit>()
                                            .setTeamId(teamId);
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  CyberSlideUpFadeIn(
                                    delay: const Duration(milliseconds: 400),
                                    offset: 22,
                                    child: Opacity(
                                      opacity: gameState.hoopDuelDeckReady
                                          ? 1
                                          : 0.5,
                                      child: IgnorePointer(
                                        ignoring: !gameState.hoopDuelDeckReady,
                                        child: HudCtaButton(
                                          label: 'TIP OFF',
                                          icon: Icons.sports_basketball,
                                          accent: Cyber.gold,
                                          tapSound: SoundEffect.playMatch,
                                          helper: gameState.hoopDuelDeckReady
                                              ? '${gameState.deckBasketballStarter!.name} STARTS · '
                                                    '${basketballDifficultyLabel(state.difficulty)} · '
                                                    '${basketballTeamById(state.teamId).name.toUpperCase()}'
                                              : 'BUILD A GUARD / WING / BIG ROSTER',
                                          onTap: () =>
                                              _tipOff(context, gameState),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CyberDealtCard(
                                          key: const ValueKey(
                                            'hoop-action-deck',
                                          ),
                                          index: 0,
                                          initialDelay: const Duration(
                                            milliseconds: 470,
                                          ),
                                          staggerMs: 85,
                                          flyDistance: 95,
                                          duration: const Duration(
                                            milliseconds: 500,
                                          ),
                                          child: CyberCtaButton(
                                            key: const ValueKey(
                                              'hoop-deck-builder-button',
                                            ),
                                            label: 'Deck Builder',
                                            clip: false,
                                            onPressed: onEditDeck,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: CyberDealtCard(
                                          key: const ValueKey(
                                            'hoop-action-history',
                                          ),
                                          index: 1,
                                          initialDelay: const Duration(
                                            milliseconds: 470,
                                          ),
                                          staggerMs: 85,
                                          flyDistance: 95,
                                          duration: const Duration(
                                            milliseconds: 500,
                                          ),
                                          child: CyberCtaButton(
                                            key: const ValueKey(
                                              'hoop-match-history-button',
                                            ),
                                            label: 'Match History',
                                            clip: false,
                                            onPressed: () =>
                                                showMatchHistoryArchive(
                                                  context,
                                                  gameState.matchHistory
                                                      .where(
                                                        (entry) =>
                                                            entry.isBasketball,
                                                      )
                                                      .toList(),
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
}

// ---------------------------------------------------------------------------
// Status strip + hero
// ---------------------------------------------------------------------------

class _CourtStatusBar extends StatelessWidget {
  const _CourtStatusBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: Cyber.success,
            shape: BoxShape.circle,
            boxShadow: Cyber.glow(
              Cyber.success,
              alpha: 0.6,
              blur: 8,
              spread: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'COURT OPEN',
          style: TextStyle(
            color: Cyber.success,
            fontFamily: Cyber.displayFont,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: Cyber.gold.withValues(alpha: 0.16),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'SYS://HOOP_DUEL v1.0.0',
          style: TextStyle(
            color: Cyber.muted,
            fontFamily: Cyber.displayFont,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _HeroRow extends StatelessWidget {
  const _HeroRow({required this.stats});

  final BasketballStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _HoopEmblem(size: 84),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HOOP DUEL',
                style: Cyber.display(23, letterSpacing: 1.2).copyWith(
                  shadows: [
                    Shadow(
                      color: Cyber.gold.withValues(alpha: 0.45),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'TWO HALVES · SHOT CLOCK · FIRST TO OUTSCORE',
                style: TextStyle(
                  color: Cyber.muted,
                  fontFamily: Cyber.displayFont,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: CyberChip(
                  label: stats.wins > 0
                      ? '${stats.wins} WINS'
                      : stats.games > 0
                      ? '${stats.games} GAMES IN'
                      : 'FRESH LEGS',
                  color: stats.wins > 0 ? Cyber.gold : Cyber.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HoopEmblem extends StatefulWidget {
  const _HoopEmblem({this.size = 84});

  final double size;

  @override
  State<_HoopEmblem> createState() => _HoopEmblemState();
}

class _HoopEmblemState extends State<_HoopEmblem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final pulse = 0.5 + 0.5 * math.sin(_pulse.value * math.pi);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size * 0.9,
                height: size * 0.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Cyber.bg.withValues(alpha: 0.5),
                  border: Border.all(
                    color: Cyber.gold.withValues(alpha: 0.26 + pulse * 0.12),
                  ),
                  boxShadow: Cyber.glow(
                    Cyber.gold,
                    alpha: 0.2 + pulse * 0.08,
                    blur: 18 + pulse * 4,
                    spread: -4,
                  ),
                ),
              ),
              Icon(
                Icons.sports_basketball,
                size: size * 0.46,
                color: Cyber.gold,
                shadows: [
                  Shadow(
                    color: Cyber.gold.withValues(alpha: 0.62),
                    blurRadius: 16 + pulse * 4,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RecordPanel extends StatelessWidget {
  const _RecordPanel({required this.stats});

  final BasketballStats stats;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.gold,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          _RecordStat(label: 'GAMES', value: '${stats.games}'),
          _RecordStat(
            label: 'WINS',
            value: '${stats.wins}',
            accent: Cyber.gold,
          ),
          _RecordStat(
            label: 'BEST WIN',
            value: stats.bestMargin > 0 ? '+${stats.bestMargin}' : '—',
            accent: Cyber.cyan,
          ),
          _RecordStat(
            label: 'DUNKS',
            value: '${stats.totalDunks}',
            accent: Cyber.magenta,
          ),
          _RecordStat(
            label: 'STREAK',
            value: '${stats.currentStreak}',
            accent: stats.currentStreak > 0 ? Cyber.success : Cyber.muted,
          ),
        ],
      ),
    );
  }
}

class _RecordStat extends StatelessWidget {
  const _RecordStat({
    required this.label,
    required this.value,
    this.accent = Colors.white,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: accent,
                fontFamily: Cyber.displayFont,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: Cyber.muted,
              fontFamily: Cyber.displayFont,
              fontSize: 7,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Difficulty
// ---------------------------------------------------------------------------

class _DifficultyPicker extends StatelessWidget {
  const _DifficultyPicker({required this.selected});

  final BasketballDifficulty selected;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BasketballCubit>();
    return Row(
      children: [
        for (final difficulty in BasketballDifficulty.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                playSound(SoundEffect.uiTap);
                cubit.setDifficulty(difficulty);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: difficulty == selected
                      ? Color.alphaBlend(
                          Cyber.gold.withValues(alpha: 0.14),
                          Cyber.panel,
                        )
                      : Cyber.panel,
                  border: Border.all(
                    color: difficulty == selected
                        ? Cyber.gold
                        : Cyber.border.withValues(alpha: 0.5),
                    width: difficulty == selected ? 1.6 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      basketballDifficultyLabel(difficulty),
                      style: Cyber.display(
                        11,
                        color: difficulty == selected
                            ? Cyber.gold
                            : Cyber.muted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(switch (difficulty) {
                      BasketballDifficulty.rookie => 'Forgiving',
                      BasketballDifficulty.pro => 'Balanced',
                      BasketballDifficulty.allStar => 'Ruthless',
                    }, style: const TextStyle(color: Cyber.muted, fontSize: 9)),
                  ],
                ),
              ),
            ),
          ),
          if (difficulty != BasketballDifficulty.values.last)
            const SizedBox(width: 8),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Team Jersey
// ---------------------------------------------------------------------------

class _TeamPicker extends StatelessWidget {
  const _TeamPicker({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final team in basketballTeams) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(team.id),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 52,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: team.id == selected
                          ? Color.alphaBlend(
                              team.primary.withValues(alpha: 0.12),
                              Cyber.panel,
                            )
                          : Cyber.panel,
                      border: Border.all(
                        color: team.id == selected
                            ? Colors.white
                            : Cyber.border.withValues(alpha: 0.5),
                        width: team.id == selected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 24,
                        height: 32,
                        decoration: BoxDecoration(
                          color: team.primary,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: team.secondary, width: 2),
                          boxShadow: team.id == selected ? [
                            BoxShadow(
                              color: team.primary.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ] : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    team.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: team.id == selected
                          ? Colors.white
                          : Cyber.muted,
                      fontFamily: Cyber.displayFont,
                      fontSize: 6.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (team != basketballTeams.last) const SizedBox(width: 6),
        ],
      ],
    );
  }
}
