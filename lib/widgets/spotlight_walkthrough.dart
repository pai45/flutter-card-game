import 'dart:async';
import 'dart:math';
import 'dart:ui';

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
  });

  final GlobalKey targetKey;
  final String title;
  final String body;
  final String? hint;
  final IconData icon;
  final Color accent;
  final double padding;
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
    this.forceToken = 0,
    super.key,
  });

  final String keyName;
  final List<SpotlightStep> steps;
  final bool enabled;
  final Duration startDelay;
  final VoidCallback? onComplete;
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
  });

  final String keyName;
  final List<SpotlightStep> steps;
  final VoidCallback? onComplete;

  @override
  State<_SpotlightWalkthroughPage> createState() =>
      _SpotlightWalkthroughPageState();
}

class _SpotlightWalkthroughPageState extends State<_SpotlightWalkthroughPage>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  Rect? _targetRect;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTarget());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
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
    setState(() => _targetRect = _measureTarget(_step));
  }

  Rect? _measureTarget(SpotlightStep step) {
    final render = step.targetKey.currentContext?.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return null;
    final offset = render.localToGlobal(Offset.zero);
    return offset & render.size;
  }

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

  @override
  Widget build(BuildContext context) {
    final step = _step;
    final rect = _targetRect;
    final size = MediaQuery.sizeOf(context);
    const cardMaxHeight = 320.0;
    final cardMaxWidth = min(size.width - 32, 320.0);

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              return CustomPaint(
                painter: _SpotlightDimPainter(
                  target: rect,
                  padding: step.padding,
                  accent: step.accent,
                  pulse: _pulse.value,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
          if (rect != null)
            Positioned(
              left: max(8, rect.left - 4),
              top: max(8, rect.top - 4),
              width: min(rect.width + 8, size.width - 16),
              height: rect.height + 8,
              child: IgnorePointer(child: const SizedBox.shrink()),
            ),
          Positioned(
            left: 16,
            right: 16,
            top: _cardTop(size, rect),
            child: Center(
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
                          TextButton(
                            onPressed: _skipAll,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'SKIP',
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (_index > 0)
                            Expanded(
                              child: TextButton(
                                onPressed: _back,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  '< BACK',
                                  style: TextStyle(fontSize: 10),
                                ),
                              ),
                            ),
                          Expanded(
                            child: TextButton(
                              onPressed: _next,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                _index < widget.steps.length - 1
                                    ? 'NEXT >'
                                    : 'GOT IT >',
                                style: const TextStyle(fontSize: 10),
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
        ],
      ),
    );
  }

  double _cardTop(Size screen, Rect? target) {
    const cardEstimate = 320.0;
    const margin = 16.0;
    if (target == null) return screen.height * 0.28;
    final below = target.bottom + margin;
    if (below + cardEstimate < screen.height - margin) return below;
    final above = target.top - cardEstimate - margin;
    if (above > margin) return above;
    return margin;
  }
}

class _SpotlightDimPainter extends CustomPainter {
  const _SpotlightDimPainter({
    required this.target,
    required this.padding,
    required this.accent,
    required this.pulse,
  });

  final Rect? target;
  final double padding;
  final Color accent;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (target != null) {
      final hole = RRect.fromRectAndRadius(
        target!.inflate(padding),
        const Radius.circular(3),
      );
      dim.addRRect(hole);
      dim.fillType = PathFillType.evenOdd;

      final glowAlpha = 0.35 + pulse * 0.25;
      canvas.drawRRect(
        hole,
        Paint()
          ..color = accent.withValues(alpha: glowAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawRRect(
        hole.inflate(3 + pulse * 4),
        Paint()
          ..color = accent.withValues(alpha: 0.08 + pulse * 0.06)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    canvas.drawPath(
      dim,
      Paint()..color = Colors.black.withValues(alpha: 0.84),
    );
  }

  @override
  bool shouldRepaint(_SpotlightDimPainter old) =>
      old.target != target ||
      old.padding != padding ||
      old.accent != accent ||
      old.pulse != pulse;
}
