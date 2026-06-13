import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../blocs/game/game_event.dart';
import '../../../blocs/game/game_state.dart';
import '../../../config/theme.dart';
import '../../../utils/label_helpers.dart';
import '../../../widgets/card_unpack_animation.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

String _itemRarity(PackRevealItem item) => item.tier.name;

enum _Phase { intro, reveal, actions, summary }

class PackOnboardingScreen extends StatefulWidget {
  const PackOnboardingScreen({required this.reveal, super.key});

  final PackRevealData reveal;

  @override
  State<PackOnboardingScreen> createState() => _PackOnboardingScreenState();
}

class _PackOnboardingScreenState extends State<PackOnboardingScreen>
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
      widget.reveal.animatedItems.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 320),
      ),
    );

    _summaryCtrl = List.generate(
      widget.reveal.items.length,
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
    for (int i = 0; i < widget.reveal.animatedItems.length; i++) {
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

  void _skipIntro() {
    if (!mounted || _phase != _Phase.intro) return;
    _exitFlash.stop();
    setState(() => _phase = _Phase.reveal);
  }

  void _skipAllReveal() {
    if (!mounted || _phase != _Phase.reveal) return;
    if (widget.reveal.groupActionCards &&
        widget.reveal.groupedActionItems.isNotEmpty) {
      setState(() => _phase = _Phase.actions);
    } else {
      _showSummary();
    }
  }

  void _onCardComplete() {
    if (!mounted) return;
    if (_cardIndex < widget.reveal.animatedItems.length - 1) {
      setState(() => _cardIndex++);
    } else if (widget.reveal.groupActionCards &&
        widget.reveal.groupedActionItems.isNotEmpty) {
      setState(() => _phase = _Phase.actions);
    } else {
      _showSummary();
    }
  }

  void _showSummary() {
    setState(() => _phase = _Phase.summary);
    for (int i = 0; i < _summaryCtrl.length; i++) {
      Future.delayed(Duration(milliseconds: 80 + 120 * i), () {
        if (mounted) _summaryCtrl[i].forward();
      });
    }
  }

  void _enterGame() {
    _summaryExit.forward().then((_) {
      if (mounted) context.read<GameBloc>().add(PackRevealSeen());
    });
  }

  @override
  void dispose() {
    _bgPulse.dispose();
    _titleDrop.dispose();
    _exitFlash.dispose();
    for (final c in _slotCtrl) {
      c.dispose();
    }
    for (final c in _summaryCtrl) {
      c.dispose();
    }
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
    _Phase.actions => _buildActions(context),
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
            _PackRevealBackdrop(
              glowColor: Cyber.cyan,
              glowOpacity: 0.04 + 0.05 * _bgPulse.value,
            ),
            Opacity(
              opacity: (1 - ef).clamp(0.0, 1.0),
              child: SafeArea(
                child: DefaultTextStyle(
                  style: const TextStyle(decoration: TextDecoration.none),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: _iv(td, 0.0, 0.28),
                            child: Transform.translate(
                              offset: Offset(
                                0,
                                24 * (1 - _iv(td, 0.0, 0.28)),
                              ),
                              child: Text(
                                'PITCH DUEL',
                                style: Cyber.label(
                                  11,
                                  color: Cyber.cyan.withValues(alpha: 0.5),
                                  letterSpacing: 6,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Opacity(
                            opacity: _iv(td, 0.12, 0.65),
                            child: Transform.translate(
                              offset: Offset(
                                0,
                                80 * (1 - _iv(td, 0.12, 0.65)),
                              ),
                              child: _PackGradientHeadline(
                                text: widget.reveal.headline,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Opacity(
                            opacity: _iv(td, 0.32, 0.72),
                            child: Transform.translate(
                              offset: Offset(
                                0,
                                20 * (1 - _iv(td, 0.32, 0.72)),
                              ),
                              child: Text(
                                widget.reveal.statusLabel,
                                style: Cyber.label(
                                  12,
                                  color: Cyber.amber,
                                  letterSpacing: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 36),
                          Opacity(
                            opacity: _iv(td, 0.5, 0.88),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (
                                  int i = 0;
                                  i < widget.reveal.animatedItems.length;
                                  i++
                                )
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          Opacity(
                            opacity: _iv(td, 0.68, 1.0),
                            child: AnimatedBuilder(
                              animation: _bgPulse,
                              builder: (_, _) => Opacity(
                                opacity: 0.35 + 0.65 * _bgPulse.value,
                                child: Text(
                                  'PREPARING YOUR SQUAD...',
                                  style: Cyber.body(
                                    10,
                                    color: Cyber.muted,
                                    weight: FontWeight.w700,
                                    letterSpacing: 2.5,
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
            ),
            if (ef > 0)
              ColoredBox(
                color: Colors.white.withValues(alpha: ef.clamp(0.0, 1.0)),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: PackSkipButton(onPressed: _skipIntro),
            ),
          ],
        );
      },
    );
  }

  // ── Card reveal ────────────────────────────────────────────────────────────
  Widget _buildReveal(BuildContext context) {
    final animatedItems = widget.reveal.animatedItems;
    final item = animatedItems[_cardIndex];
    return Stack(
      key: ValueKey('reveal_$_cardIndex'),
      fit: StackFit.expand,
      children: [
        CardUnpackAnimation(
          key: ValueKey('unpack_$_cardIndex'),
          playerName: item.shortName,
          position: item.isPlayer
              ? playerRoleLabel(item.playerCard!)
              : item.actionCard!.category.name.toUpperCase(),
          rating: item.rating,
          rarity: _itemRarity(item),
          onComplete: _onCardComplete,
          showTapCountdown: false,
          showSkip: false,
          // SizedBox + FittedBox gives layout size = visual size (192×288),
          // which lets the shimmer overlay in CardUnpackAnimation cover the
          // full card via Positioned.fill (Transform.scale wouldn't work
          // because it leaves layout size at the pre-scale 128×192 bounds).
          frontFace: SizedBox(
            width: 192,
            height: 288,
            child: FittedBox(child: _RevealItemFace(item)),
          ),
        ),
        // Progress indicator overlay at top
        Positioned(
          top: MediaQuery.of(context).padding.top + 14,
          left: 0,
          right: 0,
          child: Center(
            child: _ProgressDots(
              current: _cardIndex + 1,
              total: animatedItems.length,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: PackSkipButton(onPressed: _skipAllReveal),
        ),
      ],
    );
  }

  // ── Summary ────────────────────────────────────────────────────────────────
  Widget _buildActions(BuildContext context) {
    final actions = widget.reveal.groupedActionItems;
    return Stack(
      fit: StackFit.expand,
      children: [
        const _PackRevealBackdrop(glowColor: Cyber.cyan),
        SafeArea(
          child: DefaultTextStyle(
            style: const TextStyle(decoration: TextDecoration.none),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                    child: Column(
                      children: [
                        Text(
                          'ACTION CARDS',
                          textAlign: TextAlign.center,
                          style: Cyber.display(
                            22,
                            color: Cyber.cyan,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${actions.length} ACTIONS UNLOCKED TOGETHER',
                          textAlign: TextAlign.center,
                          style: Cyber.body(
                            10,
                            color: Cyber.muted,
                            weight: FontWeight.w800,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final item in actions)
                              _RevealItemFace(item, size: VisualCardSize.sm),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                _BottomCtaBar(
                  child: FilledButton(
                    onPressed: _showSummary,
                    style: FilledButton.styleFrom(
                      backgroundColor: Cyber.cyan,
                      foregroundColor: Cyber.bg,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(
                      'CONTINUE',
                      style: Cyber.label(14, color: Cyber.bg, letterSpacing: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    final items = widget.reveal.items;
    final playerIndices = [
      for (int i = 0; i < items.length; i++)
        if (items[i].isPlayer) i,
    ];
    final actionIndices = [
      for (int i = 0; i < items.length; i++)
        if (!items[i].isPlayer) i,
    ];
    return AnimatedBuilder(
      animation: _summaryExit,
      builder: (context, child) => Opacity(
        opacity: (1 - _summaryExit.value).clamp(0.0, 1.0),
        child: child,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _PackRevealBackdrop(glowColor: Cyber.lime),
          SafeArea(
            child: DefaultTextStyle(
              style: const TextStyle(decoration: TextDecoration.none),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emoji_events_rounded,
                            size: 54,
                            color: Cyber.gold,
                          ),
                          const SizedBox(height: 14),

                          Text(
                            'SQUAD ASSEMBLED!',
                            style: Cyber.display(
                              22,
                              color: Cyber.lime,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            widget.reveal.summaryLabel,
                            textAlign: TextAlign.center,
                            style: Cyber.body(
                              10,
                              color: Cyber.muted,
                              weight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                          if (widget.reveal.detailLabel != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              widget.reveal.detailLabel!,
                              textAlign: TextAlign.center,
                              style: Cyber.body(
                                10,
                                color: Cyber.cyan.withValues(alpha: 0.85),
                                weight: FontWeight.w800,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ],
                          if (widget.reveal.xpGained > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              '+${widget.reveal.xpGained} XP',
                              textAlign: TextAlign.center,
                              style: Cyber.label(
                                12,
                                color: Cyber.lime.withValues(alpha: 0.9),
                                letterSpacing: 1.6,
                              ),
                            ),
                          ],
                          if (widget.reveal.levelsGained.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'LEVEL ${widget.reveal.levelsGained.last} REACHED',
                              textAlign: TextAlign.center,
                              style: Cyber.label(
                                10,
                                color: Cyber.gold.withValues(alpha: 0.9),
                                letterSpacing: 1.8,
                              ),
                            ),
                          ],
                          const SizedBox(height: 30),

                          // Cards grouped under left-aligned section headers.
                          if (playerIndices.isNotEmpty)
                            _cardGroup('PLAYER CARDS', playerIndices),
                          if (playerIndices.isNotEmpty &&
                              actionIndices.isNotEmpty)
                            const SizedBox(height: 26),
                          if (actionIndices.isNotEmpty)
                            _cardGroup('ACTION CARDS', actionIndices),
                        ],
                    ),
                  ),
                ),
                _BottomCtaBar(
                  child: FilledButton(
                    onPressed: _enterGame,
                    style: FilledButton.styleFrom(
                      backgroundColor: Cyber.lime,
                      foregroundColor: Cyber.bg,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(
                      widget.reveal.ctaLabel,
                      style: Cyber.label(14, color: Cyber.bg, letterSpacing: 2),
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

  /// A left-aligned, full-width section: an accent header with a count over a
  /// start-aligned wrap of the cards at [indices] (indices into
  /// `widget.reveal.items`, so each maps to its own summary animation).
  Widget _cardGroup(String title, List<int> indices) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryGroupHeader(title: title, count: indices.length),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 10,
            runSpacing: 10,
            children: [for (final i in indices) _summaryCard(i)],
          ),
        ],
      ),
    );
  }

  /// A single summary card with its staggered scale-in/fade-in animation.
  Widget _summaryCard(int i) {
    return AnimatedBuilder(
      animation: _summaryCtrl[i],
      builder: (_, _) {
        final t = _summaryCtrl[i].value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.scale(
            scale: Curves.easeOutBack.transform(t),
            child: _RevealItemFace(
              widget.reveal.items[i],
              size: VisualCardSize.sm,
            ),
          ),
        );
      },
    );
  }
}

// ── interval helper: maps t∈[0,1] through range [a,b] ────────────────────────
double _iv(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

/// Solid backdrop for pack-reveal screens. Background painters sit in
/// [Positioned.fill] behind content so grid/glow never bleed through text.
class _PackRevealBackdrop extends StatelessWidget {
  const _PackRevealBackdrop({required this.glowColor, this.glowOpacity = 0.055});

  final Color glowColor;
  final double glowOpacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF0D111A)),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _RadialGlowPainter(
                color: glowColor,
                opacity: glowOpacity,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Gradient pack headline without [ShaderMask] — avoids strikethrough artifacts.
class _PackGradientHeadline extends StatelessWidget {
  const _PackGradientHeadline({required this.text});

  final String text;

  static const _gradient = LinearGradient(
    colors: [Color(0xFF5CDFFF), Color(0xFFD4FF5C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 64;
        final lineCount = '\n'.allMatches(text).length + 1;
        final height = 56.0 * lineCount * 1.08;
        return Text(
          text,
          textAlign: TextAlign.center,
          style: Cyber.display(52, letterSpacing: 4).copyWith(
            height: 1.08,
            foreground: Paint()
              ..shader = _gradient.createShader(
                Rect.fromLTWH(0, 0, width, height),
              ),
          ),
        );
      },
    );
  }
}

/// Docks a primary CTA to the bottom of an onboarding step: full-width button
/// in a container with 24px bottom padding and a hairline top divider, so the
/// content above can scroll while the action stays pinned.
class _BottomCtaBar extends StatelessWidget {
  const _BottomCtaBar({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0D111A),
        border: Border(
          top: BorderSide(color: Cyber.cyan.withValues(alpha: 0.12)),
        ),
      ),
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

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
      ),
      child: Center(
        child: Text(
          '?',
          style: Cyber.display(24, color: Cyber.cyan),
        ),
      ),
    );
  }
}

/// Left-aligned section header for a card group on the summary screen: an
/// accent tick, an uppercase Orbitron label and the item count. Static chrome,
/// so it carries no glow (per the design rule).
class _SummaryGroupHeader extends StatelessWidget {
  const _SummaryGroupHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 15,
          color: Cyber.cyan.withValues(alpha: 0.9),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Cyber.label(13, color: Cyber.cyan, letterSpacing: 2.2),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: Cyber.body(
            11,
            color: Cyber.muted,
            weight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _RevealItemFace extends StatelessWidget {
  const _RevealItemFace(this.item, {this.size = VisualCardSize.md});

  final PackRevealItem item;
  final VisualCardSize size;

  @override
  Widget build(BuildContext context) {
    final player = item.playerCard;
    if (player != null) {
      return CyberPlayerCardTile(card: player, selected: false, size: size);
    }
    return CyberActionCardTile(
      card: item.actionCard!,
      selected: false,
      size: size,
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D111A).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'CARD $current OF $total',
            style: Cyber.body(
              10,
              color: const Color(0xFF94A3B8),
              weight: FontWeight.w700,
              letterSpacing: 2.5,
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
      ),
    );
  }
}

// ── Painters ───────────────────────────────────────────────────────────────────

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
          colors: [
            color.withValues(alpha: opacity),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_RadialGlowPainter old) => old.opacity != opacity;
}
