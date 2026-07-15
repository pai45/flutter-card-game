import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/tennis_scorecard.dart';
import '../models/sport_match.dart';

class TennisScorecardView extends StatelessWidget {
  const TennisScorecardView({
    super.key,
    required this.scorecard,
    required this.match,
    required this.accent,
  });

  final TennisScorecard scorecard;
  final SportMatch match;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Cyber.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Cyber.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderRow(),
          _buildPlayerRow(match.away.name, true),
          const Divider(height: 1, color: Cyber.border),
          _buildPlayerRow(match.home.name, false),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.5),
        border: const Border(bottom: BorderSide(color: Cyber.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text('PLAYER', style: Cyber.label(10, color: Cyber.muted)),
          ),
          for (int i = 0; i < scorecard.sets.length; i++)
            Expanded(
              child: Text(
                'SET ${i + 1}',
                textAlign: TextAlign.center,
                style: Cyber.label(10, color: Cyber.muted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(String playerName, bool isAway) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              playerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.body(13, weight: FontWeight.bold),
            ),
          ),
          for (int i = 0; i < scorecard.sets.length; i++)
            Expanded(
              child: _buildSetScore(scorecard.sets[i], isAway),
            ),
        ],
      ),
    );
  }

  Widget _buildSetScore(TennisSet setScore, bool isAway) {
    final score = isAway ? setScore.awayScore : setScore.homeScore;
    final tiebreak = isAway ? setScore.awayTiebreak : setScore.homeTiebreak;
    final isWinner = isAway ? setScore.isAwayWinner : setScore.isHomeWinner;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          score.toString(),
          style: Cyber.display(14, color: isWinner ? accent : Colors.white)
              .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        if (tiebreak != null)
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 1),
            child: Text(
              tiebreak.toString(),
              style: Cyber.label(9, color: isWinner ? accent : Cyber.muted),
            ),
          ),
      ],
    );
  }
}
