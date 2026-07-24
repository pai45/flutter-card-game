import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../data/basketball_teams.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Jersey locker for the Hoop Duel deck builder — free jerseys plus owned paid.
class BasketballJerseySelector extends StatelessWidget {
  const BasketballJerseySelector({
    required this.selectedId,
    required this.ownedTeamIds,
    required this.onSelected,
    this.onBrowseShop,
    super.key,
  });

  final String selectedId;
  final Iterable<String> ownedTeamIds;
  final ValueChanged<String> onSelected;
  final VoidCallback? onBrowseShop;

  @override
  Widget build(BuildContext context) {
    final selected = basketballTeamById(selectedId);
    final ownedPaid = basketballTeams
        .where(
          (team) =>
              !isBasketballTeamFree(team) && ownedTeamIds.contains(team.id),
        )
        .toList();
    final freeTeams = basketballTeams.where(isBasketballTeamFree).toList();

    return CyberPanel(
      key: const ValueKey('basketball-jersey-selector'),
      accent: Cyber.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SectionLabel(label: 'TEAM JERSEY'),
              const Spacer(),
              Container(
                width: 5,
                height: 5,
                color: Cyber.cyan,
                margin: const EdgeInsets.only(right: 6),
              ),
              Flexible(
                child: Text(
                  '${selected.name.toUpperCase()} // EQUIPPED',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: Cyber.label(
                    7.5,
                    color: Cyber.cyan,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'FREE JERSEYS',
            style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1.6),
          ),
          const SizedBox(height: 8),
          _JerseyGrid(
            teams: freeTeams,
            selectedId: selectedId,
            onSelected: onSelected,
          ),
          if (ownedPaid.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'YOUR JERSEYS',
              style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1.6),
            ),
            const SizedBox(height: 8),
            _JerseyGrid(
              teams: ownedPaid,
              selectedId: selectedId,
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
                  'BROWSE MORE JERSEYS IN SHOP',
                  style: Cyber.label(8, color: Cyber.cyan, letterSpacing: 1.2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _JerseyGrid extends StatelessWidget {
  const _JerseyGrid({
    required this.teams,
    required this.selectedId,
    required this.onSelected,
  });

  final List<BasketballTeamLivery> teams;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 4;
        const gap = 8.0;
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var index = 0; index < teams.length; index++)
              BasketballJerseyTile(
                team: teams[index],
                index: index,
                selected: teams[index].id == selectedId,
                width: tileWidth,
                onTap: () {
                  playSound(SoundEffect.cardSelect);
                  HapticFeedback.selectionClick();
                  onSelected(teams[index].id);
                },
              ),
          ],
        );
      },
    );
  }
}

class BasketballJerseyTile extends StatelessWidget {
  const BasketballJerseyTile({
    required this.team,
    required this.index,
    required this.selected,
    required this.width,
    required this.onTap,
    super.key,
  });

  final BasketballTeamLivery team;
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
      label: '${team.name} team jersey',
      child: ExcludeSemantics(
        child: PressableScale(
          key: ValueKey('basketball-jersey-${team.id}'),
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
                        team.primary.withValues(alpha: 0.16),
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
                        color: selected ? Cyber.cyan : team.primary,
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
                        painter: BasketballJerseyPreviewPainter(team),
                      ),
                    ),
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: 7,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          team.name.toUpperCase(),
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

/// Compact jersey silhouette for shop tiles and deck-builder swatches.
class BasketballJerseyPreviewPainter extends CustomPainter {
  const BasketballJerseyPreviewPainter(this.team);

  final BasketballTeamLivery team;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final top = size.height * 0.12;
    final bodyW = size.width * 0.42;
    final bodyH = size.height * 0.62;
    final sleeveW = size.width * 0.16;
    final sleeveH = size.height * 0.22;

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, top + bodyH * 0.55),
        width: bodyW,
        height: bodyH,
      ),
      const Radius.circular(4),
    );
    final leftSleeve = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - bodyW * 0.5 - sleeveW * 0.7, top + bodyH * 0.08, sleeveW, sleeveH),
      const Radius.circular(3),
    );
    final rightSleeve = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx + bodyW * 0.5 - sleeveW * 0.3, top + bodyH * 0.08, sleeveW, sleeveH),
      const Radius.circular(3),
    );

    final primary = Paint()..color = team.primary;
    final secondary = Paint()..color = team.secondary;
    final accent = Paint()
      ..color = team.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas
      ..drawRRect(leftSleeve, secondary)
      ..drawRRect(rightSleeve, secondary)
      ..drawRRect(body, primary);

    // Collar + side stripe
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, top + bodyH * 0.18),
          width: bodyW * 0.28,
          height: bodyH * 0.12,
        ),
        const Radius.circular(2),
      ),
      secondary,
    );
    canvas.drawLine(
      Offset(cx - bodyW * 0.18, top + bodyH * 0.32),
      Offset(cx - bodyW * 0.18, top + bodyH * 0.88),
      accent,
    );

    // Number plate
    final numberStyle = TextStyle(
      color: team.accent,
      fontFamily: Cyber.displayFont,
      fontSize: size.height * 0.22,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.5,
    );
    final tp = TextPainter(
      text: TextSpan(text: '0', style: numberStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(cx - tp.width * 0.5, top + bodyH * 0.42 - tp.height * 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant BasketballJerseyPreviewPainter oldDelegate) =>
      oldDelegate.team != team;
}
