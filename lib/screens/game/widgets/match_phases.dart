import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../blocs/game/game_event.dart';
import '../../../blocs/game/game_state.dart';
import '../../../config/enums.dart';
import '../../../config/theme.dart';
import '../../../models/cards.dart';
import '../../../utils/label_helpers.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/match_widgets.dart';
import '../../../widgets/pitch_background.dart';
import '../../../widgets/spotlight_walkthrough.dart';
import 'round_result_cinematic.dart';

// ── Toss-phase local colour constants ────────────────────────────────────────
const Color _kTossCyan = Color(0xFF5CDFFF);
const Color _kTossRed = Color(0xFFFF4D4D);
const Color _kTossBg = Color(0xFF0D111A);
const Color _kTossMuted = Color(0xFF8FA3B8);

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
  static const _cpuDecisionDuration = Duration(milliseconds: 3600);

  final _flipKey = GlobalKey();

  // Entrance stagger for the idle state (coin pops in, then the flip CTA).
  late final AnimationController _entry;
  late final Animation<double> _coinEntry;
  late final Animation<double> _ctaEntry;

  // Bottom result panel reveal + the CPU "deciding" meter (player lost the toss).
  late final AnimationController _reveal;
  late final AnimationController _cpuDecision;

  bool _landed = false;
  bool _cpuStarted = false;
  bool _cpuFinalized = false;
  bool _advanced = false;

  bool get _resolved => widget.state.tossResult != null;
  bool get _won => widget.state.playerWonToss == true;

  String get _resultCaption {
    final landed = (widget.state.tossResult ?? '').toUpperCase();
    final call = widget.state.tossChoice?.toUpperCase();
    return call == null
        ? 'IT LANDED $landed'
        : 'YOU CALLED $call · IT LANDED $landed';
  }

  List<SpotlightStep> get _tossSpotlightSteps => [
    SpotlightStep(
      targetKey: _flipKey,
      title: 'Call the Toss',
      body:
          'Pick HEADS or TAILS to flip the coin. Match the landed face to win '
          'the toss and choose your role.',
      icon: Icons.toll,
      accent: _kTossCyan,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _coinEntry = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.0, 0.72, curve: Curves.easeOutBack),
    );
    _ctaEntry = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
    );
    _entry.forward();

    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _cpuDecision = AnimationController(
      vsync: this,
      duration: _cpuDecisionDuration,
    );
  }

  @override
  void dispose() {
    _entry.dispose();
    _reveal.dispose();
    _cpuDecision.dispose();
    super.dispose();
  }

  // Fired by the shared coin once its spin settles on a face.
  void _onCoinLanded() {
    if (_landed || !mounted) return;
    setState(() => _landed = true);
    final reduce = MediaQuery.of(context).disableAnimations;
    playSound(SoundEffect.whoosh);
    if (reduce) {
      _reveal.value = 1;
    } else {
      _reveal.forward();
    }
    if (!_won && !_cpuStarted) {
      _cpuStarted = true;
      if (!reduce) playSound(SoundEffect.riser);
      _cpuDecision.duration = reduce
          ? const Duration(milliseconds: 900)
          : _cpuDecisionDuration;
      _cpuDecision.forward().then((_) => _completeCpuDecision());
    }
  }

  Future<void> _completeCpuDecision() async {
    if (_advanced || !mounted) return;
    setState(() => _cpuFinalized = true);
    playSound(SoundEffect.commit);
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted || _advanced) return;
    _advanced = true;
    context.read<GameBloc>().add(TossContinued());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kTossBg,
      body: Stack(
        children: [
          const Positioned.fill(child: StadiumBackground()),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TossTopBar(label: 'COIN TOSS', onQuit: widget.onQuit),
                Expanded(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _entry,
                      builder: (context, child) => Transform.scale(
                        scale: _coinEntry.value.clamp(0.0, 1.05),
                        child: child,
                      ),
                      child: _TossCoin(
                        result: widget.state.tossResult,
                        won: widget.state.playerWonToss,
                        onLanded: _onCoinLanded,
                      ),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: _buildBottom(context),
                ),
              ],
            ),
          ),
          if (!_resolved)
            SpotlightTutorial(
              keyName: 'toss',
              steps: _tossSpotlightSteps,
              startDelay: const Duration(milliseconds: 900),
            ),
        ],
      ),
    );
  }

  Widget _buildBottom(BuildContext context) {
    if (!_resolved) {
      return _buildFlipControls(context);
    }
    if (!_landed) {
      return Padding(
        key: const ValueKey('flipping'),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
        child: Text(
          'FLIPPING…',
          textAlign: TextAlign.center,
          style: Cyber.label(12, color: _kTossMuted, letterSpacing: 3),
        ),
      );
    }
    return KeyedSubtree(
      key: const ValueKey('result'),
      child: _buildResultPanel(context),
    );
  }

  void _callToss(BuildContext context, String call) {
    if (_resolved) return;
    context.read<GameBloc>().add(TossResolved(call));
  }

  Widget _buildFlipControls(BuildContext context) {
    return Padding(
      key: const ValueKey('flip'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      child: AnimatedBuilder(
        animation: _entry,
        builder: (context, child) => Opacity(
          opacity: _ctaEntry.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - _ctaEntry.value)),
            child: child,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CALL THE TOSS TO SEE WHO ATTACKS',
              textAlign: TextAlign.center,
              style: Cyber.body(11, color: _kTossMuted),
            ),
            const SizedBox(height: 12),
            SpotlightTarget(
              spotlightKey: _flipKey,
              child: Row(
                children: [
                  Expanded(
                    child: _CallChoiceButton(
                      face: 'H',
                      label: 'HEADS',
                      accent: _kTossCyan,
                      onTap: () => _callToss(context, 'heads'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CallChoiceButton(
                      face: 'T',
                      label: 'TAILS',
                      accent: const Color(0xFFC084FC),
                      onTap: () => _callToss(context, 'tails'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultPanel(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_reveal, _cpuDecision]),
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_reveal.value.clamp(0.0, 1.0));
        final panelT = Curves.easeOutBack.transform(
          _reveal.value.clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 26 * (1 - t)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _resultCaption,
                  textAlign: TextAlign.center,
                  style: Cyber.label(13, color: _kTossMuted, letterSpacing: 2),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Transform.translate(
                    offset: Offset(0, 46 * (1 - panelT)),
                    child: Opacity(
                      opacity: t,
                      child: _won
                          ? _buildWinnerPanel(context)
                          : _buildCpuDecisionPanel(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWinnerPanel(BuildContext context) {
    final round = max(1, widget.state.currentRound);
    return Column(
      children: [
        Text(
          'YOU WON THE TOSS',
          textAlign: TextAlign.center,
          style: Cyber.display(26, color: _kTossCyan, letterSpacing: 2)
              .copyWith(
                shadows: [
                  Shadow(
                    color: _kTossCyan.withValues(alpha: 0.6),
                    blurRadius: 18,
                  ),
                ],
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'CHOOSE YOUR ROLE FOR ROUND $round',
          textAlign: TextAlign.center,
          style: Cyber.body(12, color: _kTossMuted),
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
                accent: const Color(0xFFC084FC),
                onTap: () => context.read<GameBloc>().add(RoleChosen(false)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCpuDecisionPanel() {
    final progress = _cpuDecision.value.clamp(0.0, 1.0);
    return Column(
      children: [
        Text(
          'CPU WON THE TOSS',
          textAlign: TextAlign.center,
          style: Cyber.display(26, color: _kTossRed, letterSpacing: 2),
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            _cpuFinalized
                ? 'CPU HAS DECIDED'
                : 'CPU IS DECIDING TO ATTACK OR DEFEND',
            key: ValueKey(_cpuFinalized),
            textAlign: TextAlign.center,
            style: Cyber.body(12, color: _kTossMuted),
          ),
        ),
        const SizedBox(height: 16),
        _CpuDecisionMeter(progress: progress, finalized: _cpuFinalized),
      ],
    );
  }
}

// _TossTopBar: slim round caption + close button (replaces the old big header
// and the [P1] YOU / RD x/4 / VS / ATTACKING / CPU [E1] score bar).
// [round] is optional — the coin toss happens once, so its caption omits it.
class _TossTopBar extends StatelessWidget {
  const _TossTopBar({required this.label, required this.onQuit, this.round});
  final int? round;
  final String label;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onQuit,
            icon: const Icon(Icons.close, color: _kTossCyan, size: 24),
          ),
          Expanded(
            child: Text(
              round == null ? label : 'ROUND $round · $label',
              textAlign: TextAlign.center,
              style: Cyber.label(
                11,
                color: _kTossCyan.withValues(alpha: 0.75),
                letterSpacing: 2,
              ),
            ),
          ),
          // Balances the close button so the caption stays centred.
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// _TossCoin: ONE coin for the whole toss. It idles (float + radar rings), then
// the SAME coin runs the 3-D flip and lands on the result face. Pass [result]
// = null to idle, 'heads'/'tails' to flip & land. The win/lose accent ([won]:
// cyan = player, red = CPU) is applied only AFTER the flip settles — during
// the spin the coin stays neutral so the outcome isn't telegraphed.
class _TossCoin extends StatefulWidget {
  const _TossCoin({required this.result, required this.won, this.onLanded});
  final String? result;
  final bool? won;
  final VoidCallback? onLanded;

  @override
  State<_TossCoin> createState() => _TossCoinState();
}

class _TossCoinState extends State<_TossCoin> with TickerProviderStateMixin {
  static const double _coinSize = 122;

  // Idle motion.
  late final AnimationController _float;
  late final AnimationController _ring;
  late final Animation<double> _floatAnim;
  late final Animation<double> _ringAnim;

  // Flip + landing burst.
  late final AnimationController _flip;
  late final AnimationController _glow;
  late final Animation<double> _angle;
  late final Animation<double> _settle;
  late final Animation<double> _glowPulse;

  bool _flipStarted = false;
  bool _showFlash = false;
  // True once the flip has settled — gates the win/lose colour reveal.
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _floatAnim = Tween<double>(
      begin: -4,
      end: 4,
    ).animate(CurvedAnimation(parent: _float, curve: Curves.easeInOut));
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 20000),
    );
    _ringAnim = Tween<double>(begin: 0, end: 2 * pi).animate(_ring);

    _flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _angle = Tween<double>(
      begin: 0,
      end: pi * 6,
    ).animate(CurvedAnimation(parent: _flip, curve: Curves.easeOut));
    _settle = Tween<double>(begin: 0.70, end: 1.0).animate(
      CurvedAnimation(
        parent: _flip,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutBack),
      ),
    );
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _glowPulse = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _glow, curve: Curves.easeOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.result != null) {
      _startFlip();
      return;
    }
    if (!MediaQuery.of(context).disableAnimations) {
      if (!_float.isAnimating) _float.repeat(reverse: true);
      if (!_ring.isAnimating) _ring.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _TossCoin old) {
    super.didUpdateWidget(old);
    if (old.result == null && widget.result != null) _startFlip();
  }

  void _startFlip() {
    if (_flipStarted) return;
    _flipStarted = true;
    _float.stop();
    _ring.stop();

    if (MediaQuery.of(context).disableAnimations) {
      _flip.value = 1;
      _glow.value = 1;
      _revealed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onLanded?.call();
      });
      return;
    }

    playSound(SoundEffect.coinFlip);
    _flip.forward().then((_) {
      if (!mounted) return;
      playSound(SoundEffect.coinLand);
      HapticFeedback.lightImpact();
      setState(() {
        _showFlash = true;
        _revealed = true;
      });
      _glow.forward();
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) setState(() => _showFlash = false);
      });
      widget.onLanded?.call();
    });
  }

  @override
  void dispose() {
    _float.dispose();
    _ring.dispose();
    _flip.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flipping = widget.result != null;
    // Neutral cyan until the coin settles; only then the outcome accent shows
    // (cyan = player won the call, red = CPU).
    final faceColor = _revealed && widget.won == false ? _kTossRed : _kTossCyan;
    return AnimatedBuilder(
      animation: Listenable.merge([_float, _ring, _flip, _glow]),
      builder: (context, _) {
        final ringOpacity = flipping ? (1 - _flip.value).clamp(0.0, 1.0) : 1.0;
        return SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Soft radial background glow.
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      faceColor.withValues(alpha: 0.10),
                      faceColor.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
              // Radar rings — fade out as the flip takes over.
              if (ringOpacity > 0) ...[
                Opacity(
                  opacity: ringOpacity,
                  child: Transform.rotate(
                    angle: _ringAnim.value,
                    child: const CustomPaint(
                      size: Size(220, 220),
                      painter: _RadarRingPainter(outer: true),
                    ),
                  ),
                ),
                Opacity(
                  opacity: ringOpacity,
                  child: Transform.rotate(
                    angle: -_ringAnim.value * 0.5,
                    child: const CustomPaint(
                      size: Size(168, 168),
                      painter: _RadarRingPainter(outer: false),
                    ),
                  ),
                ),
              ],
              if (_showFlash)
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
              flipping ? _buildFlipCoin(faceColor) : _buildIdleCoin(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIdleCoin() {
    return Transform.translate(
      offset: Offset(0, _floatAnim.value),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _coinSize,
            height: _coinSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xff1a3040), _kTossBg],
              ),
              border: Border.all(color: _kTossCyan, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _kTossCyan.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: _kTossCyan.withValues(alpha: 0.12),
                  blurRadius: 6,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: const CustomPaint(painter: _CoinFacePainter()),
          ),
          Container(
            width: 2,
            height: 14,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _kTossCyan.withValues(alpha: 0.55),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Container(
            width: 72,
            height: 8,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  _kTossCyan.withValues(alpha: 0.28),
                  _kTossCyan.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlipCoin(Color faceColor) {
    // While spinning, the visible face alternates every half-turn so the
    // outcome stays hidden; _angle ends on a whole number of turns, so the
    // coin settles showing the front face — which carries the actual result.
    final frontVisible = (((_angle.value + pi / 2) / pi).floor() % 2) == 0;
    final headsUp = frontVisible == (widget.result == 'heads');
    final glowBlur = 24.0 + _glowPulse.value * 40.0;
    final glowAlpha = 0.35 + _glowPulse.value * 0.45;
    return Transform.scale(
      scale: _settle.value.clamp(0.0, 1.10),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(_angle.value),
        child: Container(
          width: _coinSize,
          height: _coinSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xff1a3545), _kTossBg],
            ),
            border: Border.all(color: faceColor, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: faceColor.withValues(alpha: glowAlpha),
                blurRadius: glowBlur,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            // The back face renders mirrored under the coin's Y-rotation;
            // counter-rotate it so the letter always reads the right way.
            child: Transform(
              alignment: Alignment.center,
              transform: frontVisible
                  ? Matrix4.identity()
                  : (Matrix4.identity()..rotateY(pi)),
              child: Text(
                headsUp ? 'H' : 'T',
                style: Cyber.display(50, color: faceColor),
              ),
            ),
          ),
        ),
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
    final accent = finalized ? Cyber.success : _kTossCyan;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            finalized ? 'NEXT: SCENARIO BRIEFING' : 'CPU DECISION PROTOCOL',
            textAlign: TextAlign.center,
            style: Cyber.label(10, color: _kTossMuted, letterSpacing: 2),
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
// RoleRevealPhase  –  animated role-assignment beat
//   • CPU-won round 1:  CPU CHOSE x  →  YOUR ROLE
//   • Rounds 2–4:       ROLES SWITCHED  →  YOU NOW x
// ─────────────────────────────────────────────────────────────────────────────
class RoleRevealPhase extends StatefulWidget {
  const RoleRevealPhase({required this.state, required this.onQuit, super.key});
  final GameState state;
  final VoidCallback onQuit;

  @override
  State<RoleRevealPhase> createState() => _RoleRevealPhaseState();
}

class _RoleRevealPhaseState extends State<RoleRevealPhase>
    with TickerProviderStateMixin {
  late final AnimationController _c;
  // Drives the "auto-advance" hold bar after the reveal has landed.
  late final AnimationController _hold;
  late final Animation<double> _headlineAnim;
  late final Animation<double> _swapAnim;
  late final Animation<double> _badgeAnim;
  late final Animation<double> _ctaAnim;
  bool _badgeFired = false;
  bool _started = false;
  bool _advanced = false;

  bool get _attacking => widget.state.playerAttacking;
  // Round 1 only lands here when the player LOST the toss (CPU picked the role);
  // rounds 2–4 land here for the automatic alternating switch.
  bool get _isSwitch => max(1, widget.state.currentRound) > 1;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _headlineAnim = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.00, 0.30, curve: Curves.easeOut),
    );
    _swapAnim = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.25, 0.70, curve: Curves.easeInOut),
    );
    // easeOutBack gives one confident overshoot that settles, instead of the
    // multi-oscillation wobble of elasticOut that read as jitter on the badge.
    _badgeAnim = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.55, 0.90, curve: Curves.easeOutBack),
    );
    _ctaAnim = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.82, 1.00, curve: Curves.easeOut),
    );
    _c.addListener(_onTick);

    // After the reveal settles, hold briefly so the player can read the role,
    // then auto-advance to the scenario briefing (no tap required).
    _hold = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) _hold.forward();
    });
    _hold.addStatusListener((status) {
      if (status == AnimationStatus.completed) _advance();
    });
  }

  void _advance() {
    if (_advanced || !mounted) return;
    _advanced = true;
    context.read<GameBloc>().add(RoleRevealAcknowledged());
  }

  // Fire the sound/haptic once, as the focal badge lands. The visual flash is
  // derived from the animation in [_flashPulse] (no setState), so it fades in
  // and out in lockstep with the badge rather than popping on a timer.
  void _onTick() {
    if (_badgeFired || _c.value < 0.66) return;
    _badgeFired = true;
    playSound(_attacking ? SoundEffect.attack : SoundEffect.defense);
    HapticFeedback.mediumImpact();
  }

  // Smooth 0 → 1 → 0 white bloom synced to the badge landing.
  double get _flashPulse {
    const start = 0.62, end = 0.88;
    final v = ((_c.value - start) / (end - start)).clamp(0.0, 1.0);
    return sin(v * pi);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1.0; // jump to the settled reveal; _onTick still fires once.
      _hold.duration = const Duration(milliseconds: 1100);
      _hold.forward(); // status listener auto-advances when the hold completes.
    } else {
      _c.forward(); // completion kicks off _hold, which then auto-advances.
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onTick);
    _c.dispose();
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final round = max(1, widget.state.currentRound);
    final accent = _roleAccent(_attacking);
    final roleName = _attacking ? 'ATTACK' : 'DEFEND';
    final roleIcon = _attacking ? Icons.sports_soccer : Icons.shield;
    final headline = _isSwitch ? 'ROLES SWITCHED' : 'CPU WON THE TOSS';
    final badgeCaption = _isSwitch ? 'YOU NOW' : 'YOUR ROLE';

    return Scaffold(
      backgroundColor: _kTossBg,
      body: Stack(
        children: [
          const Positioned.fill(child: StadiumBackground()),
          // Isolate the per-frame reveal repaint from the ambient background.
          SafeArea(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TossTopBar(
                      round: round,
                      label: 'ROLE ASSIGNMENT',
                      onQuit: widget.onQuit,
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Opacity(
                                opacity: _headlineAnim.value.clamp(0.0, 1.0),
                                child: Transform.translate(
                                  offset: Offset(
                                    0,
                                    16 * (1 - _headlineAnim.value),
                                  ),
                                  child: Text(
                                    headline,
                                    textAlign: TextAlign.center,
                                    style: Cyber.display(
                                      24,
                                      color: Colors.white,
                                      letterSpacing: 2.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              _buildSwapRow(accent),
                              const SizedBox(height: 32),
                              _buildBadge(
                                accent,
                                roleName,
                                roleIcon,
                                badgeCaption,
                              ),
                              const SizedBox(height: 16),
                              Opacity(
                                opacity: _badgeAnim.value.clamp(0.0, 1.0),
                                child: Text(
                                  'PICK CARDS THAT MATCH YOUR ROLE',
                                  textAlign: TextAlign.center,
                                  style: Cyber.body(12, color: _kTossMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: _ctaAnim.value.clamp(0.0, 1.0),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(40, 0, 40, 28),
                        child: Column(
                          children: [
                            Text(
                              'NEXT: SCENARIO BRIEFING',
                              textAlign: TextAlign.center,
                              style: Cyber.label(
                                10,
                                color: _kTossMuted,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 3,
                              child: AnimatedBuilder(
                                animation: _hold,
                                builder: (context, _) => Stack(
                                  children: [
                                    Container(
                                      color: accent.withValues(alpha: 0.15),
                                    ),
                                    FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: _hold.value.clamp(0.0, 1.0),
                                      child: Container(color: accent),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildSwapRow(Color accent) {
    final t = _swapAnim.value.clamp(0.0, 1.0);
    if (_isSwitch) {
      // ATTACK ⇄ DEFEND: the highlight crosses from the old role to the new one.
      final attackHighlight = _attacking ? t : 1 - t;
      final defendHighlight = _attacking ? 1 - t : t;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _RoleRevealChip(
            role: 'ATTACK',
            icon: Icons.sports_soccer,
            accent: Cyber.cyan,
            highlight: attackHighlight,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Transform.rotate(
              angle: t * pi,
              child: Icon(
                Icons.swap_horiz,
                color: Color.lerp(_kTossMuted, Colors.white, t),
                size: 30,
              ),
            ),
          ),
          _RoleRevealChip(
            role: 'DEFEND',
            icon: Icons.shield,
            accent: const Color(0xFFC084FC),
            highlight: defendHighlight,
          ),
        ],
      );
    }
    // CPU won round 1: CPU CHOSE x  →  YOU get the opposite role.
    final cpuAttacking = !_attacking;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoleRevealChip(
          caption: 'CPU CHOSE',
          role: cpuAttacking ? 'ATTACK' : 'DEFEND',
          icon: cpuAttacking ? Icons.sports_soccer : Icons.shield,
          accent: _kTossRed,
          highlight: 0.85,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Opacity(
            opacity: t,
            child: Icon(
              Icons.arrow_forward,
              color: Color.lerp(_kTossMuted, accent, t),
              size: 28,
            ),
          ),
        ),
        _RoleRevealChip(
          caption: 'YOU',
          role: _attacking ? 'ATTACK' : 'DEFEND',
          icon: _attacking ? Icons.sports_soccer : Icons.shield,
          accent: accent,
          highlight: t,
        ),
      ],
    );
  }

  Widget _buildBadge(
    Color accent,
    String roleName,
    IconData roleIcon,
    String caption,
  ) {
    return Transform.scale(
      scale: _badgeAnim.value.clamp(0.0, 1.3),
      child: Opacity(
        opacity: _badgeAnim.value.clamp(0.0, 1.0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_flashPulse > 0.01)
              Container(
                width: 240,
                height: 104,
                color: Colors.white.withValues(alpha: 0.18 * _flashPulse),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                border: Border.all(color: accent, width: 1.6),
                boxShadow: Cyber.glow(accent, alpha: 0.5, blur: 30, spread: 0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    caption,
                    style: Cyber.label(
                      11,
                      color: accent.withValues(alpha: 0.85),
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(roleIcon, color: accent, size: 30),
                      const SizedBox(width: 12),
                      Text(
                        roleName,
                        style: Cyber.display(
                          40,
                          color: accent,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleRevealChip extends StatelessWidget {
  const _RoleRevealChip({
    required this.role,
    required this.icon,
    required this.accent,
    required this.highlight,
    this.caption,
  });

  final String role;
  final IconData icon;
  final Color accent;
  final double highlight; // 0..1 — how "lit" this chip is
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final h = highlight.clamp(0.0, 1.0);
    final roleColor = Color.lerp(_kTossMuted, accent, h)!;
    return Transform.scale(
      scale: 0.94 + 0.08 * h,
      child: Container(
        width: 108,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.04 + 0.10 * h),
          border: Border.all(
            color: accent.withValues(alpha: 0.25 + 0.55 * h),
            width: 1 + 0.6 * h,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (caption != null) ...[
              Text(
                caption!,
                style: Cyber.label(
                  9,
                  color: roleColor.withValues(alpha: 0.9),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Icon(icon, color: roleColor, size: 26),
            const SizedBox(height: 6),
            Text(
              role,
              style: Cyber.label(12, color: roleColor, letterSpacing: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ══════════════════════════════════════════════════════════════════════════════

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
                  style: Cyber.label(9, color: _kTossMuted, letterSpacing: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Heads/Tails call card for the idle toss — same silhouette as the role-choice
// card, but the glyph is a ringed coin face (H/T) echoing the coin above.
// ─────────────────────────────────────────────────────────────────────────────
class _CallChoiceButton extends StatefulWidget {
  const _CallChoiceButton({
    required this.face,
    required this.label,
    required this.accent,
    required this.onTap,
  });
  final String face;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_CallChoiceButton> createState() => _CallChoiceButtonState();
}

class _CallChoiceButtonState extends State<_CallChoiceButton>
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
            height: 96,
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
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent.withValues(alpha: 0.7),
                      width: 1.4,
                    ),
                  ),
                  child: Text(
                    widget.face,
                    style: Cyber.display(15, color: accent),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.label,
                  style: Cyber.display(17, color: accent, letterSpacing: 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Painters & clippers
// ══════════════════════════════════════════════════════════════════════════════

class _RadarRingPainter extends CustomPainter {
  const _RadarRingPainter({required this.outer});
  final bool outer;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = _kTossCyan.withValues(alpha: outer ? 0.20 : 0.30)
        ..strokeWidth = outer ? 1.0 : 1.5
        ..style = PaintingStyle.stroke,
    );

    final tickPaint = Paint()
      ..color = _kTossCyan.withValues(alpha: outer ? 0.35 : 0.55)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final count = outer ? 36 : 8;
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * pi;
      final tickLen = outer ? (i % 4 == 0 ? 8.0 : 4.0) : 10.0;
      canvas.drawLine(
        Offset(
          center.dx + cos(angle) * (radius - tickLen),
          center.dy + sin(angle) * (radius - tickLen),
        ),
        Offset(
          center.dx + cos(angle) * radius,
          center.dy + sin(angle) * radius,
        ),
        tickPaint,
      );
    }

    if (!outer) {
      // Cardinal bracket marks at N / E / S / W
      final bp = Paint()
        ..color = _kTossCyan.withValues(alpha: 0.60)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < 4; i++) {
        final a = i * (pi / 2);
        final bx = center.dx + cos(a) * (radius + 5);
        final by = center.dy + sin(a) * (radius + 5);
        canvas.drawLine(
          Offset(bx - sin(a) * 8, by + cos(a) * 8),
          Offset(bx + sin(a) * 8, by - cos(a) * 8),
          bp,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RadarRingPainter old) => old.outer != outer;
}

class _CoinFacePainter extends CustomPainter {
  const _CoinFacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.58;
    final stroke = Paint()
      ..color = _kTossCyan.withValues(alpha: 0.70)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      true,
      Paint()
        ..color = _kTossCyan.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill,
    );
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      stroke,
    );
    canvas.drawCircle(center, radius, stroke);
    canvas.drawCircle(
      center,
      3,
      Paint()
        ..color = _kTossCyan.withValues(alpha: 0.90)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_CoinFacePainter _) => false;
}

class ScenarioPhase extends StatefulWidget {
  const ScenarioPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  State<ScenarioPhase> createState() => _ScenarioPhaseState();
}

class _ScenarioPhaseState extends State<ScenarioPhase> {
  final _briefingKey = GlobalKey<_ScenarioBriefingSectionState>();

  List<SpotlightStep> get _spotlightSteps => [
    SpotlightStep(
      targetKey: _briefingKey,
      title: 'Scenario',
      body: 'Read the scenario. ATK/DEF bonuses apply this round.',
      icon: Icons.flag,
      accent: Cyber.lime,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scenario = widget.state.currentScenario;
    if (scenario == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final roundOne = widget.state.currentRound == 1;
    final walkthroughMatch =
        roundOne &&
        !context.watch<GameBloc>().state.tutorialSeen.contains('scenario');
    return MatchPhaseScaffold(
      title: 'Round ${max(1, widget.state.currentRound)}',
      subtitle: '// Scenario Briefing',
      state: widget.state,
      onQuit: widget.onQuit,
      spotlightKey: walkthroughMatch ? 'scenario' : null,
      spotlightSteps: walkthroughMatch ? _spotlightSteps : const [],
      spotlightEnabled: walkthroughMatch,
      spotlightDelay: const Duration(milliseconds: 450),
      spotlightOnComplete: () => _briefingKey.currentState?.beginCountdown(),
      spotlightCardAnchor: SpotlightCardAnchor.bottom,
      spotlightCardBottomInset: 24,
      children: [
        ScenarioBriefingSection(
          key: _briefingKey,
          scenario: scenario,
          attacking: widget.state.playerAttacking,
          initialSeconds: 3,
          deferCountdown: walkthroughMatch,
        ),
      ],
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
      _ScenarioBriefingSectionState();
}

class _ScenarioBriefingSectionState extends State<ScenarioBriefingSection>
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
        return Center(
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
                child: _RadarTargetIcon(accent: accent),
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
                  style: Cyber.body(
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
            const SizedBox(height: 20),
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

class _RadarTargetIcon extends StatelessWidget {
  const _RadarTargetIcon({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(46, 46),
      painter: _RadarTargetPainter(accent),
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

class _RadarTargetPainter extends CustomPainter {
  const _RadarTargetPainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final line = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final faint = Paint()
      ..color = accent.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, radius - 2, line);
    canvas.drawCircle(center, radius * 0.42, line);
    canvas.drawCircle(center, radius * 0.18, Paint()..color = accent);
    canvas.drawLine(Offset(center.dx, 4), Offset(center.dx, 10), faint);
    canvas.drawLine(
      Offset(center.dx, size.height - 4),
      Offset(center.dx, size.height - 10),
      faint,
    );
    canvas.drawLine(Offset(4, center.dy), Offset(10, center.dy), faint);
    canvas.drawLine(
      Offset(size.width - 4, center.dy),
      Offset(size.width - 10, center.dy),
      faint,
    );
  }

  @override
  bool shouldRepaint(_RadarTargetPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

// ─────────────────────────────────────────────────────────────────────────────
// Match-phase entrance animators
// ─────────────────────────────────────────────────────────────────────────────

/// Slides any child up from below + fades it in. Used for section headings
/// and the top informational panels so the page composes itself in a sweep
/// rather than appearing all at once.
class _SlideUpFadeIn extends StatefulWidget {
  const _SlideUpFadeIn({
    required this.child,
    this.delay = Duration.zero,
    this.offset = 30.0,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<_SlideUpFadeIn> createState() => _SlideUpFadeInState();
}

class _SlideUpFadeInState extends State<_SlideUpFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _t;
  Timer? _kickoff;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _t = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _kickoff = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _kickoff?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (_, child) => Opacity(
        opacity: _t.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _t.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Animates a card as if it is being dealt onto a table: it travels up from
/// off-screen with a touch of tilt, then settles in place with a small
/// over-shoot scale bounce. Per-card stagger is keyed off [index].
class _DealtCard extends StatefulWidget {
  const _DealtCard({
    required this.index,
    required this.child,
    this.initialDelay = const Duration(milliseconds: 220),
    this.staggerMs = 75,
    this.flyDistance = 260.0,
    this.duration = const Duration(milliseconds: 540),
    super.key,
  });

  final int index;
  final Widget child;
  final Duration initialDelay;
  final int staggerMs;
  final double flyDistance;
  final Duration duration;

  @override
  State<_DealtCard> createState() => _DealtCardState();
}

class _DealtCardState extends State<_DealtCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _slide;
  late final Animation<double> _settle;
  late final Animation<double> _opacity;
  late final Animation<double> _tilt;
  Timer? _kickoff;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _slide = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _settle = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
    _opacity = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
    );
    _tilt = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

    final delay =
        widget.initialDelay +
        Duration(milliseconds: widget.index * widget.staggerMs);
    _kickoff = Timer(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _kickoff?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        const tiltAmount = 0.07;
        final tiltAngle =
            (widget.index.isEven ? -tiltAmount : tiltAmount) *
            (1 - _tilt.value);
        return Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, widget.flyDistance * (1 - _slide.value)),
            child: Transform.rotate(
              angle: tiltAngle,
              child: Transform.scale(
                scale: _settle.value.clamp(0.5, 1.2),
                child: child,
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class PlayPhase extends StatefulWidget {
  const PlayPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  State<PlayPhase> createState() => _PlayPhaseState();
}

class _PlayPhaseState extends State<PlayPhase> {
  final _powerKey = GlobalKey();
  final _playersKey = GlobalKey();
  final _actionsKey = GlobalKey();

  List<SpotlightStep> get _spotlightSteps => [
    SpotlightStep(
      targetKey: _powerKey,
      title: 'Power Preview',
      body: 'OVR + action + bonus. Timing adds up to +20.',
      icon: Icons.bolt,
      accent: Cyber.gold,
    ),
    SpotlightStep(
      targetKey: _playersKey,
      title: 'Player Card',
      body: 'Pick one player. OVR is base power.',
      icon: Icons.person,
      accent: Cyber.cyan,
    ),
    SpotlightStep(
      targetKey: _actionsKey,
      title: 'Action Card',
      body: 'Pick one action for your role.',
      icon: Icons.style,
      accent: Cyber.magenta,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final playerPool = state.playerAttacking
        ? state.deckAttackers
        : state.deckDefenders;
    final sectionLabel = state.playerAttacking
        ? 'SELECT AN ATTACKER'
        : 'SELECT A DEFENDER FROM YOUR DECK';
    final lockLabel = state.playerAttacking ? 'LOCK ATTACK' : 'LOCK DEFENSE';
    final roleAccent = _roleAccent(state.playerAttacking);
    final hasCompleteSelection =
        state.selectedPlayerCard != null && state.selectedActionCard != null;
    final availableActions = state.deckActions
        .where(
          (card) => state.playerAttacking
              ? card.category == ActionCategory.attack ||
                    card.category == ActionCategory.special
              : card.category == ActionCategory.defense ||
                    card.category == ActionCategory.special,
        )
        .toList();
    final scenarioBonus = state.playerAttacking
        ? state.currentScenario?.attackBonus ?? 0
        : state.currentScenario?.defenseBonus ?? 0;
    final selectedAction = state.selectedActionCard;
    final isRisky = selectedAction?.risky ?? false;
    final basePower = !hasCompleteSelection
        ? null
        : state.selectedPlayerCard!.rating +
              selectedAction!.power +
              scenarioBonus;
    final successChance = basePower == null
        ? null
        : _playerSuccessChance(state, basePower.toDouble());
    final chanceLabel = state.playerAttacking ? 'GOAL CHANCE' : 'STOP CHANCE';
    final chancePct = successChance == null
        ? null
        : (successChance * 100).round();
    final roundOne = state.currentRound == 1;

    return MatchPhaseScaffold(
      title: 'Round ${max(1, state.currentRound)}',
      subtitle: state.currentScenario?.title ?? '// Play Protocol',
      state: state,
      onQuit: widget.onQuit,
      spotlightKey: roundOne ? 'play' : null,
      spotlightSteps: roundOne ? _spotlightSteps : const [],
      spotlightEnabled: roundOne,
      spotlightDelay: const Duration(milliseconds: 700),
      bottomAction: hasCompleteSelection
          ? BottomLockButton(
              label: lockLabel,
              helper:
                  '$chancePct% ${state.playerAttacking ? 'GOAL' : 'STOP'} · TAP TO STRIKE',
              accent: roleAccent,
              onPressed: () async {
                final bloc = context.read<GameBloc>();
                if (MediaQuery.of(context).disableAnimations) {
                  bloc.add(MovePlayed());
                  return;
                }
                final surge = await showShotMeter(
                  context,
                  base: basePower!.toDouble(),
                  accent: roleAccent,
                  chanceLabel: chanceLabel,
                  successChance: successChance!,
                  isRisky: isRisky,
                );
                if (surge != null) bloc.add(MovePlayed(playerSurge: surge));
              },
            )
          : null,
      children: [
        _SlideUpFadeIn(
          child: ScenarioPanel(
            scenario: state.currentScenario,
            attacking: state.playerAttacking,
            bonus: scenarioBonus,
            accent: roleAccent,
            isRisky: isRisky,
          ),
        ),
        _SlideUpFadeIn(
          delay: const Duration(milliseconds: 90),
          child: SpotlightTarget(
            spotlightKey: _powerKey,
            child: PowerPreviewBar(
              player: state.selectedPlayerCard,
              action: state.selectedActionCard,
              bonus: scenarioBonus,
              total: basePower,
              maxPower: basePower == null ? null : basePower + 20,
              attacking: state.playerAttacking,
              accent: roleAccent,
            ),
          ),
        ),
        SpotlightTarget(
          spotlightKey: _playersKey,
          child: DefenderDeckGrid(
            title: sectionLabel,
            cards: playerPool,
            selectedId: state.selectedPlayerCard?.id,
            redCardedIds: state.redCardedCards,
            attacking: state.playerAttacking,
            accent: roleAccent,
            onSelect: (card) =>
                context.read<GameBloc>().add(PlayerSelected(card)),
          ),
        ),
        SpotlightTarget(
          spotlightKey: _actionsKey,
          child: ActionCardRail(
            cards: availableActions,
            selectedId: state.selectedActionCard?.id,
            usedIds: state.usedActionCards,
            accent: roleAccent,
            onSelect: (card) =>
                context.read<GameBloc>().add(ActionSelected(card)),
          ),
        ),
      ],
    );
  }
}

class ScenarioPanel extends StatelessWidget {
  const ScenarioPanel({
    required this.scenario,
    required this.attacking,
    required this.bonus,
    required this.accent,
    this.isRisky = false,
    super.key,
  });

  final ScenarioCard? scenario;
  final bool attacking;
  final int bonus;
  final Color accent;
  final bool isRisky;

  @override
  Widget build(BuildContext context) {
    final title = attacking
        ? '${(scenario?.title ?? 'Final Third').toUpperCase()} // FINISHERS'
        : 'NO STER // STOPPERS';
    // Border + tinted fill removed: the scenario header now reads as plain
    // text/chips on the background. Dropping the 12px vertical padding also
    // nudges the whole header up a little.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Cyber.display(20, color: accent, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                label: attacking ? 'ATK BONUS' : 'DEF BONUS',
                value: '+$bonus',
                accent: accent,
              ),
              // Truthful now: reflects the selected action's risk instead of a
              // hardcoded value. Risky actions carry a 12% foul/red-card chance.
              _InfoChip(
                label: 'RISK',
                value: isRisky ? 'HIGH' : 'LOW',
                accent: isRisky ? Cyber.danger : Cyber.muted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Cyber.label(10, color: accent, letterSpacing: 1)),
          const SizedBox(width: 10),
          Text(value, style: Cyber.display(16, color: Colors.white)),
        ],
      ),
    );
  }
}

class PowerPreviewBar extends StatelessWidget {
  const PowerPreviewBar({
    required this.player,
    required this.action,
    required this.bonus,
    required this.total,
    required this.maxPower,
    required this.attacking,
    required this.accent,
    super.key,
  });

  final PlayerCard? player;
  final ActionCard? action;
  final int bonus;
  final int? total;
  final int? maxPower;
  final bool attacking;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AngularBorderContainer(
      accent: Cyber.line,
      glow: false,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
      child: Column(
        children: [
          Text(
            attacking ? 'ATK POWER PREVIEW' : 'DEF POWER PREVIEW',
            style: Cyber.label(11, color: accent, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  attacking ? Icons.sports_soccer : Icons.shield,
                  color: accent,
                  size: 18,
                ),
                const SizedBox(width: 10),
                _PowerText(
                  player == null ? '--' : '${player!.rating}',
                  color: accent,
                ),
                _PowerSymbol('+', color: accent),
                Icon(
                  action?.icon ?? Icons.grid_view,
                  color: Cyber.magenta,
                  size: 18,
                ),
                const SizedBox(width: 10),
                _PowerText(
                  action == null ? '--' : '${action!.power}',
                  color: Cyber.magenta,
                ),
                _PowerSymbol('+', color: accent),
                Text('BONUS', style: Cyber.label(11, color: accent)),
                const SizedBox(width: 8),
                _PowerText('+$bonus', color: Cyber.success),
                _PowerSymbol('=', color: accent),
                // Honest range (floor..floor+20) rather than a fake exact total.
                _PowerText(
                  total == null ? '--' : '$total–$maxPower',
                  color: Cyber.gold,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PowerText extends StatelessWidget {
  const _PowerText(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Cyber.display(19, color: color));
  }
}

class _PowerSymbol extends StatelessWidget {
  const _PowerSymbol(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(text, style: Cyber.display(18, color: color)),
    );
  }
}

class DefenderDeckGrid extends StatelessWidget {
  const DefenderDeckGrid({
    required this.title,
    required this.cards,
    required this.selectedId,
    required this.redCardedIds,
    required this.attacking,
    required this.accent,
    required this.onSelect,
    super.key,
  });

  final String title;
  final List<PlayerCard> cards;
  final String? selectedId;
  final List<String> redCardedIds;
  final bool attacking;
  final Color accent;
  final ValueChanged<PlayerCard> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        _SlideUpFadeIn(
          delay: const Duration(milliseconds: 180),
          offset: 18,
          child: _PlaySectionHeading(title, color: accent),
        ),
        const SizedBox(height: 12),
        _PlaySelectionBackdrop(
          bright: true,
          accent: accent,
          pitchHalf: attacking ? PitchHalf.top : PitchHalf.bottom,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.66,
            ),
            itemBuilder: (context, index) {
              final card = cards[index];
              final disabled = redCardedIds.contains(card.id);
              return _DealtCard(
                key: ValueKey('deck-${card.id}'),
                index: index,
                initialDelay: const Duration(milliseconds: 260),
                child: Center(
                  child: CyberPlayerCardTile(
                    card: card,
                    selected: selectedId == card.id,
                    disabled: disabled,
                    size: VisualCardSize.lg,
                    selectedAccent: accent,
                    onTap: disabled ? null : () => onSelect(card),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PlaySectionHeading extends StatelessWidget {
  const _PlaySectionHeading(this.title, {this.color = Cyber.cyan});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Cyber.label(16, color: color, letterSpacing: 1.1),
    );
  }
}

/// Full-bleed backdrop behind card pickers — optional pitch half + role tint.
class _PlaySelectionBackdrop extends StatelessWidget {
  const _PlaySelectionBackdrop({
    required this.bright,
    required this.accent,
    required this.child,
    this.pitchHalf,
    this.showTint = true,
    this.horizontalPadding = _listPadding,
    this.topPadding = 14,
    this.bottomPadding = 14,
  });

  static const _listPadding = 16.0;

  final bool bright;
  final Color accent;
  final Widget child;
  final PitchHalf? pitchHalf;
  final bool showTint;
  final double horizontalPadding;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    // Must match [MatchPhaseScaffold] ListView horizontal padding (16).
    final screenW = MediaQuery.sizeOf(context).width;
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideInset = (screenW - constraints.maxWidth) / 2;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (showTint)
              Positioned(
                left: -sideInset,
                right: -sideInset,
                top: 0,
                bottom: 0,
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (pitchHalf != null)
                        PitchHalfBackground(half: pitchHalf!)
                      else
                        ColoredBox(
                          color: bright
                              ? accent.withValues(alpha: 0.18)
                              : accent.withValues(alpha: 0.12),
                        ),
                      ColoredBox(
                        color: accent.withValues(alpha: bright ? 0.08 : 0.05),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                topPadding,
                horizontalPadding,
                bottomPadding,
              ),
              child: child,
            ),
          ],
        );
      },
    );
  }
}

class ActionCardRail extends StatelessWidget {
  const ActionCardRail({
    required this.cards,
    required this.selectedId,
    required this.accent,
    required this.onSelect,
    this.usedIds = const [],
    super.key,
  });

  final List<ActionCard> cards;
  final String? selectedId;
  final Color accent;
  final ValueChanged<ActionCard> onSelect;
  final List<String> usedIds;

  @override
  Widget build(BuildContext context) {
    // Estimated time the deck grid's last card finishes landing so the action
    // rail enters as the deck visibly settles.
    const railBaseDelay = Duration(milliseconds: 620);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SlideUpFadeIn(
          delay: railBaseDelay,
          offset: 18,
          child: _PlaySectionHeading('SELECT AN ACTION', color: accent),
        ),
        const SizedBox(height: 4),
        _PlaySelectionBackdrop(
          bright: false,
          accent: accent,
          showTint: false,
          horizontalPadding: 0,
          topPadding: 0,
          bottomPadding: 0,
          child: SizedBox(
            // lg tile (148) × selection scale (1.12) + hard shadow (6) + lift (5).
            height: 188,
            child: ListView.separated(
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
              itemCount: cards.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final card = cards[index];
                final used = usedIds.contains(card.id);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _DealtCard(
                      key: ValueKey('action-${card.id}'),
                      index: index,
                      initialDelay:
                          railBaseDelay + const Duration(milliseconds: 80),
                      staggerMs: 65,
                      flyDistance: 200,
                      duration: const Duration(milliseconds: 480),
                      child: CyberActionCardTile(
                        card: card,
                        selected: selectedId == card.id,
                        disabled: used,
                        disabledLabel: 'USED',
                        size: VisualCardSize.lg,
                        selectedAccent: accent,
                        onTap: used ? null : () => onSelect(card),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Primary "lock in your move" CTA. Reuses the Play Match button treatment
/// (angular HUD silhouette, pulsing glow, haptic) so committing a move feels as
/// premium as starting a match. Opening the Shot Meter is the actual action.
class BottomLockButton extends StatelessWidget {
  const BottomLockButton({
    required this.label,
    required this.helper,
    required this.accent,
    required this.onPressed,
    super.key,
  });

  final String label;
  final String helper;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return HudCtaButton(
      label: label,
      helper: helper,
      icon: Icons.sports_soccer,
      accent: accent,
      // The round's decisive action — a meatier "commit" cue, not a plain tap.
      tapSound: SoundEffect.commit,
      height: 70,
      onTap: onPressed,
    );
  }
}

/// The player's honest success probability for the current selection: goal
/// chance when attacking, save/stop chance when defending. Uses the same
/// thresholds the engine resolves with ([goalChanceForDiff]).
double _playerSuccessChance(GameState state, double basePower) {
  const meanSwing = 10.0; // expected value of the hidden 0..20 swing
  final playerExpected = basePower + meanSwing;
  final oppExpected = _opponentPowerEstimate(state) + meanSwing;
  if (state.playerAttacking) {
    return goalChanceForDiff(playerExpected - oppExpected);
  }
  return 1 - goalChanceForDiff(oppExpected - playerExpected);
}

/// A scouting estimate of the opponent's power this round — the averages of
/// their relevant player and action pools plus the scenario bonus. No specific
/// opponent card is revealed.
double _opponentPowerEstimate(GameState state) {
  final scenario = state.currentScenario;
  final players = state.playerAttacking
      ? state.opponentDefenders
      : state.opponentAttackers;
  final live = players
      .where((c) => !state.opponentRedCarded.contains(c.id))
      .toList();
  final ratingPool = live.isEmpty ? players : live;
  final relevantCategory = state.playerAttacking
      ? ActionCategory.defense
      : ActionCategory.attack;
  final relevant = state.opponentActions
      .where(
        (a) =>
            a.category == relevantCategory ||
            a.category == ActionCategory.special,
      )
      .toList();
  final actionPool = relevant.isEmpty ? state.opponentActions : relevant;
  final avgRating = ratingPool.isEmpty
      ? 75.0
      : ratingPool.map((c) => c.rating).reduce((a, b) => a + b) /
            ratingPool.length;
  final avgPower = actionPool.isEmpty
      ? 10.0
      : actionPool.map((a) => a.power).reduce((a, b) => a + b) /
            actionPool.length;
  final bonus = state.playerAttacking
      ? scenario?.defenseBonus ?? 0
      : scenario?.attackBonus ?? 0;
  return avgRating + avgPower + bonus;
}

/// Opens the Shot Meter — a focused timing strike that sets the player's power
/// swing (0..20). Returns the surge, or null if dismissed without striking.
Future<double?> showShotMeter(
  BuildContext context, {
  required double base,
  required Color accent,
  required String chanceLabel,
  required double successChance,
  required bool isRisky,
}) {
  return showGeneralDialog<double>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Shot Meter',
    barrierColor: Colors.black.withValues(alpha: 0.74),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => ShotMeterOverlay(
      base: base,
      accent: accent,
      chanceLabel: chanceLabel,
      successChance: successChance,
      isRisky: isRisky,
    ),
    transitionBuilder: (context, anim, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
      child: child,
    ),
  );
}

/// The transient strike overlay. All the new round-phase richness (odds, range,
/// the timed strike and its feedback) lives here so the resting screen stays
/// clean. Tapping anywhere strikes.
class ShotMeterOverlay extends StatefulWidget {
  const ShotMeterOverlay({
    required this.base,
    required this.accent,
    required this.chanceLabel,
    required this.successChance,
    required this.isRisky,
    super.key,
  });

  final double base;
  final Color accent;
  final String chanceLabel;
  final double successChance; // 0..1
  final bool isRisky;

  @override
  State<ShotMeterOverlay> createState() => _ShotMeterOverlayState();
}

class _ShotMeterOverlayState extends State<ShotMeterOverlay>
    with SingleTickerProviderStateMixin {
  static const double _sweetCenter = 0.72;
  static const double _halfZone = 0.07;

  final _meterKey = GlobalKey();

  List<SpotlightStep> get _spotlightSteps => [
    SpotlightStep(
      targetKey: _meterKey,
      title: 'Shot Meter',
      body: 'Tap in the sweet zone for up to +20 power.',
      icon: Icons.speed,
      accent: widget.accent,
      padding: 10,
    ),
  ];

  late final AnimationController _sweep;
  bool _struck = false;
  double _frozenAt = 0;
  String _tier = '';
  int _surge = 0;
  int _lastTickBucket = -1;

  @override
  void initState() {
    super.initState();
    _sweep =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 900),
          )
          ..addListener(_onSweep)
          ..repeat(reverse: true);
    // Build tension the moment the meter appears.
    playSound(SoundEffect.riser);
  }

  void _onSweep() {
    if (_struck) return;
    // Escalating tick as the marker closes on the sweet zone.
    final near = (1 - (_sweep.value - _sweetCenter).abs() / 0.5).clamp(
      0.0,
      1.0,
    );
    if (near > 0.55) {
      final bucket = (near * 6).floor();
      if (bucket != _lastTickBucket) {
        _lastTickBucket = bucket;
        playSound(SoundEffect.countdownTick);
        HapticFeedback.selectionClick();
      }
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  void _strike() {
    if (_struck) return;
    final pos = _sweep.value;
    _sweep.stop();
    final d = (pos - _sweetCenter).abs();
    final quality = (1.0 - d / 0.5).clamp(0.0, 1.0);
    final surge = (20.0 * quality).round();
    final String tier;
    if (d <= 0.045) {
      tier = 'PERFECT';
    } else if (d <= _halfZone) {
      tier = 'GREAT';
    } else if (quality >= 0.45) {
      tier = 'GOOD';
    } else {
      tier = pos < _sweetCenter ? 'EARLY' : 'LATE';
    }
    if (tier == 'PERFECT') {
      HapticFeedback.heavyImpact();
      playSound(SoundEffect.special);
    } else {
      HapticFeedback.mediumImpact();
    }
    setState(() {
      _struck = true;
      _frozenAt = pos;
      _tier = tier;
      _surge = surge;
    });
    // Hold the result briefly, then resolve into the cinematic round result.
    Future.delayed(const Duration(milliseconds: 740), () {
      if (mounted) Navigator.of(context).pop(surge.toDouble());
    });
  }

  Color get _resultColor => switch (_tier) {
    'PERFECT' || 'GREAT' => Cyber.success,
    'GOOD' => Cyber.amber,
    _ => Cyber.danger,
  };

  @override
  Widget build(BuildContext context) {
    final pct = (widget.successChance * 100).round();
    final minP = widget.base.round();
    final maxP = (widget.base + 20).round();
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _strike,
          child: SafeArea(
            child: Align(
              alignment: const Alignment(0, 0.55),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AngularBorderContainer(
                  accent: widget.accent,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.chanceLabel,
                                style: Cyber.label(
                                  10,
                                  color: widget.accent,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('$pct%', style: Cyber.display(28)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'POWER',
                                style: Cyber.label(
                                  10,
                                  color: Cyber.muted,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$minP–$maxP',
                                style: Cyber.display(22, color: Cyber.gold),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SpotlightTarget(
                        spotlightKey: _meterKey,
                        child: SizedBox(
                          height: 30,
                          width: double.infinity,
                          child: AnimatedBuilder(
                            animation: _sweep,
                            builder: (context, _) => CustomPaint(
                              painter: _ShotMeterPainter(
                                progress: _struck ? _frozenAt : _sweep.value,
                                sweetCenter: _sweetCenter,
                                halfZone: _halfZone,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_struck)
                        Text(
                          _tier == 'EARLY' || _tier == 'LATE'
                              ? '$_tier   +$_surge'
                              : '$_tier!   +$_surge POWER',
                          style: Cyber.display(20, color: _resultColor),
                        )
                      else ...[
                        Text(
                          '— TAP TO STRIKE —',
                          style: Cyber.label(
                            13,
                            color: widget.accent,
                            letterSpacing: 2,
                          ),
                        ),
                        if (widget.isRisky) ...[
                          const SizedBox(height: 8),
                          Text(
                            'RISKY ACTION · 12% FOUL',
                            style: Cyber.label(
                              9,
                              color: Cyber.danger,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SpotlightTutorial(
          keyName: 'shot-meter',
          steps: _spotlightSteps,
          startDelay: const Duration(milliseconds: 420),
        ),
      ],
    );
  }
}

class _ShotMeterPainter extends CustomPainter {
  _ShotMeterPainter({
    required this.progress,
    required this.sweetCenter,
    required this.halfZone,
  });

  final double progress; // 0..1 marker position
  final double sweetCenter;
  final double halfZone;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, radius);

    canvas.save();
    canvas.clipRRect(rrect);
    // Track gradient: danger → amber → success (sweet) → amber → danger.
    final shader = const LinearGradient(
      colors: [
        Cyber.danger,
        Cyber.amber,
        Cyber.success,
        Cyber.amber,
        Cyber.danger,
      ],
      stops: [0.0, 0.45, 0.72, 0.86, 1.0],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = shader);
    canvas.drawRect(
      rect,
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
    // Brighter sweet-zone band.
    final zoneLeft = (sweetCenter - halfZone) * size.width;
    final zoneRight = (sweetCenter + halfZone) * size.width;
    canvas.drawRect(
      Rect.fromLTRB(zoneLeft, 0, zoneRight, size.height),
      Paint()..color = Cyber.success.withValues(alpha: 0.42),
    );
    canvas.restore();

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.22),
    );

    // Marker with a soft glow.
    final x = progress.clamp(0.0, 1.0) * size.width;
    canvas.drawLine(
      Offset(x, -4),
      Offset(x, size.height + 4),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawLine(
      Offset(x, -4),
      Offset(x, size.height + 4),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ShotMeterPainter old) =>
      old.progress != progress ||
      old.sweetCenter != sweetCenter ||
      old.halfZone != halfZone;
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

class RoundResultPhase extends StatefulWidget {
  const RoundResultPhase({
    required this.state,
    required this.onQuit,
    super.key,
  });

  final GameState state;
  final VoidCallback onQuit;

  @override
  State<RoundResultPhase> createState() => _RoundResultPhaseState();
}

class _RoundResultPhaseState extends State<RoundResultPhase> {
  bool _cinematicDone = false;
  final _arenaKey = GlobalKey();
  final _countdownKey = GlobalKey<_NextRoundCountdownState>();

  List<SpotlightStep> get _spotlightSteps => [
    SpotlightStep(
      targetKey: _arenaKey,
      title: 'Round Result',
      body: 'Goal, Saved, Blocked, Missed, Foul, or Red Card.',
      icon: Icons.sports_soccer,
      accent: Cyber.cyan,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final result = widget.state.roundResults.last;
    final roundOne = result.round == 1;
    final walkthroughMatch =
        roundOne &&
        !context.watch<GameBloc>().state.tutorialSeen.contains('round-result');
    return MatchPhaseScaffold(
      title: 'Round ${result.round} // Result',
      subtitle: '// Resolution Log',
      state: widget.state,
      onQuit: widget.onQuit,
      spotlightKey: walkthroughMatch ? 'round-result' : null,
      spotlightSteps: walkthroughMatch ? _spotlightSteps : const [],
      spotlightEnabled: walkthroughMatch && _cinematicDone,
      spotlightDelay: const Duration(milliseconds: 350),
      spotlightOnComplete: () => _countdownKey.currentState?.beginCountdown(),
      spotlightCardAnchor: SpotlightCardAnchor.bottom,
      spotlightCardBottomInset: 24,
      bottomAction: widget.state.currentRound >= 4
          ? CyberCtaButton(
              label: 'Full-Time Result',
              primary: true,
              onPressed: () => context.read<GameBloc>().add(RoundAdvanced()),
            )
          : null,
      children: [
        SpotlightTarget(
          spotlightKey: _arenaKey,
          child: RoundClashArena(
            result: result,
            playerScore: widget.state.playerScore,
            opponentScore: widget.state.opponentScore,
            onComplete: () {
              if (mounted) setState(() => _cinematicDone = true);
            },
          ),
        ),
        if (widget.state.currentRound < 4)
          AnimatedOpacity(
            opacity: _cinematicDone ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: _cinematicDone
                ? _NextRoundCountdown(
                    key: _countdownKey,
                    deferCountdown: walkthroughMatch,
                    onComplete: () =>
                        context.read<GameBloc>().add(RoundAdvanced()),
                  )
                : const SizedBox(height: 72),
          ),
      ],
    );
  }
}

class _NextRoundCountdown extends StatefulWidget {
  const _NextRoundCountdown({
    required this.onComplete,
    this.deferCountdown = false,
    super.key,
  });

  final VoidCallback onComplete;
  final bool deferCountdown;

  @override
  State<_NextRoundCountdown> createState() => _NextRoundCountdownState();
}

class _NextRoundCountdownState extends State<_NextRoundCountdown> {
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

// ─── Match Intro ─────────────────────────────────────────────────────────────

class MatchIntroPhase extends StatefulWidget {
  const MatchIntroPhase({
    required this.deckName,
    required this.onComplete,
    super.key,
  });

  final String deckName;
  final VoidCallback onComplete;

  @override
  State<MatchIntroPhase> createState() => _MatchIntroPhaseState();
}

class _MatchIntroPhaseState extends State<MatchIntroPhase>
    with TickerProviderStateMixin {
  // 0 = cinematic reveal, 1 = countdown, 2 = kick off
  int _stage = 0;
  int _countdown = 3;

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _kickoff = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 680),
  );

  @override
  void initState() {
    super.initState();
    _reveal.addStatusListener(_onRevealDone);
    _reveal.forward();
  }

  void _onRevealDone(AnimationStatus s) {
    if (s != AnimationStatus.completed) return;
    setState(() {
      _stage = 1;
      _countdown = 3;
    });
    _runCountdown();
  }

  Future<void> _runCountdown() async {
    for (var i = 3; i > 0; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      _pulse
        ..reset()
        ..forward();
      playSound(SoundEffect.countdownTick);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    setState(() => _stage = 2);
    _kickoff.forward();
    playSound(SoundEffect.goal);
    await Future<void>.delayed(const Duration(milliseconds: 780));
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _reveal
      ..removeStatusListener(_onRevealDone)
      ..dispose();
    _pulse.dispose();
    _kickoff.dispose();
    super.dispose();
  }

  // Interpolate a sub-interval of _reveal.value with an optional curve.
  double _rv(double a, double b, {Curve curve = Curves.easeOut}) =>
      curve.transform(((_reveal.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: AnimatedBuilder(
        animation: Listenable.merge([_reveal, _pulse, _kickoff]),
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            const StadiumBackground(),
            if (_stage == 0) _buildReveal(context),
            if (_stage == 1) _buildCountdown(),
            if (_stage == 2) _buildKickoff(),
          ],
        ),
      ),
    );
  }

  // ── Stage 0: cinematic reveal ──────────────────────────────────────────────
  Widget _buildReveal(BuildContext context) {
    final scanLine = _rv(0.08, 0.64);
    final titleIn = _rv(0.22, 0.52, curve: Curves.easeOutCubic);
    final subtitleIn = _rv(0.40, 0.70);
    final sidesIn = _rv(0.55, 1.00, curve: Curves.easeOutCubic);
    final screenH = MediaQuery.sizeOf(context).height;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Horizontal scan sweep
        Positioned(
          top: screenH * scanLine,
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: Cyber.cyan,
              boxShadow: [
                BoxShadow(
                  color: Cyber.cyan.withValues(alpha: 0.7),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
        // Centre: title + subtitle + VS badges
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Game title
              Transform.scale(
                scale: 0.72 + 0.28 * titleIn,
                child: Opacity(
                  opacity: titleIn.clamp(0.0, 1.0),
                  child: Text(
                    'CYBER REACT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Cyber.cyan,
                      fontFamily: 'Orbitron',
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(
                          color: Cyber.cyan.withValues(alpha: titleIn * 0.85),
                          blurRadius: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Opacity(
                opacity: subtitleIn.clamp(0.0, 1.0),
                child: Text(
                  '// MATCH PROTOCOL INITIATED',
                  style: TextStyle(
                    color: Cyber.cyan.withValues(alpha: 0.58),
                    fontFamily: 'Orbitron',
                    fontSize: 10,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              // YOU vs CPU badges
              Opacity(
                opacity: sidesIn.clamp(0.0, 1.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: Offset(-38 * (1 - sidesIn), 0),
                      child: _VsBadge(
                        label: 'YOU',
                        sub: widget.deckName,
                        color: Cyber.lime,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        'VS',
                        style: Cyber.display(24, color: Cyber.gold).copyWith(
                          shadows: [
                            const Shadow(color: Cyber.gold, blurRadius: 20),
                          ],
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(38 * (1 - sidesIn), 0),
                      child: const _VsBadge(
                        label: 'CPU',
                        sub: 'Opponent',
                        color: Cyber.amber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Stage 1: 3-2-1 countdown ───────────────────────────────────────────────
  Widget _buildCountdown() {
    final p = _pulse.value;

    // Scale: slams from 2.0 → 1.0 in first 25%, holds, then expands + fades.
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

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MATCH STARTING IN',
                style: TextStyle(
                  color: Cyber.cyan.withValues(alpha: 0.55),
                  fontFamily: 'Orbitron',
                  fontSize: 11,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 18),
              Transform.scale(
                scale: scale.clamp(0.4, 2.5),
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Text(
                    '$_countdown',
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
            ],
          ),
        ),
      ],
    );
  }

  // ── Stage 2: KICK OFF stamp ────────────────────────────────────────────────
  Widget _buildKickoff() {
    final k = Curves.easeOutBack.transform(_kickoff.value);
    final flash = (1 - (_kickoff.value / 0.38).clamp(0.0, 1.0)) * 0.55;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Flash overlay
        Container(color: Cyber.lime.withValues(alpha: flash.clamp(0.0, 1.0))),
        Center(
          child: Transform.translate(
            offset: Offset(0, -90 * (1 - k.clamp(0.0, 1.0))),
            child: Transform.scale(
              scale: (0.35 + 0.65 * k).clamp(0.0, 1.5),
              child: Opacity(
                opacity: k.clamp(0.0, 1.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Cyber.lime.withValues(alpha: 0.13),
                    border: Border.all(color: Cyber.lime, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Cyber.lime.withValues(alpha: 0.6),
                        blurRadius: 44,
                      ),
                    ],
                  ),
                  child: Text(
                    'KICK OFF!',
                    style:
                        Cyber.display(
                          42,
                          color: Cyber.lime,
                          letterSpacing: 4,
                        ).copyWith(
                          shadows: [
                            const Shadow(color: Cyber.lime, blurRadius: 22),
                          ],
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VsBadge extends StatelessWidget {
  const _VsBadge({required this.label, required this.sub, required this.color});

  final String label;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 16),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'Orbitron',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color.withValues(alpha: 0.65),
              fontFamily: 'Orbitron',
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
