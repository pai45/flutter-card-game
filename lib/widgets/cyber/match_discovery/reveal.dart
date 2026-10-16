part of '../match_discovery.dart';

class EditorialRevealCard extends StatelessWidget {
  const EditorialRevealCard({
    required this.match,
    required this.onTap,
    this.quiz,
    super.key,
  });
  final SportMatch match;
  final PredictionQuiz? quiz;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    label: quiz == null ? null : 'Reveal ${quiz!.title}',
    child: EditorialPlate(
      gold: true,
      motionId: 'reveal:${match.id}:${quiz?.id ?? ''}',
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              match.sport == Sport.motorsport
                  ? match.home.name
                  : '${match.home.name} vs ${match.away.name}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: editorialText(
                context,
                14,
                weight: FontWeight.w600,
                color: Cyber.gold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.chevron_right, size: 18, color: Cyber.gold),
        ],
      ),
    ),
  );
}
