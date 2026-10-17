part of '../match_discovery.dart';

Color editorialSportAccent(Sport? sport) => switch (sport) {
  Sport.cricket => AppTheme.whiteColor,
  Sport.basketball => Cyber.gold,
  Sport.motorsport => Cyber.f1Red,
  _ => Cyber.cyan,
};
Color editorialEventInk(Color color) {
  final surface = kFixtureStripDark.computeLuminance();
  for (var mix = 0; mix <= 60; mix += 10) {
    final lifted = Color.lerp(color, Colors.white, mix / 100)!;
    if ((lifted.computeLuminance() + .05) / (surface + .05) >= 4.5) {
      return lifted;
    }
  }
  return Color.lerp(color, Colors.white, .6)!;
}

TextStyle editorialText(
  BuildContext context,
  double size, {
  FontWeight weight = FontWeight.w400,
  Color? color,
}) => Cyber.bodyFor(
  context,
  size,
  weight: weight,
  color: color ?? Colors.white,
  height: 1.4,
);
String editorialStatus(String status) =>
    MatchDiscoveryTokens.statusLabels[status] ?? '';
String editorialKickoff(DateTime date, DateTime now) {
  final d = date.toLocal(), n = now.toLocal();
  final today = d.year == n.year && d.month == n.month && d.day == n.day;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return 'Starts ${today ? 'today' : '${d.day} ${months[d.month - 1]}'} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String? editorialDeadline(DateTime? date, String status, DateTime now) {
  if (date == null || !['upcoming', 'live'].contains(status)) {
    return null;
  }
  final difference = date.difference(now).inSeconds;
  if (difference <= 0) {
    return null;
  }
  final m = (difference / 60).ceil();
  return 'Closes in ${m < 60
      ? '${m}m'
      : m < 1440
      ? '${m ~/ 60}h ${m % 60}m'
      : '${(m / 1440).ceil()}d'}';
}

Color _statusColor(String status) => switch (status) {
  'live' => Cyber.red,
  'upcoming' => Cyber.gold,
  'unresolved' => Cyber.amber,
  'settled' => Cyber.success,
  _ => Cyber.muted,
};

Color editorialMatchAccent(SportMatch match, {bool followed = false}) {
  if (match.status == MatchStatus.live) {
    return Cyber.red;
  }
  if (match.status == MatchStatus.finished) {
    final result = (match.resultLine ?? '').toLowerCase();
    final leader = result
        .split(RegExp(r'\b(?:won|wins|winner|beat|defeat(?:ed)?)\b'))
        .first;
    if (!RegExp(r'draw|tie|abandon|no result').hasMatch(result)) {
      for (final team in [match.home, match.away]) {
        if ([team.name, team.shortName].any(
              (name) => name.length > 2 && leader.contains(name.toLowerCase()),
            ) &&
            RegExp(r'won|wins|winner|beat|defeat').hasMatch(result)) {
          return team.color;
        }
      }
      if (match.sport == Sport.football || match.sport == Sport.basketball) {
        final home = int.tryParse(match.homeScore ?? ''),
            away = int.tryParse(match.awayScore ?? '');
        if (home != null && away != null && home != away) {
          return home > away ? match.home.color : match.away.color;
        }
      }
    }
    return Cyber.border;
  }
  return followed ? Cyber.cyan : Cyber.border;
}

String editorialLifecycleText(String? status, String? liveContext) {
  final context = status == 'live' ? liveContext?.trim() : null;
  return '${editorialStatus(status ?? "")}${context != null && context.isNotEmpty ? " $context" : ""}';
}
