import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import 'picks_home_view.dart';
import 'widgets/standings_table.dart' show DetailTopBar;

class AllPicksScreen extends StatelessWidget {
  const AllPicksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('all-picks-screen'),
      backgroundColor: Cyber.bg,
      body: const CyberPlainBackground(
        child: SafeArea(
          child: Column(
            children: [
              DetailTopBar(title: 'ALL PICKS'),
              Expanded(child: PicksHomeView(animateIntro: false)),
            ],
          ),
        ),
      ),
    );
  }
}
