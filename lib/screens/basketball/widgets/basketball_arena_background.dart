import 'package:flutter/material.dart';

import '../../../widgets/matchmaking/matchmaking_arena_background.dart';

/// Shared animated arena backdrop for the Hoop Duel lobby (and any future
/// matchmaking cinematic that wants the same court bed).
class BasketballArenaBackground extends StatelessWidget {
  const BasketballArenaBackground({required this.child, super.key});

  final Widget child;

  static const assetPath = 'assets/backgrounds/hoop_arena.jpg';

  @override
  Widget build(BuildContext context) {
    return MatchmakingArenaBackground(asset: assetPath, child: child);
  }
}