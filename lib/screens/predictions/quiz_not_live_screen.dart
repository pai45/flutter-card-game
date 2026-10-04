import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/sport_match.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import 'widgets/quiz_chrome.dart';

/// Standalone empty state shown when a fixture's quiz isn't live yet (no
/// questions to render). Just the match header + a [CyberNoDataState] hint.
class QuizNotLiveScreen extends StatelessWidget {
  const QuizNotLiveScreen({
    required this.match,
    required this.onLeaderboard,
    super.key,
  });

  final SportMatch match;
  final VoidCallback onLeaderboard;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberPlainBackground(child: SizedBox.expand()),
          ),
          SafeArea(
            child: Column(
              children: [
                QuizTopBar(
                  onBack: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  onLeaderboard: onLeaderboard,
                ),
                const SizedBox(height: 20),
                QuizHeader(match: match),
                const Expanded(
                  child: CyberNoDataState(
                    icon: Icons.quiz_outlined,
                    title: 'Quiz not live yet',
                    message:
                        'Prediction questions will appear here when this match opens.',
                    accent: Cyber.violet,
                    spark: Icons.schedule,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
