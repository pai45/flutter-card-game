import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../utils/sound_effects.dart';
import 'cyber_widgets.dart';

/// The app's one charting system, lifted out of the pick market detail screen so
/// picks and match stats read as the same surface.
///
/// A chart is a flat [Cyber.chartSurface] panel with a cyan section label, an
/// optional range switcher, a scrubbable plot, and a legend that reads out every
/// series at the scrubbed point. Per the glow rule the panel itself stays calm —
/// the single focal moment is the reveal sweep (see [CyberChartPanel.glow]) and
/// the white playhead the player is dragging.

/// How a series marker is drawn on the plot.
enum ChartMarkerShape { dot, diamond, ring }

/// One plotted line. [values] are in the series' own units; the painter scales
/// every series together so they share one y-axis.
class ChartSeries {
  const ChartSeries({
    required this.label,
    required this.color,
    required this.values,
    this.strokeWidth = 2.4,
    this.fill = false,
    this.readout,
  });

  final String label;
  final Color color;
  final List<double> values;
  final double strokeWidth;

  /// Draws the signature gradient wash beneath the line. Reserve it for the
  /// leading/primary series — one focal series per chart.
  final bool fill;

  /// Formats the legend value at a scrubbed index. Receives the index too, so a
  /// series can read a richer state off a parallel list (a cricket score reads
  /// `84/2`, not just the runs). Defaults to a rounded number.
  final String Function(double value, int index)? readout;

  String readoutAt(int? selectedIndex) {
    if (values.isEmpty) return '—';
    final index = (selectedIndex ?? values.length - 1).clamp(
      0,
      values.length - 1,
    );
    final value = values[index];
    return readout?.call(value, index) ?? value.round().toString();
  }
}

/// A moment pinned to the plot — a goal, a wicket, a lead change.
class ChartMarker {
  const ChartMarker({
    required this.fraction,
    required this.color,
    this.shape = ChartMarkerShape.dot,
    this.label,
    this.alignTop = true,
    this.focal = false,
  });

  /// Horizontal position as 0..1 across the plot.
  final double fraction;
  final Color color;
  final ChartMarkerShape shape;
  final String? label;

  /// Whether the marker rides the top or the bottom edge of the plot.
  final bool alignTop;

  /// The single most decisive marker on the chart. Drawn with an extra halo.
  final bool focal;
}

/// Paints [series] as polylines over a HUD grid, with an optional signed
/// baseline, event [markers], a reveal sweep and a scrub playhead.
class CyberChartPainter extends CustomPainter {
  const CyberChartPainter({
    required this.series,
    required this.selectedIndex,
    this.markers = const <ChartMarker>[],
    this.stepped = false,
    this.signed = false,
    this.bloom = false,
    this.percentScale = false,
    this.revealProgress = 1,
    this.xAxisLabels = const <String>[],
    this.yAxisLabels = false,
    this.gridDivisions = 2,
  });

  final List<ChartSeries> series;
  final int? selectedIndex;
  final List<ChartMarker> markers;

  /// Pins the axis to 0..100 for probability charts. Everything else scales to
  /// its own data.
  final bool percentScale;

  /// Step interpolation (market odds hold their price until the next trade).
  /// Sports series move continuously, so they stay linear.
  final bool stepped;

  /// Plots around a centre baseline with values read as ±, for two-sided
  /// pressure/momentum charts.
  final bool signed;

  /// Adds a blurred underglow beneath each line. Costs a mask filter per
  /// segment — reserve it for the one hero chart on a screen.
  final bool bloom;

  /// 0..1 left-to-right reveal sweep.
  final double revealProgress;

