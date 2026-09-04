import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../data/team_palettes.dart';
import '../../../models/sport_match.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Shared furniture for the football / cricket / basketball STATS views, built
/// on the pick market-detail language so a match report and a pick market read
/// as the same surface.

/// The hero block at the top of every STATS OVERVIEW — the match's single most
/// interesting number, sized like the market detail's leading-probability
/// treatment.
///
/// The chamfered silhouette, the 34pt figure in the leading side's colour and
/// the movement chip beside it are lifted from the market header.
class MatchPulseHeader extends StatelessWidget {
  const MatchPulseHeader({
    required this.match,
    required this.title,
    required this.statusLabel,
    required this.heroValue,
    required this.heroLabel,
    required this.heroCaption,
    required this.heroColor,
    required this.metrics,
    this.subtitle,
    this.delta,
    this.deltaSuffix,
    this.deltaDecimals = 0,
    super.key,
  });

  final SportMatch match;
  final String title;
  final String statusLabel;

  /// Pre-formatted so each sport keeps its own unit (68%, 9.4, 161/5).
  final String heroValue;
  final String heroLabel;
  final String heroCaption;
  final Color heroColor;
  final List<Widget> metrics;
  final String? subtitle;
  final double? delta;
  final String? deltaSuffix;
  final int deltaDecimals;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (match.status) {
      MatchStatus.live => Cyber.danger,
      MatchStatus.finished => Cyber.cyan,
      MatchStatus.upcoming => Cyber.gold,
    };

