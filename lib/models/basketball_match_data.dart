class BasketballMatchDetails {
  const BasketballMatchDetails({
    required this.league,
    required this.leagueAbbreviation,
    required this.season,
    required this.gameNote,
    required this.status,
    required this.venue,
    required this.city,
    required this.state,
    required this.country,
    required this.neutralSite,
    required this.attendance,
    required this.broadcast,
    required this.overtime,
    required this.series,
    required this.officials,
    required this.leaders,
    required this.turningPoints,
    required this.plays,
    required this.injuries,
    required this.teams,
  });

  final String league;
  final String leagueAbbreviation;
  final int season;
  final String gameNote;
  final String status;
  final String venue;
  final String city;
  final String state;
  final String country;
  final bool neutralSite;
  final int attendance;
  final String broadcast;
  final bool overtime;
  final List<BasketballSeriesNote> series;
  final List<BasketballOfficial> officials;
  final List<BasketballLeaderGroup> leaders;
  final List<BasketballTurningPoint> turningPoints;
  final List<BasketballPlay> plays;
  final List<BasketballInjuryReport> injuries;
  final List<BasketballTeamRoster> teams;
}

class BasketballSeriesNote {
  const BasketballSeriesNote({
    required this.title,
    required this.description,
    required this.summary,
    required this.completed,
  });

  final String title;
  final String description;
  final String summary;
  final bool completed;
}

class BasketballOfficial {
  const BasketballOfficial({required this.name, required this.role});
  final String name;
  final String role;
}

class BasketballLeaderGroup {
  const BasketballLeaderGroup({
    required this.team,
    required this.teamId,
    required this.leaders,
  });
  final String team;
  final String teamId;
  final List<BasketballLeader> leaders;
}

class BasketballLeader {
  const BasketballLeader({
    required this.id,
    required this.category,
    required this.label,
    required this.name,
    required this.value,
  });
  final String id;
  final String category;
  final String label;
  final String name;
  final num value;
}

class BasketballTurningPoint {
  const BasketballTurningPoint({
    required this.playId,
    required this.period,
    required this.clock,
    required this.homeWinPercentage,
    required this.awayWinPercentage,
    required this.homeScore,
    required this.awayScore,
    required this.swing,
    required this.text,
  });

  final String playId;
  final int period;
  final String clock;
  final double homeWinPercentage;
  final double awayWinPercentage;
  final int homeScore;
  final int awayScore;
  final double swing;
  final String text;
}

class BasketballCoordinate {
  const BasketballCoordinate({required this.x, required this.y});
  final double x;
  final double y;
}

class BasketballPlay {
  const BasketballPlay({
    required this.id,
    required this.period,
    required this.clock,
    required this.kind,
    required this.label,
    required this.text,
    required this.isHomeTeam,
    required this.players,
    required this.scoringPlay,
    required this.points,
    required this.homeScore,
    required this.awayScore,
    required this.shootingPlay,
    required this.made,
    required this.homeWinPercentage,
    required this.swing,
    this.coordinate,
  });

  final String id;
  final int period;
  final String clock;
  final String kind;
  final String label;
  final String text;
  final bool isHomeTeam;
  final List<String> players;
  final bool scoringPlay;
  final int points;
  final int homeScore;
  final int awayScore;
  final bool shootingPlay;
  final bool made;
  final BasketballCoordinate? coordinate;
  final double homeWinPercentage;
  final double swing;
}

class BasketballInjuryReport {
  const BasketballInjuryReport({
    required this.team,
    required this.teamId,
    required this.injuries,
  });
  final String team;
  final String teamId;
  final List<BasketballInjury> injuries;
}

class BasketballInjury {
  const BasketballInjury({
    required this.id,
    required this.name,
    required this.position,
    required this.status,
    this.date,
  });
  final String id;
  final String name;
  final String position;
  final String status;
  final DateTime? date;
}

class BasketballTeamRoster {
  const BasketballTeamRoster({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.isHome,
    required this.boxscoreAvailable,
    required this.playerCount,
    required this.playedCount,
    required this.players,
  });
  final String id;
  final String name;
  final String abbreviation;
  final bool isHome;
  final bool boxscoreAvailable;
  final int playerCount;
  final int playedCount;
  final List<BasketballRosterPlayer> players;
}

class BasketballShotSplit {
  const BasketballShotSplit({
    required this.made,
    required this.attempted,
    required this.percentage,
  });
  final int made;
  final int attempted;
  final double percentage;

  String get display => '$made-$attempted';
}

class BasketballRosterPlayer {
  const BasketballRosterPlayer({
    required this.id,
    required this.name,
    required this.shortName,
    required this.jersey,
    required this.position,
    required this.starter,
    required this.didNotPlay,
    required this.ejected,
    required this.minutes,
    required this.points,
    required this.fieldGoals,
    required this.threePointers,
    required this.freeThrows,
    required this.rebounds,
    required this.assists,
    required this.turnovers,
    required this.steals,
    required this.blocks,
    required this.offensiveRebounds,
    required this.defensiveRebounds,
    required this.fouls,
    required this.plusMinus,
    this.reason,
  });

  final String id;
  final String name;
  final String shortName;
  final String jersey;
  final String position;
  final bool starter;
  final bool didNotPlay;
  final String? reason;
  final bool ejected;
  final double minutes;
  final int points;
  final BasketballShotSplit fieldGoals;
  final BasketballShotSplit threePointers;
  final BasketballShotSplit freeThrows;
  final int rebounds;
  final int assists;
  final int turnovers;
  final int steals;
  final int blocks;
  final int offensiveRebounds;
  final int defensiveRebounds;
  final int fouls;
  final int plusMinus;
}
