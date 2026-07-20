import '../models/picks.dart';
import '../models/prediction.dart';
import '../models/sport_match.dart';
import 'market_archetypes.dart';
import 'match_outcome_resolver.dart';
import 'quiz_archetypes.dart';

/// Glues [MatchOutcomeResolver] to the per-domain archetype resolvers,
/// producing a settled [PredictionQuiz] or [PickMarket] for a finished
/// match. This is what [PredictionCubit.loadSport] (and, from Phase 4, the
/// picks equivalent) calls instead of storing a fixture's quiz/market as-is
/// — the fix is entirely upstream of `PredictionCubit.settle()`/
/// `PicksCubit.settlePosition()`, which already do the right thing once
/// `quiz.settleable`/`market.resolvedOutcomeId` is populated.
abstract final class SettlementWriter {
  static PredictionQuiz computeQuizSettlement(
    SportMatch match,
    PredictionQuiz quiz,
  ) {
    final outcome = MatchOutcomeResolver.resolve(match);
    return PredictionQuiz(
      id: quiz.id,
      matchId: quiz.matchId,
      title: quiz.title,
      subtitle: quiz.subtitle,
      prizeLabel: quiz.prizeLabel,
      entryFee: quiz.entryFee,
      questions: QuizArchetypes.settle(match.sport, quiz.questions, outcome),
    );
  }

  static PickMarket computeMarketSettlement(
    SportMatch match,
    PickMarket market,
  ) {
    final outcome = MatchOutcomeResolver.resolve(match);
    return MarketArchetypes.settle(market, outcome);
  }
}
