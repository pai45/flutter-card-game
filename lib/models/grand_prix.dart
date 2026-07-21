/// Domain model for Grand Prix Dash — the one-lap top-down F1 arcade racer.
///
/// Pure data: enums, track geometry, race result, and the persisted lifetime
/// record. No Flutter/Flame imports so the race engine and tests stay pure.
library;

enum GrandPrixCircuitId {
  harbourStreet,
  desertMile,
  emeraldPark,
  mountainPass,
  coastalSprint,
}

enum GrandPrixLivery {
  gridLine,
  scarlet,
  silverArrow,
  papaya,
  midnight,
  racingGreen,
  skyBlue,
}

enum TrackSectionType { straight, corner, chicane }

enum CornerDirection { left, right }

enum LaunchGrade { perfect, great, good, slow, jump }

enum GrandPrixVerdict { win, podium, points, finished }

GrandPrixVerdict grandPrixVerdict(int position) => switch (position) {
  1 => GrandPrixVerdict.win,
  <= 3 => GrandPrixVerdict.podium,
  <= 10 => GrandPrixVerdict.points,
  _ => GrandPrixVerdict.finished,
};

GrandPrixCircuitId grandPrixCircuitFromName(String? name) =>
    GrandPrixCircuitId.values.firstWhere(
      (id) => id.name == name,
      orElse: () => GrandPrixCircuitId.emeraldPark,
    );

GrandPrixLivery grandPrixLiveryFromName(String? name) =>
    GrandPrixLivery.values.firstWhere(
      (livery) => livery.name == name,
      orElse: () => GrandPrixLivery.gridLine,
    );

/// One stretch of track. The simulation is 1D (distance along the lap plus a
/// lateral offset), so a corner only affects physics through [safeSpeed] and
/// pixels through [bend] — the sideways shift of the drawn centerline.
class TrackSection {
  const TrackSection._({
    required this.type,
    required this.length,
    this.direction,
    this.safeSpeed,
    this.wallThreshold = 14,
    this.bend = 0,
  });

  const TrackSection.straight(double length)
    : this._(type: TrackSectionType.straight, length: length);

  const TrackSection.corner({
    required double length,
    required CornerDirection direction,
    required double safeSpeed,
    double wallThreshold = 14,
    double bend = 24,
  }) : this._(
         type: TrackSectionType.corner,
         length: length,
         direction: direction,
         safeSpeed: safeSpeed,
         wallThreshold: wallThreshold,
         bend: bend,
       );

  const TrackSection.chicane({
    required double length,
    required CornerDirection direction,
    required double safeSpeed,
    double wallThreshold = 12,
    double bend = 14,
  }) : this._(
         type: TrackSectionType.chicane,
         length: length,
         direction: direction,
         safeSpeed: safeSpeed,
         wallThreshold: wallThreshold,
         bend: bend,
       );

  final TrackSectionType type;

  /// Section length in metres.
  final double length;

  /// Entry flick direction; null for straights.
  final CornerDirection? direction;

  /// Max clean entry speed (m/s); null for straights.
  final double? safeSpeed;

  /// Overspeed (m/s above [safeSpeed]) beyond which entry means wall contact.
  final double wallThreshold;

  /// Magnitude of the centerline's sideways shift through the section (m).
  /// Rendering only — see `centerlineX` in the engine.
  final double bend;

  bool get isStraight => type == TrackSectionType.straight;

  /// Signed bend: negative = left, positive = right (matches lateral axis).
  double get signedBend =>
      direction == CornerDirection.left ? -bend : bend;
}

class GrandPrixCircuit {
  const GrandPrixCircuit({
    required this.id,
    required this.name,
    required this.character,
    required this.flavor,
    required this.difficultyStars,
    required this.sections,
  });

  final GrandPrixCircuitId id;
  final String name;

  /// Short type tag, e.g. 'STREET', 'SPEEDWAY'.
  final String character;

  /// One-line lobby description.
  final String flavor;
  final int difficultyStars;
  final List<TrackSection> sections;

  double get lapLength =>
      sections.fold(0, (sum, section) => sum + section.length);
}

/// A single overtake, kept for the result screen's "MVP move" beat.
class OvertakeEvent {
  const OvertakeEvent({
    required this.overtakenName,
    required this.overtakenPosition,
    required this.atDistance,
  });

  final String overtakenName;

  /// Position the player took by the pass (lower = better move).
  final int overtakenPosition;
  final double atDistance;
}

class GrandPrixResult {
  const GrandPrixResult({
    required this.position,
    required this.fieldSize,
    required this.startPosition,
    required this.lapTimeMs,
    required this.personalBest,
    required this.launchGrade,
    required this.circuit,
    required this.xp,
    this.laps = 1,
    this.bestOvertakeName,
    this.retired = false,
  });

  final int position;
  final int fieldSize;
  final int startPosition;

  /// Total race time over all laps (single-lap races: the lap time).
  final int lapTimeMs;
  final bool personalBest;
  final LaunchGrade launchGrade;
  final GrandPrixCircuitId circuit;
  final int xp;

  /// Race distance the result was set over.
  final int laps;
  final String? bestOvertakeName;

  /// The player got stuck and timed out — a DNF, shown as GAME OVER.
  final bool retired;

  GrandPrixVerdict get verdict => grandPrixVerdict(position);
  int get placesGained => startPosition - position;
}

