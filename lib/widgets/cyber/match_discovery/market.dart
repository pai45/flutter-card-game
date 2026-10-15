part of '../match_discovery.dart';

class EditorialMarketCard extends StatelessWidget {
  const EditorialMarketCard({
    required this.market,
    required this.onOpen,
    required this.onBuy,
    this.positions = const [],
    this.featured = false,
    super.key,
  });
  final PickMarket market;
  final VoidCallback onOpen;
  final ValueChanged<PickOutcome> onBuy;
  final List<PickPosition> positions;
  final bool featured;
  @override
  Widget build(BuildContext context) => EditorialPlate(
    signalAccent: editorialSportAccent(market.sport),
    motionId: 'pick:${market.id}',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorialStatusArea(
          sport: market.sport,
          label:
              '${market.leagueLabel} · ${market.type == PickMarketType.future ? 'Future' : 'Match Pick'}',
          status: market.status.name,
          timing:
              editorialDeadline(
                market.closesAt,
                market.status.name,
                DateTime.now(),
              ) ??
              (market.status == PickMarketStatus.live
                  ? market.liveLabel
                  : null),
        ),
        InkWell(
          onTap: onOpen,
          child: Text(
            market.question,
            style: editorialText(context, 16, weight: FontWeight.w600),
          ),
        ),
        if (!featured && market.contextTitle != null) ...[
          const SizedBox(height: 12),
          Text(
            market.contextTitle!,
            style: editorialText(context, 12, color: Cyber.muted),
          ),
        ],
        const SizedBox(height: 12),
        for (final outcome
            in featured
                ? market.outcomes.take(MatchDiscoveryTokens.featuredOutcomes)
                : market.outcomes)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: EditorialOutcomeRow(
              label: outcome.label,
              percentage: outcome.probabilityPercent,
              accent: outcome.color,
              rowKey: ValueKey('editorial-outcome-${market.id}-${outcome.id}'),
              priceKey: ValueKey('editorial-price-${market.id}-${outcome.id}'),
              onPressed: market.canBuy ? () => onBuy(outcome) : null,
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${market.volumeOz} Oz volume${positions.isNotEmpty ? ' · ${positions.length} held' : ''}',
                  style: editorialText(context, 12, color: Cyber.muted),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onOpen,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(
                  positions.any((p) => p.canSettle)
                      ? 'View result ↗'
                      : market.type == PickMarketType.future
                      ? 'View Future ↗'
                      : 'View Pick ↗',
                  style: editorialText(
                    context,
                    12,
                    weight: FontWeight.w600,
                    color: Cyber.cyan,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
