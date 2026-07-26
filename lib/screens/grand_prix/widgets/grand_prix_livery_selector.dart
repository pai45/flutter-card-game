import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../data/grand_prix_liveries.dart';
import '../../../games/grand_prix/grand_prix_car_painter.dart';
import '../../../models/grand_prix.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Livery locker for the Grand Prix pit deck — free livery plus owned paid
/// liveries.
class GrandPrixLiverySelector extends StatelessWidget {
  const GrandPrixLiverySelector({
    required this.selected,
    required this.ownedLiveryIds,
    required this.onSelected,
    this.onBrowseShop,
    super.key,
  });

  final GrandPrixLivery selected;
  final Iterable<String> ownedLiveryIds;
  final ValueChanged<GrandPrixLivery> onSelected;
  final VoidCallback? onBrowseShop;

  @override
  Widget build(BuildContext context) {
    final selectedSpec = grandPrixLiverySpec(selected);
    final ownedPaid = grandPrixLiveries
        .where(
          (spec) =>
              !isGrandPrixLiveryFree(spec.livery) &&
              isGrandPrixLiveryOwned(spec.livery.name, ownedLiveryIds),
        )
        .toList();
    final freeLiveries = grandPrixLiveries
        .where((spec) => isGrandPrixLiveryFree(spec.livery))
        .toList();

    return CyberPanel(
      key: const ValueKey('grand-prix-livery-selector'),
      accent: Cyber.magenta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SectionLabel(label: 'TEAM LIVERY'),
              const Spacer(),
              Container(
                width: 5,
                height: 5,
                color: Cyber.magenta,
                margin: const EdgeInsets.only(right: 6),
              ),
              Flexible(
                child: Text(
                  '${selectedSpec.name} // EQUIPPED',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: Cyber.label(
                    7.5,
                    color: Cyber.magenta,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'FREE LIVERIES',
            style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1.6),
          ),
          const SizedBox(height: 8),
          _LiveryGrid(
            specs: freeLiveries,
            selected: selected,
            onSelected: onSelected,
          ),
          if (ownedPaid.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'YOUR LIVERIES',
              style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1.6),
            ),
            const SizedBox(height: 8),
            _LiveryGrid(
              specs: ownedPaid,
              selected: selected,
              onSelected: onSelected,
            ),
          ] else if (onBrowseShop != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onBrowseShop,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'BROWSE MORE LIVERIES IN SHOP',
                  style: Cyber.label(8, color: Cyber.magenta, letterSpacing: 1.2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveryGrid extends StatelessWidget {
  const _LiveryGrid({
    required this.specs,
    required this.selected,
    required this.onSelected,
  });

  final List<GrandPrixLiverySpec> specs;
  final GrandPrixLivery selected;
  final ValueChanged<GrandPrixLivery> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 4;
        const gap = 8.0;
        final tileWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var index = 0; index < specs.length; index++)
              GrandPrixLiveryTile(
                spec: specs[index],
                index: index,
                selected: specs[index].livery == selected,
                width: tileWidth,
                onTap: () {
                  playSound(SoundEffect.cardSelect);
                  HapticFeedback.selectionClick();
                  onSelected(specs[index].livery);
                },
              ),
          ],
        );
      },
    );
  }
}

class GrandPrixLiveryTile extends StatelessWidget {
  const GrandPrixLiveryTile({
    required this.spec,
    required this.index,
    required this.selected,
    required this.width,
    required this.onTap,
    super.key,
  });

  final GrandPrixLiverySpec spec;
  final int index;
  final bool selected;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const clipper = HudChamferClipper(bigCut: 9, smallCut: 2);
    return Semantics(
      button: true,
      selected: selected,
      label: '${spec.name} livery',
      child: ExcludeSemantics(
        child: PressableScale(
          key: ValueKey('gp-livery-${spec.livery.name}'),
          onTap: onTap,
          child: SizedBox(
            width: width,
            height: 94,
            child: ChamferedActionSurface(
              clipper: clipper,
              borderColor: selected
                  ? Cyber.magenta
                  : Cyber.border.withValues(alpha: 0.72),
              borderWidth: selected ? 1.6 : 1,
              glowColor: selected ? Cyber.magenta : null,
              glow: selected ? 0.85 : 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                color: selected
                    ? Color.alphaBlend(
                        spec.primary.withValues(alpha: 0.16),
                        Cyber.panel,
                      )
                    : Cyber.panel,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 2,
                      child: ColoredBox(
                        color: selected ? Cyber.magenta : spec.primary,
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
                        child: CustomPaint(
                          painter: GrandPrixCarPreviewPainter(spec),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 7,
                      top: 6,
                      child: Text(
                        '${index + 1}'.padLeft(2, '0'),
                        style: Cyber.label(
                          6.5,
                          color: selected ? Cyber.magenta : Cyber.muted,
                          letterSpacing: 0.8,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: 4,
                      child: Text(
                        spec.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Cyber.label(
                          6,
                          color: selected ? Colors.white : Cyber.muted,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
