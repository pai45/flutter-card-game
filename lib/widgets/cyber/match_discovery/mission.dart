part of '../match_discovery.dart';

class EditorialMission extends StatelessWidget {
  const EditorialMission({
    required this.match,
    required this.quiz,
    required this.onTap,
    this.prediction,
    this.history = false,
    super.key,
  });
  final SportMatch match;
  final PredictionQuiz quiz;
  final UserPrediction? prediction;
  final bool history;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final count = quiz.questions
        .where((q) => prediction?.answers[q.id] != null)
        .length;
    return EditorialPlate(
      onTap: onTap,
      motionId: 'mission:${match.id}:${quiz.id}',
      signalAccent: editorialSportAccent(match.sport),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EditorialStatusArea(
            label: history ? quiz.title : 'XP prediction',
            sport: match.sport,
            status: prediction?.status == PredictionStatus.settled
                ? 'settled'
                : match.status == MatchStatus.finished && prediction != null
                ? 'unresolved'
                : match.status == MatchStatus.live
                ? 'live'
                : prediction?.status == PredictionStatus.locked
                ? 'closed'
                : match.status.name,
          ),
          if (match.sport == Sport.motorsport)
            Text(
              match.home.name,
              style: editorialText(context, 16, weight: FontWeight.w600),
            )
          else
            Semantics(
              label: '${match.home.name} versus ${match.away.name}',
              excludeSemantics: true,
              child: Row(
                children: [
                  TeamLogo(
                    team: match.home,
                    width: 32,
                    height: 32,
                    sport: match.sport,
                    competition: match.leagueId,
                  ),
                  Expanded(child: const EditorialVersus()),
                  TeamLogo(
                    team: match.away,
                    width: 32,
                    height: 32,
                    sport: match.sport,
                    competition: match.leagueId,
                    cutBottomRight: false,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text(
            prediction?.status == PredictionStatus.settled
                ? '${prediction!.correctCount ?? 0} / ${quiz.questions.length} correct'
                : '$count / ${quiz.questions.length} answered',
            style: editorialText(context, 12, color: Cyber.muted),
          ),
          const SizedBox(height: 12),
          EditorialQuestionProgress(
            answered: count,
            total: quiz.questions.length,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                Cyber.gold.withValues(alpha: .06),
                kFixtureStripDark,
              ),
              border: const Border(
                left: BorderSide(color: Cyber.gold, width: 2),
              ),
            ),
            child: Text(
              prediction?.status == PredictionStatus.settled
                  ? '+${prediction!.rewardEarned} XP'
                  : 'Up to ${quiz.maxReward} XP',
              style: editorialText(
                context,
                12,
                weight: FontWeight.w600,
                color: Cyber.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
