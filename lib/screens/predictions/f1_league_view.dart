import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/f1_league/f1_league_cubit.dart';
import '../../config/theme.dart';
import '../../models/f1_league_data.dart';
import '../../models/league.dart';
import '../../widgets/cyber/cyber_chart.dart';
import '../../widgets/cyber/cyber_filter_chips.dart';
import '../../widgets/cyber/cyber_underline_tabs.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import 'widgets/standings_table.dart';

/// F1 has its own championship vocabulary and ESPN data contract. It never
/// falls through to football standings or the prototype prediction roster.
class F1LeagueView extends StatefulWidget {
  const F1LeagueView({
    required this.league,
    required this.gamesTab,
    required this.picksTab,
    this.openFixturesTab = false,
    this.followed = false,
    this.followBusy = false,
    this.onToggleFollow,
    super.key,
  });
  final League league;
  final bool openFixturesTab;
  final Widget gamesTab;
  final Widget picksTab;
  final bool followed;
  final bool followBusy;
  final VoidCallback? onToggleFollow;

  @override
  State<F1LeagueView> createState() => _F1LeagueViewState();
}

class _F1LeagueViewState extends State<F1LeagueView> {
  late int _tab = widget.openFixturesTab ? 3 : 0;
  bool _championshipConstructors = false;
  bool _constructors = false;
  String? _round;
  String? _expanded;

