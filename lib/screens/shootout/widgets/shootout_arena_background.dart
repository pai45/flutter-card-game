import 'package:flutter/material.dart';

import '../../../widgets/matchmaking/matchmaking_arena_background.dart';

/// Shared animated arena backdrop for the Penalty Shootout lobby and its
/// matchmaking cinematic.
class ShootoutArenaBackground extends StatelessWidget {
  const ShootoutArenaBackground({required this.child, super.key});

  final Widget child;

  static const assetPath = 'assets/backgrounds/penalty_arena.png';

  @override
  Widget build(BuildContext context) {
    return MatchmakingArenaBackground(asset: assetPath, child: child);
  }
}
