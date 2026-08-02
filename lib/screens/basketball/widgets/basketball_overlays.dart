import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../data/basketball_athletes.dart';
import '../../../games/basketball/basketball_game.dart';
import '../../../models/basketball.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Halftime: score check + pick who plays the second half (fresh legs beat).
class BasketballHalftimeOverlay extends StatefulWidget {
  const BasketballHalftimeOverlay({
    required this.game,
    required this.rosterIds,
    required this.onResume,
    super.key,
  });

  final BasketballGame game;
  final List<String> rosterIds;

  /// Called with the roster index to field for H2 (may equal the active one).
  final ValueChanged<int> onResume;

  @override
  State<BasketballHalftimeOverlay> createState() =>
      _BasketballHalftimeOverlayState();
}

class _BasketballHalftimeOverlayState extends State<BasketballHalftimeOverlay> {
  late int _selected = widget.game.engine.teams[0].activeIndex;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final team = game.engine.teams[0];
    final activeIndex = team.activeIndex;
    return ColoredBox(
      color: Cyber.bg.withValues(alpha: 0.95),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text(
                    'HALFTIME',
                    style: Cyber.display(24, letterSpacing: 3).copyWith(
                      shadows: [
                        Shadow(
                          color: Cyber.gold.withValues(alpha: 0.5),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${game.scorePlayer.value}',
                        style: Cyber.display(30, color: Cyber.cyan),
                      ),
                      Text(
                        '  —  ',
                        style: Cyber.display(16, color: Cyber.muted),
                      ),
                      Text(
                        '${game.scoreCpu.value}',
                        style: Cyber.display(30, color: Cyber.magenta),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionLabel(label: 'WHO TAKES THE SECOND HALF?'),
                const SizedBox(height: 4),
                const Text(
                  'The bench rested to full stamina.',
                  style: TextStyle(color: Cyber.muted, fontSize: 11),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < widget.rosterIds.length; i++) ...[
                  _SubCard(
                    athlete: basketballAthleteById(widget.rosterIds[i]),
                    stamina: i == activeIndex
                        ? game.engine.playerBody.stamina
                        : team.staminas[i],
                    wasOn: i == activeIndex,
                    selected: i == _selected,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      playSound(SoundEffect.cardSelect);
                      setState(() => _selected = i);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 10),
                HudCtaButton(
                  label: 'START 2ND HALF',
                  icon: Icons.sports_basketball,
                  accent: Cyber.gold,
                  tapSound: SoundEffect.playMatch,
                  helper: _selected == activeIndex
                      ? 'STAY WITH ${basketballAthleteById(widget.rosterIds[_selected]).name}'
                      : 'SUB IN ${basketballAthleteById(widget.rosterIds[_selected]).name} — FRESH LEGS',
                  onTap: () => widget.onResume(_selected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubCard extends StatelessWidget {
  const _SubCard({
    required this.athlete,
    required this.stamina,
    required this.wasOn,
    required this.selected,
    required this.onTap,
  });

  final BasketballAthlete athlete;
  final double stamina;
  final bool wasOn;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = basketballLookFor(athlete.id);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(look.accent.withValues(alpha: 0.12), Cyber.panel)
              : Cyber.panel,
          border: Border.all(
            color: selected ? look.accent : Cyber.border.withValues(alpha: 0.6),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: look.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        athlete.name,
                        style: Cyber.display(13, letterSpacing: 1),
                      ),
                      const SizedBox(width: 8),
                      if (wasOn)
                        const CyberChip(label: 'ON COURT', color: Cyber.cyan)
                      else if (stamina >= 99)
                        const CyberChip(label: 'FRESH', color: Cyber.success),
                    ],
                  ),
                  const SizedBox(height: 6),
                  CyberProgressBar(
                    value: stamina / 100,
                    accent: stamina < 35 ? Cyber.danger : Cyber.success,
                    height: 5,
                    radius: 2,
                    animate: false,
                    trackColor: Cyber.success.withValues(alpha: 0.12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? look.accent : Cyber.muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// OVERTIME stinger — sudden death, auto-advances (tap to skip).
class BasketballOvertimeOverlay extends StatefulWidget {
  const BasketballOvertimeOverlay({required this.onBegin, super.key});

  final VoidCallback onBegin;

  @override
  State<BasketballOvertimeOverlay> createState() =>
      _BasketballOvertimeOverlayState();
}

class _BasketballOvertimeOverlayState extends State<BasketballOvertimeOverlay> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    playSound(SoundEffect.riser);
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 2200), _finish);
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    widget.onBegin();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _finish,
      child: ColoredBox(
        color: Cyber.bg.withValues(alpha: 0.94),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            builder: (context, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 1.4 - 0.4 * Curves.easeOutBack.transform(t),
                child: child,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'OVERTIME',
                  style: Cyber.display(34, color: Cyber.gold, letterSpacing: 4)
                      .copyWith(
                    shadows: [
                      Shadow(
                        color: Cyber.gold.withValues(alpha: 0.6),
                        blurRadius: 22,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'SUDDEN DEATH — FIRST BASKET WINS',
                  style: Cyber.label(10, color: Colors.white, letterSpacing: 2.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
