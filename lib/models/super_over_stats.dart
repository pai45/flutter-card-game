import 'super_over.dart';

class SuperOverStats {
  const SuperOverStats({
    this.highScore = 0,
    this.chaseWins = 0,
    this.chaseLosses = 0,
    this.totalSixes = 0,
    this.totalRuns = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.lastJersey = CricketJersey.mumbai,
  });

  final int highScore;
  final int chaseWins;
  final int chaseLosses;
  final int totalSixes;
  final int totalRuns;
  final int currentStreak;
  final int bestStreak;
  final CricketJersey lastJersey;

  factory SuperOverStats.fromJson(Map<String, dynamic> json) => SuperOverStats(
        highScore: json['highScore'] as int? ?? 0,
        chaseWins: json['chaseWins'] as int? ?? 0,
        chaseLosses: json['chaseLosses'] as int? ?? 0,
        totalSixes: json['totalSixes'] as int? ?? 0,
        totalRuns: json['totalRuns'] as int? ?? 0,
        currentStreak: json['currentStreak'] as int? ?? 0,
        bestStreak: json['bestStreak'] as int? ?? 0,
        lastJersey: cricketJerseyFromName(json['lastJersey'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'highScore': highScore,
        'chaseWins': chaseWins,
        'chaseLosses': chaseLosses,
        'totalSixes': totalSixes,
        'totalRuns': totalRuns,
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'lastJersey': lastJersey.name,
      };

  SuperOverStats copyWith({
    int? highScore,
    int? chaseWins,
    int? chaseLosses,
    int? totalSixes,
    int? totalRuns,
    int? currentStreak,
    int? bestStreak,
    CricketJersey? lastJersey,
  }) {
    return SuperOverStats(
      highScore: highScore ?? this.highScore,
      chaseWins: chaseWins ?? this.chaseWins,
      chaseLosses: chaseLosses ?? this.chaseLosses,
      totalSixes: totalSixes ?? this.totalSixes,
      totalRuns: totalRuns ?? this.totalRuns,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      lastJersey: lastJersey ?? this.lastJersey,
    );
  }
}
