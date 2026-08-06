import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/league.dart';
import '../../../models/sport_match.dart';
import '../../../models/team_standing.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/team_logo.dart';

/// Back chevron + title bar shared by the league and team detail screens.
class DetailTopBar extends StatelessWidget {
  const DetailTopBar({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              playSound(SoundEffect.uiTap);
              Navigator.of(context).maybePop();
            },
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Cyber.cyan,
                size: 18,
              ),
            ),
          ),
          Text(title, style: Cyber.display(15, letterSpacing: 1.6)),
        ],
      ),
    );
  }
}

/// League lockup: chamfered accent emblem + full name + team count. The
/// emblem is a flat accent plate rather than a glow, since it is persistent
/// chrome (glow rule).
class LeagueHeader extends StatelessWidget {
  const LeagueHeader({
    required this.league,
    required this.teamCount,
    this.subtitle,
    super.key,
  });

  final League league;
  final int teamCount;

  /// Overrides the default "N TEAMS · SEASON STANDINGS" strapline, e.g. with
  /// the live season label from the feed.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final accent = league.accent;
    final code = league.shortCode;
    return Row(
      children: [
        ClipPath(
          clipper: const HudChamferClipper(bigCut: 12, smallCut: 2),
          child: Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent,
                  Color.lerp(accent, Colors.black, 0.32) ?? accent,
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: FittedBox(
              child: Text(
                code,
                style: Cyber.display(
                  15,
                  color: _inkOn(accent),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                league.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Cyber.display(
                  19,
                  color: Colors.white,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle ?? '$teamCount TEAMS // SEASON STANDINGS',
                style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1.2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dark ink on a bright plate, white on a dark one.
Color _inkOn(Color fill) =>
    fill.computeLuminance() > 0.45 ? AppTheme.darkInk : Colors.white;

/// The league standings table. Football shows P/W/D/L/GD/PTS; cricket (rows with
/// a null [TeamStanding.drawn]) shows P/W/L/NRR/PTS. Each row taps through to the
/// team. Calm by design — no glow (glow rule) except the qualification line,
/// which is the table's single live element; rank 1 gets a gold tick only.
///
/// When rows carry [TeamStanding.goalsFor] the table widens to F/A, and when
/// they carry [TeamStanding.zoneNote] a labelled cut-off line is drawn wherever
/// the qualification zone changes (the MLS playoff line, promotion/relegation
/// elsewhere).
class StandingsTable extends StatelessWidget {
  const StandingsTable({
    required this.rows,
    required this.onTapTeam,
    this.accent = Cyber.cyan,
    this.showGoals = false,
    super.key,
  });

  final List<TeamStanding> rows;
  final ValueChanged<SportTeam> onTapTeam;
  final Color accent;

  /// Adds the F/A columns. Off by default so the narrow mock tables are
  /// unaffected.
  final bool showGoals;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Text(
        'Standings unavailable.',
        style: Cyber.body(13, color: Cyber.muted),
      );
    }
    final cricket = rows.first.drawn == null;
    final withGoals = showGoals && rows.first.goalsFor != null;
    final cols = cricket
        ? <_Col>[
            _Col('P', 22, (s) => '${s.played}'),
            _Col('W', 20, (s) => '${s.won}'),
            _Col('L', 20, (s) => '${s.lost}'),
            _Col('NRR', 42, (s) => s.diffLabel),
            _Col('PTS', 30, (s) => '${s.points}'),
          ]
        : <_Col>[
            _Col('P', 22, (s) => '${s.played}'),
            _Col('W', 20, (s) => '${s.won}'),
            _Col('D', 20, (s) => '${s.drawn}'),
            _Col('L', 20, (s) => '${s.lost}'),
            if (withGoals) _Col('F', 22, (s) => '${s.goalsFor}'),
            if (withGoals) _Col('A', 22, (s) => '${s.goalsAgainst}'),
            _Col('GD', 30, (s) => s.diffLabel),
            _Col('PTS', 30, (s) => '${s.points}'),
          ];

    return ClipPath(
      clipper: const HudChamferClipper(bigCut: 14, smallCut: 2),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff121b30), Color(0xff0e1628)],
          ),
          border: Border.all(
            color: Color.lerp(const Color(0xff243654), accent, 0.22) ??
                const Color(0xff243654),
          ),
        ),
        child: Column(
          children: [
            _HeaderRow(cols: cols),
            for (var i = 0; i < rows.length; i++) ...[
              _DataRow(
                row: rows[i],
                cols: cols,
                last: i == rows.length - 1 && _zoneAfter(i) == null,
                onTap: () => onTapTeam(rows[i].team),
              ),
              if (_zoneAfter(i) case final zone?)
                _QualificationLine(label: zone, color: rows[i].zoneColor),
            ],
          ],
        ),
      ),
    );
  }

  /// The zone label to draw *below* row [i] — set when the next row leaves the
  /// current qualification zone (or when this is the last qualifying row).
  String? _zoneAfter(int i) {
    final current = rows[i].zoneNote;
    if (current == null || current.isEmpty) return null;
    final next = i + 1 < rows.length ? rows[i + 1].zoneNote : null;
    if (next == current) return null;
    return _shortZoneLabel(current);
  }
}

/// Turns the feed's prose into a HUD cut-off label. Where the note names a
/// specific round ("Qualifies for MLS Cup Playoffs - Round One Best-of-3
/// series") that round is what distinguishes one line from the next, so it
/// wins ("ROUND ONE"); otherwise the whole note is used ("RELEGATION").
String _shortZoneLabel(String note) {
  final parts = note.split(' - ');
  if (parts.length > 1) {
    final words = parts[1].trim().split(RegExp(r'\s+'));
    return words.take(2).join(' ').toUpperCase();
  }
  var text = parts.first.trim();
  for (final prefix in const ['Qualifies for ', 'Qualification for ']) {
    if (text.startsWith(prefix)) {
      text = text.substring(prefix.length);
      break;
    }
  }
  return text.toUpperCase();
}

/// The cut-off rule under the last team inside a qualification zone. This is
/// the table's one glowing element — it marks a live, meaningful threshold.
class _QualificationLine extends StatelessWidget {
  const _QualificationLine({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Cyber.success;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 3, 10, 3),
      child: Row(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.65),
                boxShadow: Cyber.glow(tint, alpha: 0.35, blur: 8, spread: -3),
              ),
              child: const SizedBox(height: 1.4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Cyber.label(7.5, color: tint, letterSpacing: 1.1),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.cols});

