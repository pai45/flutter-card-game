import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/cricket_scorecard.dart';
import 'cyber/cyber_filter_chips.dart';
import 'cyber/cyber_widgets.dart';

class CricketScorecardView extends StatefulWidget {
  const CricketScorecardView({
    super.key,
    required this.scorecard,
    required this.accent,
  });

  final CricketScorecard scorecard;
  final Color accent;

  @override
  State<CricketScorecardView> createState() => _CricketScorecardViewState();
}

class _CricketScorecardViewState extends State<CricketScorecardView> {
  int _selectedIndex = 0;

  @override
  void didUpdateWidget(covariant CricketScorecardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedIndex >= widget.scorecard.innings.length) {
      _selectedIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.scorecard.innings.isEmpty) {
      return Center(
        child: Text(
          'No scorecard data available',
          style: Cyber.body(13, color: Cyber.muted),
        ),
      );
    }

    final innings = widget.scorecard.innings[_selectedIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.scorecard.innings.length > 1) ...[
          CyberSectionHeading(
            label: 'INNINGS CONTROL',
            trailing: CyberStatPill(
              label: '${_selectedIndex + 1}/${widget.scorecard.innings.length}',
              color: widget.accent,
            ),
          ),
          const SizedBox(height: 10),
          CyberFilterChips(
            key: const ValueKey('scorecard-innings-selector'),
            labels: [
              for (final item in widget.scorecard.innings)
                item.teamName.toUpperCase(),
            ],
            selected: innings.teamName.toUpperCase(),
            accent: widget.accent,
            padding: EdgeInsets.zero,
            onSelect: _selectInnings,
          ),
          const SizedBox(height: 16),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.025, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: _InningsScorecard(
            key: ValueKey(
              'scorecard-innings-${innings.number ?? _selectedIndex}',
            ),
            innings: innings,
            accent: widget.accent,
            fallbackNumber: _selectedIndex + 1,
          ),
        ),
      ],
    );
  }

  void _selectInnings(String teamName) {
    final index = widget.scorecard.innings.indexWhere(
      (innings) => innings.teamName.toUpperCase() == teamName,
    );
    if (index < 0 || index == _selectedIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }
}

class _InningsScorecard extends StatelessWidget {
  const _InningsScorecard({
    required this.innings,
    required this.accent,
    required this.fallbackNumber,
    super.key,
  });

  final CricketInnings innings;
  final Color accent;
  final int fallbackNumber;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInningsHeader(),
        if (innings.batters.isNotEmpty) ...[
          const SizedBox(height: 20),
          CyberSectionHeading(
            label: 'BATTING CARD',
            trailing: Text(
              '${innings.batters.length} BATTERS',
              style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 8),
          _buildBattingTable(),
        ],
        if (innings.didNotBat.isNotEmpty || innings.fow.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildInningsNotes(),
        ],
        if (innings.partnerships.isNotEmpty) ...[
          const SizedBox(height: 20),
          CyberSectionHeading(
            label: 'PARTNERSHIPS',
            trailing: Text(
              '${innings.partnerships.length} STANDS',
              style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 8),
          _buildPartnerships(),
        ],
        if (innings.bowlers.isNotEmpty) ...[
          const SizedBox(height: 20),
          CyberSectionHeading(
            label: 'BOWLING CARD',
            trailing: Text(
              '${innings.bowlers.length} BOWLERS',
              style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 8),
          _buildBowlingTable(),
        ],
      ],
    );
  }

