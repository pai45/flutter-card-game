import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/cricket_scorecard.dart';

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
        // Innings Toggle
        if (widget.scorecard.innings.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(widget.scorecard.innings.length, (
                  index,
                ) {
                  final inn = widget.scorecard.innings[index];
                  final isSelected = _selectedIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIndex = index),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? widget.accent.withValues(alpha: 0.2)
                            : Cyber.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? widget.accent : Cyber.border,
                        ),
                      ),
                      child: Text(
                        inn.teamName,
                        style: Cyber.body(13, color: AppTheme.whiteColor)
                            .copyWith(
                              color: isSelected ? widget.accent : Cyber.muted,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

        _buildInningsHeader(innings),
        const SizedBox(height: 16),
        if (innings.batters.isNotEmpty) _buildBattingTable(innings),
        if (innings.didNotBat.isNotEmpty) _buildDidNotBat(innings.didNotBat),
        if (innings.fow.isNotEmpty) _buildFow(innings.fow),
        if (innings.partnerships.isNotEmpty)
          _buildPartnerships(innings.partnerships),
        if (innings.bowlers.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildBowlingTable(innings.bowlers),
        ],
      ],
    );
  }

  Widget _buildInningsHeader(CricketInnings innings) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Cyber.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Cyber.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${innings.teamName} Innings',
                  style: Cyber.body(13, color: AppTheme.whiteColor).copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.whiteColor,
                  ),
                ),
                if (innings.runRate != null)
                  Text(
                    'RR ${innings.runRate!.toStringAsFixed(2)}'
                    '${innings.target == null ? '' : ' // TARGET ${innings.target}'}',
                    style: Cyber.label(8, color: Cyber.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                innings.scoreText,
                textAlign: TextAlign.right,
                style: Cyber.display(
                  13,
                  color: widget.accent,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              if (innings.overs != null)
                Text(
                  '${innings.overs!.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} OV',
                  style: Cyber.label(8, color: Cyber.muted),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBattingTable(CricketInnings innings) {
    final batters = innings.batters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: const BoxDecoration(
            color: Cyber.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: _headerText('Batter')),
              Expanded(child: _headerText('R', align: TextAlign.right)),
              Expanded(child: _headerText('B', align: TextAlign.right)),
              Expanded(child: _headerText('4s', align: TextAlign.right)),
              Expanded(child: _headerText('6s', align: TextAlign.right)),
              Expanded(
                flex: 2,
                child: _headerText('SR', align: TextAlign.right),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Cyber.panel,
            border: Border.all(color: Cyber.border),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(8),
            ),
          ),
          child: Column(
            children: [
              ...batters.map((b) {
                final isOut =
                    b.dismissalText != null && b.dismissalText!.isNotEmpty;
                return Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Cyber.border)),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.name,
                              style: Cyber.body(13, color: AppTheme.whiteColor)
                                  .copyWith(
                                    color: isOut
                                        ? AppTheme.whiteColor
                                        : widget.accent,
                                    fontWeight: isOut
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                  ),
                            ),
                            if (isOut)
                              Text(
                                b.dismissalText!,
                                style: Cyber.body(
                                  13,
                                  color: AppTheme.whiteColor,
                                ).copyWith(fontSize: 10, color: Cyber.muted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              '${b.position == null ? '' : 'POS ${b.position} // '}${b.minutes == null ? '' : '${b.minutes} MIN // '}${b.notOut ? 'NOT OUT' : ''}${b.milestone == null ? '' : ' // ${b.milestone}'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Cyber.label(6.8, color: Cyber.muted),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${b.runs}',
                          textAlign: TextAlign.right,
                          style: Cyber.body(
                            13,
                            color: AppTheme.whiteColor,
                            weight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(child: _valText('${b.balls}')),
                      Expanded(child: _valText('${b.fours}')),
                      Expanded(child: _valText('${b.sixes}')),
                      Expanded(
                        flex: 2,
                        child: Text(
                          b.strikeRate.toStringAsFixed(1),
                          textAlign: TextAlign.right,
                          style: Cyber.body(12, color: Cyber.muted),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (innings.extras.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Extras',
                          style: Cyber.body(
                            13,
                            color: AppTheme.whiteColor,
                            weight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: Text(
                          innings.extras,
                          textAlign: TextAlign.right,
                          style: Cyber.body(
                            13,
                            color: AppTheme.whiteColor,
                            weight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDidNotBat(List<String> dnb) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: RichText(
        text: TextSpan(
          style: Cyber.body(12, color: Cyber.muted),
          children: [
            TextSpan(
              text: 'Yet to bat: ',
              style: Cyber.body(
                12,
                color: Cyber.muted,
                weight: FontWeight.bold,
              ),
            ),
            TextSpan(text: dnb.join(', ')),
          ],
        ),
      ),
    );
  }

  Widget _buildFow(List<String> fow) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: RichText(
        text: TextSpan(
          style: Cyber.body(12, color: Cyber.muted),
          children: [
            TextSpan(
              text: 'Fall of wickets: ',
              style: Cyber.body(
                12,
                color: Cyber.muted,
                weight: FontWeight.bold,
              ),
            ),
            TextSpan(text: fow.join(', ')),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerships(List<CricketPartnership> partnerships) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Cyber.panel,
          border: Border.all(color: Cyber.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'PARTNERSHIPS',
              style: Cyber.label(9, color: widget.accent, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            for (final partnership in partnerships)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        partnership.wicket,
                        style: Cyber.label(8, color: Cyber.muted),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        partnership.batters
                            .map((batter) => '${batter.name} ${batter.runs}')
                            .join(' + '),
                        style: Cyber.body(11),
                      ),
                    ),
                    Text(
                      '${partnership.runs} (${partnership.overs.toStringAsFixed(1)} ov)',
                      style: Cyber.display(9, color: widget.accent).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBowlingTable(List<CricketBowler> bowlers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: const BoxDecoration(
            color: Cyber.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: _headerText('Bowler')),
              Expanded(child: _headerText('O', align: TextAlign.right)),
              Expanded(child: _headerText('M', align: TextAlign.right)),
              Expanded(child: _headerText('R', align: TextAlign.right)),
              Expanded(child: _headerText('W', align: TextAlign.right)),
              Expanded(
                flex: 2,
                child: _headerText('ER', align: TextAlign.right),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Cyber.panel,
            border: Border.all(color: Cyber.border),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(8),
            ),
          ),
          child: Column(
            children: bowlers.map((b) {
              return Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Cyber.border)),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.name,
                            style: Cyber.body(13, color: AppTheme.whiteColor),
                          ),
                          Text(
                            'DOT ${b.dots ?? '-'} // WD ${b.wides ?? '-'} // NB ${b.noBalls ?? '-'} // 4C ${b.foursConceded ?? '-'} // 6C ${b.sixesConceded ?? '-'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Cyber.label(6.5, color: Cyber.muted),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        b.overs
                            .toStringAsFixed(1)
                            .replaceAll(RegExp(r'\.0$'), ''),
                        textAlign: TextAlign.right,
                        style: Cyber.body(13, color: AppTheme.whiteColor),
                      ),
                    ),
                    Expanded(child: _valText('${b.maidens}')),
                    Expanded(child: _valText('${b.runs}')),
                    Expanded(
                      child: Text(
                        '${b.wickets}',
                        textAlign: TextAlign.right,
                        style: Cyber.body(
                          13,
                          color: widget.accent,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        b.economyRate.toStringAsFixed(1),
                        textAlign: TextAlign.right,
                        style: Cyber.body(12, color: Cyber.muted),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _headerText(String text, {TextAlign align = TextAlign.left}) {
    return Text(
      text,
      textAlign: align,
      style: Cyber.body(
        13,
        color: AppTheme.whiteColor,
      ).copyWith(fontSize: 11, color: Cyber.muted, fontWeight: FontWeight.w600),
    );
  }

  Widget _valText(String text) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: Cyber.body(12, color: Cyber.muted),
    );
  }
}
