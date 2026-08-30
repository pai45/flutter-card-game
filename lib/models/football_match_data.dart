/// Football-specific match metadata supplied by the normalized match package.
class FootballMatchDetails {
  const FootballMatchDetails({
    required this.league,
    required this.season,
    required this.status,
    required this.completed,
    required this.venue,
    required this.city,
    required this.country,
    required this.neutralSite,
    required this.attendance,
    required this.scoreDisplay,
    required this.winner,
    required this.scorers,
  });

  final String league;
  final String season;
  final String status;
  final bool completed;
  final String venue;
  final String city;
  final String country;
  final bool neutralSite;
  final int attendance;
  final String scoreDisplay;
  final String? winner;
  final List<FootballScorer> scorers;
}

class FootballScorer {
  const FootballScorer({
    required this.id,
    required this.name,
    required this.team,
    required this.teamId,
    required this.minute,
    required this.period,
    required this.type,
    required this.shootout,
    this.assist,
  });

  final String id;
  final String name;
  final String team;
  final String teamId;
  final String minute;
  final int period;
  final String type;
  final String? assist;
  final bool shootout;
}

/// One signed sample in the match-pressure trace. Positive [value] favours the
/// home side, negative favours the away side.
class FootballMomentumPoint {
  const FootballMomentumPoint({
    required this.minute,
    required this.home,
    required this.away,
    required this.value,
  });

  final int minute;
  final double home;
  final double away;
  final double value;
}

class FootballMomentumGoal {
  const FootballMomentumGoal({
    required this.minute,
    required this.axis,
    required this.clock,
    required this.isHomeTeam,
    required this.team,
    required this.player,
  });

  final int minute;
  final int axis;
  final String clock;
  final bool isHomeTeam;
  final String team;
  final String player;
}

class FootballMomentum {
  const FootballMomentum({
    required this.totalMinutes,
    required this.halftimeMinute,
    required this.homeTeam,
    required this.awayTeam,
    required this.series,
    required this.goals,
  });

  final int totalMinutes;
  final int halftimeMinute;
  final String homeTeam;
  final String awayTeam;
  final List<FootballMomentumPoint> series;
  final List<FootballMomentumGoal> goals;

  FootballMomentumPoint? get homePeak {
    if (series.isEmpty) return null;
    return series.reduce((a, b) => a.value >= b.value ? a : b);
  }

  FootballMomentumPoint? get awayPeak {
    if (series.isEmpty) return null;
    return series.reduce((a, b) => a.value <= b.value ? a : b);
  }
}
