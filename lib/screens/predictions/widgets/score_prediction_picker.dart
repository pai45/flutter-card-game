import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/sport_match.dart';

/// Split-bar score entry matching the reference: home team colour on the left
/// with controls hugging the centre line, dark away half mirrored on the right.
class ScorePredictionPicker extends StatelessWidget {
  const ScorePredictionPicker({
    required this.match,
    required this.homeScore,
    required this.awayScore,
    required this.onHomeChanged,
    required this.onAwayChanged,
    this.enabled = true,
    this.settled = false,
    this.correctHome,
    this.correctAway,
  });

  final SportMatch match;
  final int homeScore;
  final int awayScore;
  final ValueChanged<int> onHomeChanged;
  final ValueChanged<int> onAwayChanged;
  final bool enabled;
  final bool settled;

  /// Actual result — shown when [settled] for correct/wrong feedback.
  final int? correctHome;
  final int? correctAway;

  static const _maxGoals = 15;
  static const _awayBg = Color(0xff141418);
  static const _barHeight = 104.0;

  bool get _homeCorrect =>
      settled && correctHome == homeScore && correctAway == awayScore;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: _barHeight,
        child: Row(
          children: [
            Expanded(
              child: _TeamHalf(
                teamName: match.home.name,
                teamColor: match.home.color,
                score: homeScore,
                nameAlign: TextAlign.start,
                controlsOnRight: true,
                enabled: enabled,
                settled: settled,
                isCorrect: _homeCorrect,
                onChanged: onHomeChanged,
              ),
            ),
            Expanded(
              child: _TeamHalf(
                teamName: match.away.name,
                teamColor: _awayBg,
                score: awayScore,
                nameAlign: TextAlign.end,
                controlsOnRight: false,
                enabled: enabled,
                settled: settled,
                isCorrect: _homeCorrect,
                onChanged: onAwayChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamHalf extends StatelessWidget {
  const _TeamHalf({
    required this.teamName,
    required this.teamColor,
    required this.score,
    required this.nameAlign,
    required this.controlsOnRight,
    required this.enabled,
    required this.settled,
    required this.isCorrect,
    required this.onChanged,
  });

  final String teamName;
  final Color teamColor;
  final int score;
  final TextAlign nameAlign;
  final bool controlsOnRight;
  final bool enabled;
  final bool settled;
  final bool isCorrect;
  final ValueChanged<int> onChanged;

  Color get _buttonBg => Color.lerp(teamColor, Colors.black, 0.38)!;

  @override
  Widget build(BuildContext context) {
    final controls = _ScoreControls(
      score: score,
      buttonBg: _buttonBg,
      enabled: enabled,
      settled: settled,
      isCorrect: isCorrect,
      onChanged: onChanged,
    );

    final name = Padding(
      padding: EdgeInsets.only(
        left: controlsOnRight ? 16 : 8,
        right: controlsOnRight ? 8 : 16,
      ),
      child: Text(
        teamName,
        textAlign: nameAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Cyber.body(15, weight: FontWeight.w700),
      ),
    );

    return ColoredBox(
      color: teamColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controlsOnRight) ...[
            Expanded(child: Center(child: name)),
            Center(child: controls),
          ] else ...[
            Center(child: controls),
            Expanded(child: Center(child: name)),
          ],
        ],
      ),
    );
  }
}

class _ScoreControls extends StatelessWidget {
  const _ScoreControls({
    required this.score,
    required this.buttonBg,
    required this.enabled,
    required this.settled,
    required this.isCorrect,
    required this.onChanged,
  });

  final int score;
  final Color buttonBg;
  final bool enabled;
  final bool settled;
  final bool isCorrect;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scoreColor = settled
        ? (isCorrect ? Cyber.success : Colors.white)
        : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StepButton(
            icon: Icons.remove,
            bg: buttonBg,
            enabled: enabled && score > 0,
            onTap: () => onChanged(score - 1),
          ),
          const SizedBox(height: 4),
          Text(
            '$score',
            style: Cyber.display(30, color: scoreColor)
                .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 4),
          _StepButton(
            icon: Icons.add,
            bg: buttonBg,
            enabled: enabled && score < ScorePredictionPicker._maxGoals,
            onTap: () => onChanged(score + 1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.bg,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final Color bg;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        color: enabled ? bg : bg.withValues(alpha: 0.55),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
