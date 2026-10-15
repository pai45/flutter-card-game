import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../design_system/match_discovery.generated.dart';
import '../../models/picks.dart';
import '../../models/prediction.dart';
import '../../models/sport_match.dart';
import '../team_logo.dart';
import 'cyber_widgets.dart';
import 'fixture_card.dart';
import 'statoz_icons.dart';

Color editorialSportAccent(Sport? sport) => switch (sport) {
  Sport.cricket => AppTheme.whiteColor,
  Sport.basketball => Cyber.gold,
  Sport.motorsport => Cyber.f1Red,
  _ => Cyber.cyan,
};
Color editorialEventInk(Color color) {
  final surface = kFixtureStripDark.computeLuminance();
  for (var mix = 0; mix <= 60; mix += 10) {
    final lifted = Color.lerp(color, Colors.white, mix / 100)!;
    if ((lifted.computeLuminance() + .05) / (surface + .05) >= 4.5) {
      return lifted;
    }
  }
  return Color.lerp(color, Colors.white, .6)!;
}

TextStyle editorialText(
  BuildContext context,
  double size, {
  FontWeight weight = FontWeight.w400,
  Color? color,
}) => Cyber.bodyFor(
  context,
  size,
  weight: weight,
  color: color ?? Colors.white,
  height: 1.4,
);
String editorialStatus(String status) =>
    MatchDiscoveryTokens.statusLabels[status] ?? '';
String editorialKickoff(DateTime date, DateTime now) {
  final d = date.toLocal(), n = now.toLocal();
  final today = d.year == n.year && d.month == n.month && d.day == n.day;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return 'Starts ${today ? 'today' : '${d.day} ${months[d.month - 1]}'} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String? editorialDeadline(DateTime? date, String status, DateTime now) {
  if (date == null || !['upcoming', 'live'].contains(status)) {
    return null;
  }
  final difference = date.difference(now).inSeconds;
  if (difference <= 0) {
    return null;
  }
  final m = (difference / 60).ceil();
  return 'Closes in ${m < 60
      ? '${m}m'
      : m < 1440
      ? '${m ~/ 60}h ${m % 60}m'
      : '${(m / 1440).ceil()}d'}';
}

Color _statusColor(String status) => switch (status) {
  'live' => Cyber.red,
  'upcoming' => Cyber.gold,
  'unresolved' => Cyber.amber,
  'settled' => Cyber.success,
  _ => Cyber.muted,
};

class EditorialStatusArea extends StatelessWidget {
  const EditorialStatusArea({
    required this.label,
    this.status,
    this.timing,
    this.liveContext,
    this.sport,
    this.showDivider = true,
    super.key,
  });
  final String label;
  final String? status, timing, liveContext;
  final Sport? sport;
  final bool showDivider;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, box) {
          final live = status == 'live' ? liveContext?.trim() : null;
          final tagLabel =
              '${editorialStatus(status ?? "")}${live != null && live.isNotEmpty ? " $live" : ""}';
          final tag = status == null
              ? null
              : ChamferedActionSurface(
                  key: const ValueKey('editorial-lifecycle-dock'),
                  clipper: const ShapeBorderClipper(
                    shape: BeveledRectangleBorder(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(4),
                      ),
                    ),
                  ),
                  borderColor: Color.alphaBlend(
                    _statusColor(status!).withValues(alpha: .28),
                    kFixtureStripDark,
                  ),
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: MatchDiscoveryTokens.tagMinHeight,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: MatchDiscoveryTokens.tagHorizontal,
                      vertical: MatchDiscoveryTokens.tagVertical,
                    ),
                    color: Color.alphaBlend(
                      _statusColor(
                        status!,
                      ).withValues(alpha: MatchDiscoveryTokens.statusTint),
                      kFixtureStripDark,
                    ),
                    child: Text(
                      tagLabel,
                      style: editorialText(
                        context,
                        12,
                        weight: FontWeight.w600,
                        color: _statusColor(status!),
                      ),
                    ),
                  ),
                );
          final marker = Row(
            children: [
              if (sport != null)
                StatozSportIcon(
                  sport: sport!,
                  size: MatchDiscoveryTokens.emblem,
                  color: editorialSportAccent(sport),
                )
              else
                Container(width: 16, height: 2, color: Cyber.cyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: editorialText(
                    context,
                    12,
                    weight: FontWeight.w600,
                    color: Cyber.muted,
                  ).copyWith(letterSpacing: .5),
                ),
              ),
            ],
          );
          if (tag == null) return marker;
          final text = TextPainter(
            text: TextSpan(
              text: tagLabel,
              style: editorialText(
                context,
                12,
                weight: FontWeight.w600,
                color: _statusColor(status!),
              ),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final tagHeight = (text.height + MatchDiscoveryTokens.tagVertical * 2)
              .clamp(MatchDiscoveryTokens.tagMinHeight, double.infinity);
          final narrow = box.maxWidth < 220;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (narrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: (tagHeight + 8 - MatchDiscoveryTokens.card)
                          .clamp(16.0, double.infinity)
                          .toDouble(),
                    ),
                    marker,
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: marker),
                    const SizedBox(width: 8),
                    SizedBox(
                      width:
                          text.width + MatchDiscoveryTokens.tagHorizontal * 2,
                      height: 0,
                    ),
                  ],
                ),
              Positioned(
                top: -MatchDiscoveryTokens.card,
                right: -MatchDiscoveryTokens.card,
                child: tag,
              ),
            ],
          );
        },
      ),
      if (timing != null &&
          timing!.trim().isNotEmpty &&
          timing!.trim().toUpperCase() != editorialStatus(status ?? '')) ...[
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Text(
            timing!,
            style: editorialText(context, 12, color: Cyber.muted),
          ),
        ),
      ],
      const SizedBox(height: 7),
      if (showDivider)
        Container(height: 1, color: kFixtureBorder)
      else
        const SizedBox(height: 1),
      const SizedBox(height: 4),
    ],
  );
}

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