/// Formats a lap time in ms as `m:ss.mmm` (or `--:--.---` when unset).
String formatLapTime(int? lapTimeMs) {
  if (lapTimeMs == null || lapTimeMs <= 0) return '--:--.---';
  final minutes = lapTimeMs ~/ 60000;
  final seconds = (lapTimeMs % 60000) ~/ 1000;
  final millis = lapTimeMs % 1000;
  return '$minutes:${seconds.toString().padLeft(2, '0')}.'
      '${millis.toString().padLeft(3, '0')}';
}

/// Persisted lifetime racing record (on-device only — mirrors
/// [FootballChessStats]). Also remembers the last-used circuit/livery so a
/// returning racer can hit START RACE immediately.
class GrandPrixStats {
  const GrandPrixStats({
    this.races = 0,
    this.wins = 0,
    this.podiums = 0,
    this.bestPosition = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.bestLapMsByCircuit = const {},
    this.lastCircuit = GrandPrixCircuitId.emeraldPark,
    this.lastLivery = GrandPrixLivery.gridLine,
    this.lastLaps = 1,
  });

  factory GrandPrixStats.fromJson(Map<String, dynamic> json) {
    final rawLaps = json['bestLapMsByCircuit'];
    final laps = <String, int>{};
    if (rawLaps is Map) {
      for (final entry in rawLaps.entries) {
        final value = entry.value;
        if (value is int && value > 0) laps['${entry.key}'] = value;
      }
    }
    final lastLaps = json['lastLaps'] as int? ?? 1;
    return GrandPrixStats(
      races: json['races'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      podiums: json['podiums'] as int? ?? 0,
      bestPosition: json['bestPosition'] as int? ?? 0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      bestStreak: json['bestStreak'] as int? ?? 0,
      bestLapMsByCircuit: laps,
      lastCircuit: grandPrixCircuitFromName(json['lastCircuit'] as String?),
      lastLivery: grandPrixLiveryFromName(json['lastLivery'] as String?),
      lastLaps: lastLaps >= 1 && lastLaps <= 9 ? lastLaps : 1,
    );
  }

  final int races;
  final int wins;
  final int podiums;

  /// Best finishing position ever; 0 means no race finished yet.
  final int bestPosition;
  final int currentStreak;
  final int bestStreak;

  /// Personal-best race time per circuit+distance. Single-lap bests are keyed
  /// by [GrandPrixCircuitId.name] (the legacy key); multi-lap bests append the
  /// lap count (`emeraldPark@3L`) so distances never race each other.
  final Map<String, int> bestLapMsByCircuit;
  final GrandPrixCircuitId lastCircuit;
  final GrandPrixLivery lastLivery;

  /// Last-used race distance in laps (persisted like circuit/livery).
  final int lastLaps;

  static String _bestKey(GrandPrixCircuitId circuit, int laps) =>
      laps <= 1 ? circuit.name : '${circuit.name}@${laps}L';

  int? bestLapMs(GrandPrixCircuitId circuit, {int laps = 1}) =>
      bestLapMsByCircuit[_bestKey(circuit, laps)];

  /// True when [lapTimeMs] beats (or sets) the stored best for this
  /// circuit+distance.
  bool isPersonalBest(GrandPrixCircuitId circuit, int lapTimeMs, {int laps = 1}) {
    final best = bestLapMs(circuit, laps: laps);
    return best == null || lapTimeMs < best;
  }

  GrandPrixStats copyWith({
    GrandPrixCircuitId? lastCircuit,
    GrandPrixLivery? lastLivery,
    int? lastLaps,
  }) => GrandPrixStats(
    races: races,
    wins: wins,
    podiums: podiums,
    bestPosition: bestPosition,
    currentStreak: currentStreak,
    bestStreak: bestStreak,
    bestLapMsByCircuit: bestLapMsByCircuit,
    lastCircuit: lastCircuit ?? this.lastCircuit,
    lastLivery: lastLivery ?? this.lastLivery,
    lastLaps: lastLaps ?? this.lastLaps,
  );

  GrandPrixStats recordResult({
    required int position,
    required int lapTimeMs,
    required GrandPrixCircuitId circuit,
    int laps = 1,
  }) {
    final won = position == 1;
    final nextStreak = won ? currentStreak + 1 : 0;
    final bests = Map<String, int>.from(bestLapMsByCircuit);
    if (lapTimeMs > 0 && isPersonalBest(circuit, lapTimeMs, laps: laps)) {
      bests[_bestKey(circuit, laps)] = lapTimeMs;
    }
    return GrandPrixStats(
      races: races + 1,
      wins: won ? wins + 1 : wins,
      podiums: position <= 3 ? podiums + 1 : podiums,
      bestPosition: bestPosition == 0 || position < bestPosition
          ? position
          : bestPosition,
      currentStreak: nextStreak,
      bestStreak: nextStreak > bestStreak ? nextStreak : bestStreak,
      bestLapMsByCircuit: bests,
      lastCircuit: circuit,
      lastLivery: lastLivery,
      lastLaps: laps,
    );
  }

  Map<String, dynamic> toJson() => {
    'races': races,
    'wins': wins,
    'podiums': podiums,
    'bestPosition': bestPosition,
    'currentStreak': currentStreak,
    'bestStreak': bestStreak,
    'bestLapMsByCircuit': bestLapMsByCircuit,
    'lastCircuit': lastCircuit.name,
    'lastLivery': lastLivery.name,
    'lastLaps': lastLaps,
  };
}
