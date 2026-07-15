import 'dart:ui';

import '../models/super_over.dart';

/// Original, sponsor-free jersey colourways used only by Super Over.
class CricketJerseySpec {
  const CricketJerseySpec({
    required this.jersey,
    required this.name,
    required this.shortName,
    required this.primary,
    required this.accent,
  });

  final CricketJersey jersey;
  final String name;
  final String shortName;
  final Color primary;
  final Color accent;

  String get id => jersey.name;
}

const List<CricketJerseySpec> cricketJerseys = [
  CricketJerseySpec(
    jersey: CricketJersey.nightCyan,
    name: 'NIGHT CYAN',
    shortName: 'NIGHT',
    primary: Color(0xFF083C5C),
    accent: Color(0xFF5CDFFF),
  ),
  CricketJerseySpec(
    jersey: CricketJersey.violetPulse,
    name: 'VIOLET PULSE',
    shortName: 'PULSE',
    primary: Color(0xFF3A245D),
    accent: Color(0xFFC27AFF),
  ),
  CricketJerseySpec(
    jersey: CricketJersey.goldStrike,
    name: 'GOLD STRIKE',
    shortName: 'STRIKE',
    primary: Color(0xFF4A3812),
    accent: Color(0xFFFDC700),
  ),
  CricketJerseySpec(
    jersey: CricketJersey.emberRed,
    name: 'EMBER RED',
    shortName: 'EMBER',
    primary: Color(0xFF541C2A),
    accent: Color(0xFFFF5573),
  ),
  CricketJerseySpec(
    jersey: CricketJersey.tealVector,
    name: 'TEAL VECTOR',
    shortName: 'VECTOR',
    primary: Color(0xFF0A4544),
    accent: Color(0xFF42E8C8),
  ),
  CricketJerseySpec(
    jersey: CricketJersey.monoIce,
    name: 'MONO ICE',
    shortName: 'ICE',
    primary: Color(0xFF26313D),
    accent: Color(0xFFE8F4FF),
  ),
];

CricketJerseySpec cricketJerseySpec(CricketJersey jersey) =>
    cricketJerseys.firstWhere((spec) => spec.jersey == jersey);

/// Reads both the current neutral IDs and every legacy IPL-style enum value.
///
/// The mapping is fixed so an existing selection always migrates to the same
/// original colour family on every device.
CricketJersey superOverJerseyFromStoredId(String? storedId) {
  final id = _normalizedId(storedId);
  return switch (id) {
    'nightcyan' => CricketJersey.nightCyan,
    'violetpulse' => CricketJersey.violetPulse,
    'goldstrike' => CricketJersey.goldStrike,
    'emberred' => CricketJersey.emberRed,
    'tealvector' => CricketJersey.tealVector,
    'monoice' => CricketJersey.monoIce,

    // v1 enum/display/code aliases.
    'mumbai' || 'mumbaiindians' || 'mi' => CricketJersey.nightCyan,
    'chennai' || 'chennaikings' || 'csk' => CricketJersey.goldStrike,
    'bangalore' || 'royalbangalore' || 'rcb' => CricketJersey.emberRed,
    'kolkata' || 'kolkatariders' || 'kkr' => CricketJersey.violetPulse,
    'delhi' || 'delhicapitals' || 'dc' => CricketJersey.nightCyan,
    'rajasthan' || 'rajasthanroyals' || 'rr' => CricketJersey.violetPulse,
    'punjab' || 'punjabkings' || 'pbks' => CricketJersey.emberRed,
    'hyderabad' || 'sunrisers' || 'srh' => CricketJersey.tealVector,
    'lucknow' || 'lucknowgiants' || 'lsg' => CricketJersey.monoIce,
    'gujarat' || 'gujarattitans' || 'gt' => CricketJersey.tealVector,
    _ => CricketJersey.nightCyan,
  };
}

String _normalizedId(String? value) =>
    (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
