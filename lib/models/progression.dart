import 'dart:math';

import 'cards.dart';

// Cumulative XP required to reach level L. L1 = 0, L2 = 100, L3 = 300.
const int _kLevelXp = 50;

int xpToReach(int level) => _kLevelXp * level * (level - 1);

int levelFromXp(int totalXp) {
  final xp = max(0, totalXp);
  final level =
      ((_kLevelXp + sqrt(_kLevelXp * _kLevelXp + 4 * _kLevelXp * xp)) /
              (2 * _kLevelXp))
          .floor();
  return max(1, level);
}

class LevelProgress {
  const LevelProgress({
    required this.level,
    required this.intoLevel,
    required this.levelSpan,
    required this.toNextLevel,
    required this.pct,
  });

  final int level;
  final int intoLevel;
  final int levelSpan;
  final int toNextLevel;
  final double pct;
}

LevelProgress levelProgress(int totalXp) {
  final xp = max(0, totalXp);
  final level = levelFromXp(xp);
  final start = xpToReach(level);
  final next = xpToReach(level + 1);
  final span = next - start;
  final into = xp - start;
  return LevelProgress(
    level: level,
    intoLevel: into,
    levelSpan: span,
    toNextLevel: next - xp,
    pct: span == 0 ? 0 : (into / span).clamp(0.0, 1.0),
  );
}

int playerCardXp(PlayerCard card) => card.rating;

int actionCardXp(ActionCard card) => max(15, 30 + card.power);

const Duration kDailyDropCooldown = Duration(hours: 24);

class DailyDropStatus {
  const DailyDropStatus(this.ready, this.remaining);

  final bool ready;
  final Duration remaining;
}

DailyDropStatus dailyDropStatus(DateTime? lastClaimedAt, [DateTime? now]) {
  if (lastClaimedAt == null) return const DailyDropStatus(true, Duration.zero);
  final elapsed = (now ?? DateTime.now()).difference(lastClaimedAt);
  final remaining = kDailyDropCooldown - elapsed;
  if (remaining <= Duration.zero) {
    return const DailyDropStatus(true, Duration.zero);
  }
  return DailyDropStatus(false, remaining);
}

String formatCountdown(Duration duration) {
  final totalMinutes =
      duration.inMinutes + (duration.inSeconds % 60 > 0 ? 1 : 0);
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return hours <= 0 ? '${minutes}m' : '${hours}h ${minutes}m';
}

int coinsForResult(String result) {
  final normalized = result.toLowerCase();
  if (normalized == 'victory' || normalized == 'win') return 50;
  if (normalized == 'draw') return 25;
  return 10;
}

// Calculate XP delta for a match result.
// Wins get more XP scaled by goal margin + shutout bonus, capped at +25.
// Losses lose XP scaled by goal conceded margin, floored at -15.
// Draws (level after 4 rounds) award a small flat +4.
int calculateMatchXP({
  required String resultLabel,
  required int playerScore,
  required int opponentScore,
}) {
  if (resultLabel == 'Draw') return 4;
  if (resultLabel == 'Victory') {
    final diff = playerScore - opponentScore;
    final shutout = opponentScore == 0 ? 5 : 0;
    return min(25, 10 + diff * 3 + shutout);
  }
  // Defeat
  return max(-15, -(5 + (opponentScore - playerScore) * 2));
}

// XP for the standalone Penalty Shootout mode — a quicker mode, so smaller
// stakes than a full match: +8/+10/+12 by winning margin, nothing on a loss.
int calculateShootoutXP({required bool won, required int margin}) =>
    won ? min(12, 8 + (margin - 1) * 2) : 0;

int shootoutCoins(bool won) => won ? 20 : 5;

// XP for the 5v5 Football Chess mode — a full 2-minute tactical match, so it
// pays a little more than the quick shootout. A win scales with the goal margin
// (+14 base, +3 per extra goal, capped at +26); a draw is a small +6; a loss
// still earns a tiny +2 for finishing. XP only — this mode never pays coins.
int calculateFootballChessXP({
  required bool won,
  required bool draw,
  required int goalMargin,
}) {
  if (won) return min(26, 14 + (goalMargin - 1).clamp(0, 99) * 3);
  if (draw) return 6;
  return 2;
}

