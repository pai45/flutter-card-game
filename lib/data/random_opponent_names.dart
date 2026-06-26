import 'dart:math';

const List<String> _randomOpponentFirstNames = [
  'Aarav',
  'Mateo',
  'Luca',
  'Noah',
  'Elias',
  'Omar',
  'Kenji',
  'Rafael',
  'Dante',
  'Niko',
  'Sofia',
  'Maya',
  'Amara',
  'Leila',
  'Ines',
  'Yara',
  'Mina',
  'Talia',
  'Nora',
  'Elena',
  'Theo',
  'Kai',
  'Arjun',
  'Malik',
  'Diego',
];

const List<String> _randomOpponentLastNames = [
  'Sharma',
  'Rossi',
  'Tan',
  'Silva',
  'Okafor',
  'Haddad',
  'Santos',
  'Kovac',
  'Novak',
  'Mensah',
  'Garcia',
  'Petrov',
  'Kimani',
  'Moreau',
  'Rahman',
  'Bennett',
  'Alvarez',
  'Hassan',
  'Ito',
  'Diallo',
];

final List<String> randomOpponentNames = List.unmodifiable([
  for (final firstName in _randomOpponentFirstNames)
    for (final lastName in _randomOpponentLastNames) '$firstName $lastName',
]);

String randomOpponentName({Random? random}) {
  final rng = random ?? Random();
  return randomOpponentNames[rng.nextInt(randomOpponentNames.length)];
}
