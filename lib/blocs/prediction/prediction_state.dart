import '../../models/league.dart';
import '../../models/prediction.dart';
import '../../models/sport_match.dart';
import '../../models/team_standing.dart';

class PredictionState {
  const PredictionState({
    this.loading = true,
    this.leagues = const [],
    this.fixtures = const [],
    this.predictions = const {},
    this.standingsByLeague = const {},
    this.quizzes = const {},
  });

  final bool loading;
  final List<League> leagues;
  final List<SportMatch> fixtures;

  /// matchId → the user's prediction for that fixture.
  final Map<String, UserPrediction> predictions;

  /// leagueId → that league's rank-sorted standings table.
  final Map<String, List<TeamStanding>> standingsByLeague;

  /// quiz key (matchId::quizId) → PredictionQuiz
  final Map<String, PredictionQuiz> quizzes;

  /// Fixtures grouped under their league, preserving league order.
  Map<League, List<SportMatch>> get fixturesByLeague {
    final grouped = <League, List<SportMatch>>{};
    for (final league in leagues) {
      final matches = fixtures.where((m) => m.leagueId == league.id).toList();
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

  UserPrediction? predictionFor(
    String matchId, [
    String quizId = kDefaultPredictionQuizId,
  ]) => predictions[predictionStorageKey(matchId, quizId)];

  List<UserPrediction> predictionsForMatch(String matchId) => predictions.values
      .where((prediction) => prediction.matchId == matchId)
      .toList(growable: false);

  UserPrediction? predictionSummaryForMatch(String matchId) {
    final items = predictionsForMatch(matchId);
    if (items.isEmpty) return null;
    items.sort((a, b) {
      final statusRank = _summaryStatusRank(
        b.status,
      ).compareTo(_summaryStatusRank(a.status));
      if (statusRank != 0) return statusRank;
      return b.submittedAt.compareTo(a.submittedAt);
    });
    return items.first;
  }

  /// Rank-sorted standings for a league (empty if not loaded).
  List<TeamStanding> standingsFor(String leagueId) =>
      standingsByLeague[leagueId] ?? const [];

  /// Fixtures in [leagueId] that involve [teamId] (home or away).
  List<SportMatch> fixturesForTeam(String leagueId, String teamId) => fixtures
      .where(
        (m) =>
            m.leagueId == leagueId &&
            (m.home.id == teamId || m.away.id == teamId),
      )
      .toList();

  PredictionState copyWith({
    bool? loading,
    List<League>? leagues,
    List<SportMatch>? fixtures,
    Map<String, UserPrediction>? predictions,
    Map<String, List<TeamStanding>>? standingsByLeague,
    Map<String, PredictionQuiz>? quizzes,
  }) => PredictionState(
    loading: loading ?? this.loading,
    leagues: leagues ?? this.leagues,
    fixtures: fixtures ?? this.fixtures,
    predictions: predictions ?? this.predictions,
    standingsByLeague: standingsByLeague ?? this.standingsByLeague,
    quizzes: quizzes ?? this.quizzes,
  );
}

int _summaryStatusRank(PredictionStatus status) => switch (status) {
  PredictionStatus.open => 1,
  PredictionStatus.locked => 2,
  PredictionStatus.settled => 3,
};
