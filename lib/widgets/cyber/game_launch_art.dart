import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../config/game_ladder.dart';
import 'game_discovery.g.dart';

/// Stable fallback identifiers retained for existing discovery-card callers.
enum CyberGameArt {
  tactics,
  penalty,
  chess,
  cricket,
  basketball,
  racing,
  tennis,
  quiz,
  bingo,
  player,
  driver,
  winner,
}

class DiscoveryPose {
  const DiscoveryPose(this.x, this.y, this.rotate, this.scale, this.opacity);
  final double x, y, rotate, scale, opacity;
}

/// Pure motion evaluator, shared with the generated web family's smoothstep.
DiscoveryPose sampleDiscoveryMotion(List<dynamic> frames, double phase) {
  if (frames.isEmpty) return const DiscoveryPose(0, 0, 0, 1, 1);
  final t = phase.clamp(0.0, 1.0);
  var index = frames.indexWhere((dynamic frame) => (frame['at'] as num) >= t);
  if (index < 0) index = frames.length - 1;
  final a = frames[math.max(0, index - 1)] as Map<String, dynamic>;
  final b = frames[index] as Map<String, dynamic>;
  final start = (a['at'] as num).toDouble(), end = (b['at'] as num).toDouble();
  final u = end == start ? 0.0 : (t - start) / (end - start);
  final eased = u * u * (3 - 2 * u);
  double value(String key) =>
      (a[key] as num).toDouble() +
      ((b[key] as num).toDouble() - (a[key] as num).toDouble()) * eased;
  return DiscoveryPose(
    value('x'),
    value('y'),
    value('rotate'),
    value('scale'),
    value('opacity'),
  );
}

/// Layered original vectors, using the same assets and tracks as statoz_web.
class CyberGameIllustration extends StatefulWidget {
  const CyberGameIllustration({
    required this.art,
    required this.accent,
    this.game,
    this.animate = true,
    this.phase,
    super.key,
  });
  final CyberGameArt art;
  final Color accent;
  final ArcadeGame? game;
  final bool animate;

  /// Deterministic review/seek pose; suppresses the live controller when set.
  final double? phase;

  @override
  State<CyberGameIllustration> createState() => _CyberGameIllustrationState();
}

class _CyberGameIllustrationState extends State<CyberGameIllustration>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: gameDiscoveryData['cycleMs'] as int),
  );
  ScrollPosition? _scroll;
  bool _visible = true;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  void _syncMotion() {
    final active =
        widget.animate &&
        widget.phase == null &&
        _visible &&
        _foreground &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (active) {
      if (!_loop.isAnimating) _loop.repeat();
    } else {
      _loop.stop();
      _loop.value =
          (widget.phase ?? (gameDiscoveryData['stillPhase'] as num).toDouble())
              .clamp(0.0, 1.0);
    }
  }

  void _checkVisibility() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final view = View.of(context);
    var viewport = Offset.zero & (view.physicalSize / view.devicePixelRatio);
    final scrollBox = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (scrollBox is RenderBox && scrollBox.hasSize) {
      viewport = viewport.intersect(
        scrollBox.localToGlobal(Offset.zero) & scrollBox.size,
      );
    }
    final visible = viewport.overlaps(
      box.localToGlobal(Offset.zero) & box.size,
    );
    if (visible != _visible) {
      _visible = visible;
      _syncMotion();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (_scroll != next) {
      _scroll?.removeListener(_checkVisibility);
      _scroll = next;
      _scroll?.addListener(_checkVisibility);
    }
    _syncMotion();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  @override
  void didUpdateWidget(CyberGameIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (mounted) _syncMotion();
  }

  @override
  void dispose() {
    _scroll?.removeListener(_checkVisibility);
    WidgetsBinding.instance.removeObserver(this);
    _loop.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _scene {
    final games = gameDiscoveryData['games'] as Map<String, dynamic>;
    if (widget.game != null) {
      return games.values.cast<Map<String, dynamic>>().firstWhere(
        (scene) => scene['flutter'] == widget.game!.name,
      );
    }
    const fallback = {
      CyberGameArt.tactics: 'pitch-duel',
      CyberGameArt.penalty: 'penalty-shootout',
      CyberGameArt.chess: 'football-chess',
      CyberGameArt.cricket: 'final-over',
      CyberGameArt.basketball: 'hoop-duel',
      CyberGameArt.racing: 'grand-prix-dash',
      CyberGameArt.tennis: 'tennis-rally',
      CyberGameArt.quiz: 'football-quiz',
      CyberGameArt.bingo: 'football-bingo',
      CyberGameArt.player: 'guess-player',
      CyberGameArt.driver: 'guess-driver',
      CyberGameArt.winner: 'tennis-guess-winner',
    };
    return games[fallback[widget.art]] as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    final scene = _scene;
    final pivot = scene['pivot'] as List<dynamic>;
    final alignment = Alignment(
      (pivot[0] as num) / 110 - 1,
      (pivot[1] as num) / 80 - 1,
    );
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 220,
            height: 160,
            child: Stack(
              clipBehavior: Clip.none,
              children: (scene['layers'] as List<dynamic>).map((dynamic layer) {
                final picture = SvgPicture.asset(
                  'assets/game_discovery/layers/${layer['asset']}',
                  width: 220,
                  height: 160,
                  excludeFromSemantics: true,
                );
                final frames = layer['frames'] as List<dynamic>;
                if (frames.isEmpty) return picture;
                return AnimatedBuilder(
                  animation: _loop,
                  child: picture,
                  builder: (context, child) {
                    final pose = sampleDiscoveryMotion(frames, _loop.value);
                    return Transform.translate(
                      offset: Offset(pose.x, pose.y),
                      child: Transform.rotate(
                        angle: pose.rotate * math.pi / 180,
                        alignment: alignment,
                        child: Transform.scale(
                          scale: pose.scale,
                          alignment: alignment,
                          child: Opacity(opacity: pose.opacity, child: child),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
