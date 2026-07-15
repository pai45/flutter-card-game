import '../models/cards.dart';
import '../models/super_over.dart';

/// A presentation-safe Super Over identity backed by a shared cricket card.
///
/// The shared [cardId], rating and trait-derived archetype remain authoritative,
/// while all identity shown in Super Over is generated independently. This type
/// deliberately has no player name, country, team or portrait fields.
class SuperOverBatterProfile {
  const SuperOverBatterProfile({
    required this.cardId,
    required this.displayName,
    required this.rating,
    required this.archetype,
    required this.battingPosition,
    required this.jerseyNumber,
    required this.visualSeed,
  });

  /// Internal link to ownership, deck order, mastery and settlement data.
  final String cardId;

  /// Original fictional callsign. This is the only athlete identity UI should
  /// render inside Super Over.
  final String displayName;
  final int rating;
  final CricketBattingStyle archetype;

  /// One-based position in the selected three-card batting unit.
  final int battingPosition;
  final int jerseyNumber;

  /// Stable seed for procedural face, hair and equipment variants.
  final int visualSeed;

  String get archetypeLabel => switch (archetype) {
    CricketBattingStyle.anchor => 'ANCHOR',
    CricketBattingStyle.powerHitter => 'POWER HITTER',
    CricketBattingStyle.improviser => 'IMPROVISER',
  };

  /// Safe renderable fields only. [cardId] remains an internal lookup key and
  /// must not be displayed to the player.
  Map<String, Object> toPresentationJson() => {
    'displayName': displayName,
    'rating': rating,
    'archetype': archetype.name,
    'battingPosition': battingPosition,
    'jerseyNumber': jerseyNumber,
    'visualSeed': visualSeed,
  };
}

/// Converts shared cricket cards into original, mode-local presentation data.
abstract final class SuperOverBatterProfiles {
  static const List<String> _callsigns = [
    'ASTER',
    'BLAZE',
    'CIPHER',
    'COMET',
    'DRIFT',
    'ECHO',
    'FLUX',
    'HALO',
    'ION',
    'JETT',
    'KESTREL',
    'LYNX',
    'MAKO',
    'NOVA',
    'ORBIT',
    'PULSE',
    'QUILL',
    'RIFT',
    'SOL',
    'TEMPEST',
    'VANTA',
    'VECTOR',
    'WILDFIRE',
    'ZENITH',
  ];

  static SuperOverBatterProfile fromCard(
    PlayerCard card, {
    required int orderIndex,
  }) {
    final seed = _stableHash(card.id);
    final callsign = _callsigns[seed % _callsigns.length];
    final jerseyNumber = 10 + seed % 90;
    return SuperOverBatterProfile(
      cardId: card.id,
      displayName: '$callsign $jerseyNumber',
      rating: card.rating,
      archetype: archetypeForTrait(card.trait),
      battingPosition: orderIndex.clamp(0, 2) + 1,
      jerseyNumber: jerseyNumber,
      visualSeed: seed,
    );
  }

  static List<SuperOverBatterProfile> fromBattingOrder(
    Iterable<PlayerCard> cards,
  ) => [
    for (final (index, card) in cards.take(3).indexed)
      fromCard(card, orderIndex: index),
  ];

  static CricketBattingStyle archetypeForTrait(String trait) {
    return switch (trait.trim().toLowerCase()) {
      'all-rounder' => CricketBattingStyle.powerHitter,
      'wicket-keeper' => CricketBattingStyle.improviser,
      _ => CricketBattingStyle.anchor,
    };
  }

  /// FNV-1a rather than `String.hashCode`, so identities stay stable across
  /// platforms, process restarts and Dart SDK updates.
  static int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
