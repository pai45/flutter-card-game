import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PitchDuelApp());
}

enum AppSection { home, deck, howToPlay, match }

enum CardTier { silver, gold, purple }

enum PlayerRole { attacker, defender }

enum ActionCategory { attack, defense, special }

enum MatchPhase {
  idle,
  toss,
  tossResult,
  scenario,
  play,
  roundResult,
  matchEnd,
  penalty,
  finalResult,
}

enum RoundOutcome { goal, saved, blocked, missed, foul, redCard }

class Cyber {
  static const bg = Color(0xff05070d);
  static const bg2 = Color(0xff0a0e1a);
  static const panel = Color(0xff0e1424);
  static const panel2 = Color(0xff131b2e);
  static const cyan = Color(0xff5cdfff);
  static const magenta = Color(0xffff3df7);
  static const lime = Color(0xffb6ff3d);
  static const amber = Color(0xffffb13d);
  static const red = Color(0xffff2e63);
  static const violet = Color(0xff8a5cff);
  static const line = Color(0x665cdfff);
  static const muted = Color(0xff8fa3b8);

  static LinearGradient panelGradient([Color? glow]) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [(glow ?? cyan).withValues(alpha: 0.16), panel, panel2],
    stops: const [0, 0.42, 1],
  );
}

class PlayerCard {
  const PlayerCard({
    required this.id,
    required this.name,
    required this.role,
    required this.rating,
    required this.trait,
    required this.tier,
    required this.icon,
  });

  final String id;
  final String name;
  final PlayerRole role;
  final int rating;
  final String trait;
  final CardTier tier;
  final IconData icon;
}

class ActionCard {
  const ActionCard({
    required this.id,
    required this.title,
    required this.category,
    required this.effect,
    required this.power,
    required this.risky,
    required this.icon,
  });

  final String id;
  final String title;
  final ActionCategory category;
  final String effect;
  final int power;
  final bool risky;
  final IconData icon;
}

