import 'dart:math';

import '../models/cards.dart';
import '../models/guess_player.dart';
import '../models/sport_match.dart';

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

const List<GuessPlayerTimeline> footballGuessTimelines = [
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
  GuessPlayerTimeline(
    playerName: 'Lautaro Martínez',
    career: [
      ClubSpell(clubName: 'Racing Club', startYear: 2015),
      ClubSpell(clubName: 'Inter', startYear: 2018),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Julián Álvarez',
    career: [
      ClubSpell(clubName: 'River Plate', startYear: 2018),
      ClubSpell(clubName: 'Man City', startYear: 2022),
      ClubSpell(clubName: 'Atlético Madrid', startYear: 2024),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Rodrigo De Paul',
    career: [
      ClubSpell(clubName: 'Racing Club', startYear: 2012),
      ClubSpell(clubName: 'Valencia', startYear: 2014),
      ClubSpell(clubName: 'Udinese', startYear: 2016),
      ClubSpell(clubName: 'Atlético Madrid', startYear: 2021),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Enzo Fernández',
    career: [
      ClubSpell(clubName: 'River Plate', startYear: 2019),
      ClubSpell(clubName: 'Defensa y Justicia', startYear: 2020),
      ClubSpell(clubName: 'River Plate', startYear: 2021),
      ClubSpell(clubName: 'Benfica', startYear: 2022),
      ClubSpell(clubName: 'Chelsea', startYear: 2023),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Alexis Mac Allister',
    career: [
      ClubSpell(clubName: 'Argentinos Juniors', startYear: 2016),
      ClubSpell(clubName: 'Brighton', startYear: 2019),
      ClubSpell(clubName: 'Boca Juniors', startYear: 2019),
      ClubSpell(clubName: 'Brighton', startYear: 2020),
      ClubSpell(clubName: 'Liverpool', startYear: 2023),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Neymar',
    career: [
      ClubSpell(clubName: 'Santos', startYear: 2009),
      ClubSpell(clubName: 'Barcelona', startYear: 2013),
      ClubSpell(clubName: 'Paris SG', startYear: 2017),
      ClubSpell(clubName: 'Al Hilal', startYear: 2023),
      ClubSpell(clubName: 'Santos', startYear: 2025),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Raphinha',
    career: [
      ClubSpell(clubName: 'Avaí', startYear: 2016),
      ClubSpell(clubName: 'Vitória Guimarães', startYear: 2016),
      ClubSpell(clubName: 'Sporting CP', startYear: 2017),
      ClubSpell(clubName: 'Rennes', startYear: 2018),
      ClubSpell(clubName: 'Leeds United', startYear: 2020),
      ClubSpell(clubName: 'Barcelona', startYear: 2022),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Bruno Guimarães',
    career: [
      ClubSpell(clubName: 'Audax', startYear: 2015),
      ClubSpell(clubName: 'Athletico Paranaense', startYear: 2017),
      ClubSpell(clubName: 'Lyon', startYear: 2020),
      ClubSpell(clubName: 'Newcastle United', startYear: 2022),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Matheus Cunha',
    career: [
      ClubSpell(clubName: 'Coritiba', startYear: 2017),
      ClubSpell(clubName: 'Sion', startYear: 2018),
      ClubSpell(clubName: 'RB Leipzig', startYear: 2018),
      ClubSpell(clubName: 'Hertha Berlin', startYear: 2020),
      ClubSpell(clubName: 'Atlético Madrid', startYear: 2021),
      ClubSpell(clubName: 'Wolves', startYear: 2023),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Kylian Mbappé',
    career: [
      ClubSpell(clubName: 'Monaco', startYear: 2015),
      ClubSpell(clubName: 'Paris SG', startYear: 2017),
      ClubSpell(clubName: 'Real Madrid', startYear: 2024),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Ousmane Dembélé',
    career: [
      ClubSpell(clubName: 'Rennes', startYear: 2015),
      ClubSpell(clubName: 'Dortmund', startYear: 2016),
      ClubSpell(clubName: 'Barcelona', startYear: 2017),
      ClubSpell(clubName: 'Paris SG', startYear: 2023),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Michael Olise',
    career: [
      ClubSpell(clubName: 'Reading', startYear: 2017),
      ClubSpell(clubName: 'Crystal Palace', startYear: 2021),
      ClubSpell(clubName: 'Bayern Munich', startYear: 2024),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Bukayo Saka',
    career: [ClubSpell(clubName: 'Arsenal', startYear: 2018)],
  ),
  GuessPlayerTimeline(
    playerName: 'Phil Foden',
    career: [ClubSpell(clubName: 'Man City', startYear: 2017)],
  ),
  GuessPlayerTimeline(
    playerName: 'Marcus Rashford',
    career: [
      ClubSpell(clubName: 'Man United', startYear: 2015),
      ClubSpell(clubName: 'Aston Villa', startYear: 2025),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Cole Palmer',
    career: [
      ClubSpell(clubName: 'Man City', startYear: 2020),
      ClubSpell(clubName: 'Chelsea', startYear: 2023),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Rafael Leão',
    career: [
      ClubSpell(clubName: 'Sporting CP', startYear: 2017),
      ClubSpell(clubName: 'Lille', startYear: 2018),
      ClubSpell(clubName: 'AC Milan', startYear: 2019),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Bruno Fernandes',
    career: [
      ClubSpell(clubName: 'Novara', startYear: 2012),
      ClubSpell(clubName: 'Udinese', startYear: 2013),
      ClubSpell(clubName: 'Sampdoria', startYear: 2016),
      ClubSpell(clubName: 'Sporting CP', startYear: 2017),
      ClubSpell(clubName: 'Man United', startYear: 2020),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Bernardo Silva',
    career: [
      ClubSpell(clubName: 'Benfica', startYear: 2013),
      ClubSpell(clubName: 'Monaco', startYear: 2014),
      ClubSpell(clubName: 'Man City', startYear: 2017),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Vitinha',
    career: [
      ClubSpell(clubName: 'Porto', startYear: 2020),
      ClubSpell(clubName: 'Wolves', startYear: 2020),
      ClubSpell(clubName: 'Porto', startYear: 2021),
      ClubSpell(clubName: 'Paris SG', startYear: 2022),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Lamine Yamal',
    career: [ClubSpell(clubName: 'Barcelona', startYear: 2023)],
  ),
  GuessPlayerTimeline(
    playerName: 'Nico Williams',
    career: [ClubSpell(clubName: 'Athletic Club', startYear: 2021)],
  ),
  GuessPlayerTimeline(
    playerName: 'Pedri González',
    career: [
      ClubSpell(clubName: 'Las Palmas', startYear: 2019),
      ClubSpell(clubName: 'Barcelona', startYear: 2020),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Mikel Oyarzabal',
    career: [ClubSpell(clubName: 'Real Sociedad', startYear: 2015)],
  ),
  GuessPlayerTimeline(
    playerName: 'Jamal Musiala',
    career: [ClubSpell(clubName: 'Bayern Munich', startYear: 2020)],
  ),
];

const List<GuessPlayerTimeline> basketballGuessTimelines = [
  GuessPlayerTimeline(
    playerName: 'LeBron James',
    career: [
      ClubSpell(clubName: 'Cleveland', startYear: 2003),
      ClubSpell(clubName: 'Miami Heat', startYear: 2010),
      ClubSpell(clubName: 'Cleveland', startYear: 2014),
      ClubSpell(clubName: 'LA Lakers', startYear: 2018),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Kevin Durant',
    career: [
      ClubSpell(clubName: 'Seattle', startYear: 2007),
      ClubSpell(clubName: 'Oklahoma', startYear: 2008),
      ClubSpell(clubName: 'Golden State', startYear: 2016),
      ClubSpell(clubName: 'Brooklyn', startYear: 2019),
      ClubSpell(clubName: 'Phoenix', startYear: 2023),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Jayson Tatum',
    career: [ClubSpell(clubName: 'Boston', startYear: 2017)],
  ),
  GuessPlayerTimeline(
    playerName: 'Nikola Jokic',
    career: [
      ClubSpell(clubName: 'Mega Basket', startYear: 2012),
      ClubSpell(clubName: 'Denver', startYear: 2015),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Shai Gilgeous-Alexander',
    career: [
      ClubSpell(clubName: 'Kentucky', startYear: 2017),
      ClubSpell(clubName: 'LA Clippers', startYear: 2018),
      ClubSpell(clubName: 'Oklahoma City', startYear: 2019),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Luka Doncic',
    career: [
      ClubSpell(clubName: 'Real Madrid', startYear: 2015),
      ClubSpell(clubName: 'Dallas', startYear: 2018),
      ClubSpell(clubName: 'LA Lakers', startYear: 2025),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Victor Wembanyama',
    career: [
      ClubSpell(clubName: 'Nanterre 92', startYear: 2019),
      ClubSpell(clubName: 'ASVEL', startYear: 2021),
      ClubSpell(clubName: 'Metropolitans 92', startYear: 2022),
      ClubSpell(clubName: 'San Antonio', startYear: 2023),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Giannis Antetokounmpo',
    career: [
      ClubSpell(clubName: 'Filathlitikos', startYear: 2011),
      ClubSpell(clubName: 'Milwaukee', startYear: 2013),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Stephen Curry',
    career: [
      ClubSpell(clubName: 'Davidson', startYear: 2006),
      ClubSpell(clubName: 'Golden State', startYear: 2009),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Anthony Edwards',
    career: [
      ClubSpell(clubName: 'Georgia', startYear: 2020),
      ClubSpell(clubName: 'Minnesota', startYear: 2020),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Donovan Mitchell',
    career: [
      ClubSpell(clubName: 'Louisville', startYear: 2015),
      ClubSpell(clubName: 'Utah', startYear: 2017),
      ClubSpell(clubName: 'Cleveland', startYear: 2022),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Jalen Brunson',
    career: [
      ClubSpell(clubName: 'Villanova', startYear: 2015),
      ClubSpell(clubName: 'Dallas', startYear: 2018),
      ClubSpell(clubName: 'New York', startYear: 2022),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Joel Embiid',
    career: [
      ClubSpell(clubName: 'Kansas', startYear: 2013),
      ClubSpell(clubName: 'Philadelphia', startYear: 2014),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Devin Booker',
    career: [
      ClubSpell(clubName: 'Kentucky', startYear: 2014),
      ClubSpell(clubName: 'Phoenix', startYear: 2015),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Cade Cunningham',
    career: [
      ClubSpell(clubName: 'Oklahoma State', startYear: 2020),
      ClubSpell(clubName: 'Detroit', startYear: 2021),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Trae Young',
    career: [
      ClubSpell(clubName: 'Oklahoma', startYear: 2017),
      ClubSpell(clubName: 'Atlanta', startYear: 2018),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Bam Adebayo',
    career: [
      ClubSpell(clubName: 'Kentucky', startYear: 2016),
      ClubSpell(clubName: 'Miami', startYear: 2017),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Tyler Herro',
    career: [
      ClubSpell(clubName: 'Kentucky', startYear: 2018),
      ClubSpell(clubName: 'Miami', startYear: 2019),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Kyrie Irving',
    career: [
      ClubSpell(clubName: 'Duke', startYear: 2010),
      ClubSpell(clubName: 'Cleveland', startYear: 2011),
      ClubSpell(clubName: 'Boston', startYear: 2017),
      ClubSpell(clubName: 'Brooklyn', startYear: 2019),
      ClubSpell(clubName: 'Dallas', startYear: 2023),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Kawhi Leonard',
    career: [
      ClubSpell(clubName: 'San Diego State', startYear: 2009),
      ClubSpell(clubName: 'San Antonio', startYear: 2011),
      ClubSpell(clubName: 'Toronto', startYear: 2018),
      ClubSpell(clubName: 'LA Clippers', startYear: 2019),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'James Harden',
    career: [
      ClubSpell(clubName: 'Arizona State', startYear: 2007),
      ClubSpell(clubName: 'Oklahoma City', startYear: 2009),
      ClubSpell(clubName: 'Houston', startYear: 2012),
      ClubSpell(clubName: 'Brooklyn', startYear: 2021),
      ClubSpell(clubName: 'Philadelphia', startYear: 2022),
      ClubSpell(clubName: 'LA Clippers', startYear: 2023),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Klay Thompson',
    career: [
      ClubSpell(clubName: 'Washington State', startYear: 2008),
      ClubSpell(clubName: 'Golden State', startYear: 2011),
      ClubSpell(clubName: 'Dallas', startYear: 2024),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Jamal Murray',
    career: [
      ClubSpell(clubName: 'Kentucky', startYear: 2015),
      ClubSpell(clubName: 'Denver', startYear: 2016),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Derrick White',
    career: [
      ClubSpell(clubName: 'Colorado', startYear: 2012),
      ClubSpell(clubName: 'San Antonio', startYear: 2017),
      ClubSpell(clubName: 'Boston', startYear: 2022),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Jaylen Brown',
    career: [
      ClubSpell(clubName: 'California', startYear: 2015),
      ClubSpell(clubName: 'Boston', startYear: 2016),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Pascal Siakam',
    career: [
      ClubSpell(clubName: 'New Mexico State', startYear: 2014),
      ClubSpell(clubName: 'Toronto', startYear: 2016),
      ClubSpell(clubName: 'Indiana', startYear: 2024),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Karl-Anthony Towns',
    career: [
      ClubSpell(clubName: 'Kentucky', startYear: 2014),
      ClubSpell(clubName: 'Minnesota', startYear: 2015),
      ClubSpell(clubName: 'New York', startYear: 2024),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Paul George',
    career: [
      ClubSpell(clubName: 'Fresno State', startYear: 2008),
      ClubSpell(clubName: 'Indiana', startYear: 2010),
      ClubSpell(clubName: 'Oklahoma City', startYear: 2017),
      ClubSpell(clubName: 'LA Clippers', startYear: 2019),
      ClubSpell(clubName: 'Philadelphia', startYear: 2024),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Zion Williamson',
    career: [
      ClubSpell(clubName: 'Duke', startYear: 2018),
      ClubSpell(clubName: 'New Orleans', startYear: 2019),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'LaMelo Ball',
    career: [
      ClubSpell(clubName: 'Illawarra Hawks', startYear: 2019),
      ClubSpell(clubName: 'Charlotte', startYear: 2020),
    ],
  ),
];

const List<GuessPlayerTimeline> cricketGuessTimelines = [
  GuessPlayerTimeline(
    playerName: 'Virat Kohli',
    career: [
      ClubSpell(clubName: 'Delhi', startYear: 2006),
      ClubSpell(clubName: 'India U19', startYear: 2008),
      ClubSpell(clubName: 'RCB', startYear: 2008),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Suryakumar Yadav',
    career: [
      ClubSpell(clubName: 'Mumbai', startYear: 2010),
      ClubSpell(clubName: 'MI', startYear: 2012),
      ClubSpell(clubName: 'KKR', startYear: 2014),
      ClubSpell(clubName: 'MI', startYear: 2018),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Shubman Gill',
    career: [
      ClubSpell(clubName: 'Punjab', startYear: 2017),
      ClubSpell(clubName: 'KKR', startYear: 2018),
      ClubSpell(clubName: 'GT', startYear: 2022),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Heinrich Klaasen',
    career: [
      ClubSpell(clubName: 'Titans', startYear: 2011),
      ClubSpell(clubName: 'Chennai Super Kings', startYear: 2018),
      ClubSpell(clubName: 'Royal Challengers Bengaluru', startYear: 2019),
      ClubSpell(clubName: 'Rajasthan Royals', startYear: 2020),
      ClubSpell(clubName: 'Punjab Kings', startYear: 2021),
      ClubSpell(clubName: 'Sunrisers Hyderabad', startYear: 2023),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Rohit Sharma',
    career: [
      ClubSpell(clubName: 'Deccan Chargers', startYear: 2008),
      ClubSpell(clubName: 'Mumbai Indians', startYear: 2011),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Sunil Narine',
    career: [
      ClubSpell(clubName: 'Trinidad and Tobago', startYear: 2009),
      ClubSpell(clubName: 'Kolkata Knight Riders', startYear: 2012),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Ravindra Jadeja',
    career: [
      ClubSpell(clubName: 'Rajasthan Royals', startYear: 2008),
      ClubSpell(clubName: 'Kochi Tuskers Kerala', startYear: 2011),
      ClubSpell(clubName: 'Chennai Super Kings', startYear: 2012),
      ClubSpell(clubName: 'Gujarat Lions', startYear: 2016),
      ClubSpell(clubName: 'Chennai Super Kings', startYear: 2018),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Rishabh Pant',
    career: [
      ClubSpell(clubName: 'Delhi Capitals', startYear: 2016),
      ClubSpell(clubName: 'Lucknow Super Giants', startYear: 2025),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Jos Buttler',
    career: [
      ClubSpell(clubName: 'Mumbai Indians', startYear: 2016),
      ClubSpell(clubName: 'Rajasthan Royals', startYear: 2018),
      ClubSpell(clubName: 'Gujarat Titans', startYear: 2025),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Hardik Pandya',
    career: [
      ClubSpell(clubName: 'Mumbai Indians', startYear: 2015),
      ClubSpell(clubName: 'Gujarat Titans', startYear: 2022),
      ClubSpell(clubName: 'Mumbai Indians', startYear: 2024),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Travis Head',
    career: [
      ClubSpell(clubName: 'South Australia', startYear: 2009),
      ClubSpell(clubName: 'Delhi Capitals', startYear: 2016),
      ClubSpell(clubName: 'Royal Challengers Bengaluru', startYear: 2017),
      ClubSpell(clubName: 'Sunrisers Hyderabad', startYear: 2024),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Nicholas Pooran',
    career: [
      ClubSpell(clubName: 'Trinidad and Tobago', startYear: 2012),
      ClubSpell(clubName: 'Punjab Kings', startYear: 2021),
      ClubSpell(clubName: 'Sunrisers Hyderabad', startYear: 2022),
      ClubSpell(clubName: 'Lucknow Super Giants', startYear: 2023),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'MS Dhoni',
    career: [
      ClubSpell(clubName: 'Bihar', startYear: 1999),
      ClubSpell(clubName: 'Jharkhand', startYear: 2004),
      ClubSpell(clubName: 'Chennai Super Kings', startYear: 2008),
      ClubSpell(clubName: 'Rising Pune Supergiant', startYear: 2016),
      ClubSpell(clubName: 'Chennai Super Kings', startYear: 2018),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Sanju Samson',
    career: [
      ClubSpell(clubName: 'Kerala', startYear: 2011),
      ClubSpell(clubName: 'Kolkata Knight Riders', startYear: 2012),
      ClubSpell(clubName: 'Rajasthan Royals', startYear: 2013),
      ClubSpell(clubName: 'Delhi Daredevils', startYear: 2016),
      ClubSpell(clubName: 'Rajasthan Royals', startYear: 2018),
      ClubSpell(clubName: 'Chennai Super Kings', startYear: 2025),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Yashasvi Jaiswal',
    career: [
      ClubSpell(clubName: 'Mumbai', startYear: 2019),
      ClubSpell(clubName: 'Rajasthan Royals', startYear: 2020),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'KL Rahul',
    career: [
      ClubSpell(clubName: 'Karnataka', startYear: 2010),
      ClubSpell(clubName: 'Royal Challengers Bengaluru', startYear: 2013),
      ClubSpell(clubName: 'Sunrisers Hyderabad', startYear: 2014),
      ClubSpell(clubName: 'Royal Challengers Bengaluru', startYear: 2016),
      ClubSpell(clubName: 'Punjab Kings', startYear: 2018),
      ClubSpell(clubName: 'Lucknow Super Giants', startYear: 2022),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Ruturaj Gaikwad',
    career: [
      ClubSpell(clubName: 'Maharashtra', startYear: 2016),
      ClubSpell(clubName: 'Chennai Super Kings', startYear: 2019),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Quinton de Kock',
    career: [
      ClubSpell(clubName: 'Sunrisers Hyderabad', startYear: 2014),
      ClubSpell(clubName: 'Delhi Capitals', startYear: 2016),
      ClubSpell(clubName: 'Royal Challengers Bengaluru', startYear: 2019),
      ClubSpell(clubName: 'Mumbai Indians', startYear: 2020),
      ClubSpell(clubName: 'Lucknow Super Giants', startYear: 2022),
      ClubSpell(clubName: 'Mumbai Indians', startYear: 2025),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Rinku Singh',
    career: [
      ClubSpell(clubName: 'Uttar Pradesh', startYear: 2014),
      ClubSpell(clubName: 'Kolkata Knight Riders', startYear: 2018),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Abhishek Sharma',
    career: [
      ClubSpell(clubName: 'Punjab', startYear: 2017),
      ClubSpell(clubName: 'Delhi Capitals', startYear: 2018),
      ClubSpell(clubName: 'Sunrisers Hyderabad', startYear: 2022),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Sam Curran',
    career: [
      ClubSpell(clubName: 'Surrey', startYear: 2015),
      ClubSpell(clubName: 'Punjab Kings', startYear: 2019),
      ClubSpell(clubName: 'Chennai Super Kings', startYear: 2020),
      ClubSpell(clubName: 'Punjab Kings', startYear: 2023),
      ClubSpell(clubName: 'Rajasthan Royals', startYear: 2025),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Axar Patel',
    career: [
      ClubSpell(clubName: 'Gujarat', startYear: 2010),
      ClubSpell(clubName: 'Mumbai Indians', startYear: 2013),
      ClubSpell(clubName: 'Punjab Kings', startYear: 2014),
      ClubSpell(clubName: 'Delhi Capitals', startYear: 2019),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Shreyas Iyer',
    career: [
      ClubSpell(clubName: 'Mumbai', startYear: 2014),
      ClubSpell(clubName: 'Delhi Capitals', startYear: 2015),
      ClubSpell(clubName: 'Kolkata Knight Riders', startYear: 2022),
      ClubSpell(clubName: 'Punjab Kings', startYear: 2025),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Shivam Dube',
    career: [
      ClubSpell(clubName: 'Mumbai', startYear: 2011),
      ClubSpell(clubName: 'Royal Challengers Bengaluru', startYear: 2019),
      ClubSpell(clubName: 'Rajasthan Royals', startYear: 2021),
      ClubSpell(clubName: 'Chennai Super Kings', startYear: 2022),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Phil Salt',
    career: [
      ClubSpell(clubName: 'Sussex', startYear: 2013),
      ClubSpell(clubName: 'Delhi Capitals', startYear: 2020),
      ClubSpell(clubName: 'Kolkata Knight Riders', startYear: 2023),
      ClubSpell(clubName: 'Royal Challengers Bengaluru', startYear: 2025),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Cameron Green',
    career: [
      ClubSpell(clubName: 'Western Australia', startYear: 2016),
      ClubSpell(clubName: 'Mumbai Indians', startYear: 2023),
      ClubSpell(clubName: 'Royal Challengers Bengaluru', startYear: 2024),
      ClubSpell(clubName: 'Kolkata Knight Riders', startYear: 2025),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Riyan Parag',
    career: [
      ClubSpell(clubName: 'Assam', startYear: 2017),
      ClubSpell(clubName: 'Rajasthan Royals', startYear: 2019),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'David Miller',
    career: [
      ClubSpell(clubName: 'Dolphins', startYear: 2008),
      ClubSpell(clubName: 'Punjab Kings', startYear: 2012),
      ClubSpell(clubName: 'Rajasthan Royals', startYear: 2020),
      ClubSpell(clubName: 'Gujarat Titans', startYear: 2022),
      ClubSpell(clubName: 'Delhi Capitals', startYear: 2025),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Marcus Stoinis',
    career: [
      ClubSpell(clubName: 'Western Australia', startYear: 2009),
      ClubSpell(clubName: 'Delhi Capitals', startYear: 2015),
      ClubSpell(clubName: 'Punjab Kings', startYear: 2016),
      ClubSpell(clubName: 'Royal Challengers Bengaluru', startYear: 2019),
      ClubSpell(clubName: 'Lucknow Super Giants', startYear: 2022),
      ClubSpell(clubName: 'Punjab Kings', startYear: 2025),
    ],
  ),
  GuessPlayerTimeline(
    playerName: 'Wanindu Hasaranga',
    career: [
      ClubSpell(clubName: 'Sri Lanka', startYear: 2017),
      ClubSpell(clubName: 'Royal Challengers Bengaluru', startYear: 2021),
      ClubSpell(clubName: 'Rajasthan Royals', startYear: 2022),
      ClubSpell(clubName: 'Royal Challengers Bengaluru', startYear: 2024),
      ClubSpell(clubName: 'Lucknow Super Giants', startYear: 2025),
    ],
  ),
];

abstract interface class GuessPlayerPuzzleRepository {
  List<GuessPlayerPuzzle> get puzzles;

  GuessPlayerPuzzle? puzzleById(String id);

  GuessPlayerPuzzle puzzleForDay(DateTime day);

  List<String> validate();
}

/// Local, versioned daily deck. Every route is authored from career stops;
/// profile data belongs exclusively to the paid intel scans in the play UI.
class LocalGuessPlayerPuzzleRepository implements GuessPlayerPuzzleRepository {
  LocalGuessPlayerPuzzleRepository({
    required this.sport,
    required this.timelines,
    required this.players,
  }) : puzzles = _buildPuzzles(sport, timelines, players);

  static const int minimumDeckSize = 30;
  static const String scheduleVersion = 'career-intel-v2';

  final Sport sport;
  final List<GuessPlayerTimeline> timelines;
  final List<PlayerCard> players;

  @override
  final List<GuessPlayerPuzzle> puzzles;

  late final List<GuessPlayerPuzzle> _scheduled = [...puzzles]
    ..sort((a, b) {
      final aHash = _stableHash('$scheduleVersion:${sport.name}:${a.id}');
      final bHash = _stableHash('$scheduleVersion:${sport.name}:${b.id}');
      final byHash = aHash.compareTo(bHash);
      return byHash != 0 ? byHash : a.id.compareTo(b.id);
    });

  @override
  GuessPlayerPuzzle? puzzleById(String id) {
    for (final puzzle in puzzles) {
      if (puzzle.id == id) return puzzle;
    }
    return null;
  }

  @override
  GuessPlayerPuzzle puzzleForDay(DateTime day) {
    if (_scheduled.isEmpty) {
      throw StateError('Guess Player has no ${sport.name} puzzles.');
    }
    final normalized = DateTime.utc(day.year, day.month, day.day);
    final days = normalized.difference(DateTime.utc(2024)).inDays;
    final index =
        ((days % _scheduled.length) + _scheduled.length) % _scheduled.length;
    return _scheduled[index];
  }

  @override
  List<String> validate() {
    final issues = <String>[];
    if (puzzles.length < minimumDeckSize) {
      issues.add(
        '${sport.name} requires $minimumDeckSize puzzles; found ${puzzles.length}.',
      );
    }
    final difficultyCounts = {
      for (final difficulty in GuessPlayerDifficulty.values)
        difficulty: puzzles
            .where((puzzle) => puzzle.difficulty == difficulty)
            .length,
    };
    if (difficultyCounts.values.isNotEmpty &&
        difficultyCounts.values.reduce(max) -
                difficultyCounts.values.reduce(min) >
            1) {
      issues.add('${sport.name} puzzle difficulties are not balanced.');
    }
    final ids = <String>{};
    final playerIds = players.map((player) => player.id).toSet();
    for (final puzzle in puzzles) {
      if (!ids.add(puzzle.id)) {
        issues.add('Duplicate puzzle id: ${puzzle.id}.');
      }
      if (puzzle.sport != sport) {
        issues.add('${puzzle.id} belongs to the wrong sport.');
      }
      if (!playerIds.contains(puzzle.playerId)) {
        issues.add('${puzzle.id} targets missing player ${puzzle.playerId}.');
      }
      if (puzzle.clues.length != 6) {
        issues.add('${puzzle.id} must contain exactly six clues.');
      }
      if (puzzle.clues.any(
        (clue) => clue.label.trim().isEmpty || clue.value.trim().isEmpty,
      )) {
        issues.add('${puzzle.id} contains an empty clue.');
      }
      if (puzzle.clues.any((clue) => clue.kind != GuessPlayerClueKind.career)) {
        issues.add('${puzzle.id} contains non-career route intel.');
      }
      final clueKeys = puzzle.clues
          .map(
            (clue) =>
                '${clue.kind.name}:${clue.value.toLowerCase()}:${clue.year}',
          )
          .toSet();
      if (clueKeys.length != puzzle.clues.length) {
        issues.add('${puzzle.id} contains a repeated clue.');
      }
      final player = players
          .where((candidate) => candidate.id == puzzle.playerId)
          .firstOrNull;
      final forbidden = player?.name.toLowerCase();
      if (forbidden != null &&
          puzzle.clues.any(
            (clue) => clue.value.toLowerCase().contains(forbidden),
          )) {
        issues.add('${puzzle.id} contains the answer in a clue.');
      }
      final years = puzzle.clues
          .map((clue) => clue.year)
          .whereType<int>()
          .toList();
      for (var i = 1; i < years.length; i++) {
        if (years[i] < years[i - 1]) {
          issues.add('${puzzle.id} career clues are not chronological.');
          break;
        }
      }
    }
    return issues;
  }
}

List<GuessPlayerPuzzle> _buildPuzzles(
  Sport sport,
  List<GuessPlayerTimeline> timelines,
  List<PlayerCard> players,
) {
  final byName = {for (final player in players) player.name: player};
  final selected = <PlayerCard>[];
  final seen = <String>{};

  for (final timeline in timelines) {
    final player = byName[timeline.playerName];
    if (player != null && seen.add(player.id)) selected.add(player);
  }

  final ranked = [...players]
    ..sort((a, b) {
      final rating = b.rating.compareTo(a.rating);
      return rating != 0 ? rating : a.name.compareTo(b.name);
    });
  for (final player in ranked) {
    if (selected.length >= LocalGuessPlayerPuzzleRepository.minimumDeckSize) {
      break;
    }
    if (seen.add(player.id)) selected.add(player);
  }

  return [
    for (var index = 0; index < selected.length; index++)
      _puzzleFor(
        sport,
        selected[index],
        timelines
            .where((timeline) => timeline.playerName == selected[index].name)
            .firstOrNull,
        index,
      ),
  ];
}

GuessPlayerPuzzle _puzzleFor(
  Sport sport,
  PlayerCard player,
  GuessPlayerTimeline? timeline,
  int index,
) {
  final clues = <GuessPlayerClue>[];

  void add(GuessPlayerClue clue) {
    if (clues.length >= 6) return;
    final duplicate = clues.any(
      (item) =>
          item.kind == clue.kind &&
          item.value == clue.value &&
          item.year == clue.year,
    );
    if (!duplicate) clues.add(clue);
  }

  final career = timeline?.career ?? const <ClubSpell>[];
  for (var careerIndex = 0; careerIndex < career.length; careerIndex++) {
    final spell = career[careerIndex];
    final nextStart = careerIndex + 1 < career.length
        ? career[careerIndex + 1].startYear
        : null;
    add(
      GuessPlayerClue(
        kind: GuessPlayerClueKind.career,
        label: careerIndex == 0
            ? 'CAREER ORIGIN'
            : 'CAREER MOVE ${careerIndex + 1}',
        value: spell.clubName.toUpperCase(),
        year: spell.startYear,
        endYear: nextStart == null ? null : max(spell.startYear, nextStart - 1),
      ),
    );
  }

  // Six attempts remain constant even for a short career. These neutral route
  // markers make the completed path honest without leaking non-career stats.
  while (clues.length < 6) {
    clues.add(
      GuessPlayerClue(
        kind: GuessPlayerClueKind.career,
        label: 'CAREER ARCHIVE ${clues.length + 1}',
        value: 'ROUTE COMPLETE // ${clues.length + 1}',
      ),
    );
  }

  final difficulty = switch (index % 3) {
    0 => GuessPlayerDifficulty.easy,
    1 => GuessPlayerDifficulty.medium,
    _ => GuessPlayerDifficulty.hard,
  };
  return GuessPlayerPuzzle(
    id: '${sport.name}-${player.id}',
    sport: sport,
    playerId: player.id,
    difficulty: difficulty,
    clues: List.unmodifiable(clues.take(6)),
  );
}

int _stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}
