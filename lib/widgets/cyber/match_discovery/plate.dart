part of '../match_discovery.dart';

class EditorialPlate extends StatefulWidget {
  const EditorialPlate({
    required this.child,
    this.onTap,
    this.quiet = false,
    this.gold = false,
    this.backgroundAccent,
    this.signalAccent = Cyber.cyan,
    this.motionId,
    this.contentPadding,
    super.key,
  });
  final Widget child;
  final VoidCallback? onTap;
  final bool quiet, gold;
  final Color? backgroundAccent;
  final Color signalAccent;
  final String? motionId;
  final EdgeInsetsGeometry? contentPadding;
  @override
  State<EditorialPlate> createState() => _EditorialPlateState();
}

class _EditorialPlateState extends State<EditorialPlate>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: MatchDiscoveryTokens.entranceMs),
  );
  final Set<ScrollPosition> _scrolls = {};
  Timer? _delay;
  bool _visible = false, _seen = false, _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _entrance.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _seen = true;
        if (widget.motionId != null) {
          PageStorage.maybeOf(
            context,
          )?.writeState(context, true, identifier: widget.motionId);
        }
      }
    });
    final life = WidgetsBinding.instance.lifecycleState;
    _foreground = life == null || life == AppLifecycleState.resumed;
  }

  void _finishEntrance() {
    _delay?.cancel();
    _delay = null;
    _seen = true;
    _entrance.value = 1;
    if (widget.motionId != null) {
      PageStorage.maybeOf(
        context,
      )?.writeState(context, true, identifier: widget.motionId);
    }
  }

  void _checkEntrance() {
    if (!mounted || _seen) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final view = View.of(context);
    var viewport = Offset.zero & (view.physicalSize / view.devicePixelRatio);
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final render = element.findRenderObject();
        if (render is RenderBox && render.hasSize) {
          viewport = viewport.intersect(
            render.localToGlobal(Offset.zero) & render.size,
          );
        }
      }
      return true;
    });
    final bounds = box.localToGlobal(Offset.zero) & box.size,
        overlap = viewport.intersect(bounds);
    _visible =
        !overlap.isEmpty &&
        overlap.width * overlap.height / (bounds.width * bounds.height) >=
            MatchDiscoveryTokens.entranceThreshold;
    final active =
        _visible &&
        _foreground &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        TickerMode.valuesOf(context).enabled;
    if (!active) {
      _delay?.cancel();
      _delay = null;
      _entrance.stop();
      return;
    }
    if (_entrance.isAnimating || _delay != null) return;
    if (_entrance.value > 0) {
      _entrance.forward();
      return;
    }
    final band = (bounds.top / (viewport.height / 3))
        .floor()
        .clamp(0, 3)
        .toInt();
    _delay = Timer(
      Duration(
        milliseconds: _entrance.value > 0
            ? 0
            : band * MatchDiscoveryTokens.entranceStaggerMs,
      ),
      () {
        _delay = null;
        if (mounted &&
            _visible &&
            _foreground &&
            (ModalRoute.of(context)?.isCurrent ?? true) &&
            TickerMode.valuesOf(context).enabled) {
          _entrance.forward();
        }
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final positions = <ScrollPosition>{};
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        positions.add((element.state as ScrollableState).position);
      }
      return true;
    });
    for (final old in _scrolls.difference(positions)) {
      old.removeListener(_checkEntrance);
    }
    for (final next in positions.difference(_scrolls)) {
      next.addListener(_checkEntrance);
    }
    _scrolls
      ..clear()
      ..addAll(positions);
    if (MediaQuery.disableAnimationsOf(context) ||
        (widget.motionId != null &&
            PageStorage.maybeOf(
                  context,
                )?.readState(context, identifier: widget.motionId) ==
                true)) {
      _seen = true;
      _entrance.value = 1;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkEntrance();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (mounted) _checkEntrance();
  }

  @override
  void dispose() {
    _delay?.cancel();
    for (final position in _scrolls) {
      position.removeListener(_checkEntrance);
    }
    WidgetsBinding.instance.removeObserver(this);
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _entrance,
    builder: (context, _) {
      final progress = Curves.easeOutCubic.transform(_entrance.value);
      return Focus(
        canRequestFocus: false,
        onFocusChange: (focused) {
          if (focused) _finishEntrance();
        },
        child: Transform.translate(
          offset: Offset(
            0,
            MatchDiscoveryTokens.entranceDistance * (1 - progress),
          ),
          child: Opacity(
            opacity: progress,
            child: _buildPlate(context, progress),
          ),
        ),
      );
    },
  );

  bool focused = false, pressed = false;
  void _handleActivate() {
    _finishEntrance();
    HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  Widget _buildPlate(BuildContext context, double progress) {
    final color = widget.gold
        ? Cyber.gold
        : focused
        ? Cyber.cyan
        : kFixtureBorder;
    final surface = ChamferedActionSurface(
      clipper: const HudChamferClipper(
        bigCut: MatchDiscoveryTokens.cut,
        smallCut: 0,
      ),
      borderColor: color,
      child: Container(
        decoration: BoxDecoration(
          color: widget.quiet ? kFixtureStripDark : null,
          gradient: widget.quiet
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kFixtureTop, kFixtureBase, kFixtureStripDark],
                ),
        ),
        child: CustomPaint(
          painter: _EditorialEtching(
            accent: widget.gold ? Cyber.gold : widget.signalAccent,
            quiet: widget.quiet,
            progress: progress,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: widget.backgroundAccent == null
                  ? null
                  : RadialGradient(
                      center: Alignment.topRight,
                      radius: MatchDiscoveryTokens.matchTintRadius,
                      colors: [
                        widget.backgroundAccent!.withValues(
                          alpha: MatchDiscoveryTokens.matchTintOpacity,
                        ),
                        widget.backgroundAccent!.withValues(alpha: 0),
                      ],
                      stops: const [0, MatchDiscoveryTokens.matchTintStop],
                    ),
            ),
            child: Padding(
              padding:
                  widget.contentPadding ??
                  const EdgeInsets.all(MatchDiscoveryTokens.card),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
    if (widget.onTap == null) {
      return surface;
    }
    return Semantics(
      button: true,
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) => setState(() => focused = v),
        onShowHoverHighlight: (v) => setState(() => focused = v),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _handleActivate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleActivate,
          onTapDown: (_) => setState(() => pressed = true),
          onTapUp: (_) => setState(() => pressed = false),
          onTapCancel: () => setState(() => pressed = false),
          child: AnimatedScale(
            scale: pressed ? 0.99 : 1,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 120),
            child: surface,
          ),
        ),
      ),
    );
  }
}

