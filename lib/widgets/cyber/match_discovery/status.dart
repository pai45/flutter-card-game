part of '../match_discovery.dart';

class EditorialStatusArea extends StatelessWidget {
  const EditorialStatusArea({
    required this.label,
    this.status,
    this.timing,
    this.liveContext,
    this.sport,
    this.showDivider = true,
    this.showMarker = true,
    super.key,
  });
  final String label;
  final String? status, timing, liveContext;
  final Sport? sport;
  final bool showDivider, showMarker;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, box) {
          final tagLabel = editorialLifecycleText(status, liveContext);
          final tag = status == null
              ? null
              : ChamferedActionSurface(
                  key: const ValueKey('editorial-lifecycle-dock'),
                  clipper: const ShapeBorderClipper(
                    shape: BeveledRectangleBorder(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(4),
                      ),
                    ),
                  ),
                  borderColor: Color.alphaBlend(
                    _statusColor(status!).withValues(alpha: .28),
                    kFixtureStripDark,
                  ),
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: MatchDiscoveryTokens.tagMinHeight,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: MatchDiscoveryTokens.tagHorizontal,
                      vertical: MatchDiscoveryTokens.tagVertical,
                    ),
                    color: Color.alphaBlend(
                      _statusColor(
                        status!,
                      ).withValues(alpha: MatchDiscoveryTokens.statusTint),
                      kFixtureStripDark,
                    ),
                    child: Text(
                      tagLabel,
                      style: editorialText(
                        context,
                        12,
                        weight: FontWeight.w600,
                        color: _statusColor(status!),
                      ),
                    ),
                  ),
                );
          final marker = Row(
            children: [
              if (sport != null)
                StatozSportIcon(
                  sport: sport!,
                  size: MatchDiscoveryTokens.emblem,
                  color: editorialSportAccent(sport),
                )
              else
                Container(width: 16, height: 2, color: Cyber.cyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: editorialText(
                    context,
                    12,
                    weight: FontWeight.w600,
                    color: Cyber.muted,
                  ).copyWith(letterSpacing: .5),
                ),
              ),
            ],
          );
          if (tag == null) return showMarker ? marker : const SizedBox.shrink();
          final text = TextPainter(
            text: TextSpan(
              text: tagLabel,
              style: editorialText(
                context,
                12,
                weight: FontWeight.w600,
                color: _statusColor(status!),
              ),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final tagHeight = (text.height + MatchDiscoveryTokens.tagVertical * 2)
              .clamp(MatchDiscoveryTokens.tagMinHeight, double.infinity);
          final narrow = box.maxWidth < 220;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (!showMarker)
                SizedBox(
                  height: (tagHeight - MatchDiscoveryTokens.card).clamp(
                    0.0,
                    double.infinity,
                  ),
                )
              else if (narrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: (tagHeight + 8 - MatchDiscoveryTokens.card)
                          .clamp(16.0, double.infinity)
                          .toDouble(),
                    ),
                    marker,
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: marker),
                    const SizedBox(width: 8),
                    SizedBox(
                      width:
                          text.width + MatchDiscoveryTokens.tagHorizontal * 2,
                      height: 0,
                    ),
                  ],
                ),
              Positioned(
                top: -MatchDiscoveryTokens.card,
                right: -MatchDiscoveryTokens.card,
                child: tag,
              ),
            ],
          );
        },
      ),
      if (timing != null &&
          timing!.trim().isNotEmpty &&
          timing!.trim().toUpperCase() != editorialStatus(status ?? '')) ...[
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Text(
            timing!,
            style: editorialText(context, 12, color: Cyber.muted),
          ),
        ),
      ],
      if (showMarker) const SizedBox(height: 7),
      if (showDivider && showMarker)
        Container(height: 1, color: kFixtureBorder)
      else if (showMarker)
        const SizedBox(height: 1),
      const SizedBox(height: 4),
    ],
  );
}
