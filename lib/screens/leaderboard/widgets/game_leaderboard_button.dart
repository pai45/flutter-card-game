import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/enums.dart';
import '../../../config/theme.dart';
import '../../../models/sport_match.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_tooltip.dart';
import '../leaderboard_screen.dart';
import 'rank_widgets.dart' show cutCornerDecoration;

/// Re-exported so a lobby can name its board without importing the whole
/// leaderboard screen.
export '../leaderboard_screen.dart' show GameMode;

/// Top-bar action every game lobby carries: opens the leaderboard already
/// filtered to that game's board, pushed over the lobby so BACK returns you to
/// the tee-up instead of dumping you out of the game.
///
/// Persistent chrome, so it never glows — flat plate, accent border only.
class GameLeaderboardButton extends StatelessWidget {
  const GameLeaderboardButton({
    required this.sport,
    required this.mode,
    this.accent = Cyber.cyan,
    this.onNavigate,
    super.key,
  });

  final Sport sport;
  final GameMode mode;
  final Color accent;

  /// The lobby's own section navigation, so leaving the board for the shop or
  /// a profile still works. Null where the lobby has no section handler — the
  /// board then just closes.
  final ValueChanged<AppSection>? onNavigate;

  void _open(BuildContext context) {
    playSound(SoundEffect.uiTap);
    HapticFeedback.selectionClick();
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => LeaderboardScreen(
          initialType: LeaderboardType.games,
          initialSport: sport,
          initialMode: mode,
          onClose: navigator.pop,
          onNavigate: (section) {
            navigator.pop();
            onNavigate?.call(section);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CyberTooltip(
      message: 'RANK // ${gameModeLabel(sport, mode)}',
      accentColor: accent,
      triggerMode: TooltipTriggerMode.longPress,
      child: Semantics(
        button: true,
        label: 'Leaderboard',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _open(context),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: cutCornerDecoration(
              color: Cyber.panel.withValues(alpha: 0.55),
              borderColor: accent.withValues(alpha: 0.5),
              cut: 8,
            ),
            child: Icon(Icons.leaderboard_rounded, color: accent, size: 19),
          ),
        ),
      ),
    );
  }
}
