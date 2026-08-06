import '../models/football_bingo.dart';

/// Curated senior-club records for the Football Bingo season.  Each record is
/// checked against the linked career databases; youth/reserve-only spells are
/// deliberately excluded.
final footballBingoCareers = <FootballBingoCareer>[
  _career('bingo-messi', 'Lionel Messi', 'MESSI', ['barca', 'psg', 'intermiami']),
  _career('bingo-mbappe', 'Kylian Mbappe', 'MBAPPE', ['monaco', 'psg', 'realmadrid']),
  _career('bingo-ibrahimovic', 'Zlatan Ibrahimovic', 'IBRA', ['malmo', 'ajax', 'juventus', 'inter', 'barca', 'acmilan', 'psg', 'manutd', 'lagalaxy']),
  _career('bingo-pedro', 'Pedro', 'PEDRO', ['barca', 'chelsea', 'lazio']),
  _career('bingo-hazard', 'Eden Hazard', 'HAZARD', ['lille', 'chelsea', 'realmadrid']),
  _career('bingo-mata', 'Juan Mata', 'MATA', ['valencia', 'chelsea', 'manutd', 'galatasaray', 'vissel-kobe']),
  _career('bingo-dani-alves', 'Dani Alves', 'D. ALVES', ['bahia', 'sevilla', 'barca', 'juventus', 'psg', 'saopaulo', 'pumas']),
  _career('bingo-ronaldo', 'Cristiano Ronaldo', 'RONALDO', ['sporting', 'manutd', 'realmadrid', 'juventus', 'alnassr']),
  _career('bingo-pogba', 'Paul Pogba', 'POGBA', ['manutd', 'juventus', 'monaco']),
  _career('bingo-sane', 'Leroy Sane', 'SANE', ['schalke', 'mancity', 'bayern', 'galatasaray']),
  _career('bingo-sterling', 'Raheem Sterling', 'STERLING', ['liverpool', 'mancity', 'chelsea', 'arsenal']),
  _career('bingo-zinchenko', 'Oleksandr Zinchenko', 'ZINCHENKO', ['ufa', 'mancity', 'psv', 'arsenal']),
  _career('bingo-alaba', 'David Alaba', 'ALABA', ['austria-wien', 'bayern', 'hoffenheim', 'realmadrid']),
  _career('bingo-xabi-alonso', 'Xabi Alonso', 'X. ALONSO', ['realsociedad', 'eibar', 'liverpool', 'realmadrid', 'bayern']),
  _career('bingo-odegaard', 'Martin Odegaard', 'ODEGAARD', ['stromsgodset', 'realmadrid', 'heerenveen', 'vitesse', 'realsociedad', 'arsenal']),
  _career('bingo-robben', 'Arjen Robben', 'ROBBEN', ['groningen', 'psv', 'chelsea', 'realmadrid', 'bayern']),
  _career('bingo-torres', 'Fernando Torres', 'TORRES', ['atletico', 'liverpool', 'chelsea', 'acmilan', 'sagan-tosu']),
  _career('bingo-cech', 'Petr Cech', 'CECH', ['chmel-blsany', 'sparta-prague', 'rennes', 'chelsea', 'arsenal']),
  _career('bingo-hakimi', 'Achraf Hakimi', 'HAKIMI', ['realmadrid', 'dortmund', 'inter', 'psg']),
  _career('bingo-ronaldinho', 'Ronaldinho', 'RONALDINHO', ['gremio', 'psg', 'barca', 'acmilan', 'flamengo', 'atletico-mg', 'queretaro', 'fluminense']),
  _career('bingo-pochettino', 'Mauricio Pochettino', 'POCHETTINO', ['newells', 'espanyol', 'psg', 'bordeaux', 'tottenham']),
  _career('bingo-vidal', 'Arturo Vidal', 'VIDAL', ['colo-colo', 'leverkusen', 'juventus', 'bayern', 'barca', 'inter', 'flamengo', 'athletico-pr']),
  _career('bingo-higuain', 'Gonzalo Higuain', 'HIGUAIN', ['riverplate', 'realmadrid', 'napoli', 'juventus', 'acmilan', 'chelsea', 'intermiami']),
  _career('bingo-kulusevski', 'Dejan Kulusevski', 'KULUSEVSKI', ['atalanta', 'parma', 'juventus', 'tottenham']),
  _career('bingo-lukaku', 'Romelu Lukaku', 'LUKAKU', ['anderlecht', 'chelsea', 'westbrom', 'everton', 'manutd', 'inter', 'roma', 'napoli']),
  _career('bingo-dalot', 'Diogo Dalot', 'DALOT', ['porto', 'manutd', 'acmilan']),
  _career('bingo-eriksen', 'Christian Eriksen', 'ERIKSEN', ['ajax', 'tottenham', 'inter', 'brentford', 'manutd']),
];

