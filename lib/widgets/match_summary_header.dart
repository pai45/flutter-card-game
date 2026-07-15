import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/sport_match.dart';
import 'team_logo.dart';

/// Cyber-styled summary of the fixture represented by [match].
///
/// Team sports use the match-detail score header, while Formula One fixtures
/// use the compact Grand Prix weekend header.
class MatchSummaryHeader extends StatelessWidget {
  const MatchSummaryHeader({required this.match, super.key});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    if (match.sport == Sport.f1) {
      return _GrandPrixSummaryHeader(match: match);
    }
    return _TeamMatchSummaryHeader(match: match);
  }
}

class _TeamMatchSummaryHeader extends StatelessWidget {
  const _TeamMatchSummaryHeader({required this.match});

  final SportMatch match;

  Color get _statusColor => switch (match.status) {
    MatchStatus.upcoming => Cyber.gold,
    MatchStatus.live => Cyber.danger,
    MatchStatus.finished => Cyber.muted,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: CustomPaint(
        painter: const _HeaderBracketsPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
          child: Column(
            children: [
              Text(
                _teamStatusText(match),
                style: Cyber.display(
                  15,
                  color: _statusColor,
                  letterSpacing: 1.5,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  TeamLogo(
                    team: match.home,
                    width: 44,
                    height: 44,
                    cutBottomRight: true,
                    sport: match.sport,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TeamDetails(
                      team: match.home,
                      score: match.homeScore,
                      sport: match.sport,
                    ),
                  ),
                  if (match.sport != Sport.cricket)
                    SizedBox(
                      width: match.hasScore ? 72 : 22,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _headerScoreText(match),
                          maxLines: 1,
                          style:
                              Cyber.display(
                                match.hasScore ? 16 : 17,
                                color: match.hasScore
                                    ? Colors.white
                                    : Cyber.muted,
                                letterSpacing: 0,
                              ).copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'vs',
                        style: Cyber.display(12, color: Cyber.muted),
                      ),
                    ),
                  Expanded(
                    child: _TeamDetails(
                      team: match.away,
                      score: match.awayScore,
                      sport: match.sport,
                      alignEnd: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  TeamLogo(
                    team: match.away,
                    width: 44,
                    height: 44,
                    cutBottomRight: false,
                    sport: match.sport,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(height: 3, color: match.home.color),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Container(
                      height: 3,
                      color: match.away.color.withValues(alpha: 0.92),
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

class _TeamDetails extends StatelessWidget {
  const _TeamDetails({
    required this.team,
    required this.score,
    required this.sport,
    this.alignEnd = false,
  });

  final SportTeam team;
  final String? score;
  final Sport sport;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          team.name,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Cyber.body(14, weight: FontWeight.w800),
        ),
        if (sport == Sport.cricket && score != null && score!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            score!,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Cyber.display(12, color: Colors.white, letterSpacing: 0),
          ),
        ],
      ],
    );
  }
}

class _GrandPrixSummaryHeader extends StatelessWidget {
  const _GrandPrixSummaryHeader({required this.match});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final (statusText, statusColor) = switch (match.status) {
      MatchStatus.upcoming => ('UPCOMING', Cyber.gold),
      MatchStatus.live => ('LIVE', Cyber.danger),
      MatchStatus.finished => ('FT', Cyber.muted),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: CustomPaint(
        painter: const _HeaderBracketsPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          child: Column(
            children: [
              Text(
                statusText,
                style: Cyber.display(
                  14,
                  color: statusColor,
                  letterSpacing: 1.6,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              const SizedBox(height: 10),
              Text(
                match.home.name.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Cyber.display(20, weight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Container(height: 3, color: Cyber.cyan)),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Container(
                      height: 3,
                      color: Cyber.danger.withValues(alpha: 0.92),
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

class _HeaderBracketsPainter extends CustomPainter {
  const _HeaderBracketsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const len = 16.0;
    final paint = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, len), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);
  }

  @override
  bool shouldRepaint(covariant _HeaderBracketsPainter oldDelegate) => false;
}

String _headerScoreText(SportMatch match) {
  if (match.sport == Sport.football ||
      match.sport == Sport.basketball ||
      match.sport == Sport.tennis) {
    if (!match.hasScore) return '-';
    return '${match.homeScore ?? '-'} - ${match.awayScore ?? '-'}';
  }
  if (match.sport == Sport.cricket) {
    final home = match.homeScore;
    final away = match.awayScore;
    if (home != null && away != null) {
      return '$home  v  $away';
    }
    return home ?? away ?? '-';
  }
  return '${match.homeScore ?? '-'} - ${match.awayScore ?? '-'}';
}

String _teamStatusText(SportMatch match) => switch (match.status) {
  MatchStatus.upcoming => _formatTime(match.kickoff),
  MatchStatus.live =>
    match.liveMinute != null ? "LIVE ${match.liveMinute}'" : 'LIVE',
  MatchStatus.finished => 'FT',
};

String _formatTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
