import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../blocs/game/game_event.dart';
import '../../../blocs/game/game_state.dart';
import '../../../config/theme.dart';
import '../../../models/cards.dart';
import '../../../models/pitch_duel_rules.dart';
import '../../../utils/label_helpers.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/cyber/cyber_toss_coin.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/spotlight_walkthrough.dart';

String _opponentName(GameState state) => state.opponentName ?? 'Opponent';

String compactOpponentName(GameState state) {
  final firstName = _opponentName(state).split(RegExp(r'\s+')).first;
  return firstName.length <= 7 ? firstName.toUpperCase() : 'OPP';
}

// ─────────────────────────────────────────────────────────────────────────────
// TossPhase  –  full HUD redesign
// ─────────────────────────────────────────────────────────────────────────────
class CoinTossPhase extends StatefulWidget {
  const CoinTossPhase({required this.state, required this.onQuit, super.key});
  final GameState state;
  final VoidCallback onQuit;

  @override
  State<CoinTossPhase> createState() => _CoinTossPhaseState();
}

class _CoinTossPhaseState extends State<CoinTossPhase>
    with TickerProviderStateMixin {
  static const _cpuDecisionDuration = Duration(milliseconds: 700);

  final _flipKey = GlobalKey();
  late final AnimationController _cpuDecision;

  bool _cpuStarted = false;
  bool _cpuFinalized = false;
  bool _advanced = false;

  bool get _won => widget.state.playerWonToss == true;

  List<SpotlightStep> get _tossSpotlightSteps => [
    SpotlightStep(
      targetKey: _flipKey,
      title: 'Call the Toss',
      body:
          'Pick HEADS or TAILS to flip the coin. Match the landed face to win '
          'the toss and choose your role.',
      icon: Icons.toll,
      accent: Cyber.cyan,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _cpuDecision = AnimationController(
      vsync: this,
      duration: _cpuDecisionDuration,
    );
  }

  @override
  void dispose() {
    _cpuDecision.dispose();
    super.dispose();
  }

  void _onCoinLanded() {
    if (!mounted) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (!_won && !_cpuStarted) {
      _cpuStarted = true;
      if (!reduce) playSound(SoundEffect.riser);
      _cpuDecision.duration = reduce
          ? const Duration(milliseconds: 180)
          : _cpuDecisionDuration;
      _cpuDecision.forward().then((_) => _completeCpuDecision());
    }
  }

  Future<void> _completeCpuDecision() async {
    if (_advanced || !mounted) return;
    setState(() => _cpuFinalized = true);
    playSound(SoundEffect.commit);
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted || _advanced) return;
    _advanced = true;
    context.read<GameBloc>().add(TossContinued());
  }

  @override
  Widget build(BuildContext context) {
    return CyberCoinTossPhase(
      result: widget.state.tossResult,
      won: widget.state.playerWonToss,
      call: widget.state.tossChoice,
      onQuit: widget.onQuit,
      onCall: (call) => context.read<GameBloc>().add(TossResolved(call)),
      onLanded: _onCoinLanded,
      callTargetKey: _flipKey,
      overlay: widget.state.tossResult == null
          ? SpotlightTutorial(
              keyName: 'toss',
              steps: _tossSpotlightSteps,
              startDelay: const Duration(milliseconds: 900),
            )
          : null,
      resolvedContent: _won
          ? _buildWinnerPanel(context)
          : _buildCpuDecisionPanel(),
    );
  }

  Widget _buildWinnerPanel(BuildContext context) {
    final round = max(1, widget.state.currentRound);
    return Column(
      children: [
        Text(
          'YOU WON THE TOSS',
          textAlign: TextAlign.center,
          style: Cyber.display(26, color: Cyber.cyan, letterSpacing: 2)
              .copyWith(
                shadows: [
                  Shadow(
                    color: Cyber.cyan.withValues(alpha: 0.6),
                    blurRadius: 18,
                  ),
                ],
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'CHOOSE YOUR ROLE FOR ROUND $round',
          textAlign: TextAlign.center,
          style: Cyber.bodyFor(context, 12, color: Cyber.muted),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _RoleChoiceButton(
                icon: Icons.sports_soccer,
                label: 'ATTACK',
                sub: 'GO FOR GOAL',
                accent: Cyber.cyan,
                onTap: () => context.read<GameBloc>().add(RoleChosen(true)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RoleChoiceButton(
                icon: Icons.shield,
                label: 'DEFEND',
                sub: 'SHUT THEM OUT',
                accent: Cyber.violet,
                onTap: () => context.read<GameBloc>().add(RoleChosen(false)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCpuDecisionPanel() {
    final opponent = _opponentName(widget.state).toUpperCase();
    return AnimatedBuilder(
      animation: _cpuDecision,
      builder: (context, _) => Column(
        children: [
          Text(
            '$opponent WON THE TOSS',
            textAlign: TextAlign.center,
            style: Cyber.display(26, color: Cyber.danger, letterSpacing: 2),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              _cpuFinalized
                  ? '$opponent HAS DECIDED'
                  : '$opponent IS DECIDING TO ATTACK OR DEFEND',
              key: ValueKey(_cpuFinalized),
              textAlign: TextAlign.center,
              style: Cyber.bodyFor(context, 12, color: Cyber.muted),
            ),
          ),
          const SizedBox(height: 16),
          _CpuDecisionMeter(
            progress: _cpuDecision.value.clamp(0.0, 1.0),
            finalized: _cpuFinalized,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CpuDecisionMeter  –  CPU "deciding" progress bar (player lost the toss)
// ─────────────────────────────────────────────────────────────────────────────
class _CpuDecisionMeter extends StatelessWidget {
  const _CpuDecisionMeter({required this.progress, required this.finalized});

  final double progress;
  final bool finalized;

  @override
  Widget build(BuildContext context) {
    final accent = finalized ? Cyber.success : Cyber.cyan;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            finalized
                ? 'NEXT: SCENARIO BRIEFING'
                : 'OPPONENT DECISION PROTOCOL',
            textAlign: TextAlign.center,
            style: Cyber.label(10, color: Cyber.muted, letterSpacing: 2),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 3,
            child: Stack(
              children: [
                Container(color: accent.withValues(alpha: 0.14)),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(color: accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Big role-choice card for the toss winner (ATTACK / DEFEND)
// ─────────────────────────────────────────────────────────────────────────────
class _RoleChoiceButton extends StatefulWidget {
  const _RoleChoiceButton({
    required this.icon,
    required this.label,
    required this.sub,
    required this.accent,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String sub;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_RoleChoiceButton> createState() => _RoleChoiceButtonState();
}

class _RoleChoiceButtonState extends State<_RoleChoiceButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _press, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _onTap() {
    _press.forward().then((_) {
      _press.reverse();
      widget.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return AnimatedBuilder(
      animation: _press,
      builder: (_, _) => Transform.scale(
        scale: _scale.value,
        child: GestureDetector(
          onTap: _onTap,
          child: Container(
            height: 124,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              border: Border.all(
                color: accent.withValues(alpha: 0.55),
                width: 1.4,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: accent, size: 34),
                const SizedBox(height: 10),
                Text(
                  widget.label,
                  style: Cyber.display(20, color: accent, letterSpacing: 2),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.sub,
                  style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _roleAccent(bool attacking) => roleAccent(attacking);

class ScenarioBriefingSection extends StatefulWidget {
  const ScenarioBriefingSection({
    required this.scenario,
    required this.attacking,
    this.onComplete,
    this.initialSeconds = 2,
    this.deferCountdown = false,
    super.key,
  });

  final ScenarioCard scenario;
  final bool attacking;
  final int initialSeconds;
  final VoidCallback? onComplete;

  /// When true, the auto-advance timer waits until [beginCountdown] is called
  /// (e.g. after the first-match walkthrough is dismissed).
  final bool deferCountdown;

  @override
  State<ScenarioBriefingSection> createState() =>
      ScenarioBriefingSectionState();
}

class ScenarioBriefingSectionState extends State<ScenarioBriefingSection>
    with TickerProviderStateMixin {
  late int _seconds;
  bool _advanced = false;
  bool _countdownStarted = false;
  bool _entranceStarted = false;
  bool _stampFired = false;
  GameBloc? _bloc;
  late final AnimationController _scanner = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _seconds = widget.initialSeconds;
    if (!widget.deferCountdown) {
      beginCountdown();
    }
  }

  void beginCountdown() {
    if (_countdownStarted || _advanced) return;
    _countdownStarted = true;
    setState(() => _seconds = widget.initialSeconds);
    _tick();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_entranceStarted) {
      _entranceStarted = true;
      if (MediaQuery.of(context).disableAnimations) {
        _stampFired = true;
        _entrance.value = 1;
      } else {
        _entrance.addListener(_onEntranceTick);
        _entrance.forward();
      }
    }
    if (_bloc != null) return;
    try {
      _bloc = context.read<GameBloc>();
    } catch (_) {
      // Widget tests may omit a bloc when only [onComplete] is under test.
    }
  }

  void _onEntranceTick() {
    if (_stampFired || _entrance.value < _kBriefingStampStart) return;
    _stampFired = true;
    playSound(SoundEffect.commit);
    HapticFeedback.mediumImpact();
  }

  void _finishCountdown() {
    if (_advanced || !mounted) return;
    _advanced = true;
    widget.onComplete?.call();
    _bloc?.add(PlayStarted());
  }

  Future<void> _tick() async {
    for (var i = widget.initialSeconds; i > 0; i--) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted || _advanced) return;
      setState(() => _seconds = i - 1);
    }
    _finishCountdown();
  }

  @override
  void dispose() {
    _scanner.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _roleAccent(widget.attacking);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = min(constraints.maxWidth, 430.0);
        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScenarioBriefingCard(
                      scenario: widget.scenario,
                      attacking: widget.attacking,
                      entrance: _entrance,
                    ),
                    const SizedBox(height: 24),
                    CountdownBlock(
                      seconds: _seconds,
                      scanner: _scanner,
                      accent: accent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Scenario briefing entrance beats (fractions of the entrance timeline) ───
const _kBriefingIconEnd = 0.18;
const _kBriefingDecodeStart = 0.08;
const _kBriefingDecodeEnd = 0.55;
const _kBriefingBodyStart = 0.42;
const _kBriefingBodyEnd = 0.66;
const _kBriefingChipStart = 0.56;
const _kBriefingChipEnd = 0.84;
const _kBriefingStampStart = 0.80;

class ScenarioBriefingCard extends StatelessWidget {
  const ScenarioBriefingCard({
    required this.scenario,
    required this.attacking,
    this.entrance,
    super.key,
  });

  final ScenarioCard scenario;
  final bool attacking;

  /// Drives the staggered decrypt entrance; null renders the settled card.
  final Animation<double>? entrance;

  @override
  Widget build(BuildContext context) {
    final anim = entrance;
    if (anim == null) return _buildCard(context, 1);
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => _buildCard(context, anim.value),
    );
  }

  Widget _buildCard(BuildContext context, double t) {
    final accent = _roleAccent(attacking);
    final status = attacking ? 'ATTACKING THIS ROUND' : 'DEFENDING THIS ROUND';

    double seg(double a, double b, [Curve curve = Curves.easeOut]) {
      if (t <= a) return 0;
      if (t >= b) return 1;
      return curve.transform((t - a) / (b - a));
    }

    final iconT = seg(0, _kBriefingIconEnd);
    final decodeT = seg(
      _kBriefingDecodeStart,
      _kBriefingDecodeEnd,
      Curves.linear,
    );
    final bodyT = seg(_kBriefingBodyStart, _kBriefingBodyEnd);
    final chipAT = seg(
      _kBriefingChipStart,
      _kBriefingChipStart + 0.18,
      Curves.easeOutBack,
    );
    final chipBT = seg(
      _kBriefingChipEnd - 0.18,
      _kBriefingChipEnd,
      Curves.easeOutBack,
    );
    final stampT = seg(_kBriefingStampStart, 1, Curves.easeOutCubic);
    // Transient pulse behind the role badge as it stamps down (peaks mid-stamp).
    final stampPulse = 4 * stampT * (1 - stampT);

    return CustomPaint(
      painter: _ScenarioPanelPainter(accent),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: iconT,
              child: Transform.scale(
                scale: 0.6 + 0.4 * iconT,
                child: PitchVectorArt(
                  asset: pitchScenarioAsset(scenario),
                  color: accent,
                  width: 56,
                  height: 42,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _DecryptText(
              text: scenario.title.toUpperCase(),
              t: decodeT,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: Cyber.display(26, color: accent, letterSpacing: 1.3)
                  .copyWith(
                    shadows: [
                      Shadow(
                        color: accent.withValues(alpha: 0.65 * decodeT),
                        blurRadius: 18,
                      ),
                    ],
                  ),
            ),
            const SizedBox(height: 10),
            Opacity(
              opacity: bodyT,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - bodyT)),
                child: Text(
                  scenario.description,
                  textAlign: TextAlign.center,
                  style: Cyber.bodyFor(
                    context,
                    13,
                    color: Colors.white.withValues(alpha: 0.82),
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Transform.scale(
              scaleX: bodyT,
              child: Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 34),
                color: accent.withValues(alpha: 0.14),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ChipPop(
                    t: chipAT,
                    child: BonusChip(
                      label: 'ATTACK',
                      value: '+${scenario.attackBonus}',
                      accent: Cyber.cyan,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _ChipPop(
                    t: chipBT,
                    child: BonusChip(
                      label: 'DEFENSE',
                      value: '+${scenario.defenseBonus}',
                      accent: accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'SCENARIO MATCH +6',
              style: Cyber.label(10, color: Cyber.cyan),
            ),
            const SizedBox(height: 4),
            Text(
              pitchScenarioActionNames(
                scenario,
                attacking: attacking,
              ).join(' • '),
              textAlign: TextAlign.center,
              style: Cyber.bodyFor(context, 12, color: AppTheme.whiteColor),
            ),
            const SizedBox(height: 16),
            Opacity(
              opacity: stampT,
              child: Transform.scale(
                scale: 1.55 - 0.55 * stampT,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.6),
                      width: 1.4,
                    ),
                    boxShadow: stampPulse > 0.01
                        ? [
                            BoxShadow(
                              color: accent.withValues(
                                alpha: 0.35 * stampPulse,
                              ),
                              blurRadius: 20,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        attacking ? Icons.sports_soccer : Icons.shield,
                        color: accent,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          status,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.display(
                            16,
                            color: accent,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scale + fade pop-in for the bonus chips (overshoot handled by the curve).
class _ChipPop extends StatelessWidget {
  const _ChipPop({required this.t, required this.child});

  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.scale(scale: 0.75 + 0.25 * t, child: child),
    );
  }
}

/// Headline that decodes left→right: revealed characters are final, the rest
/// flicker through glitch glyphs (spaces stay fixed so layout barely shifts).
class _DecryptText extends StatelessWidget {
  const _DecryptText({
    required this.text,
    required this.t,
    required this.style,
    this.textAlign,
    this.maxLines,
  });

  final String text;
  final double t;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;

  static const _glyphs = r'#$%&@!?<>/\=+*';

  @override
  Widget build(BuildContext context) {
    String shown;
    if (t >= 1) {
      shown = text;
    } else {
      final revealed = (t * text.length).floor();
      // Quantised seed → glyphs flicker every few frames, not every frame.
      final rng = Random((t * 12).floor() * 131 + text.length);
      final buf = StringBuffer();
      for (var i = 0; i < text.length; i++) {
        final ch = text[i];
        buf.write(
          i < revealed || ch == ' ' ? ch : _glyphs[rng.nextInt(_glyphs.length)],
        );
      }
      shown = buf.toString();
    }
    return Text(
      shown,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

class BonusChip extends StatelessWidget {
  const BonusChip({
    required this.label,
    required this.value,
    required this.accent,
    super.key,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xff08131e).withValues(alpha: 0.98),
        border: Border.all(color: accent.withValues(alpha: 0.62)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.1), blurRadius: 10),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Cyber.label(12, color: accent)),
            const SizedBox(width: 8),
            Text(value, style: Cyber.label(12, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _ScenarioPanelPainter extends CustomPainter {
  const _ScenarioPanelPainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const cut = 13.0;
    final rectPath = Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, cut)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..lineTo(0, cut)
      ..close();

    canvas.drawPath(
      rectPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff07111d), Color(0xff0d111a)],
        ).createShader(Offset.zero & size),
    );

    final glow = Paint()
      ..color = accent.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final line = Paint()
      ..color = accent.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawPath(rectPath, glow);
    canvas.drawPath(rectPath, line);

    final corner = Paint()
      ..color = accent.withValues(alpha: 0.95)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(size.width - cut - 20, 0),
      Offset(size.width - cut, 0),
      corner,
    );
    canvas.drawLine(
      Offset(size.width, cut),
      Offset(size.width, cut + 20),
      corner,
    );
    canvas.drawLine(
      Offset(0, size.height - cut - 20),
      Offset(0, size.height - cut),
      corner,
    );
    canvas.drawLine(
      Offset(cut, size.height),
      Offset(cut + 20, size.height),
      corner,
    );
  }

  @override
  bool shouldRepaint(_ScenarioPanelPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

// ─────────────────────────────────────────────────────────────────────────────
// Match-phase entrance animators
// ─────────────────────────────────────────────────────────────────────────────

/// Primary "lock in your move" CTA. Reuses the Play Match button treatment
/// (angular HUD silhouette, pulsing glow, haptic) so committing a move feels as
/// premium as starting a match. Opening the Shot Meter is the actual action.
class BottomLockButton extends StatelessWidget {
  const BottomLockButton({
    required this.label,
    required this.helper,
    required this.accent,
    required this.onPressed,
    this.icon = Icons.sports_soccer,
    super.key,
  });

  final String label;
  final String helper;
  final Color accent;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return HudCtaButton(
      label: label,
      helper: helper,
      icon: icon,
      accent: accent,
      // The round's decisive action — a meatier "commit" cue, not a plain tap.
      tapSound: SoundEffect.commit,
      height:
          70 +
          (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(0, 14) * 5,
      onTap: onPressed,
    );
  }
}

/// A scouting range over all remaining legal pairs, never the committed pick.
PitchPowerRange? playerRivalRange(GameState state) {
  final scenario = state.currentScenario;
  if (scenario == null) return null;
  return pitchRivalRange(
    players: state.playerAttacking
        ? state.opponentDefenders
        : state.opponentAttackers,
    actions: state.opponentActions,
    usedPlayers: [...state.opponentUsedPlayerCards, ...state.opponentRedCarded],
    usedActions: state.opponentUsedActionCards,
    scenario: scenario,
    round: state.currentRound,
    attacking: !state.playerAttacking,
  );
}

Future<ShotTimingResult?> showShotMeter(
  BuildContext context, {
  required PowerBreakdown power,
  required Color accent,
  required PitchPowerRange? rivalRange,
  required bool attacking,
}) => showGeneralDialog<ShotTimingResult>(
  context: context,
  barrierDismissible: false,
  barrierLabel: 'Shot Meter',
  barrierColor: Cyber.bg.withValues(alpha: 0.82),
  transitionDuration: const Duration(milliseconds: 180),
  pageBuilder: (_, _, _) => ShotMeterOverlay(
    power: power,
    accent: accent,
    rivalRange: rivalRange,
    attacking: attacking,
  ),
  transitionBuilder: (_, animation, _, child) =>
      FadeTransition(opacity: animation, child: child),
);

class ShotMeterOverlay extends StatefulWidget {
  const ShotMeterOverlay({
    required this.power,
    required this.accent,
    required this.rivalRange,
    required this.attacking,
    super.key,
  });
  final PowerBreakdown power;
  final Color accent;
  final PitchPowerRange? rivalRange;
  final bool attacking;
  @override
  State<ShotMeterOverlay> createState() => _ShotMeterOverlayState();
}

class _ShotMeterOverlayState extends State<ShotMeterOverlay>
    with SingleTickerProviderStateMixin {
  final _meterKey = GlobalKey();
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? _startTimer;
  Timer? _resultTimer;
  ShotTimingResult? _result;
  bool _booted = false;
  bool _ready = false;
  bool _tutorialPending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;
    try {
      _tutorialPending = !context.read<GameBloc>().state.tutorialSeen.contains(
        'shot-meter',
      );
    } catch (_) {
      _tutorialPending = false;
    }
    if (!_tutorialPending) _startSweep();
  }

  void _startSweep() {
    if (_ready || _startTimer != null) return;
    _startTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _tutorialPending = false;
      });
      _sweep.repeat(reverse: true);
      playSound(SoundEffect.riser);
    });
  }

  void _strike() {
    if (!_ready || _result != null) return;
    final result = ShotTimingResult.at(_sweep.value);
    _sweep.stop();
    setState(() => _result = result);
    if (result.quality == ShotTimingQuality.perfect) {
      HapticFeedback.heavyImpact();
      playSound(SoundEffect.special);
    } else if (result.quality == ShotTimingQuality.great) {
      HapticFeedback.mediumImpact();
      playSound(SoundEffect.commit);
    } else if (result.bonus > 0) {
      HapticFeedback.lightImpact();
      playSound(SoundEffect.commit);
    } else {
      HapticFeedback.selectionClick();
      playSound(SoundEffect.miss);
    }
    _resultTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _resultTimer?.cancel();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rival = widget.rivalRange;
    final result = _result;
    return Material(
      color: Cyber.bg.withValues(alpha: 0),
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _strike,
            child: SafeArea(
              child: Align(
                alignment: const Alignment(0, 0.3),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: CyberPanel(
                      cornerCuts: true,
                      accent: widget.accent,
                      glow: true,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            widget.attacking
                                ? 'TIME YOUR STRIKE'
                                : 'TIME YOUR BLOCK',
                            style: Cyber.display(
                              18,
                              color: AppTheme.whiteColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 16,
                            runSpacing: 10,
                            children: [
                              _TimingStat(
                                label: 'CARD POWER',
                                value: '${widget.power.base}',
                                color: widget.accent,
                              ),
                              _TimingStat(
                                label: 'TIMING',
                                value: '+0–8',
                                color: Cyber.cyan,
                              ),
                              _TimingStat(
                                label: 'RIVAL POWER RANGE',
                                value: rival == null
                                    ? '—'
                                    : '${rival.min}–${rival.max}',
                                color: Cyber.muted,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Text(
                              'PERFECT +${ShotTimingQuality.perfect.bonus}',
                              style: Cyber.label(10, color: Cyber.cyan),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SpotlightTarget(
                            spotlightKey: _meterKey,
                            child: SizedBox(
                              height: 48,
                              width: double.infinity,
                              child: AnimatedBuilder(
                                animation: _sweep,
                                builder: (_, _) => CustomPaint(
                                  painter: _ShotMeterPainter(
                                    progress: result?.position ?? _sweep.value,
                                    accent: widget.accent,
                                    frozen: result != null,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text(
                                'EARLY +0',
                                style: Cyber.label(8, color: Cyber.muted),
                              ),
                              Text(
                                'GOOD +${ShotTimingQuality.good.bonus}  ·  GREAT +${ShotTimingQuality.great.bonus}',
                                style: Cyber.label(
                                  8,
                                  color: Cyber.cyan,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'LATE +0',
                                style: Cyber.label(8, color: Cyber.muted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          if (result != null) ...[
                            Text(
                              '${result.label}  +${result.bonus}',
                              textAlign: TextAlign.center,
                              style: Cyber.display(
                                24,
                                color: result.bonus > 0
                                    ? Cyber.cyan
                                    : Cyber.muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'FINAL POWER ${widget.power.base + result.bonus}',
                              textAlign: TextAlign.center,
                              style: Cyber.label(
                                11,
                                color: AppTheme.whiteColor,
                              ),
                            ),
                          ] else
                            CyberCtaButton(
                              label: _ready
                                  ? 'TAP TO ${widget.attacking ? 'STRIKE' : 'BLOCK'}'
                                  : 'GET READY',
                              primary: true,
                              onPressed: _ready ? _strike : null,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_tutorialPending)
            SpotlightTutorial(
              keyName: 'shot-meter',
              startDelay: const Duration(milliseconds: 100),
              onComplete: _startSweep,
              steps: [
                SpotlightStep(
                  targetKey: _meterKey,
                  title: 'Make the cards count',
                  body:
                      'Your cards set the power. Tap the centered target for Perfect +8, Great +6 or Good +4. Timing helps a close play.',
                  icon: Icons.speed,
                  accent: widget.accent,
                  padding: 10,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TimingStat extends StatelessWidget {
  const _TimingStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Cyber.label(8, color: Cyber.muted, letterSpacing: 0.5),
      ),
      const SizedBox(height: 6),
      Text(
        value,
        style: Cyber.display(
          17,
          color: color,
          letterSpacing: 0,
        ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    ],
  );
}

class _ShotMeterPainter extends CustomPainter {
  const _ShotMeterPainter({
    required this.progress,
    required this.accent,
    required this.frozen,
  });
  final double progress;
  final Color accent;
  final bool frozen;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 6, size.width, size.height - 12);
    canvas.drawRect(rect, Paint()..color = Cyber.bg2);
    for (final zone in [
      (ShotTimingResult.goodHalfWidth, 0.18),
      (ShotTimingResult.greatHalfWidth, 0.4),
      (ShotTimingResult.perfectHalfWidth, 0.85),
    ]) {
      canvas.drawRect(
        Rect.fromLTRB(
          (0.5 - zone.$1) * size.width,
          rect.top,
          (0.5 + zone.$1) * size.width,
          rect.bottom,
        ),
        Paint()..color = accent.withValues(alpha: zone.$2),
      );
    }
    canvas.drawRect(
      rect,
      Paint()
        ..color = Cyber.border
        ..style = PaintingStyle.stroke,
    );
    final x = progress.clamp(0, 1) * size.width;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = AppTheme.whiteColor
        ..strokeWidth = frozen ? 4 : 3,
    );
    final marker = Path()
      ..moveTo(x - 5, 0)
      ..lineTo(x + 5, 0)
      ..lineTo(x, 5)
      ..close();
    canvas.drawPath(marker, Paint()..color = AppTheme.whiteColor);
  }

  @override
  bool shouldRepaint(covariant _ShotMeterPainter old) =>
      old.progress != progress || old.accent != accent || old.frozen != frozen;
}

class AngularBorderContainer extends StatelessWidget {
  const AngularBorderContainer({
    required this.child,
    this.accent = Cyber.cyan,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.height,
    this.fillOpacity = 0.88,
    this.solidFill = false,
    this.glow = true,
    super.key,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double? height;
  final double fillOpacity;
  final bool solidFill;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    const fill = Color(0xff101827);
    const deepFill = Color(0xff0d111a);
    final gradientColors = solidFill
        ? [Color.lerp(fill, accent, 0.18)!, deepFill, fill]
        : [
            accent.withValues(alpha: 0.08),
            deepFill.withValues(alpha: 0.95),
            fill.withValues(alpha: 0.9),
          ];

    return Container(
      margin: margin,
      height: height,
      decoration: BoxDecoration(
        boxShadow: glow
            ? [BoxShadow(color: accent.withValues(alpha: 0.16), blurRadius: 18)]
            : null,
      ),
      child: ClipPath(
        clipper: CyberClipper(),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fill.withValues(alpha: fillOpacity),
            border: Border.all(
              color: accent.withValues(alpha: 0.75),
              width: 1.2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class NextRoundCountdown extends StatefulWidget {
  const NextRoundCountdown({
    required this.onComplete,
    this.deferCountdown = false,
    super.key,
  });

  final VoidCallback onComplete;
  final bool deferCountdown;

  @override
  State<NextRoundCountdown> createState() => NextRoundCountdownState();
}

class NextRoundCountdownState extends State<NextRoundCountdown> {
  int _seconds = 3;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    if (!widget.deferCountdown) {
      beginCountdown();
    }
  }

  void beginCountdown() {
    if (_started) return;
    _started = true;
    _tick();
  }

  Future<void> _tick() async {
    for (var i = 3; i > 0; i--) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _seconds = i - 1);
    }
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'NEXT ROUND // ${_seconds > 0 ? '0$_seconds' : 'GO'}',
          style: Cyber.label(
            12,
            color: Cyber.muted,
            letterSpacing: 2.2,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        const SizedBox(height: 6),
        Text(
          _seconds > 0 ? '$_seconds' : 'GO!',
          style: Cyber.display(
            44,
            color: Cyber.cyan,
            letterSpacing: 4,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}
