import 'dart:ui';

import '../models/basketball.dart';

/// 180-player 2026 NBA Hoop Duel roster: six players per team.
///
/// Each seed locks the card/game identity: team, player, position, basketball
/// deck role, and OVR. Granular gameplay ratings are generated from those
/// values so the roster stays maintainable while preserving distinct play
/// styles for guards, wings, and bigs.
final List<BasketballAthlete> basketballAthletes = [
  for (final seed in _basketballSeeds) _buildAthlete(seed),
];

BasketballAthlete basketballAthleteById(String id) =>
    basketballAthletes.firstWhere(
      (athlete) => athlete.id == id,
      orElse: () => basketballAthletes.first,
    );

class _Seed {
  const _Seed(this.teamCode, this.name, this.position, this.role, this.ovr);

  final String teamCode;
  final String name;
  final String position;
  final BasketballCardRole role;
  final int ovr;
}

const List<_Seed> _basketballSeeds = [
  _Seed('ATL', 'Trae Young', 'PG', BasketballCardRole.guard, 91),
  _Seed('ATL', 'Jalen Johnson', 'PF', BasketballCardRole.wing, 88),
  _Seed('ATL', 'Kristaps Porzingis', 'C', BasketballCardRole.big, 84),
  _Seed('ATL', 'Nickeil Alexander-Walker', 'SG', BasketballCardRole.guard, 79),
  _Seed('ATL', 'Onyeka Okongwu', 'C', BasketballCardRole.big, 79),
  _Seed('ATL', 'Zaccharie Risacher', 'SF', BasketballCardRole.wing, 78),
  _Seed('BOS', 'Jayson Tatum', 'SF/PF', BasketballCardRole.wing, 94),
  _Seed('BOS', 'Jaylen Brown', 'SG/SF', BasketballCardRole.wing, 90),
  _Seed('BOS', 'Derrick White', 'G', BasketballCardRole.guard, 86),
  _Seed('BOS', 'Payton Pritchard', 'PG', BasketballCardRole.guard, 82),
  _Seed('BOS', 'Neemias Queta', 'C', BasketballCardRole.big, 77),
  _Seed('BOS', 'Baylor Scheierman', 'G/F', BasketballCardRole.wing, 75),
  _Seed('BKN', 'Michael Porter Jr.', 'SF', BasketballCardRole.wing, 86),
  _Seed('BKN', 'Cam Thomas', 'SG', BasketballCardRole.guard, 84),
  _Seed('BKN', 'Nic Claxton', 'C', BasketballCardRole.big, 82),
  _Seed('BKN', 'Terance Mann', 'G', BasketballCardRole.guard, 79),
  _Seed('BKN', 'Noah Clowney', 'F', BasketballCardRole.wing, 77),
  _Seed('BKN', 'Tyler Bilodeau', 'F/C', BasketballCardRole.big, 72),
  _Seed('CHA', 'LaMelo Ball', 'PG', BasketballCardRole.guard, 88),
  _Seed('CHA', 'Brandon Miller', 'SF', BasketballCardRole.wing, 86),
  _Seed('CHA', 'Miles Bridges', 'SF/PF', BasketballCardRole.wing, 82),
  _Seed('CHA', 'Kon Knueppel', 'G/F', BasketballCardRole.guard, 78),
  _Seed('CHA', 'Moussa Diabate', 'C', BasketballCardRole.big, 74),
  _Seed('CHA', 'Kylan Boswell', 'G', BasketballCardRole.guard, 72),
  _Seed('CHI', 'Coby White', 'PG', BasketballCardRole.guard, 84),
  _Seed('CHI', 'Josh Giddey', 'G/F', BasketballCardRole.guard, 84),
  _Seed('CHI', 'Nikola Vucevic', 'C', BasketballCardRole.big, 82),
  _Seed('CHI', 'Matas Buzelis', 'F', BasketballCardRole.wing, 79),
  _Seed('CHI', 'Ayo Dosunmu', 'G', BasketballCardRole.guard, 78),
  _Seed('CHI', 'Tobe Awaka', 'F/C', BasketballCardRole.wing, 72),
  _Seed('CLE', 'Donovan Mitchell', 'SG', BasketballCardRole.guard, 92),
  _Seed('CLE', 'Evan Mobley', 'PF/C', BasketballCardRole.big, 91),
  _Seed('CLE', 'Darius Garland', 'PG', BasketballCardRole.guard, 87),
  _Seed('CLE', 'Jarrett Allen', 'C', BasketballCardRole.big, 86),
  _Seed('CLE', 'DeAndre Hunter', 'SF', BasketballCardRole.wing, 79),
  _Seed('CLE', 'Max Strus', 'G/F', BasketballCardRole.wing, 78),
  _Seed('DAL', 'Kyrie Irving', 'PG', BasketballCardRole.guard, 90),
  _Seed('DAL', 'Cooper Flagg', 'F', BasketballCardRole.wing, 84),
  _Seed('DAL', 'Klay Thompson', 'SG', BasketballCardRole.guard, 82),
  _Seed('DAL', 'PJ Washington', 'PF', BasketballCardRole.wing, 79),
  _Seed('DAL', 'Daniel Gafford', 'C', BasketballCardRole.big, 79),
  _Seed('DAL', 'Dereck Lively II', 'C', BasketballCardRole.big, 78),
  _Seed('DEN', 'Nikola Jokic', 'C', BasketballCardRole.big, 97),
  _Seed('DEN', 'Jamal Murray', 'PG', BasketballCardRole.guard, 88),
  _Seed('DEN', 'Aaron Gordon', 'PF', BasketballCardRole.wing, 84),
  _Seed('DEN', 'Cam Johnson', 'SF', BasketballCardRole.wing, 81),
  _Seed('DEN', 'Christian Braun', 'G/F', BasketballCardRole.guard, 79),
  _Seed('DEN', 'Julian Strawther', 'G/F', BasketballCardRole.guard, 76),
  _Seed('DET', 'Cade Cunningham', 'PG', BasketballCardRole.guard, 91),
  _Seed('DET', 'Jaden Ivey', 'SG', BasketballCardRole.guard, 84),
  _Seed('DET', 'Ausar Thompson', 'SF', BasketballCardRole.wing, 81),
  _Seed('DET', 'Tobias Harris', 'PF', BasketballCardRole.wing, 81),
  _Seed('DET', 'Jalen Duren', 'C', BasketballCardRole.big, 79),
  _Seed('DET', 'Ron Holland', 'F', BasketballCardRole.wing, 77),
  _Seed('GSW', 'Stephen Curry', 'PG', BasketballCardRole.guard, 93),
  _Seed('GSW', 'Jimmy Butler', 'SF', BasketballCardRole.wing, 89),
  _Seed('GSW', 'Draymond Green', 'PF/C', BasketballCardRole.big, 83),
  _Seed('GSW', 'Jonathan Kuminga', 'F', BasketballCardRole.wing, 82),
  _Seed('GSW', 'Brandin Podziemski', 'G', BasketballCardRole.guard, 78),
  _Seed('GSW', 'Moses Moody', 'G/F', BasketballCardRole.wing, 77),
  _Seed('HOU', 'Kevin Durant', 'PF', BasketballCardRole.wing, 93),
  _Seed('HOU', 'Alperen Sengun', 'C', BasketballCardRole.big, 90),
  _Seed('HOU', 'Amen Thompson', 'G/F', BasketballCardRole.guard, 86),
  _Seed('HOU', 'Jabari Smith Jr.', 'PF', BasketballCardRole.wing, 79),
  _Seed('HOU', 'Reed Sheppard', 'G', BasketballCardRole.guard, 76),
  _Seed('HOU', 'Steven Adams', 'C', BasketballCardRole.big, 75),
  _Seed('IND', 'Tyrese Haliburton', 'PG', BasketballCardRole.guard, 90),
  _Seed('IND', 'Pascal Siakam', 'PF', BasketballCardRole.wing, 88),
  _Seed('IND', 'Andrew Nembhard', 'G', BasketballCardRole.guard, 81),
  _Seed('IND', 'Bennedict Mathurin', 'G/F', BasketballCardRole.guard, 79),
  _Seed('IND', 'Aaron Nesmith', 'SF', BasketballCardRole.wing, 79),
  _Seed('IND', 'Obi Toppin', 'PF', BasketballCardRole.big, 78),
  _Seed('LAC', 'Kawhi Leonard', 'SF', BasketballCardRole.wing, 89),
  _Seed('LAC', 'James Harden', 'PG', BasketballCardRole.guard, 87),
  _Seed('LAC', 'Bradley Beal', 'SG', BasketballCardRole.guard, 84),
  _Seed('LAC', 'Ivica Zubac', 'C', BasketballCardRole.big, 82),
  _Seed('LAC', 'Bogdan Bogdanovic', 'G', BasketballCardRole.guard, 79),
  _Seed('LAC', 'Nicolas Batum', 'G/F', BasketballCardRole.wing, 75),
  _Seed('LAL', 'Luka Doncic', 'PG', BasketballCardRole.guard, 96),
  _Seed('LAL', 'LeBron James', 'SF/PF', BasketballCardRole.wing, 91),
  _Seed('LAL', 'Austin Reaves', 'G', BasketballCardRole.guard, 83),
  _Seed('LAL', 'Rui Hachimura', 'F', BasketballCardRole.wing, 79),
  _Seed('LAL', 'Marcus Smart', 'G', BasketballCardRole.guard, 78),
  _Seed('LAL', 'Jaxson Hayes', 'C', BasketballCardRole.big, 74),
  _Seed('MEM', 'Ja Morant', 'PG', BasketballCardRole.guard, 89),
  _Seed('MEM', 'Jaren Jackson Jr.', 'PF/C', BasketballCardRole.big, 88),
  _Seed('MEM', 'Cameron Boozer', 'F', BasketballCardRole.wing, 82),
  _Seed('MEM', 'Zach Edey', 'C', BasketballCardRole.big, 80),
  _Seed('MEM', 'Santi Aldama', 'F/C', BasketballCardRole.wing, 79),
  _Seed('MEM', 'Scotty Pippen Jr.', 'G', BasketballCardRole.guard, 75),
  _Seed('MIA', 'Giannis Antetokounmpo', 'PF', BasketballCardRole.wing, 95),
  _Seed('MIA', 'Bam Adebayo', 'C', BasketballCardRole.big, 90),
  _Seed('MIA', 'Tyler Herro', 'SG', BasketballCardRole.guard, 87),
  _Seed('MIA', 'Kelel Ware', 'C', BasketballCardRole.big, 79),
  _Seed('MIA', 'Jaime Jaquez Jr.', 'F', BasketballCardRole.wing, 78),
  _Seed('MIA', 'Davion Mitchell', 'G', BasketballCardRole.guard, 76),
  _Seed('MIL', 'Nate Ament', 'F', BasketballCardRole.wing, 82),
  _Seed('MIL', 'Kyle Kuzma', 'F', BasketballCardRole.wing, 81),
  _Seed('MIL', 'Bobby Portis', 'PF/C', BasketballCardRole.big, 79),
  _Seed('MIL', 'Kevin Porter Jr.', 'G', BasketballCardRole.guard, 78),
  _Seed('MIL', 'Cole Anthony', 'G', BasketballCardRole.guard, 76),
  _Seed('MIL', 'Alex Antetokounmpo', 'F', BasketballCardRole.big, 70),
  _Seed('MIN', 'Anthony Edwards', 'SG', BasketballCardRole.guard, 93),
  _Seed('MIN', 'Julius Randle', 'PF', BasketballCardRole.wing, 87),
  _Seed('MIN', 'Rudy Gobert', 'C', BasketballCardRole.big, 86),
  _Seed('MIN', 'Naz Reid', 'C/F', BasketballCardRole.big, 82),
  _Seed('MIN', 'Jaden McDaniels', 'SF', BasketballCardRole.wing, 81),
  _Seed('MIN', 'Rob Dillingham', 'G', BasketballCardRole.guard, 72),
  _Seed('NOP', 'Zion Williamson', 'PF', BasketballCardRole.big, 87),
  _Seed('NOP', 'Dejounte Murray', 'PG', BasketballCardRole.guard, 86),
  _Seed('NOP', 'Trey Murphy III', 'SF', BasketballCardRole.wing, 84),
  _Seed('NOP', 'Herb Jones', 'SF', BasketballCardRole.wing, 79),
  _Seed('NOP', 'Yves Missi', 'C', BasketballCardRole.big, 78),
  _Seed('NOP', 'Jordan Hawkins', 'G', BasketballCardRole.guard, 76),
  _Seed('NYK', 'Jalen Brunson', 'PG', BasketballCardRole.guard, 92),
  _Seed('NYK', 'Karl-Anthony Towns', 'C', BasketballCardRole.big, 90),
  _Seed('NYK', 'Mikal Bridges', 'SF', BasketballCardRole.wing, 86),
  _Seed('NYK', 'OG Anunoby', 'F', BasketballCardRole.wing, 85),
  _Seed('NYK', 'Josh Hart', 'G/F', BasketballCardRole.wing, 82),
  _Seed('NYK', 'Jose Alvarado', 'G', BasketballCardRole.guard, 77),
  _Seed('OKC', 'Shai Gilgeous-Alexander', 'PG', BasketballCardRole.guard, 97),
  _Seed('OKC', 'Chet Holmgren', 'C', BasketballCardRole.big, 90),
  _Seed('OKC', 'Jalen Williams', 'G/F', BasketballCardRole.wing, 90),
  _Seed('OKC', 'Alex Caruso', 'G', BasketballCardRole.guard, 82),
  _Seed('OKC', 'Lu Dort', 'G/F', BasketballCardRole.wing, 79),
  _Seed('OKC', 'Brooks Barnhizer', 'G', BasketballCardRole.guard, 72),
  _Seed('ORL', 'Paolo Banchero', 'PF', BasketballCardRole.wing, 91),
  _Seed('ORL', 'Franz Wagner', 'SF', BasketballCardRole.wing, 88),
  _Seed('ORL', 'Desmond Bane', 'SG', BasketballCardRole.guard, 87),
  _Seed('ORL', 'Jalen Suggs', 'G', BasketballCardRole.guard, 82),
  _Seed('ORL', 'Anthony Black', 'G', BasketballCardRole.guard, 79),
  _Seed('ORL', 'Goga Bitadze', 'C', BasketballCardRole.big, 78),
  _Seed('PHI', 'Joel Embiid', 'C', BasketballCardRole.big, 92),
  _Seed('PHI', 'Tyrese Maxey', 'PG', BasketballCardRole.guard, 90),
  _Seed('PHI', 'Paul George', 'SF', BasketballCardRole.wing, 86),
  _Seed('PHI', 'Jared McCain', 'G', BasketballCardRole.guard, 80),
  _Seed('PHI', 'Adem Bona', 'F/C', BasketballCardRole.big, 76),
  _Seed('PHI', 'Dominick Barlow', 'F', BasketballCardRole.wing, 74),
  _Seed('PHX', 'Devin Booker', 'SG', BasketballCardRole.guard, 91),
  _Seed('PHX', 'Jalen Green', 'G', BasketballCardRole.guard, 84),
  _Seed('PHX', 'Dillon Brooks', 'SF', BasketballCardRole.wing, 80),
  _Seed('PHX', 'Grayson Allen', 'G', BasketballCardRole.guard, 79),
  _Seed('PHX', 'Ryan Dunn', 'F', BasketballCardRole.wing, 77),
  _Seed('PHX', 'Oso Ighodaro', 'F/C', BasketballCardRole.big, 74),
  _Seed('POR', 'Deni Avdija', 'F', BasketballCardRole.wing, 84),
  _Seed('POR', 'Scoot Henderson', 'PG', BasketballCardRole.guard, 82),
  _Seed('POR', 'Shaedon Sharpe', 'G', BasketballCardRole.guard, 81),
  _Seed('POR', 'Jerami Grant', 'F', BasketballCardRole.wing, 80),
  _Seed('POR', 'Donovan Clingan', 'C', BasketballCardRole.big, 78),
  _Seed('POR', 'Robert Williams III', 'C', BasketballCardRole.big, 76),
  _Seed('SAC', 'Domantas Sabonis', 'C', BasketballCardRole.big, 89),
  _Seed('SAC', 'Zach LaVine', 'SG', BasketballCardRole.guard, 86),
  _Seed('SAC', 'DeMar DeRozan', 'SF', BasketballCardRole.wing, 85),
  _Seed('SAC', 'Keegan Murray', 'F', BasketballCardRole.wing, 81),
  _Seed('SAC', 'Precious Achiuwa', 'F/C', BasketballCardRole.big, 78),
  _Seed('SAC', 'Darius Acuff Jr.', 'G', BasketballCardRole.guard, 73),
  _Seed('SAS', 'Victor Wembanyama', 'C', BasketballCardRole.big, 96),
  _Seed('SAS', 'DeAaron Fox', 'PG', BasketballCardRole.guard, 89),
  _Seed('SAS', 'Stephon Castle', 'G', BasketballCardRole.guard, 83),
  _Seed('SAS', 'Devin Vassell', 'G/F', BasketballCardRole.wing, 82),
  _Seed('SAS', 'Harrison Barnes', 'F', BasketballCardRole.wing, 78),
  _Seed('SAS', 'Bismack Biyombo', 'C', BasketballCardRole.big, 72),
  _Seed('TOR', 'Scottie Barnes', 'F', BasketballCardRole.wing, 91),
  _Seed('TOR', 'Brandon Ingram', 'SF', BasketballCardRole.wing, 87),
  _Seed('TOR', 'RJ Barrett', 'G/F', BasketballCardRole.wing, 84),
  _Seed('TOR', 'Immanuel Quickley', 'PG', BasketballCardRole.guard, 82),
  _Seed('TOR', 'Jakob Poeltl', 'C', BasketballCardRole.big, 80),
  _Seed('TOR', 'Gradey Dick', 'G/F', BasketballCardRole.guard, 74),
  _Seed('UTA', 'Lauri Markkanen', 'F', BasketballCardRole.wing, 87),
  _Seed('UTA', 'Ace Bailey', 'F', BasketballCardRole.wing, 82),
  _Seed('UTA', 'Keyonte George', 'G', BasketballCardRole.guard, 80),
  _Seed('UTA', 'Walker Kessler', 'C', BasketballCardRole.big, 79),
  _Seed('UTA', 'Trey Alexander', 'G', BasketballCardRole.guard, 73),
  _Seed('UTA', 'Tamar Bates', 'G', BasketballCardRole.guard, 70),
  _Seed('WAS', 'Anthony Davis', 'C/PF', BasketballCardRole.big, 91),
  _Seed('WAS', 'Deandre Ayton', 'C', BasketballCardRole.big, 84),
  _Seed('WAS', 'Bilal Coulibaly', 'F', BasketballCardRole.wing, 80),
  _Seed('WAS', 'Alex Sarr', 'F/C', BasketballCardRole.wing, 79),
  _Seed('WAS', 'Tre Johnson', 'G', BasketballCardRole.guard, 78),
  _Seed('WAS', 'Bub Carrington', 'G', BasketballCardRole.guard, 76),
];

