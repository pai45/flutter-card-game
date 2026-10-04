import 'match.dart';
import 'pitch_duel_rules.dart';

enum PitchMasteryKind { linkedPlays, doubleMatch, linkedRoles }

typedef PitchMasteryPlay = ({bool attacking, PowerBreakdown power});

/// A small rotating skill goal, derived from real match history. It changes no
/// rewards or resolution rules. Optional goal identity in history keeps the
/// cycle moving when old matches are trimmed; legacy records remain readable.
class PitchMasteryGoal {
  const PitchMasteryGoal(this.kind);
  final PitchMasteryKind kind;
  int get target => kind == PitchMasteryKind.doubleMatch ? 1 : 2;
  String get title => switch (kind) {
    PitchMasteryKind.linkedPlays => 'LINK TWO PLAYS',
    PitchMasteryKind.doubleMatch => 'BUILD A +10 COMBO',
    PitchMasteryKind.linkedRoles => 'LINK BOTH ROLES',
  };
  String get description => switch (kind) {
    PitchMasteryKind.linkedPlays =>
      'Use a matching player or scenario in two rounds.',
    PitchMasteryKind.doubleMatch =>
      'Match the player and scenario in one play.',
    PitchMasteryKind.linkedRoles => 'Find a combination in attack and defense.',
  };
  int progress(Iterable<PitchMasteryPlay> plays) {
    if (kind == PitchMasteryKind.linkedRoles) {
      return plays
          .where((p) => p.power.combo > 0)
          .map((p) => p.attacking)
          .toSet()
          .length;
    }
    return plays
        .where(
          (p) => kind == PitchMasteryKind.doubleMatch
              ? p.power.combo == 10
              : p.power.combo > 0,
        )
        .length
        .clamp(0, target);
  }
}

List<MatchHistoryEntry> _realMatches(List<MatchHistoryEntry> history) =>
    history.where((m) => m.mode == 'match' && !m.isDemo).toList();

PitchMasteryGoal pitchMasteryGoal(List<MatchHistoryEntry> history) {
  final matches = _realMatches(history);
  final last = matches.firstOrNull?.pitchMasteryIndex;
  return PitchMasteryGoal(
    PitchMasteryKind.values[((last == null ? matches.length : last + 1) %
        PitchMasteryKind.values.length)],
  );
}

PitchMasteryGoal pitchCompletedMasteryGoal(List<MatchHistoryEntry> history) {
  final matches = _realMatches(history);
  final index =
      matches.firstOrNull?.pitchMasteryIndex ??
      (matches.isEmpty ? 0 : matches.length - 1);
  return PitchMasteryGoal(
    PitchMasteryKind.values[index % PitchMasteryKind.values.length],
  );
}

Iterable<PitchMasteryPlay> pitchPlayerPlays(
  Iterable<RoundResult> rounds,
) sync* {
  for (final round in rounds) {
    final power = round.playerAttacking
        ? round.attackBreakdown
        : round.defenseBreakdown;
    if (power != null) yield (attacking: round.playerAttacking, power: power);
  }
}

int pitchBestLinkedPlays(List<MatchHistoryEntry> history) {
  var best = 0;
  for (final match in history.where((m) => m.mode == 'match' && !m.isDemo)) {
    final linked = match.rounds
        .where((r) => (r.playerBreakdown?.combo ?? 0) > 0)
        .length;
    if (linked > best) best = linked;
  }
  return best;
}