class EditorialInset extends StatelessWidget {
  const EditorialInset({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.edge = kFixtureBorder,
    this.fill = kFixtureStripDark,
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color edge, fill;
  @override
  Widget build(BuildContext context) => ChamferedActionSurface(
    clipper: const HudChamferClipper(
      bigCut: MatchDiscoveryTokens.detailCut,
      smallCut: 0,
    ),
    borderColor: edge,
    child: ColoredBox(
      color: fill,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class EditorialAction extends StatelessWidget {
  const EditorialAction(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: EditorialInset(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: editorialText(
                context,
                12,
                weight: FontWeight.w600,
                color: Cyber.cyan,
              ),
            ),
          ),
          Container(width: 1, height: 16, color: kFixtureBorder),
          const SizedBox(width: 8),
          const Icon(Icons.north_east, size: 16, color: Cyber.cyan),
        ],
      ),
    ),
  );
}

class EditorialQuestionProgress extends StatelessWidget {
  const EditorialQuestionProgress({
    required this.answered,
    required this.total,
    super.key,
  });
  final int answered, total;
  @override
  Widget build(BuildContext context) => total <= 0
      ? const SizedBox.shrink()
      : ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0)
                  const SizedBox(width: MatchDiscoveryTokens.progressGap),
                Expanded(
                  child: Container(
                    height: MatchDiscoveryTokens.progressHeight,
                    color: i < answered ? Cyber.cyan : Cyber.border,
                  ),
                ),
              ],
            ],
          ),
        );
}

Color editorialMatchAccent(SportMatch match, {bool followed = false}) {
  if (match.status == MatchStatus.live) {
    return Cyber.red;
  }
  if (match.status == MatchStatus.finished) {
    final result = (match.resultLine ?? '').toLowerCase();
    final leader = result
        .split(RegExp(r'\b(?:won|wins|winner|beat|defeat(?:ed)?)\b'))
        .first;
    if (!RegExp(r'draw|tie|abandon|no result').hasMatch(result)) {
      for (final team in [match.home, match.away]) {
        if ([team.name, team.shortName].any(
              (name) => name.length > 2 && leader.contains(name.toLowerCase()),
            ) &&
            RegExp(r'won|wins|winner|beat|defeat').hasMatch(result)) {
          return team.color;
        }
      }
      if (match.sport == Sport.football || match.sport == Sport.basketball) {
        final home = int.tryParse(match.homeScore ?? ''),
            away = int.tryParse(match.awayScore ?? '');
        if (home != null && away != null && home != away) {
          return home > away ? match.home.color : match.away.color;
        }
      }
    }
    return Cyber.border;
  }
  return followed ? Cyber.cyan : Cyber.border;
}