    return ClipPath(
      clipper: const HudChamferClipper(bigCut: 16, smallCut: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CyberStatPill(
                  label: _sportLabel(match.sport),
                  color: Cyber.magenta,
                ),
                const SizedBox(width: 8),
                CyberStatPill(label: statusLabel, color: statusColor),
                const Spacer(),
                Flexible(
                  child: Text(
                    match.leagueId.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: Cyber.label(10, color: Cyber.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: Cyber.display(18, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            _HeroFigure(
              value: heroValue,
              label: heroLabel,
              caption: heroCaption,
              color: heroColor,
              delta: delta,
              deltaSuffix: deltaSuffix,
              deltaDecimals: deltaDecimals,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Text(
                subtitle!,
                style: Cyber.body(
                  12,
                  color: Cyber.muted,
                  weight: FontWeight.w700,
                ),
              ),
            ],
            if (metrics.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < metrics.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    metrics[i],
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The big number fades up on entry so arriving at STATS lands as a beat rather
/// than a static readout.
class _HeroFigure extends StatelessWidget {
  const _HeroFigure({
    required this.value,
    required this.label,
    required this.caption,
    required this.color,
    required this.delta,
    required this.deltaSuffix,
    required this.deltaDecimals,
  });

  final String value;
  final String label;
  final String caption;
  final Color color;
  final double? delta;
  final String? deltaSuffix;
  final int deltaDecimals;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 620),
            curve: Curves.easeOutCubic,
            builder: (context, progress, child) => Opacity(
              opacity: progress,
              child: Transform.translate(
                offset: Offset(0, (1 - progress) * 8),
                child: child,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: Cyber.display(
                  34,
                  color: color,
                  letterSpacing: 0,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.label(10, color: Colors.white, letterSpacing: 1),
              ),
              const SizedBox(height: 4),
              Text(
                caption.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.label(
                  8,
                  color: Cyber.muted.withValues(alpha: 0.8),
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (delta != null && delta != 0) ...[
          const SizedBox(width: 10),
          CyberSlideUpFadeIn(
            delay: const Duration(milliseconds: 420),
            child: CyberDeltaChip(
              delta: delta!,
              suffix: deltaSuffix,
              decimals: deltaDecimals,
            ),
          ),
        ],
      ],
    );
  }
}

/// The flat data-surface shell every stat row, event card and roster row sits
/// on — the market detail outcome-row container. Tinting is opt-in via
/// [accent]; per the glow rule it never glows.
class StatsRowShell extends StatelessWidget {
  const StatsRowShell({
    required this.child,
    this.accent,
    this.selected = false,
    this.onTap,
    this.padding = const EdgeInsets.all(10),
    super.key,
  });

  final Widget child;
  final Color? accent;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final accent = this.accent;
    final surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: selected && accent != null
            ? accent.withValues(alpha: 0.12)
            : Cyber.chartSurface,
        border: Border.all(
          color: selected && accent != null
              ? accent
              : accent?.withValues(alpha: 0.4) ?? Cyber.border,
        ),
      ),
      child: child,
    );
    if (onTap == null) return surface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: surface,
    );
  }
}

/// One home-vs-away metric, shaped like a market outcome row: the two values as
/// big tabular figures either side of the label, over a split meter at the home
/// side's share. Replaces the three near-identical split-bar implementations
/// the sport views each carried.
class StatComparisonRow extends StatelessWidget {
  const StatComparisonRow({
    required this.stat,
    required this.homeColor,
    required this.awayColor,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final TeamStatLine stat;
  final Color homeColor;
  final Color awayColor;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final homeLeads = stat.homeShare >= 0.5;
    final valueStyle = Cyber.display(
      16,
      letterSpacing: 0,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

    return StatsRowShell(
      accent: homeLeads ? homeColor : awayColor,
      selected: selected,
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 62,
                child: Text(
                  stat.homeDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle.copyWith(
                    color: homeLeads ? homeColor : Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  stat.label.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1),
                ),
              ),
              SizedBox(
                width: 62,
                child: Text(
                  stat.awayDisplay,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle.copyWith(
                    color: homeLeads ? Colors.white : awayColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SplitBar(
            share: stat.homeShare,
            homeColor: homeColor,
            awayColor: awayColor,
          ),
        ],
      ),
    );
  }
}

/// Two meters back to back, split at the home share, so the pair reads as one
/// contested bar.
class _SplitBar extends StatelessWidget {
  const _SplitBar({
    required this.share,
    required this.homeColor,
    required this.awayColor,
  });

  final double share;
  final Color homeColor;
  final Color awayColor;

  @override
  Widget build(BuildContext context) {
    final homeFlex = (share * 1000).round().clamp(5, 995);
    // Each side carries its own height: a childless ColoredBox collapses to
    // zero under the row's loose cross-axis constraints.
    return Row(
      children: [
        Expanded(
          flex: homeFlex,
          child: Container(height: 6, color: homeColor),
        ),
        const SizedBox(width: 3),
        Expanded(
          flex: 1000 - homeFlex,
          child: Container(height: 6, color: awayColor),
        ),
      ],
    );
  }
}

/// Team identity marker used above a comparison block — a colour swatch, the
/// short code and the full name.
class TeamLegendMark extends StatelessWidget {
  const TeamLegendMark({
    required this.team,
    required this.sport,
    this.alignEnd = false,
    super.key,
  });

  final SportTeam team;
  final Sport sport;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final color = paletteForTeam(team, sport: sport).primary;
    final swatch = Container(width: 4, height: 30, color: color);
    final copy = Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          team.shortName.toUpperCase(),
          style: Cyber.display(13, color: color),
        ),
        Text(
          team.name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Cyber.label(8, color: Cyber.muted, letterSpacing: 0.8),
        ),
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: alignEnd
          ? [Flexible(child: copy), const SizedBox(width: 8), swatch]
          : [swatch, const SizedBox(width: 8), Flexible(child: copy)],
    );
  }
}

/// The home/away identity pair that heads a comparison block. Both sides flex,
/// so a long club name ellipsises instead of overflowing the row.
class TeamLegendRow extends StatelessWidget {
  const TeamLegendRow({required this.match, super.key});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TeamLegendMark(team: match.home, sport: match.sport),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TeamLegendMark(
            team: match.away,
            sport: match.sport,
            alignEnd: true,
          ),
        ),
      ],
    );
  }
}

String _sportLabel(Sport sport) => switch (sport) {
  Sport.football => 'FOOTBALL',
  Sport.cricket => 'CRICKET',
  Sport.basketball => 'BASKETBALL',
  Sport.tennis => 'TENNIS',
  _ => 'MATCH',
};
