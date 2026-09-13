import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

import '../../../config/theme.dart';
import '../../../models/f1_race_package.dart';
import '../../../models/sport_match.dart';
import '../../../services/f1_race_package_service.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_chart.dart';
import '../../../widgets/cyber/cyber_filter_chips.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import 'match_stats_shell.dart';
import 'standings_table.dart';

/// The motorsport STATS tab.
///
/// A Grand Prix is not a 1v1, so this deliberately does **not** use
/// [MatchPulseHeader] — there is no home-vs-away pair to put either side of a
/// split bar. The hero is the circuit itself.
///
/// There is no lap chart, and there cannot be one: ESPN publishes no lap-by-lap
/// data for F1. Every lap endpoint 404s, the `plays` feed returns `count: 0`,
/// and `lapsLead` is broken (it totals 4 across the field of a 53-lap race), so
/// nothing here claims to know who led on any given lap. What the feed does
/// support is charted honestly — see docs/data/f1-race-field-inventory.md.
///
/// Races the bundled package does not cover fall back to the ESPN scoreboard
/// panels, which carry pre-formatted result strings rather than parsed data.
class MotorsportMatchStatsView extends StatefulWidget {
  const MotorsportMatchStatsView({
    required this.match,
    this.enableFeedback = true,
    super.key,
  });

  final SportMatch match;

  /// Suppresses haptics so widget tests settle deterministically.
  final bool enableFeedback;

  @override
  State<MotorsportMatchStatsView> createState() =>
      _MotorsportMatchStatsViewState();
}

class _MotorsportMatchStatsViewState extends State<MotorsportMatchStatsView> {
  late Future<F1RacePackage?> _package;

  @override
  void initState() {
    super.initState();
    _package = _resolve();
  }

  @override
  void didUpdateWidget(MotorsportMatchStatsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.id != widget.match.id) _package = _resolve();
  }

  Future<F1RacePackage?> _resolve() => F1RacePackageService.packageFor(
    raceId: widget.match.id,
    // Motorsport fixtures carry the Grand Prix title on the home side; the
    // synthetic away entry is only the series label.
    name: widget.match.home.name,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<F1RacePackage?>(
      future: _package,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Cyber.cyan,
              ),
            ),
          );
        }
        final package = snapshot.data;
        if (package == null) {
          return F1ScoreboardFallback(match: widget.match);
        }
        return _F1RaceStats(
          package: package,
          enableFeedback: widget.enableFeedback,
        );
      },
    );
  }
}

class _F1RaceStats extends StatefulWidget {
  const _F1RaceStats({required this.package, required this.enableFeedback});

  final F1RacePackage package;
  final bool enableFeedback;

  @override
  State<_F1RaceStats> createState() => _F1RaceStatsState();
}

class _F1RaceStatsState extends State<_F1RaceStats> {
  static const _tabs = <String>['RACE', 'WEEKEND', 'QUALIFYING'];

  String _activeTab = _tabs.first;