// Longer Grand Prix race distances multiply the position payout — a 5-lap
// endurance run is worth the grind. Shown on the lobby's distance selector so
// keep the lobby chip and the payout reading from this one function.
int grandPrixXpMultiplier(int laps) => switch (laps) {
  >= 5 => 3,
  >= 3 => 2,
  _ => 1,
};

// XP for Grand Prix Dash — an arcade race, so it pays by finishing position:
// a one-lap win matches Football Chess's ceiling, a backmarker finish still
// earns a little, and longer distances multiply the position payout (see
// [grandPrixXpMultiplier]). A new personal best on the circuit+distance adds
// +3. XP only — racing never subtracts XP and never pays coins.
int calculateGrandPrixXP(int position, {bool personalBest = false, int laps = 1}) {
  final base = switch (position) {
    1 => 26,
    2 => 22,
    3 => 18,
    <= 6 => 12,
    <= 10 => 8,
    _ => 4,
  };
  return base * grandPrixXpMultiplier(laps) + (personalBest ? 3 : 0);
}

// XP for Hoop Duel — a two-half basketball duel on the same scale as the other
// arcade modes: a win scales with the margin (+16 base, +2 per point of
// margin, capped at Football Chess's +26 ceiling; +2 more for surviving
// overtime), a loss still earns a little (+6 if it forced overtime). XP only —
// the court never pays coins.
int calculateBasketballXP({
  required bool won,
  required int margin,
  required bool overtime,
}) {
  if (!won) return overtime ? 6 : 4;
  final base = min(26, 16 + margin * 2);
  return overtime ? min(26, base + 2) : base;
}

/// Per-mode / meta XP tracks. Profile total level uses [levelFromXp] on the
/// sum of all track XP — the same curve as each individual track.
enum ProgressTrack {
  pitchDuel,
  shootout,
  footballChess,
  quiz,
  bingo,
  guessPlayer,
  finalOver,
  hoopDuel,
  grandPrix,
  tennis,
  prediction,
  cardsMeta,
}

extension ProgressTrackX on ProgressTrack {
  String get shortLabel => switch (this) {
    ProgressTrack.pitchDuel => 'PITCH',
    ProgressTrack.shootout => 'SHOOTOUT',
    ProgressTrack.footballChess => 'CHESS',
    ProgressTrack.quiz => 'QUIZ',
    ProgressTrack.bingo => 'BINGO',
    ProgressTrack.guessPlayer => 'GUESS',
    ProgressTrack.finalOver => 'FINAL OVER',
    ProgressTrack.hoopDuel => 'HOOP',
    ProgressTrack.grandPrix => 'GP',
    ProgressTrack.tennis => 'TENNIS',
    ProgressTrack.prediction => 'PREDICT',
    ProgressTrack.cardsMeta => 'CARDS',
  };

  String get displayLabel => switch (this) {
    ProgressTrack.pitchDuel => 'PITCH DUEL',
    ProgressTrack.shootout => 'PENALTY SHOOTOUT',
    ProgressTrack.footballChess => 'FOOTBALL CHESS',
    ProgressTrack.quiz => 'QUIZ',
    ProgressTrack.bingo => 'FOOTBALL BINGO',
    ProgressTrack.guessPlayer => 'GUESS PLAYER',
    ProgressTrack.finalOver => 'FINAL OVER',
    ProgressTrack.hoopDuel => 'HOOP DUEL',
    ProgressTrack.grandPrix => 'GRAND PRIX',
    ProgressTrack.tennis => 'TENNIS RALLY',
    ProgressTrack.prediction => 'PREDICTIONS',
    ProgressTrack.cardsMeta => 'CARDS / META',
  };
}

Map<ProgressTrack, int> _normalizeXpByTrack(Map<ProgressTrack, int> raw) {
  final out = <ProgressTrack, int>{};
  for (final track in ProgressTrack.values) {
    final xp = raw[track] ?? 0;
    if (xp > 0) out[track] = xp;
  }
  return Map.unmodifiable(out);
}