BasketballAthlete _buildAthlete(_Seed seed) {
  final shootingNames = {
    'Stephen Curry',
    'Kevin Durant',
    'Tyrese Haliburton',
    'Devin Booker',
    'Klay Thompson',
    'Michael Porter Jr.',
    'Jamal Murray',
    'Trae Young',
    'Jalen Brunson',
  };
  final isShooter = shootingNames.contains(seed.name);
  final archetype = switch (seed.role) {
    BasketballCardRole.guard =>
      isShooter
          ? BasketballArchetype.sharpshooter
          : BasketballArchetype.balancedGuard,
    BasketballCardRole.wing =>
      isShooter
          ? BasketballArchetype.sharpshooter
          : BasketballArchetype.slasher,
    BasketballCardRole.big => BasketballArchetype.interiorPower,
  };
  final trait = switch (archetype) {
    BasketballArchetype.sharpshooter => BasketballTrait.deepRange,
    BasketballArchetype.balancedGuard => BasketballTrait.quickRelease,
    BasketballArchetype.slasher => BasketballTrait.rimPressure,
    BasketballArchetype.interiorPower => BasketballTrait.glassCleaner,
  };
  final heightM = switch (seed.role) {
    BasketballCardRole.guard => seed.position.contains('F') ? 1.96 : 1.91,
    BasketballCardRole.wing => seed.position.contains('PF') ? 2.06 : 2.03,
    BasketballCardRole.big =>
      seed.name == 'Victor Wembanyama'
          ? 2.24
          : seed.name == 'Kristaps Porzingis'
          ? 2.21
          : 2.11,
  };

  return BasketballAthlete(
    id: '${seed.teamCode.toLowerCase()}-${_slug(seed.name)}',
    name: seed.name,
    ovr: seed.ovr,
    teamName: _teamNames[seed.teamCode]!,
    teamCode: seed.teamCode,
    position: seed.position,
    cardRole: seed.role,
    archetype: archetype,
    trait: trait,
    tagline: _tagline(seed, trait),
    heightM: heightM,
    speed: _rating(seed.ovr, _speedDelta(seed.role)),
    handling: _rating(seed.ovr, _handlingDelta(seed.role, isShooter)),
    inside: _rating(seed.ovr, _insideDelta(seed.role)),
    mid: _rating(seed.ovr, isShooter ? 5 : _midDelta(seed.role)),
    three: _rating(seed.ovr, isShooter ? 8 : _threeDelta(seed.role)),
    dunk: _rating(seed.ovr, _dunkDelta(seed.role)),
    defense: _rating(seed.ovr, _defenseDelta(seed.role)),
    steal: _rating(seed.ovr, _stealDelta(seed.role)),
    block: _rating(seed.ovr, _blockDelta(seed.role)),
    rebound: _rating(seed.ovr, _reboundDelta(seed.role)),
    stamina: _rating(seed.ovr, seed.ovr >= 90 ? 3 : 0),
  );
}

