import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../blocs/game/game_event.dart';
import '../../../config/enums.dart';
import '../../../config/theme.dart';
import '../../../models/cards.dart';
import '../../../utils/label_helpers.dart';
import '../../../widgets/card_unpack_animation.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

String _cardRarity(PlayerCard card) => switch (card.rarity) {
  CardRarity.common => 'common',
  CardRarity.rare => 'rare',
  CardRarity.epic => 'epic',
  CardRarity.legendary => 'legendary',
};

enum _Phase { intro, reveal, summary }

class StarterPackOnboardingScreen extends StatefulWidget {
  const StarterPackOnboardingScreen({required this.cards, super.key});

  final List<PlayerCard> cards;

  @override
  State<StarterPackOnboardingScreen> createState() =>
      _StarterPackOnboardingScreenState();
}

class _StarterPackOnboardingScreenState
    extends State<StarterPackOnboardingScreen>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.intro;
  int _cardIndex = 0;

  // Intro
  late final AnimationController _bgPulse;
  late final AnimationController _titleDrop;
  late final AnimationController _exitFlash;
  late final List<AnimationController> _slotCtrl;

  // Summary
  late final List<AnimationController> _summaryCtrl;
  late final AnimationController _summaryExit;

  @override
  void initState() {
    super.initState();

    _bgPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _titleDrop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();

    _exitFlash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _slotCtrl = List.generate(
      widget.cards.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 320),
      ),
    );

    _summaryCtrl = List.generate(
      widget.cards.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 420),
      ),
    );

    _summaryExit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    // Stagger slot reveals starting at 700ms
    for (int i = 0; i < widget.cards.length; i++) {
      final idx = i;
      Future.delayed(Duration(milliseconds: 720 + idx * 130), () {
        if (mounted) _slotCtrl[idx].forward();
      });
    }

    // Auto-advance intro after 3s
    Future.delayed(const Duration(milliseconds: 3000), _exitIntro);
  }

  void _exitIntro() {
    if (!mounted || _phase != _Phase.intro) return;
    _exitFlash.forward().then((_) {
      if (!mounted) return;
      setState(() => _phase = _Phase.reveal);
    });
  }

  void _onCardComplete() {
    if (!mounted) return;
    if (_cardIndex < widget.cards.length - 1) {
      setState(() => _cardIndex++);
    } else {
      setState(() => _phase = _Phase.summary);
      for (int i = 0; i < _summaryCtrl.length; i++) {
        Future.delayed(Duration(milliseconds: 80 + 120 * i), () {
          if (mounted) _summaryCtrl[i].forward();
        });
      }
    }
  }

  void _enterGame() {
    _summaryExit.forward().then((_) {
      if (mounted) context.read<GameBloc>().add(StarterPackSeen());
    });
  }

  @override
  void dispose() {
    _bgPulse.dispose();
    _titleDrop.dispose();
    _exitFlash.dispose();
    for (final c in _slotCtrl) { c.dispose(); }
    for (final c in _summaryCtrl) { c.dispose(); }
    _summaryExit.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) => switch (_phase) {
    _Phase.intro => _buildIntro(context),
    _Phase.reveal => _buildReveal(context),
    _Phase.summary => _buildSummary(context),
  };

  // ── Intro ──────────────────────────────────────────────────────────────────
  Widget _buildIntro(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_bgPulse, _titleDrop, _exitFlash]),
      builder: (context, _) {
        final td = _titleDrop.value;
        final ef = _exitFlash.value;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Dark base
            const ColoredBox(color: Color(0xFF0D111A)),

            // Subtle grid
            CustomPaint(painter: _GridPainter(opacity: 0.05 + 0.025 * _bgPulse.value)),

            // Radial cyan glow
            CustomPaint(
              painter: _RadialGlowPainter(
                color: Cyber.cyan,
                opacity: 0.04 + 0.05 * _bgPulse.value,
              ),
            ),

            // Main content
            Opacity(
              opacity: (1 - ef).clamp(0.0, 1.0),
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Brand sub-label
                        Opacity(
                          opacity: _iv(td, 0.0, 0.28),
                          child: Transform.translate(
                            offset: Offset(0, 24 * (1 - _iv(td, 0.0, 0.28))),
                            child: Text(
                              'PITCH DUEL',
                              style: TextStyle(
                                color: Cyber.cyan.withValues(alpha: 0.5),
                                fontFamily: 'Orbitron',
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Big STARTER PACK title
                        Opacity(
                          opacity: _iv(td, 0.12, 0.65),
                          child: Transform.translate(
                            offset: Offset(0, 80 * (1 - _iv(td, 0.12, 0.65))),
                            child: ShaderMask(
                              shaderCallback: (b) => const LinearGradient(
                                colors: [Color(0xFF5CDFFF), Color(0xFFD4FF5C)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(b),
                              child: const Text(
                                'STARTER\nPACK',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Orbitron',
                                  fontSize: 52,
                                  fontWeight: FontWeight.w900,
                                  height: 0.95,
                                  letterSpacing: 4,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // UNLOCKED amber label
                        Opacity(
                          opacity: _iv(td, 0.32, 0.72),
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - _iv(td, 0.32, 0.72))),
                            child: Text(
                              'UNLOCKED',
                              style: TextStyle(
                                color: Cyber.amber,
                                fontFamily: 'Orbitron',
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),

                        // 5 mystery card slots
                        Opacity(
                          opacity: _iv(td, 0.5, 0.88),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (int i = 0; i < widget.cards.length; i++) ...[
                                AnimatedBuilder(
                                  animation: _slotCtrl[i],
                                  builder: (_, _) {
                                    final v = _slotCtrl[i].value;
                                    return Transform.scale(
                                      scale: Curves.easeOutBack.transform(v),
                                      child: Opacity(
                                        opacity: v.clamp(0.0, 1.0),
                                        child: const _MysterySlot(),
                                      ),
                                    );
                                  },
                                ),
                                if (i < widget.cards.length - 1)
                                  const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Pulsing status line
                        Opacity(
                          opacity: _iv(td, 0.68, 1.0),
                          child: AnimatedBuilder(
                            animation: _bgPulse,
                            builder: (_, _) => Opacity(
                              opacity: 0.35 + 0.65 * _bgPulse.value,
                              child: Text(
                                'PREPARING YOUR SQUAD...',
                                style: TextStyle(
                                  color: Cyber.muted,
                                  fontSize: 10,
                                  letterSpacing: 2.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // White flash exit
            if (ef > 0)
              ColoredBox(
                color: Colors.white.withValues(alpha: ef.clamp(0.0, 1.0)),
              ),
          ],
        );
      },
    );
  }

  // ── Card reveal ────────────────────────────────────────────────────────────
  Widget _buildReveal(BuildContext context) {
    final card = widget.cards[_cardIndex];
    return Stack(
      key: ValueKey('reveal_$_cardIndex'),
      fit: StackFit.expand,
      children: [
        CardUnpackAnimation(
          key: ValueKey('unpack_$_cardIndex'),
          playerName: card.name,
          position: playerRoleLabel(card),
          rating: card.rating,
          rarity: _cardRarity(card),
          onComplete: _onCardComplete,
          frontFace: CyberPlayerCardTile(
            card: card,
            selected: false,
            size: VisualCardSize.md,
          ),
        ),
        // Progress indicator overlay at top
        Positioned(
          top: MediaQuery.of(context).padding.top + 14,
          left: 0,
          right: 0,
          child: _ProgressDots(
            current: _cardIndex + 1,
            total: widget.cards.length,
          ),
        ),
      ],
    );
  }

  // ── Summary ────────────────────────────────────────────────────────────────
  Widget _buildSummary(BuildContext context) {
    return AnimatedBuilder(
      animation: _summaryExit,
      builder: (context, child) => Opacity(
        opacity: (1 - _summaryExit.value).clamp(0.0, 1.0),
        child: child,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF0D111A)),
          CustomPaint(painter: const _GridPainter(opacity: 0.05)),
          CustomPaint(
            painter: _RadialGlowPainter(color: Cyber.lime, opacity: 0.055),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Trophy icon
                  Icon(
                    Icons.emoji_events_rounded,
                    size: 54,
                    color: Cyber.gold,
                    shadows: [
                      Shadow(
                        color: Cyber.gold.withValues(alpha: 0.6),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // SQUAD ASSEMBLED title
                  Text(
                    'SQUAD ASSEMBLED!',
                    style: TextStyle(
                      color: Cyber.lime,
                      fontFamily: 'Orbitron',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          color: Cyber.lime.withValues(alpha: 0.55),
                          blurRadius: 22,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${widget.cards.length} CARDS ADDED TO YOUR COLLECTION',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Cyber.muted,
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Cards in a wrap
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (int i = 0; i < widget.cards.length; i++)
                        AnimatedBuilder(
                          animation: _summaryCtrl[i],
                          builder: (_, _) {
                            final t = _summaryCtrl[i].value.clamp(0.0, 1.0);
                            return Opacity(
                              opacity: t,
                              child: Transform.scale(
                                scale: Curves.easeOutBack.transform(t),
                                child: CyberPlayerCardTile(
                                  card: widget.cards[i],
                                  selected: false,
                                  size: VisualCardSize.sm,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // CTA
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _enterGame,
                      style: FilledButton.styleFrom(
                        backgroundColor: Cyber.lime,
                        foregroundColor: Cyber.bg,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text(
                        'ENTER THE GAME',
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          fontSize: 14,
                        ),
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

// ── interval helper: maps t∈[0,1] through range [a,b] ────────────────────────
double _iv(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

// ── Small widgets ──────────────────────────────────────────────────────────────

class _MysterySlot extends StatelessWidget {
  const _MysterySlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 62,
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.5),
        border: Border.all(color: Cyber.cyan.withValues(alpha: 0.45), width: 1),
        boxShadow: [
          BoxShadow(
            color: Cyber.cyan.withValues(alpha: 0.15),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '?',
          style: TextStyle(
            color: Cyber.cyan,
            fontFamily: 'Orbitron',
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'CARD $current OF $total',
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            letterSpacing: 2.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < total; i++) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: i < current ? 24 : 14,
                height: 3,
                decoration: BoxDecoration(
                  color: i < current
                      ? const Color(0xFF5CDFFF)
                      : const Color(0xFF94A3B8).withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              if (i < total - 1) const SizedBox(width: 4),
            ],
          ],
        ),
      ],
    );
  }
}

// ── Painters ───────────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Cyber.cyan.withValues(alpha: opacity)
      ..strokeWidth = 0.5;
    const step = 32.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.opacity != opacity;
}

class _RadialGlowPainter extends CustomPainter {
  const _RadialGlowPainter({required this.color, required this.opacity});

  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final r = size.width * 0.88;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: opacity), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_RadialGlowPainter old) => old.opacity != opacity;
}