class EditorialMatchCard extends StatelessWidget {
  const EditorialMatchCard({
    required this.match,
    required this.onTap,
    this.compact = false,
    this.competitionLabel,
    this.followed = false,
    super.key,
  });
  final SportMatch match;
  final VoidCallback? onTap;
  final bool compact;
  final bool followed;
  final String? competitionLabel;
  @override
  Widget build(BuildContext context) {
    final stacked =
        compact ||
        match.sport == Sport.cricket ||
        match.sport == Sport.basketball;
    final timing = match.status == MatchStatus.upcoming
        ? editorialKickoff(match.kickoff, DateTime.now())
        : match.status == MatchStatus.live
        ? match.liveStatusNote ??
              (match.sport == Sport.football && match.liveMinute != null
                  ? '${match.liveMinute}′'
                  : null)
        : null;
    final session = (match.f1Sessions ?? [])
        .where((s) => s.results.isNotEmpty)
        .lastOrNull;
    return EditorialPlate(
      onTap: onTap,
      backgroundAccent: editorialMatchAccent(match, followed: followed),
      motionId: 'match:${match.id}:$compact',
      signalAccent: editorialSportAccent(match.sport),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EditorialStatusArea(
            sport: match.sport,
            label: competitionLabel ?? match.leagueId.toUpperCase(),
            status: match.status.name,
            timing: match.status == MatchStatus.live ? null : timing,
            liveContext: match.status == MatchStatus.live ? timing : null,
          ),
          if (match.sport == Sport.motorsport) ...[
            Text(
              match.home.name,
              style: editorialText(context, 16, weight: FontWeight.w600),
            ),
            if (session != null) ...[
              const SizedBox(height: 12),
              Text(
                session.name,
                style: editorialText(context, 12, color: Cyber.muted),
              ),
              for (final row in session.results.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    row,
                    style: editorialText(context, 14, weight: FontWeight.w600),
                  ),
                ),
            ],
          ] else if (stacked) ...[
            teamRow(context, match.home, match.homeScore),
            const SizedBox(height: 12),
            const Divider(height: 1, color: kFixtureBorder),
            const SizedBox(height: 8),
            teamRow(context, match.away, match.awayScore),
          ] else
            LayoutBuilder(
              builder: (context, box) {
                final score = Text(
                  match.status == MatchStatus.upcoming
                      ? 'VS'
                      : '${match.homeScore ?? '—'} : ${match.awayScore ?? '—'}',
                  textAlign: TextAlign.center,
                  style:
                      Cyber.display(
                        MediaQuery.sizeOf(context).width < 360
                            ? MatchDiscoveryTokens.score
                            : MatchDiscoveryTokens.wideScore,
                      ).copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                );
                if (MediaQuery.sizeOf(context).width < 360 ||
                    MediaQuery.textScalerOf(context).scale(14) / 14 >= 1.4) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: identity(context, match.home)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: identity(context, match.away, away: true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      score,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: identity(context, match.home)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: score,
                    ),
                    Expanded(child: identity(context, match.away, away: true)),
                  ],
                );
              },
            ),
          if (match.resultLine != null && match.sport != Sport.football) ...[
            const SizedBox(height: 12),
            Text(
              match.resultLine!,
              style: editorialText(context, 12, color: Cyber.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget identity(BuildContext context, SportTeam team, {bool away = false}) =>
      Column(
        crossAxisAlignment: away
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          TeamLogo(
            team: team,
            width: 32,
            height: 32,
            sport: match.sport,
            competition: match.leagueId,
            cutBottomRight: !away,
          ),
          const SizedBox(height: 8),
          Text(
            team.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: away ? TextAlign.right : TextAlign.left,
            style: editorialText(context, 14, weight: FontWeight.w600),
          ),
        ],
      );
  TextStyle scoreStyle(BuildContext context, String score) =>
      score != '—' && !RegExp(r'\d').hasMatch(score)
      ? editorialText(context, 12, color: Cyber.muted)
      : Cyber.display(
          MatchDiscoveryTokens.score,
        ).copyWith(fontWeight: FontWeight.w700);
  Widget teamRow(BuildContext context, SportTeam team, String? value) {
    final innings = match.cricketScorecard?.innings
        .where((i) => i.teamName == team.name || i.teamName == team.shortName)
        .lastOrNull;
    final raw = value ?? innings?.scoreText ?? '—';
    final score = match.sport == Sport.cricket
        ? raw.split('(').first.trim()
        : raw;
    final note = innings?.overs != null
        ? '${innings!.overs} overs${innings.target != null ? ' · Target ${innings.target}' : ''}'
        : raw.contains('(')
        ? raw.substring(raw.indexOf('('))
        : null;
    final name = Row(
      children: [
        TeamLogo(
          team: team,
          width: compact ? 28 : 36,
          height: compact ? 28 : 36,
          sport: match.sport,
          competition: match.leagueId,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            team.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: editorialText(context, 14, weight: FontWeight.w600),
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact ||
            MediaQuery.sizeOf(context).width < 360 ||
            MediaQuery.textScalerOf(context).scale(14) / 14 >= 1.4) ...[
          name,
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(score, style: scoreStyle(context, score)),
          ),
        ] else
          Row(
            children: [
              Expanded(child: name),
              const SizedBox(width: 12),
              Text(score, style: scoreStyle(context, score)),
            ],
          ),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(note, style: editorialText(context, 12, color: Cyber.muted)),
        ],
      ],
    );
  }
}

