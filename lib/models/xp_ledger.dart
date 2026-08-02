import 'dart:math';

import 'progression.dart';

enum XpTransactionType { earn, loss, openingBalance }

enum XpTransactionSource {
  openingBalance,
  match,
  shootout,
  prediction,
  pack,
  dailyDrop,
  streakReward,
  cardUnlock,
  quiz,
  footballChess,
  grandPrix,
  superOver,
  basketball,
  tennis,
  finalOver,
  guessPlayer,
  bingo,
}

/// Maps an XP ledger source onto a [ProgressTrack].
ProgressTrack progressTrackForSource(XpTransactionSource source) =>
    switch (source) {
      XpTransactionSource.match => ProgressTrack.pitchDuel,
      XpTransactionSource.shootout => ProgressTrack.shootout,
      XpTransactionSource.footballChess => ProgressTrack.footballChess,
      XpTransactionSource.quiz => ProgressTrack.quiz,
      XpTransactionSource.bingo => ProgressTrack.bingo,
      XpTransactionSource.guessPlayer => ProgressTrack.guessPlayer,
      XpTransactionSource.finalOver ||
      XpTransactionSource.superOver => ProgressTrack.finalOver,
      XpTransactionSource.basketball => ProgressTrack.hoopDuel,
      XpTransactionSource.grandPrix => ProgressTrack.grandPrix,
      XpTransactionSource.tennis => ProgressTrack.tennis,
      XpTransactionSource.prediction => ProgressTrack.prediction,
      XpTransactionSource.pack ||
      XpTransactionSource.dailyDrop ||
      XpTransactionSource.cardUnlock ||
      XpTransactionSource.streakReward ||
      XpTransactionSource.openingBalance => ProgressTrack.cardsMeta,
    };

/// Rebuild per-track XP from a legacy single [legacyTotalXp] and/or the ledger.
PlayerProgression migrateProgressionFromLegacy({
  required int legacyTotalXp,
  required List<XpLedgerEntry> ledger,
}) {
  if (ledger.isEmpty) {
    if (legacyTotalXp <= 0) return PlayerProgression.initial();
    return PlayerProgression(
      xpByTrack: {ProgressTrack.cardsMeta: legacyTotalXp},
    );
  }

  final totals = <ProgressTrack, int>{
    for (final track in ProgressTrack.values) track: 0,
  };
  // Ledger is newest-first in app state; fold oldest→newest for running totals.
  final chronological = [...ledger]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  for (final entry in chronological) {
    final track = progressTrackForSource(entry.source);
    totals[track] = max(0, (totals[track] ?? 0) + entry.delta);
  }

  final folded = totals.values.fold<int>(0, (sum, xp) => sum + xp);
  // If ledger fold disagrees badly with stored total (e.g. truncated ledger),
  // keep the fold when it has any XP; otherwise fall back to cardsMeta dump.
  if (folded <= 0 && legacyTotalXp > 0) {
    return PlayerProgression(
      xpByTrack: {ProgressTrack.cardsMeta: legacyTotalXp},
    );
  }
  return PlayerProgression(xpByTrack: totals);
}

class XpLedgerEntry {
  const XpLedgerEntry({
    required this.id,
    required this.timestamp,
    required this.delta,
    required this.balanceAfter,
    required this.type,
    required this.source,
    required this.title,
    this.details,
  });

  factory XpLedgerEntry.fromJson(Map<String, dynamic> json) => XpLedgerEntry(
    id: json['id'] as String,
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    delta: json['delta'] as int,
    balanceAfter: json['balanceAfter'] as int,
    type: XpTransactionType.values.byName(json['type'] as String),
    source: XpTransactionSource.values.byName(json['source'] as String),
    title: json['title'] as String,
    details: json['details'] as String?,
  );

  final String id;
  final DateTime timestamp;
  final int delta;
  final int balanceAfter;
  final XpTransactionType type;
  final XpTransactionSource source;
  final String title;
  final String? details;

  ProgressTrack get track => progressTrackForSource(source);

  bool get isPositive => delta > 0;
  bool get isNegative => delta < 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'delta': delta,
    'balanceAfter': balanceAfter,
    'type': type.name,
    'source': source.name,
    'title': title,
    'details': details,
  };
}

class XpApplication {
  const XpApplication({
    required this.progression,
    required this.levelsGained,
    required this.trackLevelsGained,
    required this.totalLevelsGained,
    required this.track,
    required this.ledger,
    required this.appliedDelta,
  });

  final PlayerProgression progression;
  final List<int> levelsGained;
  final List<int> trackLevelsGained;
  final List<int> totalLevelsGained;
  final ProgressTrack track;
  final List<XpLedgerEntry> ledger;
  final int appliedDelta;
}

XpApplication applyXpTransaction({
  required PlayerProgression progression,
  required List<XpLedgerEntry> ledger,
  required int delta,
  required XpTransactionSource source,
  required String title,
  String? details,
  DateTime? timestamp,
  ProgressTrack? track,
}) {
  final resolvedTrack = track ?? progressTrackForSource(source);
  final applied = progression.applyXP(delta, resolvedTrack);
  final updated = applied.updated;
  final appliedDelta = updated.totalXP - progression.totalXP;
  if (appliedDelta == 0) {
    return XpApplication(
      progression: updated,
      levelsGained: const [],
      trackLevelsGained: const [],
      totalLevelsGained: const [],
      track: resolvedTrack,
      ledger: ledger,
      appliedDelta: 0,
    );
  }
  final now = timestamp ?? DateTime.now();
  final entry = XpLedgerEntry(
    id: 'xp-${now.microsecondsSinceEpoch}',
    timestamp: now,
    delta: appliedDelta,
    balanceAfter: updated.totalXP,
    type: appliedDelta > 0 ? XpTransactionType.earn : XpTransactionType.loss,
    source: source,
    title: title,
    details: details,
  );
  return XpApplication(
    progression: updated,
    levelsGained: applied.levelsGained,
    trackLevelsGained: applied.trackLevelsGained,
    totalLevelsGained: applied.totalLevelsGained,
    track: resolvedTrack,
    ledger: [entry, ...ledger],
    appliedDelta: appliedDelta,
  );
}
