class StoredDeckSlot {
  const StoredDeckSlot({
    required this.id,
    required this.name,
    required this.attackers,
    required this.defenders,
    required this.actions,
  });

  final String id;
  final String name;
  final List<String> attackers;
  final List<String> defenders;
  final List<String> actions;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'attackers': attackers,
    'defenders': defenders,
    'actions': actions,
  };

  static StoredDeckSlot fromJson(Map<String, dynamic> json) => StoredDeckSlot(
    id: json['id'] as String,
    name: json['name'] as String,
    attackers: List<String>.from(json['attackers'] as List),
    defenders: List<String>.from(json['defenders'] as List),
    actions: List<String>.from(json['actions'] as List),
  );
}

const defaultDeckSlots = [
  StoredDeckSlot(
    id: 'slot-1',
    name: 'World Icons',
    attackers: ['fra-kylian-mbappe', 'eng-harry-kane'],
    defenders: ['ned-virgil-van-dijk', 'esp-rodri'],
    actions: ['act1', 'act2', 'act6', 'act7', 'act8', 'act15'],
  ),
];
