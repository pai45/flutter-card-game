part of '../match_discovery.dart';

class EditorialEventsPanel extends StatelessWidget {
  const EditorialEventsPanel({
    required this.markets,
    required this.onOpen,
    super.key,
  });
  final List<PickMarket> markets;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) => EditorialPlate(
    quiet: true,
    contentPadding: const EdgeInsets.symmetric(
      vertical: MatchDiscoveryTokens.card,
    ),
    motionId: 'events:${markets.map((m) => m.id).join(',')}',
    signalAccent: editorialSportAccent(markets.firstOrNull?.sport),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MatchDiscoveryTokens.card,
          ),
          child: Text(
            'EVENTS',
            style: Cyber.display(
              14,
            ).copyWith(fontWeight: FontWeight.w600, letterSpacing: .5),
          ),
        ),
        for (var i = 0; i < markets.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MatchDiscoveryTokens.card,
              ),
              child: Divider(height: 1, color: Cyber.border),
            ),
          EditorialEventRow(
            market: markets[i],
            onTap: () => onOpen(markets[i].id),
          ),
        ],
      ],
    ),
  );
}

class EditorialEventRow extends StatelessWidget {
  const EditorialEventRow({
    required this.market,
    required this.onTap,
    super.key,
  });
  final PickMarket market;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final leading = market.leadingOutcome,
        delta = market.latestDeltaFor(leading.id);
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MatchDiscoveryTokens.card,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EditorialStatusArea(
                label: market.leagueLabel,
                sport: market.sport,
                showDivider: false,
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          market.question,
                          style: editorialText(
                            context,
                            MatchDiscoveryTokens.question,
                            weight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          leading.label,
                          style: editorialText(context, 12, color: Cyber.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${leading.probabilityPercent}%',
                        style:
                            Cyber.display(
                              14,
                              color: editorialEventInk(leading.color),
                            ).copyWith(
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                      if (delta != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${delta > 0 ? '+' : ''}$delta pp',
                          style: editorialText(
                            context,
                            12,
                            color: delta > 0
                                ? Cyber.success
                                : delta < 0
                                ? Cyber.red
                                : Cyber.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
