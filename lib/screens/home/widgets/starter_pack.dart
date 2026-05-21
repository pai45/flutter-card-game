import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../blocs/game/game_event.dart';
import '../../../config/theme.dart';
import '../../../models/cards.dart';
import '../../../utils/label_helpers.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

class StarterPackHomePanel extends StatelessWidget {
  const StarterPackHomePanel({required this.cards, super.key});

  final List<PlayerCard> cards;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.amber,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'STARTER PACK UNLOCKED',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Cyber.amber.withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final card in cards)
                SizedBox(
                  width: 52,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(card.icon, color: tierColor(card.tier), size: 22),
                      const SizedBox(height: 3),
                      Text(
                        playerRoleLabel(card),
                        style: TextStyle(
                          color: tierColor(card.tier),
                          fontFamily: 'Orbitron',
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                await showDialog<void>(
                  context: context,
                  builder: (_) => StarterPackRevealDialog(cards: cards),
                );
                if (!context.mounted) return;
                context.read<GameBloc>().add(StarterPackSeen());
              },
              child: const Text('CLAIM CARDS'),
            ),
          ),
        ],
      ),
    );
  }
}


class StarterPackRevealDialog extends StatelessWidget {
  const StarterPackRevealDialog({required this.cards, super.key});

  final List<PlayerCard> cards;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: CyberPanel(
        accent: Cyber.amber,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'STARTER PACK UNLOCKED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Cyber.amber.withValues(alpha: 0.92),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'First launch reward: 2 ATK, 2 DEF, 1 GK',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pack rarity odds: Bronze 50%  Silver 30%  Gold 15%  Platinum 5%',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Cyber.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final card in cards)
                    CyberPlayerCardTile(
                      card: card,
                      selected: true,
                      size: VisualCardSize.sm,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CONTINUE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
