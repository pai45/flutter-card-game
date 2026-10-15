import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/sport_match.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/team_logo.dart';
import 'prediction_helpers.dart';

// ── Top / bottom chrome that fades into the question backdrop ─────────────────
enum QuizChromeEdge { top, bottom }

class QuizChromeShell extends StatelessWidget {
  const QuizChromeShell({required this.edge, required this.child, super.key});

  final QuizChromeEdge edge;
  final Widget child;

  static const _opacity = 0.92;
  static const _fadeHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    final solid = Cyber.bg.withValues(alpha: _opacity);
    final clear = Cyber.bg.withValues(alpha: 0);
    final gradient = edge == QuizChromeEdge.top
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [solid, solid, solid.withValues(alpha: 0.35), clear],
            stops: const [0, 0.58, 0.82, 1],
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [clear, solid.withValues(alpha: 0.35), solid, solid],
            stops: const [0, 0.18, 0.42, 1],
          );

    final fadePad = edge == QuizChromeEdge.top
        ? const EdgeInsets.only(bottom: _fadeHeight)
        : const EdgeInsets.only(top: _fadeHeight);

    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: Padding(padding: fadePad, child: child),
    );
  }
}

// ── Top bar (back + leaderboard trophy) ───────────────────────────────────────
class QuizTopBar extends StatelessWidget {
  const QuizTopBar({required this.onBack, required this.onLeaderboard, super.key});

