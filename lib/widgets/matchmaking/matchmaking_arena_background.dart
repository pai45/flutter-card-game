import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../cyber/cyber_widgets.dart';

/// Shared animated arena backdrop for matchmaking (and sport lobbies that
/// want the same bed). Optional [asset] overlays a drifting sport plate;
/// missing art falls back to the gradient + texture stack.
class MatchmakingArenaBackground extends StatefulWidget {
  const MatchmakingArenaBackground({
    required this.child,
    this.asset,
    super.key,
  });

  final Widget child;

  /// Optional full-bleed arena image, e.g. `assets/backgrounds/penalty_arena.png`.
  final String? asset;

  @override
  State<MatchmakingArenaBackground> createState() =>
      _MatchmakingArenaBackgroundState();
}

class _MatchmakingArenaBackgroundState extends State<MatchmakingArenaBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff02060f), Color(0xff06121f), Color(0xff01040a)],
        ),
      ),
      child: Stack(
        children: [
          if (asset != null)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final phase = _controller.value * math.pi * 2;
                  return Transform.translate(
                    offset: Offset(math.sin(phase) * 6, math.cos(phase) * 4),
                    child: Transform.scale(
                      scale: 1.05 + 0.008 * math.sin(phase * 2),
                      child: child,
                    ),
                  );
                },
                child: Opacity(
                  opacity: 0.45,
                  child: Image.asset(
                    asset,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Cyber.bg.withValues(alpha: 0.28),
                    Colors.transparent,
                    Cyber.bg.withValues(alpha: 0.6),
                  ],
                  stops: const [0.0, 0.46, 1.0],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: CyberTextureOverlay()),
          widget.child,
        ],
      ),
    );
  }
}
