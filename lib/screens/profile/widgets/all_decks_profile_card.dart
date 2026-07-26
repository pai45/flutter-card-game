import 'package:flutter/material.dart';

import '../../../blocs/game/game_state.dart';
import '../../../config/theme.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import 'profile_card.dart';

class AllDecksProfileCard extends StatelessWidget {
  const AllDecksProfileCard({
    required this.game,
    required this.onTap,
    super.key,
  });

  final GameState game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = game.deckSlots
        .where((slot) => slot.id == game.activeDeckId)
        .firstOrNull;
    final readiness = [
      (Icons.sports_soccer, Cyber.cyan, game.pitchDuelDeckReady),
      (Icons.sports_cricket, Cyber.lime, game.finalOverDeckReady),
      (Icons.sports_basketball, Cyber.gold, game.hoopDuelDeckReady),
      (Icons.sports_tennis, Cyber.lime, game.tennisDeckReady),
      (Icons.sports_motorsports, Cyber.f1Red, game.racingDriverDeckReady),
    ];
    final allReady = game.sportDeckReadyCount == readiness.length;

    return PressableScale(
      onTap: onTap,
      child: ProfileCard(
        borderColor: Cyber.cyan.withValues(alpha: 0.52),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Cyber.cyan.withValues(alpha: 0.1),
                    border: Border.all(
                      color: Cyber.cyan.withValues(alpha: 0.46),
                    ),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Cyber.cyan,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ALL DECKS',
                        style: Cyber.label(
                          11,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '// ${active?.name.toUpperCase() ?? 'ACTIVE SQUAD'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.label(
                          8,
                          color: Cyber.cyan,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${game.sportDeckReadyCount}/5',
                  style: Cyber.display(
                    17,
                    color: allReady ? Cyber.success : Cyber.cyan,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Cyber.cyan, size: 21),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < readiness.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _SportReadyNode(
                      icon: readiness[i].$1,
                      accent: readiness[i].$2,
                      ready: readiness[i].$3,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            CyberProgressBar(
              value: game.sportDeckReadyCount / readiness.length,
              accent: allReady ? Cyber.success : Cyber.cyan,
            ),
            const SizedBox(height: 8),
            Text(
              allReady
                  ? 'EVERY SPORT LOADOUT IS LOCKED AND READY'
                  : 'MANAGE THE SAME LOADOUTS USED IN EVERY GAME',
              style: Cyber.label(
                7,
                color: Cyber.muted,
                letterSpacing: 0.9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SportReadyNode extends StatelessWidget {
  const _SportReadyNode({
    required this.icon,
    required this.accent,
    required this.ready,
  });

  final IconData icon;
  final Color accent;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ready
            ? Color.alphaBlend(accent.withValues(alpha: 0.12), Cyber.panel)
            : Cyber.bg.withValues(alpha: 0.44),
        border: Border.all(
          color: ready ? accent.withValues(alpha: 0.65) : Cyber.line,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: ready ? accent : Cyber.muted, size: 19),
          if (ready)
            const Positioned(
              right: 3,
              top: 3,
              child: Icon(Icons.check, color: Cyber.success, size: 9),
            ),
        ],
      ),
    );
  }
}
