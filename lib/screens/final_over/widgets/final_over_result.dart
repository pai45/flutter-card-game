import 'dart:async';

import 'package:final_over/final_over.dart' show BallResult, ExtraType;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../config/theme.dart';
import '../../../models/final_over.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/level_up_celebration.dart';

/// The pay-off. Four beats, 750ms apart, tap to skip:
///   1. the verdict,
///   2. the score, the grade plate and the stars,
///   3. the over you actually bowled — ball by ball — and the box score,
///   4. the XP, the record, and the way back in.
///
/// XP was credited before this overlay mounted, so skipping costs nothing.
class FinalOverResultOverlay extends StatefulWidget {
  const FinalOverResultOverlay({
    required this.summary,
    required this.stats,
    required this.history,
    required this.onRematch,
    required this.onExit,
    super.key,
  });

  final FinalOverMatchSummary summary;
  final FinalOverStats stats;
  final List<BallResult> history;
  final VoidCallback onRematch;
  final VoidCallback onExit;

  @override
  State<FinalOverResultOverlay> createState() => _FinalOverResultOverlayState();
}

class _FinalOverResultOverlayState extends State<FinalOverResultOverlay> {
  static const _maxStage = 3;
  int _stage = 0;
  Timer? _timer;
  bool _showLevelUp = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 750), (timer) {
      if (!mounted) return;
      if (_stage >= _maxStage) {
        timer.cancel();
        return;
      }
      setState(() => _stage += 1);
      playSound(SoundEffect.cardSlam);
      if (_stage >= _maxStage) _maybeLevelUp();
    });
  }

  void _skip() {
    if (_stage >= _maxStage) return;
    _timer?.cancel();
    setState(() => _stage = _maxStage);
    _maybeLevelUp();
  }

  void _maybeLevelUp() {
    if (!mounted) return;
    if (context.read<GameBloc>().state.pendingLevelUps.isNotEmpty) {
      setState(() => _showLevelUp = true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final accent = s.won ? Cyber.success : Cyber.danger;

    return GestureDetector(
      onTap: _skip,
      child: ColoredBox(
        color: Cyber.bg.withValues(alpha: 0.97),
        child: Stack(
          children: [
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 18,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1 — verdict
                        _RevealIn(
                          visible: _stage >= 0,
                          child: Column(
                            children: [
                              Text(
                                s.resultLabel,
                                textAlign: TextAlign.center,
                                style: Cyber.display(
                                  30,
                                  color: accent,
                                  letterSpacing: 3,
                                ).copyWith(
                                  shadows: [
                                    Shadow(
                                      color: accent.withValues(alpha: 0.55),
                                      blurRadius: 22,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _reason(s),
                                textAlign: TextAlign.center,
                                style: Cyber.body(12, color: Cyber.muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // 2 — score + grade + stars
                        _RevealIn(
                          visible: _stage >= 1,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.scoreLine,
                                      style: Cyber.display(
                                        38,
                                        color: Colors.white,
                                      ).copyWith(
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'CHASING ${s.target}',
                                      style: Cyber.label(
                                        9,
                                        color: Cyber.muted,
                                        letterSpacing: 1.6,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _Stars(stars: s.stars),
                                  ],
                                ),
                              ),
                              _GradePlate(grade: s.grade, accent: accent),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // 3 — the over, ball by ball + the box score
                        _RevealIn(
                          visible: _stage >= 2,
                          child: CyberPanel(
                            accent: Cyber.cyan,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SectionLabel(label: 'THE OVER'),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final b in widget.history)
                                      _HistoryToken(result: b),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const HudLine(),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    _Stat('SIXES', '${s.sixes}'),
                                    _Stat('FOURS', '${s.fours}'),
                                    _Stat('BEST COMBO', '×${s.bestCombo}'),
                                    _Stat(
                                      'OBJECTIVE',
                                      s.objectiveCompleted ? '✓' : '—',
                                      color: s.objectiveCompleted
                                          ? Cyber.success
                                          : Cyber.muted,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // 4 — the money
                        _RevealIn(
                          visible: _stage >= 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _XpLine(xp: s.xp),
                              const SizedBox(height: 8),
                              Text(
                                'BEST ${widget.stats.bestScore}  ·  '
                                '${widget.stats.wins}/${widget.stats.chases} CHASES WON',
                                textAlign: TextAlign.center,
                                style: Cyber.label(
                                  9,
                                  color: Cyber.muted,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(height: 18),
                              HudCtaButton(
                                label: 'CHASE AGAIN',
                                icon: Icons.replay_rounded,
                                accent: Cyber.gold,
                                onTap: widget.onRematch,
                              ),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: widget.onExit,
                                child: Text(
                                  'BACK TO FINAL OVER',
                                  style: Cyber.label(
                                    10,
                                    color: Cyber.muted,
                                    letterSpacing: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_showLevelUp)
              LevelUpCelebration(
                levels: context.read<GameBloc>().state.pendingLevelUps,
                onDismissed: () => setState(() => _showLevelUp = false),
              ),
          ],
        ),
      ),
    );
  }

  String _reason(FinalOverMatchSummary s) {
    if (s.won) {
      final spare = s.ballsToSpare;
      if (spare == 0) return 'Off the last ball.';
      return 'With $spare ${spare == 1 ? 'ball' : 'balls'} to spare.';
    }
    if (s.wickets >= 2) return 'All out with the chase alive.';
    final short = s.target - s.runs;
    return '$short ${short == 1 ? 'run' : 'runs'} short.';
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 3; i++)
        Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Icon(
            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 20,
            color: i < stars ? Cyber.gold : Cyber.border,
          ),
        ),
    ],
  );
}

class _GradePlate extends StatelessWidget {
  const _GradePlate({required this.grade, required this.accent});
  final String grade;
  final Color accent;

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const HudChamferClipper(bigCut: 12, smallCut: 4),
    child: Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.7), width: 1.4),
      ),
      child: Text(
        grade,
        style: Cyber.display(34, color: accent, letterSpacing: 1),
      ),
    ),
  );
}

/// One ball of the over. Extras are amber and off to the side, because they
/// didn't count against you.
class _HistoryToken extends StatelessWidget {
  const _HistoryToken({required this.result});
  final BallResult result;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (result) {
      final b when !b.legal =>
        (b.extra == ExtraType.noBall ? 'NB' : 'WD', Cyber.amber),
      final b when b.isWicket => ('W', Cyber.danger),
      final b when b.boundary == 6 => ('6', Cyber.gold),
      final b when b.boundary == 4 => ('4', Cyber.cyan),
      final b when b.totalRuns == 0 => ('•', Cyber.muted),
      final b => ('${b.totalRuns}', Cyber.success),
    };
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: Cyber.display(13, color: color),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Cyber.display(
            16,
            color: color ?? Colors.white,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Cyber.label(7.5, color: Cyber.muted, letterSpacing: 1),
        ),
      ],
    ),
  );
}

/// Cosmetic count-up. The XP is already in the ledger.
class _XpLine extends StatelessWidget {
  const _XpLine({required this.xp});
  final int xp;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 900),
    curve: Curves.easeOutCubic,
    builder: (context, t, _) => Text(
      '+${(xp * t).round()} XP',
      textAlign: TextAlign.center,
      style: Cyber.display(26, color: Cyber.violet, letterSpacing: 2).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
        shadows: [
          Shadow(color: Cyber.violet.withValues(alpha: 0.5), blurRadius: 18),
        ],
      ),
    ),
  );
}

class _RevealIn extends StatelessWidget {
  const _RevealIn({required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSlide(
    offset: visible ? Offset.zero : const Offset(0, 0.18),
    duration: const Duration(milliseconds: 340),
    curve: Curves.easeOutCubic,
    child: AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 340),
      child: child,
    ),
  );
}
