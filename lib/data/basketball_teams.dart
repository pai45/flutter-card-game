import 'package:flutter/material.dart';

class BasketballTeamLivery {
  const BasketballTeamLivery({
    required this.id,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.accent,
  });

  final String id;
  final String name;
  final Color primary;
  final Color secondary;
  final Color accent;
}

const List<BasketballTeamLivery> basketballTeams = [
  BasketballTeamLivery(
    id: 'lakers',
    name: 'Los Angeles',
    primary: Color(0xFFFDB927), // Gold
    secondary: Color(0xFF552583), // Purple
    accent: Color(0xFF000000), // Black
  ),
  BasketballTeamLivery(
    id: 'bulls',
    name: 'Chicago',
    primary: Color(0xFFCE1141), // Red
    secondary: Color(0xFF000000), // Black
    accent: Color(0xFFFFFFFF), // White
  ),
  BasketballTeamLivery(
    id: 'celtics',
    name: 'Boston',
    primary: Color(0xFF007A33), // Green
    secondary: Color(0xFFFFFFFF), // White
    accent: Color(0xFF000000), // Black
  ),
  BasketballTeamLivery(
    id: 'warriors',
    name: 'Golden State',
    primary: Color(0xFF1D428A), // Royal Blue
    secondary: Color(0xFFFFC72C), // Golden Yellow
    accent: Color(0xFFFFFFFF), // White
  ),
  BasketballTeamLivery(
    id: 'heat',
    name: 'Miami',
    primary: Color(0xFF98002E), // Red
    secondary: Color(0xFFF9A01B), // Yellow
    accent: Color(0xFF000000), // Black
  ),
  BasketballTeamLivery(
    id: 'knicks',
    name: 'New York',
    primary: Color(0xFFF58426), // Orange
    secondary: Color(0xFF006BB6), // Blue
    accent: Color(0xFFFFFFFF), // White
  ),
];

BasketballTeamLivery basketballTeamById(String id) {
  return basketballTeams.firstWhere((team) => team.id == id, orElse: () => basketballTeams.first);
}