  void _change(VoidCallback update) {
    HapticFeedback.selectionClick();
    setState(update);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: CyberBackground(
      child: SafeArea(
        child: BlocBuilder<F1LeagueCubit, F1LeagueState>(
          builder: (context, state) {
            final data = state.data;
            return Column(
              children: [
                DetailTopBar(
                  title: 'F1 CHAMPIONSHIP',
                  trailing: _refreshButton(context, state),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: LeagueHeader(
                    league: widget.league,
                    teamCount: data?.constructors.length ?? 0,
                    subtitle: data == null
                        ? 'CHAMPIONSHIP STANDINGS'
                        : '${data.season} // ${data.drivers.length} DRIVERS · ${data.constructors.length} TEAMS',
                    followed: widget.followed,
                    followBusy: widget.followBusy,
                    onToggleFollow: widget.onToggleFollow,
                  ),
                ),
                CyberUnderlineTabs(
                  labels: const ['TABLE', 'ROUNDS', 'STATS', 'GAMES', 'PICKS'],
                  activeIndex: _tab,
                  onTap: (index) => _change(() {
                    _tab = index;
                    _expanded = null;
                  }),
                ),
                Expanded(
                  child: _tab >= 3
                      ? AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: KeyedSubtree(
                            key: ValueKey('f1-tab-$_tab'),
                            child: _tab == 3
                                ? widget.gamesTab
                                : widget.picksTab,
                          ),
                        )
                      : data == null
                      ? _unavailable(context, state)
                      : RefreshIndicator(
                          onRefresh: context.read<F1LeagueCubit>().refresh,
                          color: Cyber.cyan,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: ListView(
                              key: ValueKey('f1-tab-$_tab'),
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                24,
                              ),
                              children: [
                                if (_tab == 0) ...[
                                  CyberFilterChips(
                                    labels: const ['WDC', 'WCC'],
                                    selected: _championshipConstructors
                                        ? 'WCC'
                                        : 'WDC',
                                    padding: EdgeInsets.zero,
                                    onSelect: (label) => _change(() {
                                      _championshipConstructors =
                                          label == 'WCC';
                                      _expanded = null;
                                    }),
                                  ),
                                  const SizedBox(height: 16),
                                  ..._championship(
                                    data,
                                    _championshipConstructors,
                                  ),
                                ] else if (_tab == 2)
                                  ..._stats(data)
                                else
                                  ..._rounds(data),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _unavailable(BuildContext context, F1LeagueState state) {
    if (state.refreshing) {
      return const Center(child: CircularProgressIndicator(color: Cyber.cyan));
    }
    return CyberNoDataState(
      icon: Icons.sports_motorsports_outlined,
      title: 'STANDINGS UNAVAILABLE',
      message: 'The championship feed could not be loaded.',
      actionLabel: 'RETRY',
      onAction: context.read<F1LeagueCubit>().refresh,
    );
  }

  Widget _refreshButton(BuildContext context, F1LeagueState state) =>
      IconButton(
        tooltip: state.refreshing
            ? 'Refreshing ESPN standings'
            : state.failed
            ? 'Refresh unavailable. Retry ESPN standings'
            : 'Refresh ESPN standings',
        onPressed: state.refreshing
            ? null
            : () {
                HapticFeedback.selectionClick();
                context.read<F1LeagueCubit>().refresh();
              },
        icon: state.refreshing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Cyber.muted,
                ),
              )
            : const Icon(Icons.refresh, color: Cyber.cyan, size: 20),
      );

  List<Widget> _championship(F1LeagueData data, bool constructors) {
    final rows = constructors ? data.constructors : data.drivers;
    if (rows.isEmpty) {
      return [
        const CyberNoDataState(
          icon: Icons.table_rows_outlined,
          title: 'NO STANDINGS',
          message: 'ESPN has not supplied this championship table.',
        ),
      ];
    }
    final leader = rows.first;
    final next = rows.length > 1 ? rows[1] : null;
    final gap = leader.points != null && next?.points != null
        ? leader.points! - next!.points!
        : null;
    return [
      SectionLabel(
        label: constructors
            ? 'World Constructors’ Championship'
            : 'World Drivers’ Championship',
      ),
      const SizedBox(height: 12),
      CyberPanel(
        accent: Cyber.cyan,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CHAMPIONSHIP LEADER',
              style: Cyber.label(9, color: Cyber.cyan),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(leader.name, style: Cyber.display(21))),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      f1Number(leader.points),
                      style: _numberStyle(28, Cyber.cyan),
                    ),
                    Text('POINTS', style: Cyber.label(8, color: Cyber.muted)),
                  ],
                ),
              ],
            ),
            if (gap != null) ...[
              const SizedBox(height: 12),
              Text(
                '${f1Number(gap)} PTS ahead of ${next!.name}',
                style: Cyber.body(12, color: Cyber.muted),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
      const SectionLabel(label: 'The chase // tap an entry to inspect'),
      const SizedBox(height: 12),
      _tableHeader(),
      for (final row in rows) _standingRow(row, data, leader.points),
    ];
  }

  Widget _tableHeader({bool round = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            round ? '' : 'POS',
            style: Cyber.label(8, color: Cyber.muted),
          ),
        ),
        Expanded(
          child: Text('ENTRY', style: Cyber.label(8, color: Cyber.muted)),
        ),
        SizedBox(
          width: 52,
          child: Text(
            'PTS',
            textAlign: TextAlign.right,
            style: Cyber.label(8, color: Cyber.muted),
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(
            round ? '' : 'GAP',
            textAlign: TextAlign.right,
            style: Cyber.label(8, color: Cyber.muted),
          ),
        ),
      ],
    ),
  );

  Widget _standingRow(
    F1Standing row,
    F1LeagueData data,
    num? leaderPoints, {
    String? round,
  }) {
    final key = '${_tab}_${_constructors}_${row.id}';
    final expanded = _expanded == key;
    final points = round == null ? row.points : row.byRace[round];
    final gap = leaderPoints != null && row.points != null
        ? leaderPoints - row.points!
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CyberPanel(
        padding: EdgeInsets.zero,
        accent: expanded ? Cyber.cyan : Cyber.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: expanded,
              child: InkWell(
                onTap: () => _change(() => _expanded = expanded ? null : key),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: round == null
                            ? Text(
                                f1Number(row.rank),
                                style: _numberStyle(
                                  12,
                                  row.rank == 1 ? Cyber.cyan : Cyber.muted,
                                ),
                              )
                            : const Icon(
                                Icons.sports_motorsports_outlined,
                                size: 16,
                                color: Cyber.muted,
                              ),
                      ),
                      Expanded(
                        child: Text(
                          row.name,
                          style: Cyber.body(13),
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 44,
                        child: Text(
                          f1Number(points),
                          textAlign: TextAlign.right,
                          style: _numberStyle(13, Cyber.cyan),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          round != null
                              ? ''
                              : gap == null
                              ? '—'
                              : gap == 0
                              ? '—'
                              : '-${f1Number(gap)}',
                          textAlign: TextAlign.right,
                          style: _numberStyle(9, Cyber.muted),
                        ),
                      ),
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: Cyber.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(color: Cyber.border),
                          Text(
                            'WEEKEND POINTS',
                            style: Cyber.label(9, color: Cyber.cyan),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${row.scoringRounds} scoring rounds · best ${f1Number(row.bestWeekend)} PTS',
                            style: Cyber.body(12, color: Cyber.muted),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final race in data.rounds.where(
                                (r) => row.byRace.containsKey(r.code),
                              ))
                                Tooltip(
                                  message: race.name,
                                  child: _metric(
                                    race.code,
                                    f1Number(row.byRace[race.code]),
                                  ),
                                ),
                            ],
                          ),
                          if (row.byRace.isEmpty)
                            Text(
                              'No recorded weekend points.',
                              style: Cyber.body(12),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _stats(F1LeagueData data) {
    final rows = _constructors ? data.constructors : data.drivers;
    final recorded = data.recordedRounds;
    final top = rows.take(3).toList();
    // Never bridge missing entrant data with an invented zero. Only chart a
    // leading trio whose entire recorded history is available from ESPN.
    final chartable =
        recorded.isNotEmpty &&
        top.isNotEmpty &&
        top.every(
          (row) => recorded.every((race) => row.byRace.containsKey(race.code)),
        );
    final best = rows.where((r) => r.bestWeekend != null).toList()
      ..sort((a, b) => b.bestWeekend!.compareTo(a.bestWeekend!));
    return [
      _entryFilter(),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _metric('RECORDED', '${recorded.length}/${data.rounds.length}'),
          _metric('ENTRIES', '${rows.length}'),
          _metric(
            'POINT SCORERS',
            '${rows.where((r) => (r.points ?? 0) > 0).length}',
          ),
        ],
      ),
      const SizedBox(height: 20),
      if (chartable)
        CyberChartPanel(
          key: ValueKey('points-chart-$_constructors-${data.fetchedAt}'),
          title: 'Points race',
          caption: 'CURRENT TOP ${top.length}',
          yAxisLabels: true,
          height: 200,
          contextLabelAt: (index) => recorded[index].name,
          xAxisLabels: [
            for (var i = 0; i < recorded.length; i++)
              i == 0 || i == recorded.length - 1 || i % 4 == 0
                  ? recorded[i].code
                  : '',
          ],
          series: [
            for (var i = 0; i < top.length; i++)
              ChartSeries(
                label: top[i].name,
                color: [Cyber.cyan, AppTheme.whiteColor, Cyber.muted][i],
                values: _cumulative(top[i], recorded),
                readout: (v, _) => '${f1Number(v)} PTS',
              ),
          ],
        )
      else
        Text(
          'Complete points histories are not available for the leading entries.',
          style: Cyber.body(12, color: Cyber.muted),
        ),
      const SizedBox(height: 8),
      Text(
        'Cumulative weekend points from ESPN. Drag the chart to inspect each round.',
        style: Cyber.body(11, color: Cyber.muted),
      ),
      const SizedBox(height: 24),
      const SectionLabel(label: 'Best weekend hauls'),
      const SizedBox(height: 8),
      Text(
        'Highest points in one weekend, including sprint points when supplied. Ties share the same total.',
        style: Cyber.body(11, color: Cyber.muted),
      ),
      const SizedBox(height: 12),
      for (final row in best.take(5))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CyberPanel(
            accent: Cyber.border,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.name, style: Cyber.body(13)),
                      Text(
                        row.byRace.entries
                            .where((e) => e.value == row.bestWeekend)
                            .map((e) => e.key)
                            .join(' · '),
                        style: Cyber.label(8, color: Cyber.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${f1Number(row.bestWeekend)} PTS',
                  style: _numberStyle(14, Cyber.cyan),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _rounds(F1LeagueData data) {
    if (data.rounds.isEmpty) {
      return [Text('No rounds supplied by ESPN.', style: Cyber.body(13))];
    }
    final selected =
        data.rounds.where((r) => r.code == _round).firstOrNull ??
        data.recordedRounds.lastOrNull ??
        data.rounds.first;
    final rows =
        (_constructors ? data.constructors : data.drivers)
            .where((r) => r.byRace.containsKey(selected.code))
            .toList()
          ..sort(
            (a, b) =>
                b.byRace[selected.code]!.compareTo(a.byRace[selected.code]!),
          );
    return [
      const SectionLabel(label: 'Round by round'),
      const SizedBox(height: 8),
      CyberFilterChips(
        labels: data.rounds.map((r) => r.code).toList(),
        selected: selected.code,
        padding: const EdgeInsets.symmetric(vertical: 8),
        onSelect: (code) => _change(() {
          _round = code;
          _expanded = null;
        }),
      ),
      const SizedBox(height: 8),
      Text(selected.name, style: Cyber.display(18)),
      const SizedBox(height: 8),
      Text(
        selected.played
            ? 'WEEKEND POINTS // HIGH TO LOW'
            : 'NO RESULT RECORDED',
        style: Cyber.label(9, color: Cyber.muted),
      ),
      const SizedBox(height: 16),
      _entryFilter(),
      if (rows.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CyberNoDataState(
            icon: Icons.flag_outlined,
            title: 'NO POINTS YET',
            message: 'ESPN has not supplied points for this round.',
          ),
        )
      else ...[
        const SizedBox(height: 12),
        _tableHeader(round: true),
        for (final row in rows)
          _standingRow(row, data, null, round: selected.code),
      ],
    ];
  }

  Widget _entryFilter() => CyberFilterChips(
    labels: const ['DRIVERS', 'CONSTRUCTORS'],
    selected: _constructors ? 'CONSTRUCTORS' : 'DRIVERS',
    padding: EdgeInsets.zero,
    onSelect: (label) => _change(() {
      _constructors = label == 'CONSTRUCTORS';
      _expanded = null;
    }),
  );

  Widget _metric(String label, String value) => CyberPanel(
    accent: Cyber.border,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Cyber.label(8, color: Cyber.muted)),
        const SizedBox(height: 4),
        Text(value, style: _numberStyle(14, Cyber.textPrimary)),
      ],
    ),
  );

  List<double> _cumulative(F1Standing row, List<F1LeagueRound> rounds) {
    var sum = 0.0;
    return [
      for (final race in rounds) sum += row.byRace[race.code]!.toDouble(),
    ];
  }

  TextStyle _numberStyle(double size, Color color) => Cyber.display(
    size,
    color: color,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
