/// Content colours for Final Over's athletes.
///
/// Two independent sources, exactly as Hoop Duel splits them:
///   • a [FinalOverKit] is *clothing* — the shirt, the pads, the helmet, the
///     number. The player picks one in the lobby; the bowling side gets a
///     contrasting one.
///   • a [FinalOverLook] is *the person* — skin and hair. Never a team colour.
///
/// Everything else on screen (pitch, HUD, stumps) comes from `Cyber` tokens.
library;

import 'dart:ui';

/// A team kit: shirt [primary], trim [secondary], number/boots [accent].
class FinalOverKit {
  const FinalOverKit({
    required this.id,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.accent,
  });

  final String id;
  final String name;

  /// Shirt, helmet dome, shoulder bar. Trousers are this, darkened.
  final Color primary;

  /// Shirt trim, pads, gloves, sleeve.
  final Color secondary;

  /// Jersey number, boots, the second shirt stripe.
  final Color accent;
}

const finalOverKits = <FinalOverKit>[
  FinalOverKit(
    id: 'voltage',
    name: 'VOLTAGE',
    primary: Color(0xFF1B48D6),
    secondary: Color(0xFFEFF3FF),
    accent: Color(0xFF35E0FF),
  ),
  FinalOverKit(
    id: 'ember',
    name: 'EMBER',
    primary: Color(0xFFD83A1E),
    secondary: Color(0xFF2A1410),
    accent: Color(0xFFFFB53D),
  ),
  FinalOverKit(
    id: 'meridian',
    name: 'MERIDIAN',
    primary: Color(0xFF0E8A5F),
    secondary: Color(0xFFF2FFF9),
    accent: Color(0xFFB4FF3D),
  ),
  FinalOverKit(
    id: 'sovereign',
    name: 'SOVEREIGN',
    primary: Color(0xFF6A2BD9),
    secondary: Color(0xFFE9DDFF),
    accent: Color(0xFFFFD24A),
  ),
  FinalOverKit(
    id: 'monsoon',
    name: 'MONSOON',
    primary: Color(0xFF1F7FA8),
    secondary: Color(0xFF0B2C3B),
    accent: Color(0xFF7FE9FF),
  ),
  FinalOverKit(
    id: 'saffron',
    name: 'SAFFRON',
    primary: Color(0xFFE87722),
    secondary: Color(0xFF14243D),
    accent: Color(0xFFFFF0C2),
  ),
  FinalOverKit(
    id: 'obsidian',
    name: 'OBSIDIAN',
    primary: Color(0xFF37415C),
    secondary: Color(0xFF9AA8C7),
    accent: Color(0xFFFF3D77),
  ),
  FinalOverKit(
    id: 'coral',
    name: 'CORAL',
    primary: Color(0xFFE0407A),
    secondary: Color(0xFFFFE3EC),
    accent: Color(0xFF20E3B2),
  ),
];

/// The one kit every player starts with — no coin cost.
const finalOverFreeKitId = 'voltage';

/// Coin price for every non-free kit in the Shop.
const finalOverKitCoinPrice = 100;

bool isFinalOverKitFree(FinalOverKit kit) => kit.id == finalOverFreeKitId;

int finalOverKitPrice(FinalOverKit kit) =>
    isFinalOverKitFree(kit) ? 0 : finalOverKitCoinPrice;

/// Default owned kit ids for a fresh wallet.
List<String> defaultOwnedFinalOverKitIds() => [finalOverFreeKitId];

/// Ensures the free kit is always present and dedupes ids.
List<String> normalizeOwnedFinalOverKitIds(Iterable<String> ids) {
  final owned = ids.toSet()..add(finalOverFreeKitId);
  return owned.toList();
}

bool isFinalOverKitOwned(String kitId, Iterable<String> ownedKitIds) =>
    isFinalOverKitFree(finalOverKitById(kitId)) ||
    ownedKitIds.contains(kitId);

FinalOverKit finalOverKitById(String id) =>
    finalOverKits.firstWhere((k) => k.id == id, orElse: () => finalOverKits.first);

/// The bowling side always wears something other than the batter's kit, so the
/// two never read as one team.
FinalOverKit finalOverOpponentKit(String playerKitId) {
  final index = finalOverKits.indexWhere((k) => k.id == playerKitId);
  final safe = index < 0 ? 0 : index;
  return finalOverKits[(safe + 3) % finalOverKits.length];
}

/// Skin + hair. Same 5-tone ladder Hoop Duel's athlete looks are built from.
class FinalOverLook {
  const FinalOverLook({required this.skin, required this.hair});

  final Color skin;
  final Color hair;
}

const _looks = <FinalOverLook>[
  FinalOverLook(skin: Color(0xFF6B4423), hair: Color(0xFF17110D)),
  FinalOverLook(skin: Color(0xFF8D5524), hair: Color(0xFF1C1310)),
  FinalOverLook(skin: Color(0xFFC68642), hair: Color(0xFF2B1D14)),
  FinalOverLook(skin: Color(0xFFE0AC69), hair: Color(0xFF4A2F1B)),
  FinalOverLook(skin: Color(0xFFF1C27D), hair: Color(0xFF6B4A2A)),
];

/// Stable per-actor look. Uses a hand-rolled hash (never `String.hashCode`,
/// which is not stable across Dart versions) so a given actor keeps the same
/// face between sessions and between the lobby preview and the pitch.
FinalOverLook finalOverLookFor(String actorId) =>
    _looks[_stableHash(actorId) % _looks.length];

/// Shirt number for an actor, 0–99.
int finalOverNumberFor(String actorId) => _stableHash(actorId) % 100;

int _stableHash(String id) =>
    id.codeUnits.fold(0, (acc, unit) => (acc * 31 + unit) & 0x7fffffff);
