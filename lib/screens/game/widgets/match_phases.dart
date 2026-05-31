import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../blocs/game/game_event.dart';
import '../../../blocs/game/game_state.dart';
import '../../../config/enums.dart';
import '../../../config/theme.dart';
import '../../../config/tutorial_steps.dart';
import '../../../models/cards.dart';
import '../../../models/match.dart';
import '../../../utils/label_helpers.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/match_widgets.dart';

// ── Toss-phase local colour constants ────────────────────────────────────────
const Color _kTossCyan = Color(0xFF5CDFFF);
const Color _kTossRed = Color(0xFFFF4D4D);
const Color _kTossBg = Color(0xFF0D111A);
const Color _kTossMuted = Color(0xFF8FA3B8);

// ─────────────────────────────────────────────────────────────────────────────
// TossPhase  –  full HUD redesign
// ─────────────────────────────────────────────────────────────────────────────
class TossPhase extends StatefulWidget {
  const TossPhase({required this.state, required this.onQuit, super.key});
  final GameState state;
  final VoidCallback onQuit;

  @override
  State<TossPhase> createState() => _TossPhaseState();
}

class _TossPhaseState extends State<TossPhase> with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final Animation<double> _headerAnim;
  late final Animation<double> _scoreAnim;
  late final Animation<double> _coinAnim;
  late final Animation<double> _buttonsAnim;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _headerAnim = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.00, 0.40, curve: Curves.easeOut),
    );
    _scoreAnim = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.20, 0.55, curve: Curves.easeOut),
    );
    _coinAnim = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.35, 0.80, curve: Curves.easeOutBack),
    );
    _buttonsAnim = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.62, 1.00, curve: Curves.easeOut),
    );
    _entry.forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final round = max(1, widget.state.currentRound);
    return Scaffold(
      backgroundColor: _kTossBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(1.0),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: AnimatedBuilder(
              animation: _entry,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Opacity(
                    opacity: _headerAnim.value.clamp(0.0, 1.0),
                    child: _TossHudHeader(round: round, onQuit: widget.onQuit),
                  ),
                  Opacity(
                    opacity: _scoreAnim.value.clamp(0.0, 1.0),
                    child: _TossScoreBar(state: widget.state),
                  ),
                  Expanded(
                    child: Center(
                      child: Transform.scale(
                        scale: _coinAnim.value.clamp(0.0, 1.05),
                        child: const _HolographicCoin(),
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: _buttonsAnim.value.clamp(0.0, 1.0),
                    child: const _HudSectionLabel(label: 'PICK YOUR CALL'),
                  ),
                  const SizedBox(height: 10),
                  Opacity(
                    opacity: _buttonsAnim.value.clamp(0.0, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _CallButton(
                              label: 'HEADS',
                              selected: widget.state.tossChoice == 'heads',
                              onTap: () => context.read<GameBloc>().add(
                                TossChoiceChanged('heads'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CallButton(
                              label: 'TAILS',
                              selected: widget.state.tossChoice == 'tails',
                              onTap: () => context.read<GameBloc>().add(
                                TossChoiceChanged('tails'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Opacity(
                    opacity: _buttonsAnim.value.clamp(0.0, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: _TossCta(
                        label: 'FLIP COIN',
                        enabled: widget.state.tossChoice != null,
                        onPressed: () =>
                            context.read<GameBloc>().add(TossResolved()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TossResultPhase  –  HUD redesign
// ─────────────────────────────────────────────────────────────────────────────
class TossResultPhase extends StatelessWidget {
  const TossResultPhase({required this.state, required this.onQuit, super.key});
  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final round = max(1, state.currentRound);
    final won = state.playerWonToss == true;
    return Scaffold(
      backgroundColor: _kTossBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(1.0),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TossHudHeader(round: round, onQuit: onQuit),
                _TossScoreBar(state: state),
                Expanded(
                  child: Center(
                    child: _CoinFlipReveal(result: state.tossResult ?? ''),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _kTossCyan.withValues(alpha: 0.40),
                        width: 1,
                      ),
                      color: _kTossCyan.withValues(alpha: 0.05),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'IT LANDED '
                          '${(state.tossResult ?? '').toUpperCase()}',
                          textAlign: TextAlign.center,
                          style: Cyber.display(
                            22,
                            color: _kTossCyan,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          won
                              ? 'YOU WON THE TOSS — PICK YOUR ROLE'
                              : 'CPU WON THE TOSS — SELECTING ROLE',
                          textAlign: TextAlign.center,
                          style: Cyber.body(12, color: _kTossMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: won
                      ? Row(
                          children: [
                            Expanded(
                              child: _TossCta(
                                label: 'ATTACK',
                                enabled: true,
                                onPressed: () => context.read<GameBloc>().add(
                                  RoleChosen(true),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TossCta(
                                label: 'DEFEND',
                                enabled: true,
                                fillColor: Cyber.panel,
                                textColor: _kTossCyan,
                                onPressed: () => context.read<GameBloc>().add(
                                  RoleChosen(false),
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: _kTossCyan,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
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
// _CoinFlipReveal  –  3-D flip, glow burst, result flash
// ─────────────────────────────────────────────────────────────────────────────
class _CoinFlipReveal extends StatefulWidget {
  const _CoinFlipReveal({required this.result});
  final String result;

  @override
  State<_CoinFlipReveal> createState() => _CoinFlipRevealState();
}

class _CoinFlipRevealState extends State<_CoinFlipReveal>
    with TickerProviderStateMixin {
  late final AnimationController _flip;
  late final AnimationController _glow;
  late final Animation<double> _angle;
  late final Animation<double> _settle;
  late final Animation<double> _glowPulse;
  bool _showFlash = false;

  @override
  void initState() {
    super.initState();
    playSound(SoundEffect.coinFlip);

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

    _flip.forward().then((_) {
      if (!mounted) return;
      setState(() => _showFlash = true);
      _glow.forward();
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) setState(() => _showFlash = false);
      });
    });
  }

  @override
  void dispose() {
    _flip.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_flip, _glow]),
      builder: (_, _) {
        final glowBlur = 24.0 + _glowPulse.value * 40.0;
        final glowAlpha = 0.35 + _glowPulse.value * 0.45;
        return SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_showFlash)
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
              Transform.scale(
                scale: _settle.value.clamp(0.0, 1.10),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(_angle.value),
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xff1a3545), _kTossBg],
                      ),
                      border: Border.all(color: _kTossCyan, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: _kTossCyan.withValues(alpha: glowAlpha),
                          blurRadius: glowBlur,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.result == 'heads' ? 'H' : 'T',
                        style: Cyber.display(52, color: _kTossCyan),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ══════════════════════════════════════════════════════════════════════════════

class _TossHudHeader extends StatelessWidget {
  const _TossHudHeader({required this.round, required this.onQuit});
  final int round;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onQuit,
                icon: const Icon(Icons.close, color: _kTossCyan, size: 28),
              ),
              const SizedBox(width: 2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ROUND $round',
                    style: Cyber.display(
                      28,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'COIN TOSS PROTOCOL',
                    style: Cyber.label(
                      11,
                      color: _kTossCyan.withValues(alpha: 0.75),
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          CustomPaint(
            painter: _HudBracketLinePainter(),
            child: const SizedBox(height: 10),
          ),
        ],
      ),
    );
  }
}

class _TossScoreBar extends StatelessWidget {
  const _TossScoreBar({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final round = max(1, state.currentRound);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Player
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '[P1] YOU',
                      style: Cyber.label(
                        11,
                        color: _kTossCyan,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      '${state.playerScore}',
                      style: Cyber.display(
                        36,
                        color: _kTossCyan,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              // Centre
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'RD $round / 4',
                    style: Cyber.label(
                      10,
                      color: _kTossMuted,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'VS',
                    style: Cyber.display(
                      22,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: _kTossCyan, width: 1),
                    ),
                    child: Text(
                      'ATTACKING',
                      style: Cyber.label(
                        9,
                        color: _kTossCyan,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              // CPU
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'CPU [E1]',
                      style: Cyber.label(
                        11,
                        color: _kTossRed,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      '${state.opponentScore}',
                      style: Cyber.display(
                        36,
                        color: _kTossRed,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          CustomPaint(
            painter: _ScoreBarDividerPainter(),
            child: const SizedBox(height: 8),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Holographic coin  –  idle float + ring rotation
// ─────────────────────────────────────────────────────────────────────────────
class _HolographicCoin extends StatefulWidget {
  const _HolographicCoin();

  @override
  State<_HolographicCoin> createState() => _HolographicCoinState();
}

class _HolographicCoinState extends State<_HolographicCoin>
    with TickerProviderStateMixin {
  late final AnimationController _float;
  late final AnimationController _ring;
  late final Animation<double> _floatAnim;
  late final Animation<double> _ringAnim;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(
      begin: -4,
      end: 4,
    ).animate(CurvedAnimation(parent: _float, curve: Curves.easeInOut));
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 20000),
    )..repeat();
    _ringAnim = Tween<double>(begin: 0, end: 2 * pi).animate(_ring);
  }

  @override
  void dispose() {
    _float.dispose();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_float, _ring]),
      builder: (_, _) => SizedBox(
        width: 240,
        height: 240,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft radial background glow
            Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _kTossCyan.withValues(alpha: 0.10),
                    _kTossCyan.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
            // Outer radar ring — slow clockwise
            Transform.rotate(
              angle: _ringAnim.value,
              child: CustomPaint(
                size: const Size(220, 220),
                painter: const _RadarRingPainter(outer: true),
              ),
            ),
            // Mid ring — slow counter-rotation
            Transform.rotate(
              angle: -_ringAnim.value * 0.5,
              child: CustomPaint(
                size: const Size(168, 168),
                painter: const _RadarRingPainter(outer: false),
              ),
            ),
            // Float group: inner coin + projection beam + base
            Transform.translate(
              offset: Offset(0, _floatAnim.value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 108,
                    height: 108,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _HudSectionLabel extends StatelessWidget {
  const _HudSectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: _kTossCyan.withValues(alpha: 0.28),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '< $label >',
            style: Cyber.label(
              11,
              color: _kTossCyan.withValues(alpha: 0.85),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: _kTossCyan.withValues(alpha: 0.28),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Heads / Tails choice card
// ─────────────────────────────────────────────────────────────────────────────
class _CallButton extends StatefulWidget {
  const _CallButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_CallButton> createState() => _CallButtonState();
}

class _CallButtonState extends State<_CallButton>
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
    final sel = widget.selected;
    return AnimatedBuilder(
      animation: _press,
      builder: (_, _) => Transform.scale(
        scale: _scale.value,
        child: GestureDetector(
          onTap: _onTap,
          child: Container(
            height: 92,
            decoration: BoxDecoration(
              color: sel ? _kTossCyan.withValues(alpha: 0.10) : Cyber.panel,
              border: Border.all(
                color: sel ? _kTossCyan : _kTossCyan.withValues(alpha: 0.28),
                width: sel ? 1.5 : 1.0,
              ),
              boxShadow: sel
                  ? [
                      BoxShadow(
                        color: _kTossCyan.withValues(alpha: 0.22),
                        blurRadius: 16,
                      ),
                    ]
                  : const [],
            ),
            child: Stack(
              children: [
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 18,
                    child: CustomPaint(painter: _HatchPainter()),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(38, 38),
                        painter: _CoinIconPainter(
                          isHeads: widget.label == 'HEADS',
                          selected: sel,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.label,
                        style: Cyber.label(
                          13,
                          color: sel ? _kTossCyan : _kTossMuted,
                          letterSpacing: 2,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Primary / secondary CTA button with angular clip
// ─────────────────────────────────────────────────────────────────────────────
class _TossCta extends StatefulWidget {
  const _TossCta({
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.fillColor = _kTossCyan,
    this.textColor = _kTossBg,
  });
  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  final Color fillColor;
  final Color textColor;

  @override
  State<_TossCta> createState() => _TossCtaState();
}

class _TossCtaState extends State<_TossCta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _press, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _press,
      builder: (_, _) => Opacity(
        opacity: widget.enabled ? 1.0 : 0.38,
        child: Transform.scale(
          scale: _scale.value,
          child: GestureDetector(
            onTapDown: widget.enabled ? (_) => _press.forward() : null,
            onTapUp: widget.enabled
                ? (_) {
                    _press.reverse();
                    widget.onPressed();
                  }
                : null,
            onTapCancel: () => _press.reverse(),
            child: ClipPath(
              clipper: const _AngularClipper(),
              child: Container(
                width: double.infinity,
                height: 52,
                color: widget.fillColor,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 36,
                      child: CustomPaint(painter: _ButtonDecorationPainter()),
                    ),
                    Text(
                      widget.label,
                      style: Cyber.display(
                        15,
                        color: widget.textColor,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
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

class _HudBracketLinePainter extends CustomPainter {
  const _HudBracketLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kTossCyan.withValues(alpha: 0.50)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height / 2)
        ..lineTo(size.width - 18, size.height / 2)
        ..lineTo(size.width, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(_HudBracketLinePainter _) => false;
}

class _ScoreBarDividerPainter extends CustomPainter {
  const _ScoreBarDividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kTossCyan.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final mid = size.height / 2;
    canvas.drawPath(
      Path()
        ..moveTo(8, 0)
        ..lineTo(0, mid)
        ..lineTo(8, size.height)
        ..lineTo(size.width - 8, size.height)
        ..lineTo(size.width, mid)
        ..lineTo(size.width - 8, 0)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ScoreBarDividerPainter _) => false;
}

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

class _CoinIconPainter extends CustomPainter {
  const _CoinIconPainter({required this.isHeads, required this.selected});
  final bool isHeads;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final alpha = selected ? 0.9 : 0.45;
    final stroke = Paint()
      ..color = _kTossCyan.withValues(alpha: alpha)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, stroke);

    if (isHeads) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 1),
        pi,
        pi,
        true,
        Paint()
          ..color = _kTossCyan.withValues(alpha: selected ? 0.28 : 0.12)
          ..style = PaintingStyle.fill,
      );
      canvas.drawLine(
        Offset(center.dx - radius + 2, center.dy),
        Offset(center.dx + radius - 2, center.dy),
        stroke,
      );
    } else {
      const segs = 12;
      for (int i = 0; i < segs; i += 2) {
        final a1 = (i / segs) * 2 * pi;
        final a2 = ((i + 0.7) / segs) * 2 * pi;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - 6),
          a1,
          a2 - a1,
          false,
          Paint()
            ..color = _kTossCyan.withValues(alpha: alpha)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
      }
      canvas.drawCircle(
        center,
        3,
        Paint()
          ..color = _kTossCyan.withValues(alpha: alpha)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_CoinIconPainter old) =>
      old.selected != selected || old.isHeads != isHeads;
}

class _HatchPainter extends CustomPainter {
  const _HatchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kTossCyan.withValues(alpha: 0.11)
      ..strokeWidth = 1.0;
    const spacing = 8.0;
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter _) => false;
}

class _AngularClipper extends CustomClipper<Path> {
  const _AngularClipper();
  static const _n = 10.0;

  @override
  Path getClip(Size size) => Path()
    ..moveTo(_n, 0)
    ..lineTo(size.width - _n, 0)
    ..lineTo(size.width, _n)
    ..lineTo(size.width, size.height - _n)
    ..lineTo(size.width - _n, size.height)
    ..lineTo(_n, size.height)
    ..lineTo(0, size.height - _n)
    ..lineTo(0, _n)
    ..close();

  @override
  bool shouldReclip(_AngularClipper _) => false;
}

class _ButtonDecorationPainter extends CustomPainter {
  const _ButtonDecorationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..strokeWidth = 1.5;
    const spacing = 6.0;
    for (double x = 0; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x - size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ButtonDecorationPainter _) => false;
}

class ScenarioPhase extends StatelessWidget {
  const ScenarioPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final scenario = state.currentScenario;
    if (scenario == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return MatchPhaseScaffold(
      title: 'Round ${max(1, state.currentRound)}',
      subtitle: '// Scenario Briefing',
      state: state,
      onQuit: onQuit,
      tutorialKey: 'scenario',
      tutorialSteps: scenarioTutorialSteps,
      children: [
        ScenarioBriefingSection(
          scenario: scenario,
          attacking: state.playerAttacking,
          initialSeconds: 2,
          onComplete: () => context.read<GameBloc>().add(PlayStarted()),
        ),
      ],
    );
  }
}

Color _roleAccent(bool attacking) =>
    attacking ? Cyber.cyan : const Color(0xFFA855F7);

class ScenarioBriefingSection extends StatefulWidget {
  const ScenarioBriefingSection({
    required this.scenario,
    required this.attacking,
    required this.onComplete,
    this.initialSeconds = 2,
    super.key,
  });

  final ScenarioCard scenario;
  final bool attacking;
  final int initialSeconds;
  final VoidCallback onComplete;

  @override
  State<ScenarioBriefingSection> createState() =>
      _ScenarioBriefingSectionState();
}

class _ScenarioBriefingSectionState extends State<ScenarioBriefingSection>
    with SingleTickerProviderStateMixin {
  late int _seconds = widget.initialSeconds;
  late final AnimationController _scanner = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _tick();
  }

  Future<void> _tick() async {
    for (var i = widget.initialSeconds; i > 0; i--) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _seconds = i - 1);
    }
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _scanner.dispose();
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
              decoration: BoxDecoration(
                color: const Color(0xff080d16),
                border: Border.all(color: accent.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.08),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _ScenarioGridPainter(accent),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScenarioBriefingCard(
                      scenario: widget.scenario,
                      attacking: widget.attacking,
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

class ScenarioBriefingCard extends StatelessWidget {
  const ScenarioBriefingCard({
    required this.scenario,
    required this.attacking,
    super.key,
  });

  final ScenarioCard scenario;
  final bool attacking;

  @override
  Widget build(BuildContext context) {
    final accent = _roleAccent(attacking);
    final status = attacking ? 'ATTACKING THIS ROUND' : 'DEFENDING THIS ROUND';
    return CustomPaint(
      painter: _ScenarioPanelPainter(accent),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RadarTargetIcon(accent: accent),
            const SizedBox(height: 16),
            Text(
              scenario.title.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Cyber.display(26, color: accent, letterSpacing: 1.3)
                  .copyWith(
                    shadows: [
                      Shadow(
                        color: accent.withValues(alpha: 0.65),
                        blurRadius: 18,
                      ),
                    ],
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              scenario.description,
              textAlign: TextAlign.center,
              style: Cyber.body(
                13,
                color: Colors.white.withValues(alpha: 0.82),
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 34),
              color: accent.withValues(alpha: 0.14),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: BonusChip(
                    label: 'ATTACK',
                    value: '+${scenario.attackBonus}',
                    accent: Cyber.cyan,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: BonusChip(
                    label: 'DEFENSE',
                    value: '+${scenario.defenseBonus}',
                    accent: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  attacking ? Icons.sports_soccer : Icons.shield,
                  color: accent,
                  size: 17,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.label(11, color: accent, letterSpacing: 1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

class CountdownBlock extends StatelessWidget {
  const CountdownBlock({
    required this.seconds,
    required this.scanner,
    required this.accent,
    super.key,
  });

  final int seconds;
  final Animation<double> scanner;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CountdownRing(seconds: seconds, scanner: scanner, accent: accent),
        const SizedBox(height: 12),
        Text(
          'Card select starts in...',
          textAlign: TextAlign.center,
          style: Cyber.body(
            12,
            color: accent.withValues(alpha: 0.7),
            weight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class CountdownRing extends StatelessWidget {
  const CountdownRing({
    required this.seconds,
    required this.scanner,
    required this.accent,
    super.key,
  });

  final int seconds;
  final Animation<double> scanner;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scanner,
      builder: (context, _) {
        final pulse = 1 + sin(scanner.value * pi * 2) * 0.025;
        return Transform.scale(
          scale: pulse,
          child: SizedBox(
            width: 154,
            height: 154,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CountdownRingPainter(scanner.value, accent),
                  ),
                ),
                Text(
                  seconds > 0 ? '$seconds' : 'GO',
                  style:
                      Cyber.display(
                        seconds > 0 ? 72 : 44,
                        color: accent,
                        letterSpacing: 0.8,
                      ).copyWith(
                        shadows: [
                          Shadow(
                            color: accent.withValues(alpha: 0.85),
                            blurRadius: 24,
                          ),
                          Shadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 42,
                          ),
                        ],
                      ),
                ),
              ],
            ),
          ),
        );
      },
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

class _CountdownRingPainter extends CustomPainter {
  const _CountdownRingPainter(this.scan, this.accent);

  final double scan;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final faint = Paint()
      ..color = accent.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final line = Paint()
      ..color = accent.withValues(alpha: 0.46)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final sweep = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: pi * 2,
        colors: [
          Colors.transparent,
          accent.withValues(alpha: 0.08),
          accent.withValues(alpha: 0.68),
          Colors.transparent,
        ],
        stops: const [0, 0.68, 0.82, 1],
        transform: GradientRotation(scan * pi * 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - 8, faint);
    canvas.drawCircle(center, radius - 28, faint);
    canvas.drawCircle(center, radius - 46, line);
    canvas.drawCircle(center, radius - 16, sweep);

    for (var i = 0; i < 12; i++) {
      final angle = (pi * 2 / 12) * i;
      final inner = radius - (i % 3 == 0 ? 25 : 18);
      final outer = radius - 8;
      final p1 = center + Offset(cos(angle), sin(angle)) * inner;
      final p2 = center + Offset(cos(angle), sin(angle)) * outer;
      canvas.drawLine(p1, p2, faint);
    }

    final crosshair = Paint()
      ..color = accent.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      crosshair,
    );
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      crosshair,
    );
  }

  @override
  bool shouldRepaint(_CountdownRingPainter oldDelegate) =>
      oldDelegate.scan != scan || oldDelegate.accent != accent;
}

class _ScenarioGridPainter extends CustomPainter {
  const _ScenarioGridPainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.035)
      ..strokeWidth = 0.8;
    const gap = 22.0;
    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ScenarioGridPainter oldDelegate) =>
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

class PlayPhase extends StatelessWidget {
  const PlayPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final playerPool = state.playerAttacking
        ? state.deckAttackers
        : state.deckDefenders;
    final sectionLabel = state.playerAttacking
        ? 'SELECT AN ATTACKER FROM YOUR DECK'
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
    final estimate =
        state.selectedPlayerCard == null || state.selectedActionCard == null
        ? null
        : state.selectedPlayerCard!.rating +
              state.selectedActionCard!.power +
              scenarioBonus;
    return MatchPhaseScaffold(
      title: 'Round ${max(1, state.currentRound)}',
      subtitle: state.currentScenario?.title ?? '// Play Protocol',
      state: state,
      onQuit: onQuit,
      tutorialKey: 'play',
      tutorialSteps: playTutorialSteps,
      bottomAction: hasCompleteSelection
          ? BottomLockButton(
              enabled: true,
              label: lockLabel,
              helper: 'Power preview ${estimate ?? '--'} ready',
              accent: roleAccent,
              onPressed: () => context.read<GameBloc>().add(MovePlayed()),
            )
          : null,
      children: [
        _SlideUpFadeIn(
          child: ScenarioPanel(
            scenario: state.currentScenario,
            attacking: state.playerAttacking,
            bonus: scenarioBonus,
            accent: roleAccent,
          ),
        ),
        _SlideUpFadeIn(
          delay: const Duration(milliseconds: 90),
          child: PowerPreviewBar(
            player: state.selectedPlayerCard,
            action: state.selectedActionCard,
            bonus: scenarioBonus,
            total: estimate,
            attacking: state.playerAttacking,
            accent: roleAccent,
          ),
        ),
        DefenderDeckGrid(
          title: sectionLabel,
          cards: playerPool,
          selectedId: state.selectedPlayerCard?.id,
          redCardedIds: state.redCardedCards,
          attacking: state.playerAttacking,
          accent: roleAccent,
          onSelect: (card) =>
              context.read<GameBloc>().add(PlayerSelected(card)),
        ),
        ActionCardRail(
          cards: availableActions,
          selectedId: state.selectedActionCard?.id,
          usedIds: state.usedActionCards,
          accent: roleAccent,
          onSelect: (card) =>
              context.read<GameBloc>().add(ActionSelected(card)),
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
    super.key,
  });

  final ScenarioCard? scenario;
  final bool attacking;
  final int bonus;
  final Color accent;

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
              const _InfoChip(
                label: 'RISK',
                value: 'LOW',
                accent: Cyber.magenta,
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
    required this.attacking,
    required this.accent,
    super.key,
  });

  final PlayerCard? player;
  final ActionCard? action;
  final int bonus;
  final int? total;
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
                _PowerText(total == null ? '--' : '$total', color: Cyber.gold),
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
        GridView.builder(
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
          child: _PlaySectionHeading('ACTIONS IN YOUR DECK', color: accent),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 158,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final card = cards[index];
              final used = usedIds.contains(card.id);
              return _DealtCard(
                key: ValueKey('action-${card.id}'),
                index: index,
                initialDelay: railBaseDelay + const Duration(milliseconds: 80),
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
              );
            },
          ),
        ),
      ],
    );
  }
}

class BottomLockButton extends StatelessWidget {
  const BottomLockButton({
    required this.enabled,
    required this.label,
    required this.helper,
    required this.accent,
    required this.onPressed,
    super.key,
  });

  final bool enabled;
  final String label;
  final String helper;
  final Color accent;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AngularBorderContainer(
        accent: enabled ? accent : Cyber.muted,
        fillOpacity: 1,
        solidFill: true,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: Cyber.display(
                25,
                color: enabled ? accent : Cyber.muted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              helper,
              textAlign: TextAlign.center,
              style: Cyber.body(
                12,
                color: enabled ? Colors.white70 : Cyber.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
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

class RoundResultPhase extends StatelessWidget {
  const RoundResultPhase({
    required this.state,
    required this.onQuit,
    super.key,
  });

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final result = state.roundResults.last;
    return MatchPhaseScaffold(
      title: 'Round ${result.round} // Result',
      subtitle: '// Resolution Log',
      state: state,
      onQuit: onQuit,
      tutorialKey: 'round-result',
      tutorialSteps: resultTutorialSteps,
      bottomAction: state.currentRound >= 4
          ? CyberCtaButton(
              label: 'Full-Time Result',
              primary: true,
              onPressed: () => context.read<GameBloc>().add(RoundAdvanced()),
            )
          : null,
      children: [
        _CinematicRoundResult(result: result),
        if (state.currentRound < 4)
          _NextRoundCountdown(
            startDelay: const Duration(milliseconds: 2300),
            onComplete: () => context.read<GameBloc>().add(RoundAdvanced()),
          ),
      ],
    );
  }
}

/// Accent color for an outcome (drives stamp + flashes).
Color outcomeColor(RoundOutcome outcome) => switch (outcome) {
  RoundOutcome.goal => Cyber.success,
  RoundOutcome.saved => Cyber.cyan,
  RoundOutcome.blocked => Cyber.violet,
  RoundOutcome.missed => Cyber.muted,
  RoundOutcome.foul => Cyber.amber,
  RoundOutcome.redCard => Cyber.danger,
};

/// Theatrical round reveal: letterbox bars, cards slam in from the sides, a
/// pulsing VS, power bars fill, then the outcome stamp drops with a goal
/// particle burst.
class _CinematicRoundResult extends StatefulWidget {
  const _CinematicRoundResult({required this.result});
  final RoundResult result;

  @override
  State<_CinematicRoundResult> createState() => _CinematicRoundResultState();
}

class _CinematicRoundResultState extends State<_CinematicRoundResult>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool _slammed = false;
  bool _stamped = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onTick);
    _c.forward();
  }

  void _onTick() {
    if (!_slammed && _c.value >= 0.16) {
      _slammed = true;
      playSound(SoundEffect.cardSlam);
    }
    if (!_stamped && _c.value >= 0.80) {
      _stamped = true;
      playSound(
        widget.result.outcome == RoundOutcome.redCard
            ? SoundEffect.redCard
            : (widget.result.outcome == RoundOutcome.goal
                  ? SoundEffect.goal
                  : SoundEffect.cardSlam),
      );
    }
  }

  @override
  void dispose() {
    _c
      ..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  double _interval(double a, double b, {Curve curve = Curves.easeOut}) {
    final t = ((_c.value - a) / (b - a)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final playerAttacking = r.playerAttacking;
    final playerCard = playerAttacking ? r.attackerCard : r.defenderCard;
    final oppCard = playerAttacking ? r.defenderCard : r.attackerCard;
    final playerAction = playerAttacking ? r.attackAction : r.defenseAction;
    final oppAction = playerAttacking ? r.defenseAction : r.attackAction;
    final playerPower = playerAttacking ? r.attackPower : r.defensePower;
    final oppPower = playerAttacking ? r.defensePower : r.attackPower;
    final accent = outcomeColor(r.outcome);

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final bars = _interval(0.0, 0.16);
        final pIn = _interval(0.16, 0.36, curve: Curves.easeOutBack);
        final oIn = _interval(0.30, 0.50, curve: Curves.easeOutBack);
        final vs = _interval(0.50, 0.64);
        final powerT = _interval(0.62, 0.82, curve: Curves.easeOutCubic);
        final stamp = _interval(0.80, 1.0, curve: Curves.easeOutBack);
        // easeOutBack overshoots <0 / >1, but Opacity requires [0,1].
        final pInO = pIn.clamp(0.0, 1.0);
        final oInO = oIn.clamp(0.0, 1.0);
        final vsO = vs.clamp(0.0, 1.0);
        final stampO = stamp.clamp(0.0, 1.0);
        final redShake = r.outcome == RoundOutcome.redCard
            ? sin(stamp * pi * 5) * 5 * (1 - stamp)
            : 0.0;

        return Transform.translate(
          offset: Offset(redShake, 0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35 * bars),
              border: Border.all(color: accent.withValues(alpha: 0.4 * stamp)),
            ),
            child: Column(
              children: [
                // Top letterbox bar.
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(height: 14 * bars, color: Colors.black),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Transform.translate(
                            offset: Offset(-160 * (1 - pIn), 0),
                            child: Opacity(
                              opacity: pInO,
                              child: _RevealCardColumn(
                                label: 'YOU',
                                labelColor: Cyber.cyan,
                                card: playerCard,
                                action: playerAction,
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(160 * (1 - oIn), 0),
                            child: Opacity(
                              opacity: oInO,
                              child: _RevealCardColumn(
                                label: 'CPU',
                                labelColor: Cyber.amber,
                                card: oppCard,
                                action: oppAction,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // VS marker.
                      Transform.scale(
                        scale: 0.6 + 0.4 * vs + 0.06 * sin(vs * pi),
                        child: Opacity(
                          opacity: vsO,
                          child: Text(
                            'VS',
                            style: Cyber.display(30, color: Cyber.gold)
                                .copyWith(
                                  shadows: [
                                    const Shadow(
                                      color: Cyber.gold,
                                      blurRadius: 18,
                                    ),
                                  ],
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Power bars.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      _PowerBar(
                        label: 'YOUR POWER',
                        value: playerPower,
                        progress: powerT,
                        color: Cyber.cyan,
                      ),
                      const SizedBox(height: 6),
                      _PowerBar(
                        label: 'OPPONENT POWER',
                        value: oppPower,
                        progress: powerT,
                        color: Cyber.amber,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Outcome stamp + goal particle burst.
                SizedBox(
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      if (r.outcome == RoundOutcome.goal && stamp > 0)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _BurstPainter(stamp, accent),
                          ),
                        ),
                      Transform.translate(
                        offset: Offset(0, -50 * (1 - stamp)),
                        child: Transform.rotate(
                          angle: -3 * pi / 180,
                          child: Opacity(
                            opacity: stampO,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.16),
                                border: Border.all(color: accent, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.5),
                                    blurRadius: 24,
                                  ),
                                ],
                              ),
                              child: Text(
                                outcomeLabel(r.outcome).toUpperCase(),
                                style: Cyber.display(
                                  36,
                                  color: accent,
                                  letterSpacing: 3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Bottom letterbox bar.
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(height: 14 * bars, color: Colors.black),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RevealCardColumn extends StatelessWidget {
  const _RevealCardColumn({
    required this.label,
    required this.labelColor,
    required this.card,
    required this.action,
  });

  final String label;
  final Color labelColor;
  final PlayerCard card;
  final ActionCard action;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Cyber.display(13, color: labelColor, letterSpacing: 2),
        ),
        const SizedBox(height: 6),
        CyberPlayerCardTile(card: card, selected: false),
        const SizedBox(height: 6),
        CyberChip(label: action.title, color: actionColor(action.category)),
      ],
    );
  }
}

class _PowerBar extends StatelessWidget {
  const _PowerBar({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String label;
  final double value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Normalize against a plausible max power (~150) for the fill width.
    final fill = (value / 150).clamp(0.0, 1.0) * progress;
    return Row(
      children: [
        SizedBox(
          width: 116,
          child: Text(
            label,
            style: const TextStyle(
              color: Cyber.muted,
              fontFamily: Cyber.bodyFont,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: Cyber.bg2,
              border: Border.all(color: Cyber.borderSubtle),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fill,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            (value * progress).toStringAsFixed(0),
            textAlign: TextAlign.right,
            style: Cyber.display(18, color: color, letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = color.withValues(alpha: (1 - t).clamp(0, 1));
    final rng = Random(7);
    for (var i = 0; i < 14; i++) {
      final angle = (i / 14) * 2 * pi + rng.nextDouble();
      final dist = 90 * t * (0.6 + rng.nextDouble() * 0.6);
      final p = center + Offset(cos(angle), sin(angle)) * dist;
      final s = 5 * (1 - t) + 2;
      canvas.drawRect(Rect.fromCenter(center: p, width: s, height: s), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) =>
      old.t != t || old.color != color;
}

class _NextRoundCountdown extends StatefulWidget {
  const _NextRoundCountdown({
    required this.onComplete,
    this.startDelay = Duration.zero,
  });
  final VoidCallback onComplete;
  final Duration startDelay;

  @override
  State<_NextRoundCountdown> createState() => _NextRoundCountdownState();
}

class _NextRoundCountdownState extends State<_NextRoundCountdown> {
  int _seconds = 3;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  Future<void> _tick() async {
    if (widget.startDelay > Duration.zero) {
      await Future<void>.delayed(widget.startDelay);
      if (!mounted) return;
    }
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
          _seconds > 0 ? '$_seconds' : 'Go!',
          style: const TextStyle(
            color: Cyber.cyan,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.w900,
            fontSize: 48,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Next round starting...',
          style: TextStyle(color: Cyber.line, fontSize: 13),
        ),
      ],
    );
  }
}

class MatchEndPhase extends StatefulWidget {
  const MatchEndPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  State<MatchEndPhase> createState() => _MatchEndPhaseState();
}

class _MatchEndPhaseState extends State<MatchEndPhase>
    with TickerProviderStateMixin {
  static const int _penaltyCountdownSeconds = 5;
  late int _seconds;
  late final AnimationController _scanner;
  late final AnimationController _bannerCtrl;
  late final AnimationController _scoreCtrl;
  late final AnimationController _shakeCtrl;
  bool _fired = false;

  bool get _tied => widget.state.playerScore == widget.state.opponentScore;

  @override
  void initState() {
    super.initState();
    _seconds = _penaltyCountdownSeconds;
    _scanner = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _bannerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scoreCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _bannerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _scoreCtrl.forward();
    });

    final won = widget.state.playerScore > widget.state.opponentScore;
    if (!won && !_tied) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) _shakeCtrl.forward();
      });
    }

    if (_tied) _tick();
  }

  Future<void> _tick() async {
    for (var i = _penaltyCountdownSeconds; i > 0; i--) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted || _fired) return;
      setState(() => _seconds = i - 1);
    }
    if (!mounted || _fired) return;
    _fired = true;
    context.read<GameBloc>().add(PenaltyStarted());
  }

  @override
  void dispose() {
    _scanner.dispose();
    _bannerCtrl.dispose();
    _scoreCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tied = _tied;
    final won = widget.state.playerScore > widget.state.opponentScore;
    final title = tied ? 'DEADLOCK' : (won ? 'VICTORY' : 'DEFEAT');
    final accent = tied ? Cyber.amber : (won ? Cyber.success : Cyber.danger);
    return MatchPhaseScaffold(
      title: 'Full Time',
      subtitle: '// Match Archive',
      state: widget.state,
      onQuit: widget.onQuit,
      tutorialKey: 'match-end',
      tutorialSteps: matchEndTutorialSteps,
      bottomAction: tied
          ? null
          : CyberCtaButton(
              label: 'Finish Match',
              primary: true,
              onPressed: () => context.read<GameBloc>().add(MatchFinished()),
            ),
      children: [
        const SizedBox(height: 8),
        // Outcome banner with animation.
        ScaleTransition(
          scale: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(parent: _bannerCtrl, curve: Curves.easeOutBack),
          ),
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, -0.3),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: _bannerCtrl,
                    curve: Curves.easeOutBack,
                  ),
                ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                border: Border.all(color: accent, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Column(
                children: [
                  ScaleTransition(
                    scale: Tween<double>(begin: 0, end: 1).animate(
                      CurvedAnimation(
                        parent: _bannerCtrl,
                        curve: Curves.elasticOut,
                      ),
                    ),
                    child: Icon(
                      tied
                          ? Icons.balance
                          : (won
                                ? Icons.emoji_events
                                : Icons.sentiment_dissatisfied),
                      color: accent,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: Cyber.display(40, color: accent, letterSpacing: 4),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Giant scoreline with bounce animation and shake for defeat.
        AnimatedBuilder(
          animation: Listenable.merge([_scoreCtrl, _shakeCtrl]),
          builder: (_, _) {
            final scoreScale = Tween<double>(begin: 0.5, end: 1)
                .animate(
                  CurvedAnimation(
                    parent: _scoreCtrl,
                    curve: Curves.easeOutBack,
                  ),
                )
                .value;

            final shakeOffset = won || tied
                ? 0.0
                : Tween<double>(begin: -8, end: 8)
                      .animate(
                        CurvedAnimation(
                          parent: _shakeCtrl,
                          curve: Curves.elasticInOut,
                        ),
                      )
                      .value;

            return Transform.translate(
              offset: Offset(shakeOffset, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Transform.scale(
                    scale: scoreScale,
                    child: Text(
                      '${widget.state.playerScore}',
                      style: Cyber.display(72, color: Cyber.cyan),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '-',
                      style: Cyber.display(48, color: Cyber.muted),
                    ),
                  ),
                  Transform.scale(
                    scale: scoreScale,
                    child: Text(
                      '${widget.state.opponentScore}',
                      style: Cyber.display(72, color: Cyber.danger),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (tied) ...[
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'The match is level - settle it from the spot.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Cyber.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: CountdownRing(
              seconds: _seconds,
              scanner: _scanner,
              accent: accent,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Penalty shootout starting...',
              textAlign: TextAlign.center,
              style: Cyber.body(
                12,
                color: accent.withValues(alpha: 0.7),
                weight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
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
      playSound(SoundEffect.cardSlam);
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
    final gridIn = _rv(0.00, 0.30);
    final scanLine = _rv(0.08, 0.64);
    final titleIn = _rv(0.22, 0.52, curve: Curves.easeOutCubic);
    final subtitleIn = _rv(0.40, 0.70);
    final sidesIn = _rv(0.55, 1.00, curve: Curves.easeOutCubic);
    final screenH = MediaQuery.sizeOf(context).height;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Subtle grid
        CustomPaint(painter: _GridPainter(gridIn)),
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
        CustomPaint(painter: _GridPainter(0.55)),
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
        CustomPaint(painter: _GridPainter(0.55)),
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

class _GridPainter extends CustomPainter {
  const _GridPainter(this.opacity);

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final paint = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.07 * opacity)
      ..strokeWidth = 0.5;
    for (var x = 0.0; x <= size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.opacity != opacity;
}
