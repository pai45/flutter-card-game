import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/league.dart';
import '../../../models/sport_match.dart';
import '../../../models/team_standing.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

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
              child: Icon(Icons.arrow_back_ios_new, color: Cyber.cyan, size: 18),
            ),
          ),
          Text(
            title,
            style: Cyber.display(15, letterSpacing: 1.6),
          ),
        ],
      ),
    );
  }
}

/// League lockup: chamfered accent emblem + full name + team count.
class LeagueHeader extends StatelessWidget {
  const LeagueHeader({required this.league, required this.teamCount, super.key});

  final League league;
  final int teamCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipPath(
          clipper: const HudChamferClipper(bigCut: 12, smallCut: 2),
          child: Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  league.accent,
                  Color.lerp(league.accent, Colors.black, 0.45)!,
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Text(
              league.shortCode,
              style: Cyber.display(15, color: Colors.white, letterSpacing: 0.5),
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
                style: Cyber.display(19, color: Colors.white, letterSpacing: 0.4),
              ),
              const SizedBox(height: 4),
              Text(
                '$teamCount TEAMS · SEASON STANDINGS',
                style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1.2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The league standings table. Football shows P/W/D/L/GD/PTS; cricket (rows with
/// a null [TeamStanding.drawn]) shows P/W/L/NRR/PTS. Each row taps through to the
/// team. Calm by design — no glow (glow rule); rank 1 gets a gold tick only.
class StandingsTable extends StatelessWidget {
  const StandingsTable({
    required this.rows,
    required this.onTapTeam,
    super.key,
  });

  final List<TeamStanding> rows;
  final ValueChanged<SportTeam> onTapTeam;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Text(
        'Standings unavailable.',
        style: Cyber.body(12.5, color: Cyber.muted),
      );
    }
    final cricket = rows.first.drawn == null;
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
          border: Border.all(color: const Color(0xff243654)),
        ),
        child: Column(
          children: [
            _HeaderRow(cols: cols),
            for (var i = 0; i < rows.length; i++)
              _DataRow(
                row: rows[i],
                cols: cols,
                last: i == rows.length - 1,
                onTap: () => onTapTeam(rows[i].team),
              ),
          ],
        ),
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
      style: Cyber.label(8.5, color: Cyber.muted, letterSpacing: 0.8),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        border: Border(
          bottom: BorderSide(color: const Color(0xff243654).withValues(alpha: 0.8)),
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
            const SizedBox(width: 8),
            _TeamBadge(team: row.team),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                row.team.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.body(12.5, weight: FontWeight.w700, height: 1),
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

class _TeamBadge extends StatelessWidget {
  const _TeamBadge({required this.team});

  final SportTeam team;

  @override
  Widget build(BuildContext context) {
    final light = team.color.computeLuminance() > 0.55;
    return Container(
      width: 28,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: team.color,
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          team.shortName,
          style: Cyber.label(
            8,
            color: light ? const Color(0xff15202e) : Colors.white,
            letterSpacing: 0.2,
          ),
        ),
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
        ClipPath(
          clipper: const HudChamferClipper(bigCut: 12, smallCut: 2),
          child: Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  team.color,
                  Color.lerp(team.color, Colors.black, 0.4)!,
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Text(
              team.shortName,
              style: Cyber.display(
                14,
                color: team.color.computeLuminance() > 0.55
                    ? const Color(0xff15202e)
                    : Colors.white,
                letterSpacing: 0.4,
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
                team.name,
                style: Cyber.display(19, color: Colors.white, letterSpacing: 0.4),
              ),
              const SizedBox(height: 5),
              if (s != null)
                Row(
                  children: [
                    Text(
                      'RANK #${s.rank}  ·  ${s.points} PTS',
                      style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1),
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
