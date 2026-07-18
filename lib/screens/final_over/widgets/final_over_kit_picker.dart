import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../data/final_over_kits.dart';
import '../../../games/final_over/final_over_rig.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

class FinalOverKitPicker extends StatelessWidget {
  const FinalOverKitPicker({
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = finalOverKitById(selectedId);
    return Column(
      key: const ValueKey('final-over-kit-picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SectionLabel(label: 'TEAM KIT'),
            const Spacer(),
            Container(
              width: 5,
              height: 5,
              color: Cyber.cyan,
              margin: const EdgeInsets.only(right: 6),
            ),
            Flexible(
              child: Text(
                '${selected.name} // EQUIPPED',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Cyber.label(7.5, color: Cyber.cyan, letterSpacing: 1.1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            const columns = 4;
            const gap = 8.0;
            final tileWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var index = 0; index < finalOverKits.length; index++)
                  _KitTile(
                    kit: finalOverKits[index],
                    index: index,
                    selected: finalOverKits[index].id == selectedId,
                    width: tileWidth,
                    onTap: () {
                      playSound(SoundEffect.cardSelect);
                      HapticFeedback.selectionClick();
                      onSelected(finalOverKits[index].id);
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _KitTile extends StatelessWidget {
  const _KitTile({
    required this.kit,
    required this.index,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  final FinalOverKit kit;
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
      label: '${kit.name} team kit',
      child: ExcludeSemantics(
        child: PressableScale(
          key: ValueKey('final-over-kit-${kit.id}'),
          onTap: onTap,
          child: SizedBox(
            width: width,
            height: 94,
            child: ChamferedActionSurface(
              clipper: clipper,
              borderColor: selected
                  ? Cyber.cyan
                  : Cyber.border.withValues(alpha: 0.72),
              borderWidth: selected ? 1.6 : 1,
              glowColor: selected ? Cyber.cyan : null,
              glow: selected ? 0.85 : 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                color: selected
                    ? Color.alphaBlend(
                        kit.primary.withValues(alpha: 0.16),
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
                        color: selected ? Cyber.cyan : kit.primary,
                      ),
                    ),
                    Positioned(
                      left: 7,
                      top: 6,
                      child: Text(
                        '${index + 1}'.padLeft(2, '0'),
                        style: Cyber.label(
                          6.5,
                          color: selected ? Cyber.cyan : Cyber.muted,
                          letterSpacing: 0.8,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    if (selected)
                      const Positioned(
                        right: 7,
                        top: 5,
                        child: Icon(
                          Icons.check_rounded,
                          color: Cyber.cyan,
                          size: 13,
                        ),
                      ),
                    Positioned.fill(
                      top: 9,
                      bottom: 20,
                      child: CustomPaint(
                        painter: _KitBatterPreviewPainter(kit),
                      ),
                    ),
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: 7,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          kit.name,
                          maxLines: 1,
                          style: Cyber.label(
                            7.5,
                            color: selected ? Colors.white : Cyber.muted,
                            letterSpacing: 0.8,
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
      ),
    );
  }
}

/// Uses the same athlete rig as the match so every swatch previews the full
/// shirt, trim, pads, helmet, boots, and number instead of an abstract palette.
class _KitBatterPreviewPainter extends CustomPainter {
  const _KitBatterPreviewPainter(this.kit);

  final FinalOverKit kit;

  @override
  void paint(Canvas canvas, Size size) {
    final px = size.height * 0.52;
    canvas
      ..save()
      ..translate(size.width * 0.51, size.height * 0.96);
    drawFoBatter(
      canvas,
      foBatterFrame(FoBatterPose.stance, 0),
      kit: kit,
      look: finalOverLookFor('fo-kit-preview'),
      px: px,
      heightM: kFoReferenceHeightM,
      number: finalOverNumberFor(kit.id),
      facing: -1,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _KitBatterPreviewPainter oldDelegate) =>
      oldDelegate.kit != kit;
}