String _tagline(_Seed seed, BasketballTrait trait) {
  final roleText = switch (seed.role) {
    BasketballCardRole.guard => 'Backcourt value',
    BasketballCardRole.wing => 'Two-way wing value',
    BasketballCardRole.big => 'Paint value',
  };
  final traitText = switch (trait) {
    BasketballTrait.quickRelease => 'quick-trigger reads',
    BasketballTrait.deepRange => 'deep-range pressure',
    BasketballTrait.rimPressure => 'rim pressure',
    BasketballTrait.glassCleaner => 'glass control',
  };
  return '$roleText with $traitText.';
}

int _rating(int ovr, int delta) => (ovr + delta).clamp(25, 99);

int _speedDelta(BasketballCardRole role) => switch (role) {
  BasketballCardRole.guard => 5,
  BasketballCardRole.wing => 2,
  BasketballCardRole.big => -12,
};

int _handlingDelta(BasketballCardRole role, bool shooter) => switch (role) {
  BasketballCardRole.guard => shooter ? 8 : 7,
  BasketballCardRole.wing => 2,
  BasketballCardRole.big => -10,
};

int _insideDelta(BasketballCardRole role) => switch (role) {
  BasketballCardRole.guard => -5,
  BasketballCardRole.wing => 1,
  BasketballCardRole.big => 8,
};

