/// Short chip codes for 2026 F1 constructor teams (shop AVATAR filters).
String f1TeamCode(String team) => switch (team) {
  'Red Bull Racing' => 'RBR',
  'McLaren' => 'MCL',
  'Ferrari' => 'FER',
  'Mercedes' => 'MER',
  'Aston Martin' => 'AM',
  'Williams' => 'WIL',
  'Audi' => 'AUD',
  'Alpine' => 'ALP',
  'Haas' => 'HAS',
  'Racing Bulls' => 'RB',
  'Cadillac' => 'CAD',
  _ => _fallbackTeamCode(team),
};

String _fallbackTeamCode(String team) {
  final compact = team
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '');
  if (compact.isEmpty) return 'F1';
  if (compact.length <= 3) return compact;
  return compact.substring(0, 3);
}