  final List<String> xAxisLabels;
  final bool yAxisLabels;
  final int gridDivisions;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || series.isEmpty) return;

    final topInset = markers.isEmpty ? 0.0 : 14.0;
    final bottomInset = xAxisLabels.isEmpty ? 0.0 : 16.0;
    final leftInset = yAxisLabels ? 26.0 : 0.0;
    final rect = Rect.fromLTRB(
      leftInset,
      topInset,
      size.width,
      size.height - bottomInset,
    );
    if (rect.width <= 0 || rect.height <= 0) return;

    final values = [for (final item in series) ...item.values];
    if (values.isEmpty) return;

    final double minValue;
    final double maxValue;
    if (signed) {
      final extent = math.max(
        1.0,
        values.map((value) => value.abs()).reduce(math.max),
      );
      minValue = -extent;
      maxValue = extent;
    } else if (percentScale) {
      minValue = math.max(0, values.reduce(math.min) - 8);
      maxValue = math.min(100, values.reduce(math.max) + 8);
    } else {
      final low = values.reduce(math.min);
      final high = values.reduce(math.max);
      final pad = math.max(1.0, (high - low) * 0.08);
      // Don't pad an all-positive series below zero — runs and counts have no
      // negative half to show.
      minValue = low >= 0 ? math.max(0, low - pad) : low - pad;
      maxValue = high + pad;
    }
    final spread = math.max(1.0, maxValue - minValue);

    _paintGrid(canvas, rect, minValue, spread);
    _paintXAxis(canvas, rect);

    final revealX = rect.left + rect.width * revealProgress.clamp(0.0, 1.0);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(rect.left, 0, revealX, size.height));

    for (var s = 0; s < series.length; s++) {
      _paintSeries(canvas, rect, series[s], minValue, spread);
    }
    for (final marker in markers) {
      _paintMarker(canvas, rect, marker);
    }
    canvas.restore();

    _paintPlayhead(canvas, rect, minValue, spread);
  }

  void _paintGrid(Canvas canvas, Rect rect, double minValue, double spread) {
    final grid = Paint()
      ..color = Cyber.border.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 0; i <= gridDivisions; i++) {
      final y = rect.top + rect.height * i / gridDivisions;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
      if (yAxisLabels) {
        final value = minValue + spread * (1 - i / gridDivisions);
        _paintText(
          canvas,
          value.round().toString(),
          Cyber.label(7, color: Cyber.muted),
          Offset(rect.left - 5, y - 4),
          alignRight: true,
        );
      }
    }
    if (signed) {
      canvas.drawLine(
        Offset(rect.left, rect.center.dy),
        Offset(rect.right, rect.center.dy),
        Paint()
          ..color = Cyber.cyan.withValues(alpha: 0.38)
          ..strokeWidth = 1.2,
      );
    }
  }

  void _paintXAxis(Canvas canvas, Rect rect) {
    if (xAxisLabels.isEmpty) return;
    for (var i = 0; i < xAxisLabels.length; i++) {
      final x = xAxisLabels.length == 1
          ? rect.center.dx
          : rect.left + rect.width * i / (xAxisLabels.length - 1);
      _paintText(
        canvas,
        xAxisLabels[i],
        Cyber.label(7, color: Cyber.muted),
        Offset(x, rect.bottom + 5),
        centered: true,
      );
    }
  }

  void _paintSeries(
    Canvas canvas,
    Rect rect,
    ChartSeries item,
    double minValue,
    double spread,
  ) {
    final points = _pointsFor(rect, item, minValue, spread);
    if (points.isEmpty) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      if (stepped) path.lineTo(points[i].dx, points[i - 1].dy);
      path.lineTo(points[i].dx, points[i].dy);
    }

    if (item.fill && points.length > 1) {
      final base = signed ? rect.center.dy : rect.bottom;
      // A signed series that sits below the baseline fills downward, so its
      // wash has to run the other way to stay anchored to the baseline.
      final below = signed && item.values.reduce(math.max) <= 0;
      canvas.drawPath(
        Path.from(path)
          ..lineTo(points.last.dx, base)
          ..lineTo(points.first.dx, base)
          ..close(),
        Paint()
          ..shader = LinearGradient(
            begin: below ? Alignment.bottomCenter : Alignment.topCenter,
            end: below ? Alignment.topCenter : Alignment.bottomCenter,
            colors: [
              item.color.withValues(alpha: 0.18),
              item.color.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    if (bloom) {
      canvas.drawPath(
        path,
        Paint()
          ..color = item.color.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = item.strokeWidth + 2.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = item.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = item.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  List<Offset> _pointsFor(
    Rect rect,
    ChartSeries item,
    double minValue,
    double spread,
  ) => [
    for (var i = 0; i < item.values.length; i++)
      Offset(
        item.values.length == 1
            ? rect.right
            : rect.left + rect.width * i / (item.values.length - 1),
        rect.bottom - ((item.values[i] - minValue) / spread) * rect.height,
      ),
  ];

  void _paintMarker(Canvas canvas, Rect rect, ChartMarker marker) {
    final x = rect.left + rect.width * marker.fraction.clamp(0.0, 1.0);
    final y = marker.alignTop ? rect.top + 7 : rect.bottom - 7;
    final stubEnd = marker.focal
        ? (marker.alignTop ? rect.bottom : rect.top)
        : (marker.alignTop ? y + 16 : y - 16);
    canvas.drawLine(
      Offset(x, y),
      Offset(x, stubEnd),
      Paint()
        ..color = marker.color.withValues(alpha: marker.focal ? 0.34 : 0.22)
        ..strokeWidth = 1,
    );
    final center = Offset(x, y);
    final fill = Paint()..color = marker.color;

    switch (marker.shape) {
      case ChartMarkerShape.dot:
        canvas.drawCircle(center, 4.5, fill);
      case ChartMarkerShape.diamond:
        canvas.drawPath(
          Path()
            ..moveTo(center.dx, center.dy - 4.5)
            ..lineTo(center.dx + 4.5, center.dy)
            ..lineTo(center.dx, center.dy + 4.5)
            ..lineTo(center.dx - 4.5, center.dy)
            ..close(),
          fill,
        );
      case ChartMarkerShape.ring:
        canvas.drawCircle(
          center,
          4.5,
          Paint()
            ..color = marker.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8,
        );
    }
    canvas.drawCircle(
      center,
      marker.focal ? 10 : 7.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = marker.color.withValues(alpha: marker.focal ? 0.75 : 0.48),
    );
  }

  void _paintPlayhead(
    Canvas canvas,
    Rect rect,
    double minValue,
    double spread,
  ) {
    final pointCount = chartPointCount(series);
    final index = selectedChartIndex(selectedIndex, pointCount);
    if (index == null) return;

    final x = pointCount <= 1
        ? rect.right
        : rect.left + rect.width * index / (pointCount - 1);
    drawDashedLine(
      canvas,
      Offset(x, rect.top),
      Offset(x, rect.bottom),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.square,
    );

    final marker = series.first;
    if (marker.values.isEmpty) return;
    final value = marker.values[index.clamp(0, marker.values.length - 1)];
    final center = Offset(
      x,
      rect.bottom - ((value - minValue) / spread) * rect.height,
    );
    canvas.drawCircle(
      center,
      12,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawCircle(
      center,
      7,
      Paint()..color = marker.color.withValues(alpha: 0.18),
    );
    canvas.drawCircle(center, 4, Paint()..color = marker.color);
  }

  void _paintText(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset offset, {
    bool centered = false,
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = centered
        ? offset.dx - painter.width / 2
        : alignRight
        ? offset.dx - painter.width
        : offset.dx;
    painter.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant CyberChartPainter old) =>
      old.series != series ||
      old.selectedIndex != selectedIndex ||
      old.markers != markers ||
      old.revealProgress != revealProgress;
}

/// The full chart treatment: header + optional range tabs + scrubbable plot +
/// legend readout, with an expand button that reopens the same plot full-screen.
class CyberChartPanel extends StatefulWidget {
  const CyberChartPanel({
    required this.title,
    required this.series,
    this.caption,
    this.markers = const <ChartMarker>[],
    this.ranges = const <String>[],
    this.activeRange,
    this.onRangeChanged,
    this.contextLabelAt,
    this.height = 200,
    this.stepped = false,
    this.signed = false,
    this.bloom = false,
    this.percentScale = false,
    this.revealProgress = 1,
    this.glow = false,
    this.xAxisLabels = const <String>[],
    this.yAxisLabels = false,
    this.gridDivisions = 2,
    this.markerSound = true,
    this.chartKey,
    super.key,
  });

  final String title;
  final List<ChartSeries> series;

  /// Right-aligned muted caption — the market panel's "128 BETS" slot.
  final String? caption;
  final List<ChartMarker> markers;
  final List<String> ranges;
  final String? activeRange;
  final ValueChanged<String>? onRangeChanged;

  /// Trailing context for the legend at a scrubbed index — `67'`, `10.0 OV`,
  /// `Q4 2:31`.
  final String Function(int index)? contextLabelAt;

  final double height;
  final bool stepped;
  final bool signed;
  final bool bloom;
  final bool percentScale;
  final double revealProgress;

  /// Set only while the reveal sweep is running — the one focal moment.
  final bool glow;

  final List<String> xAxisLabels;
  final bool yAxisLabels;
  final int gridDivisions;

  /// Clicks when the scrub crosses a marker, so dragging over a goal or wicket
  /// has a beat.
  final bool markerSound;

  final Key? chartKey;

  @override
  State<CyberChartPanel> createState() => _CyberChartPanelState();
}

class _CyberChartPanelState extends State<CyberChartPanel> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(CyberChartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeRange != widget.activeRange) _selectedIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    final pointCount = chartPointCount(widget.series);
    final selectedIndex = selectedChartIndex(_selectedIndex, pointCount);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Cyber.chartSurface,
        border: Border.all(color: Cyber.border),
        boxShadow: widget.glow
            ? Cyber.glow(Cyber.cyan, alpha: 0.18, blur: 18, spread: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.label(10, color: Cyber.cyan),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Expand chart',
                onPressed: () => _openExpanded(context),
                icon: const Icon(
                  Icons.open_in_full,
                  color: Cyber.cyan,
                  size: 16,
                ),
              ),
              if (widget.caption != null)
                Text(
                  widget.caption!,
                  style: Cyber.label(9, color: Cyber.muted),
                ),
            ],
          ),
          if (widget.ranges.isNotEmpty) ...[
            const SizedBox(height: 10),
            CyberChartRangeTabs(
              ranges: widget.ranges,
              active: widget.activeRange ?? widget.ranges.first,
              onChanged: (range) {
                setState(() => _selectedIndex = null);
                widget.onRangeChanged?.call(range);
              },
            ),
          ],
          const SizedBox(height: 12),
          _ChartSurface(
            chartKey: widget.chartKey,
            height: widget.height,
            pointCount: pointCount,
            selectedIndex: selectedIndex,
            onScrub: _scrubTo,
            painter: _painter(selectedIndex),
          ),
          const SizedBox(height: 10),
          CyberChartLegend(
            series: widget.series,
            selectedIndex: selectedIndex,
            contextLabel: selectedIndex == null
                ? null
                : widget.contextLabelAt?.call(selectedIndex),
          ),
        ],
      ),
    );
  }

  CyberChartPainter _painter(int? selectedIndex) => CyberChartPainter(
    series: widget.series,
    selectedIndex: selectedIndex,
    markers: widget.markers,
    stepped: widget.stepped,
    signed: widget.signed,
    bloom: widget.bloom,
    percentScale: widget.percentScale,
    revealProgress: widget.revealProgress,
    xAxisLabels: widget.xAxisLabels,
    yAxisLabels: widget.yAxisLabels,
    gridDivisions: widget.gridDivisions,
  );

  void _scrubTo(int index, int pointCount) {
    if (index == _selectedIndex) return;
    HapticFeedback.selectionClick();
    if (widget.markerSound &&
        _crossesMarker(_selectedIndex, index, pointCount)) {
      playSound(SoundEffect.uiTap);
    }
    setState(() => _selectedIndex = index);
  }

  bool _crossesMarker(int? from, int to, int pointCount) {
    if (widget.markers.isEmpty || pointCount <= 1) return false;
    final previous = from ?? pointCount - 1;
    final low = math.min(previous, to);
    final high = math.max(previous, to);
    for (final marker in widget.markers) {
      final index = (marker.fraction.clamp(0.0, 1.0) * (pointCount - 1))
          .round();
      if (index > low && index <= high) return true;
    }
    return false;
  }

  void _openExpanded(BuildContext context) {
    playSound(SoundEffect.uiTap);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CyberChartFullScreen(
          title: widget.title,
          caption: widget.caption,
          series: widget.series,
          markers: widget.markers,
          ranges: widget.ranges,
          activeRange: widget.activeRange,
          onRangeChanged: widget.onRangeChanged,
          contextLabelAt: widget.contextLabelAt,
          stepped: widget.stepped,
          signed: widget.signed,
          bloom: widget.bloom,
          percentScale: widget.percentScale,
          xAxisLabels: widget.xAxisLabels,
          yAxisLabels: widget.yAxisLabels,
          gridDivisions: widget.gridDivisions,
        ),
      ),
    );
  }
}