class EditorialEventsPanel extends StatelessWidget {
  const EditorialEventsPanel({
    required this.markets,
    required this.onOpen,
    super.key,
  });
  final List<PickMarket> markets;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) => EditorialPlate(
    quiet: true,
    contentPadding: const EdgeInsets.symmetric(
      vertical: MatchDiscoveryTokens.card,
    ),
    motionId: 'events:${markets.map((m) => m.id).join(',')}',
    signalAccent: editorialSportAccent(markets.firstOrNull?.sport),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MatchDiscoveryTokens.card,
          ),
          child: Text(
            'EVENTS',
            style: Cyber.display(
              14,
            ).copyWith(fontWeight: FontWeight.w600, letterSpacing: .5),
          ),
        ),
        for (var i = 0; i < markets.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MatchDiscoveryTokens.card,
              ),
              child: Divider(height: 1, color: Cyber.border),
            ),
          EditorialEventRow(
            market: markets[i],
            onTap: () => onOpen(markets[i].id),
          ),
        ],
      ],
    ),
  );
}

class EditorialEventRow extends StatelessWidget {
  const EditorialEventRow({
    required this.market,
    required this.onTap,
    super.key,
  });
  final PickMarket market;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final leading = market.leadingOutcome,
        delta = market.latestDeltaFor(leading.id);
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MatchDiscoveryTokens.card,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EditorialStatusArea(
                label: market.leagueLabel,
                sport: market.sport,
                showDivider: false,
                status: market.status.name,
                timing:
                    editorialDeadline(
                      market.closesAt,
                      market.status.name,
                      DateTime.now(),
                    ) ??
                    (market.status == PickMarketStatus.live
                        ? market.liveLabel
                        : null),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          market.question,
                          style: editorialText(
                            context,
                            MatchDiscoveryTokens.question,
                            weight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          leading.label,
                          style: editorialText(context, 12, color: Cyber.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${leading.probabilityPercent}%',
                        style:
                            Cyber.display(
                              14,
                              color: editorialEventInk(leading.color),
                            ).copyWith(
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                      if (delta != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${delta > 0 ? '+' : ''}$delta pp',
                          style: editorialText(
                            context,
                            12,
                            color: delta > 0
                                ? Cyber.success
                                : delta < 0
                                ? Cyber.red
                                : Cyber.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditorialMarketCard extends StatelessWidget {
  const EditorialMarketCard({
    required this.market,
    required this.onOpen,
    required this.onBuy,
    this.positions = const [],
    this.featured = false,
    super.key,
  });
  final PickMarket market;
  final VoidCallback onOpen;
  final ValueChanged<PickOutcome> onBuy;
  final List<PickPosition> positions;
  final bool featured;
  @override
  Widget build(BuildContext context) => EditorialPlate(
    signalAccent: editorialSportAccent(market.sport),
    motionId: 'pick:${market.id}',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorialStatusArea(
          sport: market.sport,
          label:
              '${market.leagueLabel} · ${market.type == PickMarketType.future ? 'Future' : 'Match Pick'}',
          status: market.status.name,
          timing:
              editorialDeadline(
                market.closesAt,
                market.status.name,
                DateTime.now(),
              ) ??
              (market.status == PickMarketStatus.live
                  ? market.liveLabel
                  : null),
        ),
        InkWell(
          onTap: onOpen,
          child: Text(
            market.question,
            style: editorialText(context, 16, weight: FontWeight.w600),
          ),
        ),
        if (!featured && market.contextTitle != null) ...[
          const SizedBox(height: 12),
          Text(
            market.contextTitle!,
            style: editorialText(context, 12, color: Cyber.muted),
          ),
        ],
        const SizedBox(height: 12),
        for (final outcome
            in featured
                ? market.outcomes.take(MatchDiscoveryTokens.featuredOutcomes)
                : market.outcomes)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Opacity(
              opacity: market.canBuy ? 1 : .65,
              child: OutlinedButton(
                key: ValueKey('editorial-outcome-${market.id}-${outcome.id}'),
                onPressed: market.canBuy
                    ? () {
                        HapticFeedback.selectionClick();
                        onBuy(outcome);
                      }
                    : null,
                style:
                    OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 44),
                      visualDensity: VisualDensity.standard,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide.none,
                      shape: const BeveledRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                    ).copyWith(
                      side: WidgetStateProperty.resolveWith(
                        (states) => BorderSide(
                          width: 2,
                          color:
                              states.contains(WidgetState.focused) ||
                                  states.contains(WidgetState.hovered)
                              ? Cyber.cyan
                              : Colors.transparent,
                        ),
                      ),
                    ),
                child: EditorialInset(
                  padding: EdgeInsets.zero,
                  edge: Color.alphaBlend(
                    outcome.color.withValues(alpha: .30),
                    kFixtureBorder,
                  ),
                  fill: Color.alphaBlend(
                    outcome.color.withValues(
                      alpha: MatchDiscoveryTokens.outcomeTint,
                    ),
                    kFixtureStripDark,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(width: 2, color: outcome.color),
                      ),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 0, 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  outcome.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: editorialText(
                                    context,
                                    14,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ChamferedActionSurface(
                            key: ValueKey(
                              'editorial-price-${market.id}-${outcome.id}',
                            ),
                            clipper: const HudChamferClipper(
                              bigCut: MatchDiscoveryTokens.detailCut,
                              smallCut: 0,
                            ),
                            borderColor: Color.lerp(
                              outcome.color,
                              Colors.white,
                              .3,
                            )!,
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: MatchDiscoveryTokens.outcomeWidth,
                                minHeight: 44,
                              ),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: outcome.color,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.darkInk.withValues(
                                      alpha: .12,
                                    ),
                                    offset: const Offset(0, -2),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: Text(
                                '${outcome.probabilityPercent}%',
                                style:
                                    Cyber.display(
                                      14,
                                      color:
                                          outcome.color.computeLuminance() >
                                              MatchDiscoveryTokens
                                                  .percentageInkThreshold
                                          ? AppTheme.darkInk
                                          : Colors.white,
                                    ).copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${market.volumeOz} Oz volume${positions.isNotEmpty ? ' · ${positions.length} held' : ''}',
                  style: editorialText(context, 12, color: Cyber.muted),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onOpen,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(
                  positions.any((p) => p.canSettle)
                      ? 'View result ↗'
                      : market.type == PickMarketType.future
                      ? 'View Future ↗'
                      : 'View Pick ↗',
                  style: editorialText(
                    context,
                    12,
                    weight: FontWeight.w600,
                    color: Cyber.cyan,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class EditorialMission extends StatelessWidget {
  const EditorialMission({
    required this.match,
    required this.quiz,
    required this.onTap,
    this.prediction,
    super.key,
  });
  final SportMatch match;
  final PredictionQuiz quiz;
  final UserPrediction? prediction;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final count = quiz.questions
        .where((q) => prediction?.answers[q.id] != null)
        .length;
    return EditorialPlate(
      onTap: onTap,
      motionId: 'mission:${match.id}:${quiz.id}',
      signalAccent: editorialSportAccent(match.sport),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EditorialStatusArea(
            label: 'XP prediction',
            sport: match.sport,
            status: prediction?.status == PredictionStatus.locked
                ? 'closed'
                : match.status.name,
          ),
          if (match.sport == Sport.motorsport)
            Text(
              match.home.name,
              style: editorialText(context, 16, weight: FontWeight.w600),
            )
          else
            Semantics(
              label: '${match.home.name} versus ${match.away.name}',
              excludeSemantics: true,
              child: Row(
                children: [
                  TeamLogo(
                    team: match.home,
                    width: 32,
                    height: 32,
                    sport: match.sport,
                    competition: match.leagueId,
                  ),
                  Expanded(
                    child: Text(
                      'VS',
                      textAlign: TextAlign.center,
                      style: Cyber.display(
                        14,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TeamLogo(
                    team: match.away,
                    width: 32,
                    height: 32,
                    sport: match.sport,
                    competition: match.leagueId,
                    cutBottomRight: false,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text(
            '$count / ${quiz.questions.length} answered',
            style: editorialText(context, 12, color: Cyber.muted),
          ),
          const SizedBox(height: 12),
          EditorialQuestionProgress(
            answered: count,
            total: quiz.questions.length,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                Cyber.gold.withValues(alpha: .06),
                kFixtureStripDark,
              ),
              border: const Border(
                left: BorderSide(color: Cyber.gold, width: 2),
              ),
            ),
            child: Text(
              'Up to ${quiz.maxReward} XP',
              style: editorialText(
                context,
                12,
                weight: FontWeight.w600,
                color: Cyber.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays out real children twice: natural heights first, then the row maximum.
/// Unlike IntrinsicHeight this supports SVG and responsive LayoutBuilder children.
class EditorialEqualRow extends MultiChildRenderObjectWidget {
  const EditorialEqualRow({
    required super.children,
    this.itemWidth,
    this.gap = 16,
    super.key,
  });
  final double? itemWidth;
  final double gap;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _EditorialEqualRowRender(itemWidth, gap);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    final render = renderObject as _EditorialEqualRowRender;
    render
      ..itemWidth = itemWidth
      ..gap = gap;
    render.markNeedsLayout();
  }
}

class _EditorialRowParentData extends ContainerBoxParentData<RenderBox> {}

class _EditorialEqualRowRender extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _EditorialRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _EditorialRowParentData> {
  _EditorialEqualRowRender(this.itemWidth, this.gap);
  double? itemWidth;
  double gap;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _EditorialRowParentData) {
      child.parentData = _EditorialRowParentData();
    }
  }

  @override
  void performLayout() {
    final width =
        itemWidth ??
        ((constraints.maxWidth - gap * (childCount - 1)) / childCount).clamp(
          0,
          double.infinity,
        );
    var height = 0.0;
    RenderBox? child = firstChild;
    while (child != null) {
      child.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
      if (child.size.height > height) height = child.size.height;
      child = (child.parentData! as _EditorialRowParentData).nextSibling;
    }
    var x = 0.0;
    child = firstChild;
    while (child != null) {
      child.layout(
        BoxConstraints.tightFor(width: width, height: height),
        parentUsesSize: true,
      );
      final data = child.parentData! as _EditorialRowParentData;
      data.offset = Offset(x, 0);
      x += width + gap;
      child = data.nextSibling;
    }
    size = constraints.constrain(Size(childCount == 0 ? 0 : x - gap, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class EditorialPairedGrid extends StatelessWidget {
  const EditorialPairedGrid({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final one =
        MediaQuery.sizeOf(context).width < MatchDiscoveryTokens.collapseWidth ||
        MediaQuery.textScalerOf(context).scale(14) / 14 >=
            MatchDiscoveryTokens.collapseTextScale;
    if (one) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: MatchDiscoveryTokens.gridGap),
            children[i],
          ],
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < children.length; i += 2) ...[
          if (i > 0) const SizedBox(height: MatchDiscoveryTokens.gridGap),
          EditorialEqualRow(
            gap: MatchDiscoveryTokens.gridGap,
            children: [
              children[i],
              if (i + 1 < children.length) children[i + 1],
            ],
          ),
        ],
      ],
    );
  }
}

class EditorialRevealCard extends StatelessWidget {
  const EditorialRevealCard({
    required this.match,
    required this.onTap,
    super.key,
  });
  final SportMatch match;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => EditorialPlate(
    gold: true,
    motionId: 'reveal:${match.id}',
    onTap: onTap,
    child: Row(
      children: [
        Expanded(
          child: Text(
            match.sport == Sport.motorsport
                ? match.home.name
                : '${match.home.name} vs ${match.away.name}',
            style: editorialText(
              context,
              14,
              weight: FontWeight.w600,
              color: Cyber.gold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.chevron_right, size: 18, color: Cyber.gold),
      ],
    ),
  );
}
