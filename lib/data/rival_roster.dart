import 'dart:math';

import '../models/rival_dossier.dart';

/// One fabricated leaderboard rival. There is no backend — a rival is just a
/// display name + canonical XP (their `base`), from which the dossier, avatar,
/// level and player tag are all derived deterministically. Shared by the
/// leaderboard, the friends arena and the player-tag resolver so a rival reads
/// identically everywhere.
class RivalSeed {
  const RivalSeed(
    this.name,
    this.base,
    this.movement, {
    this.isNew = false,
    this.badge,
    this.isUser = false,
  });

  final String name;
  final int base;

  /// >0 climbed, <0 dropped, 0 held.
  final int movement;
  final bool isNew;
  final String? badge;
  final bool isUser;

  bool get isPro => badge == 'PRO';
}

// Named users keep the exact scores from the brief; filler rivals are inserted
// above so the current user ("pai", 3870 XP, ↑3) lands at rank #12.
const List<RivalSeed> kRivalRoster = [
  RivalSeed('jarvis', 3910, -1, badge: 'PRO'),
  RivalSeed('Vortex', 3905, 2),
  RivalSeed('NeoStrike', 3901, -1, badge: 'PRO'),
  RivalSeed('PhantomX', 3897, 1),
  RivalSeed('Blaze', 3893, 4),
  RivalSeed('Titan', 3889, -2),
  RivalSeed('EchoZero', 3885, 1, badge: 'PRO'),
  RivalSeed('Reaper', 3881, -3),
  RivalSeed('NovaQ', 3878, 2),
  RivalSeed('Falcon9', 3874, -1),
  RivalSeed('Striker', 3872, 5, isNew: true),
  RivalSeed('pai', 3870, 3, isUser: true), // rank 12 — current user
  RivalSeed('Diwakar', 3860, -2),
  RivalSeed('monika', 3830, 1, badge: 'PRO'),
  RivalSeed('Raja2000', 3740, -1),
  RivalSeed('Invincible51', 3670, 4),
  RivalSeed('rocky', 3380, -2),
  RivalSeed('Mirage', 3120, 1),
  RivalSeed('Zenith', 2980, -1, isNew: true),
  RivalSeed('Ghost', 2810, 2),
  RivalSeed('Drift', 2640, -3),
  RivalSeed('Volt', 2470, 1),
  RivalSeed('Comet', 2300, -1),
  RivalSeed('Rookie7', 1980, 0, isNew: true),
];

/// Unambiguous alphabet for player tags (no 0/O/1/I/L look-alikes).
const String _tagAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

int _seedHash(String value) {
  var hash = 0;
  for (final unit in value.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}

/// An 8-character `XXXX-XXXX` tag expanded deterministically from [seed].
String _tagFromSeed(int seed) {
  var state = (seed ^ 0x5f3759df) & 0x7fffffff;
  final out = StringBuffer();
  for (var i = 0; i < 8; i++) {
    if (i == 4) out.write('-');
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    out.write(_tagAlphabet[state % _tagAlphabet.length]);
  }
  return out.toString();
}

/// The stable shareable tag for a rival [name] (same name → same tag). Used so
/// pasting a rival's tag in the friends search resolves back to that player.
String playerTagForName(String name) => _tagFromSeed(_seedHash(name));

/// A fresh random tag, used once for the local player and then persisted.
String randomPlayerTag([Random? rng]) =>
    _tagFromSeed((rng ?? Random()).nextInt(0x7fffffff));

/// Normalises a search query to a comparable tag (upper-case, no spaces/dashes).
String _normaliseTag(String query) =>
    query.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

/// Resolves a friends-search [query] to a known rival, matching (in order) an
/// exact name, an exact tag, then a name substring. Returns null when nothing
/// matches. The local user is never a result (you can't add yourself).
RivalSeed? resolveRival(String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return null;
  final upper = trimmed.toUpperCase();
  final normTag = _normaliseTag(trimmed);

  RivalSeed? byName;
  RivalSeed? byTag;
  RivalSeed? byContains;
  for (final seed in kRivalRoster) {
    if (seed.isUser) continue;
    final name = seed.name.toUpperCase();
    if (name == upper) byName ??= seed;
    if (playerTagForName(seed.name).replaceAll('-', '') == normTag) {
      byTag ??= seed;
    }
    if (byContains == null && upper.length >= 2 && name.contains(upper)) {
      byContains = seed;
    }
  }
  return byName ?? byTag ?? byContains;
}

/// The fabricated level for a rival seed (drives the search result + rows).
int rivalLevelFor(RivalSeed seed) =>
    RivalDossier.fromSeed(name: seed.name, xp: seed.base, pro: seed.isPro).level;

/// Deterministic "online now" flag for a rival, so the friends online count is
/// stable per session without any backend (~55% of rivals read as online).
bool rivalIsOnline(String name) => _seedHash(name) % 20 < 11;
