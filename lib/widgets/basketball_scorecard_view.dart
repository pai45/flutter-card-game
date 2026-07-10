import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/basketball_scorecard.dart';

class BasketballScorecardView extends StatefulWidget {
  const BasketballScorecardView({
    super.key,
    required this.scorecard,
    required this.accent,
  });

  final BasketballScorecard scorecard;
  final Color accent;

  @override
  State<BasketballScorecardView> createState() => _BasketballScorecardViewState();
}

class _BasketballScorecardViewState extends State<BasketballScorecardView> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final home = widget.scorecard.homeBoxscore;
    final away = widget.scorecard.awayBoxscore;

    final selectedBoxscore = _selectedIndex == 0 ? away : home;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLinescores(),
        const SizedBox(height: 24),
        _buildTeamStatsComparison(away.stats, home.stats, away.teamName, home.teamName),
        const SizedBox(height: 24),
        
        // Team Toggle for Boxscore
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              _buildTeamTab(away.teamName, 0),
              const SizedBox(width: 8),
              _buildTeamTab(home.teamName, 1),
            ],
          ),
        ),
        
        _buildPlayerTable(selectedBoxscore),
      ],
    );
  }

  Widget _buildTeamTab(String teamName, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? widget.accent.withValues(alpha: 0.15) : Cyber.card,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? widget.accent : Cyber.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          teamName.toUpperCase(),
          style: Cyber.display(12, color: isSelected ? widget.accent : Cyber.muted),
        ),
      ),
    );
  }

  Widget _buildLinescores() {
    final ls = widget.scorecard.linescores;
    final pc = ls.periodCount;
    final away = widget.scorecard.awayBoxscore.teamName;
    final home = widget.scorecard.homeBoxscore.teamName;
    
    return Container(
      decoration: BoxDecoration(
        color: Cyber.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Cyber.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Cyber.panel.withValues(alpha: 0.5),
              border: const Border(bottom: BorderSide(color: Cyber.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('TEAM', style: Cyber.label(10, color: Cyber.muted)),
                ),
                for (int i = 1; i <= pc; i++)
                  Expanded(
                    child: Text(
                      'Q$i', 
                      textAlign: TextAlign.center, 
                      style: Cyber.label(10, color: Cyber.muted)
                    ),
                  ),
                Expanded(
                  flex: 1,
                  child: Text('T', textAlign: TextAlign.right, style: Cyber.label(11, color: Colors.white)),
                ),
              ],
            ),
          ),
          _buildLinescoreRow(away, ls.awayScores, ls.awayTotal, pc),
          const Divider(height: 1, color: Cyber.border),
          _buildLinescoreRow(home, ls.homeScores, ls.homeTotal, pc),
        ],
      ),
    );
  }

  Widget _buildLinescoreRow(String teamName, List<int> scores, int total, int periodCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              teamName, 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis, 
              style: Cyber.body(13, weight: FontWeight.bold)
            ),
          ),
          for (int i = 0; i < periodCount; i++)
            Expanded(
              child: Text(
                i < scores.length ? scores[i].toString() : '-', 
                textAlign: TextAlign.center, 
                style: Cyber.display(13).copyWith(fontFeatures: const [FontFeature.tabularFigures()])
              ),
            ),
          Expanded(
            flex: 1,
            child: Text(
              total.toString(), 
              textAlign: TextAlign.right, 
              style: Cyber.display(14, color: widget.accent).copyWith(fontFeatures: const [FontFeature.tabularFigures()])
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamStatsComparison(BasketballTeamStats away, BasketballTeamStats home, String awayName, String homeName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Cyber.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Cyber.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(awayName.toUpperCase(), style: Cyber.label(10, color: Cyber.muted)),
              Text('TEAM STATS', style: Cyber.display(12, color: Colors.white, letterSpacing: 1.5)),
              Text(homeName.toUpperCase(), style: Cyber.label(10, color: Cyber.muted)),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatCompare('FG%', '${away.fgPct.toStringAsFixed(1)}% (${away.fgMadeApt})', '${home.fgPct.toStringAsFixed(1)}% (${home.fgMadeApt})', away.fgPct, home.fgPct),
          _buildStatCompare('3PT%', '${away.tpPct.toStringAsFixed(1)}% (${away.tpMadeApt})', '${home.tpPct.toStringAsFixed(1)}% (${home.tpMadeApt})', away.tpPct, home.tpPct),
          _buildStatCompare('FT%', '${away.ftPct.toStringAsFixed(1)}% (${away.ftMadeApt})', '${home.ftPct.toStringAsFixed(1)}% (${home.ftMadeApt})', away.ftPct, home.ftPct),
          _buildStatCompare('REB', away.rebounds.toString(), home.rebounds.toString(), away.rebounds.toDouble(), home.rebounds.toDouble()),
          _buildStatCompare('AST', away.assists.toString(), home.assists.toString(), away.assists.toDouble(), home.assists.toDouble()),
          _buildStatCompare('TO', away.turnovers.toString(), home.turnovers.toString(), -away.turnovers.toDouble(), -home.turnovers.toDouble(), invertCompare: true),
          _buildStatCompare('STL', away.steals.toString(), home.steals.toString(), away.steals.toDouble(), home.steals.toDouble()),
          _buildStatCompare('BLK', away.blocks.toString(), home.blocks.toString(), away.blocks.toDouble(), home.blocks.toDouble()),
        ],
      ),
    );
  }

  Widget _buildStatCompare(String label, String awayVal, String homeVal, double awayRaw, double homeRaw, {bool invertCompare = false}) {
    Color awayColor = Colors.white;
    Color homeColor = Colors.white;
    if (awayRaw > homeRaw) {
      awayColor = invertCompare ? Cyber.danger : widget.accent;
    } else if (homeRaw > awayRaw) {
      homeColor = invertCompare ? Cyber.danger : widget.accent;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(awayVal, style: Cyber.display(12, color: awayColor)),
              Text(label, style: Cyber.label(10, color: Cyber.muted)),
              Text(homeVal, style: Cyber.display(12, color: homeColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerTable(BasketballTeamBoxscore boxscore) {
    const double colWidth = 42.0;
    const double nameWidth = 110.0;
    
    return Container(
      decoration: BoxDecoration(
        color: Cyber.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Cyber.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pinned column
          SizedBox(
            width: nameWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCell('PLAYER', height: 36, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 12)),
                for (var p in boxscore.players)
                  _buildCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Cyber.body(12, weight: p.starter ? FontWeight.bold : FontWeight.normal)),
                        if (p.starter) Text('Starter', style: Cyber.label(8, color: Cyber.muted)),
                      ],
                    ),
                    height: 44,
                    padding: const EdgeInsets.only(left: 12),
                    alignment: Alignment.centerLeft,
                    isBordered: true,
                  ),
              ],
            ),
          ),
          
          // Scrollable columns
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildHeaderCell('MIN', width: colWidth),
                      _buildHeaderCell('PTS', width: colWidth, color: Colors.white),
                      _buildHeaderCell('REB', width: colWidth),
                      _buildHeaderCell('AST', width: colWidth),
                      _buildHeaderCell('FG', width: 56),
                      _buildHeaderCell('3PT', width: 56),
                      _buildHeaderCell('FT', width: 56),
                      _buildHeaderCell('STL', width: colWidth),
                      _buildHeaderCell('BLK', width: colWidth),
                      _buildHeaderCell('TO', width: colWidth),
                      _buildHeaderCell('PF', width: colWidth),
                      _buildHeaderCell('+/-', width: colWidth),
                    ],
                  ),
                  for (var p in boxscore.players)
                    Row(
                      children: [
                        _buildTextCell(p.minutes, width: colWidth),
                        _buildTextCell(p.points.toString(), width: colWidth, isBold: true, color: widget.accent),
                        _buildTextCell(p.rebounds.toString(), width: colWidth),
                        _buildTextCell(p.assists.toString(), width: colWidth),
                        _buildTextCell(p.fg, width: 56),
                        _buildTextCell(p.tp, width: 56),
                        _buildTextCell(p.ft, width: 56),
                        _buildTextCell(p.steals.toString(), width: colWidth),
                        _buildTextCell(p.blocks.toString(), width: colWidth),
                        _buildTextCell(p.turnovers.toString(), width: colWidth),
                        _buildTextCell(p.fouls.toString(), width: colWidth),
                        _buildTextCell(p.plusMinus, width: colWidth),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {double? width, double height = 36, Alignment alignment = Alignment.center, EdgeInsets? padding, Color color = Cyber.muted}) {
    return _buildCell(
      Text(text, style: Cyber.label(10, color: color)),
      width: width,
      height: height,
      alignment: alignment,
      padding: padding,
      isHeader: true,
    );
  }

  Widget _buildTextCell(String text, {double? width, bool isBold = false, Color color = Colors.white}) {
    return _buildCell(
      Text(
        text.isEmpty ? '-' : text,
        style: Cyber.display(12, color: color).copyWith(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontFeatures: const [FontFeature.tabularFigures()]
        ),
      ),
      width: width,
      height: 44,
      isBordered: true,
    );
  }

  Widget _buildCell(Widget child, {double? width, double height = 44, Alignment alignment = Alignment.center, EdgeInsets? padding, bool isHeader = false, bool isBordered = false}) {
    return Container(
      width: width,
      height: height,
      alignment: alignment,
      padding: padding,
      decoration: BoxDecoration(
        color: isHeader ? Cyber.panel.withValues(alpha: 0.5) : null,
        border: isBordered ? const Border(top: BorderSide(color: Cyber.border)) : null,
      ),
      child: child,
    );
  }
}
