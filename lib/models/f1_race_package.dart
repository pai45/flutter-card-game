/// Models for the bundled F1 race-weekend package
/// (`assets/data/f1-italian-gp.json`, written by `tool/generate_f1_race.dart`).
///
/// Nullability here is load-bearing rather than defensive. ESPN omits a field
/// when it has nothing to say, and for F1 the absence is the information:
/// only lead-lap finishers carry a `totalTime`, only the outright fastest-lap
/// setter carries a `fastestLap`, and a driver knocked out in Q1 simply has no
/// Q2/Q3 entry. Defaulting any of those to zero would claim a 0.000s lap.
/// See docs/data/f1-race-field-inventory.md.
library;

/// One `[value, displayValue]` stat pair — the same encoding the football and
/// cricket league packages use: the number sorts, the string renders.
class F1Stat {
  const F1Stat({required this.value, required this.display});

  final double value;
  final String display;

  static F1Stat? fromJson(Object? raw) {
    if (raw is! List || raw.length < 2) return null;
    final value = raw[0];
    if (value is! num) return null;
    return F1Stat(value: value.toDouble(), display: '${raw[1]}');
  }
}

class F1LapRecord {
  const F1LapRecord({this.driverId, this.time, this.year});

  final String? driverId;
  final String? time;
  final int? year;

  bool get isEmpty => time == null;
}

class F1Circuit {
  const F1Circuit({
    required this.id,
    required this.fullName,
    required this.diagrams,
    this.city,
    this.country,
    this.countryFlag,
    this.lengthKm,
    this.distanceKm,
    this.laps,
    this.turns,
    this.direction,
    this.established,
    this.lapRecord = const F1LapRecord(),
    this.photo,
  });

  final String id;
  final String fullName;
  final String? city;
  final String? country;
  final String? countryFlag;
  final double? lengthKm;
  final double? distanceKm;
  final int? laps;
  final int? turns;
  final String? direction;
  final int? established;
  final F1LapRecord lapRecord;

  /// Track maps keyed by variant (`circuit`, `circuitDark`, `circuitInfo`,
  /// `day`, ...). Values are SVG URLs on ESPN's CDN.
  final Map<String, String> diagrams;
  final String? photo;

  /// Prefers the dark variant, since every surface in this app is dark.
  String? get trackMap =>
      diagrams['circuitDark'] ?? diagrams['circuit'] ?? diagrams['dayDark'];

  String get locationLabel {
    final parts = [city, country].whereType<String>().where((p) => p.isNotEmpty);
    return parts.join(', ');
  }
}

class F1Driver {
  const F1Driver({
    required this.id,
    required this.displayName,
    this.fullName,
    this.shortName,
    this.abbreviation,
    this.countryFlag,
    this.countryName,
    this.headshot,
    this.number,
    this.constructorId,
    this.team,
    this.engine,
    this.tire,
    this.birthPlace,
    this.dateOfBirth,
  });

  final String id;
  final String displayName;
  final String? fullName;
  final String? shortName;
  final String? abbreviation;
  final String? countryFlag;
  final String? countryName;
  final String? headshot;
  final String? number;
  final String? constructorId;
  final String? team;
  final String? engine;
  final String? tire;
  final String? birthPlace;
  final String? dateOfBirth;

  /// Three-letter code for chart legends and grid rows; falls back to the first
  /// three letters of the surname when ESPN has no abbreviation.
  String get code {
    final abbr = abbreviation;
    if (abbr != null && abbr.isNotEmpty) return abbr.toUpperCase();
    final last = displayName.split(' ').last;
    return last.length <= 3
        ? last.toUpperCase()
        : last.substring(0, 3).toUpperCase();
  }
}

class F1Constructor {
  const F1Constructor({
    required this.id,
    required this.name,
    this.displayName,
    this.color,
  });

  final String id;
  final String name;
  final String? displayName;

  /// ESPN hex without the `#`. There are no constructor logos (they 404), so
  /// this colour is the only team identity available.
  final String? color;
}

/// One driver's line in one session's results.
class F1ClassificationEntry {
  const F1ClassificationEntry({
    required this.position,
    required this.driverId,
    required this.stats,
    this.grid,
    this.winner = false,
    this.number,
    this.constructorName,
    this.teamColor,
    this.statusName,
    this.statusDescription,
    this.statusCompleted,
    this.statusLaps,
  });

  final int position;
  final String driverId;

