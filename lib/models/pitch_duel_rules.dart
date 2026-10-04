import '../config/enums.dart';
import 'cards.dart';

/// Pitch-only metadata. Collection IDs, ratings and other sports stay unchanged.
enum PitchAffinity { finisher, creator, runner, stopper, reader, anchor }

extension PitchAffinityLabel on PitchAffinity {
  String get label => name.toUpperCase();
  String get asset => 'assets/pitch_duel/affinities/$name.svg';
}

const pitchAffinityBonus = 4;
const pitchScenarioComboBonus = 6;
const pitchTimingMax = 8;

const pitchAffinityActions = <PitchAffinity, Set<String>>{
  PitchAffinity.finisher: {'act1', 'act2', 'act5'},
  PitchAffinity.creator: {'act3', 'act15'},
  PitchAffinity.runner: {'act4', 'act6', 'act16'},
  PitchAffinity.stopper: {'act7', 'act12'},
  PitchAffinity.reader: {'act8', 'act11', 'act15'},
  PitchAffinity.anchor: {'act9', 'act10', 'act16'},
};

const pitchScenarioActions = <String, Set<String>>{
  'sc1': {'act1', 'act6', 'act8', 'act11', 'act16'},
  'sc2': {'act3', 'act4', 'act7', 'act10', 'act15'},
  'sc3': {'act2', 'act5', 'act9', 'act10'},
  'sc4': {'act2', 'act6', 'act8', 'act12', 'act14'},
  'sc5': {'act1', 'act3', 'act9', 'act11'},
  'sc6': {'act4', 'act6', 'act10', 'act11', 'act16'},
  'sc7': {'act2', 'act5', 'act7', 'act12', 'act14', 'act15'},
};

String pitchActionBaseId(ActionCard action) => action.id.split('-').first;
String pitchActionAsset(ActionCard action) =>
    'assets/pitch_duel/actions/${pitchActionBaseId(action)}.svg';
String pitchScenarioAsset(ScenarioCard scenario) =>
    'assets/pitch_duel/scenarios/${scenario.id}.svg';

PitchAffinity? _deriveAffinity(PlayerCard player) {
  final trait = player.trait.toLowerCase();
  bool has(List<String> words) => words.any(trait.contains);
  if (player.role == PlayerRole.attacker) {
    if (has([
      'creator',
      'playmaker',
      'technical',
      'tempo',
      'engine',
      'final pass',
      'link-up',
      'support',
      'flair',
      'box-to-box',
    ])) {
      return PitchAffinity.creator;
    }
    if (has([
      'wing',
      'runner',
      'explosive',
      'direct',
      'press',
      'carrier',
      'inside',
    ])) {
      return PitchAffinity.runner;
    }
    return PitchAffinity.finisher;
  }
  if (player.role == PlayerRole.defender) {
    if (has(['shield', 'leader', 'aerial', 'anchor'])) {
      return PitchAffinity.anchor;
    }
    if (has([
      'ball-playing',
      'tempo',
      'playmaker',
      'creator',
      'engine',
      'box-to-box',
      'press breaker',
      'overlap',
      'attacking',
      'wide',
      'fullback',
    ])) {
      return PitchAffinity.reader;
    }
    return PitchAffinity.stopper;
  }
  return null;
}

final pitchPlayerAffinities = <String, PitchAffinity>{
  for (final player in [...attackers, ...defenders])
    player.id: _deriveAffinity(player)!,
};

PitchAffinity? pitchAffinityFor(PlayerCard player) =>
    pitchPlayerAffinities[player.id] ?? _deriveAffinity(player);

List<String> pitchMatchingActionNames(PitchAffinity affinity) => [
  for (final id in pitchAffinityActions[affinity]!)
    actionCards.firstWhere((action) => pitchActionBaseId(action) == id).title,
];

List<String> pitchScenarioActionNames(
  ScenarioCard scenario, {
  required bool attacking,
}) => [
  for (final action in actionCards)
    if (action.tier == CardTier.bronze &&
        pitchActionFitsRole(action, attacking) &&
        (pitchScenarioActions[scenario.id]?.contains(
              pitchActionBaseId(action),
            ) ??
            false))
      action.title,
];

String pitchPlayerAbility(PlayerCard player) {
  final affinity = pitchAffinityFor(player);
  if (affinity == null) return player.trait;
  return '${affinity.label}: +4 power with ${pitchMatchingActionNames(affinity).join(', ')}.';
}

bool pitchActionFitsRole(ActionCard action, bool attacking) =>
    action.category == ActionCategory.special ||
    action.category ==
        (attacking ? ActionCategory.attack : ActionCategory.defense);

List<bool> pitchRemainingRoles(int round, bool attacking) => [
  for (var r = round; r <= 4; r++) (r - round).isEven ? attacking : !attacking,
];

/// Tiny matching problem: a special card can cover either role, but only once.
bool pitchCanComplete(List<ActionCard> actions, List<bool> roles) {
  if (roles.isEmpty) return true;
  final unique = {
    for (final action in actions) action.id: action,
  }.values.toList();
  if (unique.length < roles.length) return false;
  for (final action in unique.where(
    (a) => pitchActionFitsRole(a, roles.first),
  )) {
    if (pitchCanComplete(
      unique.where((a) => a.id != action.id).toList(),
      roles.sublist(1),
    )) {
      return true;
    }
  }
  return false;
}

