import '../models/league.dart';
import '../models/prediction.dart';
import '../models/sport_match.dart';
import '../models/team_standing.dart';
import 'espn_service.dart';
import 'live_score_service.dart';
import 'prediction_repository.dart';

class LivePredictionRepository implements PredictionRepository {
  const LivePredictionRepository(this._inner, this._liveScoreService, this._espnService);

  final PredictionRepository _inner;
  final LiveScoreService _liveScoreService;
  final EspnService _espnService;

  @override
  Future<List<League>> leagues() => _inner.leagues();

  @override
  Future<List<SportMatch>> fixtures({DateTime? day, Sport? sport}) async {
    // Return base fixtures immediately for fast initial loading
    return _inner.fixtures(day: day, sport: sport);
  }

  @override
  Future<List<SportMatch>> enrichFixturesForSport(List<SportMatch> fixtures, Sport sport) async {
    final baseEnriched = await _inner.enrichFixturesForSport(fixtures, sport);
    final finalEnriched = <SportMatch>[];
    for (final match in baseEnriched) {
      if (match.id == 'fifa_fra_par') {
        finalEnriched.add(await _liveScoreService.enrich(match));
      } else {
        finalEnriched.add(match);
      }
    }
    return List.unmodifiable(finalEnriched);
  }

  @override
  Future<List<MatchPredictionLeaderboardEntry>> matchLeaderboard(
    String matchId,
    String quizId,
  ) => _inner.matchLeaderboard(matchId, quizId);

  @override
  Future<PredictionQuiz?> quizFor(String matchId, String quizId) =>
      _inner.quizFor(matchId, quizId);

  @override
  Future<List<PredictionQuiz>> quizzesFor(String matchId) =>
      _inner.quizzesFor(matchId);

  @override
  Future<List<TeamStanding>> standings(String leagueId) {
    if (leagueId == 'fifa' || leagueId == 'epl') {
      return _espnService.fetchStandings(leagueId);
    }
    return _inner.standings(leagueId);
  }

  @override
  Future<PredictionVoteBreakdown?> votesFor(
    String matchId,
    String quizId,
    String questionId,
  ) => _inner.votesFor(matchId, quizId, questionId);
}
