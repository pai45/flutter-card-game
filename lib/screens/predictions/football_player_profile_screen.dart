import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../models/football_player_profile.dart';
import '../../models/league.dart';
import '../../models/league_stat_leaders.dart';
import '../../services/espn_football_player_profile_service.dart';
import '../../widgets/cyber/cyber_underline_tabs.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/team_logo.dart';
import 'widgets/standings_table.dart';

/// Full season dossier for an athlete selected from a league leaderboard.
///
/// The screen opens immediately with the leaderboard identity and then layers
/// ESPN's player profile + exact season split over it. That makes the route
/// useful even in web builds where ESPN blocks browser requests with CORS.
class FootballPlayerProfileScreen extends StatefulWidget {
  const FootballPlayerProfileScreen({
    required this.league,
    required this.leader,
    required this.seasonYear,
    this.service = const EspnFootballPlayerProfileService(),
    super.key,
  });

  final League league;
  final StatLeader leader;
  final int? seasonYear;
  final EspnFootballPlayerProfileService service;

  @override
  State<FootballPlayerProfileScreen> createState() =>
      _FootballPlayerProfileScreenState();
}

class _FootballPlayerProfileScreenState
    extends State<FootballPlayerProfileScreen> {
  late FootballPlayerProfile _profile = FootballPlayerProfile.seed(
    leader: widget.leader,
    seasonYear: widget.seasonYear,
  );
  var _loading = true;
  var _groupIndex = 0;
  var _showAll = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await widget.service.fetch(
      leagueId: widget.league.id,
      athleteId: widget.leader.athleteId,
      seasonYear: widget.seasonYear,
      team: widget.leader.team,
    );
    if (!mounted) return;
    setState(() {
      if (loaded != null) _profile = loaded;
      _loading = false;
    });
  }

  void _selectGroup(int index) {
    if (index == _groupIndex) return;
    HapticFeedback.selectionClick();
    setState(() {
      _groupIndex = index;
      _showAll = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: CyberPlainBackground(
        child: SafeArea(
          child: Column(
            children: [
              DetailTopBar(title: '${widget.league.shortCode} // DOSSIER'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    CyberSlideUpFadeIn(
                      child: _DossierHero(
                        profile: _profile,
                        accent: widget.league.accent,
                        loading: _loading,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionRule(label: 'PLAYER INTEL'),
                    const SizedBox(height: 10),
                    _IdentityGrid(profile: _profile),
                    const SizedBox(height: 18),
                    _SectionRule(
                      label: _profile.seasonYear == null
                          ? 'SEASON IMPACT'
                          : '${_profile.seasonYear} SEASON IMPACT',
                    ),
                    const SizedBox(height: 10),
                    _ImpactGrid(
                      profile: _profile,
                      accent: widget.league.accent,
                    ),
                    const SizedBox(height: 18),
                    _SectionRule(label: 'SCOUTING REPORT'),
                    const SizedBox(height: 10),
                    _SeasonStatSheet(
                      profile: _profile,
                      accent: widget.league.accent,
                      groupIndex: _groupIndex,
                      showAll: _showAll,
                      onGroup: _selectGroup,
                      onShowAll: () => setState(() => _showAll = !_showAll),
                    ),
                    if (!_profile.fromEspn) ...[
                      const SizedBox(height: 16),
                      _OfflineFeedNote(accent: widget.league.accent),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DossierHero extends StatelessWidget {
  const _DossierHero({
    required this.profile,
    required this.accent,
    required this.loading,
  });

  final FootballPlayerProfile profile;
  final Color accent;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final team = profile.team;
    final status = loading
        ? 'UPLINKING ESPN'
        : profile.fromEspn
        ? 'SCOUT COMPLETE'
        : 'CACHED LEADER DATA';
    return CyberPanel(
      accent: accent,
      glow: true,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -28,
            child: Text(
              profile.jersey ?? '•',
              style: Cyber.display(
                112,
                color: accent.withValues(alpha: 0.1),
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    loading ? Icons.sensors : Icons.verified_outlined,
                    size: 13,
                    color: loading ? Cyber.gold : Cyber.success,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status,
                    style: Cyber.label(
                      8.5,
                      color: loading ? Cyber.gold : Cyber.success,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'ESPN // SOCCER',
                    style: Cyber.label(
                      8,
                      color: Cyber.muted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  _IdentityEmblem(profile: profile, accent: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.display(
                            19,
                            color: Colors.white,
                            letterSpacing: 0.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [
                            if (profile.position != null)
                              profile.position!.toUpperCase(),
                            if (team != null) team.name.toUpperCase(),
                            if (profile.jersey != null) '#${profile.jersey}',
                          ].join('  //  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.label(
                            8.5,
                            color: Cyber.muted,
                            letterSpacing: 1.05,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (team != null) ...[
                    const SizedBox(width: 8),
                    TeamLogo(team: team, width: 40, height: 40),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ESPN does not serve reliable soccer headshots. This deliberate jersey/flag
/// identity glyph is more honest than a broken portrait request and remains
/// recognisable in offline mode.
class _IdentityEmblem extends StatelessWidget {
  const _IdentityEmblem({required this.profile, required this.accent});

  final FootballPlayerProfile profile;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final initials = profile.name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    return SizedBox(
      width: 62,
      height: 62,
      child: ClipPath(
        clipper: const OctagonClipper(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.16),
            border: Border.all(color: accent.withValues(alpha: 0.64)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                initials.isEmpty ? '?' : initials,
                style: Cyber.display(
                  19,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
              if (profile.flagUrl != null)
                Positioned(
                  right: 5,
                  bottom: 5,
                  child: ClipPath(
                    clipper: const OctagonClipper(cutRatio: 0.23),
                    child: Image.network(
                      profile.flagUrl!,
                      width: 18,
                      height: 13,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityGrid extends StatelessWidget {
  const _IdentityGrid({required this.profile});

  final FootballPlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final birth = profile.dateOfBirth;
    final rows = <_IntelDatum>[
      _IntelDatum('HEIGHT', profile.displayHeight ?? '—'),
      _IntelDatum('WEIGHT', profile.displayWeight ?? '—'),
      _IntelDatum('AGE', profile.age == null ? '—' : '${profile.age} YEARS'),
      _IntelDatum(
        'BORN',
        birth == null
            ? '—'
            : '${birth.day.toString().padLeft(2, '0')}/${birth.month.toString().padLeft(2, '0')}/${birth.year}',
      ),
      _IntelDatum('NATION', profile.citizenship ?? '—'),
      _IntelDatum(
        'STATUS',
        profile.active == null
            ? '—'
            : profile.active!
            ? 'ACTIVE'
            : 'INACTIVE',
      ),
    ];
    return CyberPanel(
      accent: Cyber.borderSubtle,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i += 2) ...[
            Row(
              children: [
                Expanded(child: _IntelCell(data: rows[i])),
                Container(
                  width: 1,
                  height: 48,
                  color: Cyber.line.withValues(alpha: 0.36),
                ),
                Expanded(child: _IntelCell(data: rows[i + 1])),
              ],
            ),
            if (i < rows.length - 2)
              Container(height: 1, color: Cyber.line.withValues(alpha: 0.36)),
          ],
        ],
      ),
    );
  }
}

class _IntelDatum {
  const _IntelDatum(this.label, this.value);
  final String label;
  final String value;
}

class _IntelCell extends StatelessWidget {
  const _IntelCell({required this.data});
  final _IntelDatum data;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.label,
          style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1.3),
        ),
        const SizedBox(height: 4),
        Text(
          data.value.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Cyber.body(12, weight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _ImpactGrid extends StatelessWidget {
  const _ImpactGrid({required this.profile, required this.accent});
  final FootballPlayerProfile profile;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ImpactMetric(
          label: 'GOALS',
          stat: profile.stat('totalGoals'),
          accent: accent,
        ),
        const SizedBox(width: 8),
        _ImpactMetric(label: 'ASSISTS', stat: profile.stat('goalAssists')),
        const SizedBox(width: 8),
        _ImpactMetric(label: 'APPS', stat: profile.stat('appearances')),
        const SizedBox(width: 8),
        _ImpactMetric(label: 'MINUTES', stat: profile.stat('minutes')),
      ],
    );
  }
}

class _ImpactMetric extends StatelessWidget {
  const _ImpactMetric({required this.label, required this.stat, this.accent});
  final String label;
  final FootballPlayerSeasonStat? stat;
  final Color? accent;

  @override
  Widget build(BuildContext context) => CyberMiniMetric(
    label: label,
    value: stat?.displayValue ?? '—',
    accent: accent,
  );
}

class _SeasonStatSheet extends StatelessWidget {
  const _SeasonStatSheet({
    required this.profile,
    required this.accent,
    required this.groupIndex,
    required this.showAll,
    required this.onGroup,
    required this.onShowAll,
  });

  final FootballPlayerProfile profile;
  final Color accent;
  final int groupIndex;
  final bool showAll;
  final ValueChanged<int> onGroup;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final groups = profile.statGroups;
    if (groups.isEmpty) {
      return CyberPanel(
        accent: Cyber.borderSubtle,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            'Season stat split is waiting on the ESPN feed.',
            style: Cyber.body(13, color: Cyber.muted),
          ),
        ),
      );
    }
    final index = groupIndex.clamp(0, groups.length - 1);
    final group = groups[index];
    final nonZero = group.stats.where((stat) => stat.value != 0).toList();
    final visible = showAll ? group.stats : nonZero.take(12).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CyberUnderlineTabs(
          labels: [for (final entry in groups) _groupLabel(entry.key)],
          activeIndex: index,
          accent: accent,
          height: 42,
          minTabWidth: 96,
          onTap: onGroup,
        ),
        const SizedBox(height: 10),
        Column(
          children: [
            for (var i = 0; i < visible.length; i += 2) ...[
              Row(
                children: [
                  Expanded(
                    child: _SeasonStatCell(
                      stat: visible[i],
                      accent: i == 0 ? accent : null,
                    ),
                  ),
                  if (i + 1 < visible.length) ...[
                    const SizedBox(width: 8),
                    Expanded(child: _SeasonStatCell(stat: visible[i + 1])),
                  ] else
                    const Expanded(child: SizedBox()),
                ],
              ),
              if (i + 2 < visible.length) const SizedBox(height: 8),
            ],
            if (group.stats.length > visible.length) ...[
              const SizedBox(height: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onShowAll();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(
                    showAll
                        ? 'COLLAPSE TO ACTIVE SIGNALS'
                        : 'OPEN ALL ${group.stats.length} ESPN SIGNALS',
                    textAlign: TextAlign.center,
                    style: Cyber.label(8.5, color: accent, letterSpacing: 1.25),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  static String _groupLabel(String key) => switch (key) {
    'offensive' => 'ATTACK',
    'defensive' => 'DEFENCE',
    'goalKeeping' => 'KEEPING',
    _ => 'GENERAL',
  };
}

class _SeasonStatCell extends StatelessWidget {
  const _SeasonStatCell({required this.stat, this.accent});
  final FootballPlayerSeasonStat stat;
  final Color? accent;

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const HudChamferClipper(bigCut: 7, smallCut: 2),
    child: Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: Cyber.bg2,
        border: Border.all(
          color: (accent ?? Cyber.line).withValues(alpha: 0.38),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1.0),
          ),
          const SizedBox(height: 3),
          Text(
            stat.displayValue,
            style: Cyber.display(
              15,
              color: accent ?? Colors.white,
              letterSpacing: 0.4,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    ),
  );
}

class _OfflineFeedNote extends StatelessWidget {
  const _OfflineFeedNote({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) => CyberPanel(
    accent: Cyber.amber,
    padding: const EdgeInsets.all(12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.cloud_off_outlined, size: 18, color: Cyber.amber),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'ESPN’s live dossier could not be reached. The verified leaderboard identity remains available; reopen when the feed is online for the full season split.',
            style: Cyber.body(
              12,
              color: Cyber.muted,
              weight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionRule extends StatelessWidget {
  const _SectionRule({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SectionLabel(label: label),
      const SizedBox(width: 10),
      Expanded(
        child: Container(height: 1, color: Cyber.line.withValues(alpha: 0.3)),
      ),
    ],
  );
}
