part of '../match_discovery.dart';

class EditorialRevealCard extends StatelessWidget {
  const EditorialRevealCard({
    required this.match,
    required this.onTap,
    super.key,
  });
  final SportMatch match;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => EditorialPlate(
    gold: true,
    motionId: 'reveal:${match.id}',
    onTap: onTap,
    child: Row(
      children: [
        Expanded(
          child: Text(
            match.sport == Sport.motorsport
                ? match.home.name
                : '${match.home.name} vs ${match.away.name}',
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
  );
}
