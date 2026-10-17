part of '../match_discovery.dart';

/// Reusable outcome control; features own pricing, permission and trade callbacks.
class EditorialOutcomeRow extends StatelessWidget {
  const EditorialOutcomeRow({
    required this.label,
    required this.percentage,
    required this.accent,
    this.onPressed,
    this.rowKey,
    this.priceKey,
    super.key,
  });
  final String label;
  final int percentage;
  final Color accent;
  final VoidCallback? onPressed;
  final Key? rowKey, priceKey;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onPressed != null ? 1 : .65,
    child: OutlinedButton(
      key: rowKey,
      onPressed: onPressed != null
          ? () {
              HapticFeedback.selectionClick();
              onPressed!();
            }
          : null,
      style:
          OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, MatchDiscoveryTokens.outcomeMinHeight),
            visualDensity: VisualDensity.standard,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: BorderSide.none,
            shape: const BeveledRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                bottomRight: Radius.circular(6),
              ),
            ),
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                width: 2,
                color:
                    states.contains(WidgetState.focused) ||
                        states.contains(WidgetState.hovered)
                    ? Cyber.cyan
                    : Colors.transparent,
              ),
            ),
          ),
      child: EditorialInset(
        padding: EdgeInsets.zero,
        edge: Color.alphaBlend(accent.withValues(alpha: .30), kFixtureBorder),
        fill: Color.alphaBlend(
          accent.withValues(alpha: MatchDiscoveryTokens.outcomeTint),
          kFixtureStripDark,
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(width: 2, color: accent)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 0, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        maxLines: MatchDiscoveryTokens.teamNameLines,
                        overflow: TextOverflow.ellipsis,
                        style: editorialText(
                          context,
                          14,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ChamferedActionSurface(
                  key: priceKey,
                  clipper: const HudChamferClipper(
                    bigCut: MatchDiscoveryTokens.detailCut,
                    smallCut: 0,
                  ),
                  borderColor: Color.lerp(accent, Colors.white, .3)!,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: MatchDiscoveryTokens.outcomeWidth,
                      minHeight: MatchDiscoveryTokens.outcomeMinHeight,
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.darkInk.withValues(alpha: .12),
                          offset: const Offset(0, -2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      '$percentage%',
                      style:
                          Cyber.display(
                            14,
                            color:
                                accent.computeLuminance() >
                                    MatchDiscoveryTokens.percentageInkThreshold
                                ? AppTheme.darkInk
                                : Colors.white,
                          ).copyWith(
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