Map<ProgressTrack, int> _xpByTrackFromJson(Map<String, dynamic> json) {
  final raw = json['xpByTrack'];
  if (raw is! Map) return const {};
  final out = <ProgressTrack, int>{};
  for (final entry in raw.entries) {
    final name = entry.key.toString();
    ProgressTrack? track;
    for (final value in ProgressTrack.values) {
      if (value.name == name) {
        track = value;
        break;
      }
    }
    if (track == null) continue;
    final xp = entry.value;
    final asInt = xp is int ? xp : int.tryParse(xp.toString()) ?? 0;
    if (asInt > 0) out[track] = asInt;
  }
  return _normalizeXpByTrack(out);
}

class PlayerProgression {
  const PlayerProgression._(this.xpByTrack);

  /// Test / rival helper: places [totalXP] on Cards/Meta so aggregate level
  /// matches the legacy single-pool value.
  factory PlayerProgression({int totalXP = 0, Map<ProgressTrack, int>? xpByTrack}) {
    if (xpByTrack != null) {
      return PlayerProgression._(_normalizeXpByTrack(xpByTrack));
    }
    if (totalXP <= 0) return PlayerProgression.initial();
    return PlayerProgression._(
      _normalizeXpByTrack({ProgressTrack.cardsMeta: totalXP}),
    );
  }

  factory PlayerProgression.initial() => const PlayerProgression._({});

  factory PlayerProgression.fromJson(Map<String, dynamic> json) {
    if (json['xpByTrack'] is Map) {
      return PlayerProgression._(_xpByTrackFromJson(json));
    }
    // Legacy single-pool blob — caller should migrate via ledger when possible.
    final legacyTotal = json['totalXP'] as int? ?? 0;
    if (legacyTotal <= 0) return PlayerProgression.initial();
    return PlayerProgression._(
      _normalizeXpByTrack({ProgressTrack.cardsMeta: legacyTotal}),
    );
  }

  /// True when JSON was the pre-track `{totalXP}` shape (no `xpByTrack` key).
  static bool jsonIsLegacy(Map<String, dynamic> json) =>
      json['xpByTrack'] is! Map;

  final Map<ProgressTrack, int> xpByTrack;

  int xpFor(ProgressTrack track) => xpByTrack[track] ?? 0;

  int levelFor(ProgressTrack track) => levelFromXp(xpFor(track));

  LevelProgress progressFor(ProgressTrack track) =>
      levelProgress(xpFor(track));

  int get totalXP => xpByTrack.values.fold<int>(0, (sum, xp) => sum + xp);

  int get playerLevel => levelFromXp(totalXP);
  int get xpIntoLevel => levelProgress(totalXP).intoLevel;
  int get xpToNextLevel => levelProgress(totalXP).levelSpan;
  int get xpRemainingToNextLevel => levelProgress(totalXP).toNextLevel;

  /// Tracks with any XP, stable enum order — for mastery UI.
  List<ProgressTrack> get earnedTracks => [
    for (final track in ProgressTrack.values)
      if (xpFor(track) > 0) track,
  ];

  Map<String, dynamic> toJson() => {
    'xpByTrack': {
      for (final track in ProgressTrack.values)
        if (xpFor(track) > 0) track.name: xpFor(track),
    },
    // Keep totalXP for older readers / debugging; source of truth is xpByTrack.
    'totalXP': totalXP,
  };

  /// Apply XP to one track. Returns levels crossed on the **total** curve when
  /// any, otherwise levels crossed on the track (for celebration).
  ({
    PlayerProgression updated,
    List<int> levelsGained,
    List<int> trackLevelsGained,
    List<int> totalLevelsGained,
    ProgressTrack track,
  })
  applyXP(int delta, ProgressTrack track) {
    final oldTrackXp = xpFor(track);
    final oldTrackLevel = levelFromXp(oldTrackXp);
    final oldTotalLevel = playerLevel;
    final newTrackXp = max(0, oldTrackXp + delta);
    final next = Map<ProgressTrack, int>.from(xpByTrack);
    if (newTrackXp > 0) {
      next[track] = newTrackXp;
    } else {
      next.remove(track);
    }
    final updated = PlayerProgression._(_normalizeXpByTrack(next));
    final newTrackLevel = updated.levelFor(track);
    final newTotalLevel = updated.playerLevel;
    final trackLevelsGained = List<int>.generate(
      max(0, newTrackLevel - oldTrackLevel),
      (i) => oldTrackLevel + i + 1,
    );
    final totalLevelsGained = List<int>.generate(
      max(0, newTotalLevel - oldTotalLevel),
      (i) => oldTotalLevel + i + 1,
    );
    final levelsGained = totalLevelsGained.isNotEmpty
        ? totalLevelsGained
        : trackLevelsGained;

    return (
      updated: updated,
      levelsGained: levelsGained,
      trackLevelsGained: trackLevelsGained,
      totalLevelsGained: totalLevelsGained,
      track: track,
    );
  }
}