List<ActionCard> pitchLegalActions({
  required List<ActionCard> actions,
  required List<String> usedIds,
  required int round,
  required bool attacking,
}) {
  final available = actions.where((a) => !usedIds.contains(a.id)).toList();
  final future = pitchRemainingRoles(round, attacking).skip(1).toList();
  return available
      .where(
        (a) =>
            pitchActionFitsRole(a, attacking) &&
            pitchCanComplete(
              available.where((other) => other.id != a.id).toList(),
              future,
            ),
      )
      .toList();
}

class PowerBreakdown {
  const PowerBreakdown({
    required this.player,
    required this.action,
    required this.scenario,
    this.affinity = 0,
    this.scenarioCombo = 0,
    this.timing = 0,
  });
  final int player;
  final int action;
  final int scenario;
  final int affinity;
  final int scenarioCombo;
  final int timing;
  int get combo => affinity + scenarioCombo;
  int get base => player + action + scenario + combo;
  int get total => base + timing;
  Map<String, dynamic> toJson() => {
    'player': player,
    'action': action,
    'scenario': scenario,
    'affinity': affinity,
    'scenarioCombo': scenarioCombo,
    'timing': timing,
  };
  factory PowerBreakdown.fromJson(Map<String, dynamic> json) => PowerBreakdown(
    player: (json['player'] as num?)?.toInt() ?? 0,
    action: (json['action'] as num?)?.toInt() ?? 0,
    scenario: (json['scenario'] as num?)?.toInt() ?? 0,
    affinity: (json['affinity'] as num?)?.toInt() ?? 0,
    scenarioCombo: (json['scenarioCombo'] as num?)?.toInt() ?? 0,
    timing: (json['timing'] as num?)?.toInt() ?? 0,
  );
}

PowerBreakdown pitchPower({
  required PlayerCard player,
  required ActionCard action,
  required ScenarioCard scenario,
  required bool attacking,
  int timing = 0,
}) {
  final affinity = pitchAffinityFor(player);
  final actionId = pitchActionBaseId(action);
  return PowerBreakdown(
    player: player.rating,
    action: action.power,
    scenario: attacking ? scenario.attackBonus : scenario.defenseBonus,
    affinity:
        affinity != null && pitchAffinityActions[affinity]!.contains(actionId)
        ? pitchAffinityBonus
        : 0,
    scenarioCombo: pitchScenarioActions[scenario.id]?.contains(actionId) == true
        ? pitchScenarioComboBonus
        : 0,
    timing: timing.clamp(0, pitchTimingMax),
  );
}

enum ShotTimingQuality { perfect, great, good, early, late }

extension ShotTimingBonus on ShotTimingQuality {
  int get bonus => switch (this) {
    ShotTimingQuality.perfect => 8,
    ShotTimingQuality.great => 6,
    ShotTimingQuality.good => 4,
    ShotTimingQuality.early || ShotTimingQuality.late => 0,
  };
}

class ShotTimingResult {
  const ShotTimingResult({required this.quality, required this.position});
  final ShotTimingQuality quality;
  final double position;
  int get bonus => quality.bonus;
  String get label => quality.name.toUpperCase();
  static const center = 0.5;
  static const perfectHalfWidth = 0.045;
  static const greatHalfWidth = 0.10;
  static const goodHalfWidth = 0.25;
  static const accessible = ShotTimingResult(
    quality: ShotTimingQuality.good,
    position: center + 0.15,
  );
  factory ShotTimingResult.at(double position) {
    final p = position.clamp(0.0, 1.0);
    final distance = (p - center).abs();
    // Tolerance makes painted decimal boundaries match floating-point taps.
    final quality = distance <= perfectHalfWidth + 1e-9
        ? ShotTimingQuality.perfect
        : distance <= greatHalfWidth + 1e-9
        ? ShotTimingQuality.great
        : distance <= goodHalfWidth + 1e-9
        ? ShotTimingQuality.good
        : p < center
        ? ShotTimingQuality.early
        : ShotTimingQuality.late;
    return ShotTimingResult(quality: quality, position: p);
  }
}

class PitchPowerRange {
  const PitchPowerRange(this.min, this.max);
  final int min;
  final int max;
}

PitchPowerRange? pitchRivalRange({
  required List<PlayerCard> players,
  required List<ActionCard> actions,
  required List<String> usedPlayers,
  required List<String> usedActions,
  required ScenarioCard scenario,
  required int round,
  required bool attacking,
}) {
  final legal = pitchLegalActions(
    actions: actions,
    usedIds: usedActions,
    round: round,
    attacking: attacking,
  );
  final powers = [
    for (final player in players.where((p) => !usedPlayers.contains(p.id)))
      for (final action in legal)
        pitchPower(
          player: player,
          action: action,
          scenario: scenario,
          attacking: attacking,
        ).base,
  ];
  if (powers.isEmpty) return null;
  powers.sort();
  return PitchPowerRange(powers.first, powers.last + pitchTimingMax);
}

String pitchActionAbility(ActionCard action) {
  final id = pitchActionBaseId(action);
  final affinities = [
    for (final entry in pitchAffinityActions.entries)
      if (entry.value.contains(id)) entry.key.label,
  ];
  final matches = [
    for (final scenario in scenarios)
      if (pitchScenarioActions[scenario.id]?.contains(id) == true)
        scenario.title,
  ];
  return '+${action.power} power.${affinities.isEmpty ? '' : ' +4 with ${affinities.join(' or ')}.'}'
      '${matches.isEmpty ? '' : ' +6 in ${matches.join(', ')}.'}';
}
