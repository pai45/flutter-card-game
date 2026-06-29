import '../models/football_bingo.dart';

const footballBingoPuzzles = <FootballBingoPuzzle>[
  FootballBingoPuzzle(
    id: 'daily-club-club-001',
    title: 'Club Connections',
    columns: [
      FootballBingoAxis(id: 'barca', label: 'Barcelona', shortLabel: 'FCB'),
      FootballBingoAxis(
        id: 'realmadrid',
        label: 'Real Madrid',
        shortLabel: 'RMA',
      ),
      FootballBingoAxis(
        id: 'manutd',
        label: 'Manchester United',
        shortLabel: 'MUN',
      ),
    ],
    rows: [
      FootballBingoAxis(id: 'psg', label: 'Paris SG', shortLabel: 'PSG'),
      FootballBingoAxis(
        id: 'mancity',
        label: 'Manchester City',
        shortLabel: 'MCI',
      ),
      FootballBingoAxis(id: 'chelsea', label: 'Chelsea', shortLabel: 'CHE'),
    ],
    cells: [
      FootballBingoCell(
        id: 'psg-barca',
        rowId: 'psg',
        columnId: 'barca',
        playerId: 'bra-neymar',
      ),
      FootballBingoCell(
        id: 'psg-realmadrid',
        rowId: 'psg',
        columnId: 'realmadrid',
        playerId: 'fra-kylian-mbappe',
      ),
      FootballBingoCell(
        id: 'psg-manutd',
        rowId: 'psg',
        columnId: 'manutd',
        playerId: 'uru-manuel-ugarte',
      ),
      FootballBingoCell(
        id: 'mancity-barca',
        rowId: 'mancity',
        columnId: 'barca',
        playerId: 'por-joao-cancelo',
      ),
      FootballBingoCell(
        id: 'mancity-realmadrid',
        rowId: 'mancity',
        columnId: 'realmadrid',
        playerId: 'cro-mateo-kovacic',
      ),
      FootballBingoCell(
        id: 'mancity-manutd',
        rowId: 'mancity',
        columnId: 'manutd',
        playerId: 'por-bernardo-silva',
      ),
      FootballBingoCell(
        id: 'chelsea-barca',
        rowId: 'chelsea',
        columnId: 'barca',
        playerId: 'fra-ousmane-dembele',
      ),
      FootballBingoCell(
        id: 'chelsea-realmadrid',
        rowId: 'chelsea',
        columnId: 'realmadrid',
        playerId: 'bel-thibaut-courtois',
      ),
      FootballBingoCell(
        id: 'chelsea-manutd',
        rowId: 'chelsea',
        columnId: 'manutd',
        playerId: 'por-cristiano-ronaldo',
      ),
    ],
  ),
  FootballBingoPuzzle(
    id: 'daily-club-club-002',
    title: 'Elite Transfers',
    columns: [
      FootballBingoAxis(id: 'psg', label: 'Paris SG', shortLabel: 'PSG'),
      FootballBingoAxis(
        id: 'bayern',
        label: 'Bayern Munich',
        shortLabel: 'BAY',
      ),
      FootballBingoAxis(id: 'liverpool', label: 'Liverpool', shortLabel: 'LIV'),
    ],
    rows: [
      FootballBingoAxis(id: 'barca', label: 'Barcelona', shortLabel: 'FCB'),
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
    ],
    cells: [
      FootballBingoCell(
        id: 'barca-psg',
        rowId: 'barca',
        columnId: 'psg',
        playerId: 'arg-lionel-messi',
      ),
      FootballBingoCell(
        id: 'barca-bayern',
        rowId: 'barca',
        columnId: 'bayern',
        playerId: 'ned-frenkie-de-jong',
      ),
      FootballBingoCell(
        id: 'barca-liverpool',
        rowId: 'barca',
        columnId: 'liverpool',
        playerId: 'uru-ronald-araujo',
      ),
      FootballBingoCell(
        id: 'realmadrid-psg',
        rowId: 'realmadrid',
        columnId: 'psg',
        playerId: 'bra-vinicius-junior',
      ),
      FootballBingoCell(
        id: 'realmadrid-bayern',
        rowId: 'realmadrid',
        columnId: 'bayern',
        playerId: 'ger-antonio-rudiger',
      ),
      FootballBingoCell(
        id: 'realmadrid-liverpool',
        rowId: 'realmadrid',
        columnId: 'liverpool',
        playerId: 'cro-luka-modric',
      ),
      FootballBingoCell(
        id: 'mancity-psg',
        rowId: 'mancity',
        columnId: 'psg',
        playerId: 'bra-marquinhos',
      ),
      FootballBingoCell(
        id: 'mancity-bayern',
        rowId: 'mancity',
        columnId: 'bayern',
        playerId: 'ger-leroy-sane',
      ),
      FootballBingoCell(
        id: 'mancity-liverpool',
        rowId: 'mancity',
        columnId: 'liverpool',
        playerId: 'bel-kevin-de-bruyne',
      ),
    ],
  ),
  FootballBingoPuzzle(
    id: 'daily-club-club-003',
    title: 'Rival Routes',
    columns: [
      FootballBingoAxis(id: 'chelsea', label: 'Chelsea', shortLabel: 'CHE'),
      FootballBingoAxis(id: 'arsenal', label: 'Arsenal', shortLabel: 'ARS'),
      FootballBingoAxis(
        id: 'mancity',
        label: 'Manchester City',
        shortLabel: 'MCI',
      ),
    ],
    rows: [
      FootballBingoAxis(
        id: 'realmadrid',
        label: 'Real Madrid',
        shortLabel: 'RMA',
      ),
      FootballBingoAxis(
        id: 'bayern',
        label: 'Bayern Munich',
        shortLabel: 'BAY',
      ),
      FootballBingoAxis(
        id: 'manutd',
        label: 'Manchester United',
        shortLabel: 'MUN',
      ),
    ],
    cells: [
      FootballBingoCell(
        id: 'realmadrid-chelsea',
        rowId: 'realmadrid',
        columnId: 'chelsea',
        playerId: 'ger-kai-havertz',
      ),
      FootballBingoCell(
        id: 'realmadrid-arsenal',
        rowId: 'realmadrid',
        columnId: 'arsenal',
        playerId: 'eng-jude-bellingham',
      ),
      FootballBingoCell(
        id: 'realmadrid-mancity',
        rowId: 'realmadrid',
        columnId: 'mancity',
        playerId: 'esp-dani-carvajal',
      ),
      FootballBingoCell(
        id: 'bayern-chelsea',
        rowId: 'bayern',
        columnId: 'chelsea',
        playerId: 'eng-harry-kane',
      ),
      FootballBingoCell(
        id: 'bayern-arsenal',
        rowId: 'bayern',
        columnId: 'arsenal',
        playerId: 'fra-dayot-upamecano',
      ),
      FootballBingoCell(
        id: 'bayern-mancity',
        rowId: 'bayern',
        columnId: 'mancity',
        playerId: 'ger-jamal-musiala',
      ),
      FootballBingoCell(
        id: 'manutd-chelsea',
        rowId: 'manutd',
        columnId: 'chelsea',
        playerId: 'eng-cole-palmer',
      ),
      FootballBingoCell(
        id: 'manutd-arsenal',
        rowId: 'manutd',
        columnId: 'arsenal',
        playerId: 'eng-declan-rice',
      ),
      FootballBingoCell(
        id: 'manutd-mancity',
        rowId: 'manutd',
        columnId: 'mancity',
        playerId: 'bra-casemiro',
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
