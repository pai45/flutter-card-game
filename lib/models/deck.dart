import 'football_chess.dart';

class StoredDeckSlot {
  const StoredDeckSlot({
    required this.id,
    required this.name,
    required this.attackers,
    required this.defenders,
    required this.actions,
    this.keeper,
    this.batsmen = const [],
    this.finalOverBatsmen = const [],
    this.basketballPlayers = const [],
    this.basketballStarter,
    this.tennisPlayers = const [],
    this.tennisStarter,
    this.chessFormation,
  });

  final String id;
  final String name;
  final List<String> attackers;
  final List<String> defenders;
  final List<String> actions;
  final List<String> batsmen;
  final List<String> finalOverBatsmen;
  final List<String> basketballPlayers;
  final String? basketballStarter;
  final List<String> tennisPlayers;
  final String? tennisStarter;

  /// Card id of the deck's goalkeeper, or null if none is assigned yet.
  final String? keeper;

  /// Formation used when this deck is played in 5v5 Football Chess.
  /// Null means default (ChessFormation.box).
  final ChessFormation? chessFormation;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'attackers': attackers,
    'defenders': defenders,
    'actions': actions,
    'batsmen': batsmen,
    'finalOverBatsmen': finalOverBatsmen,
    'basketballPlayers': basketballPlayers,
    'basketballStarter': basketballStarter,
    'tennisPlayers': tennisPlayers,
    'tennisStarter': tennisStarter,
    'keeper': keeper,
    if (chessFormation != null) 'chessFormation': chessFormation!.name,
  };

  static StoredDeckSlot fromJson(Map<String, dynamic> json) => StoredDeckSlot(
    id: json['id'] as String,
    name: json['name'] as String,
    attackers: List<String>.from(json['attackers'] as List),
    defenders: List<String>.from(json['defenders'] as List),
    actions: List<String>.from(json['actions'] as List),
    batsmen: json['batsmen'] != null
        ? List<String>.from(json['batsmen'] as List)
        : [],
    finalOverBatsmen: json['finalOverBatsmen'] != null
        ? List<String>.from(json['finalOverBatsmen'] as List)
        : [],
    basketballPlayers: json['basketballPlayers'] != null
        ? List<String>.from(json['basketballPlayers'] as List)
        : [],
    basketballStarter: json['basketballStarter'] as String?,
    tennisPlayers: json['tennisPlayers'] != null
        ? List<String>.from(json['tennisPlayers'] as List)
        : [],
    tennisStarter: json['tennisStarter'] as String?,
    // Older saved decks predate the keeper slot, so it may be absent.
    keeper: json['keeper'] as String?,
    chessFormation: _parseFormation(json['chessFormation'] as String?),
  );
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
    batsmen: ['ind-virat-kohli', 'eng-joe-root', 'afg-rahmanullah-gurbaz'],
    finalOverBatsmen: [
      'ind-virat-kohli',
      'eng-joe-root',
      'afg-rahmanullah-gurbaz',
    ],
  ),
];