/// The scrub surface itself — shared by the inline panel and the full-screen
/// route so the drag maths only lives in one place.
class _ChartSurface extends StatelessWidget {
  const _ChartSurface({
    required this.height,
    required this.pointCount,
    required this.selectedIndex,
    required this.onScrub,
    required this.painter,
    this.chartKey,
    this.expand = false,
  });

  final double? height;
  final int pointCount;
  final int? selectedIndex;
  final void Function(int index, int pointCount) onScrub;
  final CustomPainter painter;
  final Key? chartKey;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void selectAt(Offset position) => onScrub(
          indexForChartDx(
            dx: position.dx,
            width: constraints.maxWidth,
            pointCount: pointCount,
          ),
          pointCount,
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => selectAt(details.localPosition),
          onHorizontalDragUpdate: (details) => selectAt(details.localPosition),
          child: SizedBox(
            key: chartKey,
            height: expand ? null : height,
            child: CustomPaint(
              painter: painter,
              child: expand ? const SizedBox.expand() : null,
            ),
          ),
        );
      },
    );
  }
}

/// Full-screen presentation of a [CyberChartPanel]'s plot.
class CyberChartFullScreen extends StatefulWidget {
  const CyberChartFullScreen({
    required this.title,
    required this.series,
    this.caption,
    this.markers = const <ChartMarker>[],
    this.ranges = const <String>[],
    this.activeRange,
    this.onRangeChanged,
    this.contextLabelAt,
    this.stepped = false,
    this.signed = false,
    this.bloom = false,
    this.percentScale = false,
    this.xAxisLabels = const <String>[],
    this.yAxisLabels = false,
    this.gridDivisions = 2,
    super.key,
  });

