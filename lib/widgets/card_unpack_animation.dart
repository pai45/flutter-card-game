import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

// ── Colour constants ─────────────────────────────────────────────────────────
const Color _kBg = Color(0xFF0D111A);
const Color _kSurface = Color(0xFF1E2538);
const Color _kCyan = Color(0xFF5CDFFF);
const Color _kPurple = Color(0xFFA855F7);
const Color _kGold = Color(0xFFFFD700);
const Color _kWhite = Color(0xFFFFFFFF);
const Color _kMuted = Color(0xFF94A3B8);

// ── Rarity helpers ────────────────────────────────────────────────────────────
Color _rarityBase(String r) => switch (r) {
  'rare' => _kCyan,
  'epic' => _kPurple,
  'legendary' => _kGold,
  _ => _kWhite,
};

Color _rarityGlow(String r) => switch (r) {
  'rare' => _kCyan.withValues(alpha: 0.6),
  'epic' => _kPurple.withValues(alpha: 0.7),
  'legendary' => _kGold.withValues(alpha: 0.85),
  _ => _kWhite.withValues(alpha: 0.3),
};

List<Color> _rarityGradientColors(String r) => switch (r) {
  'rare' => [const Color(0xFF0C4A6E), const Color(0xFF0369A1)],
  'epic' => [const Color(0xFF3B0764), const Color(0xFF6B21A8)],
  'legendary' => [const Color(0xFF78350F), const Color(0xFFB45309)],
  _ => [const Color(0xFF1E2538), const Color(0xFF374151)],
};

// ── Particle ──────────────────────────────────────────────────────────────────
class _Particle {
  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotation,
  });
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double rotation;
}

// ── Stage enum ────────────────────────────────────────────────────────────────
enum _Stage {
  packEntry,
  packPulse,
  packShake,
  flash,
  cardFlip,
  cardSettle,
  rarityDrop,
  ratingCount,
  idle,
  dismissing,
}

// ═════════════════════════════════════════════════════════════════════════════
// Main widget
// ═════════════════════════════════════════════════════════════════════════════
class CardUnpackAnimation extends StatefulWidget {
  const CardUnpackAnimation({
    super.key,
    required this.playerName,
    required this.position,
    required this.rating,
    required this.rarity,
    required this.onComplete,
    this.frontFace, // optional: override the built-in card design
  });

  final String playerName;
  final String position;
  final int rating;
  final String rarity;
  final VoidCallback onComplete;
  /// If provided, displayed as the card front face instead of the built-in design.
  final Widget? frontFace;

  @override
  State<CardUnpackAnimation> createState() => _CardUnpackState();
}

