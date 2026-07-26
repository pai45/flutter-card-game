enum DailyMysteryViewMode { home, play, logs, review }

enum DailyMysteryLoadStatus { loading, ready, error }

String dailyMysteryDayKey(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

int dailyMysteryWinStreak<T>(
  Map<String, T> records,
  String currentDayKey,
  bool Function(T record) isWon,
) {
  final parsed = DateTime.tryParse(currentDayKey);
  if (parsed == null) return 0;
  var cursor = parsed;
  final today = records[currentDayKey];
  if (today == null || !isWon(today)) {
    cursor = cursor.subtract(const Duration(days: 1));
  }

  var streak = 0;
  while (true) {
    final record = records[dailyMysteryDayKey(cursor)];
    if (record == null || !isWon(record)) break;
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}
