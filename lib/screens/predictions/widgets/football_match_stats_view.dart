import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../data/team_palettes.dart';
import '../../../models/football_match_data.dart';
import '../../../models/sport_match.dart';
import '../../../widgets/cyber/cyber_chart.dart';
import '../../../widgets/cyber/cyber_filter_chips.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/match_pitch_view.dart';
import 'football_shot_map.dart';
import 'match_stats_shell.dart';

class FootballMatchStatsView extends StatefulWidget {
  const FootballMatchStatsView({required this.match, super.key});

  final SportMatch match;

  @override
  State<FootballMatchStatsView> createState() => _FootballMatchStatsViewState();
}

class _FootballMatchStatsViewState extends State<FootballMatchStatsView> {
  static const _tabs = <String>[
    'OVERVIEW',
    'MOMENTUM',
    'LINEUPS',
    'COMMENTARY',
  ];

  String _activeTab = _tabs.first;

  void _selectTab(String tab) {
    if (tab == _activeTab) return;
    HapticFeedback.selectionClick();
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
                'MOMENTUM' => _MomentumSection(match: widget.match),
                'LINEUPS' => MatchPitchView(match: widget.match),
                'COMMENTARY' => _CommentarySection(match: widget.match),
                _ => _OverviewSection(match: widget.match),
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.match});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final details = match.footballDetails;
    final stats = match.teamStats ?? const <TeamStatLine>[];

    return ListView(
      key: const ValueKey('football-stats-overview'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        const CyberSectionHeading(
          key: ValueKey('football-match-intel-heading'),
          label: 'MATCH INTEL',
        ),
        const SizedBox(height: 10),
        _MatchIntelPanel(match: match),
        if (details == null) ...[
          const SizedBox(height: 18),
          const CyberSectionHeading(
            key: ValueKey('football-scoreboard-channel-heading'),
            label: 'SCOREBOARD CHANNEL',
          ),
          const SizedBox(height: 10),
          _FeedStatePanel(match: match),
        ],
        if (stats.isNotEmpty) ...[
          const SizedBox(height: 18),
          _TeamControlPanel(match: match, stats: stats),
        ],
        const SizedBox(height: 18),
        _MatchTimelinePanel(
          key: const ValueKey('football-timeline-block'),
          match: match,
        ),
      ],
    );
  }
}

class _MatchIntelPanel extends StatelessWidget {
  const _MatchIntelPanel({required this.match});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final details = match.footballDetails;
    final venue = details == null
        ? 'Venue awaiting feed'
        : '${details.venue} // ${details.city}, ${details.country}';
    final attendance = details == null || details.attendance <= 0
        ? '—'
        : _compactNumber(details.attendance);

    return StatsRowShell(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            details?.league.toUpperCase() ?? match.leagueId.toUpperCase(),
            style: Cyber.display(15, letterSpacing: 0.8),
          ),
          const SizedBox(height: 4),
          Text(
            details?.season ?? 'Live competition feed',
            style: Cyber.body(12, color: Cyber.muted),
          ),
          const SizedBox(height: 16),
          _IntelCell(
            icon: Icons.stadium_outlined,
            label: 'VENUE',
            value: venue,
          ),
          const SizedBox(height: 8),
          _IntelCell(
            icon: Icons.groups_outlined,
            label: 'ATTENDANCE',
            value: attendance,
            numeric: true,
          ),
        ],
      ),
    );
  }
}

class _FeedStatePanel extends StatelessWidget {
  const _FeedStatePanel({required this.match});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    return StatsRowShell(
      accent: Cyber.muted,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _feedMessage(match),
            style: Cyber.body(12.5, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          _FeedFact(
            label: 'LAST UPDATED',
            value: _formatFeedDateTime(match.liveLastUpdated),
          ),
          _FeedFact(
            label: 'KICKOFF',
            value: _formatFeedDateTime(match.kickoff),
          ),
        ],
      ),
    );
  }
}