class _CardUnpackState extends State<CardUnpackAnimation>
    with TickerProviderStateMixin {
  // ── State ──
  _Stage _stage = _Stage.packEntry;
  bool _showCard = false;

  // ── Controllers (nullable, created lazily per stage) ──
  AnimationController? _packEntryCtrl; // stage 1 – 400 ms
  AnimationController? _packPulseCtrl; // stage 2 – 400 ms
  AnimationController? _packShakeCtrl; // stage 3 – 300 ms
  AnimationController? _flashCtrl;     // stage 4 – 150 ms
  AnimationController? _cardFlipCtrl;  // stage 5 – 600 ms
  AnimationController? _cardSettleCtrl;// stage 6 – 450 ms
  AnimationController? _particleCtrl;  // stage 7 – 750 ms
  AnimationController? _rarityDropCtrl;// stage 8 – 300 ms
  AnimationController? _shimmerCtrl;   // stage 8 legendary shimmer
  AnimationController? _idleCtrl;      // stage 10 – 2000 ms repeat
  AnimationController? _tapCtrl;       // stage 10 tap pulse – 1200 ms repeat
  AnimationController? _dismissCtrl;   // dismiss – 300 ms

  // ── Derived animations ──
  late Animation<Offset> _packSlide;
  late Animation<double> _packPulseScale;
  late Animation<double> _packShakeX;
  late Animation<double> _packShakeRot;
  late Animation<double> _flashOpacity;
  late Animation<double> _cardFlipAngle;
  late Animation<double> _cardSettleScale;
  late Animation<double> _rarityDropOpacity;
  late Animation<Offset> _rarityDropSlide;
  late Animation<double> _idleLevitate;
  late Animation<double> _tapPulse;
  late Animation<double> _dismissScale;
  late Animation<double> _dismissFade;

  // ── Particle data (fixed at init) ──
  late final List<_Particle> _particles;
  late final List<_Particle> _legendaryParticles;

  // ── Glow / visual values updated by listeners ──
  double _glowBlur = 0;
  double _glowOpacity = 0;
  double _bgPulseOpacity = 0.06;

  // ── Rating counter ──
  int _displayRating = 0;
  bool _ratingFlash = false;
  AnimationController? _ratingCtrl;

  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _initParticles();
    _startStage1();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Particle initialisation
  // ─────────────────────────────────────────────────────────────────────────
  void _initParticles() {
    final glowColor = _rarityBase(widget.rarity);
    _particles = List.generate(24, (i) {
      final angle = (i / 24) * 2 * pi + (_rng.nextDouble() - 0.5) * 0.3;
      final speed = 80 + _rng.nextDouble() * 100;
      final size = 2 + _rng.nextDouble() * 4;
      return _Particle(
        angle: angle,
        speed: speed,
        size: size,
        color: _rng.nextDouble() < 0.6 ? glowColor : _kWhite,
        rotation: _rng.nextDouble() * pi,
      );
    });

    _legendaryParticles = widget.rarity == 'legendary'
        ? List.generate(12, (i) {
            final angle =
                (i / 12) * 2 * pi + (_rng.nextDouble() - 0.5) * 0.3;
            return _Particle(
              angle: angle,
              speed: 60 + _rng.nextDouble() * 80,
              size: 4 + _rng.nextDouble() * 6,
              color: _kGold,
              rotation: _rng.nextDouble() * pi,
            );
          })
        : [];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stage 1: Pack entry slide  (0 – 400 ms)
  // ─────────────────────────────────────────────────────────────────────────
  void _startStage1() {
    _packEntryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _packSlide = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _packEntryCtrl!,
      curve: Curves.easeOutBack,
    ));
    _packEntryCtrl!.forward().then((_) => _startStage2());
    setState(() => _stage = _Stage.packEntry);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stage 2: Pack idle pulse  (400 – 800 ms)
  // ─────────────────────────────────────────────────────────────────────────
  void _startStage2() {
    _packPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _packPulseScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.05), weight: 0.5),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 0.5),
    ]).animate(CurvedAnimation(
      parent: _packPulseCtrl!,
      curve: Curves.easeInOut,
    ));
    _packPulseCtrl!.forward().then((_) => _startStage3());
    setState(() => _stage = _Stage.packPulse);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stage 3: Pack shake  (800 – 1100 ms)
  // ─────────────────────────────────────────────────────────────────────────
  void _startStage3() {
    _packShakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _packShakeX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -3.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -3.0, end: 3.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 3.0, end: 0.0), weight: 1),
    ]).animate(_packShakeCtrl!);
    _packShakeRot = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.04), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.04, end: 0.04), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.04, end: -0.033), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.033, end: 0.033), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.033, end: -0.02), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.02, end: 0.02), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.02, end: -0.01), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.01, end: 0.01), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.01, end: 0.0), weight: 1),
    ]).animate(_packShakeCtrl!);
    _packShakeCtrl!.forward().then((_) => _startStage4());
    setState(() => _stage = _Stage.packShake);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stage 4: Flash  (1100 – 1250 ms)
  // ─────────────────────────────────────────────────────────────────────────
  void _startStage4() {
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _flashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.9), weight: 0.5),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 0.0), weight: 0.5),
    ]).animate(_flashCtrl!);
    // Swap pack → card at the white-out peak
    _flashCtrl!.addListener(() {
      if (_flashCtrl!.value >= 0.5 && !_showCard) {
        setState(() => _showCard = true);
      }
    });
    _flashCtrl!.forward().then((_) => _startStage5());
    setState(() => _stage = _Stage.flash);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stage 5: Card flip  (1250 – 1850 ms)
  // ─────────────────────────────────────────────────────────────────────────
  void _startStage5() {
    _cardFlipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cardFlipAngle = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _cardFlipCtrl!, curve: Curves.easeInOut),
    );
    _cardFlipCtrl!.forward().then((_) => _startStage6());
    setState(() => _stage = _Stage.cardFlip);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stage 6: Card settle + glow burst  (1850 – 2300 ms)
  // Stage 7: Particles run concurrently (1850 – 2600 ms)
  // ─────────────────────────────────────────────────────────────────────────
  void _startStage6() {
    // Stage 7 – particles start simultaneously
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _particleCtrl!.addListener(() => setState(() {}));
    _particleCtrl!.forward();

    // Stage 6 – settle scale
    _cardSettleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _cardSettleScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 200 / 450,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 0.95)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 150 / 450,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.95, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 100 / 450,
      ),
    ]).animate(_cardSettleCtrl!);
    _cardSettleCtrl!.addListener(() {
      final t = _cardSettleCtrl!.value;
      setState(() {
        if (t < 0.5) {
          _glowBlur = lerpDouble(0, 60, t * 2)!;
          _glowOpacity = lerpDouble(0, 1.0, t * 2)!;
        } else {
          _glowBlur = lerpDouble(60, 20, (t - 0.5) * 2)!;
          _glowOpacity = lerpDouble(1.0, 0.5, (t - 0.5) * 2)!;
        }
      });
    });
    _cardSettleCtrl!.forward().then((_) => _startStage8());
    setState(() => _stage = _Stage.cardSettle);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stage 8: Rarity title drop  (2300 – 2700 ms)
  // ─────────────────────────────────────────────────────────────────────────
  void _startStage8() {
    _rarityDropCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _rarityDropOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rarityDropCtrl!, curve: Curves.easeOutBack),
    );
    _rarityDropSlide = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _rarityDropCtrl!, curve: Curves.easeOutBack),
    );
    setState(() => _stage = _Stage.rarityDrop);
    _rarityDropCtrl!.forward().then((_) {
      if (widget.rarity == 'legendary') {
        _startShimmer();
      } else {
        _startStage9();
      }
    });
  }

  // Legendary shimmer – plays exactly twice
  void _startShimmer() {
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _shimmerCtrl!.addListener(() => setState(() {}));
    int count = 0;
    _shimmerCtrl!.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        count++;
        if (count < 2) {
          _shimmerCtrl!.forward(from: 0);
        } else {
          _startStage9();
        }
      }
    });
    _shimmerCtrl!.forward();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stage 9: Rating counter  (2700 – 3200 ms)
  // ─────────────────────────────────────────────────────────────────────────
  void _startStage9() {
    setState(() {
      _stage = _Stage.ratingCount;
      _displayRating = 0;
    });
    _ratingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    final anim = IntTween(begin: 0, end: widget.rating).animate(
      CurvedAnimation(parent: _ratingCtrl!, curve: Curves.easeOut),
    );
    anim.addListener(() {
      if (anim.value != _displayRating) {
        setState(() {
          _displayRating = anim.value;
          _ratingFlash = true;
        });
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) setState(() => _ratingFlash = false);
        });
      }
    });
    _ratingCtrl!.forward().then((_) {
      _ratingCtrl!.dispose();
      _ratingCtrl = null;
      _startStage10();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stage 10: Idle levitation + tap prompt
  // ─────────────────────────────────────────────────────────────────────────
  void _startStage10() {
    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _idleLevitate = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _idleCtrl!, curve: Curves.easeInOut),
    );
    _idleCtrl!.addListener(() {
      final t = _idleCtrl!.value;
      setState(() {
        _glowBlur = lerpDouble(20, 35, t)!;
        _bgPulseOpacity = lerpDouble(0.04, 0.10, t)!;
      });
    });
    _idleCtrl!.repeat(reverse: true);

    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _tapPulse = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _tapCtrl!, curve: Curves.easeInOut),
    );
    _tapCtrl!.repeat(reverse: true);

    setState(() => _stage = _Stage.idle);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Dismiss on tap
  // ─────────────────────────────────────────────────────────────────────────
  void _onTap() {
    if (_stage != _Stage.idle) return;
    setState(() => _stage = _Stage.dismissing);
    _idleCtrl?.stop();
    _tapCtrl?.stop();

    _dismissCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _dismissScale = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _dismissCtrl!, curve: Curves.easeIn),
    );
    _dismissFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _dismissCtrl!, curve: Curves.easeIn),
    );
    _dismissCtrl!.addListener(() => setState(() {}));
    _dismissCtrl!.forward().then((_) => widget.onComplete());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Dispose
  // ─────────────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _packEntryCtrl?.dispose();
    _packPulseCtrl?.dispose();
    _packShakeCtrl?.dispose();
    _flashCtrl?.dispose();
    _cardFlipCtrl?.dispose();
    _cardSettleCtrl?.dispose();
    _particleCtrl?.dispose();
    _rarityDropCtrl?.dispose();
    _shimmerCtrl?.dispose();
    _ratingCtrl?.dispose();
    _idleCtrl?.dispose();
    _tapCtrl?.dispose();
    _dismissCtrl?.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dismissFadeVal =
        (_dismissCtrl != null) ? _dismissFade.value.clamp(0.0, 1.0) : 1.0;

    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: dismissFadeVal,
        child: Stack(
          children: [
            // 1 ── Dark background
            Positioned.fill(child: Container(color: _kBg)),

            // 2 ── Subtle radial glow background
            Positioned.fill(
              child: CustomPaint(
                painter: _BackgroundPainter(
                  glowColor: _rarityGlow(widget.rarity),
                  pulseOpacity: _bgPulseOpacity,
                ),
              ),
            ),

            // 3 ── Particles (only after stage 6 starts)
            if (_particleCtrl != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: _ParticlePainter(
                    particles: _particles,
                    legendaryParticles: _legendaryParticles,
                    animValue: _particleCtrl!.value,
                    isLegendary: widget.rarity == 'legendary',
                  ),
                ),
              ),

            // 4 ── Pack or Card
            Center(child: _buildPackOrCard()),

            // 5 ── Rarity title drop
            if (_rarityDropCtrl != null) _buildRarityTitle(size),

            // 6 ── Flash overlay
            if (_stage == _Stage.flash && _flashCtrl != null)
              AnimatedBuilder(
                animation: _flashCtrl!,
                builder: (_, ignored) => Container(
                  color: _kWhite.withValues(
                    alpha: _flashOpacity.value.clamp(0.0, 1.0),
                  ),
                ),
              ),

            // 7 ── Tap to continue
            if (_stage == _Stage.idle || _stage == _Stage.dismissing)
              _buildTapLabel(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pack or Card switcher
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPackOrCard() {
    return _showCard ? _buildCardAnimated() : _buildPack();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pack widget
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPack() {
    final glowColor = _rarityGlow(widget.rarity);

    // Glow blur: pulse during stage 2
    double blur = 8;
    if (_stage == _Stage.packPulse && _packPulseCtrl != null) {
      final t = _packPulseCtrl!.value;
      blur = lerpDouble(8, 24, t <= 0.5 ? t * 2 : (1 - t) * 2)!;
    }

    Widget pack = Container(
      width: 140,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _rarityGradientColors(widget.rarity),
        ),
        border: Border.all(color: glowColor, width: 1),
        borderRadius: BorderRadius.zero,
        boxShadow: [BoxShadow(color: glowColor, blurRadius: blur)],
      ),
      child: const Center(
        child: Text(
          '?',
          style: TextStyle(
            color: _kWhite,
            fontSize: 48,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );

    // Stage 1: slide in
    if (_stage == _Stage.packEntry && _packEntryCtrl != null) {
      return AnimatedBuilder(
        animation: _packEntryCtrl!,
        builder: (_, child) =>
            SlideTransition(position: _packSlide, child: child),
        child: pack,
      );
    }

    // Stage 2: pulse scale
    if (_stage == _Stage.packPulse && _packPulseCtrl != null) {
      return AnimatedBuilder(
        animation: _packPulseCtrl!,
        builder: (_, child) =>
            ScaleTransition(scale: _packPulseScale, child: child),
        child: pack,
      );
    }

    // Stage 3: shake
    if (_stage == _Stage.packShake && _packShakeCtrl != null) {
      return AnimatedBuilder(
        animation: _packShakeCtrl!,
        builder: (_, child) => Transform(
          transform: Matrix4.identity()
            ..translateByDouble(_packShakeX.value, 0, 0, 1)
            ..rotateZ(_packShakeRot.value),
          alignment: Alignment.center,
          child: child,
        ),
        child: pack,
      );
    }

    return pack;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Card with animated stages
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCardAnimated() {
    final glowColor = _rarityGlow(widget.rarity);

    // Stage 5: 3-D flip
    if (_stage == _Stage.cardFlip && _cardFlipCtrl != null) {
      return AnimatedBuilder(
        animation: _cardFlipCtrl!,
        builder: (_, ignored) {
          final angle = _cardFlipAngle.value;
          final showFront = _cardFlipCtrl!.value >= 0.5;
          final face = showFront
              ? Transform(
                  transform: Matrix4.rotationY(pi),
                  alignment: Alignment.center,
                  child: _buildCardFront(),
                )
              : _buildCardBack();
          return Transform(
            transform: Matrix4.rotationY(angle),
            alignment: Alignment.center,
            child: face,
          );
        },
      );
    }

    // Stage 6: settle scale + glow
    if (_stage == _Stage.cardSettle && _cardSettleCtrl != null) {
      return AnimatedBuilder(
        animation: _cardSettleCtrl!,
        builder: (_, child) => Transform.scale(
          scale: _cardSettleScale.value,
          child: _cardWithGlow(child!, glowColor),
        ),
        child: _buildCardFront(),
      );
    }

    // Stages 7-10 (rarity drop, rating, idle, dismiss)
    Widget card = _cardWithGlow(_buildCardFront(countingRating: _stage == _Stage.ratingCount), glowColor);

    if (_stage == _Stage.idle && _idleCtrl != null) {
      card = AnimatedBuilder(
        animation: _idleCtrl!,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, _idleLevitate.value),
          child: child,
        ),
        child: card,
      );
    }

    if (_stage == _Stage.dismissing && _dismissCtrl != null) {
      card = AnimatedBuilder(
        animation: _dismissCtrl!,
        builder: (_, child) => Transform.scale(
          scale: _dismissScale.value.clamp(0.0, 1.0),
          child: child,
        ),
        child: card,
      );
    }

    return card;
  }

  Widget _cardWithGlow(Widget child, Color glowColor) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: _glowOpacity.clamp(0.0, 1.0)),
            blurRadius: _glowBlur,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Card back face
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCardBack() {
    final glowColor = _rarityGlow(widget.rarity);
    return Container(
      width: 128,
      height: 192,
      decoration: BoxDecoration(
        color: _kBg,
        border: Border.all(color: glowColor, width: 1),
        borderRadius: BorderRadius.zero,
      ),
      child: CustomPaint(
        painter: _CardBackPainter(lineColor: _kCyan.withValues(alpha: 0.3)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Card front face
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCardFront({bool countingRating = false}) {
    // Use caller-provided widget (e.g. CyberPlayerCardTile) when available.
    if (widget.frontFace != null) return widget.frontFace!;
    final glowColor = _rarityGlow(widget.rarity);
    final baseColor = _rarityBase(widget.rarity);
    const topFraction = 0.4;

    final (rarityLabel, rarityColor) = switch (widget.rarity) {
      'rare' => ('RARE', _kCyan),
      'epic' => ('EPIC', _kPurple),
      'legendary' => ('LEGENDARY', _kGold),
      _ => ('COMMON', _kMuted),
    };

    final displayRating = countingRating ? _displayRating : widget.rating;
    final ratingTextColor = (_ratingFlash && countingRating) ? baseColor : _kWhite;

    return Container(
      width: 200,
      height: 280,
      decoration: BoxDecoration(
        color: _kBg,
        border: Border.all(color: glowColor, width: 1),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        children: [
          // Top section (40%)
          SizedBox(
            height: 280 * topFraction,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: _rarityGradientColors(widget.rarity),
                      ),
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
                // Position badge top-left
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    color: _kCyan,
                    child: Text(
                      widget.position,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                // Rating bottom-right
                Positioned(
                  bottom: 6,
                  right: 8,
                  child: Text(
                    '$displayRating',
                    style: TextStyle(
                      color: ratingTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Separator
          Container(height: 1, color: glowColor),
          // Bottom section (60%)
          Expanded(
            child: Container(
              color: _kSurface,
              padding: const EdgeInsets.all(10),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.playerName.toUpperCase(),
                        style: const TextStyle(
                          color: _kWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          height: 1.2,
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'PITCH DUEL',
                        style: TextStyle(
                          color: _kMuted,
                          fontSize: 9,
                          letterSpacing: 1.5,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Text(
                      rarityLabel,
                      style: TextStyle(
                        color: rarityColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        decoration: TextDecoration.none,
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

  // ─────────────────────────────────────────────────────────────────────────
  // Rarity title
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRarityTitle(Size size) {
    final (label, color, ls) = switch (widget.rarity) {
      'rare' => ('RARE FIND', _kCyan, 2.0),
      'epic' => ('EPIC PULL', _kPurple, 2.0),
      'legendary' => ('LEGENDARY', _kGold, 6.0),
      _ => ('COMMON CARD', _kMuted, 2.0),
    };

    Widget text = Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: widget.rarity == 'legendary' ? 24 : 20,
        fontWeight: FontWeight.w900,
        letterSpacing: ls,
        decoration: TextDecoration.none,
      ),
    );

    // Shimmer sweep for legendary
    if (widget.rarity == 'legendary' && _shimmerCtrl != null) {
      text = AnimatedBuilder(
        animation: _shimmerCtrl!,
        builder: (_, child) {
          final pos = _shimmerCtrl!.value;
          return ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.6),
                Colors.transparent,
              ],
              stops: [
                (pos - 0.2).clamp(0.0, 1.0),
                pos.clamp(0.0, 1.0),
                (pos + 0.2).clamp(0.0, 1.0),
              ],
            ).createShader(bounds),
            blendMode: BlendMode.srcATop,
            child: child,
          );
        },
        child: text,
      );
    }

    return Positioned(
      top: size.height * 0.22,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _rarityDropCtrl!,
        builder: (_, child) => SlideTransition(
          position: _rarityDropSlide,
          child: Opacity(
            opacity: _rarityDropOpacity.value.clamp(0.0, 1.0),
            child: child,
          ),
        ),
        child: Center(child: text),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tap-to-continue label
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTapLabel() {
    if (_tapCtrl == null) return const SizedBox.shrink();
    return Positioned(
      bottom: 64,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _tapCtrl!,
        builder: (_, child) => Opacity(
          opacity: _tapPulse.value.clamp(0.0, 1.0),
          child: child,
        ),
        child: const Center(
          child: Text(
            'TAP TO CONTINUE',
            style: TextStyle(
              color: _kMuted,
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Background painter – radial glow
// ═════════════════════════════════════════════════════════════════════════════
class _BackgroundPainter extends CustomPainter {
  const _BackgroundPainter({
    required this.glowColor,
    required this.pulseOpacity,
  });

  final Color glowColor;
  final double pulseOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.7;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          glowColor.withValues(alpha: pulseOpacity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) =>
      old.pulseOpacity != pulseOpacity || old.glowColor != glowColor;
}

// ═════════════════════════════════════════════════════════════════════════════
// Card back painter – diagonal line pattern
// ═════════════════════════════════════════════════════════════════════════════
class _CardBackPainter extends CustomPainter {
  const _CardBackPainter({required this.lineColor});
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    const spacing = 12.0;
    final diag = size.width + size.height;
    for (double d = -diag; d < diag; d += spacing) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CardBackPainter old) => old.lineColor != lineColor;
}

// ═════════════════════════════════════════════════════════════════════════════
// Particle painter
// ═════════════════════════════════════════════════════════════════════════════
class _ParticlePainter extends CustomPainter {
  const _ParticlePainter({
    required this.particles,
    required this.legendaryParticles,
    required this.animValue,
    required this.isLegendary,
  });

  final List<_Particle> particles;
  final List<_Particle> legendaryParticles;
  final double animValue;
  final bool isLegendary;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const gravity = 40.0;

    void drawParticles(List<_Particle> list, double t) {
      if (t <= 0) return;
      final paint = Paint()..style = PaintingStyle.fill;
      for (final p in list) {
        final opacity = (1 - t).clamp(0.0, 1.0);
        final x = center.dx + cos(p.angle) * p.speed * t;
        final y = center.dy + sin(p.angle) * p.speed * t + gravity * t * t;
        paint.color = p.color.withValues(alpha: opacity);
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(p.rotation + t * pi);
        final half = p.size / 2;
        canvas.drawRect(Rect.fromLTWH(-half, -half, p.size, p.size), paint);
        canvas.restore();
      }
    }

    drawParticles(particles, animValue);

    // Legendary second wave: starts at 200ms offset (~200/750 = 0.267)
    if (isLegendary) {
      const delay = 0.267;
      final t2 = animValue > delay ? (animValue - delay) / (1 - delay) : 0.0;
      drawParticles(legendaryParticles, t2);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.animValue != animValue;
}