  /// Starting slot. Set on the race session only, and it is **not** the
  /// qualifying position: at Monza the winner qualified 7th and started 19th
  /// after a penalty.
  final int? grid;
  final bool winner;
  final String? number;
  final String? constructorName;
  final String? teamColor;
  final String? statusName;
  final String? statusDescription;
  final bool? statusCompleted;
  final int? statusLaps;
  final Map<String, F1Stat> stats;

  F1Stat? stat(String name) => stats[name];
  double? value(String name) => stats[name]?.value;
  String? display(String name) => stats[name]?.display;

  bool get retired => statusName == 'STATUS_RETIRED';

  /// Positions made up from the grid. Null outside the race, where there is no
  /// starting order to compare against.
  int? get positionsGained {
    final from = grid;
    return from == null ? null : from - position;
  }
}

class F1Session {
  const F1Session({
    required this.id,
    required this.order,
    required this.abbreviation,
    required this.classification,
    required this.stats,
    this.typeId,
    this.text,
    this.date,
  });

  final String id;
  final int order;

  /// `FP1` / `FP2` / `FP3` / `Qual` / `Race`.
  final String abbreviation;
  final String? typeId;
  final String? text;
  final String? date;
  final Map<String, F1Stat> stats;
  final List<F1ClassificationEntry> classification;

  bool get isRace => abbreviation.toLowerCase() == 'race';
  bool get isQualifying => abbreviation.toLowerCase().startsWith('qual');
  bool get isPractice => abbreviation.toUpperCase().startsWith('FP');

  F1ClassificationEntry? entryFor(String driverId) {
    for (final entry in classification) {
      if (entry.driverId == driverId) return entry;
    }
    return null;
  }
}

class F1StandingsRow {
  const F1StandingsRow({
    required this.id,
    required this.byRace,
    this.rank,
    this.name,
    this.points,
  });

  /// Driver id on the drivers table, constructor id on the constructors table.
  final String id;
  final int? rank;
  final String? name;
  final int? points;

  /// Points per round keyed by the 3-letter GP code. A round the entrant has
  /// not reached is absent rather than zero.
  final Map<String, int> byRace;
}

class F1SeasonStandings {
  const F1SeasonStandings({
    required this.raceCodes,
    required this.drivers,
    required this.constructors,
    this.season,
    this.throughRace,
  });

  const F1SeasonStandings.empty()
    : raceCodes = const [],
      drivers = const [],
      constructors = const [],
      season = null,
      throughRace = null;

  final int? season;
  final String? throughRace;
  final List<String> raceCodes;
  final List<F1StandingsRow> drivers;
  final List<F1StandingsRow> constructors;

  /// Only the rounds actually scored so far — the feed lists all 25 codes for
  /// the season, including races that have not happened.
  List<String> get racedCodes => [
    for (final code in raceCodes)
      if (drivers.any((row) => row.byRace.containsKey(code))) code,
  ];
}

class F1RacePackage {
  const F1RacePackage({
    required this.raceId,
    required this.name,
    required this.drivers,
    required this.constructors,
    required this.sessions,
    required this.statDictionary,
    this.shortName,
    this.abbreviation,
    this.season,
    this.startDate,
    this.endDate,
    this.circuit,
    this.standings = const F1SeasonStandings.empty(),
  });

  final String raceId;
  final String name;
  final String? shortName;

  /// Three-letter GP code (`ITA`) — also the key into the standings grid.
  final String? abbreviation;
  final int? season;
  final String? startDate;
  final String? endDate;
  final F1Circuit? circuit;
  final Map<String, F1Driver> drivers;
  final Map<String, F1Constructor> constructors;
  final List<F1Session> sessions;
  final F1SeasonStandings standings;
  final Map<String, String> statDictionary;

  F1Session? get race => _session((s) => s.isRace);
  F1Session? get qualifying => _session((s) => s.isQualifying);
  List<F1Session> get practice =>
      sessions.where((s) => s.isPractice).toList(growable: false);

  /// Practice, then qualifying — the timed build-up, in running order.
  List<F1Session> get timedSessions =>
      sessions.where((s) => !s.isRace).toList(growable: false);

  F1Session? _session(bool Function(F1Session) test) {
    for (final session in sessions) {
      if (test(session)) return session;
    }
    return null;
  }

  F1Driver? driver(String id) => drivers[id];

  F1Constructor? constructorFor(String? id) =>
      id == null ? null : constructors[id];

  F1ClassificationEntry? get winner {
    final entries = race?.classification;
    if (entries == null || entries.isEmpty) return null;
    return entries.first;
  }
}
