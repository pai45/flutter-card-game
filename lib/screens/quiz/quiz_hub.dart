import 'package:flutter/material.dart';

import '../../config/enums.dart';
import 'quiz_lobby_screen.dart';

/// Standalone Football Quiz game shell — the sibling of `GameTabContent` and
/// `ShootoutTabContent`, launched as a full-screen flow from the GAMES tab.
///
/// The quiz has no shared deck and only one inner destination (the play
/// screen), which the lobby pushes as its own route — so this is a thin
/// wrapper: it just shows the lobby and routes "back" to the predictions shell.
class QuizTabContent extends StatelessWidget {
  const QuizTabContent({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    return QuizLobbyScreen(
      onBack: () => onNavigate(AppSection.predictions),
    );
  }
}