  final String title;
  final List<ChartSeries> series;
  final String? caption;
  final List<ChartMarker> markers;
  final List<String> ranges;
  final String? activeRange;
  final ValueChanged<String>? onRangeChanged;
  final String Function(int index)? contextLabelAt;
  final bool stepped;
  final bool signed;
  final bool bloom;
  final bool percentScale;
  final List<String> xAxisLabels;
  final bool yAxisLabels;
  final int gridDivisions;

  @override
  State<CyberChartFullScreen> createState() => _CyberChartFullScreenState();
}

class _CyberChartFullScreenState extends State<CyberChartFullScreen> {
  late String? _range = widget.activeRange;
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final pointCount = chartPointCount(widget.series);
    final selectedIndex = selectedChartIndex(_selectedIndex, pointCount);

    return Scaffold(
      backgroundColor: Cyber.bg,
      body: CyberPlainBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        widget.title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.display(16, letterSpacing: 1),
                      ),
                    ),
                    if (widget.caption != null)
                      Text(
                        widget.caption!,
                        style: Cyber.label(9, color: Cyber.muted),
                      ),
                  ],
                ),
              ),
              if (widget.ranges.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CyberChartRangeTabs(
                    ranges: widget.ranges,
                    active: _range ?? widget.ranges.first,
                    onChanged: (range) {
                      setState(() {
                        _range = range;
                        _selectedIndex = null;
                      });
                      widget.onRangeChanged?.call(range);
                    },
                  ),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ChartSurface(
                    height: null,
                    expand: true,
                    pointCount: pointCount,
                    selectedIndex: selectedIndex,
                    onScrub: (index, _) {
                      if (index == _selectedIndex) return;
                      HapticFeedback.selectionClick();
                      setState(() => _selectedIndex = index);
                    },
                    painter: CyberChartPainter(
                      series: widget.series,
                      selectedIndex: selectedIndex,
                      markers: widget.markers,
                      stepped: widget.stepped,
                      signed: widget.signed,
                      bloom: widget.bloom,
                      percentScale: widget.percentScale,
                      xAxisLabels: widget.xAxisLabels,
                      yAxisLabels: widget.yAxisLabels,
                      gridDivisions: widget.gridDivisions,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: CyberChartLegend(
                  series: widget.series,
                  selectedIndex: selectedIndex,
                  contextLabel: selectedIndex == null
                      ? null
                      : widget.contextLabelAt?.call(selectedIndex),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Equal-width range switcher (ALL / WEEK / DAY, FULL / 1ST HALF / 2ND HALF…).
/// The active tab is the single tinted element; per the glow rule it doesn't glow.
class CyberChartRangeTabs extends StatelessWidget {
  const CyberChartRangeTabs({
    required this.ranges,
    required this.active,
    required this.onChanged,
    super.key,
  });

  final List<String> ranges;
  final String active;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final range in ranges) ...[
          Expanded(
            child: _RangeButton(
              label: range,
              active: range == active,
              onTap: () {
                if (range == active) return;
                playSound(SoundEffect.uiTap);
                onChanged(range);
              },
            ),
          ),
          if (range != ranges.last) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class _RangeButton extends StatelessWidget {
  const _RangeButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? Cyber.cyan.withValues(alpha: 0.14)
              : Cyber.bg.withValues(alpha: 0.34),
          border: Border.all(
            color: active ? Cyber.cyan : Cyber.border.withValues(alpha: 0.75),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Cyber.label(9, color: active ? Cyber.cyan : Cyber.muted),
        ),
      ),
    );
  }
}

/// Swatch + per-series readout at the scrubbed index, with optional trailing
/// context (the minute, the over, the game clock).
class CyberChartLegend extends StatelessWidget {
  const CyberChartLegend({
    required this.series,
    required this.selectedIndex,
    this.contextLabel,
    super.key,
  });

  final List<ChartSeries> series;
  final int? selectedIndex;
  final String? contextLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 7,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final item in series)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 14, height: 3, color: item.color),
              const SizedBox(width: 6),
              Text(
                '${item.label} ${item.readoutAt(selectedIndex)}',
                style: Cyber.body(
                  10,
                  color: item.color,
                  weight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        if (contextLabel != null)
          Text(
            contextLabel!,
            style: Cyber.label(
              9,
              color: Cyber.muted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }
}

/// Longest series length across [series].
int chartPointCount(List<ChartSeries> series) {
  var count = 0;
  for (final item in series) {
    if (item.values.length > count) count = item.values.length;
  }
  return count;
}

/// Clamps a scrub index into range; a null selection reads the latest point.
int? selectedChartIndex(int? selectedIndex, int pointCount) {
  if (pointCount <= 0) return null;
  if (selectedIndex == null) return pointCount - 1;
  return selectedIndex.clamp(0, pointCount - 1);
}

/// Maps a horizontal drag position onto a series index.
int indexForChartDx({
  required double dx,
  required double width,
  required int pointCount,
}) {
  if (pointCount <= 1 || width <= 0) return 0;
  final percent = (dx / width).clamp(0.0, 1.0);
  return (percent * (pointCount - 1)).round();
}

/// Reads one series at a scrub index, clamped.
double seriesValueAt(ChartSeries series, int? selectedIndex) {
  if (series.values.isEmpty) return 0;
  final index = selectedIndex ?? series.values.length - 1;
  return series.values[index.clamp(0, series.values.length - 1)];
}

void drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
  const dash = 8.0;
  const gap = 6.0;
  final distance = (end - start).distance;
  if (distance <= 0) return;
  final direction = (end - start) / distance;
  var drawn = 0.0;
  while (drawn < distance) {
    canvas.drawLine(
      start + direction * drawn,
      start + direction * math.min(drawn + dash, distance),
      paint,
    );
    drawn += dash + gap;
  }
}
