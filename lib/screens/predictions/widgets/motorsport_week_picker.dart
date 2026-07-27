// Mon-Sun race-week helpers for motorsport MATCH browsing.
// Calendar UI reuses the shared Material showDatePicker (same as football).

DateTime mondayOf(DateTime day) {
  final start = DateTime(day.year, day.month, day.day);
  return start.subtract(Duration(days: start.weekday - 1));
}

DateTime sundayOf(DateTime day) => mondayOf(day).add(const Duration(days: 6));

List<DateTime> weekDays(DateTime weekStart) {
  final monday = mondayOf(weekStart);
  return [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
}

List<DateTime> calendarWeeks(List<DateTime> days) {
  final weeks = <int, DateTime>{};
  for (final day in days) {
    final monday = mondayOf(day);
    weeks[monday.millisecondsSinceEpoch] = monday;
  }
  final list = weeks.values.toList()..sort();
  return list;
}

String weekHeading(DateTime weekStart) {
  final monday = mondayOf(weekStart);
  final thisMonday = mondayOf(DateTime.now());
  if (_sameDay(monday, thisMonday)) return 'THIS WEEK';
  if (_sameDay(monday, thisMonday.subtract(const Duration(days: 7)))) {
    return 'LAST WEEK';
  }
  if (_sameDay(monday, thisMonday.add(const Duration(days: 7)))) {
    return 'NEXT WEEK';
  }
  return weekRangeLabel(monday);
}

String weekRangeLabel(DateTime weekStart) {
  final monday = mondayOf(weekStart);
  final sunday = sundayOf(monday);
  return '${_shortMonthDay(monday)}-${_shortMonthDay(sunday)}';
}

String _shortMonthDay(DateTime day) {
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${months[day.month - 1]} ${day.day}';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
