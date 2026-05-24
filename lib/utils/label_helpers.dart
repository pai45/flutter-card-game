import 'package:flutter/material.dart';

import '../config/enums.dart';
import '../config/theme.dart';
import '../models/cards.dart';

String playerRoleLabel(PlayerCard card) => switch (card.role) {
  PlayerRole.attacker => 'ATK',
  PlayerRole.defender => 'DEF',
  PlayerRole.goalkeeper => 'GK',
};

Color tierColor(CardTier tier) => switch (tier) {
  CardTier.bronze => const Color(0xffcd7f32),
  CardTier.silver => const Color(0xffcbd5e1),
  CardTier.gold => const Color(0xfffacc15),
  CardTier.platinum => const Color(0xff67e8f9),
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
