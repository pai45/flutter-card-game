import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/sport_match.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/team_logo.dart';

/// Compact neutral fixture card used by the team hub's MATCHES tab.
class TeamSeasonMatchCard extends StatelessWidget {
  const TeamSeasonMatchCard({
    required this.match,
    required this.onTap,
    this.competition,
    super.key,
  });

  final SportMatch match;
  final VoidCallback onTap;
  final String? competition;

  @override
  Widget build(BuildContext context) {
    final color = switch (match.status) {
      MatchStatus.live => Cyber.danger,
      MatchStatus.finished => Cyber.success,
      MatchStatus.upcoming => Cyber.cyan,
    };
    final status = switch (match.status) {
      MatchStatus.live => 'LIVE',
      MatchStatus.finished => 'FINAL',
      MatchStatus.upcoming => _time(match.kickoff),
    };
    return Semantics(
      button: true,
      label: 'Open ${match.home.name} versus ${match.away.name}',
      child: PressableScale(
        onTap: onTap,
        child: CyberPanel(
          accent: color,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            children: [
              Row(
                children: [
                  CyberStatusPill(label: status, color: color),
                  const Spacer(),
                  Text(
                    _date(match.kickoff),
                    style: Cyber.label(8, color: Cyber.muted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Team(
                      team: match.home,
                      sport: match.sport,
                      competition: competition,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      children: [
                        Text(
                          match.hasScore
                              ? '${match.homeScore ?? '-'}  -  ${match.awayScore ?? '-'}'
                              : 'VS',
                          style: Cyber.display(20, color: Colors.white),
                        ),
                        if (match.resultLine != null) ...[
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 126,
                            child: Text(
                              match.resultLine!.toUpperCase(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Cyber.label(7.5, color: Cyber.muted),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: _Team(
                      team: match.away,
                      sport: match.sport,
                      competition: competition,
                      alignEnd: true,
                    ),
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

class _Team extends StatelessWidget {
  const _Team({
    required this.team,
    required this.sport,
    required this.competition,
    this.alignEnd = false,
  });

  final SportTeam team;
  final Sport sport;
  final String? competition;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      TeamLogo(
        team: team,
        sport: sport,
        competition: competition,
        width: 34,
        height: 34,
      ),
      const SizedBox(height: 6),
      Text(
        team.shortName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Cyber.display(10, color: Colors.white),
      ),
    ],
  );
}

String _date(DateTime value) {
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${value.day.toString().padLeft(2, '0')} ${months[value.month - 1]} ${value.year}';
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
