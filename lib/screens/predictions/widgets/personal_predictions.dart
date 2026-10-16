import 'package:flutter/material.dart';
import '../../../widgets/cyber/match_discovery.dart';
import '../../../design_system/match_discovery.generated.dart';
import '../match_prediction_screen.dart';
import 'personal_prediction_selection.dart';

class PersonalPredictions extends StatelessWidget {
  const PersonalPredictions({required this.entries, super.key});
  final List<PersonalPredictionEntry> entries;
  @override
  Widget build(BuildContext context) {
    final reveals = entries.where((entry) => entry.reveal).toList();
    final played = entries.where((entry) => !entry.reveal).toList();
    void open(PersonalPredictionEntry entry) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MatchPredictionScreen(match: entry.match, quizId: entry.quiz.id),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (reveals.isNotEmpty) ...[
          Text(
            'Reveal results',
            style: editorialText(context, 16, weight: FontWeight.w600),
          ),
          const SizedBox(height: MatchDiscoveryTokens.gridGap),
          EditorialCarousel(
            id: 'personal-reveal-carousel',
            label: 'Reveal results cards',
            children: [
              for (final entry in reveals)
                EditorialRevealCard(
                  key: ValueKey('personal-reveal:${entry.prediction.key}'),
                  match: entry.match,
                  quiz: entry.quiz,
                  onTap: () => open(entry),
                ),
            ],
          ),
        ],
        if (reveals.isNotEmpty && played.isNotEmpty)
          const SizedBox(height: MatchDiscoveryTokens.moduleGap),
        if (played.isNotEmpty) ...[
          Text(
            'Your predictions',
            style: editorialText(context, 16, weight: FontWeight.w600),
          ),
          const SizedBox(height: MatchDiscoveryTokens.gridGap),
          EditorialCarousel(
            id: 'personal-played-carousel',
            label: 'Your prediction cards',
            children: [
              for (final entry in played)
                EditorialMission(
                  key: ValueKey('personal-played:${entry.prediction.key}'),
                  match: entry.match,
                  quiz: entry.quiz,
                  prediction: entry.prediction,
                  history: true,
                  onTap: () => open(entry),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
