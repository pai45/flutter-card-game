import 'dart:io';
import 'dart:math';

void main() {
  final prominentPlayers = [
    // CSK
    ['MS Dhoni', 'MSD', 'CSK', 'Wicket-keeper', 90],
    ['Ruturaj Gaikwad', 'R Gaikwad', 'CSK', 'Batsman', 88],
    ['Ravindra Jadeja', 'R Jadeja', 'CSK', 'All-rounder', 91],
    ['Matheesha Pathirana', 'M Pathirana', 'CSK', 'Bowler', 87],
    ['Shivam Dube', 'S Dube', 'CSK', 'All-rounder', 86],
    // MI
    ['Rohit Sharma', 'R Sharma', 'MI', 'Batsman', 91],
    ['Suryakumar Yadav', 'SKY', 'MI', 'Batsman', 93],
    ['Jasprit Bumrah', 'J Bumrah', 'MI', 'Bowler', 94],
    ['Hardik Pandya', 'H Pandya', 'MI', 'All-rounder', 89],
    ['Ishan Kishan', 'I Kishan', 'MI', 'Wicket-keeper', 86],
    // RCB
    ['Virat Kohli', 'V Kohli', 'RCB', 'Batsman', 94],
    ['Faf du Plessis', 'F du Plessis', 'RCB', 'Batsman', 88],
    ['Glenn Maxwell', 'G Maxwell', 'RCB', 'All-rounder', 89],
    ['Mohammed Siraj', 'M Siraj', 'RCB', 'Bowler', 87],
    ['Rajat Patidar', 'R Patidar', 'RCB', 'Batsman', 85],
    // KKR
    ['Shreyas Iyer', 'S Iyer', 'KKR', 'Batsman', 87],
    ['Andre Russell', 'A Russell', 'KKR', 'All-rounder', 90],
    ['Sunil Narine', 'S Narine', 'KKR', 'All-rounder', 91],
    ['Mitchell Starc', 'M Starc', 'KKR', 'Bowler', 89],
    ['Rinku Singh', 'R Singh', 'KKR', 'Batsman', 88],
    // SRH
    ['Pat Cummins', 'P Cummins', 'SRH', 'Bowler', 91],
    ['Travis Head', 'T Head', 'SRH', 'Batsman', 90],
    ['Abhishek Sharma', 'A Sharma', 'SRH', 'All-rounder', 87],
    ['Heinrich Klaasen', 'H Klaasen', 'SRH', 'Wicket-keeper', 92],
    ['Bhuvneshwar Kumar', 'B Kumar', 'SRH', 'Bowler', 86],
    // RR
    ['Sanju Samson', 'S Samson', 'RR', 'Wicket-keeper', 89],
    ['Jos Buttler', 'J Buttler', 'RR', 'Wicket-keeper', 91],
    ['Yuzvendra Chahal', 'Y Chahal', 'RR', 'Bowler', 88],
    ['Trent Boult', 'T Boult', 'RR', 'Bowler', 89],
    ['Yashasvi Jaiswal', 'Y Jaiswal', 'RR', 'Batsman', 88],
    // DC
    ['Rishabh Pant', 'R Pant', 'DC', 'Wicket-keeper', 90],
    ['David Warner', 'D Warner', 'DC', 'Batsman', 88],
    ['Axar Patel', 'A Patel', 'DC', 'All-rounder', 87],
    ['Kuldeep Yadav', 'K Yadav', 'DC', 'Bowler', 89],
    ['Jake Fraser-McGurk', 'J Fraser', 'DC', 'Batsman', 87],
    // PBKS
    ['Shikhar Dhawan', 'S Dhawan', 'PBKS', 'Batsman', 86],
    ['Sam Curran', 'S Curran', 'PBKS', 'All-rounder', 87],
    ['Kagiso Rabada', 'K Rabada', 'PBKS', 'Bowler', 89],
    ['Arshdeep Singh', 'A Singh', 'PBKS', 'Bowler', 88],
    ['Liam Livingstone', 'L Livingstone', 'PBKS', 'All-rounder', 86],
    // LSG
    ['KL Rahul', 'KL Rahul', 'LSG', 'Wicket-keeper', 89],
    ['Quinton de Kock', 'Q de Kock', 'LSG', 'Wicket-keeper', 88],
    ['Marcus Stoinis', 'M Stoinis', 'LSG', 'All-rounder', 88],
    ['Nicholas Pooran', 'N Pooran', 'LSG', 'Wicket-keeper', 90],
    ['Ravi Bishnoi', 'R Bishnoi', 'LSG', 'Bowler', 87],
    // GT
    ['Shubman Gill', 'S Gill', 'GT', 'Batsman', 91],
    ['Rashid Khan', 'R Khan', 'GT', 'Bowler', 93],
    ['David Miller', 'D Miller', 'GT', 'Batsman', 88],
    ['Mohammed Shami', 'M Shami', 'GT', 'Bowler', 89],
    ['Sai Sudharsan', 'S Sudharsan', 'GT', 'Batsman', 86],
  ];

  final teamsData = {
    'CSK': 'Chennai Super Kings',
    'MI': 'Mumbai Indians',
    'RCB': 'Royal Challengers Bengaluru',
    'KKR': 'Kolkata Knight Riders',
    'SRH': 'Sunrisers Hyderabad',
    'RR': 'Rajasthan Royals',
    'DC': 'Delhi Capitals',
    'PBKS': 'Punjab Kings',
    'LSG': 'Lucknow Super Giants',
    'GT': 'Gujarat Titans',
  };

  final firstNamesInd = [
    "Rahul",
    "Amit",
    "Rohan",
    "Sandeep",
    "Deepak",
    "Ravi",
    "Manish",
    "Piyush",
    "Ishant",
    "Mohit",
    "Varun",
    "Washington",
    "Krunal",
    "Devdutt",
    "Prithvi",
    "Navdeep",
    "Tushar",
    "Harshal",
    "Avesh",
    "Umran",
    "Mukesh",
    "Prasidh",
    "Shahrukh",
    "Nitish",
    "Ayush",
  ];
  final lastNamesInd = [
    "Sharma",
    "Singh",
    "Patel",
    "Kumar",
    "Yadav",
    "Chahar",
    "Pandey",
    "Chawla",
    "Sundar",
    "Gowtham",
    "Padikkal",
    "Shaw",
    "Saini",
    "Deshpande",
    "Khan",
    "Malik",
    "Krishna",
    "Rana",
    "Badoni",
    "Garg",
    "Tewatia",
    "Thakur",
    "Karthik",
    "Kishan",
  ];

  final firstNamesOs = [
    "Ben",
    "Jofra",
    "Tim",
    "Jason",
    "Kane",
    "Jonny",
    "Aiden",
    "Marco",
    "Quinton",
    "Kagiso",
    "Anrich",
    "Moeen",
    "Dawid",
    "Phil",
    "Kyle",
    "Romario",
    "Alzarri",
    "Rovman",
    "Rahmanullah",
    "Fazalhaq",
    "Naveen",
  ];
  final lastNamesOs = [
    "Stokes",
    "Archer",
    "David",
    "Holder",
    "Williamson",
    "Bairstow",
    "Markram",
    "Jansen",
    "Nortje",
    "Ali",
    "Malan",
    "Salt",
    "Mayers",
    "Shepherd",
    "Joseph",
    "Powell",
    "Gurbaz",
    "Farooqi",
    "ul-Haq",
    "Curran",
    "Brook",
  ];

  final random = Random();

  String getTier(int rating) {
    if (rating >= 90) return "Platinum";
    if (rating >= 86) return "Gold";
    if (rating >= 80) return "Silver";
    return "Bronze";
  }

  Map<String, List<List<dynamic>>> playersByTeam = {};
  for (var key in teamsData.keys) {
    playersByTeam[key] = [];
  }

  for (var p in prominentPlayers) {
    playersByTeam[p[2]]!.add(p);
  }

  for (var teamCode in teamsData.keys) {
    int needed = 18 - playersByTeam[teamCode]!.length;
    for (int i = 0; i < needed; i++) {
      bool isOverseas = random.nextDouble() < 0.3;
      String fname, lname;
      if (isOverseas) {
        fname = firstNamesOs[random.nextInt(firstNamesOs.length)];
        lname = lastNamesOs[random.nextInt(lastNamesOs.length)];
      } else {
        fname = firstNamesInd[random.nextInt(firstNamesInd.length)];
        lname = lastNamesInd[random.nextInt(lastNamesInd.length)];
      }

      String name = '$fname $lname';
      String shortName = '${fname[0]} $lname';

      // Weighting roles: more batsmen/bowlers
      int roleInt = random.nextInt(11);
      String role = 'Batsman';
      if (roleInt < 4) {
        role = 'Batsman';
      } else if (roleInt < 8)
        role = 'Bowler';
      else if (roleInt < 10)
        role = 'All-rounder';
      else
        role = 'Wicket-keeper';

      int rating = 75 + random.nextInt(10); // 75 to 84

      playersByTeam[teamCode]!.add([name, shortName, teamCode, role, rating]);
    }
  }

  List<Map<String, dynamic>> allPlayers = [];
  for (var entry in playersByTeam.entries) {
    String teamCode = entry.key;
    String teamName = teamsData[teamCode]!;
    for (var p in entry.value) {
      allPlayers.add({
        "name": p[0],
        "short_name": p[1],
        "team": teamName,
        "team_code": teamCode,
        "role": p[3],
        "rating": p[4],
        "tier": getTier(p[4]),
      });
    }
  }

  allPlayers.sort((a, b) => b['rating'].compareTo(a['rating']));

  var f = File('ipl_players.csv');
  var sink = f.openWrite();

  sink.writeln('name,short_name,team,team_code,role,rating,tier');

  for (var p in allPlayers) {
    sink.writeln(
      '${p["name"]},${p["short_name"]},${p["team"]},${p["team_code"]},${p["role"]},${p["rating"]},${p["tier"]}',
    );
  }

  sink.close();
  print('Generated ipl_players.csv');
}
