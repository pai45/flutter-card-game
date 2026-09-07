import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../data/team_palettes.dart';
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
    if (match.sport == Sport.motorsport) {
      return _GrandPrixSummaryHeader(match: match);
    }
    return _TeamMatchSummaryHeader(match: match);
  }
}

const double _crestSize = 44;

/// Distance from the screen edge to the header frame and to each team block.
const double _edgeInset = 16;

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(_edgeInset, 0, _edgeInset, 12),
      child: CustomPaint(
        painter: const _HeaderBracketsPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _TeamIdentity(
                      team: match.home,
                      score: match.homeScore,
                      sport: match.sport,
                      competition: match.leagueId,
                      cutBottomRight: true,
                    ),
                  ),
                  if (match.sport != Sport.cricket)
                    SizedBox(
                      width: match.hasScore ? 72 : 22,
                      height: _crestSize,
                      child: Center(
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
                      ),
                    )
                  else
                    SizedBox(
                      width: 40,
                      height: _crestSize,
                      child: Center(
                        child: Text(
                          'vs',
                          style: Cyber.display(12, color: Cyber.muted),
                        ),
                      ),
                    ),
                  Expanded(
                    child: _TeamIdentity(
                      team: match.away,
                      score: match.awayScore,
                      sport: match.sport,
                      competition: match.leagueId,
                      cutBottomRight: false,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Container(height: 3, color: homeColor)),
                  const SizedBox(width: 3),
                  Expanded(child: Container(height: 3, color: awayColor)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Crest above the club name, so each side of the scoreline reads as one
/// stacked identity block instead of a logo with the name floating beside it.
///
/// The block hugs its own outer edge of the header — home to the left, away to
/// the right (via [alignEnd]) — so both crests sit [_edgeInset] from the screen
/// edge and the score reads between them.
class _TeamIdentity extends StatelessWidget {
  const _TeamIdentity({
    required this.team,
    required this.score,
    required this.sport,
    required this.competition,
    required this.cutBottomRight,
    this.alignEnd = false,
  });

  final SportTeam team;
  final String? score;
  final Sport sport;
  final String competition;
  final bool cutBottomRight;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final align = alignEnd ? TextAlign.end : TextAlign.start;
    // Cricket carries its runs/wickets beside the crest and the innings
    // qualifier (overs, chase target) as a muted line under the club name, the
    // same split the SCORECARD innings header uses.
    final innings = sport == Sport.cricket
        ? _splitCricketScore(score)
        : const (runs: null, detail: null);
    final crest = TeamLogo(
      team: team,
      width: _crestSize,
      height: _crestSize,
      cutBottomRight: cutBottomRight,
      sport: sport,
      competition: competition,
    );
    final runs = innings.runs;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (runs == null)
          crest
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!alignEnd) crest,
              if (!alignEnd) const SizedBox(width: 10),
              Flexible(
                child: Text(
                  runs,
                  textAlign: align,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      Cyber.display(
                        15,
                        color: Colors.white,
                        letterSpacing: 0,
                      ).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
              if (alignEnd) const SizedBox(width: 10),
              if (alignEnd) crest,
            ],
          ),
        const SizedBox(height: 8),
        Text(
          team.name,
          textAlign: align,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: Cyber.body(13, color: Colors.white, weight: FontWeight.w800),
        ),
        if (innings.detail != null) ...[
          const SizedBox(height: 4),
          Text(
            innings.detail!.toUpperCase(),
            textAlign: align,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                Cyber.label(
                  8.5,
                  color: Cyber.muted,
                  letterSpacing: 1,
                ).copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ],
      ],
    );
  }
}

/// Splits a cricket score such as `161/5 (18/20 ov, target 156)` into the
/// runs/wickets figure shown beside the crest and the parenthesised innings
/// qualifier shown under the club name. Either half may be absent.
({String? runs, String? detail}) _splitCricketScore(String? score) {
  final raw = score?.trim() ?? '';
  if (raw.isEmpty) return const (runs: null, detail: null);
  final open = raw.indexOf('(');
  if (open < 0) return (runs: raw, detail: null);
  final close = raw.lastIndexOf(')');
  final detail = (close > open ? raw.substring(open + 1, close) : raw.substring(open + 1))
      .trim();
  final runs = raw.substring(0, open).trim();
  if (runs.isEmpty) return (runs: raw, detail: null);
  return (runs: runs, detail: detail.isEmpty ? null : detail);
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
