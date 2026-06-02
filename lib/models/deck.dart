class StoredDeckSlot {
  const StoredDeckSlot({
    required this.id,
    required this.name,
    required this.attackers,
    required this.defenders,
    required this.actions,
    this.keeper,
  });

  final String id;
  final String name;
  final List<String> attackers;
  final List<String> defenders;
  final List<String> actions;

  /// Card id of the deck's goalkeeper, or null if none is assigned yet.
  final String? keeper;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'attackers': attackers,
    'defenders': defenders,
    'actions': actions,
    'keeper': keeper,
  };

  static StoredDeckSlot fromJson(Map<String, dynamic> json) => StoredDeckSlot(
    id: json['id'] as String,
    name: json['name'] as String,
    attackers: List<String>.from(json['attackers'] as List),
    defenders: List<String>.from(json['defenders'] as List),
    actions: List<String>.from(json['actions'] as List),
    // Older saved decks predate the keeper slot, so it may be absent.
    keeper: json['keeper'] as String?,
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
  ),
];
