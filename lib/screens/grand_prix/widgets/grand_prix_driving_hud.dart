import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/grand_prix/grand_prix_cubit.dart';
import '../../../blocs/grand_prix/grand_prix_state.dart';
import '../../../config/theme.dart';
import '../../../models/grand_prix.dart';
import '../../../games/grand_prix/grand_prix_game.dart';
import '../../../games/grand_prix/grand_prix_engine.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Live driving telemetry stays on notifiers; position alone uses the Cubit.
class GrandPrixDrivingHud extends StatelessWidget {
  const GrandPrixDrivingHud({
    required this.game,
    required this.onPause,
    super.key,
  });
  final GrandPrixGame game;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CyberPanel(
          accent: Cyber.f1Red,
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Row(
                children: [
                  Semantics(
                    label: 'Pause race',
                    button: true,
                    child: IconButton(
                      tooltip: 'Pause race',
                      onPressed: onPause,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.pause,
                        color: Cyber.muted,
                        size: 20,
                      ),
                    ),
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BlocBuilder<GrandPrixCubit, GrandPrixState>(
                            buildWhen: (p, c) =>
                                p.playerPosition != c.playerPosition,
                            builder: (context, state) => Text(
                              'P${state.playerPosition}',
                              style: Cyber.display(24, color: Cyber.cyan)
                                  .copyWith(
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                          ),
                          Text(
                            '/$kFieldSize',
                            style: Cyber.label(10, color: Cyber.muted),
                          ),
                          const SizedBox(width: 24),
                          ValueListenableBuilder<double>(
                            valueListenable: game.speedKph,
                            builder: (context, speed, _) => Text(
                              '${speed.round()}',
                              style: Cyber.display(23).copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'KPH',
                            style: Cyber.label(8, color: Cyber.muted),
                          ),
                          const SizedBox(width: 10),
                          ValueListenableBuilder<GrandPrixTelemetry>(
                            valueListenable: game.telemetry,
                            builder: (context, t, _) => CyberChip(
                              label: 'G${t.gear}',
                              color: Cyber.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: game.currentLap,
                    builder: (context, lap, _) => Text(
                      'LAP $lap/${game.laps}',
                      style: Cyber.label(8, color: Cyber.muted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ValueListenableBuilder<double>(
                      valueListenable: game.lapProgress,
                      builder: (context, progress, _) => CyberProgressBar(
                        value: progress,
                        accent: Cyber.f1Red,
                        height: 4,
                        animate: false,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<GrandPrixTelemetry>(
                valueListenable: game.telemetry,
                builder: (context, t, _) => Row(
                  children: [
                    Text(
                      t.deploying ? 'DEPLOY' : 'ERS',
                      style: Cyber.label(
                        8,
                        color: t.deploying ? Cyber.cyan : Cyber.muted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CyberProgressBar(
                        value: t.energy,
                        accent: Cyber.cyan,
                        height: 4,
                        animate: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(t.energy * 100).round()}%',
                      style: Cyber.label(8, color: Cyber.muted),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t.tow > 0.1
                          ? 'TOW ${(t.tow * 100).round()}%'
                          : '${t.cleanPasses} CLEAN',
                      style: Cyber.label(
                        8,
                        color: t.tow > 0.1 ? Cyber.cyan : Cyber.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<GrandPrixTelemetry>(
          valueListenable: game.telemetry,
          builder: (context, t, _) {
            final showInfo =
                t.rivalName != null ||
                t.grip < 0.85 ||
                t.recoverySeconds > 0 ||
                t.lastLapMs != null;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showInfo)
                  Flexible(
                    child: CyberPanel(
                      accent: Cyber.border,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (t.rivalName != null) ...[
                            Text(
                              t.rivalName!.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Cyber.label(8, color: AppTheme.whiteColor),
                            ),
                            Text(
                              '+${t.rivalGapSeconds.toStringAsFixed(2)}s EST.',
                              style: Cyber.label(8, color: Cyber.muted),
                            ),
                          ],
                          if (t.grip < 0.85) ...[
                            const SizedBox(height: 6),
                            Text(
                              'GRIP ${(t.grip * 100).round()}%',
                              style: Cyber.label(8, color: Cyber.amber),
                            ),
                          ],
                          if (t.recoverySeconds > 0) ...[
                            const SizedBox(height: 6),
                            Text(
                              'RECOVERING ${t.recoverySeconds.ceil()}s',
                              style: Cyber.label(9, color: Cyber.amber),
                            ),
                          ],
                          if (t.lastLapMs != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'LAST ${formatLapTime(t.lastLapMs)}',
                              style: Cyber.label(8, color: Cyber.muted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                const Spacer(),
                if (game.isLoaded)
                  CyberPanel(
                    accent: Cyber.border,
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      children: [
                        Text(
                          'ROUTE',
                          style: Cyber.label(7, color: Cyber.muted),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 64,
                          height: 68,
                          child: CustomPaint(
                            painter: _RoutePainter(
                              game.field.geometry,
                              game.lapProgress.value,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

/// A schematic of the actual scroller centreline, explicitly a route ribbon.
class _RoutePainter extends CustomPainter {
  _RoutePainter(this.geometry, this.progress);
  final GrandPrixTrackGeometry geometry;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final length = geometry.circuit.lapLength;
    final samples = [
      for (var i = 0; i <= 64; i++) geometry.sample(length * i / 64).centerX,
    ];
    final low = samples.reduce(min);
    final high = samples.reduce(max);
    Offset point(double fraction) {
      final index = (fraction * 64).floor().clamp(0, 64);
      return Offset(
        5 + (samples[index] - low) / max(1, high - low) * (size.width - 10),
        size.height - 5 - fraction * (size.height - 10),
      );
    }

    final route = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i <= 64; i++) {
      final p = point(i / 64);
      route.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      route,
      Paint()
        ..color = Cyber.border
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(point(progress), 3.5, Paint()..color = Cyber.cyan);
    canvas.drawCircle(point(1), 2, Paint()..color = AppTheme.whiteColor);
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.geometry != geometry;
}