class _FeedFact extends StatelessWidget {
  const _FeedFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Cyber.label(8.5, color: Cyber.muted, letterSpacing: 0.8),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.right,
            style: Cyber.body(11, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _IntelCell extends StatelessWidget {
  const _IntelCell({
    required this.icon,
    required this.label,
    required this.value,
    this.numeric = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Cyber.panel2.withValues(alpha: 0.56),
        border: Border.all(color: Cyber.line.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Cyber.cyan),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: Cyber.label(
                      8.5,
                      color: Cyber.muted,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                (numeric
                        ? Cyber.display(13, letterSpacing: 0.6)
                        : Cyber.body(11.5, weight: FontWeight.w700))
                    .copyWith(
                      fontFeatures: numeric
                          ? const [FontFeature.tabularFigures()]
                          : null,
                    ),
          ),
        ],
      ),
    );
  }
}

/// TEAM CONTROL as market-style outcome rows — tap one to hold it highlighted.
class _TeamControlPanel extends StatefulWidget {
  const _TeamControlPanel({required this.match, required this.stats});

  final SportMatch match;
  final List<TeamStatLine> stats;

  @override
  State<_TeamControlPanel> createState() => _TeamControlPanelState();
}

class _TeamControlPanelState extends State<_TeamControlPanel> {
  String? _selectedLabel;

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final homeColor = paletteForTeam(
      match.home,
      sport: match.sport,
      competition: match.leagueId,
    ).secondaryTextColor;
    final awayColor = paletteForTeam(
      match.away,
      sport: match.sport,
      competition: match.leagueId,
    ).secondaryTextColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CyberSectionHeading(label: 'TEAM CONTROL'),
        const SizedBox(height: 12),
        TeamLegendRow(match: match),
        const SizedBox(height: 12),
        for (final stat in widget.stats) ...[
          StatComparisonRow(
            stat: stat,
            homeColor: homeColor,
            awayColor: awayColor,
            selected: stat.label == _selectedLabel,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(
                () => _selectedLabel = stat.label == _selectedLabel
                    ? null
                    : stat.label,
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// MOMENTUM: the two-sided pressure trace on the shared chart surface. Drag it
/// to read either side's pressure at any minute; goals ride the plot as markers
/// and the decisive one carries the focal halo.
class _MomentumSection extends StatefulWidget {
  const _MomentumSection({required this.match});

  final SportMatch match;

  @override
  State<_MomentumSection> createState() => _MomentumSectionState();
}

class _MomentumSectionState extends State<_MomentumSection> {
  static const _ranges = ['FULL', '1ST HALF', '2ND HALF'];
  String _range = _ranges.first;

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final momentum = match.footballMomentum;
    if (momentum == null || momentum.series.isEmpty) {
      return const CyberNoDataState(
        key: ValueKey('football-momentum-empty'),
        icon: Icons.show_chart,
        title: 'Pressure feed offline',
        message: 'Momentum will map the match once enough live actions arrive.',
        accent: Cyber.cyan,
        spark: Icons.bolt,
      );
    }

    final homeColor = paletteForTeam(
      match.home,
      sport: match.sport,
      competition: match.leagueId,
    ).secondaryTextColor;
    final awayColor = paletteForTeam(
      match.away,
      sport: match.sport,
      competition: match.leagueId,
    ).secondaryTextColor;
    final samples = _samplesForRange(momentum, _range);
    final shots = match.footballDetails?.shots ?? const <FootballShot>[];
    final homePeak = momentum.homePeak!;
    final awayPeak = momentum.awayPeak!;

    return ListView(
      key: const ValueKey('football-stats-momentum'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, progress, _) => CyberChartPanel(
            chartKey: const ValueKey('football-momentum-graph'),
            title: 'MATCH MOMENTUM',
            caption: '${momentum.series.length}/SAMPLES',
            height: 250,
            signed: true,
            bloom: true,
            glow: progress < 1,
            revealProgress: progress,
            ranges: _ranges,
            activeRange: _range,
            onRangeChanged: (range) => setState(() => _range = range),
            markers: _goalMarkers(momentum, samples, homeColor, awayColor),
            contextLabelAt: (index) =>
                "${samples[index.clamp(0, samples.length - 1)].minute}'",
            series: [
              ChartSeries(
                label: '${match.home.shortName.toUpperCase()} PRESSURE',
                color: homeColor,
                fill: true,
                readout: (value, _) => value.abs().toStringAsFixed(0),
                values: [for (final point in samples) point.home.abs()],
              ),
              ChartSeries(
                label: '${match.away.shortName.toUpperCase()} PRESSURE',
                color: awayColor,
                fill: true,
                readout: (value, _) => value.abs().toStringAsFixed(0),
                values: [for (final point in samples) -point.away.abs()],
              ),
            ],
          ),
        ),
        if (shots.isNotEmpty) ...[
          const SizedBox(height: 18),
          FootballShotMapPanel(
            match: match,
            shots: shots,
            homeColor: homeColor,
            awayColor: awayColor,
          ),
        ],
        const SizedBox(height: 18),
        const CyberSectionHeading(label: 'PEAK PRESSURE'),
        const SizedBox(height: 10),
        Row(
          children: [
            CyberMiniMetric(
              label: "${match.home.shortName} PEAK // ${homePeak.minute}'",
              value: homePeak.value.abs().toStringAsFixed(1),
              accent: homeColor,
            ),
            const SizedBox(width: 10),
            CyberMiniMetric(
              label: "${match.away.shortName} PEAK // ${awayPeak.minute}'",
              value: awayPeak.value.abs().toStringAsFixed(1),
              accent: awayColor,
            ),
          ],
        ),
        if (momentum.goals.isNotEmpty) ...[
          const SizedBox(height: 18),
          const CyberSectionHeading(label: 'GOAL IMPACT MARKERS'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final goal in momentum.goals)
                _GoalMarkerChip(
                  goal: goal,
                  color: goal.isHomeTeam ? homeColor : awayColor,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// FULL keeps every sample; the half filters split on the recorded halftime
/// minute and fall back to the whole trace when a half has too few samples.
List<FootballMomentumPoint> _samplesForRange(
  FootballMomentum momentum,
  String range,
) {
  if (range == 'FULL') return momentum.series;
  final halftime = momentum.halftimeMinute;
  final filtered =
      (range == '1ST HALF'
              ? momentum.series.where((point) => point.minute <= halftime)
              : momentum.series.where((point) => point.minute > halftime))
          .toList();
  return filtered.length >= 2 ? filtered : momentum.series;
}

/// Goals pinned onto the visible window. The last goal is the decisive one, so
/// it gets the focal halo — one focal element per chart.
List<ChartMarker> _goalMarkers(
  FootballMomentum momentum,
  List<FootballMomentumPoint> samples,
  Color homeColor,
  Color awayColor,
) {
  if (momentum.goals.isEmpty || samples.length < 2) {
    return const <ChartMarker>[];
  }
  final first = samples.first.minute;
  final last = samples.last.minute;
  final span = math.max(1, last - first);
  final markers = <ChartMarker>[];
  for (final goal in momentum.goals) {
    if (goal.minute < first || goal.minute > last) continue;
    markers.add(
      ChartMarker(
        fraction: (goal.minute - first) / span,
        color: goal.isHomeTeam ? homeColor : awayColor,
        alignTop: goal.isHomeTeam,
        focal: goal == momentum.goals.last,
      ),
    );
  }
  return markers;
}

class _GoalMarkerChip extends StatelessWidget {
  const _GoalMarkerChip({required this.goal, required this.color});

  final FootballMomentumGoal goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sports_soccer, size: 11, color: color),
          const SizedBox(width: 5),
          Text(
            '${goal.clock} ${goal.player}',
            style: Cyber.label(8.5, color: Cyber.muted, letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }
}

/// MATCH TIMELINE: the event spine. Minutes run down the middle and every
/// moment sits on the side of the team that made it, so who-did-what-when
/// reads in a single pass. Tap a moment to unpack the feed's report on it.
class _MatchTimelinePanel extends StatelessWidget {
  const _MatchTimelinePanel({required this.match, super.key});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final events = match.timelineEvents ?? const <MatchEvent>[];
    if (events.isEmpty) {
      return const CyberNoDataState(
        key: ValueKey('football-timeline-empty'),
        icon: Icons.timeline,
        title: 'Event log pending',
        message: 'Goals, cards and substitutions will be tracked here.',
        accent: Cyber.cyan,
        spark: Icons.sports_soccer,
      );
    }
    final homeColor = paletteForTeam(
      match.home,
      sport: match.sport,
      competition: match.leagueId,
    ).secondaryTextColor;
    final awayColor = paletteForTeam(
      match.away,
      sport: match.sport,
      competition: match.leagueId,
    ).secondaryTextColor;
    return Column(
      key: const ValueKey('football-match-timeline'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LogHeader(
          title: 'MATCH TIMELINE',
          count: events.length,
          suffix: 'EVENTS',
        ),
        const SizedBox(height: 12),
        for (final event in events)
          if (_isPeriodMarker(event.type))
            _PeriodMarker(event: event)
          else
            _TimelineRow(
              event: event,
              accent: event.isHomeTeam ? homeColor : awayColor,
            ),
      ],
    );
  }
}

/// Width of the centre column. Sized for the longest stoppage-time label
/// ("90'+5'") so the spine never shifts sideways between rows.
const double _kSpineWidth = 60;

/// One moment on the spine: the minute in the centre, the event pushed out to
/// its own team's side. Tapping expands the feed's own report on the moment.
class _TimelineRow extends StatefulWidget {
  const _TimelineRow({required this.event, required this.accent});

  final MatchEvent event;
  final Color accent;

  @override
  State<_TimelineRow> createState() => _TimelineRowState();
}

class _TimelineRowState extends State<_TimelineRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final isHome = event.isHomeTeam;
    final report = event.description?.trim() ?? '';
    final body = _EventBody(
      event: event,
      accent: widget.accent,
      alignEnd: isHome,
    );
    return PressableScale(
      enabled: report.isNotEmpty,
      onTap: report.isEmpty
          ? null
          : () {
              HapticFeedback.selectionClick();
              setState(() => _open = !_open);
            },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: isHome ? body : const SizedBox.shrink()),
                  _MinuteSpine(event: event, accent: widget.accent),
                  Expanded(child: isHome ? const SizedBox.shrink() : body),
                ],
              ),
            ),
            if (_open && report.isNotEmpty)
              _EventReport(
                text: report,
                accent: widget.accent,
                alignEnd: isHome,
              ),
          ],
        ),
      ),
    );
  }
}

