part of '../match_discovery.dart';

class EditorialMatchCard extends StatelessWidget {
  const EditorialMatchCard({
    required this.match,
    required this.onTap,
    this.compact = false,
    this.competitionLabel,
    this.followed = false,
    this.showCompetition = true,
    super.key,
  });
  final SportMatch match;
  final VoidCallback? onTap;
  final bool compact;
  final bool followed, showCompetition;
  final String? competitionLabel;
  @override
  Widget build(BuildContext context) {
    final upcoming = match.status == MatchStatus.upcoming;
    final stacked =
        !upcoming &&
        (compact ||
            match.sport == Sport.cricket ||
            match.sport == Sport.basketball);
    final timing = match.status == MatchStatus.live
        ? match.liveStatusNote ??
              (match.sport == Sport.football && match.liveMinute != null
                  ? '${match.liveMinute}′'
                  : null)
        : null;
    final session = (match.f1Sessions ?? [])
        .where((s) => s.results.isNotEmpty)
        .lastOrNull;
    return EditorialPlate(
      onTap: onTap,
      backgroundAccent: editorialMatchAccent(match, followed: followed),
      motionId: 'match:${match.id}:$compact',
      signalAccent: editorialSportAccent(match.sport),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EditorialStatusArea(
            sport: match.sport,
            label: showCompetition
                ? (competitionLabel ?? match.leagueId.toUpperCase())
                : '',
            showMarker: showCompetition,
            status: match.status.name,
            liveContext: match.status == MatchStatus.live ? timing : null,
          ),
          if (match.sport == Sport.motorsport) ...[
            Text(
              match.home.name,
              style: editorialText(context, 16, weight: FontWeight.w600),
            ),
            if (upcoming) ...[const SizedBox(height: 8), kickoffClock(context)],
            if (!upcoming && session != null) ...[
              const SizedBox(height: 12),
              Text(
                session.name,
                style: editorialText(context, 12, color: Cyber.muted),
              ),
              for (final row in session.results.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    row,
                    style: editorialText(context, 14, weight: FontWeight.w600),
                  ),
                ),
            ],
          ] else if (stacked) ...[
            teamRow(context, match.home, match.homeScore),
            const SizedBox(height: 12),
            const Divider(height: 1, color: kFixtureBorder),
            const SizedBox(height: 8),
            teamRow(context, match.away, match.awayScore),
          ] else
            LayoutBuilder(
              builder: (context, box) {
                final Widget score = match.status == MatchStatus.upcoming
                    ? kickoffClock(context)
                    : Text(
                        '${match.homeScore ?? '—'} : ${match.awayScore ?? '—'}',
                        textAlign: TextAlign.center,
                        style:
                            Cyber.display(
                              MediaQuery.sizeOf(context).width < 360
                                  ? MatchDiscoveryTokens.score
                                  : MatchDiscoveryTokens.wideScore,
                            ).copyWith(
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      );
                if (MediaQuery.sizeOf(context).width < 360 ||
                    MediaQuery.textScalerOf(context).scale(14) / 14 >= 1.4) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: identity(context, match.home)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: identity(context, match.away, away: true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      score,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: identity(context, match.home)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: score,
                    ),
                    Expanded(child: identity(context, match.away, away: true)),
                  ],
                );
              },
            ),
          if (match.resultLine != null && match.sport != Sport.football) ...[
            const SizedBox(height: 12),
            Text(
              match.resultLine!,
              style: editorialText(context, 12, color: Cyber.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget kickoffClock(BuildContext context) {
    final local = match.kickoff.toLocal();
    final clock =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return Semantics(
      label: 'Starts $clock',
      child: Text(
        clock,
        key: const ValueKey('editorial-kickoff-clock'),
        textAlign: TextAlign.center,
        style: editorialText(
          context,
          MatchDiscoveryTokens.title,
          weight: FontWeight.w500,
        ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }

  Widget identity(BuildContext context, SportTeam team, {bool away = false}) =>
      Column(
        crossAxisAlignment: away
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          TeamLogo(
            team: team,
            width: 32,
            height: 32,
            sport: match.sport,
            competition: match.leagueId,
            cutBottomRight: !away,
          ),
          const SizedBox(height: 8),
          EditorialTeamName(
            team.name,
            textAlign: away ? TextAlign.right : TextAlign.left,
          ),
        ],
      );
  TextStyle scoreStyle(BuildContext context, String score) =>
      score != '—' && !RegExp(r'\d').hasMatch(score)
      ? editorialText(context, 12, color: Cyber.muted)
      : Cyber.display(
          MatchDiscoveryTokens.score,
        ).copyWith(fontWeight: FontWeight.w700);
  Widget teamRow(BuildContext context, SportTeam team, String? value) {
    final innings = match.cricketScorecard?.innings
        .where((i) => i.teamName == team.name || i.teamName == team.shortName)
        .lastOrNull;
    final raw = value ?? innings?.scoreText ?? '—';
    final score = match.sport == Sport.cricket
        ? raw.split('(').first.trim()
        : raw;
    final note = innings?.overs != null
        ? '${innings!.overs} overs${innings.target != null ? ' · Target ${innings.target}' : ''}'
        : raw.contains('(')
        ? raw.substring(raw.indexOf('('))
        : null;
    final name = Row(
      children: [
        TeamLogo(
          team: team,
          width: compact ? 28 : 36,
          height: compact ? 28 : 36,
          sport: match.sport,
          competition: match.leagueId,
        ),
        const SizedBox(width: 12),
        Expanded(child: EditorialTeamName(team.name)),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact ||
            MediaQuery.sizeOf(context).width < 360 ||
            MediaQuery.textScalerOf(context).scale(14) / 14 >= 1.4) ...[
          name,
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(score, style: scoreStyle(context, score)),
          ),
        ] else
          Row(
            children: [
              Expanded(child: name),
              const SizedBox(width: 12),
              Text(score, style: scoreStyle(context, score)),
            ],
          ),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(note, style: editorialText(context, 12, color: Cyber.muted)),
        ],
      ],
    );
  }
}