class OpponentDeck {
  const OpponentDeck({
    required this.attackers,
    required this.defenders,
    required this.actions,
    required this.level,
  });

  final List<PlayerCard> attackers;
  final List<PlayerCard> defenders;
  final List<ActionCard> actions;
  final int level;
}

int targetRatingForLevel(int level) => min(95, 66 + level * 2);

double cpuSmartness(int level) => min(1.0, level / 12);

List<PlayerCard> _variedNearestByRating(
  List<PlayerCard> pool,
  int target,
  int count,
  Random random,
) {
  final sorted = [...pool]
    ..sort(
      (a, b) => (a.rating - target).abs().compareTo((b.rating - target).abs()),
    );
  final windowSize = min(pool.length, max(count * 8, 12));
  final window = sorted.take(windowSize).toList()..shuffle(random);
  return window.take(count).toList();
}

OpponentDeck generateOpponentDeck(
  int level,
  List<PlayerCard> attackerPool,
  List<PlayerCard> defenderPool,
  List<ActionCard> actionPool, {
  Random? random,
}) {
  final rng = random ?? Random();
  final target = targetRatingForLevel(level);
  final opponentAttackers = _variedNearestByRating(
    attackerPool,
    target,
    2,
    rng,
  );
  final opponentDefenders = _variedNearestByRating(
    defenderPool,
    target,
    2,
    rng,
  );
  final smartness = cpuSmartness(level);
  final byPower = [...actionPool]..sort((a, b) => b.power.compareTo(a.power));
  final remaining = [...actionPool];
  final picks = <ActionCard>[];

  for (var i = 0; i < 6 && remaining.isNotEmpty; i++) {
    final card = rng.nextDouble() < smartness
        ? byPower.firstWhere(remaining.contains, orElse: () => remaining.first)
        : remaining[rng.nextInt(remaining.length)];
    picks.add(card);
    remaining.remove(card);
  }

  return OpponentDeck(
    attackers: opponentAttackers,
    defenders: opponentDefenders,
    actions: picks,
    level: level,
  );
}

class ShootoutOpponent {
  const ShootoutOpponent({required this.shooters, required this.keeper});

  /// Kick order: ATK, ATK, DEF, DEF, GK — the keeper steps up last.
  final List<PlayerCard> shooters;
  final PlayerCard keeper;
}

ShootoutOpponent generateShootoutOpponent(
  int level,
  List<PlayerCard> attackerPool,
  List<PlayerCard> defenderPool,
  List<PlayerCard> keeperPool, {
  Random? random,
}) {
  final rng = random ?? Random();
  final target = targetRatingForLevel(level);
  final cpuAttackers = _variedNearestByRating(attackerPool, target, 2, rng);
  final cpuDefenders = _variedNearestByRating(defenderPool, target, 2, rng);
  final keeper = _variedNearestByRating(keeperPool, target, 1, rng).first;
  return ShootoutOpponent(
    shooters: [...cpuAttackers, ...cpuDefenders, keeper],
    keeper: keeper,
  );
}

ActionCard chooseOpponentAction(
  List<ActionCard> available,
  int level, {
  Random? random,
}) {
  final rng = random ?? Random();
  if (available.length == 1 || rng.nextDouble() > cpuSmartness(level)) {
    return available[rng.nextInt(available.length)];
  }
  int score(ActionCard card) => card.power - (card.risky ? 4 : 0);
  return ([...available]..sort((a, b) => score(b).compareTo(score(a)))).first;
}

PlayerCard chooseOpponentPlayer(
  List<PlayerCard> available,
  int level, {
  Random? random,
}) {
  final rng = random ?? Random();
  if (available.length == 1 || rng.nextDouble() > cpuSmartness(level)) {
    return available[rng.nextInt(available.length)];
  }
  return ([...available]..sort((a, b) => b.rating.compareTo(a.rating))).first;
}