  final List<_Col> cols;

  @override
  Widget build(BuildContext context) {
    Widget label(String t, {TextAlign align = TextAlign.center}) => Text(
      t,
      textAlign: align,
      style: Cyber.label(9, color: Cyber.muted, letterSpacing: 0.8),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xff243654).withValues(alpha: 0.8),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 22, child: label('#', align: TextAlign.left)),
          const SizedBox(width: 8),
          Expanded(child: label('TEAM', align: TextAlign.left)),
          for (final c in cols) SizedBox(width: c.width, child: label(c.label)),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.row,
    required this.cols,
    required this.last,
    required this.onTap,
  });

  final TeamStanding row;
  final List<_Col> cols;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rankColor = row.rank == 1 ? Cyber.gold : Cyber.muted;
    final move = row.rankChange ?? 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(
                  bottom: BorderSide(
                    color: const Color(0xff243654).withValues(alpha: 0.45),
                  ),
                ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '${row.rank}',
                style: Cyber.label(
                  12,
                  color: rankColor,
                  letterSpacing: 0.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            _RankMove(change: move),
            const SizedBox(width: 6),
            TeamLogo(team: row.team, width: 26, height: 24),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                row.tableName ?? row.team.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.body(13, weight: FontWeight.w700, height: 1),
              ),
            ),
            for (final c in cols)
              SizedBox(
                width: c.width,
                child: Text(
                  c.value(row),
                  textAlign: TextAlign.center,
                  style: Cyber.label(
                    11,
                    color: c.label == 'PTS' ? Colors.white : Cyber.muted,
                    letterSpacing: 0.2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tiny caret showing positions gained or lost since the last table update.
/// Occupies its slot even when flat so the team column never jitters.
class _RankMove extends StatelessWidget {
  const _RankMove({required this.change});

  final int change;

  @override
  Widget build(BuildContext context) {
    if (change == 0) return const SizedBox(width: 10);
    final up = change > 0;
    return SizedBox(
      width: 10,
      child: Icon(
        up ? Icons.arrow_drop_up : Icons.arrow_drop_down,
        size: 14,
        color: up ? Cyber.success : Cyber.danger,
      ),
    );
  }
}

/// Team lockup for the team detail header: badge + name + rank/points + form.
class TeamHeader extends StatelessWidget {
  const TeamHeader({required this.team, required this.standing, super.key});

  final SportTeam team;
  final TeamStanding? standing;

  @override
  Widget build(BuildContext context) {
    final s = standing;
    return Row(
      children: [
        TeamLogo(team: team, width: 54, height: 54),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                team.name,
                style: Cyber.display(
                  19,
                  color: Colors.white,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 5),
              if (s != null)
                Row(
                  children: [
                    Text(
                      'RANK #${s.rank}  ·  ${s.points} PTS',
                      style: Cyber.label(
                        10,
                        color: Cyber.muted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    FormPips(form: s.form),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Recent-form chips (most recent last): W green, D muted, L red.
class FormPips extends StatelessWidget {
  const FormPips({required this.form, super.key});

  final String form;

  @override
  Widget build(BuildContext context) {
    Color colorFor(String c) => switch (c) {
      'W' => Cyber.success,
      'L' => Cyber.danger,
      _ => Cyber.muted,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in form.split(''))
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 14,
              height: 14,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorFor(c).withValues(alpha: 0.16),
                border: Border.all(color: colorFor(c).withValues(alpha: 0.7)),
              ),
              child: Text(
                c,
                style: Cyber.label(7, color: colorFor(c), letterSpacing: 0),
              ),
            ),
          ),
      ],
    );
  }
}

class _Col {
  const _Col(this.label, this.width, this.value);

  final String label;
  final double width;
  final String Function(TeamStanding) value;
}
