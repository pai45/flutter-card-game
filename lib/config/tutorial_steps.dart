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
