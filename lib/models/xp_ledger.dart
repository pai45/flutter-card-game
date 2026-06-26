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
    required this.ledger,
    required this.appliedDelta,
  });

  final PlayerProgression progression;
  final List<int> levelsGained;
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
}) {
  final (:updated, :levelsGained) = progression.applyXP(delta);
  final appliedDelta = updated.totalXP - progression.totalXP;
  if (appliedDelta == 0) {
    return XpApplication(
      progression: updated,
      levelsGained: levelsGained,
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
    levelsGained: levelsGained,
    ledger: [entry, ...ledger],
    appliedDelta: appliedDelta,
  );
}