int _midDelta(BasketballCardRole role) => switch (role) {
  BasketballCardRole.guard => 2,
  BasketballCardRole.wing => 1,
  BasketballCardRole.big => -2,
};

int _threeDelta(BasketballCardRole role) => switch (role) {
  BasketballCardRole.guard => 3,
  BasketballCardRole.wing => 1,
  BasketballCardRole.big => -10,
};

int _dunkDelta(BasketballCardRole role) => switch (role) {
  BasketballCardRole.guard => -12,
  BasketballCardRole.wing => 3,
  BasketballCardRole.big => 7,
};

int _defenseDelta(BasketballCardRole role) => switch (role) {
  BasketballCardRole.guard => -4,
  BasketballCardRole.wing => 2,
  BasketballCardRole.big => 5,
};

int _stealDelta(BasketballCardRole role) => switch (role) {
  BasketballCardRole.guard => 2,
  BasketballCardRole.wing => 1,
  BasketballCardRole.big => -6,
};

int _blockDelta(BasketballCardRole role) => switch (role) {
  BasketballCardRole.guard => -25,
  BasketballCardRole.wing => -6,
  BasketballCardRole.big => 10,
};

int _reboundDelta(BasketballCardRole role) => switch (role) {
  BasketballCardRole.guard => -15,
  BasketballCardRole.wing => 1,
  BasketballCardRole.big => 10,
};

