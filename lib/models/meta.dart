import 'package:flutter/material.dart';

import '../config/theme.dart';

class AppInfoItem {
  const AppInfoItem({
    required this.title,
    required this.body,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color accent;
}

const commonUseCases = [
  AppInfoItem(
    title: 'Quick Local Duel',
    body:
        'Jump into a four-round head-to-head with one prepared deck and instant rematches.',
    icon: Icons.sports_soccer,
    accent: Cyber.cyan,
  ),
  AppInfoItem(
    title: 'Deck Tuning',
    body:
        'Swap attackers, defenders, and action cards to test new balance before kickoff.',
    icon: Icons.tune,
    accent: Cyber.lime,
  ),
  AppInfoItem(
    title: 'Scenario Practice',
    body:
        'Learn how round bonuses change the right play in attack and defense situations.',
    icon: Icons.radar,
    accent: Cyber.amber,
  ),
];

const coreFeatures = [
  AppInfoItem(
    title: '5-A-Side Builder',
    body:
        'Two attackers, two defenders, and a six-card action strip laid out like the web pitch.',
    icon: Icons.view_quilt,
    accent: Cyber.cyan,
  ),
  AppInfoItem(
    title: 'Scenario Rounds',
    body:
        'Every round reveals a tactical modifier before you lock your player and action card.',
    icon: Icons.auto_awesome_motion,
    accent: Cyber.violet,
  ),
  AppInfoItem(
    title: 'Penalty Finish',
    body:
        'Tied matches roll into a shootout with sudden death until one side finally breaks through.',
    icon: Icons.emoji_events,
    accent: Cyber.red,
  ),
  AppInfoItem(
    title: 'Daily Reveal',
    body:
        'Open a random featured player card for a quick showcase moment from the home screen.',
    icon: Icons.style,
    accent: Cyber.amber,
  ),
];
