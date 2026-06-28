import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/football_chess/football_chess_cubit.dart';
import '../../blocs/football_chess/football_chess_state.dart';
import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../config/theme.dart';
import '../../data/random_opponent_names.dart';
import '../../models/cards.dart';
import '../../models/football_chess.dart';
import '../../models/progression.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import 'football_chess_match_screen.dart';
import 'football_chess_matchmaking_screen.dart';

/// Pre-match lobby: lifetime record, the 5-a-side formation picker, and KICKOFF.
class FootballChessLobbyScreen extends StatefulWidget {
  const FootballChessLobbyScreen({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  State<FootballChessLobbyScreen> createState() =>
      _FootballChessLobbyScreenState();
}

class _FootballChessLobbyScreenState extends State<FootballChessLobbyScreen> {
  ChessFormation _formation = ChessFormation.box;

  final Random _rng = Random();

  /// Gate on a ready deck, build the match (fresh shuffled CPU squad), then run
  /// the matchmaking search → card face-off → kickoff into the live pitch.
  void _launch(ChessFormation formation) {
    final game = context.read<GameBloc>().state;
    if (!_deckReady(game)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Build a full 5-a-side deck first (2 ATK · 2 DEF · GK).'),
        ),
      );
      return;
    }

    final squad = <PlayerCard>[
      ...game.deckAttackers,
      ...game.deckDefenders,
      game.deckKeeper!,
    ];
    final level = game.progression.playerLevel;
    final opponentName = randomOpponentName();
    final opponentLevel = (level + _rng.nextInt(4) - 1).clamp(1, 99);
    final opponent = generateShootoutOpponent(
      opponentLevel,
      attackers,
      defenders,
      goalkeepers,
    );

    final cubit = context.read<FootballChessCubit>();
    final match = cubit.buildMatch(
      playerSquad: squad,
      formation: formation,
      opponentSquad: opponent.shooters,
      opponentName: opponentName,
      opponentLevel: opponentLevel,
    );

    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => FootballChessMatchmakingScreen(
          playerLevel: level,
          playerSquad: squad,
          opponentName: opponentName,
          opponentLevel: opponentLevel,
          opponentSquad: opponent.shooters,
          onCancel: navigator.pop,
          onKickoff: () {
            cubit.startMatch(match);
            navigator.pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: FootballChessMatchScreen(
                    onExit: navigator.pop,
                    onPlayAgain: () {
                      navigator.pop();
                      _launch(formation);
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  bool _deckReady(GameState s) =>
      s.deckAttackers.length >= 2 &&
      s.deckDefenders.length >= 2 &&
      s.deckKeeper != null;

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: '5v5 Football Chess',
      subtitle: 'TACTICAL SQUAD DUEL',
      leading: _BackButton(onTap: widget.onBack),
      child: BlocBuilder<FootballChessCubit, FootballChessState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(
              child: CircularProgressIndicator(color: Cyber.cyan),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _StatsHeader(stats: state.stats),
              const SizedBox(height: 20),
              Text(
                'CHOOSE YOUR SHAPE',
                style: Cyber.label(11, color: Cyber.muted, letterSpacing: 1.8),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  for (final f in ChessFormation.values)
                    _FormationTile(
                      formation: f,
                      selected: f == _formation,
                      onTap: () {
                        playSound(SoundEffect.cardSelect);
                        setState(() => _formation = f);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),
              HudCtaButton(
                label: 'FIND MATCH',
                icon: Icons.sports_soccer,
                tapSound: SoundEffect.playMatch,
                onTap: () => _launch(_formation),
              ),
              const SizedBox(height: 12),
              Text(
                'Chess on a pitch: take turns, move a player or the ball, '
                'win it back by position, and shoot from their half to score. '
                'XP only — coins stay in the shop.',
                textAlign: TextAlign.center,
                style: Cyber.body(11).copyWith(color: Cyber.muted, height: 1.5),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.stats});

  final FootballChessStats stats;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _stat('WINS', stats.wins, Cyber.gold),
          _divider(),
          _stat('LOSSES', stats.losses, Cyber.danger),
          _divider(),
          _stat('DRAWS', stats.draws, Cyber.amber),
          _divider(),
          _stat('STREAK', stats.currentStreak, Cyber.cyan),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 34, color: Cyber.border.withValues(alpha: 0.6));

  Widget _stat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontFamily: Cyber.displayFont,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.2)),
      ],
    );
  }
}

class _FormationTile extends StatelessWidget {
  const _FormationTile({
    required this.formation,
    required this.selected,
    required this.onTap,
  });

  final ChessFormation formation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? Cyber.cyan : Cyber.border;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (selected ? Cyber.cyan : Cyber.panel2).withValues(alpha: 0.18),
              Cyber.panel.withValues(alpha: 0.95),
            ],
          ),
          border: Border.all(
            color: accent.withValues(alpha: selected ? 1 : 0.6),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(2),
          boxShadow: selected ? Cyber.glow(Cyber.cyan) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  formation.code,
                  style: TextStyle(
                    fontFamily: Cyber.displayFont,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: selected ? Cyber.cyan : Colors.white,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                if (selected)
                  const Icon(Icons.check_circle, size: 16, color: Cyber.cyan),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              formation.label,
              style: Cyber.label(11,
                  color: selected ? Cyber.cyan : Cyber.muted, letterSpacing: 1.4),
            ),
            const Spacer(),
            Text(
              formation.blurb,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Cyber.body(10).copyWith(color: Cyber.muted, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        playSound(SoundEffect.uiTap);
        onTap();
      },
      child: const Center(
        child: Icon(Icons.arrow_back_ios_new, size: 18, color: Cyber.cyan),
      ),
    );
  }
}
