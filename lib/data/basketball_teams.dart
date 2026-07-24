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
    id: 'statoz',
    name: 'STATOZ',
    primary: Color(0xFF0B4F5C), // Deep teal body
    secondary: Color(0xFF061018), // Near-black trim
    accent: Color(0xFF35E0FF), // Cyan number/stripe
  ),
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
  BasketballTeamLivery(
    id: 'nets',
    name: 'Brooklyn',
    primary: Color(0xFF000000), // Black
    secondary: Color(0xFFFFFFFF), // White
    accent: Color(0xFF707271), // Grey
  ),
  BasketballTeamLivery(
    id: 'spurs',
    name: 'San Antonio',
    primary: Color(0xFFC4CED4), // Silver
    secondary: Color(0xFF000000), // Black
    accent: Color(0xFFEF426F), // Pink
  ),
  BasketballTeamLivery(
    id: 'suns',
    name: 'Phoenix',
    primary: Color(0xFF1D1160), // Dark Purple
    secondary: Color(0xFFE56020), // Orange
    accent: Color(0xFFF9AD1B), // Yellow
  ),
  BasketballTeamLivery(
    id: 'bucks',
    name: 'Milwaukee',
    primary: Color(0xFF00471B), // Hunter Green
    secondary: Color(0xFFEEE1C6), // Cream
    accent: Color(0xFFFFFFFF), // White
  ),
  BasketballTeamLivery(
    id: 'mavs',
    name: 'Dallas',
    primary: Color(0xFF00538C), // Royal Blue
    secondary: Color(0xFFB8C4CA), // Silver
    accent: Color(0xFFFFFFFF), // White
  ),
  BasketballTeamLivery(
    id: 'nuggets',
    name: 'Denver',
    primary: Color(0xFF0E2240), // Midnight Blue
    secondary: Color(0xFFFEC524), // Sunshine Yellow
    accent: Color(0xFF8B2131), // Maroon
  ),
];

/// The one jersey every player starts with — no coin cost.
const basketballFreeTeamId = 'statoz';

/// Coin price for every non-free jersey in the Shop.
const basketballTeamCoinPrice = 100;

bool isBasketballTeamFree(BasketballTeamLivery team) =>
    team.id == basketballFreeTeamId;

int basketballTeamPrice(BasketballTeamLivery team) =>
    isBasketballTeamFree(team) ? 0 : basketballTeamCoinPrice;

/// Default owned jersey ids for a fresh wallet.
List<String> defaultOwnedBasketballTeamIds() => [basketballFreeTeamId];

/// Ensures the free jersey is always present and dedupes ids.
List<String> normalizeOwnedBasketballTeamIds(Iterable<String> ids) {
  final owned = ids.toSet()..add(basketballFreeTeamId);
  return owned.toList();
}

bool isBasketballTeamOwned(String teamId, Iterable<String> ownedTeamIds) =>
    isBasketballTeamFree(basketballTeamById(teamId)) ||
    ownedTeamIds.contains(teamId);

BasketballTeamLivery basketballTeamById(String id) {
  return basketballTeams.firstWhere(
    (team) => team.id == id,
    orElse: () => basketballTeams.first,
  );
}