class _EditorialEtching extends CustomPainter {
  const _EditorialEtching({
    required this.accent,
    required this.quiet,
    this.progress = 1,
  });
  final Color accent;
  final bool quiet;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    const inset = MatchDiscoveryTokens.plateInset;
    final rect = Offset.zero & size;
    if (size.width < inset * 2 || size.height < inset * 2) {
      return;
    }
    canvas.save();
    canvas.translate(inset, inset);
    canvas.drawPath(
      const HudChamferClipper(
        bigCut: MatchDiscoveryTokens.cut - inset,
        smallCut: 0,
      ).buildPath(Size(size.width - inset * 2, size.height - inset * 2)),
      Paint()
        ..color = Cyber.line.withValues(
          alpha: quiet ? .18 : MatchDiscoveryTokens.etchOpacity,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
    canvas.restore();
    canvas.drawRect(
      Rect.fromLTWH(
        MatchDiscoveryTokens.cut,
        1,
        MatchDiscoveryTokens.signalLength * (.2 + .8 * progress),
        2,
      ),
      Paint()..color = accent.withValues(alpha: .6),
    );
    if (!quiet) {
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.bottom - 3, rect.width, 3),
        Paint()..color = kFixtureShadow,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EditorialEtching old) =>
      old.accent != accent || old.quiet != quiet || old.progress != progress;
}
