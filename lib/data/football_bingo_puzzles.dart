import '../models/football_bingo.dart';

const footballBingoPuzzles = <FootballBingoPuzzle>[
  FootballBingoPuzzle(
    id: 'daily-club-country-001',
    title: 'Club Country Grid',
    columns: [
      FootballBingoAxis(id: 'uru', label: 'Uruguay', shortLabel: 'URU'),
      FootballBingoAxis(id: 'bra', label: 'Brazil', shortLabel: 'BRA'),
      FootballBingoAxis(id: 'por', label: 'Portugal', shortLabel: 'POR'),
    ],
    rows: [
      FootballBingoAxis(id: 'psg', label: 'Paris SG', shortLabel: 'PSG'),
      FootballBingoAxis(id: 'barca', label: 'Barcelona', shortLabel: 'BAR'),
      FootballBingoAxis(
        id: 'manutd',
        label: 'Manchester United',
        shortLabel: 'MUN',
      ),
    ],
    cells: [
      FootballBingoCell(
        id: 'psg-uru',
        rowId: 'psg',
        columnId: 'uru',
        playerId: 'uru-manuel-ugarte',
      ),
      FootballBingoCell(
        id: 'psg-bra',
        rowId: 'psg',
        columnId: 'bra',
        playerId: 'bra-neymar',
      ),
      FootballBingoCell(
        id: 'psg-por',
        rowId: 'psg',
        columnId: 'por',
        playerId: 'por-nuno-mendes',
      ),
      FootballBingoCell(
        id: 'barca-uru',
        rowId: 'barca',
        columnId: 'uru',
        playerId: 'uru-ronald-araujo',
      ),
      FootballBingoCell(
        id: 'barca-bra',
        rowId: 'barca',
        columnId: 'bra',
        playerId: 'bra-raphinha',
      ),
      FootballBingoCell(
        id: 'barca-por',
        rowId: 'barca',
        columnId: 'por',
        playerId: 'por-joao-cancelo',
      ),
      FootballBingoCell(
        id: 'manutd-uru',
        rowId: 'manutd',
        columnId: 'uru',
        playerId: 'uru-facundo-pellistri',
      ),
      FootballBingoCell(
        id: 'manutd-bra',
        rowId: 'manutd',
        columnId: 'bra',
        playerId: 'bra-casemiro',
      ),
      FootballBingoCell(
        id: 'manutd-por',
        rowId: 'manutd',
        columnId: 'por',
        playerId: 'por-bruno-fernandes',
      ),
    ],
  ),
  FootballBingoPuzzle(
    id: 'daily-club-country-002',
    title: 'European Giants',
    columns: [
      FootballBingoAxis(id: 'eng', label: 'England', shortLabel: 'ENG'),
      FootballBingoAxis(id: 'bra', label: 'Brazil', shortLabel: 'BRA'),
      FootballBingoAxis(id: 'por', label: 'Portugal', shortLabel: 'POR'),
    ],
    rows: [
      FootballBingoAxis(
        id: 'realmadrid',
        label: 'Real Madrid',
        shortLabel: 'RMA',
      ),
      FootballBingoAxis(
        id: 'mancity',
        label: 'Manchester City',
        shortLabel: 'MCI',
      ),
      FootballBingoAxis(
        id: 'manutd',
        label: 'Manchester United',
        shortLabel: 'MUN',
      ),
    ],
    cells: [
      FootballBingoCell(
        id: 'realmadrid-eng',
        rowId: 'realmadrid',
        columnId: 'eng',
        playerId: 'eng-jude-bellingham',
      ),
      FootballBingoCell(
        id: 'realmadrid-bra',
        rowId: 'realmadrid',
        columnId: 'bra',
        playerId: 'bra-vinicius-junior',
      ),
      FootballBingoCell(
        id: 'realmadrid-por',
        rowId: 'realmadrid',
        columnId: 'por',
        playerId: 'por-cristiano-ronaldo',
      ),
      FootballBingoCell(
        id: 'mancity-eng',
        rowId: 'mancity',
        columnId: 'eng',
        playerId: 'eng-phil-foden',
      ),
      FootballBingoCell(
        id: 'mancity-bra',
        rowId: 'mancity',
        columnId: 'bra',
        playerId: 'bra-ederson-moraes',
      ),
      FootballBingoCell(
        id: 'mancity-por',
        rowId: 'mancity',
        columnId: 'por',
        playerId: 'por-bernardo-silva',
      ),
      FootballBingoCell(
        id: 'manutd-eng',
        rowId: 'manutd',
        columnId: 'eng',
        playerId: 'eng-marcus-rashford',
      ),
      FootballBingoCell(
        id: 'manutd-bra',
        rowId: 'manutd',
        columnId: 'bra',
        playerId: 'bra-casemiro',
      ),
      FootballBingoCell(
        id: 'manutd-por',
        rowId: 'manutd',
        columnId: 'por',
        playerId: 'por-bruno-fernandes',
      ),
    ],
  ),
  FootballBingoPuzzle(
    id: 'daily-club-country-003',
    title: 'Star Moves',
    columns: [
      FootballBingoAxis(id: 'arg', label: 'Argentina', shortLabel: 'ARG'),
      FootballBingoAxis(id: 'bra', label: 'Brazil', shortLabel: 'BRA'),
      FootballBingoAxis(id: 'por', label: 'Portugal', shortLabel: 'POR'),
    ],
    rows: [
      FootballBingoAxis(id: 'psg', label: 'Paris SG', shortLabel: 'PSG'),
      FootballBingoAxis(id: 'barca', label: 'Barcelona', shortLabel: 'BAR'),
      FootballBingoAxis(
        id: 'mancity',
        label: 'Manchester City',
        shortLabel: 'MCI',
      ),
    ],
    cells: [
      FootballBingoCell(
        id: 'psg-arg',
        rowId: 'psg',
        columnId: 'arg',
        playerId: 'arg-lionel-messi',
      ),
      FootballBingoCell(
        id: 'psg-bra',
        rowId: 'psg',
        columnId: 'bra',
        playerId: 'bra-neymar',
      ),
      FootballBingoCell(
        id: 'psg-por',
        rowId: 'psg',
        columnId: 'por',
        playerId: 'por-nuno-mendes',
      ),
      FootballBingoCell(
        id: 'barca-arg',
        rowId: 'barca',
        columnId: 'arg',
        playerId: 'arg-lionel-messi',
      ),
      FootballBingoCell(
        id: 'barca-bra',
        rowId: 'barca',
        columnId: 'bra',
        playerId: 'bra-raphinha',
      ),
      FootballBingoCell(
        id: 'barca-por',
        rowId: 'barca',
        columnId: 'por',
        playerId: 'por-joao-cancelo',
      ),
      FootballBingoCell(
        id: 'mancity-arg',
        rowId: 'mancity',
        columnId: 'arg',
        playerId: 'arg-julian-alvarez',
      ),
      FootballBingoCell(
        id: 'mancity-bra',
        rowId: 'mancity',
        columnId: 'bra',
        playerId: 'bra-ederson-moraes',
      ),
      FootballBingoCell(
        id: 'mancity-por',
        rowId: 'mancity',
        columnId: 'por',
        playerId: 'por-bernardo-silva',
      ),
    ],
  ),
  FootballBingoPuzzle(
    id: 'daily-club-country-004',
    title: 'Premier Links',
    columns: [
      FootballBingoAxis(id: 'ger', label: 'Germany', shortLabel: 'GER'),
      FootballBingoAxis(id: 'eng', label: 'England', shortLabel: 'ENG'),
      FootballBingoAxis(id: 'bra', label: 'Brazil', shortLabel: 'BRA'),
    ],
    rows: [
      FootballBingoAxis(id: 'arsenal', label: 'Arsenal', shortLabel: 'ARS'),
      FootballBingoAxis(
        id: 'mancity',
        label: 'Manchester City',
        shortLabel: 'MCI',
      ),
      FootballBingoAxis(
        id: 'realmadrid',
        label: 'Real Madrid',
        shortLabel: 'RMA',
      ),
    ],
    cells: [
      FootballBingoCell(
        id: 'arsenal-ger',
        rowId: 'arsenal',
        columnId: 'ger',
        playerId: 'ger-kai-havertz',
      ),
      FootballBingoCell(
        id: 'arsenal-eng',
        rowId: 'arsenal',
        columnId: 'eng',
        playerId: 'eng-bukayo-saka',
      ),
      FootballBingoCell(
        id: 'arsenal-bra',
        rowId: 'arsenal',
        columnId: 'bra',
        playerId: 'bra-gabriel-magalhaes',
      ),
      FootballBingoCell(
        id: 'mancity-ger',
        rowId: 'mancity',
        columnId: 'ger',
        playerId: 'ger-leroy-sane',
      ),
      FootballBingoCell(
        id: 'mancity-eng',
        rowId: 'mancity',
        columnId: 'eng',
        playerId: 'eng-phil-foden',
      ),
      FootballBingoCell(
        id: 'mancity-bra',
        rowId: 'mancity',
        columnId: 'bra',
        playerId: 'bra-ederson-moraes',
      ),
      FootballBingoCell(
        id: 'realmadrid-ger',
        rowId: 'realmadrid',
        columnId: 'ger',
        playerId: 'ger-antonio-rudiger',
      ),
      FootballBingoCell(
        id: 'realmadrid-eng',
        rowId: 'realmadrid',
        columnId: 'eng',
        playerId: 'eng-jude-bellingham',
      ),
      FootballBingoCell(
        id: 'realmadrid-bra',
        rowId: 'realmadrid',
        columnId: 'bra',
        playerId: 'bra-vinicius-junior',
      ),
    ],
  ),
  FootballBingoPuzzle(
    id: 'daily-club-country-005',
    title: 'Red Routes',
    columns: [
      FootballBingoAxis(id: 'ned', label: 'Netherlands', shortLabel: 'NED'),
      FootballBingoAxis(id: 'uru', label: 'Uruguay', shortLabel: 'URU'),
      FootballBingoAxis(id: 'bra', label: 'Brazil', shortLabel: 'BRA'),
    ],
    rows: [
      FootballBingoAxis(id: 'liverpool', label: 'Liverpool', shortLabel: 'LIV'),
      FootballBingoAxis(id: 'barca', label: 'Barcelona', shortLabel: 'BAR'),
      FootballBingoAxis(
        id: 'manutd',
        label: 'Manchester United',
        shortLabel: 'MUN',
      ),
    ],
    cells: [
      FootballBingoCell(
        id: 'liverpool-ned',
        rowId: 'liverpool',
        columnId: 'ned',
        playerId: 'ned-virgil-van-dijk',
      ),
      FootballBingoCell(
        id: 'liverpool-uru',
        rowId: 'liverpool',
        columnId: 'uru',
        playerId: 'uru-darwin-nunez',
      ),
      FootballBingoCell(
        id: 'liverpool-bra',
        rowId: 'liverpool',
        columnId: 'bra',
        playerId: 'bra-alisson-becker',
      ),
      FootballBingoCell(
        id: 'barca-ned',
        rowId: 'barca',
        columnId: 'ned',
        playerId: 'ned-frenkie-de-jong',
      ),
      FootballBingoCell(
        id: 'barca-uru',
        rowId: 'barca',
        columnId: 'uru',
        playerId: 'uru-ronald-araujo',
      ),
      FootballBingoCell(
        id: 'barca-bra',
        rowId: 'barca',
        columnId: 'bra',
        playerId: 'bra-raphinha',
      ),
      FootballBingoCell(
        id: 'manutd-ned',
        rowId: 'manutd',
        columnId: 'ned',
        playerId: 'ned-memphis-depay',
      ),
      FootballBingoCell(
        id: 'manutd-uru',
        rowId: 'manutd',
        columnId: 'uru',
        playerId: 'uru-facundo-pellistri',
      ),
      FootballBingoCell(
        id: 'manutd-bra',
        rowId: 'manutd',
        columnId: 'bra',
        playerId: 'bra-casemiro',
      ),
    ],
  ),
  FootballBingoPuzzle(
    id: 'daily-club-country-006',
    title: 'London And Bavaria',
    columns: [
      FootballBingoAxis(id: 'fra', label: 'France', shortLabel: 'FRA'),
      FootballBingoAxis(id: 'eng', label: 'England', shortLabel: 'ENG'),
      FootballBingoAxis(id: 'ger', label: 'Germany', shortLabel: 'GER'),
    ],
    rows: [
      FootballBingoAxis(
        id: 'bayern',
        label: 'Bayern Munich',
        shortLabel: 'BAY',
      ),
      FootballBingoAxis(id: 'arsenal', label: 'Arsenal', shortLabel: 'ARS'),
      FootballBingoAxis(id: 'chelsea', label: 'Chelsea', shortLabel: 'CHE'),
    ],
    cells: [
      FootballBingoCell(
        id: 'bayern-fra',
        rowId: 'bayern',
        columnId: 'fra',
        playerId: 'fra-dayot-upamecano',
      ),
      FootballBingoCell(
        id: 'bayern-eng',
        rowId: 'bayern',
        columnId: 'eng',
        playerId: 'eng-harry-kane',
      ),
      FootballBingoCell(
        id: 'bayern-ger',
        rowId: 'bayern',
        columnId: 'ger',
        playerId: 'ger-jamal-musiala',
      ),
      FootballBingoCell(
        id: 'arsenal-fra',
        rowId: 'arsenal',
        columnId: 'fra',
        playerId: 'fra-william-saliba',
      ),
      FootballBingoCell(
        id: 'arsenal-eng',
        rowId: 'arsenal',
        columnId: 'eng',
        playerId: 'eng-bukayo-saka',
      ),
      FootballBingoCell(
        id: 'arsenal-ger',
        rowId: 'arsenal',
        columnId: 'ger',
        playerId: 'ger-kai-havertz',
      ),
      FootballBingoCell(
        id: 'chelsea-fra',
        rowId: 'chelsea',
        columnId: 'fra',
        playerId: 'fra-n-golo-kante',
      ),
      FootballBingoCell(
        id: 'chelsea-eng',
        rowId: 'chelsea',
        columnId: 'eng',
        playerId: 'eng-cole-palmer',
      ),
      FootballBingoCell(
        id: 'chelsea-ger',
        rowId: 'chelsea',
        columnId: 'ger',
        playerId: 'ger-kai-havertz',
      ),
    ],
  ),
  FootballBingoPuzzle(
    id: 'daily-club-country-007',
    title: 'Classic Clubs',
    columns: [
      FootballBingoAxis(id: 'por', label: 'Portugal', shortLabel: 'POR'),
      FootballBingoAxis(id: 'esp', label: 'Spain', shortLabel: 'ESP'),
      FootballBingoAxis(id: 'bel', label: 'Belgium', shortLabel: 'BEL'),
    ],
    rows: [
      FootballBingoAxis(
        id: 'mancity',
        label: 'Manchester City',
        shortLabel: 'MCI',
      ),
      FootballBingoAxis(
        id: 'realmadrid',
        label: 'Real Madrid',
        shortLabel: 'RMA',
      ),
      FootballBingoAxis(id: 'chelsea', label: 'Chelsea', shortLabel: 'CHE'),
    ],
    cells: [
      FootballBingoCell(
        id: 'mancity-por',
        rowId: 'mancity',
        columnId: 'por',
        playerId: 'por-bernardo-silva',
      ),
      FootballBingoCell(
        id: 'mancity-esp',
        rowId: 'mancity',
        columnId: 'esp',
        playerId: 'esp-rodri',
      ),
      FootballBingoCell(
        id: 'mancity-bel',
        rowId: 'mancity',
        columnId: 'bel',
        playerId: 'bel-kevin-de-bruyne',
      ),
      FootballBingoCell(
        id: 'realmadrid-por',
        rowId: 'realmadrid',
        columnId: 'por',
        playerId: 'por-cristiano-ronaldo',
      ),
      FootballBingoCell(
        id: 'realmadrid-esp',
        rowId: 'realmadrid',
        columnId: 'esp',
        playerId: 'esp-dani-carvajal',
      ),
      FootballBingoCell(
        id: 'realmadrid-bel',
        rowId: 'realmadrid',
        columnId: 'bel',
        playerId: 'bel-thibaut-courtois',
      ),
      FootballBingoCell(
        id: 'chelsea-por',
        rowId: 'chelsea',
        columnId: 'por',
        playerId: 'por-joao-cancelo',
      ),
      FootballBingoCell(
        id: 'chelsea-esp',
        rowId: 'chelsea',
        columnId: 'esp',
        playerId: 'esp-pedri-gonzalez',
      ),
      FootballBingoCell(
        id: 'chelsea-bel',
        rowId: 'chelsea',
        columnId: 'bel',
        playerId: 'bel-romelu-lukaku',
      ),
    ],
  ),
];

FootballBingoPuzzle footballBingoPuzzleFor(String? id) {
  return footballBingoPuzzles.firstWhere(
    (puzzle) => puzzle.id == id,
    orElse: () => footballBingoPuzzles.first,
  );
}

FootballBingoPuzzle footballBingoPuzzleForDayIndex(int index) {
  if (footballBingoPuzzles.isEmpty) {
    throw StateError('No Football Bingo puzzles authored');
  }
  return footballBingoPuzzles[index % footballBingoPuzzles.length];
}
