import 'dart:io';

void main() {
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
    'GT': 'Gujarat Titans'
  };

  final rawSquads = {
    'CSK': [
      ['MS Dhoni', 'MSD', 'Wicket-keeper', 89],
      ['Ruturaj Gaikwad', 'R Gaikwad', 'Batsman', 88],
      ['Ravindra Jadeja', 'R Jadeja', 'All-rounder', 91],
      ['Shivam Dube', 'S Dube', 'All-rounder', 87],
      ['Matheesha Pathirana', 'M Pathirana', 'Bowler', 88],
      ['Maheesh Theekshana', 'M Theekshana', 'Bowler', 84],
      ['Deepak Chahar', 'D Chahar', 'Bowler', 83],
      ['Shardul Thakur', 'S Thakur', 'All-rounder', 82],
      ['Tushar Deshpande', 'T Deshpande', 'Bowler', 81],
      ['Devon Conway', 'D Conway', 'Batsman', 86],
      ['Daryl Mitchell', 'D Mitchell', 'All-rounder', 87],
      ['Rachin Ravindra', 'R Ravindra', 'All-rounder', 85],
      ['Ajinkya Rahane', 'A Rahane', 'Batsman', 82],
      ['Sameer Rizvi', 'S Rizvi', 'Batsman', 77],
      ['Mukesh Choudhary', 'M Choudhary', 'Bowler', 79],
      ['Rajvardhan Hangargekar', 'R Hangargekar', 'Bowler', 78],
      ['Mitchell Santner', 'M Santner', 'All-rounder', 83],
      ['Moeen Ali', 'M Ali', 'All-rounder', 85],
    ],
    'MI': [
      ['Hardik Pandya', 'H Pandya', 'All-rounder', 89],
      ['Rohit Sharma', 'R Sharma', 'Batsman', 91],
      ['Suryakumar Yadav', 'SKY', 'Batsman', 93],
      ['Jasprit Bumrah', 'J Bumrah', 'Bowler', 94],
      ['Ishan Kishan', 'I Kishan', 'Wicket-keeper', 86],
      ['Tilak Varma', 'T Varma', 'Batsman', 85],
      ['Tim David', 'T David', 'Batsman', 84],
      ['Romario Shepherd', 'R Shepherd', 'All-rounder', 82],
      ['Gerald Coetzee', 'G Coetzee', 'Bowler', 84],
      ['Piyush Chawla', 'P Chawla', 'Bowler', 80],
      ['Akash Madhwal', 'A Madhwal', 'Bowler', 81],
      ['Nehal Wadhera', 'N Wadhera', 'Batsman', 80],
      ['Dewald Brevis', 'D Brevis', 'Batsman', 79],
      ['Naman Dhir', 'N Dhir', 'All-rounder', 77],
      ['Mohammad Nabi', 'M Nabi', 'All-rounder', 82],
      ['Shreyas Gopal', 'S Gopal', 'Bowler', 78],
      ['Arjun Tendulkar', 'A Tendulkar', 'All-rounder', 75],
      ['Vishnu Vinod', 'V Vinod', 'Wicket-keeper', 76],
    ],
    'RCB': [
      ['Virat Kohli', 'V Kohli', 'Batsman', 94],
      ['Faf du Plessis', 'F du Plessis', 'Batsman', 88],
      ['Glenn Maxwell', 'G Maxwell', 'All-rounder', 89],
      ['Mohammed Siraj', 'M Siraj', 'Bowler', 87],
      ['Rajat Patidar', 'R Patidar', 'Batsman', 85],
      ['Cameron Green', 'C Green', 'All-rounder', 87],
      ['Will Jacks', 'W Jacks', 'All-rounder', 86],
      ['Dinesh Karthik', 'D Karthik', 'Wicket-keeper', 84],
      ['Mahipal Lomror', 'M Lomror', 'All-rounder', 81],
      ['Karn Sharma', 'K Sharma', 'Bowler', 79],
      ['Yash Dayal', 'Y Dayal', 'Bowler', 81],
      ['Reece Topley', 'R Topley', 'Bowler', 83],
      ['Lockie Ferguson', 'L Ferguson', 'Bowler', 84],
      ['Alzarri Joseph', 'A Joseph', 'Bowler', 82],
      ['Akash Deep', 'A Deep', 'Bowler', 80],
      ['Suyash Prabhudessai', 'S Prabhudessai', 'Batsman', 78],
      ['Vijaykumar Vyshak', 'V Vyshak', 'Bowler', 79],
      ['Tom Curran', 'T Curran', 'All-rounder', 80],
    ],
    'KKR': [
      ['Shreyas Iyer', 'S Iyer', 'Batsman', 87],
      ['Andre Russell', 'A Russell', 'All-rounder', 90],
      ['Sunil Narine', 'S Narine', 'All-rounder', 91],
      ['Mitchell Starc', 'M Starc', 'Bowler', 89],
      ['Rinku Singh', 'R Singh', 'Batsman', 88],
      ['Venkatesh Iyer', 'V Iyer', 'All-rounder', 85],
      ['Varun Chakaravarthy', 'V Chakaravarthy', 'Bowler', 86],
      ['Nitish Rana', 'N Rana', 'Batsman', 84],
      ['Phil Salt', 'P Salt', 'Wicket-keeper', 87],
      ['Harshit Rana', 'H Rana', 'Bowler', 83],
      ['Suyash Sharma', 'S Sharma', 'Bowler', 81],
      ['Chetan Sakariya', 'C Sakariya', 'Bowler', 80],
      ['Manish Pandey', 'M Pandey', 'Batsman', 80],
      ['Rahmanullah Gurbaz', 'R Gurbaz', 'Wicket-keeper', 82],
      ['Dushmantha Chameera', 'D Chameera', 'Bowler', 81],
      ['Ramandeep Singh', 'R Singh', 'All-rounder', 80],
      ['Anukul Roy', 'A Roy', 'All-rounder', 78],
      ['Vaibhav Arora', 'V Arora', 'Bowler', 80],
    ],
    'SRH': [
      ['Pat Cummins', 'P Cummins', 'Bowler', 91],
      ['Travis Head', 'T Head', 'Batsman', 90],
      ['Abhishek Sharma', 'A Sharma', 'All-rounder', 87],
      ['Heinrich Klaasen', 'H Klaasen', 'Wicket-keeper', 92],
      ['Bhuvneshwar Kumar', 'B Kumar', 'Bowler', 86],
      ['T Natarajan', 'T Natarajan', 'Bowler', 85],
      ['Aiden Markram', 'A Markram', 'Batsman', 86],
      ['Nitish Kumar Reddy', 'N Reddy', 'All-rounder', 84],
      ['Shahbaz Ahmed', 'S Ahmed', 'All-rounder', 82],
      ['Mayank Agarwal', 'M Agarwal', 'Batsman', 81],
      ['Abdul Samad', 'A Samad', 'Batsman', 80],
      ['Marco Jansen', 'M Jansen', 'All-rounder', 83],
      ['Washington Sundar', 'W Sundar', 'All-rounder', 82],
      ['Umran Malik', 'U Malik', 'Bowler', 81],
      ['Jaydev Unadkat', 'J Unadkat', 'Bowler', 80],
      ['Rahul Tripathi', 'R Tripathi', 'Batsman', 83],
      ['Glenn Phillips', 'G Phillips', 'Batsman', 84],
      ['Fazalhaq Farooqi', 'F Farooqi', 'Bowler', 82],
    ],
    'RR': [
      ['Sanju Samson', 'S Samson', 'Wicket-keeper', 89],
      ['Jos Buttler', 'J Buttler', 'Wicket-keeper', 91],
      ['Yashasvi Jaiswal', 'Y Jaiswal', 'Batsman', 88],
      ['Yuzvendra Chahal', 'Y Chahal', 'Bowler', 88],
      ['Trent Boult', 'T Boult', 'Bowler', 89],
      ['Riyan Parag', 'R Parag', 'All-rounder', 85],
      ['Ravichandran Ashwin', 'R Ashwin', 'All-rounder', 86],
      ['Sandeep Sharma', 'S Sharma', 'Bowler', 85],
      ['Avesh Khan', 'A Khan', 'Bowler', 84],
      ['Dhruv Jurel', 'D Jurel', 'Wicket-keeper', 83],
      ['Shimron Hetmyer', 'S Hetmyer', 'Batsman', 85],
      ['Rovman Powell', 'R Powell', 'Batsman', 84],
      ['Nandre Burger', 'N Burger', 'Bowler', 82],
      ['Navdeep Saini', 'N Saini', 'Bowler', 80],
      ['Kuldeep Sen', 'K Sen', 'Bowler', 81],
      ['Tom Kohler-Cadmore', 'T Kohler-Cadmore', 'Batsman', 79],
      ['Donovan Ferreira', 'D Ferreira', 'All-rounder', 78],
      ['Shubham Dubey', 'S Dubey', 'Batsman', 77],
    ],
    'DC': [
      ['Rishabh Pant', 'R Pant', 'Wicket-keeper', 90],
      ['David Warner', 'D Warner', 'Batsman', 88],
      ['Axar Patel', 'A Patel', 'All-rounder', 87],
      ['Kuldeep Yadav', 'K Yadav', 'Bowler', 89],
      ['Jake Fraser-McGurk', 'J Fraser-McGurk', 'Batsman', 87],
      ['Tristan Stubbs', 'T Stubbs', 'Wicket-keeper', 86],
      ['Khaleel Ahmed', 'K Ahmed', 'Bowler', 85],
      ['Mukesh Kumar', 'M Kumar', 'Bowler', 84],
      ['Ishant Sharma', 'I Sharma', 'Bowler', 83],
      ['Prithvi Shaw', 'P Shaw', 'Batsman', 82],
      ['Mitchell Marsh', 'M Marsh', 'All-rounder', 85],
      ['Abishek Porel', 'A Porel', 'Wicket-keeper', 81],
      ['Anrich Nortje', 'A Nortje', 'Bowler', 84],
      ['Shai Hope', 'S Hope', 'Batsman', 82],
      ['Ricky Bhui', 'R Bhui', 'Batsman', 78],
      ['Kumar Kushagra', 'K Kushagra', 'Wicket-keeper', 77],
      ['Pravin Dubey', 'P Dubey', 'All-rounder', 78],
      ['Rasikh Salam', 'R Salam', 'Bowler', 79],
    ],
    'PBKS': [
      ['Shikhar Dhawan', 'S Dhawan', 'Batsman', 86],
      ['Sam Curran', 'S Curran', 'All-rounder', 87],
      ['Kagiso Rabada', 'K Rabada', 'Bowler', 89],
      ['Arshdeep Singh', 'A Singh', 'Bowler', 88],
      ['Liam Livingstone', 'L Livingstone', 'All-rounder', 86],
      ['Jonny Bairstow', 'J Bairstow', 'Wicket-keeper', 85],
      ['Jitesh Sharma', 'J Sharma', 'Wicket-keeper', 84],
      ['Shashank Singh', 'S Singh', 'Batsman', 84],
      ['Ashutosh Sharma', 'A Sharma', 'Batsman', 83],
      ['Harpreet Brar', 'H Brar', 'All-rounder', 82],
      ['Rahul Chahar', 'R Chahar', 'Bowler', 82],
      ['Prabhsimran Singh', 'P Singh', 'Wicket-keeper', 81],
      ['Harshal Patel', 'H Patel', 'Bowler', 85],
      ['Rilee Rossouw', 'R Rossouw', 'Batsman', 83],
      ['Sikandar Raza', 'S Raza', 'All-rounder', 84],
      ['Chris Woakes', 'C Woakes', 'All-rounder', 82],
      ['Vidwath Kaverappa', 'V Kaverappa', 'Bowler', 80],
      ['Nathan Ellis', 'N Ellis', 'Bowler', 83],
    ],
    'LSG': [
      ['KL Rahul', 'KL Rahul', 'Wicket-keeper', 89],
      ['Quinton de Kock', 'Q de Kock', 'Wicket-keeper', 88],
      ['Marcus Stoinis', 'M Stoinis', 'All-rounder', 88],
      ['Nicholas Pooran', 'N Pooran', 'Wicket-keeper', 90],
      ['Ravi Bishnoi', 'R Bishnoi', 'Bowler', 87],
      ['Mayank Yadav', 'M Yadav', 'Bowler', 86],
      ['Krunal Pandya', 'K Pandya', 'All-rounder', 84],
      ['Mohsin Khan', 'M Khan', 'Bowler', 83],
      ['Ayush Badoni', 'A Badoni', 'Batsman', 82],
      ['Naveen-ul-Haq', 'Naveen', 'Bowler', 84],
      ['Deepak Hooda', 'D Hooda', 'All-rounder', 81],
      ['Devdutt Padikkal', 'D Padikkal', 'Batsman', 81],
      ['Yash Thakur', 'Y Thakur', 'Bowler', 82],
      ['Amit Mishra', 'A Mishra', 'Bowler', 80],
      ['Shamar Joseph', 'S Joseph', 'Bowler', 83],
      ['Matt Henry', 'M Henry', 'Bowler', 82],
      ['Krishnappa Gowtham', 'K Gowtham', 'All-rounder', 80],
      ['Ashton Turner', 'A Turner', 'Batsman', 79],
    ],
    'GT': [
      ['Shubman Gill', 'S Gill', 'Batsman', 91],
      ['Rashid Khan', 'R Khan', 'Bowler', 93],
      ['David Miller', 'D Miller', 'Batsman', 88],
      ['Mohammed Shami', 'M Shami', 'Bowler', 89],
      ['Sai Sudharsan', 'S Sudharsan', 'Batsman', 86],
      ['Rahul Tewatia', 'R Tewatia', 'All-rounder', 84],
      ['Wriddhiman Saha', 'W Saha', 'Wicket-keeper', 82],
      ['Noor Ahmad', 'N Ahmad', 'Bowler', 85],
      ['Mohit Sharma', 'M Sharma', 'Bowler', 84],
      ['Spencer Johnson', 'S Johnson', 'Bowler', 83],
      ['Umesh Yadav', 'U Yadav', 'Bowler', 82],
      ['Vijay Shankar', 'V Shankar', 'All-rounder', 80],
      ['Shahrukh Khan', 'S Khan', 'Batsman', 82],
      ['Azmatullah Omarzai', 'A Omarzai', 'All-rounder', 83],
      ['Joshua Little', 'J Little', 'Bowler', 82],
      ['Kartik Tyagi', 'K Tyagi', 'Bowler', 80],
      ['Abhinav Manohar', 'A Manohar', 'Batsman', 79],
      ['R. Sai Kishore', 'Sai Kishore', 'Bowler', 81],
    ],
  };

  String getTier(int rating) {
    if (rating >= 90) return "Platinum";
    if (rating >= 86) return "Gold";
    if (rating >= 80) return "Silver";
    return "Bronze";
  }

  List<Map<String, dynamic>> allPlayers = [];
  
  for (var teamCode in teamsData.keys) {
    var players = rawSquads[teamCode]!;
    for (var p in players) {
      allPlayers.add({
        "name": p[0],
        "short_name": p[1],
        "team": teamsData[teamCode],
        "team_code": teamCode,
        "role": p[2],
        "rating": p[3],
        "tier": getTier(p[3] as int)
      });
    }
  }

  allPlayers.sort((a, b) => b['rating'].compareTo(a['rating']));

  var f = File('ipl_players.csv');
  var sink = f.openWrite();
  
  sink.writeln('name,short_name,team,team_code,role,rating,tier');
  
  for (var p in allPlayers) {
    sink.writeln('${p["name"]},${p["short_name"]},${p["team"]},${p["team_code"]},${p["role"]},${p["rating"]},${p["tier"]}');
  }
  
  sink.close();
  print('Generated updated ipl_players.csv with 180 actual players');
}
