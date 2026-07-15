import 'dart:math';

/// Racing-flavored CPU driver name pool for Grand Prix Dash — same pattern as
/// `random_opponent_names.dart`, but with paddock-sounding names. Combinations
/// are invented (no real driver pairings).
const List<String> _grandPrixFirstNames = [
  'Luca',
  'Mika',
  'Jules',
  'Rio',
  'Kazuki',
  'Nico',
  'Theo',
  'Enzo',
  'Otto',
  'Dario',
  'Ivan',
  'Marco',
  'Alexi',
  'Bruno',
  'Felix',
  'Hugo',
  'Levi',
  'Mateo',
  'Ayaan',
  'Callum',
];

const List<String> _grandPrixLastNames = [
  'Vermeer',
  'Castellano',
  'Lindqvist',
  'Okada',
  'Ferrand',
  'Novak',
  'Almeida',
  'Baumann',
  'Kowalski',
  'Marchetti',
  'Sorensen',
  'Duval',
  'Ishida',
  'Petrakis',
  'Weller',
  'Zubarev',
  'Nakamura',
  'Herrero',
  'Vance',
  'Adeyemi',
];

final List<String> grandPrixDriverNames = List.unmodifiable([
  for (final firstName in _grandPrixFirstNames)
    for (final lastName in _grandPrixLastNames) '$firstName $lastName',
]);

/// Draws [count] unique driver names from the pool using [random].
List<String> generateDriverNames(int count, Random random) {
  assert(count <= grandPrixDriverNames.length);
  final pool = [...grandPrixDriverNames]..shuffle(random);
  return pool.take(count).toList();
}