  final VoidCallback onBack;
  final VoidCallback onLeaderboard;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              playSound(SoundEffect.uiTap);
              onBack();
            },
            child: const SizedBox(
              width: 36,
              height: 56,
              child: Icon(Icons.arrow_back, color: Color(0xffd9e5f6), size: 24),
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Text(
              'Back to Matches',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontFamily: Cyber.bodyFont,
                fontWeight: FontWeight.w600,
                fontSize: 18,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Semantics(
            button: true,
            label: 'Match leaderboard',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onLeaderboard,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                color: const Color(0xff11182a),
                child: const Icon(
                  Icons.emoji_events_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header: corner brackets + kickoff time + team badges + split bar ──────────
class QuizHeader extends StatelessWidget {
  const QuizHeader({required this.match, super.key});
  final SportMatch match;

  String get _statusLabel => switch (match.status) {
    MatchStatus.upcoming => formatTime(match.kickoff),
    MatchStatus.live =>
      match.liveMinute != null ? "LIVE ${match.liveMinute}'" : 'LIVE',
    MatchStatus.finished => 'FINISHED',
  };

  Color get _statusColor => switch (match.status) {
    MatchStatus.upcoming => Cyber.gold,
    MatchStatus.live => Cyber.danger,
    MatchStatus.finished => Cyber.muted,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      child: CustomPaint(
        painter: const _CornerBracketsPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
          child: Column(
            children: [
              Text(
                _statusLabel,
                style: Cyber.display(
                  15,
                  color: _statusColor,
                  letterSpacing: 1.5,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _HeaderBadge(team: match.home, cutBottomRight: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      match.home.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.body(15, weight: FontWeight.w700),
                    ),
                  ),
                  Text('-', style: Cyber.display(16, color: Cyber.muted)),
                  Expanded(
                    child: Text(
                      match.away.name,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.body(15, weight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _HeaderBadge(team: match.away, cutBottomRight: false),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(height: 4, color: match.home.color),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Container(
                      height: 4,
                      color: match.away.color.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.team, required this.cutBottomRight});
  final SportTeam team;
  final bool cutBottomRight;

  @override
  Widget build(BuildContext context) {
    return TeamLogo(
      team: team,
      width: 44,
      height: 44,
      cutBottomRight: cutBottomRight,
    );
  }
}

/// Faint HUD corner ticks framing the team header (top-left + top-right).
class _CornerBracketsPainter extends CustomPainter {
  const _CornerBracketsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const len = 16.0;
    final paint = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    // top-left
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, len), paint);
    // top-right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter oldDelegate) => false;
}

// ── Lock countdown line ───────────────────────────────────────────────────────
class LockLine extends StatelessWidget {
  const LockLine({
    required this.match,
    required this.untilLock,
    this.trailing,
    super.key,
  });
  final SportMatch match;
  final Duration untilLock;

  /// Optional second line (the potential-XP ticker while answering),
  /// stacked under the lock countdown.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final (icon, text, color) = switch (match.status) {
      MatchStatus.upcoming when untilLock > Duration.zero => (
        Icons.lock_clock,
        'QUIZ LOCKS IN ${formatCountdown(untilLock)}',
        Cyber.gold,
      ),
      MatchStatus.finished => (Icons.flag_outlined, 'MATCH ENDED', Cyber.muted),
      _ => (Icons.lock_outline, 'PREDICTIONS LOCKED', Cyber.danger),
    };

    final lockLine = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: Cyber.label(
            11,
            color: color,
            letterSpacing: 1.4,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
      child: trailing == null
          ? Center(child: lockLine)
          : Column(children: [lockLine, const SizedBox(height: 7), trailing!]),
    );
  }
}

// ── Potential-XP pot ticker ───────────────────────────────────────────────────
/// The running "pot" in the quiz header: counts up as answers lock and
/// boosters land, toward the quiz's boosted max. Gold = reward, tabular
/// figures, a brief pulse on gains — no persistent glow.
class XpPotTicker extends StatefulWidget {
  const XpPotTicker({required this.value, required this.max, super.key});

  final int value;
  final int max;

  @override
  State<XpPotTicker> createState() => _XpPotTickerState();
}

class _XpPotTickerState extends State<XpPotTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 320),
    );
  }

  @override
  void didUpdateWidget(covariant XpPotTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value > oldWidget.value) {
      _pulse.forward(from: 0).then((_) {
        if (mounted) _pulse.reverse();
      });
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.value.toDouble()),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      builder: (context, shown, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'POTENTIAL',
            style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.4),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.bolt, size: 13, color: Cyber.gold),
          const SizedBox(width: 2),
          ScaleTransition(
            scale: Tween(
              begin: 1.0,
              end: 1.2,
            ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut)),
            child: Text(
              '${shown.round()}',
              style: Cyber.display(
                12,
                color: Cyber.gold,
                letterSpacing: 0.6,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          Text(
            '/${widget.max} XP',
            style: Cyber.label(
              10,
              color: Cyber.muted,
              letterSpacing: 1.2,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

// ── Big number burst played during reveal phase ───────────────────────────────
class QuizNumberBurst extends StatelessWidget {
  const QuizNumberBurst({
    required this.number,
    required this.progress,
    super.key,
  });

  final int number;
  final double progress;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return const SizedBox.shrink();

    final p = progress.clamp(0.0, 1.0);
    final double scale;
    final double opacity;
    if (p < 0.25) {
      scale = 2.0 - Curves.easeOutBack.transform(p / 0.25);
      opacity = 1.0;
    } else if (p < 0.82) {
      scale = 1.0;
      opacity = 1.0;
    } else {
      final t = (p - 0.82) / 0.18;
      scale = 1.0 + 0.18 * t;
      opacity = 1.0 - t;
    }
    final glow = (1 - (p / 0.45).clamp(0.0, 1.0)) * 0.85 + 0.15;

    return ColoredBox(
      color: Cyber.bg.withValues(alpha: (0.86 * opacity).clamp(0.0, 0.86)),
      child: Center(
        child: Transform.scale(
          scale: scale.clamp(0.4, 2.5),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Text(
              '$number',
              style: TextStyle(
                color: Cyber.lime,
                fontFamily: 'Orbitron',
                fontSize: 128,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Cyber.lime.withValues(alpha: glow),
                    blurRadius: 52,
                  ),
                  Shadow(
                    color: Cyber.cyan.withValues(alpha: glow * 0.55),
                    blurRadius: 80,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
