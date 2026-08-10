import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/football_chess/football_chess_cubit.dart';
import '../../../blocs/football_chess/football_chess_state.dart';
import '../../../config/theme.dart';
import '../../../models/football_chess.dart';
import '../../../widgets/cyber/cyber_toss_coin.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Football Chess adapter for the shared Pitch Duel coin-toss presentation.
/// The toss winner still kicks off automatically once the coin has landed.
class FootballChessTossPhase extends StatefulWidget {
  const FootballChessTossPhase({
    required this.tossKey,
    required this.onCall,
    required this.onBeginPlay,
    required this.onQuit,
    super.key,
  });

  final GlobalKey tossKey;
  final ValueChanged<CoinSide> onCall;
  final VoidCallback onBeginPlay;
  final VoidCallback onQuit;

  @override
  State<FootballChessTossPhase> createState() => _FootballChessTossPhaseState();
}

class _FootballChessTossPhaseState extends State<FootballChessTossPhase> {
  Timer? _advanceTimer;
  bool _advanceScheduled = false;

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  void _onLanded() {
    if (_advanceScheduled || !mounted) return;
    _advanceScheduled = true;
    final delay = MediaQuery.disableAnimationsOf(context)
        ? const Duration(milliseconds: 650)
        : const Duration(milliseconds: 1300);
    _advanceTimer = Timer(delay, () {
      if (mounted) widget.onBeginPlay();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FootballChessCubit, FootballChessState>(
      buildWhen: (previous, current) =>
          (previous.match?.phase == ChessMatchPhase.toss) !=
              (current.match?.phase == ChessMatchPhase.toss) ||
          previous.match?.eventTick != current.match?.eventTick,
      builder: (context, state) {
        final match = state.match;
        if (match == null || match.phase != ChessMatchPhase.toss) {
          return const SizedBox.shrink();
        }
        return CyberCoinTossPhase(
          result: match.tossResult?.name,
          won: match.playerWonToss,
          call: match.tossCall?.name,
          prompt: 'CALL THE TOSS TO DECIDE KICKOFF',
          onQuit: widget.onQuit,
          onCall: (call) => widget.onCall(
            call == CoinSide.heads.name ? CoinSide.heads : CoinSide.tails,
          ),
          onLanded: _onLanded,
          coinTargetKey: widget.tossKey,
          resolvedContent: _FootballChessTossResult(match: match),
        );
      },
    );
  }
}

class _FootballChessTossResult extends StatelessWidget {
  const _FootballChessTossResult({required this.match});

  final ChessMatch match;

  @override
  Widget build(BuildContext context) {
    final playerWon = match.playerWonToss == true;
    final accent = playerWon ? Cyber.cyan : Cyber.danger;
    final winner = playerWon ? 'YOU' : match.opponentName.toUpperCase();
    return Column(
      children: [
        Text(
          '$winner WON THE TOSS',
          textAlign: TextAlign.center,
          style: Cyber.display(26, color: accent, letterSpacing: 2).copyWith(
            shadows: [
              Shadow(color: accent.withValues(alpha: 0.5), blurRadius: 18),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          playerWon
              ? 'YOU KICK OFF'
              : '${match.opponentName.toUpperCase()} KICKS OFF',
          textAlign: TextAlign.center,
          style: Cyber.body(12, color: Cyber.muted),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Text(
                'KICKOFF PROTOCOL LOCKED',
                style: Cyber.label(10, color: accent, letterSpacing: 2),
              ),
              const SizedBox(height: 10),
              CyberProgressBar(value: 1, accent: accent, height: 3, radius: 2),
            ],
          ),
        ),
      ],
    );
  }
}