/// The centre column: a continuous hairline with the minute plate riding it.
/// Only a goal plate glows — a goal is the one event class that moved the
/// score, so it stays the scarce focal mark down the whole spine.
class _MinuteSpine extends StatelessWidget {
  const _MinuteSpine({required this.event, required this.accent});

  final MatchEvent event;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isGoal = event.type == MatchEventType.goal;
    return SizedBox(
      width: _kSpineWidth,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Center(
              child: Container(
                width: 1,
                color: Cyber.line.withValues(alpha: 0.32),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ChamferedActionSurface(
              clipper: const HudChamferClipper(bigCut: 7, smallCut: 0),
              borderColor: accent.withValues(alpha: isGoal ? 0.72 : 0.3),
              glowColor: accent,
              glow: isGoal ? 1 : 0,
              child: Container(
                width: 48,
                height: 26,
                alignment: Alignment.center,
                color: isGoal ? accent.withValues(alpha: 0.12) : Cyber.panel,
                child: Text(
                  event.minuteLabel,
                  maxLines: 1,
                  style:
                      Cyber.display(
                        10.5,
                        color: isGoal ? accent : Cyber.muted,
                      ).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The copy for one moment, mirrored so the glyph always hugs the spine and
/// the text reads outward from it.
class _EventBody extends StatelessWidget {
  const _EventBody({
    required this.event,
    required this.accent,
    required this.alignEnd,
  });

  final MatchEvent event;
  final Color accent;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final align = alignEnd ? TextAlign.right : TextAlign.left;
    final lines = <Widget>[];

    if (event.type == MatchEventType.substitution &&
        event.secondaryPlayerName != null) {
      // A swap reads as two names, not one: who came on, then who came off.
      lines.add(
        Text(
          event.playerName.toUpperCase(),
          textAlign: align,
          style: Cyber.display(11, color: Cyber.lime, letterSpacing: 0.4),
        ),
      );
      lines.add(const SizedBox(height: 2));
      lines.add(
        Text(
          event.secondaryPlayerName!.toUpperCase(),
          textAlign: align,
          style: Cyber.display(11, color: Cyber.danger, letterSpacing: 0.4),
        ),
      );
    } else {
      lines.add(
        Text(
          (event.playerName.isEmpty
                  ? event.label ?? 'MATCH EVENT'
                  : event.playerName)
              .toUpperCase(),
          textAlign: align,
          style: Cyber.display(11.5, letterSpacing: 0.4),
        ),
      );
      if (event.type == MatchEventType.goal && event.scoreDisplay != null) {
        lines.add(const SizedBox(height: 3));
        lines.add(
          Text(
            event.scoreDisplay!,
            textAlign: align,
            style: Cyber.display(11, color: accent).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
      }
      if (event.secondaryPlayerName != null) {
        lines.add(const SizedBox(height: 3));
        lines.add(
          Text(
            'ASSIST ${event.secondaryPlayerName!.toUpperCase()}',
            textAlign: align,
            style: Cyber.label(8, color: Cyber.muted, letterSpacing: 0.6),
          ),
        );
      }
    }

    final copy = Flexible(
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: lines,
      ),
    );
    final glyph = _EventGlyph(
      type: event.type,
      color: _eventTone(event.type, accent),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: alignEnd
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: alignEnd
            ? [copy, const SizedBox(width: 8), glyph]
            : [glyph, const SizedBox(width: 8), copy],
      ),
    );
  }
}

/// The event mark. Cards are drawn as actual cards rather than borrowed from
/// the icon set — the shape carries the meaning faster than any glyph does.
class _EventGlyph extends StatelessWidget {
  const _EventGlyph({required this.type, required this.color});

  final MatchEventType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isCard =
        type == MatchEventType.yellowCard || type == MatchEventType.redCard;
    final mark = isCard
        ? Transform.rotate(
            angle: 0.18,
            child: Container(
              width: 9,
              height: 13,
              decoration: BoxDecoration(
                color: color,
                border: Border.all(
                  color: Cyber.bg.withValues(alpha: 0.6),
                  width: 0.8,
                ),
              ),
            ),
          )
        : Icon(_eventIcon(type), size: 15, color: color);
    return ChamferedActionSurface(
      clipper: const HudChamferClipper(bigCut: 7, smallCut: 0),
      borderColor: color.withValues(alpha: 0.42),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        color: color.withValues(alpha: 0.1),
        child: mark,
      ),
    );
  }
}

/// The feed's own prose on a moment, revealed on tap and pinned to the side of
/// the team it belongs to.
class _EventReport extends StatelessWidget {
  const _EventReport({
    required this.text,
    required this.accent,
    required this.alignEnd,
  });

  final String text;
  final Color accent;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final edge = BorderSide(color: accent.withValues(alpha: 0.7), width: 2);
    return Padding(
      padding: EdgeInsets.only(
        left: alignEnd ? 0 : _kSpineWidth + 8,
        right: alignEnd ? _kSpineWidth + 8 : 0,
        bottom: 10,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Cyber.panel,
          border: Border(
            left: alignEnd ? BorderSide.none : edge,
            right: alignEnd ? edge : BorderSide.none,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Text(
            text,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: Cyber.body(11.5, color: Cyber.muted),
          ),
        ),
      ),
    );
  }
}

class _PeriodMarker extends StatelessWidget {
  const _PeriodMarker({required this.event});

  final MatchEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Cyber.cyan.withValues(alpha: 0.24))),
          const SizedBox(width: 10),
          Icon(Icons.adjust, size: 12, color: Cyber.cyan),
          const SizedBox(width: 7),
          Text(
            '${event.label ?? _eventLabel(event.type)} ${event.scoreDisplay ?? ''}'
                .trim()
                .toUpperCase(),
            style: Cyber.label(9, color: Cyber.cyan, letterSpacing: 1),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: Cyber.cyan.withValues(alpha: 0.24))),
        ],
      ),
    );
  }
}

