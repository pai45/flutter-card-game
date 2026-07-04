class ClubSpell {
  final String clubName;
  final int startYear;

  const ClubSpell({required this.clubName, required this.startYear});
}

class GuessPlayerTimeline {
  final String playerName; // Matches the name in players.csv
  final List<ClubSpell> career;

  const GuessPlayerTimeline({required this.playerName, required this.career});
}

const List<GuessPlayerTimeline> guessPlayerTimelines = [
  GuessPlayerTimeline(
    playerName: 'Lionel Messi',
    career: [
      ClubSpell(clubName: 'Barcelona', startYear: 2004),
      ClubSpell(clubName: 'Paris SG', startYear: 2021),
      ClubSpell(clubName: 'Inter Miami', startYear: 2023),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Cristiano Ronaldo',
    career: [
      ClubSpell(clubName: 'Sporting CP', startYear: 2002),
      ClubSpell(clubName: 'Man United', startYear: 2003),
      ClubSpell(clubName: 'Real Madrid', startYear: 2009),
      ClubSpell(clubName: 'Juventus', startYear: 2018),
      ClubSpell(clubName: 'Man United', startYear: 2021),
      ClubSpell(clubName: 'Al Nassr', startYear: 2023),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Kevin De Bruyne',
    career: [
      ClubSpell(clubName: 'Genk', startYear: 2008),
      ClubSpell(clubName: 'Chelsea', startYear: 2012),
      ClubSpell(clubName: 'Werder Bremen', startYear: 2012),
      ClubSpell(clubName: 'VfL Wolfsburg', startYear: 2014),
      ClubSpell(clubName: 'Man City', startYear: 2015),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Jude Bellingham',
    career: [
      ClubSpell(clubName: 'Birmingham', startYear: 2019),
      ClubSpell(clubName: 'Dortmund', startYear: 2020),
      ClubSpell(clubName: 'Real Madrid', startYear: 2023),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Harry Kane',
    career: [
      ClubSpell(clubName: 'Tottenham', startYear: 2009),
      ClubSpell(clubName: 'Leyton Orient', startYear: 2011),
      ClubSpell(clubName: 'Millwall', startYear: 2012),
      ClubSpell(clubName: 'Norwich', startYear: 2012),
      ClubSpell(clubName: 'Leicester', startYear: 2013),
      ClubSpell(clubName: 'Bayern Munich', startYear: 2023),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Vinícius Júnior',
    career: [
      ClubSpell(clubName: 'Flamengo', startYear: 2017),
      ClubSpell(clubName: 'Real Madrid', startYear: 2018),
    ],
  ),
];
