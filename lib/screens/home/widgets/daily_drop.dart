import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../blocs/game/game_event.dart';
import '../../../blocs/game/game_state.dart';
import '../../../config/theme.dart';
import '../../../models/progression.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

class DailyDropButton extends StatefulWidget {
  const DailyDropButton({super.key});

  @override
  State<DailyDropButton> createState() => _DailyDropButtonState();
}

class _DailyDropButtonState extends State<DailyDropButton>
    with TickerProviderStateMixin {
  late final AnimationController _shimmer;
  late final AnimationController _glow;
  late final Animation<double> _shimmerPos;
  late final Animation<double> _glowPulse;
  Timer? _timer;
  DateTime _now = DateTime.now();
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    _shimmerPos = CurvedAnimation(
      parent: _shimmer,
      curve: const Interval(0.10, 0.52, curve: Curves.easeInOutCubic),
    );

    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _glowPulse = CurvedAnimation(parent: _glow, curve: Curves.easeInOut);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shimmer.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameState>(
      listenWhen: (previous, current) =>
          previous.pendingPackReveal != current.pendingPackReveal,
      listener: (_, state) {
        if (state.pendingPackReveal != null && mounted) {
          setState(() => _claiming = false);
        }
      },
      builder: (context, state) {
        final status = dailyDropStatus(state.dailyDropLastClaimedAt, _now);
        final ready = status.ready && !_claiming;
        final primary = _claiming
            ? 'OPENING DROP...'
            : status.ready
            ? 'OPEN DAILY DROP'
            : 'NEXT DROP IN ${formatCountdown(status.remaining)}';
        final secondary = status.ready
            ? 'A free card is waiting'
            : "You've claimed today's card - come back tomorrow";
        final accent = ready ? Cyber.cyan : Cyber.muted;

        return AnimatedBuilder(
          animation: Listenable.merge([_shimmer, _glow]),
          builder: (_, child) {
            final shimmerT = ready ? _shimmerPos.value : 0.0;
            final glowT = ready ? _glowPulse.value : 0.0;
            final glowBlur = 12.0 + glowT * 26.0;
            final glowAlpha = ready ? 0.20 + glowT * 0.20 : 0.08;

            return Container(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Cyber.bg.withValues(alpha: 0),
                    Cyber.bg.withValues(alpha: 0.94),
                    Cyber.bg,
                  ],
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: GestureDetector(
                  onTap: ready
                      ? () {
                          setState(() => _claiming = true);
                          context.read<GameBloc>().add(DailyDropClaimed());
                        }
                      : null,
                  child: ClipPath(
                    clipper: CyberClipper(),
                    child: Stack(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: ready
                                  ? const [
                                      Cyber.cyan,
                                      Color(0xff5cdfff),
                                      Cyber.lime,
                                    ]
                                  : const [
                                      Color(0xff1e2538),
                                      Color(0xff111827),
                                      Color(0xff0b1120),
                                    ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: glowAlpha),
                                blurRadius: glowBlur,
                              ),
                            ],
                          ),
                          child: const SizedBox(
                            width: double.infinity,
                            height: 76,
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _ShimmerBandPainter(t: shimmerT),
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
                                  Colors.white.withValues(alpha: 0.12),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.20),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                status.ready ? Icons.style : Icons.lock_clock,
                                color: ready ? Cyber.bg : Cyber.muted,
                              ),
                              const SizedBox(width: 14),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DAILY DROP',
                                    style: TextStyle(
                                      color: ready
                                          ? Cyber.bg.withValues(alpha: 0.72)
                                          : Cyber.muted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    primary,
                                    style: TextStyle(
                                      color: ready ? Cyber.bg : Colors.white70,
                                      fontFamily: 'Orbitron',
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.9,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    secondary,
                                    style: TextStyle(
                                      color: ready
                                          ? Cyber.bg.withValues(alpha: 0.62)
                                          : Cyber.muted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
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
          },
        );
      },
    );
  }
}

class _ShimmerBandPainter extends CustomPainter {
  const _ShimmerBandPainter({required this.t});

  final double t;

  static const double _angle = -0.38;
  static const double _bandWidth = 70.0;
  static const double _pad = 110.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final centerX = -_pad + t * (size.width + _pad * 2);
    canvas.translate(centerX, size.height / 2);
    canvas.rotate(_angle);

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: _bandWidth * 3,
      height: size.height * 2.8,
    );
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.95),
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0, 0.28, 0.44, 0.5, 0.56, 0.72, 1],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShimmerBandPainter old) => old.t != t;
}
