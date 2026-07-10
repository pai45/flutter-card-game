import '../models/league.dart';
import '../models/prediction.dart';
import '../models/sport_match.dart';
import '../models/team_standing.dart';
import 'espn_service.dart';
import 'live_score_service.dart';
import 'open_f1_service.dart';
import 'prediction_repository.dart';

class LivePredictionRepository implements PredictionRepository {
  const LivePredictionRepository(this._inner, this._liveScoreService, this._openF1Service, this._espnService);

  final PredictionRepository _inner;
  final LiveScoreService _liveScoreService;
  final OpenF1Service _openF1Service;
  final EspnService _espnService;

  @override
  Future<List<League>> leagues() => _inner.leagues();

  @override
  Future<List<SportMatch>> fixtures({DateTime? day}) async {
    // Return base fixtures immediately for fast initial loading
    return _inner.fixtures(day: day);
  }

  @override
  Future<List<SportMatch>> enrichFixtures(List<SportMatch> fixtures) async {
    final enriched = <SportMatch>[];
    for (final match in fixtures) {
      if (match.id == 'fifa_fra_par') {
        enriched.add(await _liveScoreService.enrich(match));
      } else if (match.sport == Sport.f1) {
        enriched.add(await _openF1Service.enrich(match));
      } else {
        enriched.add(match);
      }
    }
    return List.unmodifiable(enriched);
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