final footballBingoCareerPlayers = footballBingoCareers
    .map((career) => career.toPlayerCard())
    .toList(growable: false);

FootballBingoCareer? footballBingoCareerFor(String playerId) {
  for (final career in footballBingoCareers) {
    if (career.playerId == playerId) return career;
  }
  return null;
}

FootballBingoCareer _career(
  String id,
  String name,
  String shortName,
  List<String> clubs,
) => FootballBingoCareer(
  playerId: id,
  name: name,
  shortName: shortName,
  clubHistory: [for (final club in clubs) FootballBingoClubSpell(clubId: club, label: _clubLabels[club] ?? club)],
  sourceUrls: [
    'https://www.transfermarkt.com/schnellsuche/ergebnis/schnellsuche?query=${Uri.encodeComponent(name)}',
    'https://www.worldfootball.net/',
  ],
);

const _clubLabels = <String, String>{
  'psg': 'Paris SG', 'barca': 'Barcelona', 'realmadrid': 'Real Madrid', 'manutd': 'Manchester United', 'mancity': 'Manchester City', 'chelsea': 'Chelsea', 'juventus': 'Juventus', 'bayern': 'Bayern Munich', 'liverpool': 'Liverpool', 'arsenal': 'Arsenal', 'inter': 'Inter', 'acmilan': 'AC Milan', 'tottenham': 'Tottenham', 'monaco': 'Monaco', 'intermiami': 'Inter Miami', 'malmo': 'Malmo', 'ajax': 'Ajax', 'lagalaxy': 'LA Galaxy', 'lille': 'Lille', 'lazio': 'Lazio', 'valencia': 'Valencia', 'galatasaray': 'Galatasaray', 'vissel-kobe': 'Vissel Kobe', 'bahia': 'Bahia', 'sevilla': 'Sevilla', 'saopaulo': 'Sao Paulo', 'pumas': 'Pumas', 'sporting': 'Sporting CP', 'alnassr': 'Al Nassr', 'schalke': 'Schalke', 'psv': 'PSV', 'ufa': 'Ufa', 'austria-wien': 'Austria Wien', 'hoffenheim': 'Hoffenheim', 'realsociedad': 'Real Sociedad', 'eibar': 'Eibar', 'stromsgodset': 'Stromsgodset', 'heerenveen': 'Heerenveen', 'vitesse': 'Vitesse', 'groningen': 'Groningen', 'atletico': 'Atletico Madrid', 'sagan-tosu': 'Sagan Tosu', 'chmel-blsany': 'Chmel Blsany', 'sparta-prague': 'Sparta Prague', 'rennes': 'Rennes', 'dortmund': 'Dortmund', 'gremio': 'Gremio', 'flamengo': 'Flamengo', 'atletico-mg': 'Atletico Mineiro', 'queretaro': 'Queretaro', 'fluminense': 'Fluminense', 'newells': "Newell's Old Boys", 'espanyol': 'Espanyol', 'bordeaux': 'Bordeaux', 'colo-colo': 'Colo-Colo', 'leverkusen': 'Bayer Leverkusen', 'napoli': 'Napoli', 'athletico-pr': 'Athletico Paranaense', 'riverplate': 'River Plate', 'atalanta': 'Atalanta', 'parma': 'Parma', 'anderlecht': 'Anderlecht', 'westbrom': 'West Bromwich Albion', 'everton': 'Everton', 'roma': 'Roma', 'porto': 'Porto', 'brentford': 'Brentford',
};
