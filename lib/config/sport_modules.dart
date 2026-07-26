import 'package:flutter/material.dart';

import '../models/sport_match.dart';
import 'theme.dart';

class SportModule {
  const SportModule({
    required this.sport,
    required this.label,
    required this.shortLabel,
    required this.systemCode,
    required this.icon,
    required this.accent,
    required this.availableModules,
  });

  final Sport sport;
  final String label;
  final String shortLabel;
  final String systemCode;
  final IconData icon;
  final Color accent;
  final List<String> availableModules;
}

const sportModules = <SportModule>[
  SportModule(
    sport: Sport.football,
    label: 'Football',
    shortLabel: 'FTBL',
    systemCode: 'SPORT://FOOTBALL',
    icon: Icons.sports_soccer,
    accent: Cyber.cyan,
    availableModules: ['MATCHES', 'PICKS', 'GAMES', 'CARDS'],
  ),
  SportModule(
    sport: Sport.cricket,
    label: 'Cricket',
    shortLabel: 'CRKT',
    systemCode: 'SPORT://CRICKET',
    icon: Icons.sports_cricket,
    accent: Cyber.lime,
    availableModules: ['MATCHES', 'PICKS', 'FOLLOWING'],
  ),
  SportModule(
    sport: Sport.motorsport,
    label: 'Motorsport',
    shortLabel: 'Motorsport',
    systemCode: 'SPORT://MOTORSPORT',
    icon: Icons.sports_motorsports,
    accent: Cyber.f1Red,
    availableModules: ['FOLLOWING', 'COMING SOON'],
  ),
  SportModule(
    sport: Sport.basketball,
    label: 'Basket',
    shortLabel: 'BALL',
    systemCode: 'SPORT://BASKETBALL',
    icon: Icons.sports_basketball,
    accent: Cyber.gold,
    availableModules: ['FOLLOWING', 'COMING SOON'],
  ),
  SportModule(
    sport: Sport.tennis,
    label: 'Tennis',
    shortLabel: 'TENNIS',
    systemCode: 'SPORT://TENNIS',
    icon: Icons.sports_tennis,
    accent: Cyber.cyan,
    availableModules: ['FOLLOWING', 'COMING SOON'],
  ),
];

SportModule sportModuleFor(Sport sport) {
  for (final module in sportModules) {
    if (module.sport == sport) return module;
  }
  return sportModules.first;
}

Sport sportFromStorage(String? raw) {
  if (raw == null || raw.isEmpty) return Sport.football;
  // Pre-rename installs persisted the enum name 'f1'; keep resolving it to
  // the renamed Sport.motorsport so existing installs don't silently reset
  // to football.
  if (raw == 'f1') return Sport.motorsport;
  for (final sport in Sport.values) {
    if (sport.name == raw) return sport;
  }
  return Sport.football;
}