  Widget _buildInningsHeader() {
    final score = innings.runs != null && innings.wickets != null
        ? '${innings.runs}/${innings.wickets}'
        : innings.scoreText;
    final inningsNumber = innings.number ?? fallbackNumber;
    final boundaryCount = innings.batters.fold<int>(
      0,
      (total, batter) => total + batter.fours + batter.sixes,
    );

    return CyberPanel(
      key: const ValueKey('scorecard-innings-header'),
      accent: accent,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 2, color: accent),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INNINGS ${inningsNumber.toString().padLeft(2, '0')} // SCORECARD',
                        style: Cyber.label(
                          8,
                          color: accent,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${innings.teamName} Innings',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.display(14, letterSpacing: 0.35),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        innings.target == null
                            ? 'MATCH DATA // VERIFIED FIGURES'
                            : 'CHASE TARGET // ${innings.target}',
                        style: Cyber.label(
                          7,
                          color: Cyber.muted,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      score,
                      textAlign: TextAlign.right,
                      style: Cyber.display(25, color: accent, letterSpacing: 0)
                          .copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                    if (innings.overs != null)
                      Text(
                        '${_formatNumber(innings.overs!)} OVERS',
                        style: Cyber.label(
                          8,
                          color: Cyber.muted,
                          letterSpacing: 1,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                CyberMiniMetric(
                  label: 'Run rate',
                  value: innings.runRate == null
                      ? '—'
                      : innings.runRate!.toStringAsFixed(2),
                  accent: accent,
                ),
                const SizedBox(width: 6),
                CyberMiniMetric(label: 'Boundaries', value: '$boundaryCount'),
                const SizedBox(width: 6),
                CyberMiniMetric(
                  label: innings.target == null ? 'Wickets' : 'Target',
                  value: '${innings.target ?? innings.wickets ?? '—'}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattingTable() {
    final best = innings.batters.fold<int>(
      0,
      (value, batter) => batter.runs > value ? batter.runs : value,
    );
    return _ScorecardTable(
      key: const ValueKey('scorecard-batting-table'),
      accent: accent,
      header: _tableRow(
        name: 'BATTER',
        values: const ['R', 'B', '4', '6', 'SR'],
      ),
      rows: [
        for (var index = 0; index < innings.batters.length; index++)
          _batterRow(innings.batters[index], index: index, best: best),
        if (innings.extras.isNotEmpty) _extrasRow(),
      ],
    );
  }

  Widget _batterRow(
    CricketBatter batter, {
    required int index,
    required int best,
  }) {
    final dismissal = batter.dismissalText?.trim() ?? '';
    final notOut = batter.notOut || dismissal.isEmpty;
    final isTopScore = batter.runs == best && best > 0;
    final details = <String>[
      if (batter.position != null) 'POS ${batter.position}',
      if (batter.minutes != null) '${batter.minutes} MIN',
      if (notOut) 'NOT OUT',
      if (batter.milestone != null && batter.milestone!.isNotEmpty)
        batter.milestone!.toUpperCase(),
    ];

    return Container(
      color: index.isEven ? Cyber.chartSurface : Cyber.panel,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 2,
                  height: 32,
                  color: notOut ? accent : Cyber.line,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        batter.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.body(
                          12,
                          color: notOut ? accent : AppTheme.whiteColor,
                          weight: notOut ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      if (dismissal.isNotEmpty)
                        Text(
                          dismissal,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.body(8.5, color: Cyber.muted),
                        ),
                      if (details.isNotEmpty)
                        Text(
                          details.join(' // '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.label(
                            6.5,
                            color: Cyber.muted.withValues(alpha: 0.82),
                            letterSpacing: 0.7,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _numberCell(
            '${batter.runs}',
            color: isTopScore ? Cyber.gold : AppTheme.whiteColor,
            weight: FontWeight.w900,
          ),
          _numberCell('${batter.balls}'),
          _numberCell('${batter.fours}'),
          _numberCell('${batter.sixes}'),
          _numberCell(batter.strikeRate.toStringAsFixed(1), flex: 2),
        ],
      ),
    );
  }

  Widget _extrasRow() {
    return Container(
      color: accent.withValues(alpha: 0.055),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'EXTRAS',
              style: Cyber.label(9, color: accent, letterSpacing: 1.1),
            ),
          ),
          Flexible(
            child: Text(
              innings.extras,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Cyber.body(
                11,
                color: AppTheme.whiteColor,
                weight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInningsNotes() {
    return CyberPanel(
      accent: Cyber.line,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (innings.didNotBat.isNotEmpty)
            _telemetryLine(
              label: 'YET TO BAT',
              value: innings.didNotBat.join('  •  '),
            ),
          if (innings.didNotBat.isNotEmpty && innings.fow.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                height: 1,
                color: Cyber.line.withValues(alpha: 0.35),
              ),
            ),
          if (innings.fow.isNotEmpty)
            _telemetryLine(
              label: 'FALL OF WICKETS',
              value: innings.fow.join('  //  '),
            ),
        ],
      ),
    );
  }

  Widget _telemetryLine({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Cyber.label(8, color: accent, letterSpacing: 1.1)),
        const SizedBox(height: 5),
        Text(value, style: Cyber.body(10.5, color: Cyber.muted)),
      ],
    );
  }

  Widget _buildPartnerships() {
    return CyberPanel(
      accent: Cyber.line,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        children: [
          for (var index = 0; index < innings.partnerships.length; index++) ...[
            if (index > 0)
              Container(height: 1, color: Cyber.line.withValues(alpha: 0.3)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      innings.partnerships[index].wicket.toUpperCase(),
                      style: Cyber.label(8, color: accent),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      innings.partnerships[index].batters
                          .map((batter) => '${batter.name} ${batter.runs}')
                          .join(' + '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.body(10.5, weight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${innings.partnerships[index].runs} / ${_formatNumber(innings.partnerships[index].overs)} OV',
                    style: Cyber.label(
                      8,
                      color: Cyber.gold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBowlingTable() {
    final best = innings.bowlers.fold<int>(
      0,
      (value, bowler) => bowler.wickets > value ? bowler.wickets : value,
    );
    return _ScorecardTable(
      key: const ValueKey('scorecard-bowling-table'),
      accent: accent,
      header: _tableRow(
        name: 'BOWLER',
        values: const ['O', 'M', 'R', 'W', 'ER'],
      ),
      rows: [
        for (var index = 0; index < innings.bowlers.length; index++)
          _bowlerRow(innings.bowlers[index], index: index, best: best),
      ],
    );
  }

  Widget _bowlerRow(
    CricketBowler bowler, {
    required int index,
    required int best,
  }) {
    final isStrikeBowler = bowler.wickets == best && best > 0;
    return Container(
      color: index.isEven ? Cyber.chartSurface : Cyber.panel,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 2,
                  height: 30,
                  color: isStrikeBowler ? Cyber.gold : Cyber.line,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bowler.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.body(
                          12,
                          weight: isStrikeBowler
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      Text(
                        'DOT ${bowler.dots ?? '—'} // WD ${bowler.wides ?? '—'} // NB ${bowler.noBalls ?? '—'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.label(
                          6.5,
                          color: Cyber.muted.withValues(alpha: 0.82),
                          letterSpacing: 0.65,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _numberCell(_formatNumber(bowler.overs)),
          _numberCell('${bowler.maidens}'),
          _numberCell('${bowler.runs}'),
          _numberCell(
            '${bowler.wickets}',
            color: isStrikeBowler ? Cyber.gold : accent,
            weight: FontWeight.w900,
          ),
          _numberCell(bowler.economyRate.toStringAsFixed(1), flex: 2),
        ],
      ),
    );
  }

  Widget _tableRow({required String name, required List<String> values}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              name,
              style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1),
            ),
          ),
          for (var index = 0; index < values.length; index++)
            Expanded(
              flex: index == values.length - 1 ? 2 : 1,
              child: Text(
                values[index],
                textAlign: TextAlign.right,
                style: Cyber.label(8, color: Cyber.muted, letterSpacing: 0.8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _numberCell(
    String value, {
    int flex = 1,
    Color? color,
    FontWeight weight = FontWeight.w600,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        value,
        maxLines: 1,
        textAlign: TextAlign.right,
        style: Cyber.body(
          10.5,
          color: color ?? Cyber.muted,
          weight: weight,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  String _formatNumber(double value) =>
      value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
}

class _ScorecardTable extends StatelessWidget {
  const _ScorecardTable({
    required this.accent,
    required this.header,
    required this.rows,
    super.key,
  });

  final Color accent;
  final Widget header;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.line,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ColoredBox(color: accent.withValues(alpha: 0.065), child: header),
          Container(height: 1, color: accent.withValues(alpha: 0.45)),
          for (var index = 0; index < rows.length; index++) ...[
            rows[index],
            if (index != rows.length - 1)
              Container(height: 1, color: Cyber.line.withValues(alpha: 0.28)),
          ],
          const SizedBox(height: CyberClipper.cut),
        ],
      ),
    );
  }
}
