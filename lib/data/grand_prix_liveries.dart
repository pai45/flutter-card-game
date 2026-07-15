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

GrandPrixLiverySpec grandPrixLiverySpec(GrandPrixLivery livery) =>
    grandPrixLiveries.firstWhere((spec) => spec.livery == livery);
