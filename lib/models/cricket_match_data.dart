class CricketMatchDetails {
  const CricketMatchDetails({
    required this.league,
    required this.leagueAbbreviation,
    required this.season,
    required this.title,
    required this.stage,
    required this.format,
    required this.formatName,
    required this.status,
    required this.state,
    required this.result,
    required this.seriesNote,
    required this.venue,
    required this.city,
    required this.country,
    required this.neutralSite,
    required this.toss,
    required this.innings,
    required this.awards,
    required this.officials,
    required this.notes,
    required this.commentary,
    required this.teams,
  });

  final String league;
  final String leagueAbbreviation;
  final int season;
  final String title;
  final String stage;
  final String format;
  final String formatName;
  final String status;
  final String state;
  final String result;
  final String seriesNote;
  final String venue;
  final String city;
  final String country;
  final bool neutralSite;
  final CricketToss toss;
  final List<CricketInningsSummary> innings;
  final List<CricketAward> awards;
  final List<CricketOfficial> officials;
  final List<CricketMatchNote> notes;
  final List<CricketBallCommentary> commentary;
  final List<CricketTeamSquad> teams;
}

class CricketToss {
  const CricketToss({required this.team, required this.decision});
  final String team;
  final String decision;
}

class CricketInningsSummary {
  const CricketInningsSummary({
    required this.number,
    required this.team,
    required this.teamId,
    required this.abbreviation,
    required this.runs,
    required this.wickets,
    required this.overs,
    required this.fours,
    required this.sixes,
    required this.score,
    required this.description,
    required this.current,
    this.target,
  });
  final int number;
  final String team;
  final String teamId;
  final String abbreviation;
  final int runs;
  final int wickets;
  final double overs;
  final int fours;
  final int sixes;
  final int? target;
  final String score;
  final String description;
  final bool current;
}

class CricketAward {
  const CricketAward({
    required this.id,
    required this.name,
    required this.award,
    required this.team,
    required this.teamId,
  });
  final String id;
  final String name;
  final String award;
  final String team;
  final String teamId;
}

class CricketOfficial {
  const CricketOfficial({
    required this.name,
    required this.role,
    required this.country,
  });
  final String name;
  final String role;
  final String country;
}

class CricketMatchNote {
  const CricketMatchNote({
    required this.id,
    required this.innings,
    required this.day,
    required this.kind,
    required this.text,
  });
  final String id;
  final int innings;
  final int day;
  final String kind;
  final String text;
}

class CricketRequiredRate {
  const CricketRequiredRate({
    required this.runs,
    required this.balls,
    required this.runRate,
  });
  final int runs;
  final int balls;
  final double runRate;
}

class CricketBallCommentary {
  const CricketBallCommentary({
    required this.id,
    required this.sequence,
    required this.innings,
    required this.over,
    required this.overNumber,
    required this.ball,
    required this.batter,
    required this.bowler,
    required this.runs,
    required this.boundary,
    required this.wicket,
    required this.score,
    required this.runRate,
    required this.shortText,
    required this.text,
    this.dismissal,
    this.required,
    this.preText,
    this.postText,
  });
  final String id;
  final int sequence;
  final int innings;
  final String over;
  final int overNumber;
  final int ball;
  final String batter;
  final String bowler;
  final int runs;
  final bool boundary;
  final bool wicket;
  final String? dismissal;
  final String score;
  final double runRate;
  final CricketRequiredRate? required;
  final String shortText;
  final String text;
  final String? preText;
  final String? postText;
}

class CricketTeamSquad {
  const CricketTeamSquad({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.isHome,
    required this.captain,
    required this.keeper,
    required this.squadPublished,
    required this.playerCount,
    required this.players,
  });
  final String id;
  final String name;
  final String abbreviation;
  final bool isHome;
  final String captain;
  final String keeper;
  final bool squadPublished;
  final int playerCount;
  final List<CricketSquadPlayer> players;
}

class CricketPlayerPerformance {
  const CricketPlayerPerformance({
    required this.innings,
    this.battingScore,
    this.bowlingFigures,
    this.catches = 0,
    this.stumpings = 0,
  });
  final int innings;
  final String? battingScore;
  final String? bowlingFigures;
  final int catches;
  final int stumpings;
}

class CricketSquadPlayer {
  const CricketSquadPlayer({
    required this.id,
    required this.name,
    required this.fullName,
    required this.battingName,
    required this.role,
    required this.keeper,
    required this.captain,
    required this.starter,
    required this.subbedIn,
    required this.subbedOut,
    required this.active,
    required this.battingStyle,
    required this.bowlingStyle,
    required this.performances,
  });
  final String id;
  final String name;
  final String fullName;
  final String battingName;
  final String role;
  final bool keeper;
  final bool captain;
  final bool starter;
  final bool subbedIn;
  final bool subbedOut;
  final bool active;
  final String battingStyle;
  final String bowlingStyle;
  final List<CricketPlayerPerformance> performances;
}
