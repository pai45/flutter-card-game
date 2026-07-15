import 'achievement.dart';
import 'avatar_frame_option.dart';
import 'progression.dart';

/// A deterministic, fabricated profile for a leaderboard rival. There is no
/// backend, so a rival is "scouted" from the only real seeds we have — their
/// display name and canonical XP — producing the same dossier every time and
/// believable numbers that scale up with XP. Pure (no bloc/context) so it's
/// trivially testable and reusable by the dossier screen and friends roster.
class RivalDossier {
  const RivalDossier({
    required this.name,
    required this.progression,
    required this.frame,
    required this.matchesPlayed,
    required this.matchWins,
    required this.draws,
    required this.winRate,
    required this.bestStreak,
    required this.cleanSheets,
    required this.shootoutWins,
    required this.predictionsMade,
    required this.correctPredictions,
    required this.predictionAccuracy,
    required this.picksPlaced,
    required this.picksWon,
    required this.activePicks,
    required this.pickWinRate,
    required this.ownedCards,
    required this.platinumOwned,
  });

  /// Builds a rival from their leaderboard seed. [pro] (the PRO badge) gates the
  /// equipped avatar frame so the cosmetic reads as earned.
  factory RivalDossier.fromSeed({
    required String name,
    required int xp,
    bool pro = false,
  }) {
    final rng = _SeededRng(name);
    // Strength in 0..~0.95 from XP (board ranges ~1980..3910). Drives the bias
    // so higher-ranked rivals genuinely look stronger.
    final strength = (((xp - 1900) / 2200).clamp(0.0, 0.95)).toDouble();

    final matchesPlayed = 24 + (strength * 90).round() + rng.nextInt(16);
    final winRate = (44 + (strength * 30).round() + rng.nextInt(11) - 5).clamp(
      32,
      84,
    );
    final matchWins = (matchesPlayed * winRate / 100).round();
    final draws = (matchesPlayed * (0.10 + rng.nextInt(8) / 100)).round();
    final bestStreak = 2 + (strength * 6).round() + rng.nextInt(3);
    final cleanSheets = (matchWins * (0.25 + rng.nextInt(15) / 100)).round();
    final shootoutWins = 1 + (strength * 5).round() + rng.nextInt(3);

    final predictionsMade = 14 + (strength * 60).round() + rng.nextInt(18);
    final predictionAccuracy =
        (40 + (strength * 34).round() + rng.nextInt(11) - 5).clamp(28, 88);
    final correctPredictions = (predictionsMade * predictionAccuracy / 100)
        .round();

    final picksPlaced = 8 + (strength * 36).round() + rng.nextInt(12);
    final pickWinRate = (38 + (strength * 30).round() + rng.nextInt(11) - 5)
        .clamp(28, 82);
    final picksWon = (picksPlaced * pickWinRate / 100).round();
    final activePicks = rng.nextInt(6);

    final ownedCards = 14 + (strength * 70).round() + rng.nextInt(20);
    final platinumOwned = strength > 0.6 ? rng.nextInt(4) : rng.nextInt(2);

    final frame = pro
        ? avatarFrameOptions[rng.nextInt(avatarFrameOptions.length)]
        : null;

    return RivalDossier(
      name: name,
      progression: PlayerProgression(totalXP: xp),
      frame: frame,
      matchesPlayed: matchesPlayed,
      matchWins: matchWins,
      draws: draws,
      winRate: winRate,
      bestStreak: bestStreak,
      cleanSheets: cleanSheets,
      shootoutWins: shootoutWins,
      predictionsMade: predictionsMade,
      correctPredictions: correctPredictions,
      predictionAccuracy: predictionAccuracy,
      picksPlaced: picksPlaced,
      picksWon: picksWon,
      activePicks: activePicks,
      pickWinRate: pickWinRate,
      ownedCards: ownedCards,
      platinumOwned: platinumOwned,
    );
  }

  final String name;
  final PlayerProgression progression;
  final AvatarFrameOption? frame;
  final int matchesPlayed;
  final int matchWins;
  final int draws;
  final int winRate;
  final int bestStreak;
  final int cleanSheets;
  final int shootoutWins;
  final int predictionsMade;
  final int correctPredictions;
  final int predictionAccuracy;
  final int picksPlaced;
  final int picksWon;
  final int activePicks;
  final int pickWinRate;
  final int ownedCards;
  final int platinumOwned;

  int get level => progression.playerLevel;

  /// The achievement snapshot the catalogue measures the rival against, so the
  /// dossier lights the same badges the real profile would. A rival's wallet is
  /// private, so [AchievementStats.coins] is 0.
  AchievementStats get achievementStats => AchievementStats(
    level: level,
    totalXP: progression.totalXP,
    matchesPlayed: matchesPlayed,
    matchWins: matchWins,
    bestMatchStreak: bestStreak,
    cleanSheets: cleanSheets,
    shootoutWins: shootoutWins,
    // Rivals haven't hit the court yet — no fabricated hoop record.
    basketballWins: 0,
    tennisAchievements: const <String>{},
    predictionsMade: predictionsMade,
    correctPredictions: correctPredictions,
    picksPlaced: picksPlaced,
    picksWon: picksWon,
    pickStreak: bestStreak,
    pickProfit: (picksWon - (picksPlaced - picksWon)) * 20,
    ownedCards: ownedCards,
    platinumOwned: platinumOwned,
    coins: 0,
  );
}

/// A tiny deterministic RNG seeded from a string — the same name always yields
/// the same sequence (an xorshift over a 31-bit hash of the name).
class _SeededRng {
  _SeededRng(String seed) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    _state = hash == 0 ? 0x1a2b3c4d : hash;
  }

  late int _state;

  int nextInt(int max) {
    if (max <= 0) return 0;
    _state ^= (_state << 13) & 0x7fffffff;
    _state ^= _state >> 17;
    _state ^= (_state << 5) & 0x7fffffff;
    return (_state & 0x7fffffff) % max;
  }
}
