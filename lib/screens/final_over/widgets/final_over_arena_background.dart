import 'package:flutter/material.dart';

import '../../../widgets/matchmaking/matchmaking_arena_background.dart';

/// Shared animated arena backdrop for the Final Over lobby.
class FinalOverArenaBackground extends StatelessWidget {
  const FinalOverArenaBackground({required this.child, super.key});

  final Widget child;

  static const assetPath = 'assets/backgrounds/final_over_arena.jpg';

  @override
  Widget build(BuildContext context) {
    return MatchmakingArenaBackground(asset: assetPath, child: child);
  }
}