import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/game/game_bloc.dart';
import '../blocs/game/game_event.dart';
import '../config/theme.dart';
import 'cyber/cyber_widgets.dart';

/// One coach-mark step: highlights [targetKey] and shows copy in a HUD card.
class SpotlightStep {
  const SpotlightStep({
    required this.targetKey,
    required this.title,
    required this.body,
    this.hint,
    this.icon = Icons.info_outline,
    this.accent = Cyber.cyan,
    this.padding = 8,
    this.interactiveKeys = const [],
  });

  final GlobalKey targetKey;
  final String title;
  final String body;
  final String? hint;
  final IconData icon;
  final Color accent;
  final double padding;

  /// Extra regions that stay bright and tappable on this step only.
  final List<GlobalKey> interactiveKeys;
}

/// Where the walkthrough card is anchored on screen.
enum SpotlightCardAnchor {
  /// Place below/above the highlighted target when possible.
  auto,

  /// Pin to bottom center ([SpotlightTutorial.cardBottomInset] above the edge).
  bottom,
}

/// Wraps a walkthrough target so its bounds can be measured.
class SpotlightTarget extends StatelessWidget {
  const SpotlightTarget({
    required this.spotlightKey,
    required this.child,
    super.key,
  });

  final GlobalKey spotlightKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: spotlightKey, child: child);
  }
}

/// Schedules a spotlight walkthrough once per [keyName] (unless [forceToken] bumps).
class SpotlightTutorial extends StatefulWidget {
  const SpotlightTutorial({
    required this.keyName,
    required this.steps,
    this.enabled = true,
    this.startDelay = Duration.zero,
    this.onComplete,
    this.interactiveKeys = const [],
    this.cardAnchor = SpotlightCardAnchor.auto,
    this.cardBottomInset = 24,
    this.forceToken = 0,
    super.key,
  });

  final String keyName;
  final List<SpotlightStep> steps;
  final bool enabled;
  final Duration startDelay;
  final VoidCallback? onComplete;

  /// Extra regions that stay bright and tappable for the whole walkthrough.
  final List<GlobalKey> interactiveKeys;
  final SpotlightCardAnchor cardAnchor;
  final double cardBottomInset;
  final int forceToken;

  @override
  State<SpotlightTutorial> createState() => _SpotlightTutorialState();
}

