part of '../match_discovery.dart';

class EditorialInset extends StatelessWidget {
  const EditorialInset({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.edge = kFixtureBorder,
    this.fill = kFixtureStripDark,
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color edge, fill;
  @override
  Widget build(BuildContext context) => ChamferedActionSurface(
    clipper: const HudChamferClipper(
      bigCut: MatchDiscoveryTokens.detailCut,
      smallCut: 0,
    ),
    borderColor: edge,
    child: ColoredBox(
      color: fill,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class EditorialAction extends StatelessWidget {
  const EditorialAction(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: EditorialInset(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: editorialText(
                context,
                12,
                weight: FontWeight.w600,
                color: Cyber.cyan,
              ),
            ),
          ),
          Container(width: 1, height: 16, color: kFixtureBorder),
          const SizedBox(width: 8),
          const Icon(Icons.north_east, size: 16, color: Cyber.cyan),
        ],
      ),
    ),
  );
}

class EditorialQuestionProgress extends StatelessWidget {
  const EditorialQuestionProgress({
    required this.answered,
    required this.total,
    super.key,
  });
  final int answered, total;
  @override
  Widget build(BuildContext context) => total <= 0
      ? const SizedBox.shrink()
      : ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0)
                  const SizedBox(width: MatchDiscoveryTokens.progressGap),
                Expanded(
                  child: Container(
                    height: MatchDiscoveryTokens.progressHeight,
                    color: i < answered ? Cyber.cyan : Cyber.border,
                  ),
                ),
              ],
            ],
          ),
        );
}

/// Shared quiet separator: score typography must never be applied to VS.
class EditorialVersus extends StatelessWidget {
  const EditorialVersus({super.key});
  @override
  Widget build(BuildContext context) => Text(
    'VS',
    textAlign: TextAlign.center,
    style: Cyber.display(
      MatchDiscoveryTokens.support,
    ).copyWith(fontWeight: FontWeight.w600),
  );
}

/// A complete accessible identity with a two-line visual limit.
class EditorialTeamName extends StatelessWidget {
  const EditorialTeamName(
    this.name, {
    this.textAlign = TextAlign.left,
    super.key,
  });
  final String name;
  final TextAlign textAlign;
  @override
  Widget build(BuildContext context) => Text(
    name,
    maxLines: MatchDiscoveryTokens.teamNameLines,
    overflow: TextOverflow.ellipsis,
    textAlign: textAlign,
    style: editorialText(
      context,
      MatchDiscoveryTokens.name,
      weight: FontWeight.w600,
    ),
  );
}
