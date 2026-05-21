import 'package:flutter/material.dart';

import '../../config/enums.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/info_widgets.dart';
import '../../widgets/match_widgets.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    const steps = [
      'Build a valid deck with 2 attackers, 2 defenders, and 6 action cards.',
      'Win or lose the toss to decide the first-round role.',
      'Each round reveals a scenario bonus, then you choose one player and one legal action.',
      'Goals are decided by rating, action power, scenario bonus, a hidden roll, and risk checks.',
      'After four rounds, tied games go to a three-kick shootout plus sudden death.',
    ];
    return GameScaffold(
      title: 'How to Play',
      subtitle: '// Match Rules and Deck Guide',
      leading: IconButton(
        onPressed: () => onNavigate(AppSection.home),
        icon: const Icon(Icons.arrow_back),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const InfoPanel(
            icon: Icons.menu_book,
            title: 'Know the Match Loop',
            body:
                'Pitch Duel mirrors the web UI flow: build a legal five-a-side deck, read the round scenario, then commit one player card and one action card at a time.',
          ),
          const SizedBox(height: 16),
          CyberPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel(label: 'Round Flow'),
                const SizedBox(height: 8),
                for (var i = 0; i < steps.length; i++) ...[
                  ProcedureStepTile(index: i + 1, body: steps[i]),
                  if (i < steps.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const UseCasesPanel(),
          const SizedBox(height: 16),
          const FeaturesPanel(),
        ],
      ),
    );
  }
}