class _SpotlightTutorialState extends State<SpotlightTutorial> {
  bool _scheduled = false;
  int _lastForceToken = 0;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _lastForceToken = widget.forceToken;
    _maybeSchedule();
  }

  @override
  void didUpdateWidget(covariant SpotlightTutorial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.forceToken != _lastForceToken) {
      _lastForceToken = widget.forceToken;
      _scheduled = false;
      _startTimer?.cancel();
      _schedule(force: true);
      return;
    }
    if (!oldWidget.enabled && widget.enabled) {
      _scheduled = false;
      _maybeSchedule();
    }
  }

  void _maybeSchedule() {
    if (!_scheduled && widget.enabled && widget.steps.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final seen = context.read<GameBloc>().state.tutorialSeen;
        if (!seen.contains(widget.keyName)) {
          _schedule(force: false);
        }
      });
    }
  }

  void _schedule({required bool force}) {
    if (_scheduled || widget.steps.isEmpty) return;
    _scheduled = true;
    _startTimer?.cancel();
    _startTimer = Timer(widget.startDelay, () {
      if (!mounted) return;
      showSpotlightWalkthrough(
        context,
        keyName: widget.keyName,
        steps: widget.steps,
        force: force,
        onComplete: widget.onComplete,
        interactiveKeys: widget.interactiveKeys,
        cardAnchor: widget.cardAnchor,
        cardBottomInset: widget.cardBottomInset,
      );
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void showSpotlightWalkthrough(
  BuildContext context, {
  required String keyName,
  required List<SpotlightStep> steps,
  bool force = false,
  VoidCallback? onComplete,
  List<GlobalKey> interactiveKeys = const [],
  SpotlightCardAnchor cardAnchor = SpotlightCardAnchor.auto,
  double cardBottomInset = 24,
}) {
  if (steps.isEmpty) return;
  final gameBloc = context.read<GameBloc>();
  if (!force && gameBloc.state.tutorialSeen.contains(keyName)) return;

  Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (_, _, _) => BlocProvider.value(
        value: gameBloc,
        child: _SpotlightWalkthroughPage(
          keyName: keyName,
          steps: steps,
          onComplete: onComplete,
          interactiveKeys: interactiveKeys,
          cardAnchor: cardAnchor,
          cardBottomInset: cardBottomInset,
        ),
      ),
    ),
  );
}

class _SpotlightWalkthroughPage extends StatefulWidget {
  const _SpotlightWalkthroughPage({
    required this.keyName,
    required this.steps,
    this.onComplete,
    this.interactiveKeys = const [],
    this.cardAnchor = SpotlightCardAnchor.auto,
    this.cardBottomInset = 24,
  });

  final String keyName;
  final List<SpotlightStep> steps;
  final VoidCallback? onComplete;
  final List<GlobalKey> interactiveKeys;
  final SpotlightCardAnchor cardAnchor;
  final double cardBottomInset;

  @override
  State<_SpotlightWalkthroughPage> createState() =>
      _SpotlightWalkthroughPageState();
}

class _SpotlightWalkthroughPageState extends State<_SpotlightWalkthroughPage> {
  int _index = 0;
  Rect? _targetRect;
  List<Rect> _passThroughRects = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTarget());
  }

  SpotlightStep get _step => widget.steps[_index];

  Future<void> _syncTarget() async {
    final ctx = _step.targetKey.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.25,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 48));
    if (!mounted) return;
    _applyTargetMeasurement();
    if (_targetRect == null) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      _applyTargetMeasurement();
    }
  }

  void _applyTargetMeasurement() {
    setState(() {
      _targetRect = _measureTarget(_step);
      _passThroughRects = _collectPassThroughRects();
    });
  }

  Rect? _measureKey(GlobalKey key) {
    final render = key.currentContext?.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return null;
    final offset = render.localToGlobal(Offset.zero);
    return offset & render.size;
  }

  Rect? _measureTarget(SpotlightStep step) => _measureKey(step.targetKey);

  List<GlobalKey> get _stepInteractiveKeys => [
    ..._step.interactiveKeys,
    ...widget.interactiveKeys,
  ];

  List<Rect> _collectPassThroughRects() {
    final rects = <Rect>[];
    final seen = <GlobalKey>{};

    void addKey(GlobalKey key, double padding) {
      if (!seen.add(key)) return;
      final rect = _measureKey(key);
      if (rect != null) {
        rects.add(rect.inflate(padding));
      }
    }

    addKey(_step.targetKey, _step.padding);
    for (final key in _stepInteractiveKeys) {
      addKey(key, 8);
    }
    return rects;
  }

  bool get _interactiveMode => _stepInteractiveKeys.isNotEmpty;

  void _next() {
    if (_index < widget.steps.length - 1) {
      setState(() {
        _index++;
        _targetRect = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncTarget());
      return;
    }
    _dismiss(markSeen: true);
  }

  void _back() {
    if (_index == 0) return;
    setState(() {
      _index--;
      _targetRect = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTarget());
  }

  void _skipAll() {
    context.read<GameBloc>().add(TutorialsSkippedAll());
    _dismiss(markSeen: false);
  }

  void _dismiss({required bool markSeen}) {
    if (markSeen) {
      context.read<GameBloc>().add(TutorialSeenMarked(widget.keyName));
    }
    Navigator.of(context).pop();
    widget.onComplete?.call();
  }

  bool get _singleStep => widget.steps.length == 1;

  @override
  Widget build(BuildContext context) {
    final step = _step;
    final rect = _targetRect;
    final size = MediaQuery.sizeOf(context);
    const cardMaxHeight = 360.0;
    final cardMaxWidth = min(size.width - 32, 320.0);
    final hole = rect?.inflate(step.padding);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_interactiveMode)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _MultiHoleDimPainter(holes: _passThroughRects),
              ),
            ),
          )
        else
          ..._dimPanels(size, hole),
        Positioned(
          left: 16,
          right: 16,
          top: widget.cardAnchor == SpotlightCardAnchor.bottom
              ? null
              : _cardTop(size, rect),
          bottom: widget.cardAnchor == SpotlightCardAnchor.bottom
              ? widget.cardBottomInset +
                    MediaQuery.paddingOf(context).bottom
              : null,
          child: Center(
            child: Material(
              type: MaterialType.transparency,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: cardMaxWidth,
                  maxHeight: cardMaxHeight,
                ),
                child: CyberPanel(
                  accent: step.accent,
                  solidBackground: true,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: step.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${(_index + 1).toString().padLeft(2, '0')}/${widget.steps.length.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: step.accent,
                                fontFamily: 'Orbitron',
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          if (!_singleStep)
                            TextButton(
                              onPressed: _skipAll,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'SKIP ALL',
                                style: TextStyle(
                                  color: step.accent.withValues(alpha: 0.75),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        step.title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Orbitron',
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        step.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xffb8c4d4),
                          fontFamily: 'Onest',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      if (widget.steps.length > 1) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (var i = 0; i < widget.steps.length; i++)
                              Expanded(
                                child: Container(
                                  height: 2,
                                  margin: EdgeInsets.only(
                                    right: i == widget.steps.length - 1 ? 0 : 3,
                                  ),
                                  color: i == _index
                                      ? step.accent
                                      : i < _index
                                      ? step.accent.withValues(alpha: 0.35)
                                      : const Color(0xff1e2538),
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        height: 1,
                        color: step.accent.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (_index > 0)
                            Expanded(
                              child: TextButton(
                                onPressed: _back,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  '< BACK',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          Expanded(
                            child: TextButton(
                              onPressed: _index < widget.steps.length - 1
                                  ? _next
                                  : _dismissLastStep,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                minimumSize: const Size(0, 44),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                _index < widget.steps.length - 1
                                    ? 'NEXT >'
                                    : 'GOT IT >',
                                style: TextStyle(
                                  color: step.accent,
                                  fontFamily: 'Orbitron',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _dismissLastStep() => _dismiss(markSeen: true);

  double _cardTop(Size screen, Rect? target) {
    const cardEstimate = 360.0;
    const margin = 16.0;
    if (target == null) return screen.height * 0.28;
    final below = target.bottom + margin;
    if (below + cardEstimate < screen.height - margin) return below;
    final above = target.top - cardEstimate - margin;
    if (above > margin) return above;
    return margin;
  }

  /// Four dim panels around the hole so taps pass through the cutout to the UI
  /// below (e.g. HEADS / TAILS on the toss screen).
  List<Widget> _dimPanels(Size screen, Rect? hole) {
    const color = Color(0xD6000000);
    if (hole == null) {
      return [
        Positioned.fill(
          child: ColoredBox(color: color),
        ),
      ];
    }

    final left = hole.left.clamp(0.0, screen.width);
    final top = hole.top.clamp(0.0, screen.height);
    final right = hole.right.clamp(0.0, screen.width);
    final bottom = hole.bottom.clamp(0.0, screen.height);

    return [
      Positioned(left: 0, top: 0, right: 0, height: top, child: _DimPanel(color: color)),
      Positioned(left: 0, top: bottom, right: 0, bottom: 0, child: _DimPanel(color: color)),
      Positioned(left: 0, top: top, width: left, height: bottom - top, child: _DimPanel(color: color)),
      Positioned(left: right, top: top, right: 0, height: bottom - top, child: _DimPanel(color: color)),
    ];
  }
}

class _DimPanel extends StatelessWidget {
  const _DimPanel({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: color);
  }
}

class _MultiHoleDimPainter extends CustomPainter {
  const _MultiHoleDimPainter({required this.holes});

  final List<Rect> holes;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    for (final hole in holes) {
      path.addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(3)));
    }
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = const Color(0xD6000000));
  }

  @override
  bool shouldRepaint(_MultiHoleDimPainter old) => old.holes != holes;
}
