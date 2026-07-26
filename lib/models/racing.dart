import '../config/enums.dart';
import 'starter_pack.dart';

enum RacingSeries { f1, f2, nascar, indycar }

extension RacingSeriesInfo on RacingSeries {
  String get label => switch (this) {
    RacingSeries.f1 => 'F1',
    RacingSeries.f2 => 'F2',
    RacingSeries.nascar => 'NASCAR',
    RacingSeries.indycar => 'INDYCAR',
  };

  PlayerRole get playerRole => switch (this) {
    RacingSeries.f1 => PlayerRole.f1Driver,
    RacingSeries.f2 => PlayerRole.f2Driver,
    RacingSeries.nascar => PlayerRole.nascarDriver,
    RacingSeries.indycar => PlayerRole.indycarDriver,
  };
}

enum RacingArchetype {
  qualifyingSpecialist,
  racecraftMaster,
  tyreWhisperer,
  aggressiveOvertaker,
  wetWeatherAce,
  allRoundRacer,
  veteranStrategist,
  rookieSensation,
}

extension RacingArchetypeLabel on RacingArchetype {
  String get label => switch (this) {
    RacingArchetype.qualifyingSpecialist => 'QUALIFYING SPECIALIST',
    RacingArchetype.racecraftMaster => 'RACECRAFT MASTER',
    RacingArchetype.tyreWhisperer => 'TYRE WHISPERER',
    RacingArchetype.aggressiveOvertaker => 'AGGRESSIVE OVERTAKER',
    RacingArchetype.wetWeatherAce => 'WET-WEATHER ACE',
    RacingArchetype.allRoundRacer => 'ALL-ROUND RACER',
    RacingArchetype.veteranStrategist => 'VETERAN STRATEGIST',
    RacingArchetype.rookieSensation => 'ROOKIE SENSATION',
  };
}

class RacingRatings {
  const RacingRatings({
    required this.pace,
    required this.racecraft,
    required this.consistency,
    required this.tyreManagement,
    required this.wetWeather,
    required this.starts,
    required this.defending,
  });

  final int pace;
  final int racecraft;
  final int consistency;
  final int tyreManagement;
  final int wetWeather;
  final int starts;
  final int defending;

  int get overall =>
      (pace +
          racecraft +
          consistency +
          tyreManagement +
          wetWeather +
          starts +
          defending) ~/
      7;
}

/// Per-archetype sub-rating deltas (pace, racecraft, consistency,
/// tyreManagement, wetWeather, starts, defending), each set summing to zero
/// so [ratingsForArchetype] always averages back to the input `overall` —
/// only the *shape* of a driver's strengths varies by archetype, not the
/// headline number.
const _archetypeDeltas = {
  RacingArchetype.qualifyingSpecialist: [6, -1, -2, -3, -1, 3, -2],
  RacingArchetype.racecraftMaster: [-1, 7, 1, -2, -1, -1, -3],
  RacingArchetype.tyreWhisperer: [-3, -1, 3, 7, 1, -4, -3],
  RacingArchetype.aggressiveOvertaker: [4, 3, -4, -3, -1, 4, -3],
  RacingArchetype.wetWeatherAce: [-1, 2, -1, -1, 8, -2, -5],
  RacingArchetype.allRoundRacer: [1, 1, 1, 1, 1, -2, -3],
  RacingArchetype.veteranStrategist: [-4, 2, 5, 3, 2, -5, -3],
  RacingArchetype.rookieSensation: [5, 3, -6, -4, -2, 5, -1],
};

/// Generates a driver's sub-ratings from their overall rating and archetype.
RacingRatings ratingsForArchetype(int overall, RacingArchetype archetype) {
  final delta = _archetypeDeltas[archetype]!;
  int stat(int i) => (overall + delta[i]).clamp(55, 99);
  return RacingRatings(
    pace: stat(0),
    racecraft: stat(1),
    consistency: stat(2),
    tyreManagement: stat(3),
    wetWeather: stat(4),
    starts: stat(5),
    defending: stat(6),
  );
}

/// A single current driver across F1, F2, NASCAR Cup or IndyCar. Sub-ratings
/// are shaped by [archetype] and average out to roughly [overallRating],
/// which is what drives the card's [tier] via [packRarityForRating].
class RacingDriver {
  const RacingDriver({
    required this.id,
    required this.name,
    required this.series,
    required this.team,
    required this.country,
    required this.countryCode,
    required this.archetype,
    required this.ratings,
    required this.signature,
    required this.overallRating,
  });

  final String id;
  final String name;
  final RacingSeries series;
  final String team;
  final String country;
  final String countryCode;
  final RacingArchetype archetype;
  final RacingRatings ratings;
  final String signature;
  final int overallRating;

  CardTier get tier => packRarityForRating(overallRating);
}
