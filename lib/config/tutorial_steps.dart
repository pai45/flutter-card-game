import 'package:flutter/material.dart';

import 'theme.dart';

const tutorialKeys = [
  'home',
  'deck-builder',
  'toss',
  'scenario',
  'play',
  'shot-meter',
  'round-result',
  'final',
  'shootout',
];

class TutorialStepData {
  const TutorialStepData({
    required this.title,
    required this.body,
    this.icon = Icons.info_outline,
    this.accent = Cyber.cyan,
    this.hint,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color accent;
  final String? hint;
}

const homeTutorialSteps = [
  TutorialStepData(
    title: 'Welcome to PITCH/DUEL',
    body:
        'A fast 4-round card duel. Stats, scenarios and a touch of luck decide each round.',
    icon: Icons.sports_soccer,
    accent: Cyber.cyan,
    hint: '4 ROUNDS  ·  1 MOVE EACH',
  ),
  TutorialStepData(
    title: "You're ready to play",
    body:
        'Your starter deck is set. Tap PLAY MATCH to jump in, or open HOW TO PLAY anytime for the full guide.',
    icon: Icons.play_arrow,
    accent: Cyber.lime,
    hint: 'PLAY NOW  ·  HOW TO PLAY FOR DETAILS',
  ),
];

const deckTutorialSteps = [
  TutorialStepData(
    title: 'Build Your Squad',
    body:
        'Pick 2 attackers, 2 defenders, and 6 action cards. Tap players to add/remove. Lock formation when ready.',
    icon: Icons.style,
    hint: '2 ATK  +  2 DEF  +  6 ACTION = READY',
  ),
  TutorialStepData(
    title: 'Edit & Play',
    body:
        'Tap SAVE to lock the deck. Tap PLAY MATCH when ready. Tap EDIT later to adjust.',
    icon: Icons.play_arrow,
    hint: 'SAVE → PLAY MATCH',
  ),
];

const tossTutorialSteps = [
  TutorialStepData(
    title: 'Win the Toss',
    body:
        'Call HEADS or TAILS to win the toss. The call only decides who wins — '
        'win it and YOU choose to ATTACK or DEFEND for round 1.',
    icon: Icons.toll,
    hint: 'CALL TO WIN  →  THEN CHOOSE ROLE',
  ),
  TutorialStepData(
    title: 'Then Roles Switch',
    body:
        'This is the only toss. After round 1, roles automatically switch each '
        'round: attack → defense → attack.',
    icon: Icons.swap_horiz,
    hint: 'R1: YOUR CHOICE  ·  R2–R4: AUTO SWITCH',
  ),
];

const scenarioTutorialSteps = [
  TutorialStepData(
    title: 'Scenario & Bonus Stats',
    body:
        'Each round gets a scenario (counter attack, set piece, etc). Stats show ATK/DEF bonuses this round.',
    hint: 'SCENARIO  ·  ATK BONUS  ·  DEF BONUS',
  ),
  TutorialStepData(
    title: 'Your Role This Round',
    body:
        'The banner shows ATTACKER or DEFENDER. Pick cards that match your role.',
    hint: 'ATTACK ↔ DEFENSE (alternates each round)',
  ),
];

const playTutorialSteps = [
  TutorialStepData(
    title: 'Pick Player + Action',
    body:
        'Tap a player (OVR = base power). Then pick 1 action card matching your role. Tap yellow actions for risky high-reward moves.',
    icon: Icons.touch_app,
    hint: 'PLAYER  +  ACTION  →  TAP TO LOCK',
  ),
  TutorialStepData(
    title: 'Power Preview & Luck',
    body:
        'EST shows your total power (player + action + bonus). CPU power is hidden. A luck roll decides close rounds.',
    icon: Icons.stars,
    hint: 'HIGHER POWER WINS  ·  LUCK CAN FLIP IT',
  ),
];

const resultTutorialSteps = [
  TutorialStepData(
    title: 'Round Result',
    body:
        'The outcome shows: GOAL, SAVED, MISSED, FOUL, or RED CARD. Used players appear marked and are locked for the match.',
    icon: Icons.sports_soccer,
    hint: 'GOAL ✓  ·  SAVED ✓  ·  MISSED ✗  ·  FOUL ⚠️  ·  RED CARD 🔴',
  ),
  TutorialStepData(
    title: 'Next Round Begins',
    body:
        'Tap NEXT ROUND to continue. Roles automatically flip: attack ↔ defense. Repeat for 4 rounds.',
    icon: Icons.arrow_forward,
    hint: 'ROUND 2 → ROLE SWITCHES → REPEAT 3 MORE TIMES',
  ),
];

const shootoutTutorialSteps = [
  TutorialStepData(
    title: 'Penalty Shootout',
    body:
        'Your five squad players each take one kick — ratings tip the duel. Tap a goal zone to aim, then SHOOT. On CPU kicks, pick where your keeper dives.',
    icon: Icons.sports_soccer,
    hint: '5 KICKS EACH  ·  SHOOT & DIVE',
  ),
  TutorialStepData(
    title: 'Sudden Death Rules',
    body:
        'Still level after 5 kicks each? Sudden death cycles your lineup: next unanswered goal wins.',
    icon: Icons.whatshot,
    hint: 'BEST OF 5 → SUDDEN DEATH → NEXT GOAL WINS',
  ),
];

const finalTutorialSteps = [
  TutorialStepData(
    title: 'Final Score & MVP',
    body:
        'Final scoreline appears with MVP (your goal scorer). A level score after 4 rounds is a draw.',
    icon: Icons.emoji_events,
    hint: 'FINAL SCORE  ·  MVP AWARDED',
  ),
  TutorialStepData(
    title: 'What\'s Next?',
    body:
        'REMATCH plays again with the same deck. HOME exits to menu. DECK tunes your squad.',
    icon: Icons.home,
    hint: 'REMATCH  ·  HOME  ·  DECK (TAP ICON)',
  ),
];
