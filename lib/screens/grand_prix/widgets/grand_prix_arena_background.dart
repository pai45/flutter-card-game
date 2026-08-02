import 'package:flutter/material.dart';

import '../../../widgets/matchmaking/matchmaking_arena_background.dart';

/// Shared animated arena backdrop for the Grand Prix Dash lobby.
class GrandPrixArenaBackground extends StatelessWidget {
  const GrandPrixArenaBackground({required this.child, super.key});

  final Widget child;

  static const assetPath = 'assets/backgrounds/gp_arena.jpg';

  @override
  Widget build(BuildContext context) {
    return MatchmakingArenaBackground(asset: assetPath, child: child);
  }
}