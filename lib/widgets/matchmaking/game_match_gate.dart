import 'package:flutter/material.dart';

import 'game_kickoff_countdown.dart';
import 'game_matchmaking_config.dart';
import 'game_matchmaking_view.dart';
import 'matchmaking_arena_background.dart';

/// Orchestrates shared matchmaking → 3·2·1 kickoff → gameplay handoff.
class GameMatchGate extends StatefulWidget {
  const GameMatchGate({
    required this.config,
    required this.onReady,
    required this.onCancel,
    this.goLabel = 'GO!',
    super.key,
  });

  final GameMatchmakingConfig config;
  final VoidCallback onReady;
  final VoidCallback onCancel;

  /// Stamp after the countdown (Pitch Duel: `KICK OFF!`, Hoop: `TIP OFF!`).
  final String goLabel;

  @override
  State<GameMatchGate> createState() => _GameMatchGateState();
}

class _GameMatchGateState extends State<GameMatchGate> {
  bool _countdown = false;
  bool _cancelled = false;

  void _onMatched() {
    if (!mounted || _cancelled) return;
    setState(() => _countdown = true);
  }

  void _onCancel() {
    if (_cancelled) return;
    _cancelled = true;
    widget.onCancel();
  }

  void _onCountdownComplete() {
    if (!mounted || _cancelled) return;
    widget.onReady();
  }

  @override
  Widget build(BuildContext context) {
    if (_countdown) {
      return GameKickoffCountdown(
        goLabel: widget.goLabel,
        onComplete: _onCountdownComplete,
        background: MatchmakingArenaBackground(
          asset: widget.config.backgroundAsset,
          child: const SizedBox.expand(),
        ),
      );
    }
    return GameMatchmakingView(
      config: widget.config,
      onMatched: _onMatched,
      onCancel: _onCancel,
    );
  }
}