class ScenarioCard {
  const ScenarioCard({
    required this.id,
    required this.title,
    required this.description,
    required this.attackBonus,
    required this.defenseBonus,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final int attackBonus;
  final int defenseBonus;
  final IconData icon;
}

class RoundResult {
  const RoundResult({
    required this.round,
    required this.scenario,
    required this.playerAttacking,
    required this.attackerCard,
    required this.defenderCard,
    required this.attackAction,
    required this.defenseAction,
    required this.outcome,
    required this.attackPower,
    required this.defensePower,
  });

  final int round;
  final ScenarioCard scenario;
  final bool playerAttacking;
  final PlayerCard attackerCard;
  final PlayerCard defenderCard;
  final ActionCard attackAction;
  final ActionCard defenseAction;
  final RoundOutcome outcome;
  final double attackPower;
  final double defensePower;
}

class PenaltyKick {
  const PenaltyKick({
    required this.byPlayer,
    required this.scored,
    required this.label,
  });

  final bool byPlayer;
  final bool scored;
  final String label;
}

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

const attackers = [
  PlayerCard(
    id: 'atk1',
    name: 'Marcus Blaze',
    role: PlayerRole.attacker,
    rating: 92,
    trait: 'Clinical Finisher',
    tier: CardTier.gold,
    icon: Icons.sports_soccer,
  ),
  PlayerCard(
    id: 'atk2',
    name: 'Leo Viper',
    role: PlayerRole.attacker,
    rating: 95,
    trait: 'Dribble King',
    tier: CardTier.purple,
    icon: Icons.bolt,
  ),
  PlayerCard(
    id: 'atk3',
    name: 'Kai Thunder',
    role: PlayerRole.attacker,
    rating: 88,
    trait: 'Speed Demon',
    tier: CardTier.silver,
    icon: Icons.speed,
  ),
  PlayerCard(
    id: 'atk4',
    name: 'Dante Fury',
    role: PlayerRole.attacker,
    rating: 90,
    trait: 'Aerial Threat',
    tier: CardTier.gold,
    icon: Icons.air,
  ),
  PlayerCard(
    id: 'atk5',
    name: 'Riku Storm',
    role: PlayerRole.attacker,
    rating: 86,
    trait: 'Long Range',
    tier: CardTier.silver,
    icon: Icons.radar,
  ),
  PlayerCard(
    id: 'atk6',
    name: 'Zane Phantom',
    role: PlayerRole.attacker,
    rating: 93,
    trait: 'Ghost Run',
    tier: CardTier.purple,
    icon: Icons.blur_on,
  ),
];

const defenders = [
  PlayerCard(
    id: 'def1',
    name: 'Iron Wall',
    role: PlayerRole.defender,
    rating: 91,
    trait: 'Unbreakable',
    tier: CardTier.gold,
    icon: Icons.shield,
  ),
  PlayerCard(
    id: 'def2',
    name: 'Shadow Lock',
    role: PlayerRole.defender,
    rating: 89,
    trait: 'Man Marker',
    tier: CardTier.silver,
    icon: Icons.lock,
  ),
  PlayerCard(
    id: 'def3',
    name: 'Granite',
    role: PlayerRole.defender,
    rating: 94,
    trait: 'Brick Wall',
    tier: CardTier.purple,
    icon: Icons.fort,
  ),
  PlayerCard(
    id: 'def4',
    name: 'Hawk Eye',
    role: PlayerRole.defender,
    rating: 87,
    trait: 'Interceptor',
    tier: CardTier.gold,
    icon: Icons.visibility,
  ),
  PlayerCard(
    id: 'def5',
    name: 'Steel Trap',
    role: PlayerRole.defender,
    rating: 85,
    trait: 'Slide Master',
    tier: CardTier.silver,
    icon: Icons.back_hand,
  ),
  PlayerCard(
    id: 'def6',
    name: 'Aegis',
    role: PlayerRole.defender,
    rating: 93,
    trait: 'Last Stand',
    tier: CardTier.purple,
    icon: Icons.security,
  ),
];

const actionCards = [
  ActionCard(
    id: 'act1',
    title: 'Through Ball',
    category: ActionCategory.attack,
    effect: '+15 Attack Power',
    power: 15,
    risky: false,
    icon: Icons.trending_up,
  ),
  ActionCard(
    id: 'act2',
    title: 'Power Shot',
    category: ActionCategory.attack,
    effect: '+20 Attack, -5 Accuracy',
    power: 20,
    risky: false,
    icon: Icons.sports_soccer,
  ),
  ActionCard(
    id: 'act3',
    title: 'Skill Move',
    category: ActionCategory.attack,
    effect: '+12 Attack, Bypass Trait',
    power: 12,
    risky: false,
    icon: Icons.auto_awesome,
  ),
  ActionCard(
    id: 'act4',
    title: 'Cut Inside',
    category: ActionCategory.attack,
    effect: '+10 Attack, +5 Scenario',
    power: 10,
    risky: false,
    icon: Icons.turn_right,
  ),
  ActionCard(
    id: 'act5',
    title: 'Long Shot',
    category: ActionCategory.attack,
    effect: '+25 Attack, High Risk',
    power: 25,
    risky: true,
    icon: Icons.my_location,
  ),
  ActionCard(
    id: 'act6',
    title: 'Quick Break',
    category: ActionCategory.attack,
    effect: '+18 Counter Bonus',
    power: 18,
    risky: false,
    icon: Icons.flash_on,
  ),
  ActionCard(
    id: 'act7',
    title: 'Slide Tackle',
    category: ActionCategory.defense,
    effect: '+15 Defense Power',
    power: 15,
    risky: false,
    icon: Icons.swipe_down,
  ),
  ActionCard(
    id: 'act8',
    title: 'Press High',
    category: ActionCategory.defense,
    effect: '+12 Defense, Disrupt',
    power: 12,
    risky: false,
    icon: Icons.compress,
  ),
  ActionCard(
    id: 'act9',
    title: 'Block Lane',
    category: ActionCategory.defense,
    effect: '+10 Defense, +5 Position',
    power: 10,
    risky: false,
    icon: Icons.block,
  ),
  ActionCard(
    id: 'act10',
    title: 'Tight Marking',
    category: ActionCategory.defense,
    effect: '+14 Defense Power',
    power: 14,
    risky: false,
    icon: Icons.person_pin_circle,
  ),
  ActionCard(
    id: 'act11',
    title: 'Intercept',
    category: ActionCategory.defense,
    effect: '+18 Defense, Read Play',
    power: 18,
    risky: false,
    icon: Icons.call_split,
  ),
  ActionCard(
    id: 'act12',
    title: 'Last-Ditch Tackle',
    category: ActionCategory.defense,
    effect: '+22 Defense, Foul Risk',
    power: 22,
    risky: true,
    icon: Icons.warning,
  ),
  ActionCard(
    id: 'act13',
    title: 'All In',
    category: ActionCategory.special,
    effect: '+30 Power, Red Card Risk',
    power: 30,
    risky: true,
    icon: Icons.local_fire_department,
  ),
  ActionCard(
    id: 'act14',
    title: 'Tactical Foul',
    category: ActionCategory.special,
    effect: 'Stop Play, Yellow Risk',
    power: 8,
    risky: true,
    icon: Icons.flag,
  ),
  ActionCard(
    id: 'act15',
    title: 'Mind Game',
    category: ActionCategory.special,
    effect: '-10 Opponent Power',
    power: 10,
    risky: false,
    icon: Icons.psychology,
  ),
  ActionCard(
    id: 'act16',
    title: 'Fast Recovery',
    category: ActionCategory.special,
    effect: '+8 All Stats',
    power: 8,
    risky: false,
    icon: Icons.healing,
  ),
];

const scenarios = [
  ScenarioCard(
    id: 'sc1',
    title: 'Counter Attack',
    description: 'Quick transition, spaces open up',
    attackBonus: 8,
    defenseBonus: 3,
    icon: Icons.run_circle,
  ),
  ScenarioCard(
    id: 'sc2',
    title: '1v1 Final Third',
    description: 'Face to face with the last defender',
    attackBonus: 5,
    defenseBonus: 5,
    icon: Icons.adjust,
  ),
  ScenarioCard(
    id: 'sc3',
    title: 'Set Piece Chance',
    description: 'Free kick from a dangerous position',
    attackBonus: 6,
    defenseBonus: 6,
    icon: Icons.sports,
  ),
  ScenarioCard(
    id: 'sc4',
    title: 'Last Minute Pressure',
    description: 'Everything on the line, final push',
    attackBonus: 10,
    defenseBonus: 2,
    icon: Icons.timer,
  ),
  ScenarioCard(
    id: 'sc5',
    title: 'Box Defense',
    description: 'Packed defense, tight spaces',
    attackBonus: 2,
    defenseBonus: 10,
    icon: Icons.grid_view,
  ),
  ScenarioCard(
    id: 'sc6',
    title: 'Wide Break',
    description: 'Overlapping run down the flank',
    attackBonus: 7,
    defenseBonus: 4,
    icon: Icons.open_in_full,
  ),
  ScenarioCard(
    id: 'sc7',
    title: 'Penalty Box Chaos',
    description: 'Scramble in the box, anything goes',
    attackBonus: 8,
    defenseBonus: 8,
    icon: Icons.shuffle,
  ),
];

class SecureGameStorage {
  SecureGameStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _deckKey = 'pd_deck_slots_v1';
  static const _tutorialKey = 'pd_tutorial_seen_v1';
  static const _ownedCardsKey = 'pd_owned_cards_v1';

  final FlutterSecureStorage _storage;

  Future<List<StoredDeckSlot>> loadDecks() async {
    try {
      final raw = await _storage.read(key: _deckKey);
      if (raw == null || raw.isEmpty) return defaultDeckSlots;
      final data = jsonDecode(raw) as List;
      return data.map((item) => StoredDeckSlot.fromJson(item)).toList();
    } catch (_) {
      return defaultDeckSlots;
    }
  }

  Future<void> saveDecks(List<StoredDeckSlot> decks) async {
    await _storage.write(
      key: _deckKey,
      value: jsonEncode(decks.map((deck) => deck.toJson()).toList()),
    );
  }

  Future<Set<String>> loadTutorialSeen() async {
    try {
      final raw = await _storage.read(key: _tutorialKey);
      if (raw == null || raw.isEmpty) return {};
      return Set<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return {};
    }
  }

  Future<void> saveTutorialSeen(Set<String> seen) async {
    await _storage.write(key: _tutorialKey, value: jsonEncode(seen.toList()));
  }

  Future<void> resetTutorial() => _storage.delete(key: _tutorialKey);

  Future<List<String>> loadOwnedCards() async {
    try {
      final raw = await _storage.read(key: _ownedCardsKey);
      if (raw == null || raw.isEmpty) return const [];
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveOwnedCards(List<String> cardIds) async {
    await _storage.write(key: _ownedCardsKey, value: jsonEncode(cardIds));
  }
}

const defaultDeckSlots = [
  StoredDeckSlot(
    id: 'slot-1',
    name: 'All Star',
    attackers: ['atk1', 'atk2'],
    defenders: ['def1', 'def2'],
    actions: ['act1', 'act2', 'act6', 'act7', 'act8', 'act15'],
  ),
];

const tutorialKeys = [
  'home',
  'deck-builder',
  'toss',
  'scenario',
  'play',
  'round-result',
  'match-end',
  'penalty',
  'final',
];

class TutorialStepData {
  const TutorialStepData({required this.title, required this.body});

  final String title;
  final String body;
}

const homeTutorialSteps = [
  TutorialStepData(
    title: 'Welcome, Operator',
    body:
        'PITCH/DUEL is a 4-round card duel. Each round, play one player card and one action card. Stats, scenario, and luck decide the outcome.',
  ),
  TutorialStepData(
    title: "You're pre-loaded",
    body:
        'Your default loadout is ready: 2 attackers, 2 defenders, 6 actions. Play now or customize in Deck Builder.',
  ),
  TutorialStepData(
    title: 'How a match flows',
    body:
        '1. Coin toss (round 1 only)\n2. Scenario reveals + role assigned\n3. Pick a player & action card\n4. See the outcome -> next round\n\nTap PLAY MATCH when ready.',
  ),
];

const deckTutorialSteps = [
  TutorialStepData(
    title: 'Build a 5-a-side',
    body: 'Shape the pitch with 2 ATK, 2 DEF, and 6 actions.',
  ),
  TutorialStepData(
    title: 'Edit, Save, Play',
    body:
        'Tap Edit to change the deck, save it, then play when the squad is ready.',
  ),
];

const tossTutorialSteps = [
  TutorialStepData(
    title: 'Coin Toss',
    body:
        'Pick HEADS or TAILS. The winner chooses attack or defense for round 1.',
  ),
  TutorialStepData(
    title: 'Roles Alternate',
    body:
        'This is the only toss. After round 1, roles flip automatically each round.',
  ),
];

const scenarioTutorialSteps = [
  TutorialStepData(
    title: 'Scenario Briefing',
    body:
        'Each round has a football situation: counter attack, set piece, box defense, and more.',
  ),
  TutorialStepData(
    title: 'Bonus Stats',
    body:
        'ATK +X and DEF +X are added this round. Bigger attack bonus favors the attacker.',
  ),
  TutorialStepData(
    title: 'Your Role',
    body: 'The banner shows your role. Pick cards around attack or defense.',
  ),
];

const playTutorialSteps = [
  TutorialStepData(
    title: 'Pick Your Player',
    body:
        'Choose one player. OVR is base power. Used players are locked for the match.',
  ),
  TutorialStepData(
    title: 'Pick an Action',
    body:
        'Pick one action. Options match your role: ATK when attacking, DEF when defending, SPC anytime.',
  ),
  TutorialStepData(
    title: 'Risky Cards',
    body:
        'Warning cards boost power but can cause fouls or red cards. Red cards remove a player.',
  ),
  TutorialStepData(
    title: 'Read the Preview',
    body:
        'EST shows rating + action + scenario bonus. CPU power is hidden, and luck still matters.',
  ),
];

const resultTutorialSteps = [
  TutorialStepData(
    title: 'Round Resolved',
    body: 'The label shows: GOAL, SAVED, MISSED, FOUL, or RED CARD.',
  ),
  TutorialStepData(
    title: 'Used Cards',
    body:
        'Round cards appear side-by-side. Used players are marked USED and cannot replay.',
  ),
  TutorialStepData(
    title: 'Next Round',
    body: 'Tap NEXT ROUND. Roles switch each round, so attack becomes defense.',
  ),
];

const matchEndTutorialSteps = [
  TutorialStepData(
    title: 'Full Time',
    body: 'After 4 rounds, the banner shows VICTORY, DEFEAT, or DEADLOCK.',
  ),
  TutorialStepData(
    title: 'Round Log',
    body: 'The log recaps each scenario and outcome.',
  ),
  TutorialStepData(
    title: 'Tied? Penalties!',
    body: 'A draw goes to a penalty shootout.',
  ),
];

const penaltyTutorialSteps = [
  TutorialStepData(
    title: 'Sudden Death',
    body:
        'Tied match: penalty shootout. Kicks alternate until someone leads after equal attempts.',
  ),
  TutorialStepData(
    title: 'How It Works',
    body:
        'Tap TAKE KICK on your turn. CPU kicks auto-fire. Each kick has about a 65-75% score chance.',
  ),
];

const finalTutorialSteps = [
  TutorialStepData(
    title: 'Match Archive',
    body: 'Final scoreline, plus penalties if needed, appears here.',
  ),
  TutorialStepData(title: 'MVP', body: 'MVP goes to your goal scorer.'),
  TutorialStepData(
    title: 'What Next?',
    body: 'REMATCH uses the same deck. HOME exits. DECK opens squad tuning.',
  ),
];

class GameState {
  const GameState({
    required this.loading,
    required this.deckSlots,
    required this.activeDeckId,
    required this.deckAttackers,
    required this.deckDefenders,
    required this.deckActions,
    required this.ownedCardIds,
    required this.tutorialSeen,
    required this.phase,
    required this.currentRound,
    required this.playerScore,
    required this.opponentScore,
    required this.playerAttacking,
    required this.tossChoice,
    required this.tossResult,
    required this.playerWonToss,
    required this.initialAttackingChoice,
    required this.currentScenario,
    required this.selectedPlayerCard,
    required this.selectedActionCard,
    required this.usedPlayerCards,
    required this.usedActionCards,
    required this.redCardedCards,
    required this.roundResults,
    required this.opponentAttackers,
    required this.opponentDefenders,
    required this.opponentActions,
    required this.opponentRedCarded,
    required this.penaltyKicks,
    required this.penaltyPlayerScore,
    required this.penaltyOpponentScore,
    required this.penaltyRound,
    required this.penaltyPhaseOver,
  });

  factory GameState.initial() => GameState(
    loading: true,
    deckSlots: defaultDeckSlots,
    activeDeckId: defaultDeckSlots.first.id,
    deckAttackers: cardsByIds(attackers, defaultDeckSlots.first.attackers),
    deckDefenders: cardsByIds(defenders, defaultDeckSlots.first.defenders),
    deckActions: actionCardsByIds(defaultDeckSlots.first.actions),
    ownedCardIds: const [],
    tutorialSeen: const {},
    phase: MatchPhase.idle,
    currentRound: 0,
    playerScore: 0,
    opponentScore: 0,
    playerAttacking: true,
    tossChoice: null,
    tossResult: null,
    playerWonToss: null,
    initialAttackingChoice: null,
    currentScenario: null,
    selectedPlayerCard: null,
    selectedActionCard: null,
    usedPlayerCards: const [],
    usedActionCards: const [],
    redCardedCards: const [],
    roundResults: const [],
    opponentAttackers: const [],
    opponentDefenders: const [],
    opponentActions: const [],
    opponentRedCarded: const [],
    penaltyKicks: const [],
    penaltyPlayerScore: 0,
    penaltyOpponentScore: 0,
    penaltyRound: 0,
    penaltyPhaseOver: false,
  );

  final bool loading;
  final List<StoredDeckSlot> deckSlots;
  final String activeDeckId;
  final List<PlayerCard> deckAttackers;
  final List<PlayerCard> deckDefenders;
  final List<ActionCard> deckActions;
  final List<String> ownedCardIds;
  final Set<String> tutorialSeen;
  final MatchPhase phase;
  final int currentRound;
  final int playerScore;
  final int opponentScore;
  final bool playerAttacking;
  final String? tossChoice;
  final String? tossResult;
  final bool? playerWonToss;
  final bool? initialAttackingChoice;
  final ScenarioCard? currentScenario;
  final PlayerCard? selectedPlayerCard;
  final ActionCard? selectedActionCard;
  final List<String> usedPlayerCards;
  final List<String> usedActionCards;
  final List<String> redCardedCards;
  final List<RoundResult> roundResults;
  final List<PlayerCard> opponentAttackers;
  final List<PlayerCard> opponentDefenders;
  final List<ActionCard> opponentActions;
  final List<String> opponentRedCarded;
  final List<PenaltyKick> penaltyKicks;
  final int penaltyPlayerScore;
  final int penaltyOpponentScore;
  final int penaltyRound;
  final bool penaltyPhaseOver;

  bool get deckReady =>
      deckAttackers.length == 2 &&
      deckDefenders.length == 2 &&
      deckActions.length == 6;

  GameState copyWith({
    bool? loading,
    List<StoredDeckSlot>? deckSlots,
    String? activeDeckId,
    List<PlayerCard>? deckAttackers,
    List<PlayerCard>? deckDefenders,
    List<ActionCard>? deckActions,
    List<String>? ownedCardIds,
    Set<String>? tutorialSeen,
    MatchPhase? phase,
    int? currentRound,
    int? playerScore,
    int? opponentScore,
    bool? playerAttacking,
    Object? tossChoice = _sentinel,
    Object? tossResult = _sentinel,
    Object? playerWonToss = _sentinel,
    Object? initialAttackingChoice = _sentinel,
    Object? currentScenario = _sentinel,
    Object? selectedPlayerCard = _sentinel,
    Object? selectedActionCard = _sentinel,
    List<String>? usedPlayerCards,
    List<String>? usedActionCards,
    List<String>? redCardedCards,
    List<RoundResult>? roundResults,
    List<PlayerCard>? opponentAttackers,
    List<PlayerCard>? opponentDefenders,
    List<ActionCard>? opponentActions,
    List<String>? opponentRedCarded,
    List<PenaltyKick>? penaltyKicks,
    int? penaltyPlayerScore,
    int? penaltyOpponentScore,
    int? penaltyRound,
    bool? penaltyPhaseOver,
  }) => GameState(
    loading: loading ?? this.loading,
    deckSlots: deckSlots ?? this.deckSlots,
    activeDeckId: activeDeckId ?? this.activeDeckId,
    deckAttackers: deckAttackers ?? this.deckAttackers,
    deckDefenders: deckDefenders ?? this.deckDefenders,
    deckActions: deckActions ?? this.deckActions,
    ownedCardIds: ownedCardIds ?? this.ownedCardIds,
    tutorialSeen: tutorialSeen ?? this.tutorialSeen,
    phase: phase ?? this.phase,
    currentRound: currentRound ?? this.currentRound,
    playerScore: playerScore ?? this.playerScore,
    opponentScore: opponentScore ?? this.opponentScore,
    playerAttacking: playerAttacking ?? this.playerAttacking,
    tossChoice: tossChoice == _sentinel
        ? this.tossChoice
        : tossChoice as String?,
    tossResult: tossResult == _sentinel
        ? this.tossResult
        : tossResult as String?,
    playerWonToss: playerWonToss == _sentinel
        ? this.playerWonToss
        : playerWonToss as bool?,
    initialAttackingChoice: initialAttackingChoice == _sentinel
        ? this.initialAttackingChoice
        : initialAttackingChoice as bool?,
    currentScenario: currentScenario == _sentinel
        ? this.currentScenario
        : currentScenario as ScenarioCard?,
    selectedPlayerCard: selectedPlayerCard == _sentinel
        ? this.selectedPlayerCard
        : selectedPlayerCard as PlayerCard?,
    selectedActionCard: selectedActionCard == _sentinel
        ? this.selectedActionCard
        : selectedActionCard as ActionCard?,
    usedPlayerCards: usedPlayerCards ?? this.usedPlayerCards,
    usedActionCards: usedActionCards ?? this.usedActionCards,
    redCardedCards: redCardedCards ?? this.redCardedCards,
    roundResults: roundResults ?? this.roundResults,
    opponentAttackers: opponentAttackers ?? this.opponentAttackers,
    opponentDefenders: opponentDefenders ?? this.opponentDefenders,
    opponentActions: opponentActions ?? this.opponentActions,
    opponentRedCarded: opponentRedCarded ?? this.opponentRedCarded,
    penaltyKicks: penaltyKicks ?? this.penaltyKicks,
    penaltyPlayerScore: penaltyPlayerScore ?? this.penaltyPlayerScore,
    penaltyOpponentScore: penaltyOpponentScore ?? this.penaltyOpponentScore,
    penaltyRound: penaltyRound ?? this.penaltyRound,
    penaltyPhaseOver: penaltyPhaseOver ?? this.penaltyPhaseOver,
  );
}

const _sentinel = Object();

sealed class GameEvent {}

class GameLoaded extends GameEvent {}

class DeckSaved extends GameEvent {
  DeckSaved(this.slot);
  final StoredDeckSlot slot;
}

class DeckApplied extends GameEvent {
  DeckApplied(this.slotId);
  final String slotId;
}

class DeckCreated extends GameEvent {}

class TutorialReset extends GameEvent {}

class TutorialSeenMarked extends GameEvent {
  TutorialSeenMarked(this.keyName);
  final String keyName;
}

class TutorialsSkippedAll extends GameEvent {}

class OwnedCardAdded extends GameEvent {
  OwnedCardAdded(this.cardId);
  final String cardId;
}

class MatchReset extends GameEvent {}

class MatchStarted extends GameEvent {}

class TossChoiceChanged extends GameEvent {
  TossChoiceChanged(this.choice);
  final String choice;
}

class TossResolved extends GameEvent {}

class RoleChosen extends GameEvent {
  RoleChosen(this.playerAttacking);
  final bool playerAttacking;
}

class ScenarioShown extends GameEvent {}

class PlayStarted extends GameEvent {}

class PlayerSelected extends GameEvent {
  PlayerSelected(this.card);
  final PlayerCard card;
}

class ActionSelected extends GameEvent {
  ActionSelected(this.card);
  final ActionCard card;
}

class MovePlayed extends GameEvent {}

class RoundAdvanced extends GameEvent {}

class PenaltyStarted extends GameEvent {}

class PenaltyTaken extends GameEvent {}

class MatchFinished extends GameEvent {}

class GameBloc extends Bloc<GameEvent, GameState> {
  GameBloc(this._storage) : super(GameState.initial()) {
    on<GameLoaded>(_onLoaded);
    on<DeckSaved>(_onDeckSaved);
    on<DeckApplied>(_onDeckApplied);
    on<DeckCreated>(_onDeckCreated);
    on<TutorialReset>(_onTutorialReset);
    on<TutorialSeenMarked>(_onTutorialSeenMarked);
    on<TutorialsSkippedAll>(_onTutorialsSkippedAll);
    on<OwnedCardAdded>(_onOwnedCardAdded);
    on<MatchReset>((_, emit) => emit(_resetMatch(state)));
    on<MatchStarted>(_onMatchStarted);
    on<TossChoiceChanged>(
      (event, emit) => emit(state.copyWith(tossChoice: event.choice)),
    );
    on<TossResolved>(_onTossResolved);
    on<RoleChosen>(_onRoleChosen);
    on<ScenarioShown>(_onScenarioShown);
    on<PlayStarted>((_, emit) => emit(state.copyWith(phase: MatchPhase.play)));
    on<PlayerSelected>(
      (event, emit) => emit(state.copyWith(selectedPlayerCard: event.card)),
    );
    on<ActionSelected>(
      (event, emit) => emit(state.copyWith(selectedActionCard: event.card)),
    );
    on<MovePlayed>(_onMovePlayed);
    on<RoundAdvanced>(_onRoundAdvanced);
    on<PenaltyStarted>(
      (_, emit) => emit(
        state.copyWith(
          phase: MatchPhase.penalty,
          penaltyKicks: [],
          penaltyPlayerScore: 0,
          penaltyOpponentScore: 0,
          penaltyRound: 0,
          penaltyPhaseOver: false,
        ),
      ),
    );
    on<PenaltyTaken>(_onPenaltyTaken);
    on<MatchFinished>(
      (_, emit) => emit(state.copyWith(phase: MatchPhase.finalResult)),
    );
  }

  final SecureGameStorage _storage;
  final Random _random = Random();

  Future<void> _onLoaded(GameLoaded event, Emitter<GameState> emit) async {
    emit(state.copyWith(loading: false));

    final slots = await _storage.loadDecks().timeout(
      const Duration(seconds: 2),
      onTimeout: () => defaultDeckSlots,
    );
    final safeSlots = slots.isEmpty
        ? defaultDeckSlots
        : slots.map(_hydratedSlot).toList();
    final active = safeSlots.first;
    final seen = await _storage.loadTutorialSeen().timeout(
      const Duration(seconds: 2),
      onTimeout: () => <String>{},
    );
    final owned = await _storage.loadOwnedCards().timeout(
      const Duration(seconds: 2),
      onTimeout: () => <String>[],
    );
    emit(
      state.copyWith(
        loading: false,
        deckSlots: safeSlots,
        activeDeckId: active.id,
        deckAttackers: cardsByIds(attackers, active.attackers),
        deckDefenders: cardsByIds(defenders, active.defenders),
        deckActions: actionCardsByIds(active.actions),
        ownedCardIds: owned,
        tutorialSeen: seen,
      ),
    );
  }

  Future<void> _onOwnedCardAdded(
    OwnedCardAdded event,
    Emitter<GameState> emit,
  ) async {
    final owned = [...state.ownedCardIds, event.cardId];
    emit(state.copyWith(ownedCardIds: owned));
    await _storage.saveOwnedCards(owned);
  }

  Future<void> _onDeckSaved(DeckSaved event, Emitter<GameState> emit) async {
    final cleaned = _hydratedSlot(event.slot);
    final slots = [
      for (final slot in state.deckSlots)
        if (slot.id == cleaned.id) cleaned else slot,
    ];
    await _storage.saveDecks(slots);
    emit(
      state.copyWith(
        deckSlots: slots,
        activeDeckId: cleaned.id,
        deckAttackers: cardsByIds(attackers, cleaned.attackers),
        deckDefenders: cardsByIds(defenders, cleaned.defenders),
        deckActions: actionCardsByIds(cleaned.actions),
      ),
    );
  }

  void _onDeckApplied(DeckApplied event, Emitter<GameState> emit) {
    final slot = state.deckSlots.firstWhere(
      (deck) => deck.id == event.slotId,
      orElse: () => state.deckSlots.first,
    );
    emit(
      state.copyWith(
        activeDeckId: slot.id,
        deckAttackers: cardsByIds(attackers, slot.attackers),
        deckDefenders: cardsByIds(defenders, slot.defenders),
        deckActions: actionCardsByIds(slot.actions),
      ),
    );
  }

  Future<void> _onDeckCreated(
    DeckCreated event,
    Emitter<GameState> emit,
  ) async {
    final slot = StoredDeckSlot(
      id: 'slot-${DateTime.now().microsecondsSinceEpoch}',
      name: 'Squad ${state.deckSlots.length + 1}',
      attackers: const [],
      defenders: const [],
      actions: const [],
    );
    final slots = [...state.deckSlots, slot];
    await _storage.saveDecks(slots);
    emit(
      state.copyWith(
        deckSlots: slots,
        activeDeckId: slot.id,
        deckAttackers: const [],
        deckDefenders: const [],
        deckActions: const [],
      ),
    );
  }

  Future<void> _onTutorialReset(
    TutorialReset event,
    Emitter<GameState> emit,
  ) async {
    await _storage.resetTutorial();
    emit(state.copyWith(tutorialSeen: {}));
  }

  Future<void> _onTutorialSeenMarked(
    TutorialSeenMarked event,
    Emitter<GameState> emit,
  ) async {
    final seen = {...state.tutorialSeen, event.keyName};
    emit(state.copyWith(tutorialSeen: seen));
    await _storage.saveTutorialSeen(seen);
  }

  Future<void> _onTutorialsSkippedAll(
    TutorialsSkippedAll event,
    Emitter<GameState> emit,
  ) async {
    final seen = tutorialKeys.toSet();
    emit(state.copyWith(tutorialSeen: seen));
    await _storage.saveTutorialSeen(seen);
  }

  void _onMatchStarted(MatchStarted event, Emitter<GameState> emit) {
    final oppAttackers = [...attackers]..shuffle(_random);
    final oppDefenders = [...defenders]..shuffle(_random);
    final oppActions = [...actionCards]..shuffle(_random);
    emit(
      _resetMatch(state).copyWith(
        phase: MatchPhase.toss,
        currentRound: 1,
        opponentAttackers: oppAttackers.take(2).toList(),
        opponentDefenders: oppDefenders.take(2).toList(),
        opponentActions: oppActions.take(6).toList(),
      ),
    );
  }

  void _onTossResolved(TossResolved event, Emitter<GameState> emit) {
    if (state.tossChoice == null) return;
    final result = _random.nextBool() ? 'heads' : 'tails';
    emit(
      state.copyWith(
        tossResult: result,
        playerWonToss: result == state.tossChoice,
        phase: MatchPhase.tossResult,
      ),
    );
  }

  void _onRoleChosen(RoleChosen event, Emitter<GameState> emit) {
    emit(
      state.copyWith(
        playerAttacking: event.playerAttacking,
        initialAttackingChoice: event.playerAttacking,
        phase: MatchPhase.scenario,
        currentScenario: null,
      ),
    );
  }

  void _onScenarioShown(ScenarioShown event, Emitter<GameState> emit) {
    final used = state.roundResults.map((round) => round.scenario.id).toSet();
    final available = scenarios
        .where((scenario) => !used.contains(scenario.id))
        .toList();
    final pool = available.isEmpty ? scenarios : available;
    emit(
      state.copyWith(
        currentScenario: pool[_random.nextInt(pool.length)],
        phase: MatchPhase.scenario,
      ),
    );
  }

  void _onMovePlayed(MovePlayed event, Emitter<GameState> emit) {
    final playerCard = state.selectedPlayerCard;
    final actionCard = state.selectedActionCard;
    final scenario = state.currentScenario;
    if (playerCard == null || actionCard == null || scenario == null) return;

    final oppPlayers = state.playerAttacking
        ? state.opponentDefenders
              .where((card) => !state.opponentRedCarded.contains(card.id))
              .toList()
        : state.opponentAttackers
              .where((card) => !state.opponentRedCarded.contains(card.id))
              .toList();
    final fallback = state.playerAttacking
        ? state.opponentDefenders.first
        : state.opponentAttackers.first;
    final oppPlayer = oppPlayers.isEmpty
        ? fallback
        : oppPlayers[_random.nextInt(oppPlayers.length)];
    final oppAction =
        state.opponentActions[_random.nextInt(state.opponentActions.length)];

    final attackerCard = state.playerAttacking ? playerCard : oppPlayer;
    final defenderCard = state.playerAttacking ? oppPlayer : playerCard;
    final attackAction = state.playerAttacking ? actionCard : oppAction;
    final defenseAction = state.playerAttacking ? oppAction : actionCard;
    final attackPower =
        attackerCard.rating +
        attackAction.power +
        scenario.attackBonus +
        _random.nextDouble() * 20;
    final defensePower =
        defenderCard.rating +
        defenseAction.power +
        scenario.defenseBonus +
        _random.nextDouble() * 20;
    final outcome = _resolveRound(
      attackPower,
      defensePower,
      attackAction,
      defenseAction,
    );

    final opponentRedCarded = [...state.opponentRedCarded];
    final redCarded = [...state.redCardedCards];
    if (outcome == RoundOutcome.redCard) {
      if (state.playerAttacking) {
        opponentRedCarded.add(defenderCard.id);
      } else {
        redCarded.add(defenderCard.id);
      }
    }

    final playerGoal = outcome == RoundOutcome.goal && state.playerAttacking;
    final opponentGoal = outcome == RoundOutcome.goal && !state.playerAttacking;
    final result = RoundResult(
      round: state.currentRound,
      scenario: scenario,
      playerAttacking: state.playerAttacking,
      attackerCard: attackerCard,
      defenderCard: defenderCard,
      attackAction: attackAction,
      defenseAction: defenseAction,
      outcome: outcome,
      attackPower: attackPower,
      defensePower: defensePower,
    );

    emit(
      state.copyWith(
        phase: MatchPhase.roundResult,
        playerScore: state.playerScore + (playerGoal ? 1 : 0),
        opponentScore: state.opponentScore + (opponentGoal ? 1 : 0),
        usedPlayerCards: [...state.usedPlayerCards, playerCard.id],
        usedActionCards: [...state.usedActionCards, actionCard.id],
        redCardedCards: redCarded,
        opponentRedCarded: opponentRedCarded,
        roundResults: [...state.roundResults, result],
      ),
    );
  }

  void _onRoundAdvanced(RoundAdvanced event, Emitter<GameState> emit) {
    if (state.currentRound >= 4) {
      emit(state.copyWith(phase: MatchPhase.matchEnd));
      return;
    }
    final nextRound = state.currentRound + 1;
    final initialAttack = state.initialAttackingChoice ?? state.playerAttacking;
    emit(
      state.copyWith(
        currentRound: nextRound,
        phase: MatchPhase.scenario,
        currentScenario: null,
        selectedPlayerCard: null,
        selectedActionCard: null,
        playerAttacking: nextRound.isOdd ? initialAttack : !initialAttack,
      ),
    );
  }

  void _onPenaltyTaken(PenaltyTaken event, Emitter<GameState> emit) {
    if (state.penaltyPhaseOver) return;
    final byPlayer = state.penaltyRound.isEven;
    final chance = 0.65 + _random.nextDouble() * 0.1;
    final scored = _random.nextDouble() < chance;
    final kick = PenaltyKick(
      byPlayer: byPlayer,
      scored: scored,
      label: scored ? 'Goal' : (_random.nextBool() ? 'Saved' : 'Missed'),
    );
    final kicks = [...state.penaltyKicks, kick];
    final playerScore = state.penaltyPlayerScore + (byPlayer && scored ? 1 : 0);
    final opponentScore =
        state.penaltyOpponentScore + (!byPlayer && scored ? 1 : 0);
    final nextRound = state.penaltyRound + 1;
    var over = false;
    if (kicks.length >= 6 &&
        kicks.length.isEven &&
        playerScore != opponentScore) {
      over = true;
    }
    emit(
      state.copyWith(
        penaltyKicks: kicks,
        penaltyPlayerScore: playerScore,
        penaltyOpponentScore: opponentScore,
        penaltyRound: nextRound,
        penaltyPhaseOver: over,
      ),
    );
  }

  RoundOutcome _resolveRound(
    double attackPower,
    double defensePower,
    ActionCard attackAction,
    ActionCard defenseAction,
  ) {
    if (defenseAction.risky && _random.nextDouble() < 0.12) {
      return RoundOutcome.redCard;
    }
    if (attackAction.risky && _random.nextDouble() < 0.12) {
      return RoundOutcome.foul;
    }
    final diff = attackPower - defensePower;
    final roll = _random.nextDouble();
    if (diff > 15) {
      if (roll < 0.75) return RoundOutcome.goal;
      if (roll < 0.95) return RoundOutcome.saved;
      return RoundOutcome.blocked;
    }
    if (diff > 5) {
      if (roll < 0.60) return RoundOutcome.goal;
      if (roll < 0.90) return RoundOutcome.saved;
      return RoundOutcome.missed;
    }
    if (diff > -5) {
      if (roll < 0.45) return RoundOutcome.goal;
      if (roll < 0.80) return RoundOutcome.saved;
      return _random.nextBool() ? RoundOutcome.missed : RoundOutcome.blocked;
    }
    if (diff > -15) {
      if (roll < 0.65) return RoundOutcome.saved;
      if (roll < 0.90) return RoundOutcome.blocked;
      return RoundOutcome.goal;
    }
    if (roll < 0.75) return RoundOutcome.saved;
    if (roll < 0.95) return RoundOutcome.blocked;
    return RoundOutcome.goal;
  }

  GameState _resetMatch(GameState old) => GameState.initial().copyWith(
    loading: false,
    deckSlots: old.deckSlots,
    activeDeckId: old.activeDeckId,
    deckAttackers: old.deckAttackers,
    deckDefenders: old.deckDefenders,
    deckActions: old.deckActions,
    ownedCardIds: old.ownedCardIds,
    tutorialSeen: old.tutorialSeen,
  );

  StoredDeckSlot _hydratedSlot(StoredDeckSlot slot) => StoredDeckSlot(
    id: slot.id,
    name: slot.name,
    attackers: slot.attackers
        .where((id) => attackers.any((card) => card.id == id))
        .toList(),
    defenders: slot.defenders
        .where((id) => defenders.any((card) => card.id == id))
        .toList(),
    actions: slot.actions
        .where((id) => actionCards.any((card) => card.id == id))
        .toList(),
  );
}

List<PlayerCard> cardsByIds(List<PlayerCard> source, List<String> ids) => ids
    .map((id) => source.where((card) => card.id == id).firstOrNull)
    .whereType<PlayerCard>()
    .toList();

List<ActionCard> actionCardsByIds(List<String> ids) => ids
    .map((id) => actionCards.where((card) => card.id == id).firstOrNull)
    .whereType<ActionCard>()
    .toList();

class PitchDuelApp extends StatelessWidget {
  const PitchDuelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GameBloc(SecureGameStorage())..add(GameLoaded()),
      child: MaterialApp(
        title: 'Pitch Duel',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Cyber.cyan,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: Cyber.bg,
          fontFamily: 'Onest',
          textTheme: ThemeData.dark().textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
            fontFamily: 'Onest',
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xff070b14),
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
          ),
          cardTheme: CardThemeData(
            color: Cyber.panel,
            elevation: 0,
            shape: BeveledRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              side: BorderSide(color: Cyber.line),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              foregroundColor: Cyber.bg,
              backgroundColor: Cyber.cyan,
              minimumSize: const Size.fromHeight(48),
              textStyle: const TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
              shape: const BeveledRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: Cyber.cyan,
              side: const BorderSide(color: Cyber.line),
              minimumSize: const Size.fromHeight(46),
              textStyle: const TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
              shape: const BeveledRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          ),
          chipTheme: const ChipThemeData(
            backgroundColor: Cyber.panel2,
            selectedColor: Cyber.cyan,
            side: BorderSide(color: Cyber.line),
            labelStyle: TextStyle(
              color: Colors.white,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
        home: const AppShell(),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppSection section = AppSection.home;

  void _go(AppSection next) => setState(() => section = next);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, state) {
        if (state.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return switch (section) {
          AppSection.home => HomeScreen(onNavigate: _go),
          AppSection.deck => DeckBuilderScreen(onNavigate: _go),
          AppSection.howToPlay => HowToPlayScreen(onNavigate: _go),
          AppSection.match => MatchScreen(onNavigate: _go),
        };
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, state) {
        return Scaffold(
          appBar: ReactHeaderBar(
            title: 'Pitch Duel',
            subtitle: '// Main Terminal',
            onBack: () => onNavigate(AppSection.home),
          ),
          body: CyberBackground(
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 116),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sports_soccer,
                            size: 58,
                            color: Cyber.cyan,
                            shadows: [
                              Shadow(
                                color: Cyber.cyan.withValues(alpha: 0.55),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          CyberChip(
                            label: state.deckReady
                                ? '● Deck Online'
                                : '◐ Default Loadout',
                            color: state.deckReady ? Cyber.lime : Cyber.amber,
                          ),
                          const SizedBox(height: 28),
                          CyberCtaButton(
                            label: 'Play Match',
                            primary: true,
                            onPressed: state.deckReady
                                ? () {
                                    context.read<GameBloc>().add(
                                      MatchStarted(),
                                    );
                                    onNavigate(AppSection.match);
                                  }
                                : null,
                          ),
                          const SizedBox(height: 12),
                          CyberCtaButton(
                            label: 'Deck Builder',
                            onPressed: () => onNavigate(AppSection.deck),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => onNavigate(AppSection.howToPlay),
                            child: const Text(
                              'HOW TO PLAY',
                              style: TextStyle(
                                color: Cyber.cyan,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          LoadoutStatusPanel(state: state),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              context.read<GameBloc>().add(TutorialReset());
                              showTutorialNow(
                                context,
                                keyName: 'home',
                                steps: homeTutorialSteps,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Tutorial reset')),
                              );
                            },
                            child: Text(
                              '↻ REPLAY WALKTHROUGH',
                              style: TextStyle(
                                color: Cyber.cyan.withValues(alpha: 0.55),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const SizedBox(width: 160, child: HudLine()),
                        ],
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: DailyDropButton(),
                ),
                const TutorialTip(keyName: 'home', steps: homeTutorialSteps),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DailyDropButton extends StatelessWidget {
  DailyDropButton({super.key});

  final Random _random = Random();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Cyber.bg.withValues(alpha: 0),
            Cyber.bg.withValues(alpha: 0.94),
            Cyber.bg,
          ],
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: GestureDetector(
          onTap: () {
            final pool = [...attackers, ...defenders];
            final card = pool[_random.nextInt(pool.length)];
            showDialog<void>(
              context: context,
              barrierColor: Colors.black.withValues(alpha: 0.78),
              builder: (_) => Dialog(
                backgroundColor: Colors.transparent,
                child: CyberPanel(
                  accent: Cyber.amber,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'CARD GENERATED',
                        style: TextStyle(
                          color: Cyber.cyan.withValues(alpha: 0.72),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      CyberPlayerCardTile(
                        card: card,
                        selected: true,
                        size: VisualCardSize.md,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        card.name.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Cyber.cyan,
                          fontFamily: 'Orbitron',
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CLOSE'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          child: ClipPath(
            clipper: CyberClipper(),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Cyber.amber, Color(0xffff7a2f), Cyber.magenta],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Cyber.amber.withValues(alpha: 0.32),
                    blurRadius: 22,
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.style, color: Color(0xff160a00)),
                  SizedBox(width: 14),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DAILY DROP',
                        style: TextStyle(
                          color: Color(0xaa160a00),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'OPEN YOUR DAILY CARD',
                        style: TextStyle(
                          color: Color(0xff160a00),
                          fontFamily: 'Orbitron',
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DeckBuilderScreen extends StatefulWidget {
  const DeckBuilderScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<DeckBuilderScreen> createState() => _DeckBuilderScreenState();
}

class _DeckBuilderScreenState extends State<DeckBuilderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late List<String> selectedAttackers;
  late List<String> selectedDefenders;
  late List<String> selectedActions;
  bool editing = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    final state = context.read<GameBloc>().state;
    selectedAttackers = state.deckAttackers.map((card) => card.id).toList();
    selectedDefenders = state.deckDefenders.map((card) => card.id).toList();
    selectedActions = state.deckActions.map((card) => card.id).toList();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool get valid =>
      selectedAttackers.length == 2 &&
      selectedDefenders.length == 2 &&
      selectedActions.length == 6;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameState>(
      listener: (_, state) {
        selectedAttackers = state.deckAttackers.map((card) => card.id).toList();
        selectedDefenders = state.deckDefenders.map((card) => card.id).toList();
        selectedActions = state.deckActions.map((card) => card.id).toList();
      },
      builder: (context, state) {
        final active = state.deckSlots.firstWhere(
          (slot) => slot.id == state.activeDeckId,
        );
        final selectedAttackerCards = cardsByIds(attackers, selectedAttackers);
        final selectedDefenderCards = cardsByIds(defenders, selectedDefenders);
        final selectedActionCards = actionCardsByIds(selectedActions);
        final actionAtk = selectedActionCards
            .where((card) => card.category == ActionCategory.attack)
            .length;
        final actionDef = selectedActionCards
            .where((card) => card.category == ActionCategory.defense)
            .length;
        final actionSpc = selectedActionCards
            .where((card) => card.category == ActionCategory.special)
            .length;
        return Scaffold(
          appBar: ReactHeaderBar(
            title: 'Deck Builder',
            subtitle: editing ? 'Editing / unsaved' : active.name,
            onBack: () => widget.onNavigate(AppSection.home),
            showShop: false,
            rightSlot: TextButton(
              onPressed: editing
                  ? null
                  : () => context.read<GameBloc>().add(DeckCreated()),
              child: const Text('NEW DECK'),
            ),
          ),
          body: CyberBackground(
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 118),
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 430),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: 58,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: state.deckSlots.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (_, index) {
                                      final slot = state.deckSlots[index];
                                      final activeSlot =
                                          slot.id == state.activeDeckId;
                                      return DeckPill(
                                        label: slot.name,
                                        meta:
                                            'P ${slot.attackers.length + slot.defenders.length}/4 / ACT ${slot.actions.length}/6',
                                        selected: activeSlot,
                                        onTap: editing
                                            ? null
                                            : () => context
                                                  .read<GameBloc>()
                                                  .add(DeckApplied(slot.id)),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 10),
                                FiveSideDeckPanel(
                                  deckName: active.name,
                                  valid: valid,
                                  attackers: selectedAttackerCards,
                                  defenders: selectedDefenderCards,
                                  actions: selectedActionCards,
                                  actionAtk: actionAtk,
                                  actionDef: actionDef,
                                  actionSpc: actionSpc,
                                  onAttackTap: () {
                                    if (editing) _tabs.animateTo(0);
                                  },
                                  onDefenseTap: () {
                                    if (editing) _tabs.animateTo(1);
                                  },
                                  onActionTap: () {
                                    if (editing) _tabs.animateTo(2);
                                  },
                                ),
                                if (editing) ...[
                                  const SizedBox(height: 12),
                                  _DeckTabBar(controller: _tabs, state: this),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 330,
                                    child: TabBarView(
                                      controller: _tabs,
                                      children: [
                                        SelectionWrap<PlayerCard>(
                                          cards: attackers,
                                          selectedIds: selectedAttackers,
                                          enabled: editing,
                                          builder: (card, selected, disabled) =>
                                              CyberPlayerCardTile(
                                                card: card,
                                                selected: selected,
                                                disabled: disabled,
                                                size: VisualCardSize.sm,
                                              ),
                                          onToggle: (card) => _toggle(
                                            selectedAttackers,
                                            card.id,
                                            2,
                                          ),
                                          isDisabled: (card) =>
                                              selectedAttackers.length >= 2 &&
                                              !selectedAttackers.contains(
                                                card.id,
                                              ),
                                        ),
                                        SelectionWrap<PlayerCard>(
                                          cards: defenders,
                                          selectedIds: selectedDefenders,
                                          enabled: editing,
                                          builder: (card, selected, disabled) =>
                                              CyberPlayerCardTile(
                                                card: card,
                                                selected: selected,
                                                disabled: disabled,
                                                size: VisualCardSize.sm,
                                              ),
                                          onToggle: (card) => _toggle(
                                            selectedDefenders,
                                            card.id,
                                            2,
                                          ),
                                          isDisabled: (card) =>
                                              selectedDefenders.length >= 2 &&
                                              !selectedDefenders.contains(
                                                card.id,
                                              ),
                                        ),
                                        SelectionWrap<ActionCard>(
                                          cards: actionCards,
                                          selectedIds: selectedActions,
                                          enabled: editing,
                                          builder: (card, selected, disabled) =>
                                              CyberActionCardTile(
                                                card: card,
                                                selected: selected,
                                                disabled: disabled,
                                                size: VisualCardSize.sm,
                                              ),
                                          onToggle: (card) => _toggle(
                                            selectedActions,
                                            card.id,
                                            6,
                                          ),
                                          isDisabled: (card) =>
                                              selectedActions.length >= 6 &&
                                              !selectedActions.contains(
                                                card.id,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    BottomActionBar(
                      primaryLabel: 'PLAY',
                      primaryEnabled: valid,
                      primaryOnTap: () {
                        final slot = StoredDeckSlot(
                          id: state.activeDeckId,
                          name: active.name,
                          attackers: selectedAttackers,
                          defenders: selectedDefenders,
                          actions: selectedActions,
                        );
                        context.read<GameBloc>().add(DeckSaved(slot));
                        context.read<GameBloc>().add(MatchStarted());
                        widget.onNavigate(AppSection.match);
                      },
                      secondaryLabel: editing ? 'SAVE' : 'EDIT',
                      secondaryOnTap: () {
                        if (editing) {
                          final slot = StoredDeckSlot(
                            id: state.activeDeckId,
                            name: active.name,
                            attackers: selectedAttackers,
                            defenders: selectedDefenders,
                            actions: selectedActions,
                          );
                          context.read<GameBloc>().add(DeckSaved(slot));
                        }
                        setState(() => editing = !editing);
                      },
                    ),
                  ],
                ),
                const TutorialTip(
                  keyName: 'deck-builder',
                  steps: deckTutorialSteps,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggle(List<String> ids, String id, int max) {
    if (!editing) return;
    setState(() {
      if (ids.contains(id)) {
        ids.remove(id);
      } else if (ids.length < max) {
        ids.add(id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Only $max cards allowed in this group')),
        );
      }
    });
  }
}

class MatchScreen extends StatefulWidget {
  const MatchScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  Timer? cpuTossTimer;
  Timer? cpuPenaltyTimer;

  @override
  void dispose() {
    cpuTossTimer?.cancel();
    cpuPenaltyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameState>(
      listener: (context, state) {
        if (state.phase == MatchPhase.scenario &&
            state.currentScenario == null) {
          context.read<GameBloc>().add(ScenarioShown());
        }
        if (state.phase == MatchPhase.tossResult &&
            state.playerWonToss == false) {
          cpuTossTimer?.cancel();
          cpuTossTimer = Timer(const Duration(milliseconds: 900), () {
            if (!mounted) return;
            context.read<GameBloc>().add(RoleChosen(Random().nextBool()));
          });
        }
        if (state.phase == MatchPhase.penalty &&
            !state.penaltyPhaseOver &&
            state.penaltyRound.isOdd) {
          cpuPenaltyTimer?.cancel();
          cpuPenaltyTimer = Timer(const Duration(milliseconds: 800), () {
            if (!mounted) return;
            context.read<GameBloc>().add(PenaltyTaken());
          });
        }
      },
      builder: (context, state) {
        return switch (state.phase) {
          MatchPhase.toss => TossPhase(
            state: state,
            onQuit: () => _quit(context),
          ),
          MatchPhase.tossResult => TossResultPhase(
            state: state,
            onQuit: () => _quit(context),
          ),
          MatchPhase.scenario => ScenarioPhase(
            state: state,
            onQuit: () => _quit(context),
          ),
          MatchPhase.play => PlayPhase(
            state: state,
            onQuit: () => _quit(context),
          ),
          MatchPhase.roundResult => RoundResultPhase(
            state: state,
            onQuit: () => _quit(context),
          ),
          MatchPhase.matchEnd => MatchEndPhase(
            state: state,
            onQuit: () => _quit(context),
          ),
          MatchPhase.penalty => PenaltyPhase(
            state: state,
            onQuit: () => _quit(context),
          ),
          MatchPhase.finalResult => FinalResultPhase(
            state: state,
            onNavigate: widget.onNavigate,
          ),
          MatchPhase.idle => GameScaffold(
            title: 'Match',
            subtitle: '// Match Terminal',
            leading: IconButton(
              onPressed: () => _quit(context),
              icon: const Icon(Icons.close),
            ),
            child: Center(
              child: CyberCtaButton(
                label: 'Start Match',
                primary: true,
                onPressed: () => context.read<GameBloc>().add(MatchStarted()),
              ),
            ),
          ),
        };
      },
    );
  }

  Future<void> _quit(BuildContext context) async {
    final gameBloc = context.read<GameBloc>();
    final phase = gameBloc.state.phase;
    final matchInProgress =
        phase != MatchPhase.idle &&
        phase != MatchPhase.finalResult &&
        phase != MatchPhase.matchEnd;

    if (matchInProgress) {
      final confirmed = await showCyberConfirmDialog(
        context,
        title: 'Quit Match?',
        message: 'Your current match progress will be lost.',
        confirmLabel: 'Quit',
        cancelLabel: 'Keep Playing',
        destructive: true,
      );
      if (!mounted || !confirmed) return;
    }

    gameBloc.add(MatchReset());
    widget.onNavigate(AppSection.home);
  }
}

class TossPhase extends StatelessWidget {
  const TossPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return MatchPhaseScaffold(
      title: 'Round ${max(1, state.currentRound)}',
      subtitle: '// Coin Toss Protocol',
      state: state,
      onQuit: onQuit,
      tutorialKey: 'toss',
      tutorialSteps: tossTutorialSteps,
      children: [
        const SizedBox(height: 18),
        Icon(
          Icons.toll,
          size: 92,
          color: Cyber.cyan,
          shadows: [Shadow(color: Cyber.cyan, blurRadius: 18)],
        ),
        const SizedBox(height: 8),
        const Text(
          '▸ INITIATING TOSS',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Cyber.cyan,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.w900,
            letterSpacing: 1.7,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: ChoiceButton(
                label: 'Heads',
                selected: state.tossChoice == 'heads',
                onTap: () =>
                    context.read<GameBloc>().add(TossChoiceChanged('heads')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceButton(
                label: 'Tails',
                selected: state.tossChoice == 'tails',
                onTap: () =>
                    context.read<GameBloc>().add(TossChoiceChanged('tails')),
              ),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: state.tossChoice == null
              ? null
              : () => context.read<GameBloc>().add(TossResolved()),
          icon: const Icon(Icons.flip),
          label: const Text('▸ FLIP COIN'),
        ),
      ],
    );
  }
}

class TossResultPhase extends StatelessWidget {
  const TossResultPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return MatchPhaseScaffold(
      title: 'Round ${max(1, state.currentRound)}',
      subtitle: '// Coin Toss Result',
      state: state,
      onQuit: onQuit,
      tutorialKey: 'toss',
      tutorialSteps: tossTutorialSteps,
      children: [
        InfoPanel(
          icon: Icons.toll,
          title: 'It landed ${state.tossResult?.toUpperCase()}',
          body: state.playerWonToss == true
              ? 'You won the toss. Pick your opening role.'
              : 'CPU won the toss and is choosing a role.',
        ),
        if (state.playerWonToss == true)
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      context.read<GameBloc>().add(RoleChosen(true)),
                  icon: const Icon(Icons.sports_soccer),
                  label: const Text('Attack'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      context.read<GameBloc>().add(RoleChosen(false)),
                  icon: const Icon(Icons.shield),
                  label: const Text('Defend'),
                ),
              ),
            ],
          )
        else
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class ScenarioPhase extends StatelessWidget {
  const ScenarioPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final scenario = state.currentScenario;
    if (scenario == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return MatchPhaseScaffold(
      title: 'Round ${max(1, state.currentRound)}',
      subtitle: '// Scenario Briefing',
      state: state,
      onQuit: onQuit,
      tutorialKey: 'scenario',
      tutorialSteps: scenarioTutorialSteps,
      children: [
        InfoPanel(
          icon: scenario.icon,
          title: scenario.title,
          body:
              '${scenario.description}\nAttack +${scenario.attackBonus}  Defense +${scenario.defenseBonus}\nYou are ${state.playerAttacking ? 'attacking' : 'defending'} this round.',
        ),
        FilledButton.icon(
          onPressed: () => context.read<GameBloc>().add(PlayStarted()),
          icon: const Icon(Icons.style),
          label: const Text('▸ SELECT CARDS'),
        ),
      ],
    );
  }
}

class PlayPhase extends StatelessWidget {
  const PlayPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final playerPool = state.playerAttacking
        ? state.deckAttackers
        : state.deckDefenders;
    final availablePlayers = playerPool
        .where((card) => !state.redCardedCards.contains(card.id))
        .toList();
    final availableActions = state.deckActions
        .where(
          (card) => state.playerAttacking
              ? card.category == ActionCategory.attack ||
                    card.category == ActionCategory.special
              : card.category == ActionCategory.defense ||
                    card.category == ActionCategory.special,
        )
        .toList();
    final scenarioBonus = state.playerAttacking
        ? state.currentScenario?.attackBonus ?? 0
        : state.currentScenario?.defenseBonus ?? 0;
    final estimate =
        state.selectedPlayerCard == null || state.selectedActionCard == null
        ? null
        : state.selectedPlayerCard!.rating +
              state.selectedActionCard!.power +
              scenarioBonus;
    return MatchPhaseScaffold(
      title: 'Round ${max(1, state.currentRound)}',
      subtitle: state.currentScenario?.title ?? '// Play Protocol',
      state: state,
      onQuit: onQuit,
      tutorialKey: 'play',
      tutorialSteps: playTutorialSteps,
      children: [
        RoleStrip(attacking: state.playerAttacking),
        SelectedMovePanel(
          player: state.selectedPlayerCard,
          action: state.selectedActionCard,
          estimate: estimate,
        ),
        SectionLabel(
          label: state.playerAttacking
              ? 'Roster // Finishers'
              : 'Roster // Stoppers',
        ),
        SizedBox(
          height: 162,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: availablePlayers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, index) {
              final card = availablePlayers[index];
              return CyberPlayerCardTile(
                card: card,
                selected: state.selectedPlayerCard?.id == card.id,
                onTap: () => context.read<GameBloc>().add(PlayerSelected(card)),
              );
            },
          ),
        ),
        const SectionLabel(label: 'Action Grid'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final card in availableActions)
              CyberActionCardTile(
                card: card,
                selected: state.selectedActionCard?.id == card.id,
                onTap: () => context.read<GameBloc>().add(ActionSelected(card)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        CyberCtaButton(
          label: 'Execute Move',
          primary: true,
          onPressed:
              state.selectedPlayerCard == null ||
                  state.selectedActionCard == null
              ? null
              : () => context.read<GameBloc>().add(MovePlayed()),
        ),
      ],
    );
  }
}

class RoundResultPhase extends StatelessWidget {
  const RoundResultPhase({
    required this.state,
    required this.onQuit,
    super.key,
  });

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final result = state.roundResults.last;
    return MatchPhaseScaffold(
      title: 'Round ${result.round} // Result',
      subtitle: '// Resolution Log',
      state: state,
      onQuit: onQuit,
      tutorialKey: 'round-result',
      tutorialSteps: resultTutorialSteps,
      children: [
        Icon(outcomeIcon(result.outcome), size: 72, color: Cyber.cyan),
        Text(
          outcomeLabel(result.outcome).toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Cyber.cyan,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.w900,
            fontSize: 26,
            letterSpacing: 2,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CyberChip(
              label: result.attackPower.toStringAsFixed(1),
              color: Cyber.lime,
            ),
            const SizedBox(width: 10),
            CyberChip(
              label: result.defensePower.toStringAsFixed(1),
              color: Cyber.cyan,
            ),
          ],
        ),
        InfoPanel(
          icon: outcomeIcon(result.outcome),
          title: outcomeLabel(result.outcome),
          body:
              '${result.attackerCard.name} with ${result.attackAction.title}\nvs ${result.defenderCard.name} with ${result.defenseAction.title}\nPower ${result.attackPower.toStringAsFixed(1)} - ${result.defensePower.toStringAsFixed(1)}',
        ),
        FilledButton.icon(
          onPressed: () => context.read<GameBloc>().add(RoundAdvanced()),
          icon: Icon(
            state.currentRound >= 4 ? Icons.flag : Icons.arrow_forward,
          ),
          label: Text(
            state.currentRound >= 4 ? 'Full-Time Result' : 'Next Round',
          ),
        ),
      ],
    );
  }
}

class MatchEndPhase extends StatelessWidget {
  const MatchEndPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final tied = state.playerScore == state.opponentScore;
    final title = tied
        ? 'Deadlock'
        : (state.playerScore > state.opponentScore ? 'Victory' : 'Defeat');
    return MatchPhaseScaffold(
      title: 'Full Time',
      subtitle: '// Match Archive',
      state: state,
      onQuit: onQuit,
      tutorialKey: 'match-end',
      tutorialSteps: matchEndTutorialSteps,
      children: [
        InfoPanel(
          icon: tied ? Icons.balance : Icons.emoji_events,
          title: title,
          body: tied
              ? 'The match is level. Settle it from the spot.'
              : 'Regular time is complete.',
        ),
        FilledButton.icon(
          onPressed: () => context.read<GameBloc>().add(
            tied ? PenaltyStarted() : MatchFinished(),
          ),
          icon: Icon(tied ? Icons.adjust : Icons.done),
          label: Text(tied ? 'Penalty Shootout' : 'Finish Match'),
        ),
      ],
    );
  }
}

class PenaltyPhase extends StatelessWidget {
  const PenaltyPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final playerTurn = state.penaltyRound.isEven;
    return MatchPhaseScaffold(
      title: 'Penalty Shootout',
      subtitle: '// Sudden Pressure',
      state: state,
      onQuit: onQuit,
      scoreLabel:
          'PEN ${state.penaltyPlayerScore}-${state.penaltyOpponentScore}',
      tutorialKey: 'penalty',
      tutorialSteps: penaltyTutorialSteps,
      children: [
        InfoPanel(
          icon: Icons.adjust,
          title:
              'Penalties ${state.penaltyPlayerScore}-${state.penaltyOpponentScore}',
          body: state.penaltyPhaseOver
              ? 'Shootout complete.'
              : playerTurn
              ? 'Your kick.'
              : 'CPU is stepping up.',
        ),
        for (final kick in state.penaltyKicks.reversed)
          CyberPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  kick.scored ? Icons.check_circle : Icons.cancel,
                  color: kick.scored ? Cyber.lime : Cyber.red,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(kick.byPlayer ? 'YOU' : 'CPU')),
                Text(kick.label),
              ],
            ),
          ),
        if (state.penaltyPhaseOver)
          FilledButton.icon(
            onPressed: () => context.read<GameBloc>().add(MatchFinished()),
            icon: const Icon(Icons.done_all),
            label: const Text('Final Result'),
          )
        else
          FilledButton.icon(
            onPressed: playerTurn
                ? () => context.read<GameBloc>().add(PenaltyTaken())
                : null,
            icon: const Icon(Icons.sports_soccer),
            label: Text(playerTurn ? 'Take Kick' : 'CPU Kicking'),
          ),
      ],
    );
  }
}

class FinalResultPhase extends StatelessWidget {
  const FinalResultPhase({
    required this.state,
    required this.onNavigate,
    super.key,
  });

  final GameState state;
  final ValueChanged<AppSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    final won =
        state.playerScore > state.opponentScore ||
        (state.playerScore == state.opponentScore &&
            state.penaltyPlayerScore > state.penaltyOpponentScore);
    final mvp = state.roundResults
        .where(
          (round) =>
              round.outcome == RoundOutcome.goal && round.playerAttacking,
        )
        .map((round) => round.attackerCard)
        .firstOrNull;
    return GameScaffold(
      title: 'Final Result',
      subtitle: '// Archive Complete',
      leading: IconButton(
        onPressed: () {
          context.read<GameBloc>().add(MatchReset());
          onNavigate(AppSection.home);
        },
        icon: const Icon(Icons.close),
      ),
      child: Stack(
        children: [
          PhaseList(
            children: [
              ScoreboardPanel(state: state, label: 'FINAL'),
              InfoPanel(
                icon: won ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                title: won ? 'Match Won' : 'Match Lost',
                body:
                    'Regular score ${state.playerScore}-${state.opponentScore}${state.penaltyKicks.isNotEmpty ? '\nPenalties ${state.penaltyPlayerScore}-${state.penaltyOpponentScore}' : ''}',
              ),
              if (mvp != null) CyberPlayerCardTile(card: mvp, selected: true),
              Text('Round Log', style: Theme.of(context).textTheme.titleLarge),
              for (final round in state.roundResults)
                ListTile(
                  leading: CircleAvatar(child: Text('${round.round}')),
                  title: Text(
                    '${round.scenario.title}: ${outcomeLabel(round.outcome)}',
                  ),
                  subtitle: Text(
                    round.playerAttacking ? 'You attacked' : 'You defended',
                  ),
                ),
              FilledButton.icon(
                onPressed: () {
                  context.read<GameBloc>().add(MatchStarted());
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Rematch'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  context.read<GameBloc>().add(MatchReset());
                  onNavigate(AppSection.home);
                },
                icon: const Icon(Icons.home),
                label: const Text('Home'),
              ),
            ],
          ),
          const TutorialTip(keyName: 'final', steps: finalTutorialSteps),
        ],
      ),
    );
  }
}

Future<bool> showCyberConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: CyberConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      ),
    ),
  );
  return confirmed ?? false;
}

class CyberConfirmDialog extends StatelessWidget {
  const CyberConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    super.key,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? Cyber.red : Cyber.cyan;
    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: CyberPanel(
          accent: destructive ? Cyber.magenta : Cyber.cyan,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: accent,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          destructive ? 'WARNING' : 'CONFIRM',
                          style: TextStyle(
                            color: accent,
                            fontFamily: 'Orbitron',
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Orbitron',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Color(0xff9aa8bb),
                        fontFamily: 'Onest',
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const HudLine(),
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Expanded(
                      child: _CyberDialogAction(
                        label: cancelLabel,
                        color: Cyber.muted,
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    Container(width: 1, color: const Color(0xff1e2538)),
                    Expanded(
                      child: _CyberDialogAction(
                        label: '$confirmLabel >',
                        color: accent,
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CyberDialogAction extends StatelessWidget {
  const _CyberDialogAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.08),
        child: Center(
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontFamily: 'Orbitron',
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
            ),
          ),
        ),
      ),
    );
  }
}

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    const steps = [
      'Build a valid deck with 2 attackers, 2 defenders, and 6 action cards.',
      'Win or lose the toss to decide the first-round role.',
      'Each round reveals a scenario bonus, then you choose one player and one legal action.',
      'Goals are decided by rating, action power, scenario bonus, a hidden roll, and risk checks.',
      'After four rounds, tied games go to a three-kick shootout plus sudden death.',
    ];
    return GameScaffold(
      title: 'How to Play',
      leading: IconButton(
        onPressed: () => onNavigate(AppSection.home),
        icon: const Icon(Icons.arrow_back),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < steps.length; i++)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(steps[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class GameScaffold extends StatelessWidget {
  const GameScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.showShop = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool showShop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ReactHeaderBar(
        title: title,
        subtitle: subtitle,
        onBack: leading == null ? null : () => Navigator.maybePop(context),
        leftSlot: leading,
        showShop: showShop,
      ),
      body: CyberBackground(child: child),
    );
  }
}

class ReactHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const ReactHeaderBar({
    required this.title,
    this.subtitle,
    this.onBack,
    this.leftSlot,
    this.rightSlot,
    this.showShop = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? leftSlot;
  final Widget? rightSlot;
  final bool showShop;

  @override
  Size get preferredSize => const Size.fromHeight(66);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      titleSpacing: 0,
      title: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff0b1120), Color(0xff070b14)],
          ),
          border: Border(bottom: BorderSide(color: Color(0xff1e2538))),
        ),
        child: Row(
          children: [
            if (leftSlot != null)
              SizedBox(width: 42, height: 42, child: leftSlot)
            else if (onBack != null)
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                color: Cyber.cyan,
              ),
            if (leftSlot != null || onBack != null) const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '/',
                        style: TextStyle(
                          color: Cyber.cyan,
                          fontFamily: 'Orbitron',
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Orbitron',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Cyber.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            if (showShop) ...[
              HeaderShopButton(onTap: () => showShopDialog(context)),
              const SizedBox(width: 8),
            ],
            ?rightSlot,
          ],
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(2),
        child: HudLine(),
      ),
    );
  }
}

class HeaderShopButton extends StatelessWidget {
  const HeaderShopButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Cyber.cyan.withValues(alpha: 0.08),
          border: Border.all(color: Cyber.cyan.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Cyber.cyan.withValues(alpha: 0.08),
              blurRadius: 12,
              spreadRadius: -6,
            ),
          ],
        ),
        child: const Text(
          'SHOP',
          style: TextStyle(
            color: Cyber.cyan,
            fontFamily: 'Onest',
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
      ),
    );
  }
}

class ShopPackOption {
  const ShopPackOption({
    required this.id,
    required this.name,
    required this.coins,
    required this.gradient,
  });

  final String id;
  final String name;
  final int coins;
  final LinearGradient gradient;
}

const shopPacks = [
  ShopPackOption(
    id: 'bronze',
    name: 'Bronze Pack',
    coins: 10,
    gradient: LinearGradient(
      colors: [Color(0xff855332), Color(0xffc07a45), Color(0xff3a2519)],
    ),
  ),
  ShopPackOption(
    id: 'silver',
    name: 'Silver Pack',
    coins: 50,
    gradient: LinearGradient(
      colors: [Color(0xff657080), Color(0xffd9e2ef), Color(0xff485160)],
    ),
  ),
  ShopPackOption(
    id: 'gold',
    name: 'Gold Pack',
    coins: 250,
    gradient: LinearGradient(
      colors: [Color(0xff9b6418), Color(0xffffd23d), Color(0xff7a4108)],
    ),
  ),
  ShopPackOption(
    id: 'platinum',
    name: 'Platinum Pack',
    coins: 1000,
    gradient: LinearGradient(
      colors: [
        Color(0xff25365a),
        Color(0xffc9f7ff),
        Color(0xffba6eff),
        Color(0xff10182e),
      ],
    ),
  ),
];

void showShopDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.78),
    builder: (_) => BlocProvider.value(
      value: context.read<GameBloc>(),
      child: const ShopDialog(),
    ),
  );
}

void showTutorialNow(
  BuildContext context, {
  required String keyName,
  required List<TutorialStepData> steps,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (_) => BlocProvider.value(
      value: context.read<GameBloc>(),
      child: TutorialDialog(keyName: keyName, steps: steps, force: true),
    ),
  );
}

class ShopDialog extends StatefulWidget {
  const ShopDialog({super.key});

  @override
  State<ShopDialog> createState() => _ShopDialogState();
}

class _ShopDialogState extends State<ShopDialog> {
  final Random _random = Random();
  ShopPackOption? openingPack;
  PlayerCard? revealedCard;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.55),
                  radius: 0.75,
                  colors: [
                    Cyber.cyan.withValues(alpha: 0.18),
                    const Color(0xe603050a),
                    const Color(0xf003050a),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430, minHeight: 420),
              child: CyberPanel(
                padding: const EdgeInsets.all(18),
                child: Stack(
                  children: [
                    if (openingPack == null)
                      _ShopPackPicker(onOpen: _openPack)
                    else
                      _ShopOpeningStage(
                        pack: openingPack!,
                        card: revealedCard!,
                        onBack: () => setState(() {
                          openingPack = null;
                          revealedCard = null;
                        }),
                      ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Cyber.cyan),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openPack(ShopPackOption pack) {
    final card = _pickPackCard(pack.id);
    context.read<GameBloc>().add(OwnedCardAdded(card.id));
    setState(() {
      openingPack = pack;
      revealedCard = card;
    });
  }

  PlayerCard _pickPackCard(String packId) {
    final allCards = [...attackers, ...defenders];
    final silver = allCards
        .where((card) => card.tier == CardTier.silver)
        .toList();
    final gold = allCards.where((card) => card.tier == CardTier.gold).toList();
    final purple = allCards
        .where((card) => card.tier == CardTier.purple)
        .toList();
    final roll = _random.nextDouble();
    var pool = allCards;
    if (packId == 'bronze') {
      pool = roll < 0.72
          ? silver
          : roll < 0.94
          ? gold
          : purple;
    }
    if (packId == 'silver') {
      pool = roll < 0.45
          ? silver
          : roll < 0.86
          ? gold
          : purple;
    }
    if (packId == 'gold') {
      pool = roll < 0.20
          ? silver
          : roll < 0.72
          ? gold
          : purple;
    }
    if (packId == 'platinum') {
      pool = roll < 0.12 ? gold : purple;
    }
    return pool[_random.nextInt(pool.length)];
  }
}

class _ShopPackPicker extends StatelessWidget {
  const _ShopPackPicker({required this.onOpen});

  final ValueChanged<ShopPackOption> onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 42, bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CARD SHOP',
                        style: TextStyle(
                          color: Cyber.cyan.withValues(alpha: 0.62),
                          fontFamily: 'Onest',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'CHOOSE PACK',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Orbitron',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.style, color: Cyber.cyan, size: 34),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemCount: shopPacks.length,
            itemBuilder: (_, index) {
              final pack = shopPacks[index];
              return ShopPackCard(pack: pack, onTap: () => onOpen(pack));
            },
          ),
        ],
      ),
    );
  }
}

