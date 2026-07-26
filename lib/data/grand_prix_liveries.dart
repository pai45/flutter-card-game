import 'dart:ui';

import '../models/grand_prix.dart';

/// Constructor-color livery palette for Grand Prix Dash.
///
/// These are CONTENT colors (like card-rarity and team colors), not UI chrome
/// — the one documented exception to the "no hardcoded colors" rule. All UI
/// around them still uses `AppTheme`/`Cyber` tokens. Names are generic
/// archetypes to avoid constructor trademarks.
class GrandPrixLiverySpec {
  const GrandPrixLiverySpec({
    required this.livery,
    required this.name,
    required this.primary,
    required this.accent,
  });

  final GrandPrixLivery livery;
  final String name;
  final Color primary;
  final Color accent;
}

const List<GrandPrixLiverySpec> grandPrixLiveries = [
  GrandPrixLiverySpec(
    livery: GrandPrixLivery.gridLine,
    name: 'GRID LINE',
    primary: Color(0xFF0A0E14),
    accent: Color(0xFF35E7FF),
  ),
  GrandPrixLiverySpec(
    livery: GrandPrixLivery.scarlet,
    name: 'SCARLET',
    primary: Color(0xFFD8232A),
    accent: Color(0xFFFFE24A),
  ),
  GrandPrixLiverySpec(
    livery: GrandPrixLivery.silverArrow,
    name: 'SILVER ARROW',
    primary: Color(0xFFB9BFC6),
    accent: Color(0xFF00D2BE),
  ),
  GrandPrixLiverySpec(
    livery: GrandPrixLivery.papaya,
    name: 'PAPAYA',
    primary: Color(0xFFFF8000),
    accent: Color(0xFF2A9DF4),
  ),
  GrandPrixLiverySpec(
    livery: GrandPrixLivery.midnight,
    name: 'MIDNIGHT',
    primary: Color(0xFF16265C),
    accent: Color(0xFF35E7FF),
  ),
  GrandPrixLiverySpec(
    livery: GrandPrixLivery.racingGreen,
    name: 'RACING GREEN',
    primary: Color(0xFF0B5B3C),
    accent: Color(0xFFD4AF37),
  ),
  GrandPrixLiverySpec(
    livery: GrandPrixLivery.skyBlue,
    name: 'SKY BLUE',
    primary: Color(0xFF6FC5F0),
    accent: Color(0xFFF4F7FA),
  ),
];

/// The one livery every player starts with — no coin cost.
const grandPrixFreeLivery = GrandPrixLivery.gridLine;

/// Coin price for every non-free livery in the Shop.
const grandPrixLiveryCoinPrice = 100;

GrandPrixLiverySpec grandPrixLiverySpec(GrandPrixLivery livery) =>
    grandPrixLiveries.firstWhere((spec) => spec.livery == livery);

bool isGrandPrixLiveryFree(GrandPrixLivery livery) =>
    livery == grandPrixFreeLivery;

int grandPrixLiveryPrice(GrandPrixLivery livery) =>
    isGrandPrixLiveryFree(livery) ? 0 : grandPrixLiveryCoinPrice;

List<String> defaultOwnedGrandPrixLiveryIds() => [grandPrixFreeLivery.name];

List<String> normalizeOwnedGrandPrixLiveryIds(Iterable<String> ids) {
  final owned = ids.toSet()..add(grandPrixFreeLivery.name);
  return owned.toList();
}

bool isGrandPrixLiveryOwned(String liveryId, Iterable<String> ownedLiveryIds) =>
    isGrandPrixLiveryFree(grandPrixLiveryFromName(liveryId)) ||
    ownedLiveryIds.contains(liveryId);

GrandPrixLivery ensureEquippedLiveryOwned(
  Iterable<String> ownedLiveryIds,
  GrandPrixLivery equipped,
) {
  if (isGrandPrixLiveryOwned(equipped.name, ownedLiveryIds)) return equipped;
  return grandPrixFreeLivery;
}