  void _selectTab(String tab) {
    if (tab == _activeTab) return;
    if (widget.enableFeedback) HapticFeedback.selectionClick();
    setState(() => _activeTab = tab);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CyberFilterChips(
          labels: _tabs,
          selected: _activeTab,
          accent: Cyber.cyan,
          onSelect: _selectTab,
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey(_activeTab),
              child: switch (_activeTab) {
                'WEEKEND' => _WeekendSection(package: widget.package),
                'QUALIFYING' => _QualifyingSection(package: widget.package),
                _ => _RaceSection(package: widget.package),
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// RACE
// ---------------------------------------------------------------------------

class _RaceSection extends StatelessWidget {
  const _RaceSection({required this.package});

  final F1RacePackage package;

  @override
  Widget build(BuildContext context) {
    final race = package.race;

    return ListView(
      key: const ValueKey('motorsport-stats-race'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        _CircuitHero(package: package),
        if (race == null || race.classification.isEmpty) ...[
          const SizedBox(height: 18),
          const CyberNoDataState(
            icon: Icons.sports_score_outlined,
            title: 'Race not run',
            message:
                'Classification, gaps and positions gained land here once the '
                'chequered flag drops.',
            accent: Cyber.gold,
            spark: Icons.flag_outlined,
          ),
        ] else ...[
          const SizedBox(height: 18),
          const CyberSectionHeading(
            key: ValueKey('motorsport-gap-heading'),
            label: 'GAP TO LEADER',
          ),
          const SizedBox(height: 10),
          _RaceGapChart(package: package, race: race),
          const SizedBox(height: 18),
          const CyberSectionHeading(label: 'CLASSIFICATION'),
          const SizedBox(height: 10),
          _ClassificationList(package: package, race: race),
        ],
      ],
    );
  }
}

/// The race hero: the circuit ESPN draws, the numbers that define a lap of it,
/// and who won. Replaces the two-sided team plate the other sports use.
class _CircuitHero extends StatelessWidget {
  const _CircuitHero({required this.package});

  final F1RacePackage package;

  @override
  Widget build(BuildContext context) {
    final circuit = package.circuit;
    final winner = package.winner;
    final driver = winner == null ? null : package.driver(winner.driverId);
    final accent = _entryColor(package, winner) ?? Cyber.cyan;

    return ClipPath(
      clipper: const HudChamferClipper(bigCut: 16, smallCut: 3),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Cyber.chartSurface,
          border: Border.all(color: Cyber.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CyberStatPill(
                  label: package.abbreviation ?? 'F1',
                  color: Cyber.magenta,
                ),
                const SizedBox(width: 8),
                if (package.season != null)
                  CyberStatPill(
                    label: 'SEASON',
                    value: '${package.season}',
                    color: Cyber.cyan,
                  ),
              ],
            ),
            if (circuit != null) ...[
              const SizedBox(height: 12),
              Text(
                circuit.fullName,
                style: Cyber.body(12, color: Cyber.muted),
              ),
              const SizedBox(height: 12),
              _TrackMap(circuit: circuit, package: package),
              const SizedBox(height: 12),
              Row(
                children: [
                  CyberMiniMetric(
                    label: 'LAPS',
                    value: '${circuit.laps ?? '—'}',
                  ),
                  const SizedBox(width: 10),
                  CyberMiniMetric(
                    label: 'LAP',
                    value: circuit.lengthKm == null
                        ? '—'
                        : '${circuit.lengthKm!.toStringAsFixed(3)} KM',
                  ),
                  const SizedBox(width: 10),
                  CyberMiniMetric(
                    label: 'TURNS',
                    value: '${circuit.turns ?? '—'}',
                  ),
                ],
              ),
              if (!circuit.lapRecord.isEmpty) ...[
                const SizedBox(height: 10),
                _RecordLine(package: package, record: circuit.lapRecord),
              ],
            ],
            if (winner != null && driver != null) ...[
              const SizedBox(height: 12),
              _WinnerPlate(
                package: package,
                entry: winner,
                driver: driver,
                accent: accent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The `viewBox` of ESPN's circuit SVGs. Every marker coordinate below lives in
/// this space, so the tap overlay stays glued to the drawing at any zoom.
const Size _kTrackViewBox = Size(160, 96);

/// Centre of the chequered start/finish block ESPN draws into the circuit SVG
/// (the `Group-6` 3x3 of 1x1 rects, spanning 123.73-126.01 x 78.29-80.57).
///
/// The chequered pattern is the one marker on these diagrams whose meaning is
/// unambiguous. The SVG's other drawn markers — a red disc and two yellow ones —
/// carry no legend, so nothing here labels them. Its `S1`/`S2`/`S3` are text
/// outlines in a separate subtree, NOT segments of the track path: the circuit
/// is one continuous shape, so there is no per-sector geometry to hit-test even
/// if there were sector data to show, and there is none — see
/// docs/data/f1-race-field-inventory.md.
const Offset _kStartFinishMarker = Offset(124.87, 79.43);

/// ESPN's circuit diagram.
///
/// The bytes are fetched here rather than through `SvgPicture.network` so a
/// failure is contained: an offline device, a CDN error or a response that
/// isn't SVG at all would otherwise surface as an unhandled decode error from
/// inside the loader. The map is decoration over numbers that stand on their
/// own, so it degrades to an icon instead. ESPN serves these with
/// `Access-Control-Allow-Origin: *`, so it works on web too.
///
/// Once the bytes are in hand the map can be opened full screen
/// ([F1TrackMapScreen]); the affordance stays hidden until then, so it never
/// promises a view that would open empty.
class _TrackMap extends StatefulWidget {
  const _TrackMap({required this.circuit, required this.package});

  final F1Circuit circuit;
  final F1RacePackage package;

  @override
  State<_TrackMap> createState() => _TrackMapState();
}

class _TrackMapState extends State<_TrackMap> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final href = widget.circuit.trackMap;
    if (href == null) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    try {
      final response = await http.get(Uri.parse(href));
      final body = response.bodyBytes;
      if (response.statusCode != 200 || !_looksLikeSvg(body)) {
        throw const FormatException('not an SVG');
      }
      if (mounted) setState(() => _bytes = body);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Guards against an error page served with a 200 — the decoder throws on
  /// anything that is not markup, and that throw escapes the widget.
  static bool _looksLikeSvg(Uint8List bytes) {
    if (bytes.length < 4) return false;
    final head = String.fromCharCodes(
      bytes.take(math.min(256, bytes.length)),
    ).trimLeft();
    return head.startsWith('<');
  }

  void _expand(Uint8List bytes) {
    HapticFeedback.selectionClick();
    playSound(SoundEffect.uiTap);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => F1TrackMapScreen(package: widget.package, svg: bytes),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final ready = bytes != null && !_failed;
    return Container(
      height: 132,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: Cyber.bg.withValues(alpha: 0.42)),
      child: Stack(
        children: [
          Positioned.fill(
            child: ready
                ? SvgPicture.memory(
                    bytes,
                    fit: BoxFit.contain,
                    placeholderBuilder: (_) => const _TrackMapFallback(),
                    errorBuilder: (_, _, _) => const _TrackMapFallback(),
                  )
                : const _TrackMapFallback(),
          ),
          if (ready)
            Positioned(
              right: 4,
              top: 0,
              child: _ExpandMapButton(onTap: () => _expand(bytes)),
            ),
        ],
      ),
    );
  }
}

/// Opens the circuit full screen. Calm chamfered chrome, no glow — the winner
/// plate is this card's focal element and stays that way.
class _ExpandMapButton extends StatelessWidget {
  const _ExpandMapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Expand circuit map',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClipPath(
          clipper: const HudChamferClipper(bigCut: 8, smallCut: 2),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Cyber.panel.withValues(alpha: 0.9),
              border: Border.all(color: Cyber.line),
            ),
            child: const Icon(
              Icons.open_in_full,
              size: 14,
              color: Cyber.cyan,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-screen circuit map
// ---------------------------------------------------------------------------

/// What the map's readout is currently describing.
enum _TrackFocus { lap, startFinish }

/// The circuit, full screen, pinch-zoomable, with a readout underneath.
///
/// Only two things on this map can be spoken about truthfully, so only two
/// things are tappable: the chequered **start/finish** block ESPN draws, and
/// **the lap** itself (the rest of the map). There is deliberately no
/// per-sector panel — ESPN publishes no sector splits (`.../splits` 404s, and
/// no stat key in the package is sector-scoped), so a sector readout could only
/// have been invented.
class F1TrackMapScreen extends StatefulWidget {
  const F1TrackMapScreen({
    required this.package,
    required this.svg,
    super.key,
  });

  final F1RacePackage package;
  final Uint8List svg;

  @override
  State<F1TrackMapScreen> createState() => _F1TrackMapScreenState();
}

class _F1TrackMapScreenState extends State<F1TrackMapScreen>
    with SingleTickerProviderStateMixin {
  static const double _doubleTapScale = 2.6;

  final TransformationController _view = TransformationController();
  final GlobalKey _viewport = GlobalKey();
  late final AnimationController _zoom;
  Animation<Matrix4>? _zoomTween;
  _TrackFocus _focus = _TrackFocus.lap;

  @override
  void initState() {
    super.initState();
    _zoom = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
      final tween = _zoomTween;
      if (tween != null) _view.value = tween.value;
    });
  }

  @override
  void dispose() {
    _zoom.dispose();
    _view.dispose();
    super.dispose();
  }

  void _select(_TrackFocus focus) {
    if (_focus == focus) return;
    HapticFeedback.selectionClick();
    playSound(SoundEffect.uiTap);
    setState(() => _focus = focus);
  }

  /// Double tap zooms about the point tapped, and again to reset.
  ///
  /// The reporting detector sits inside the viewer, so its local position is in
  /// the already-transformed child space; the zoom matrix has to be built in
  /// viewport space, which is what this resolves the global position against.
  void _handleDoubleTap(TapDownDetails details) {
    final zoomedIn = _view.value.getMaxScaleOnAxis() > 1.4;
    final box = _viewport.currentContext?.findRenderObject() as RenderBox?;
    final point = box == null
        ? details.localPosition
        : box.globalToLocal(details.globalPosition);
    final target = zoomedIn
        ? Matrix4.identity()
        : (Matrix4.identity()
            ..translateByDouble(point.dx, point.dy, 0, 1)
            ..scaleByDouble(
              _doubleTapScale,
              _doubleTapScale,
              _doubleTapScale,
              1,
            )
            ..translateByDouble(-point.dx, -point.dy, 0, 1));
    _zoomTween = Matrix4Tween(begin: _view.value, end: target).animate(
      CurvedAnimation(parent: _zoom, curve: Curves.easeOutCubic),
    );
    _zoom.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final circuit = widget.package.circuit;
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: CyberTextureOverlay()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DetailTopBar(title: circuit?.fullName ?? 'CIRCUIT'),
                  Expanded(
                    child: InteractiveViewer(
                      key: _viewport,
                      transformationController: _view,
                      minScale: 1,
                      maxScale: 6,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: _kTrackViewBox.aspectRatio,
                          child: _TrackCanvas(
                            svg: widget.svg,
                            view: _view,
                            focus: _focus,
                            onLap: () => _select(_TrackFocus.lap),
                            onDoubleTapDown: _handleDoubleTap,
                            onStartFinish: () =>
                                _select(_TrackFocus.startFinish),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _focus == _TrackFocus.startFinish
                        ? _StartFinishReadout(
                            key: const ValueKey('motorsport-map-startfinish'),
                            package: widget.package,
                          )
                        : _LapReadout(
                            key: const ValueKey('motorsport-map-lap'),
                            package: widget.package,
                          ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The drawing plus its one tappable marker, laid out in `viewBox` units so the
/// marker sits exactly where ESPN drew the chequered flag.
class _TrackCanvas extends StatelessWidget {
  const _TrackCanvas({
    required this.svg,
    required this.view,
    required this.focus,
    required this.onLap,
    required this.onDoubleTapDown,
    required this.onStartFinish,
  });

  final Uint8List svg;
  final TransformationController view;
  final _TrackFocus focus;
  final VoidCallback onLap;
  final GestureTapDownCallback onDoubleTapDown;
  final VoidCallback onStartFinish;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sx = constraints.maxWidth / _kTrackViewBox.width;
        final sy = constraints.maxHeight / _kTrackViewBox.height;
        const hit = 40.0;
        return Stack(
          children: [
            // Anywhere on the drawing that is not the marker is "the lap".
            // Both gestures live on one detector so they share an arena entry
            // — split across two, the tap wins and the double tap never fires.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onLap,
                onDoubleTapDown: onDoubleTapDown,
                onDoubleTap: () {},
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: SvgPicture.memory(
                  svg,
                  // The box already matches the viewBox, so fill == contain
                  // and the marker maths below stays exact.
                  fit: BoxFit.fill,
                  placeholderBuilder: (_) => const _TrackMapFallback(),
                  errorBuilder: (_, _, _) => const _TrackMapFallback(),
                ),
              ),
            ),
            Positioned(
              left: (_kStartFinishMarker.dx * sx) - (hit / 2),
              top: (_kStartFinishMarker.dy * sy) - (hit / 2),
              width: hit,
              height: hit,
              child: AnimatedBuilder(
                animation: view,
                builder: (context, child) => Transform.scale(
                  // Hold the marker at a constant on-screen size as the map
                  // zooms, so it stays tappable without swallowing the track.
                  scale: 1 / view.value.getMaxScaleOnAxis(),
                  child: child,
                ),
                child: _StartFinishMarker(
                  selected: focus == _TrackFocus.startFinish,
                  onTap: onStartFinish,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The one tappable point on the map. Selected is the single glowing element
/// on this screen.
class _StartFinishMarker extends StatelessWidget {
  const _StartFinishMarker({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Start finish line',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: selected ? 26 : 22,
            height: selected ? 26 : 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Cyber.bg.withValues(alpha: 0.86),
              border: Border.all(
                color: selected ? Cyber.cyan : Cyber.muted,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected ? Cyber.glow(Cyber.cyan) : null,
            ),
            child: Icon(
              Icons.sports_score,
              size: selected ? 14 : 12,
              color: selected ? Cyber.cyan : Cyber.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// The lap itself: the circuit facts ESPN publishes, including the three the
/// card has no room for (race distance, direction, year established).
class _LapReadout extends StatelessWidget {
  const _LapReadout({required this.package, super.key});

  final F1RacePackage package;

  @override
  Widget build(BuildContext context) {
    final circuit = package.circuit;
    if (circuit == null) return const SizedBox.shrink();
    final record = circuit.lapRecord;
    final holder = record.driverId == null
        ? null
        : package.driver(record.driverId!);
    return _MapReadoutShell(
      label: 'THE LAP',
      caption: 'TAP THE CHEQUERED MARKER FOR THE START/FINISH LINE',
      children: [
        Row(
          children: [
            CyberMiniMetric(label: 'LAPS', value: '${circuit.laps ?? '—'}'),
            const SizedBox(width: 10),
            CyberMiniMetric(
              label: 'LAP',
              value: circuit.lengthKm == null
                  ? '—'
                  : '${circuit.lengthKm!.toStringAsFixed(3)} KM',
            ),
            const SizedBox(width: 10),
            CyberMiniMetric(label: 'TURNS', value: '${circuit.turns ?? '—'}'),
          ],
        ),
        if (circuit.distanceKm != null)
          _MapFactRow(
            label: 'RACE DISTANCE',
            value: '${circuit.distanceKm!.toStringAsFixed(2)} KM',
          ),
        if (circuit.direction != null)
          _MapFactRow(
            label: 'DIRECTION',
            value: circuit.direction!.toUpperCase(),
          ),
        if (circuit.established != null)
          _MapFactRow(label: 'ESTABLISHED', value: '${circuit.established}'),
        if (!record.isEmpty)
          _MapFactRow(
            label: 'LAP RECORD',
            value: record.time ?? '—',
            detail: [
              holder?.displayName,
              if (record.year != null) '${record.year}',
            ].whereType<String>().join(' · '),
            accent: Cyber.cyan,
          ),
      ],
    );
  }
}

/// The start/finish line: who lined up on it, who crossed it first, and who
/// gained the most between the two.
class _StartFinishReadout extends StatelessWidget {
  const _StartFinishReadout({required this.package, super.key});

  final F1RacePackage package;

  @override
  Widget build(BuildContext context) {
    final entries = package.race?.classification ?? const [];
    final winner = package.winner;
    final pole = entries.where((e) => e.grid == 1).firstOrNull;
    final movers =
        entries.where((e) => e.grid != null).toList(growable: false)
          ..sort(
            (a, b) => (b.grid! - b.position).compareTo(a.grid! - a.position),
          );
    final climber = movers.firstOrNull;
    final livery = _Livery.of(package);

    String named(F1ClassificationEntry? e) =>
        e == null ? '—' : (package.driver(e.driverId)?.displayName ?? '—');

    return _MapReadoutShell(
      label: 'START / FINISH',
      caption: 'TAP THE MAP TO GO BACK TO THE LAP',
      children: [
        if (pole != null)
          _MapFactRow(
            label: 'POLE',
            value: named(pole),
            detail: pole.constructorName,
            accent: livery.colorFor(pole.driverId),
          ),
        if (winner != null)
          _MapFactRow(
            label: 'WINNER',
            value: named(winner),
            detail: winner.grid == null
                ? winner.constructorName
                : 'FROM P${winner.grid}',
            accent: livery.colorFor(winner.driverId),
          ),
        if (climber != null && climber.grid! - climber.position > 0)
          _MapFactRow(
            label: 'BIGGEST GAIN',
            value: named(climber),
            detail:
                'P${climber.grid} → P${climber.position} · '
                '+${climber.grid! - climber.position}',
            accent: livery.colorFor(climber.driverId),
          ),
      ],
    );
  }
}

/// Shared frame for the two map readouts.
class _MapReadoutShell extends StatelessWidget {
  const _MapReadoutShell({
    required this.label,
    required this.caption,
    required this.children,
  });

  final String label;
  final String caption;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Cyber.label(10, color: Cyber.cyan, letterSpacing: 1.6),
            ),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: Cyber.line)),
          ],
        ),
        const SizedBox(height: 8),
        for (final child in children) ...[
          child,
          const SizedBox(height: 6),
        ],
        Text(
          caption,
          style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1.1),
        ),
      ],
    );
  }
}

class _MapFactRow extends StatelessWidget {
  const _MapFactRow({
    required this.label,
    required this.value,
    this.detail,
    this.accent,
  });

  final String label;
  final String value;
  final String? detail;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    return StatsRowShell(
      child: Row(
        children: [
          if (accent != null) ...[
            Container(width: 3, height: 18, color: accent),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.2),
          ),
          const Spacer(),
          if (detail != null && detail.isNotEmpty) ...[
            Flexible(
              child: Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Cyber.body(11, color: Cyber.muted),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            value,
            style: Cyber.display(12, color: accent ?? Colors.white),
          ),
        ],
      ),
    );
  }
}

class _TrackMapFallback extends StatelessWidget {
  const _TrackMapFallback();

  @override
  Widget build(BuildContext context) => Center(
    child: Icon(
      Icons.route_outlined,
      color: Cyber.muted.withValues(alpha: 0.5),
      size: 30,
    ),
  );
}

class _RecordLine extends StatelessWidget {
  const _RecordLine({required this.package, required this.record});

  final F1RacePackage package;
  final F1LapRecord record;

  @override
  Widget build(BuildContext context) {
    final holder = record.driverId == null
        ? null
        : package.driver(record.driverId!);
    return StatsRowShell(
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 14, color: Cyber.muted),
          const SizedBox(width: 8),
          Text(
            'LAP RECORD',
            style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.2),
          ),
          const Spacer(),
          if (holder != null || record.year != null) ...[
            Flexible(
              child: Text(
                [
                  holder?.displayName,
                  if (record.year != null) '${record.year}',
                ].whereType<String>().join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.body(11, color: Cyber.muted),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Text(
            record.time ?? '—',
            style: Cyber.display(
              13,
              color: Cyber.cyan,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

class _WinnerPlate extends StatelessWidget {
  const _WinnerPlate({
    required this.package,
    required this.entry,
    required this.driver,
    required this.accent,
  });

  final F1RacePackage package;
  final F1ClassificationEntry entry;
  final F1Driver driver;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final gained = entry.positionsGained;
    return StatsRowShell(
      accent: Cyber.gold,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(width: 4, height: 38, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WINNER',
                  style: Cyber.label(9, color: Cyber.gold, letterSpacing: 1.4),
                ),
                const SizedBox(height: 5),
                Text(
                  driver.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.body(15, weight: FontWeight.w800),
                ),
                if (entry.constructorName != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.constructorName!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.label(9, color: Cyber.muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.display('totalTime') ?? '—',
                style: Cyber.display(
                  14,
                  color: Cyber.gold,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              if (gained != null && gained > 0) ...[
                const SizedBox(height: 5),
                Text(
                  'FROM P${entry.grid} · +$gained',
                  style: Cyber.label(9, color: Cyber.success),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// How the lead lap spread out behind the winner.
///
/// Only cars still on the lead lap are plotted. A lapped or retired runner has
/// no time gap in the feed at all, and standing one in by converting laps to
/// seconds would draw a twenty-minute deficit that never happened — the earlier
/// version of this chart did exactly that and topped out at a fictional 1208s.
/// The classification below lists everybody.
class _RaceGapChart extends StatelessWidget {
  const _RaceGapChart({required this.package, required this.race});

  final F1RacePackage package;
  final F1Session race;

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final entry in race.classification)
        if (entry.position == 1 || entry.stat('behindTime') != null) entry,
    ];
    if (entries.length < 2) {
      return const CyberNoDataState(
        icon: Icons.timeline,
        title: 'No measured gaps',
        message: 'No car finished on the lead lap with a recorded time gap.',
        accent: Cyber.cyan,
      );
    }

    final codes = [
      for (final entry in entries) package.driver(entry.driverId)?.code ?? '—',
    ];
    final lapped = race.classification.length - entries.length;

    return _RevealChart(
      builder: (progress) => CyberChartPanel(
        chartKey: const ValueKey('motorsport-gap-chart'),
        title: 'GAP TO LEADER',
        caption: '${entries.length} ON THE LEAD LAP',
        height: 190,
        revealProgress: progress,
        yAxisLabels: true,
        gridDivisions: 4,
        yAxisFormatter: (value) => '+${value.toStringAsFixed(0)}s',
        xAxisLabels: [codes.first, codes[codes.length ~/ 2], codes.last],
        contextLabelAt: (index) =>
            index < codes.length ? codes[index] : '—',
        markerSound: false,
        series: [
          ChartSeries(
            label: lapped > 0 ? 'GAP · $lapped LAPPED' : 'GAP',
            color: Cyber.cyan,
            fill: true,
            values: [
              for (final entry in entries)
                (entry.value('behindTime') ?? 0) / 1000,
            ],
            readout: (value, index) => entries[index].position == 1
                ? 'LEADER'
                : entries[index].display('behindTime') ?? '—',
          ),
        ],
      ),
    );
  }
}

class _ClassificationList extends StatelessWidget {
  const _ClassificationList({required this.package, required this.race});

  final F1RacePackage package;
  final F1Session race;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in race.classification) ...[
          if (entry.position > 1) const SizedBox(height: 6),
          _ClassificationRow(package: package, entry: entry),
        ],
      ],
    );
  }
}

class _ClassificationRow extends StatelessWidget {
  const _ClassificationRow({required this.package, required this.entry});

  final F1RacePackage package;
  final F1ClassificationEntry entry;

  @override
  Widget build(BuildContext context) {
    final driver = package.driver(entry.driverId);
    final teamColor = _entryColor(package, entry) ?? Cyber.muted;
    final podium = entry.position <= 3;
    final positionColor = entry.position == 1
        ? Cyber.gold
        : (podium ? Cyber.cyan : Cyber.muted);
    final gained = entry.positionsGained;

    // A retired car has no total time and no gap; the honest readout is its
    // status and how far it got.
    final trailing = entry.retired
        ? '${entry.statusLaps ?? 0} LAPS'
        : (entry.position == 1
              ? entry.display('totalTime') ?? '—'
              : entry.display('behindTime') ??
                    (entry.value('behindLaps') != null
                        ? '+${entry.value('behindLaps')!.round()} LAP'
                        : '—'));

    return StatsRowShell(
      accent: entry.position == 1 ? Cyber.gold : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              'P${entry.position}',
              style: Cyber.display(
                13,
                color: positionColor,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          Container(width: 3, height: 26, color: teamColor),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver?.displayName ?? entry.driverId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.body(
                    13,
                    weight: podium ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (entry.constructorName != null) entry.constructorName!,
                    if (entry.grid != null) 'GRID P${entry.grid}',
                  ].join(' · ').toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1),
                ),
              ],
            ),
          ),
          if (gained != null && gained != 0) ...[
            const SizedBox(width: 8),
            Text(
              gained > 0 ? '+$gained' : '$gained',
              style: Cyber.label(
                10,
                color: gained > 0 ? Cyber.success : Cyber.danger,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          const SizedBox(width: 10),
          SizedBox(
            width: 74,
            child: Text(
              trailing,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.display(
                11,
                color: entry.retired
                    ? Cyber.danger
                    : (entry.position == 1 ? Cyber.gold : Cyber.muted),
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WEEKEND
// ---------------------------------------------------------------------------

class _WeekendSection extends StatelessWidget {
  const _WeekendSection({required this.package});

  final F1RacePackage package;

  @override
  Widget build(BuildContext context) {
    final track = _WeekendTrack.build(package);

    return ListView(
      key: const ValueKey('motorsport-stats-weekend'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        const CyberSectionHeading(
          key: ValueKey('motorsport-position-track-heading'),
          label: 'WEEKEND POSITION TRACK',
        ),
        const SizedBox(height: 10),
        if (track == null)
          const CyberNoDataState(
            icon: Icons.show_chart,
            title: 'Weekend incomplete',
            message:
                'The position track needs every session from first practice to '
                'the flag before it can plot a line.',
            accent: Cyber.cyan,
          )
        else ...[
          _PositionTrackChart(track: track),
          const SizedBox(height: 8),
          Text(
            'Position at each stage of the weekend. ESPN publishes no '
            'lap-by-lap data for F1, so this tracks the sessions themselves — '
            'no lap positions are inferred.',
            style: Cyber.body(11, color: Cyber.muted),
          ),
        ],
        const SizedBox(height: 18),
        const CyberSectionHeading(label: 'PACE EVOLUTION'),
        const SizedBox(height: 10),
        _PaceEvolutionChart(package: package),
      ],
    );
  }
}

/// The six stops of a race weekend for the drivers who completed all of them.
///
/// Reserves who only ran FP1 are excluded rather than interpolated — inventing
/// a grid slot for a driver who never started is exactly the kind of plausible
/// fiction this data does not support.
class _WeekendTrack {
  const _WeekendTrack({
    required this.stages,
    required this.fieldSize,
    required this.rows,
  });

  final List<String> stages;
  final int fieldSize;
  final List<_WeekendTrackRow> rows;

  static _WeekendTrack? build(F1RacePackage package) {
    final race = package.race;
    if (race == null || race.classification.isEmpty) return null;
    final timed = package.timedSessions;
    if (timed.isEmpty) return null;

    final stages = <String>[
      for (final session in timed) session.abbreviation.toUpperCase(),
      'GRID',
      'FIN',
    ];

    final livery = _Livery.of(package);
    final rows = <_WeekendTrackRow>[];
    // Top finishers only: 22 lines is unreadable, and the story of a race is at
    // the front. Same call the market odds chart makes with its top outcomes.
    for (final entry in race.classification.take(6)) {
      final positions = <double>[];
      var complete = true;
      for (final session in timed) {
        final seen = session.entryFor(entry.driverId);
        if (seen == null) {
          complete = false;
          break;
        }
        positions.add(seen.position.toDouble());
      }
      final grid = entry.grid;
      if (!complete || grid == null) continue;
      positions
        ..add(grid.toDouble())
        ..add(entry.position.toDouble());
      rows.add(
        _WeekendTrackRow(
          driverId: entry.driverId,
          code: package.driver(entry.driverId)?.code ?? '—',
          color: livery.colorFor(entry.driverId),
          positions: positions,
          winner: entry.position == 1,
        ),
      );
    }
    if (rows.isEmpty) return null;

    final fieldSize = race.classification.length;
    return _WeekendTrack(stages: stages, fieldSize: fieldSize, rows: rows);
  }
}

class _WeekendTrackRow {
  const _WeekendTrackRow({
    required this.driverId,
    required this.code,
    required this.color,
    required this.positions,
    required this.winner,
  });

  final String driverId;
  final String code;
  final Color color;
  final List<double> positions;
  final bool winner;
}

/// The focal chart. Positions are plotted inverted so P1 rides the top of the
/// plot the way a timing screen reads.
class _PositionTrackChart extends StatelessWidget {
  const _PositionTrackChart({required this.track});

  final _WeekendTrack track;

  @override
  Widget build(BuildContext context) {
    final top = track.fieldSize + 1;
    double invert(double position) => top - position;

    // The biggest climb from the grid is the story of the race, so it gets the
    // one focal marker on the screen.
    _WeekendTrackRow? climber;
    var bestClimb = 0.0;
    for (final row in track.rows) {
      final climb = row.positions[row.positions.length - 2] - row.positions.last;
      if (climb > bestClimb) {
        bestClimb = climb;
        climber = row;
      }
    }

    return _RevealChart(
      duration: const Duration(milliseconds: 1100),
      builder: (progress) => CyberChartPanel(
        chartKey: const ValueKey('motorsport-position-track-chart'),
        title: 'WEEKEND POSITION TRACK',
        // The climb is the headline, and a marker label pinned at the right
        // edge would run off the plot.
        caption: climber != null && bestClimb > 0
            ? '${climber.code} +${bestClimb.round()} FROM THE GRID'
            : '${track.rows.length} DRIVERS',
        height: 250,
        bloom: true,
        // The only glow on the screen, and only while the sweep runs.
        glow: progress < 1,
        revealProgress: progress,
        yAxisLabels: true,
        gridDivisions: 4,
        yAxisFormatter: (value) => 'P${(top - value).round().clamp(1, top)}',
        xAxisLabels: track.stages,
        contextLabelAt: (index) =>
            index < track.stages.length ? track.stages[index] : '',
        markers: [
          if (climber != null && bestClimb > 0)
            ChartMarker(
              fraction: 1,
              color: Cyber.gold,
              shape: ChartMarkerShape.diamond,
              value: invert(climber.positions.last),
              focal: true,
            ),
        ],
        series: [
          for (final row in track.rows)
            ChartSeries(
              label: row.code,
              color: row.color,
              fill: row.winner,
              strokeWidth: row.winner ? 2.8 : 2,
              values: [for (final p in row.positions) invert(p)],
              readout: (value, index) => 'P${row.positions[index].round()}',
            ),
        ],
      ),
    );
  }
}

/// Best lap per driver across the timed sessions — who found time overnight.
class _PaceEvolutionChart extends StatelessWidget {
  const _PaceEvolutionChart({required this.package});

  final F1RacePackage package;

  @override
  Widget build(BuildContext context) {
    final timed = package.timedSessions;
    final race = package.race;
    if (timed.length < 2 || race == null) {
      return const CyberNoDataState(
        icon: Icons.speed_outlined,
        title: 'No timed sessions',
        message: 'Practice and qualifying lap times land here once they run.',
        accent: Cyber.cyan,
      );
    }

    final stages = [
      for (final session in timed) session.abbreviation.toUpperCase(),
    ];
    final livery = _Livery.of(package);
    final series = <ChartSeries>[];
    for (final entry in race.classification.take(5)) {
      final values = <double>[];
      var complete = true;
      for (final session in timed) {
        final lap = session.entryFor(entry.driverId)?.value('totalTime');
        if (lap == null) {
          complete = false;
          break;
        }
        values.add(lap);
      }
      if (!complete) continue;
      series.add(
        ChartSeries(
          label: package.driver(entry.driverId)?.code ?? '—',
          color: livery.colorFor(entry.driverId),
          values: values,
          strokeWidth: 2,
          readout: (value, index) => _lapTime(value),
        ),
      );
    }

    if (series.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.speed_outlined,
        title: 'No comparable laps',
        message: 'No driver set a time in every session of this weekend.',
        accent: Cyber.cyan,
      );
    }

    return _RevealChart(
      builder: (progress) => CyberChartPanel(
        chartKey: const ValueKey('motorsport-pace-chart'),
        title: 'PACE EVOLUTION',
        caption: 'BEST LAP',
        height: 200,
        revealProgress: progress,
        yAxisLabels: true,
        gridDivisions: 3,
        yAxisFormatter: _lapTime,
        xAxisLabels: stages,
        contextLabelAt: (index) => index < stages.length ? stages[index] : '',
        markerSound: false,
        series: series,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QUALIFYING
// ---------------------------------------------------------------------------

class _QualifyingSection extends StatelessWidget {
  const _QualifyingSection({required this.package});

  final F1RacePackage package;

  @override
  Widget build(BuildContext context) {
    final qualifying = package.qualifying;

    return ListView(
      key: const ValueKey('motorsport-stats-qualifying'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        const CyberSectionHeading(
          key: ValueKey('motorsport-qualifying-heading'),
          label: 'QUALIFYING ELIMINATION',
        ),
        const SizedBox(height: 10),
        if (qualifying == null || qualifying.classification.isEmpty)
          const CyberNoDataState(
            icon: Icons.timer_outlined,
            title: 'Qualifying pending',
            message:
                'Q1, Q2 and Q3 lap times drop here once the session runs.',
            accent: Cyber.gold,
            spark: Icons.electric_bolt,
          )
        else ...[
          _QualifyingChart(package: package, qualifying: qualifying),
          const SizedBox(height: 8),
          Text(
            'A line stops at the segment its driver was knocked out in — the '
            'feed records no time beyond the cut, so none is drawn.',
            style: Cyber.body(11, color: Cyber.muted),
          ),
        ],
        const SizedBox(height: 18),
        const CyberSectionHeading(label: 'GRID VS FINISH'),
        const SizedBox(height: 10),
        _GridDeltaBoard(package: package),
      ],
    );
  }
}

/// Q1 → Q2 → Q3 for the drivers who reached Q3, with the two cuts marked. The
/// package omits a segment a driver never reached rather than storing `0.000`,
/// so an eliminated line simply ends.
class _QualifyingChart extends StatelessWidget {
  const _QualifyingChart({required this.package, required this.qualifying});

  final F1RacePackage package;
  final F1Session qualifying;

  static const _segments = ['qual1TimeMS', 'qual2TimeMS', 'qual3TimeMS'];

  @override
  Widget build(BuildContext context) {
    final entries = qualifying.classification;
    final reachedQ2 = entries.where((e) => e.value('qual2TimeMS') != null).length;
    final reachedQ3 = entries.where((e) => e.value('qual3TimeMS') != null).length;

    final livery = _Livery.of(package);
    final series = <ChartSeries>[];
    for (final entry in entries.take(6)) {
      final values = <double>[];
      for (final segment in _segments) {
        final lap = entry.value(segment);
        if (lap == null) break;
        values.add(lap);
      }
      if (values.length < 2) continue;
      series.add(
        ChartSeries(
          label: package.driver(entry.driverId)?.code ?? '—',
          color: livery.colorFor(entry.driverId),
          values: values,
          strokeWidth: entry.position == 1 ? 2.8 : 2,
          fill: entry.position == 1,
          readout: (value, index) => _lapTime(value),
        ),
      );
    }

    if (series.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.timer_outlined,
        title: 'No segment times',
        message: 'This session records a grid order but no Q1/Q2/Q3 splits.',
        accent: Cyber.gold,
      );
    }

    return _RevealChart(
      builder: (progress) => CyberChartPanel(
        chartKey: const ValueKey('motorsport-qualifying-chart'),
        title: 'QUALIFYING ELIMINATION',
        // The cut counts ride the caption, not the markers: an edge-pinned
        // ChartMarker draws its shape but never its label (only markers placed
        // on the trace carry text), so a label here would be invisible.
        caption:
            '${entries.length - reachedQ2} OUT IN Q1 · '
            '${reachedQ2 - reachedQ3} IN Q2',
        height: 210,
        revealProgress: progress,
        yAxisLabels: true,
        gridDivisions: 3,
        yAxisFormatter: _lapTime,
        xAxisLabels: const ['Q1', 'Q2', 'Q3'],
        contextLabelAt: (index) => const ['Q1', 'Q2', 'Q3'][index.clamp(0, 2)],
        markers: [
          const ChartMarker(
            fraction: 0,
            color: Cyber.danger,
            shape: ChartMarkerShape.ring,
          ),
          const ChartMarker(
            fraction: 0.5,
            color: Cyber.danger,
            shape: ChartMarkerShape.ring,
          ),
        ],
        series: series,
      ),
    );
  }
}

/// Positions gained from the grid, as signed bars either side of a centre line.
///
/// Deliberately not a line chart: each driver is a separate category, so a
/// polyline between them would imply a trend across drivers that does not
/// exist. Bars compare magnitudes, which is the actual question here.
class _GridDeltaBoard extends StatelessWidget {
  const _GridDeltaBoard({required this.package});

  final F1RacePackage package;

  @override
  Widget build(BuildContext context) {
    final race = package.race;
    final entries = [
      for (final entry
          in race?.classification ?? const <F1ClassificationEntry>[])
        if (entry.positionsGained != null) entry,
    ];
    if (entries.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.swap_vert,
        title: 'No starting grid',
        message:
            'Positions gained needs both a grid slot and a finishing place.',
        accent: Cyber.cyan,
      );
    }

    final ranked = [...entries]
      ..sort(
        (a, b) => b.positionsGained!.compareTo(a.positionsGained!),
      );
    final extent = ranked
        .map((e) => e.positionsGained!.abs())
        .fold<int>(1, math.max);
    final livery = _Livery.of(package);

    return Container(
      key: const ValueKey('motorsport-grid-delta-board'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Cyber.chartSurface,
        border: Border.all(color: Cyber.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'GRID VS FINISH',
                style: Cyber.label(10, color: Cyber.cyan, letterSpacing: 1.4),
              ),
              const Spacer(),
              Text(
                'POSITIONS GAINED',
                style: Cyber.label(9, color: Cyber.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final entry in ranked) ...[
            _GridDeltaRow(
              code: package.driver(entry.driverId)?.code ?? '—',
              gained: entry.positionsGained!,
              extent: extent,
              color: livery.colorFor(entry.driverId),
            ),
            const SizedBox(height: 5),
          ],
        ],
      ),
    );
  }
}

class _GridDeltaRow extends StatelessWidget {
  const _GridDeltaRow({
    required this.code,
    required this.gained,
    required this.extent,
    required this.color,
  });

  final String code;
  final int gained;
  final int extent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final share = (gained.abs() / extent).clamp(0.0, 1.0);
    final tone = gained > 0
        ? Cyber.success
        : (gained < 0 ? Cyber.danger : Cyber.muted);

    return Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(
            code,
            style: Cyber.label(
              10,
              color: Colors.white,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Container(width: 3, height: 14, color: color),
        const SizedBox(width: 6),
        // Two mirrored halves so every bar grows away from one shared centre.
        Expanded(
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: gained < 0 ? share : 0,
                      child: Container(height: 8, color: tone),
                    ),
                  ),
                ),
                Container(width: 1, height: 14, color: Cyber.line),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: gained > 0 ? share : 0,
                      child: Container(height: 8, color: tone),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 30,
          child: Text(
            gained == 0 ? '0' : (gained > 0 ? '+$gained' : '$gained'),
            textAlign: TextAlign.end,
            style: Cyber.label(
              10,
              color: tone,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Sweeps a chart in on first build. Reused by every chart here so the section
/// lands as a beat rather than appearing fully drawn.
class _RevealChart extends StatefulWidget {
  const _RevealChart({
    required this.builder,
    this.duration = const Duration(milliseconds: 900),
  });

  final Widget Function(double progress) builder;
  final Duration duration;

  @override
  State<_RevealChart> createState() => _RevealChartState();
}

class _RevealChartState extends State<_RevealChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  late final Animation<double> _reveal = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _reveal,
    builder: (context, _) => widget.builder(_reveal.value),
  );
}

/// Milliseconds to `1:22.612`, or `58.204` under a minute.
String _lapTime(double milliseconds) {
  if (milliseconds <= 0) return '—';
  final total = milliseconds.round();
  final minutes = total ~/ 60000;
  final seconds = (total % 60000) / 1000;
  final secondsText = seconds.toStringAsFixed(3);
  if (minutes == 0) return secondsText;
  return '$minutes:${seconds < 10 ? '0' : ''}$secondsText';
}

/// Per-driver plot colours.
///
/// ESPN publishes no constructor logos, so livery colour is the only team
/// identity available — but two team-mates share one livery, which makes their
/// lines indistinguishable on a chart. The second driver of each team is
/// lightened so a pair reads as "same team, different car" rather than as one
/// line doubling back.
class _Livery {
  const _Livery(this._byDriver);

  factory _Livery.of(F1RacePackage package) {
    final byDriver = <String, Color>{};
    final seenPerTeam = <String, int>{};
    // Race order first so the higher-placed team-mate keeps the pure livery.
    final ordered = <F1ClassificationEntry>[
      ...?package.race?.classification,
      for (final session in package.sessions) ...session.classification,
    ];
    for (final entry in ordered) {
      if (byDriver.containsKey(entry.driverId)) continue;
      final base = _entryColor(package, entry);
      if (base == null) continue;
      final team = entry.constructorName ?? entry.driverId;
      final ordinal = seenPerTeam.update(
        team,
        (value) => value + 1,
        ifAbsent: () => 0,
      );
      byDriver[entry.driverId] = ordinal == 0
          ? base
          : Color.lerp(base, Colors.white, 0.42 + 0.12 * (ordinal - 1)) ?? base;
    }
    return _Livery(byDriver);
  }

  final Map<String, Color> _byDriver;

  Color colorFor(String driverId) => _byDriver[driverId] ?? Cyber.cyan;
}

/// Raw livery colour for a classification row, before team-mate separation.
Color? _entryColor(F1RacePackage package, F1ClassificationEntry? entry) {
  if (entry == null) return null;
  final direct = _hexColor(entry.teamColor);
  if (direct != null) return direct;
  final driver = package.driver(entry.driverId);
  return _hexColor(package.constructorFor(driver?.constructorId)?.color);
}

Color? _hexColor(String? raw) {
  if (raw == null) return null;
  final hex = raw.replaceAll('#', '').trim();
  if (hex.length != 6) return null;
  final value = int.tryParse(hex, radix: 16);
  if (value == null) return null;
  final color = Color(0xFF000000 | value);
  // Williams runs a white livery, which disappears against the plot's white
  // playhead and legend text; nudge anything near-white toward the panel accent.
  return _luminanceSafe(color);
}

Color _luminanceSafe(Color color) {
  final luminance = color.computeLuminance();
  if (luminance > 0.86) {
    return Color.lerp(color, Cyber.cyan, 0.35) ?? color;
  }
  if (luminance < 0.04) {
    return Color.lerp(color, Cyber.muted, 0.5) ?? color;
  }
  return color;
}

// ---------------------------------------------------------------------------
// Fallback — races with no bundled package
// ---------------------------------------------------------------------------

/// The pre-package F1 view: ESPN's scoreboard strings, printed as they arrive.
///
/// Kept for every race the bundled package does not cover. These panels carry
/// display strings (`"1. Verstappen · Red Bull (1:20.901)"`) rather than parsed
/// values, which is exactly why they cannot be charted.
class F1ScoreboardFallback extends StatelessWidget {
  const F1ScoreboardFallback({required this.match, super.key});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final sessions = f1NonQualifyingSessions(match.f1Sessions);
    final standings = match.f1DriverStandings ?? const <String>[];

    if (sessions.isEmpty && standings.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.sports_score_outlined,
        title: 'Weekend not started',
        message:
            'Session results and championship standings appear here once the '
            'weekend gets under way.',
        accent: Cyber.cyan,
        spark: Icons.flag_outlined,
      );
    }

    return ListView(
      key: const ValueKey('motorsport-stats-fallback'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        if (sessions.isNotEmpty) ...[
          const CyberSectionHeading(label: 'SESSION RESULTS'),
          const SizedBox(height: 10),
          _SessionResultsPanel(sessions: sessions),
        ],
        if (standings.isNotEmpty) ...[
          if (sessions.isNotEmpty) const SizedBox(height: 18),
          const CyberSectionHeading(label: 'DRIVER STANDINGS'),
          const SizedBox(height: 10),
          _DriverStandingsPanel(standings: standings),
        ],
      ],
    );
  }
}

class _SessionResultsPanel extends StatelessWidget {
  const _SessionResultsPanel({required this.sessions});

  final List<F1SessionResult> sessions;

  @override
  Widget build(BuildContext context) {
    return StatsRowShell(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var s = 0; s < sessions.length; s++) ...[
            if (s > 0) ...[
              const SizedBox(height: 10),
              Divider(
                height: 1,
                thickness: 1,
                color: Cyber.line.withValues(alpha: 0.1),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              sessions[s].name.toUpperCase(),
              style: Cyber.label(11, color: Cyber.cyan, letterSpacing: 1.2),
            ),
            const SizedBox(height: 6),
            if (sessions[s].results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  'Not yet run.',
                  style: Cyber.body(12, color: Cyber.muted),
                ),
              )
            else
              for (final result in sessions[s].results)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    result,
                    style: Cyber.body(13, color: Colors.white),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _DriverStandingsPanel extends StatelessWidget {
  const _DriverStandingsPanel({required this.standings});

  final List<String> standings;

  @override
  Widget build(BuildContext context) {
    return StatsRowShell(
      accent: Cyber.gold,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < standings.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: Cyber.line.withValues(alpha: 0.1),
              ),
            SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${i + 1}',
                        style:
                            Cyber.display(
                              14,
                              color: i < 3 ? Cyber.gold : Cyber.muted,
                            ).copyWith(
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        standings[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.body(
                          14,
                          weight: i < 3 ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// F1 LINEUP tab — ESPN qualifying order as the starting grid
// ---------------------------------------------------------------------------

/// Public because `match_detail_screen.dart` still routes the LINEUP tab here.
class F1QualifyingLineupView extends StatelessWidget {
  const F1QualifyingLineupView({required this.match, super.key});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final sessions = f1QualifyingSessions(match.f1Sessions);
    if (sessions.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.grid_view_outlined,
        title: 'Grid not set',
        message:
            'Qualifying results will lock the starting grid here once the session runs.',
        accent: Cyber.cyan,
        spark: Icons.flag_outlined,
      );
    }

    final hasAnyResults = sessions.any((s) => s.results.isNotEmpty);
    if (!hasAnyResults) {
      return const CyberNoDataState(
        icon: Icons.timer_outlined,
        title: 'Qualifying pending',
        message:
            'The session is on the schedule — grid order drops here when times are in.',
        accent: Cyber.gold,
        spark: Icons.electric_bolt,
      );
    }

    return ListView(
      key: const ValueKey('f1-qualifying-lineup'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        for (var s = 0; s < sessions.length; s++) ...[
          if (s > 0) const SizedBox(height: 14),
          _F1QualifyingGridPanel(session: sessions[s]),
        ],
      ],
    );
  }
}

class _F1QualifyingGridPanel extends StatelessWidget {
  const _F1QualifyingGridPanel({required this.session});

  final F1SessionResult session;

  @override
  Widget build(BuildContext context) {
    final isSprint = session.isSprintQualifying;
    final title = isSprint ? 'SPRINT QUALIFYING' : 'STARTING GRID';
    final accent = isSprint ? Cyber.magenta : Cyber.cyan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CyberSectionHeading(label: title),
        const SizedBox(height: 10),
        StatsRowShell(
          accent: accent,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (session.results.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Text(
                    'Not yet run.',
                    style: Cyber.body(13, color: Cyber.muted),
                  ),
                )
              else
                for (var i = 0; i < session.results.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: Cyber.line.withValues(alpha: 0.1),
                    ),
                  _F1GridRow(
                    entry: session.results[i],
                    index: i,
                    isPole: i == 0 && !isSprint,
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _F1GridRow extends StatelessWidget {
  const _F1GridRow({
    required this.entry,
    required this.index,
    required this.isPole,
  });

  final String entry;
  final int index;
  final bool isPole;

  @override
  Widget build(BuildContext context) {
    final parsed = parseF1ResultEntry(entry);
    final posColor = isPole
        ? Cyber.gold
        : (index < 3 ? Cyber.cyan : Cyber.muted);
    final nameWeight = isPole || index < 3 ? FontWeight.w800 : FontWeight.w600;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: isPole
          ? BoxDecoration(
              color: Color.alphaBlend(
                Cyber.gold.withValues(alpha: 0.08),
                Cyber.panel,
              ),
            )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              'P${parsed.position ?? (index + 1)}',
              style: Cyber.display(
                13,
                color: posColor,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parsed.driver,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.body(14, weight: nameWeight),
                ),
                if (parsed.constructor != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    parsed.constructor!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.label(
                      9,
                      color: Cyber.muted,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isPole) ...[
            const SizedBox(width: 8),
            Text(
              'POLE',
              style: Cyber.label(9, color: Cyber.gold, letterSpacing: 1.4),
            ),
          ],
          if (parsed.time != null) ...[
            const SizedBox(width: 10),
            Text(
              parsed.time!,
              style: Cyber.display(
                12,
                color: isPole ? Cyber.gold : Cyber.muted,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ],
      ),
    );
  }
}

List<F1SessionResult> f1QualifyingSessions(List<F1SessionResult>? sessions) {
  if (sessions == null || sessions.isEmpty) return const [];
  return sessions.where((s) => s.isQualifying).toList(growable: false);
}

List<F1SessionResult> f1NonQualifyingSessions(List<F1SessionResult>? sessions) {
  if (sessions == null || sessions.isEmpty) return const [];
  return sessions.where((s) => !s.isQualifying).toList(growable: false);
}

({int? position, String driver, String? constructor, String? time})
parseF1ResultEntry(String entry) {
  final positionMatch = RegExp(r'^\s*(\d+)[.)]\s*').firstMatch(entry);
  final int? position = positionMatch == null
      ? null
      : int.tryParse(positionMatch.group(1)!);
  final stripped = entry.replaceFirst(RegExp(r'^\s*\d+[.)]\s*'), '').trim();
  final timeMatch = RegExp(r'\(([^)]+)\)\s*$').firstMatch(stripped);
  final String? time = timeMatch?.group(1)?.trim();
  final withoutTime = timeMatch == null
      ? stripped
      : stripped.substring(0, timeMatch.start).trim();
  final parts = withoutTime.split(' · ');
  final driver = parts.first.trim();
  final constructor = parts.length > 1 ? parts[1].trim() : null;
  return (
    position: position,
    driver: driver.isEmpty ? entry : driver,
    constructor: constructor == null || constructor.isEmpty
        ? null
        : constructor,
    time: time == null || time.isEmpty ? null : time,
  );
}
