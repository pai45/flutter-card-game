import 'package:flutter/material.dart';

import '../config/enums.dart';
import '../config/theme.dart';
import '../models/cards.dart';

String playerRoleLabel(PlayerCard card) => switch (card.role) {
  PlayerRole.attacker => 'ATK',
  PlayerRole.defender => 'DEF',
  PlayerRole.goalkeeper => 'GK',
  PlayerRole.batsman => 'BAT',
  PlayerRole.bowler => 'BOWL',
  PlayerRole.basketballGuard => 'G',
  PlayerRole.basketballWing => 'W',
  PlayerRole.basketballBig => 'BIG',
  PlayerRole.tennisSingles => 'SGL',
};

Color tierColor(CardTier tier) => switch (tier) {
  CardTier.bronze => const Color(0xffcd7f32),
  CardTier.silver => const Color(0xffcbd5e1),
  CardTier.gold => const Color(0xfffacc15),
  CardTier.platinum => const Color(0xff67e8f9),
};

/// Attack/defend lane accent used across play and round-result UI.
Color roleAccent(bool attacking) =>
    attacking ? Cyber.cyan : const Color(0xFFC084FC);

Color outcomeColor(RoundOutcome outcome) => switch (outcome) {
  RoundOutcome.goal => Cyber.success,
  RoundOutcome.saved => Cyber.cyan,
  RoundOutcome.blocked => Cyber.violet,
  RoundOutcome.missed => Cyber.muted,
  RoundOutcome.foul => Cyber.amber,
  RoundOutcome.redCard => Cyber.danger,
};

Color actionColor(ActionCategory category) => switch (category) {
  ActionCategory.attack => Cyber.lime,
  ActionCategory.defense => Cyber.violet,
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

/// Short, perspective-aware flavour caption shown under the round verdict.
///
/// [playerAttacking] flips the voice between the player's and the CPU's point of
/// view so a goal reads "you find the net" vs "CPU buries it". Kept deterministic
/// so widget/golden tests stay stable.
String outcomeNarration(
  RoundOutcome outcome, {
  required bool playerAttacking,
}) => switch (outcome) {
  RoundOutcome.goal =>
    playerAttacking
        ? 'Top corner — you find the net!'
        : 'CPU buries it past your keeper.',
  RoundOutcome.saved =>
    playerAttacking
        ? 'Denied — the keeper gets a strong hand to it.'
        : 'Your keeper stands tall and saves!',
  RoundOutcome.blocked =>
    playerAttacking
        ? 'Wall holds — the shot is smothered.'
        : 'You throw a body in the way — blocked!',
  RoundOutcome.missed =>
    playerAttacking
        ? 'Dragged wide — the chance is gone.'
        : 'CPU skews it wide — let off!',
  RoundOutcome.foul => 'Cynical challenge — the whistle blows.',
  RoundOutcome.redCard => 'Straight red — down to ten!',
};