class ShopPackCard extends StatelessWidget {
  const ShopPackCard({required this.pack, required this.onTap, super.key});

  final ShopPackOption pack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipPath(
        clipper: CyberClipper(),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: pack.gradient,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 26),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.2),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.24),
                    ],
                    stops: const [0, 0.42, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Cyber.bg.withValues(alpha: 0.38),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(Icons.style, color: Colors.white, size: 24),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 34,
              child: Text(
                pack.name.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 15,
              child: Text(
                '${pack.coins} COINS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontFamily: 'Onest',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopOpeningStage extends StatelessWidget {
  const _ShopOpeningStage({
    required this.pack,
    required this.card,
    required this.onBack,
  });

  final ShopPackOption pack;
  final PlayerCard card;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 560,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const _PackBurst(),
          Positioned(top: 58, child: ShopPackVisual(pack: pack)),
          Positioned(
            top: 32,
            child: Column(
              children: [
                Text(
                  '${pack.name} Opened'.toUpperCase(),
                  style: TextStyle(
                    color: Cyber.cyan.withValues(alpha: 0.72),
                    fontFamily: 'Onest',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.6,
                  ),
                ),
                const SizedBox(height: 192),
                CyberPlayerCardTile(
                  card: card,
                  selected: true,
                  size: VisualCardSize.md,
                ),
                const SizedBox(height: 14),
                Text(
                  card.name.toUpperCase(),
                  style: const TextStyle(
                    color: Cyber.cyan,
                    fontFamily: 'Orbitron',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'ADDED TO YOUR CARDS',
                  style: TextStyle(
                    color: Cyber.lime,
                    fontFamily: 'Onest',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.1,
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: onBack,
                  child: const Text('CHOOSE ANOTHER PACK'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShopPackVisual extends StatelessWidget {
  const ShopPackVisual({required this.pack, super.key});

  final ShopPackOption pack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 198,
      height: 282,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: pack.gradient,
                border: Border.all(
                  color: Cyber.amber.withValues(alpha: 0.86),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Cyber.amber.withValues(alpha: 0.42),
                    blurRadius: 28,
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: CardStripePainter(color: Colors.white)),
          ),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.42),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Icon(Icons.style, color: Cyber.bg, size: 34),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.26),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.22),
                  ],
                  stops: const [0, 0.18, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TutorialTip extends StatefulWidget {
  const TutorialTip({
    required this.keyName,
    required this.steps,
    this.forceToken = 0,
    super.key,
  });

  final String keyName;
  final List<TutorialStepData> steps;
  final int forceToken;

  @override
  State<TutorialTip> createState() => _TutorialTipState();
}

class _TutorialTipState extends State<TutorialTip> {
  bool _scheduled = false;
  int _lastForceToken = 0;

  @override
  void initState() {
    super.initState();
    _lastForceToken = widget.forceToken;
    _maybeSchedule();
  }

  @override
  void didUpdateWidget(covariant TutorialTip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final forced = widget.forceToken != _lastForceToken;
    if (forced) {
      _lastForceToken = widget.forceToken;
      _scheduled = false;
      _schedule(force: true);
      return;
    }
    _maybeSchedule();
  }

  void _maybeSchedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scheduled) return;
      final seen = context.read<GameBloc>().state.tutorialSeen;
      if (!seen.contains(widget.keyName)) {
        _schedule();
      }
    });
  }

  void _schedule({bool force = false}) {
    if (_scheduled || widget.steps.isEmpty) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.85),
        builder: (_) => BlocProvider.value(
          value: context.read<GameBloc>(),
          child: TutorialDialog(
            keyName: widget.keyName,
            steps: widget.steps,
            force: force,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class TutorialDialog extends StatefulWidget {
  const TutorialDialog({
    required this.keyName,
    required this.steps,
    this.force = false,
    super.key,
  });

  final String keyName;
  final List<TutorialStepData> steps;
  final bool force;

  @override
  State<TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<TutorialDialog> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[index];
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: CyberPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Cyber.cyan,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Cyber.cyan, blurRadius: 8)],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '▸ ONBOARDING · ${(index + 1).toString().padLeft(2, '0')}/${widget.steps.length.toString().padLeft(2, '0')}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Cyber.cyan,
                      fontFamily: 'Onest',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
                TextButton(onPressed: _skipAll, child: const Text('SKIP ALL')),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              step.title.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Orbitron',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.7,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              step.body,
              style: const TextStyle(
                color: Color(0xffd1d5db),
                fontFamily: 'Onest',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                for (var i = 0; i < widget.steps.length; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(
                        right: i == widget.steps.length - 1 ? 0 : 5,
                      ),
                      decoration: BoxDecoration(
                        color: i == index
                            ? Cyber.cyan
                            : i < index
                            ? Cyber.cyan.withValues(alpha: 0.42)
                            : const Color(0xff1e2538),
                        boxShadow: i == index
                            ? [
                                BoxShadow(
                                  color: Cyber.cyan.withValues(alpha: 0.7),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const HudLine(),
            Row(
              children: [
                if (index > 0)
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => index--),
                      child: const Text('◄ BACK'),
                    ),
                  ),
                Expanded(
                  child: TextButton(
                    onPressed: _next,
                    child: Text(
                      index < widget.steps.length - 1 ? 'NEXT ▸' : 'GOT IT ▸',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _next() {
    if (index < widget.steps.length - 1) {
      setState(() => index++);
      return;
    }
    context.read<GameBloc>().add(TutorialSeenMarked(widget.keyName));
    Navigator.pop(context);
  }

  void _skipAll() {
    context.read<GameBloc>().add(TutorialsSkippedAll());
    Navigator.pop(context);
  }
}

class _PackBurst extends StatelessWidget {
  const _PackBurst();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 310,
      height: 310,
      child: Stack(
        children: [
          for (var i = 0; i < 12; i++)
            Positioned.fill(
              child: Transform.rotate(
                angle: i * pi / 6,
                child: Align(
                  alignment: const Alignment(0, -0.38),
                  child: Container(
                    width: 3,
                    height: 126,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Cyber.amber.withValues(alpha: 0.95),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Cyber.amber.withValues(alpha: 0.5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CyberBackground extends StatelessWidget {
  const CyberBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: CyberGridPainter())),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.2, -0.75),
                radius: 1.1,
                colors: [
                  Cyber.cyan.withValues(alpha: 0.12),
                  Cyber.violet.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class CyberGridPainter extends CustomPainter {
  const CyberGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Cyber.bg);
    final paint = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    const step = 40.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HudLine extends StatelessWidget {
  const HudLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Cyber.cyan.withValues(alpha: 0.9),
            Cyber.magenta.withValues(alpha: 0.75),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class PhaseList extends StatelessWidget {
  const PhaseList({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (_, index) => children[index],
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemCount: children.length,
    );
  }
}

class MatchPhaseScaffold extends StatelessWidget {
  const MatchPhaseScaffold({
    required this.title,
    required this.subtitle,
    required this.state,
    required this.children,
    required this.onQuit,
    this.scoreLabel,
    this.tutorialKey,
    this.tutorialSteps = const [],
    super.key,
  });

  final String title;
  final String subtitle;
  final GameState state;
  final List<Widget> children;
  final VoidCallback onQuit;
  final String? scoreLabel;
  final String? tutorialKey;
  final List<TutorialStepData> tutorialSteps;

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: title,
      subtitle: subtitle,
      leading: IconButton(
        onPressed: onQuit,
        icon: const Icon(Icons.close, color: Cyber.cyan),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              ScoreboardPanel(state: state, label: scoreLabel),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (_, index) => children[index],
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemCount: children.length,
                ),
              ),
            ],
          ),
          if (tutorialKey != null)
            TutorialTip(keyName: tutorialKey!, steps: tutorialSteps),
        ],
      ),
    );
  }
}

class RoleStrip extends StatelessWidget {
  const RoleStrip({required this.attacking, super.key});

  final bool attacking;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: attacking ? Cyber.lime : Cyber.cyan,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(
            attacking ? Icons.sports_soccer : Icons.shield,
            color: attacking ? Cyber.lime : Cyber.cyan,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'YOU // ${attacking ? 'ATTACKING' : 'DEFENDING'}',
              style: TextStyle(
                color: attacking ? Cyber.lime : Cyber.cyan,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
              ),
            ),
          ),
          const HiddenCard(),
          const SizedBox(width: 8),
          const HiddenCard(),
        ],
      ),
    );
  }
}

class HiddenCard extends StatelessWidget {
  const HiddenCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Cyber.red, Cyber.panel]),
        border: Border.all(color: Cyber.red.withValues(alpha: 0.5)),
      ),
      child: const Icon(Icons.style, color: Cyber.red, size: 16),
    );
  }
}

class SelectedMovePanel extends StatelessWidget {
  const SelectedMovePanel({
    required this.player,
    required this.action,
    required this.estimate,
    super.key,
  });

  final PlayerCard? player;
  final ActionCard? action;
  final int? estimate;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      child: Row(
        children: [
          Expanded(
            child: _MoveSlot(
              label: 'PLAYER',
              value: player?.name ?? 'Select card',
              color: Cyber.cyan,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MoveSlot(
              label: 'ACTION',
              value: action?.title ?? 'Select action',
              color: Cyber.magenta,
            ),
          ),
          const SizedBox(width: 10),
          CyberChip(
            label: estimate == null ? 'EST --' : 'EST $estimate',
            color: Cyber.lime,
          ),
        ],
      ),
    );
  }
}

class _MoveSlot extends StatelessWidget {
  const _MoveSlot({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.45),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: Cyber.cyan.withValues(alpha: 0.7),
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class CyberCtaButton extends StatelessWidget {
  const CyberCtaButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final bg = primary
        ? const LinearGradient(colors: [Cyber.cyan, Color(0xff5cb4ff)])
        : LinearGradient(colors: [Cyber.panel2, Cyber.panel]);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: onPressed,
        child: ClipPath(
          clipper: CyberClipper(),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 56),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: bg,
              border: Border.all(color: primary ? Cyber.cyan : Cyber.line),
              boxShadow: [
                BoxShadow(
                  color: (primary ? Cyber.cyan : Cyber.bg).withValues(
                    alpha: 0.3,
                  ),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: primary ? Cyber.bg : Cyber.cyan,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoadoutStatusPanel extends StatelessWidget {
  const LoadoutStatusPanel({required this.state, super.key});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '▸ LOADOUT STATUS',
            style: TextStyle(
              color: Cyber.cyan.withValues(alpha: 0.68),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MiniStat(
                  'ATK',
                  '${state.deckAttackers.length}/2',
                  state.deckAttackers.length == 2,
                ),
              ),
              Expanded(
                child: MiniStat(
                  'DEF',
                  '${state.deckDefenders.length}/2',
                  state.deckDefenders.length == 2,
                ),
              ),
              Expanded(
                child: MiniStat(
                  'ACT',
                  '${state.deckActions.length}/6',
                  state.deckActions.length == 6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MiniStat extends StatelessWidget {
  const MiniStat(this.label, this.value, this.ok, {super.key});

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: ok ? Cyber.cyan : Cyber.amber,
            fontFamily: 'Orbitron',
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class DeckPill extends StatelessWidget {
  const DeckPill({
    required this.label,
    required this.meta,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final String meta;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [Cyber.lime, Cyber.cyan])
              : const LinearGradient(colors: [Cyber.panel2, Cyber.panel]),
          border: Border.all(color: selected ? Cyber.lime : Cyber.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 14, color: Cyber.bg),
              const SizedBox(width: 6),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: selected ? Cyber.bg : Colors.white,
                    fontSize: 11,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  meta,
                  style: TextStyle(
                    color: selected
                        ? Cyber.bg.withValues(alpha: 0.65)
                        : Cyber.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FiveSideDeckPanel extends StatelessWidget {
  const FiveSideDeckPanel({
    required this.deckName,
    required this.valid,
    required this.attackers,
    required this.defenders,
    required this.actions,
    required this.actionAtk,
    required this.actionDef,
    required this.actionSpc,
    required this.onAttackTap,
    required this.onDefenseTap,
    required this.onActionTap,
    super.key,
  });

  final String deckName;
  final bool valid;
  final List<PlayerCard> attackers;
  final List<PlayerCard> defenders;
  final List<ActionCard> actions;
  final int actionAtk;
  final int actionDef;
  final int actionSpc;
  final VoidCallback onAttackTap;
  final VoidCallback onDefenseTap;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '5-A-SIDE DECK',
                      style: TextStyle(
                        color: Cyber.cyan.withValues(alpha: 0.65),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      deckName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              CyberChip(
                label: valid ? 'Ready' : 'Build',
                color: valid ? Cyber.lime : Cyber.amber,
              ),
            ],
          ),
          const SizedBox(height: 12),
          FiveSidePitch(
            attackers: attackers,
            defenders: defenders,
            onAttackTap: onAttackTap,
            onDefenseTap: onDefenseTap,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '6 ACTION CARDS',
                style: TextStyle(
                  color: Cyber.cyan.withValues(alpha: 0.65),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.7,
                ),
              ),
              const Spacer(),
              Text(
                'ATK $actionAtk / DEF $actionDef / SPC $actionSpc',
                style: TextStyle(
                  color: Cyber.cyan.withValues(alpha: 0.45),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 106,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final card = index < actions.length ? actions[index] : null;
                if (card == null) {
                  return EmptyActionSlot(onTap: onActionTap);
                }
                return CyberActionCardTile(
                  card: card,
                  selected: true,
                  onTap: onActionTap,
                  size: VisualCardSize.sm,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FiveSidePitch extends StatelessWidget {
  const FiveSidePitch({
    required this.attackers,
    required this.defenders,
    required this.onAttackTap,
    required this.onDefenseTap,
    super.key,
  });

  final List<PlayerCard> attackers;
  final List<PlayerCard> defenders;
  final VoidCallback onAttackTap;
  final VoidCallback onDefenseTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 390,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff073222), Color(0xff061b22), Color(0xff08111d)],
        ),
        border: Border.all(color: Cyber.cyan.withValues(alpha: 0.35)),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: PitchPainter())),
          Positioned(
            left: 34,
            top: 28,
            child: FormationSlot(
              label: 'ATK',
              card: attackers.firstOrNull,
              onTap: onAttackTap,
            ),
          ),
          Positioned(
            right: 34,
            top: 28,
            child: FormationSlot(
              label: 'ATK',
              card: attackers.length > 1 ? attackers[1] : null,
              onTap: onAttackTap,
            ),
          ),
          Positioned(
            left: 34,
            top: 158,
            child: FormationSlot(
              label: 'DEF',
              card: defenders.firstOrNull,
              onTap: onDefenseTap,
            ),
          ),
          Positioned(
            right: 34,
            top: 158,
            child: FormationSlot(
              label: 'DEF',
              card: defenders.length > 1 ? defenders[1] : null,
              onTap: onDefenseTap,
            ),
          ),
          const Positioned(left: 0, right: 0, bottom: 22, child: KeeperCore()),
        ],
      ),
    );
  }
}

class FormationSlot extends StatelessWidget {
  const FormationSlot({
    required this.label,
    required this.card,
    required this.onTap,
    super.key,
  });

  final String label;
  final PlayerCard? card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (card != null) {
      return CyberPlayerCardTile(
        card: card!,
        selected: true,
        onTap: onTap,
        size: VisualCardSize.sm,
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 96,
        height: 144,
        decoration: BoxDecoration(
          color: Cyber.bg.withValues(alpha: 0.58),
          border: Border.all(color: Cyber.cyan.withValues(alpha: 0.45)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              label == 'ATK' ? Icons.sports_soccer : Icons.shield,
              color: Cyber.cyan,
              size: 34,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Cyber.cyan,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'ADD CARD',
              style: TextStyle(color: Cyber.muted, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class KeeperCore extends StatelessWidget {
  const KeeperCore({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 112,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Cyber.magenta.withValues(alpha: 0.16),
          border: Border.all(color: Cyber.magenta.withValues(alpha: 0.65)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'GK',
              style: TextStyle(
                color: Cyber.magenta,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
              ),
            ),
            Icon(Icons.back_hand, color: Cyber.magenta, size: 28),
            Text(
              'KEEPER CORE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyActionSlot extends StatelessWidget {
  const EmptyActionSlot({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 96,
        decoration: BoxDecoration(
          color: Cyber.panel.withValues(alpha: 0.65),
          border: Border.all(color: Cyber.line),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style, color: Cyber.cyan),
            SizedBox(height: 6),
            Text(
              'ADD\nACTION',
              textAlign: TextAlign.center,
              style: TextStyle(color: Cyber.muted, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckTabBar extends StatelessWidget {
  const _DeckTabBar({required this.controller, required this.state});

  final TabController controller;
  final _DeckBuilderScreenState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Cyber.bg2,
        border: Border.all(color: const Color(0xff1e2538)),
      ),
      child: TabBar(
        controller: controller,
        tabs: [
          Tab(text: 'ATK (${state.selectedAttackers.length}/2)'),
          Tab(text: 'DEF (${state.selectedDefenders.length}/2)'),
          Tab(text: 'ACT (${state.selectedActions.length}/6)'),
        ],
      ),
    );
  }
}

class SelectionWrap<T> extends StatelessWidget {
  const SelectionWrap({
    required this.cards,
    required this.selectedIds,
    required this.enabled,
    required this.builder,
    required this.onToggle,
    required this.isDisabled,
    super.key,
  });

  final List<T> cards;
  final List<String> selectedIds;
  final bool enabled;
  final Widget Function(T card, bool selected, bool disabled) builder;
  final ValueChanged<T> onToggle;
  final bool Function(T card) isDisabled;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final card in cards)
            GestureDetector(
              onTap: enabled ? () => onToggle(card) : null,
              child: builder(
                card,
                selectedIds.contains(switch (card) {
                  PlayerCard c => c.id,
                  ActionCard c => c.id,
                  _ => '',
                }),
                isDisabled(card),
              ),
            ),
        ],
      ),
    );
  }
}

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    required this.primaryLabel,
    required this.primaryEnabled,
    required this.primaryOnTap,
    required this.secondaryLabel,
    required this.secondaryOnTap,
    super.key,
  });

  final String primaryLabel;
  final bool primaryEnabled;
  final VoidCallback primaryOnTap;
  final String secondaryLabel;
  final VoidCallback secondaryOnTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Cyber.panel.withValues(alpha: 0.96),
          border: const Border(top: BorderSide(color: Color(0xff1e2538))),
        ),
        child: Row(
          children: [
            Expanded(
              child: CyberCtaButton(
                label: secondaryLabel,
                onPressed: secondaryOnTap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CyberCtaButton(
                label: primaryLabel,
                primary: true,
                onPressed: primaryEnabled ? primaryOnTap : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PitchPainter extends CustomPainter {
  const PitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(16, size.height * 0.26),
      Offset(size.width - 16, size.height * 0.26),
      paint,
    );
    canvas.drawLine(
      Offset(16, size.height * 0.54),
      Offset(size.width - 16, size.height * 0.54),
      paint,
    );
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.54), 44, paint);
    canvas.drawRect(
      Rect.fromLTWH(20, 18, size.width - 40, size.height - 36),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              border: Border.all(color: Cyber.cyan.withValues(alpha: 0.55)),
              gradient: RadialGradient(
                colors: [Cyber.cyan.withValues(alpha: 0.25), Cyber.panel2],
              ),
            ),
            child: Icon(icon, size: 28, color: Cyber.cyan),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Cyber.cyan,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(body, style: const TextStyle(color: Cyber.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CyberPanel extends StatelessWidget {
  const CyberPanel({
    required this.child,
    this.accent = Cyber.cyan,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: CyberClipper(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: Cyber.panelGradient(accent),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class CyberClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const cut = 12.0;
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, cut)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class ScoreboardPanel extends StatelessWidget {
  const ScoreboardPanel({required this.state, this.label, super.key});

  final GameState state;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff070b14), Color(0xff111827), Color(0xff070b14)],
        ),
        border: Border(
          top: BorderSide(color: Cyber.cyan.withValues(alpha: 0.28)),
          bottom: BorderSide(color: Cyber.red.withValues(alpha: 0.32)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _HudIdentity(
              label: '[P1] YOU',
              score: state.playerScore,
              color: Cyber.cyan,
              alignRight: false,
            ),
          ),
          Column(
            children: [
              Text(
                label ?? 'RN ${max(1, state.currentRound)}/4',
                style: const TextStyle(
                  color: Cyber.muted,
                  fontSize: 10,
                  fontFamily: 'Onest',
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '— VS —',
                style: const TextStyle(
                  fontFamily: 'Orbitron',
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Expanded(
            child: _HudIdentity(
              label: 'CPU [E1]',
              score: state.opponentScore,
              color: Cyber.red,
              alignRight: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _HudIdentity extends StatelessWidget {
  const _HudIdentity({
    required this.label,
    required this.score,
    required this.color,
    required this.alignRight,
  });

  final String label;
  final int score;
  final Color color;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: alignRight
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'Onest',
              fontWeight: FontWeight.w900,
              fontSize: 11,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            '$score',
            style: TextStyle(
              color: color,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.w900,
              fontSize: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class CardList<T> extends StatelessWidget {
  const CardList({
    required this.cards,
    required this.selectedIds,
    required this.builder,
    required this.onToggle,
    required this.enabled,
    super.key,
  });

  final List<T> cards;
  final List<String> selectedIds;
  final Widget Function(T card, bool selected) builder;
  final ValueChanged<T> onToggle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final card = cards[index];
        final id = switch (card) {
          PlayerCard c => c.id,
          ActionCard c => c.id,
          _ => '',
        };
        return Opacity(
          opacity: enabled ? 1 : 0.72,
          child: InkWell(
            onTap: enabled ? () => onToggle(card) : null,
            child: builder(card, selectedIds.contains(id)),
          ),
        );
      },
    );
  }
}

enum VisualCardSize { sm, md }

class CyberPlayerCardTile extends StatelessWidget {
  const CyberPlayerCardTile({
    required this.card,
    required this.selected,
    this.disabled = false,
    this.size = VisualCardSize.sm,
    this.onTap,
    super.key,
  });

  final PlayerCard card;
  final bool selected;
  final bool disabled;
  final VisualCardSize size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tier = tierColor(card.tier);
    final small = size == VisualCardSize.sm;
    final width = small ? 96.0 : 128.0;
    final height = small ? 144.0 : 192.0;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.35 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: width,
          height: height,
          decoration: BoxDecoration(
            border: Border.all(color: selected ? Cyber.cyan : tier, width: 2),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff0f1623), Cyber.panel, Cyber.bg2],
            ),
            boxShadow: [
              BoxShadow(
                color: (selected ? Cyber.cyan : tier).withValues(alpha: 0.3),
                blurRadius: selected ? 22 : 12,
              ),
            ],
          ),
          child: ClipPath(
            clipper: CyberClipper(),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: CardStripePainter(color: tier)),
                ),
                Positioned(
                  left: 4,
                  right: 4,
                  top: 4,
                  bottom: height * 0.24,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xfff7f7f4),
                          Colors.white,
                          tier,
                          const Color(0xff111827),
                          Cyber.red,
                        ],
                        stops: const [0, 0.40, 0.54, 0.72, 1],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        card.icon,
                        size: small ? 42 : 64,
                        color: const Color(0xff111827),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: small ? 36 : 44,
                    height: small ? 30 : 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.white, tier]),
                      border: const Border(
                        left: BorderSide(color: Colors.black54, width: 2),
                        bottom: BorderSide(color: Colors.black54, width: 2),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${card.rating}',
                          style: TextStyle(
                            color: Cyber.bg,
                            fontFamily: 'Orbitron',
                            fontSize: small ? 12 : 15,
                            fontWeight: FontWeight.w900,
                            height: 0.9,
                          ),
                        ),
                        const Text(
                          'OVR',
                          style: TextStyle(
                            color: Cyber.bg,
                            fontSize: 5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    color: Colors.black.withValues(alpha: 0.58),
                    child: Text(
                      card.role == PlayerRole.attacker ? 'ATK' : 'DEF',
                      style: TextStyle(
                        color: tier,
                        fontFamily: 'Orbitron',
                        fontSize: small ? 7 : 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 4,
                  right: 4,
                  bottom: height * 0.24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 3,
                    ),
                    color: Colors.black.withValues(alpha: 0.64),
                    child: Text(
                      card.trait,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: small ? 7 : 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: height * 0.24,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xff202836), Color(0xff121824)],
                      ),
                    ),
                    child: Text(
                      card.name,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.w900,
                        fontSize: small ? 9 : 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CyberActionCardTile extends StatelessWidget {
  const CyberActionCardTile({
    required this.card,
    required this.selected,
    this.disabled = false,
    this.size = VisualCardSize.sm,
    this.onTap,
    super.key,
  });

  final ActionCard card;
  final bool selected;
  final bool disabled;
  final VisualCardSize size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = actionColor(card.category);
    final small = size == VisualCardSize.sm;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.3 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: small ? 80 : 96,
          height: small ? 96 : 128,
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? Cyber.cyan
                  : (card.risky ? Cyber.magenta : color),
              width: selected ? 2 : 1.2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withValues(alpha: 0.2), Cyber.panel, Cyber.bg2],
            ),
            boxShadow: [
              BoxShadow(
                color: (selected ? Cyber.cyan : color).withValues(alpha: 0.24),
                blurRadius: selected ? 16 : 8,
              ),
            ],
          ),
          child: ClipPath(
            clipper: CyberClipper(),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    color: color,
                    child: Text(
                      actionCode(card.category),
                      style: const TextStyle(
                        color: Cyber.bg,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    color: Cyber.panel,
                    child: Text(
                      '+${card.power}',
                      style: const TextStyle(
                        color: Cyber.cyan,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 22, 8, 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(card.icon, color: color, size: small ? 20 : 24),
                      Text(
                        card.title.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Orbitron',
                          fontWeight: FontWeight.w900,
                          fontSize: 9,
                        ),
                      ),
                      Text(
                        card.effect,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: color.withValues(alpha: 0.76),
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (card.risky)
                  const Positioned(
                    bottom: 3,
                    left: 3,
                    child: Icon(
                      Icons.warning_amber,
                      color: Cyber.red,
                      size: 13,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CyberChip extends StatelessWidget {
  const CyberChip({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontFamily: 'Onest',
          fontSize: 10,
          fontWeight: FontWeight.w900,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class CardStripePainter extends CustomPainter {
  const CardStripePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.11)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 18) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CardStripePainter oldDelegate) =>
      oldDelegate.color != color;
}

class PlayerCardTile extends StatelessWidget {
  const PlayerCardTile({
    required this.card,
    required this.selected,
    this.onTap,
    super.key,
  });

  final PlayerCard card;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: tierColor(card.tier),
          child: Icon(card.icon, color: Colors.black),
        ),
        title: Text(
          card.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('${card.trait} • ${card.role.name.toUpperCase()}'),
        trailing: Text(
          '${card.rating}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class ActionCardTile extends StatelessWidget {
  const ActionCardTile({
    required this.card,
    required this.selected,
    this.onTap,
    super.key,
  });

  final ActionCard card;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Icon(card.icon)),
        title: Text(
          card.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${card.category.name.toUpperCase()} • ${card.effect}${card.risky ? ' • Risky' : ''}',
        ),
        trailing: Text(
          '+${card.power}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class ChoiceButton extends StatelessWidget {
  const ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? Cyber.cyan.withValues(alpha: 0.18)
            : Cyber.panel,
        foregroundColor: selected ? Cyber.cyan : Cyber.muted,
        side: BorderSide(color: selected ? Cyber.cyan : Cyber.line),
      ),
      child: Text(label),
    );
  }
}

Color tierColor(CardTier tier) => switch (tier) {
  CardTier.silver => const Color(0xffcbd5e1),
  CardTier.gold => const Color(0xfffacc15),
  CardTier.purple => const Color(0xffc084fc),
};

Color actionColor(ActionCategory category) => switch (category) {
  ActionCategory.attack => Cyber.lime,
  ActionCategory.defense => Cyber.cyan,
  ActionCategory.special => Cyber.magenta,
};

String actionCode(ActionCategory category) => switch (category) {
  ActionCategory.attack => 'ATK',
  ActionCategory.defense => 'DEF',
  ActionCategory.special => 'SPC',
};

IconData outcomeIcon(RoundOutcome outcome) => switch (outcome) {
  RoundOutcome.goal => Icons.sports_soccer,
  RoundOutcome.saved => Icons.pan_tool,
  RoundOutcome.blocked => Icons.block,
  RoundOutcome.missed => Icons.close,
  RoundOutcome.foul => Icons.flag,
  RoundOutcome.redCard => Icons.style,
};

String outcomeLabel(RoundOutcome outcome) => switch (outcome) {
  RoundOutcome.goal => 'Goal',
  RoundOutcome.saved => 'Saved',
  RoundOutcome.blocked => 'Blocked',
  RoundOutcome.missed => 'Missed',
  RoundOutcome.foul => 'Foul',
  RoundOutcome.redCard => 'Red Card',
};
