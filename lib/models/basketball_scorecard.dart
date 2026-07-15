class BasketballScorecard {
  const BasketballScorecard({
    required this.homeBoxscore,
    required this.awayBoxscore,
    required this.linescores,
  });
  final BasketballTeamBoxscore homeBoxscore;
  final BasketballTeamBoxscore awayBoxscore;
  final BasketballLinescores linescores;
}

class BasketballLinescores {
  const BasketballLinescores({
    required this.homeScores,
    required this.awayScores,
    required this.homeTotal,
    required this.awayTotal,
    this.periodCount = 4,
  });
  final List<int> homeScores;
  final List<int> awayScores;
  final int homeTotal;
  final int awayTotal;
  final int periodCount; // usually 4 for quarters
}

class BasketballTeamBoxscore {
  const BasketballTeamBoxscore({
    required this.teamName,
    required this.teamId,
    required this.stats,
    required this.players,
  });
  final String teamName;
  final String teamId;
  final BasketballTeamStats stats;
  final List<BasketballPlayerStat> players;
}

class BasketballTeamStats {
  const BasketballTeamStats({
    required this.fgMadeApt,
    required this.fgPct,
    required this.tpMadeApt,
    required this.tpPct,
    required this.ftMadeApt,
    required this.ftPct,
    required this.rebounds,
    required this.assists,
    required this.steals,
    required this.blocks,
    required this.turnovers,
  });
  final String fgMadeApt;
  final double fgPct;
  final String tpMadeApt;
  final double tpPct;
  final String ftMadeApt;
  final double ftPct;
  final int rebounds;
  final int assists;
  final int steals;
  final int blocks;
  final int turnovers;
}

class BasketballPlayerStat {
  const BasketballPlayerStat({
    required this.name,
    required this.starter,
    required this.minutes,
    required this.points,
    required this.fg,
    required this.tp,
    required this.ft,
    required this.rebounds,
    required this.assists,
    required this.turnovers,
    required this.steals,
    required this.blocks,
    required this.fouls,
    required this.plusMinus,
  });
  final String name;
  final bool starter;
  final String minutes;
  final int points;
  final String fg;
  final String tp;
  final String ft;
  final int rebounds;
  final int assists;
  final int turnovers;
  final int steals;
  final int blocks;
  final int fouls;
  final String plusMinus;
}