Color _eventTone(MatchEventType type, Color accent) => switch (type) {
  MatchEventType.yellowCard => Cyber.amber,
  MatchEventType.redCard => Cyber.danger,
  MatchEventType.substitution => Cyber.lime,
  _ => accent,
};

IconData _eventIcon(MatchEventType type) => switch (type) {
  MatchEventType.goal => Icons.sports_soccer,
  MatchEventType.substitution => Icons.swap_horiz,
  _ => Icons.bolt,
};

class _CommentarySection extends StatelessWidget {
  const _CommentarySection({required this.match});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final commentary = match.commentary ?? const <MatchCommentary>[];
    if (commentary.isEmpty) {
      return const CyberNoDataState(
        key: ValueKey('football-commentary-empty'),
        icon: Icons.mic_none,
        title: 'Match comms silent',
        message: 'The play-by-play channel opens once commentary is available.',
        accent: Cyber.cyan,
        spark: Icons.graphic_eq,
      );
    }
    return CustomScrollView(
      key: const ValueKey('football-stats-commentary'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          sliver: SliverToBoxAdapter(
            child: _LogHeader(
              title: 'LIVE MATCH COMMS',
              count: commentary.length,
              suffix: 'ENTRIES',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          sliver: SliverList.separated(
            itemCount: commentary.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _CommentaryRow(
              item: commentary[index],
              fallbackSequence: index,
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentaryRow extends StatelessWidget {
  const _CommentaryRow({required this.item, required this.fallbackSequence});

  final MatchCommentary item;
  final int fallbackSequence;

  @override
  Widget build(BuildContext context) {
    final sequence = item.sequence ?? fallbackSequence;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.minute.isEmpty ? '—' : item.minute,
                  style: Cyber.display(11, color: Cyber.cyan).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'SEQ ${sequence.toString().padLeft(3, '0')}',
                  style: Cyber.label(
                    7.5,
                    color: Cyber.muted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 42,
            color: Cyber.line.withValues(alpha: 0.22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.teamName != null || item.kind != null) ...[
                  Text(
                    [
                      if (item.teamName != null) item.teamName!.toUpperCase(),
                      if (item.kind != null) item.kind!.toUpperCase(),
                    ].join(' // '),
                    style: Cyber.label(
                      8,
                      color: Cyber.cyan,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
                Text(item.text, style: Cyber.body(12, color: Cyber.muted)),
                if (item.players.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'PLAYERS // ${item.players.join(' · ')}',
                    style: Cyber.label(
                      7.5,
                      color: Cyber.muted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogHeader extends StatelessWidget {
  const _LogHeader({
    required this.title,
    required this.count,
    required this.suffix,
  });

  final String title;
  final int count;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return CyberSectionHeading(
      label: title,
      trailing: Text(
        '${count.toString().padLeft(3, '0')} $suffix',
        style: Cyber.label(
          8.5,
          color: Cyber.muted,
          letterSpacing: 0.8,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

bool _isPeriodMarker(MatchEventType type) => switch (type) {
  MatchEventType.kickoff ||
  MatchEventType.halftime ||
  MatchEventType.secondHalf ||
  MatchEventType.fullTime => true,
  _ => false,
};

String _eventLabel(MatchEventType type) => switch (type) {
  MatchEventType.kickoff => 'Kickoff',
  MatchEventType.halftime => 'Halftime',
  MatchEventType.secondHalf => 'Second half',
  MatchEventType.fullTime => 'Full time',
  MatchEventType.goal => 'Goal',
  MatchEventType.yellowCard => 'Yellow card',
  MatchEventType.redCard => 'Red card',
  MatchEventType.substitution => 'Substitution',
};

String _feedMessage(SportMatch match) {
  final note = match.liveStatusNote?.trim();
  if (note != null && note.isNotEmpty) return note;
  return switch (match.status) {
    MatchStatus.upcoming => 'Scoreboard opens when the match starts.',
    MatchStatus.live =>
      match.liveMinute == null
          ? 'Live match data is active.'
          : 'Live clock: ${match.liveMinute} minutes.',
    MatchStatus.finished =>
      match.resultLine?.trim().isNotEmpty == true
          ? match.resultLine!.trim()
          : 'Final score has been recorded.',
  };
}

String _formatFeedDateTime(DateTime? value) {
  if (value == null) return 'Unavailable';
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

String _compactNumber(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}