String _slug(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

const Map<String, String> _teamNames = {
  'ATL': 'Atlanta Hawks',
  'BOS': 'Boston Celtics',
  'BKN': 'Brooklyn Nets',
  'CHA': 'Charlotte Hornets',
  'CHI': 'Chicago Bulls',
  'CLE': 'Cleveland Cavaliers',
  'DAL': 'Dallas Mavericks',
  'DEN': 'Denver Nuggets',
  'DET': 'Detroit Pistons',
  'GSW': 'Golden State Warriors',
  'HOU': 'Houston Rockets',
  'IND': 'Indiana Pacers',
  'LAC': 'LA Clippers',
  'LAL': 'Los Angeles Lakers',
  'MEM': 'Memphis Grizzlies',
  'MIA': 'Miami Heat',
  'MIL': 'Milwaukee Bucks',
  'MIN': 'Minnesota Timberwolves',
  'NOP': 'New Orleans Pelicans',
  'NYK': 'New York Knicks',
  'OKC': 'Oklahoma City Thunder',
  'ORL': 'Orlando Magic',
  'PHI': 'Philadelphia 76ers',
  'PHX': 'Phoenix Suns',
  'POR': 'Portland Trail Blazers',
  'SAC': 'Sacramento Kings',
  'SAS': 'San Antonio Spurs',
  'TOR': 'Toronto Raptors',
  'UTA': 'Utah Jazz',
  'WAS': 'Washington Wizards',
};

/// On-court + card look for one athlete (content colors).
class BasketballAthleteLook {
  const BasketballAthleteLook({
    required this.accent,
    required this.skin,
    required this.hair,
  });

  /// Signature color used for the card trim and heat aura tint.
  final Color accent;
  final Color skin;
  final Color hair;
}

const Map<String, BasketballAthleteLook> _teamLooks = {
  'ATL': BasketballAthleteLook(
    accent: Color(0xFFE03A3E),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF17110D),
  ),
  'BOS': BasketballAthleteLook(
    accent: Color(0xFF007A33),
    skin: Color(0xFFC68642),
    hair: Color(0xFF191919),
  ),
  'BKN': BasketballAthleteLook(
    accent: Color(0xFFF5F5F5),
    skin: Color(0xFFE0AC69),
    hair: Color(0xFF1B1B22),
  ),
  'CHA': BasketballAthleteLook(
    accent: Color(0xFF1D8CAB),
    skin: Color(0xFFC68642),
    hair: Color(0xFF2B221B),
  ),
  'CHI': BasketballAthleteLook(
    accent: Color(0xFFCE1141),
    skin: Color(0xFFE0AC69),
    hair: Color(0xFF4B2E1F),
  ),
  'CLE': BasketballAthleteLook(
    accent: Color(0xFFFFB81C),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF151515),
  ),
  'DAL': BasketballAthleteLook(
    accent: Color(0xFF00538C),
    skin: Color(0xFFC68642),
    hair: Color(0xFF1D1714),
  ),
  'DEN': BasketballAthleteLook(
    accent: Color(0xFFFFC72C),
    skin: Color(0xFFE0AC69),
    hair: Color(0xFF5A3B26),
  ),
  'DET': BasketballAthleteLook(
    accent: Color(0xFFC8102E),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF111111),
  ),
  'GSW': BasketballAthleteLook(
    accent: Color(0xFFFFC72C),
    skin: Color(0xFFC68642),
    hair: Color(0xFF231A14),
  ),
  'HOU': BasketballAthleteLook(
    accent: Color(0xFFCE1141),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF141414),
  ),
  'IND': BasketballAthleteLook(
    accent: Color(0xFFFFC633),
    skin: Color(0xFFC68642),
    hair: Color(0xFF151515),
  ),
  'LAC': BasketballAthleteLook(
    accent: Color(0xFFC8102E),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF111111),
  ),
  'LAL': BasketballAthleteLook(
    accent: Color(0xFFFDB927),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF141414),
  ),
  'MEM': BasketballAthleteLook(
    accent: Color(0xFF5D76A9),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF111111),
  ),
  'MIA': BasketballAthleteLook(
    accent: Color(0xFF98002E),
    skin: Color(0xFF6B4423),
    hair: Color(0xFF181818),
  ),
  'MIL': BasketballAthleteLook(
    accent: Color(0xFF00471B),
    skin: Color(0xFFC68642),
    hair: Color(0xFF201914),
  ),
  'MIN': BasketballAthleteLook(
    accent: Color(0xFF78BE20),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF111111),
  ),
  'NOP': BasketballAthleteLook(
    accent: Color(0xFFC8102E),
    skin: Color(0xFF6B4423),
    hair: Color(0xFF111111),
  ),
  'NYK': BasketballAthleteLook(
    accent: Color(0xFFF58426),
    skin: Color(0xFFC68642),
    hair: Color(0xFF17120F),
  ),
  'OKC': BasketballAthleteLook(
    accent: Color(0xFFEF3B24),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF111111),
  ),
  'ORL': BasketballAthleteLook(
    accent: Color(0xFF0077C0),
    skin: Color(0xFFC68642),
    hair: Color(0xFF17120F),
  ),
  'PHI': BasketballAthleteLook(
    accent: Color(0xFF006BB6),
    skin: Color(0xFF6B4423),
    hair: Color(0xFF111111),
  ),
  'PHX': BasketballAthleteLook(
    accent: Color(0xFFE56020),
    skin: Color(0xFFC68642),
    hair: Color(0xFF17120F),
  ),
  'POR': BasketballAthleteLook(
    accent: Color(0xFFE03A3E),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF111111),
  ),
  'SAC': BasketballAthleteLook(
    accent: Color(0xFF5A2D81),
    skin: Color(0xFFE0AC69),
    hair: Color(0xFF5A3B26),
  ),
  'SAS': BasketballAthleteLook(
    accent: Color(0xFFC4CED4),
    skin: Color(0xFFE0AC69),
    hair: Color(0xFF2C221B),
  ),
  'TOR': BasketballAthleteLook(
    accent: Color(0xFFCE1141),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF151515),
  ),
  'UTA': BasketballAthleteLook(
    accent: Color(0xFFFFC72C),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF111111),
  ),
  'WAS': BasketballAthleteLook(
    accent: Color(0xFF002B5C),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF111111),
  ),
};

BasketballAthleteLook basketballLookFor(String id) {
  final athlete = basketballAthletes.where((item) => item.id == id).firstOrNull;
  return _teamLooks[athlete?.teamCode] ?? _teamLooks.values.first;
}
