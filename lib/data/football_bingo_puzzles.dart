import '../models/football_bingo.dart';

/// Fifty authored daily layouts. The three verified career boards rotate their
/// axes each season slot, giving every day a distinct layout and stable ID.
final footballBingoPuzzles = List<FootballBingoPuzzle>.generate(50, _puzzleForIndex, growable: false);

FootballBingoPuzzle _puzzleForIndex(int index) {
  final blueprint = _blueprints[index % _blueprints.length];
  final turn = (index ~/ _blueprints.length) % 3;
  final rows = _rotate(blueprint.rows, turn);
  final columns = _rotate(blueprint.columns, (turn * 2) % 3);
  return FootballBingoPuzzle(
    id: 'daily-career-v2-${(index + 1).toString().padLeft(3, '0')}',
    title: 'Career Grid ${(index + 1).toString().padLeft(2, '0')}',
    columns: columns,
    rows: rows,
    cells: [
      for (final entry in blueprint.players.entries)
        FootballBingoCell(
          id: '${index + 1}-${entry.key.replaceAll(':', '-')}',
          rowId: entry.key.split(':').first,
          columnId: entry.key.split(':').last,
          playerId: entry.value,
        ),
    ],
  );
}

List<T> _rotate<T>(List<T> values, int count) => [
  ...values.skip(count),
  ...values.take(count),
];

class _Blueprint {
  const _Blueprint(this.rows, this.columns, this.players);
  final List<FootballBingoAxis> rows;
  final List<FootballBingoAxis> columns;
  final Map<String, String> players;
}

final _blueprints = <_Blueprint>[
  _Blueprint(
    [_axis('psg', 'Paris SG', 'PSG'), _axis('chelsea', 'Chelsea', 'CHE'), _axis('juventus', 'Juventus', 'JUV')],
    [_axis('barca', 'Barcelona', 'FCB'), _axis('realmadrid', 'Real Madrid', 'RMA'), _axis('manutd', 'Manchester United', 'MUN')],
    {'psg:barca': 'bingo-messi', 'psg:realmadrid': 'bingo-mbappe', 'psg:manutd': 'bingo-ibrahimovic', 'chelsea:barca': 'bingo-pedro', 'chelsea:realmadrid': 'bingo-hazard', 'chelsea:manutd': 'bingo-mata', 'juventus:barca': 'bingo-dani-alves', 'juventus:realmadrid': 'bingo-ronaldo', 'juventus:manutd': 'bingo-pogba'},
  ),
  _Blueprint(
    [_axis('mancity', 'Manchester City', 'MCI'), _axis('realmadrid', 'Real Madrid', 'RMA'), _axis('chelsea', 'Chelsea', 'CHE')],
    [_axis('bayern', 'Bayern Munich', 'BAY'), _axis('liverpool', 'Liverpool', 'LIV'), _axis('arsenal', 'Arsenal', 'ARS')],
    {'mancity:bayern': 'bingo-sane', 'mancity:liverpool': 'bingo-sterling', 'mancity:arsenal': 'bingo-zinchenko', 'realmadrid:bayern': 'bingo-alaba', 'realmadrid:liverpool': 'bingo-xabi-alonso', 'realmadrid:arsenal': 'bingo-odegaard', 'chelsea:bayern': 'bingo-robben', 'chelsea:liverpool': 'bingo-torres', 'chelsea:arsenal': 'bingo-cech'},
  ),
  _Blueprint(
    [_axis('psg', 'Paris SG', 'PSG'), _axis('juventus', 'Juventus', 'JUV'), _axis('manutd', 'Manchester United', 'MUN')],
    [_axis('inter', 'Inter', 'INT'), _axis('acmilan', 'AC Milan', 'MIL'), _axis('tottenham', 'Tottenham', 'TOT')],
    {'psg:inter': 'bingo-hakimi', 'psg:acmilan': 'bingo-ronaldinho', 'psg:tottenham': 'bingo-pochettino', 'juventus:inter': 'bingo-vidal', 'juventus:acmilan': 'bingo-higuain', 'juventus:tottenham': 'bingo-kulusevski', 'manutd:inter': 'bingo-lukaku', 'manutd:acmilan': 'bingo-dalot', 'manutd:tottenham': 'bingo-eriksen'},
  ),
];

FootballBingoAxis _axis(String id, String label, String shortLabel) =>
    FootballBingoAxis(id: id, label: label, shortLabel: shortLabel);

FootballBingoPuzzle footballBingoPuzzleFor(String? id) => footballBingoPuzzles.firstWhere(
  (puzzle) => puzzle.id == id,
  orElse: () => footballBingoPuzzles.first,
);

FootballBingoPuzzle footballBingoPuzzleForDayIndex(int index) =>
    footballBingoPuzzles[index % footballBingoPuzzles.length];
