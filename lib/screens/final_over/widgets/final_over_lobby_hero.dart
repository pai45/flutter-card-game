import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Same local vector composition as web. Decorative motion never gates play.
class FinalOverLobbyHero extends StatefulWidget {
  const FinalOverLobbyHero({this.paused = false, super.key});
  final bool paused;
  static const animationAsset = 'assets/game_lobbies/final-over.json';
  static const posterAsset = 'assets/game_lobbies/final-over-poster.svg';

  @override
  State<FinalOverLobbyHero> createState() => _FinalOverLobbyHeroState();
}

class _FinalOverLobbyHeroState extends State<FinalOverLobbyHero>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock = AnimationController(vsync: this);
  bool _ready = false;
  bool _foreground = true;
  bool _reduced = true;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _enabled = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didUpdateWidget(covariant FinalOverLobbyHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    if (_ready && _foreground && _enabled && !_reduced && !widget.paused) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
    }
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          final dpr = MediaQuery.devicePixelRatioOf(context);
          final scale =
              math.max(
                1,
                (math.min(box.maxWidth / 192, box.maxHeight / 256) * dpr)
                    .round(),
              ) /
              dpr;
          final width = 192 * scale, height = 256 * scale;
          final left = ((box.maxWidth - width) * dpr / 2).round() / dpr;
          final top = ((box.maxHeight - height) * dpr).round() / dpr;
          const fit = BoxFit.fill;
          return ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  width: width,
                  height: height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      SvgPicture.asset(
                        FinalOverLobbyHero.posterAsset,
                        fit: fit,
                        alignment: Alignment.bottomCenter,
                        errorBuilder: (_, _, _) => const SizedBox.expand(),
                      ),
                      if (!_reduced)
                        Opacity(
                          opacity: _ready ? 1 : 0,
                          child: Lottie.asset(
                            FinalOverLobbyHero.animationAsset,
                            controller: _clock,
                            fit: fit,
                            alignment: Alignment.bottomCenter,
                            onLoaded: (composition) {
                              if (!mounted) return;
                              _clock.duration = composition.duration;
                              setState(() => _ready = true);
                              _sync();
                            },
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    super.dispose();
  }
}
