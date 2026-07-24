import 'football_chess.dart';

const _deckSlotSentinel = Object();

class StoredDeckSlot {
  const StoredDeckSlot({
    required this.id,
    required this.name,
    required this.attackers,
    required this.defenders,
    required this.actions,
    this.keeper,
    this.finalOverBatsmen = const [],
    this.basketballPlayers = const [],
    this.basketballStarter,
    this.tennisPlayers = const [],
    this.tennisStarter,
    this.racingPlayers = const [],
    this.racingStarter,
    this.chessFormation,
  });

  final String id;
  final String name;
  final List<String> attackers;
  final List<String> defenders;
  final List<String> actions;
  final List<String> finalOverBatsmen;
  final List<String> basketballPlayers;
  final String? basketballStarter;
  final List<String> tennisPlayers;
  final String? tennisStarter;
  final List<String> racingPlayers;
  final String? racingStarter;

  /// Card id of the deck's goalkeeper, or null if none is assigned yet.
  final String? keeper;

  /// Formation used when this deck is played in 5v5 Football Chess.
  /// Null means default (ChessFormation.box).
  final ChessFormation? chessFormation;

  StoredDeckSlot copyWith({
    String? id,
    String? name,
    List<String>? attackers,
    List<String>? defenders,
    List<String>? actions,
    List<String>? finalOverBatsmen,
    List<String>? basketballPlayers,
    Object? basketballStarter = _deckSlotSentinel,
    List<String>? tennisPlayers,
    Object? tennisStarter = _deckSlotSentinel,
    List<String>? racingPlayers,
    Object? racingStarter = _deckSlotSentinel,
    Object? keeper = _deckSlotSentinel,
    Object? chessFormation = _deckSlotSentinel,
  }) => StoredDeckSlot(
    id: id ?? this.id,
    name: name ?? this.name,
    attackers: attackers ?? this.attackers,
    defenders: defenders ?? this.defenders,
    actions: actions ?? this.actions,
    finalOverBatsmen: finalOverBatsmen ?? this.finalOverBatsmen,
    basketballPlayers: basketballPlayers ?? this.basketballPlayers,
    basketballStarter: basketballStarter == _deckSlotSentinel
        ? this.basketballStarter
        : basketballStarter as String?,
    tennisPlayers: tennisPlayers ?? this.tennisPlayers,
    tennisStarter: tennisStarter == _deckSlotSentinel
        ? this.tennisStarter
        : tennisStarter as String?,
    racingPlayers: racingPlayers ?? this.racingPlayers,
    racingStarter: racingStarter == _deckSlotSentinel
        ? this.racingStarter
        : racingStarter as String?,
    keeper: keeper == _deckSlotSentinel ? this.keeper : keeper as String?,
    chessFormation: chessFormation == _deckSlotSentinel
        ? this.chessFormation
        : chessFormation as ChessFormation?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'attackers': attackers,
    'defenders': defenders,
    'actions': actions,
    'finalOverBatsmen': finalOverBatsmen,
    'basketballPlayers': basketballPlayers,
    'basketballStarter': basketballStarter,
    'tennisPlayers': tennisPlayers,
    'tennisStarter': tennisStarter,
    'racingPlayers': racingPlayers,
    'racingStarter': racingStarter,
    'keeper': keeper,
    if (chessFormation != null) 'chessFormation': chessFormation!.name,
  };

  static StoredDeckSlot fromJson(Map<String, dynamic> json) {
    final legacyBatsmen = json['batsmen'] != null
        ? List<String>.from(json['batsmen'] as List)
        : const <String>[];
    final finalOverBatsmen = json['finalOverBatsmen'] != null
        ? List<String>.from(json['finalOverBatsmen'] as List)
        : legacyBatsmen;
    return StoredDeckSlot(
      id: json['id'] as String,
      name: json['name'] as String,
      attackers: List<String>.from(json['attackers'] as List),
      defenders: List<String>.from(json['defenders'] as List),
      actions: List<String>.from(json['actions'] as List),
      finalOverBatsmen: finalOverBatsmen,
      basketballPlayers: json['basketballPlayers'] != null
          ? List<String>.from(json['basketballPlayers'] as List)
          : [],
      basketballStarter: json['basketballStarter'] as String?,
      tennisPlayers: json['tennisPlayers'] != null
          ? List<String>.from(json['tennisPlayers'] as List)
          : [],
      tennisStarter: json['tennisStarter'] as String?,
      racingPlayers: json['racingPlayers'] != null
          ? List<String>.from(json['racingPlayers'] as List)
          : [],
      racingStarter: json['racingStarter'] as String?,
      // Older saved decks predate the keeper slot, so it may be absent.
      keeper: json['keeper'] as String?,
      chessFormation: _parseFormation(json['chessFormation'] as String?),
    );
  }
}

ChessFormation? _parseFormation(String? name) {
  if (name == null) return null;
  return ChessFormation.values.firstWhere(
    (f) => f.name == name,
    orElse: () => ChessFormation.box,
  );
}

const defaultDeckSlots = [
  StoredDeckSlot(
    id: 'slot-1',
    name: 'World Icons',
    attackers: ['fra-kylian-mbappe', 'eng-harry-kane'],
    defenders: ['ned-virgil-van-dijk', 'esp-rodri'],
    actions: [
      'act1-gold',
      'act2-gold',
      'act6-gold',
      'act7-gold',
      'act8-gold',
      'act15-gold',
    ],
    keeper: 'bra-alisson-becker',
    finalOverBatsmen: [
      'ind-virat-kohli',
      'eng-joe-root',
      'afg-rahmanullah-gurbaz',
    ],
  ),
];
