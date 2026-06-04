import '../../models/league.dart';
import '../../models/prediction.dart';
import '../../models/sport_match.dart';

class PredictionState {
  const PredictionState({
    this.loading = true,
    this.leagues = const [],
    this.fixtures = const [],
    this.predictions = const {},
  });

  final bool loading;
  final List<League> leagues;
  final List<SportMatch> fixtures;

  /// matchId → the user's prediction for that fixture.
  final Map<String, UserPrediction> predictions;

  /// Fixtures grouped under their league, preserving league order.
  Map<League, List<SportMatch>> get fixturesByLeague {
    final grouped = <League, List<SportMatch>>{};
    for (final league in leagues) {
      final matches = fixtures
          .where((m) => m.leagueId == league.id)
          .toList();
      if (matches.isNotEmpty) grouped[league] = matches;
    }
    return grouped;
  }

  int get predictionsMade => predictions.length;

  int get correctPredictions => predictions.values
      .where((p) => p.status == PredictionStatus.settled)
      .fold(0, (sum, p) => sum + (p.correctCount ?? 0));

  League? leagueFor(String leagueId) {
    for (final league in leagues) {
      if (league.id == leagueId) return league;
    }
    return null;
  }

  UserPrediction? predictionFor(String matchId) => predictions[matchId];

  PredictionState copyWith({
    bool? loading,
    List<League>? leagues,
    List<SportMatch>? fixtures,
    Map<String, UserPrediction>? predictions,
  }) => PredictionState(
    loading: loading ?? this.loading,
    leagues: leagues ?? this.leagues,
    fixtures: fixtures ?? this.fixtures,
    predictions: predictions ?? this.predictions,
  );
}
