import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/avatar_frame_option.dart';

/// One side of the matchmaking face-off (player or rival).
class MatchmakingFighter {
  const MatchmakingFighter({
    required this.name,
    required this.avatarAsset,
    this.badge,
    this.frame,
    this.accent,
  });

  final String name;
  final String avatarAsset;
  final String? badge;
  final AvatarFrameOption? frame;

  /// Banner accent; defaults to cyan (player) / gold (opponent) at the call site.
  final Color? accent;
}

/// Configurable identity + chrome for the shared matchmaking cinematic.
class GameMatchmakingConfig {
  const GameMatchmakingConfig({
    required this.title,
    required this.player,
    required this.opponent,
    this.subtitle = '// MATCHMAKING',
    this.queueLabel = 'SCANNING GLOBAL QUEUE',
    this.backgroundAsset,
    this.searchAccent = Cyber.cyan,
    this.lockedAccent = Cyber.gold,
  });

  /// Header title, e.g. `PITCH DUEL`.
  final String title;

  /// Header subtitle under the title.
  final String subtitle;

  /// Telemetry line under the search progress bar.
  final String queueLabel;

  /// Optional arena art (`assets/backgrounds/...`). Null = gradient bed only.
  final String? backgroundAsset;

  final MatchmakingFighter player;
  final MatchmakingFighter opponent;

  final Color searchAccent;
  final Color lockedAccent;
}
