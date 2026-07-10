import 'dart:ui';

import '../models/super_over.dart';

/// IPL team jersey palettes for Super Over.
///
/// These are CONTENT colors (like card-rarity and team colors), not UI chrome.
/// Names use generic city archetypes to avoid trademark issues. All UI around
/// them still uses `AppTheme`/`Cyber` tokens.
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
}

const List<CricketJerseySpec> cricketJerseys = [
  CricketJerseySpec(
    jersey: CricketJersey.mumbai,
    name: 'MUMBAI INDIANS',
    shortName: 'MI',
    primary: Color(0xFF004BA0),
    accent: Color(0xFFD4AF37),
  ),
  CricketJerseySpec(
    jersey: CricketJersey.chennai,
    name: 'CHENNAI KINGS',
    shortName: 'CSK',
    primary: Color(0xFFFFCE00),
    accent: Color(0xFF0066B2),
  ),
  CricketJerseySpec(
    jersey: CricketJersey.bangalore,
    name: 'ROYAL BANGALORE',
    shortName: 'RCB',
    primary: Color(0xFFD4213D),
    accent: Color(0xFF000000),
  ),
  CricketJerseySpec(
    jersey: CricketJersey.kolkata,
    name: 'KOLKATA RIDERS',
    shortName: 'KKR',
    primary: Color(0xFF3A225D),
    accent: Color(0xFFD4AF37),
  ),
  CricketJerseySpec(
    jersey: CricketJersey.delhi,
    name: 'DELHI CAPITALS',
    shortName: 'DC',
    primary: Color(0xFF1A4A8A),
    accent: Color(0xFFEF3E42),
  ),
  CricketJerseySpec(
    jersey: CricketJersey.rajasthan,
    name: 'RAJASTHAN ROYALS',
    shortName: 'RR',
    primary: Color(0xFFE83E8C),
    accent: Color(0xFF254AA5),
  ),
  CricketJerseySpec(
    jersey: CricketJersey.punjab,
    name: 'PUNJAB KINGS',
    shortName: 'PBKS',
    primary: Color(0xFFD71920),
    accent: Color(0xFFDCDDDF),
  ),
  CricketJerseySpec(
    jersey: CricketJersey.hyderabad,
    name: 'SUNRISERS',
    shortName: 'SRH',
    primary: Color(0xFFFF822A),
    accent: Color(0xFF000000),
  ),
  CricketJerseySpec(
    jersey: CricketJersey.lucknow,
    name: 'LUCKNOW GIANTS',
    shortName: 'LSG',
    primary: Color(0xFF3496CC),
    accent: Color(0xFF88C540),
  ),
  CricketJerseySpec(
    jersey: CricketJersey.gujarat,
    name: 'GUJARAT TITANS',
    shortName: 'GT',
    primary: Color(0xFF1C1C2E),
    accent: Color(0xFF69B3E7),
  ),
];

CricketJerseySpec cricketJerseySpec(CricketJersey jersey) =>
    cricketJerseys.firstWhere((spec) => spec.jersey == jersey);
