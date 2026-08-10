const fs = require('fs');

const teamsData = {
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

// 18 players per team = 180 players based on 2026 IPL updates
const rawSquads = {
  'CSK': [
    ['Ruturaj Gaikwad', 'R Gaikwad', 'Batsman', 88],
    ['MS Dhoni', 'MSD', 'Wicket-keeper', 89],
    ['Sanju Samson', 'S Samson', 'Wicket-keeper', 89],
    ['Dewald Brevis', 'D Brevis', 'Batsman', 81],
    ['Kartik Sharma', 'K Sharma', 'Batsman', 77],
    ['Sarfaraz Khan', 'S Khan', 'Batsman', 80],
    ['Shivam Dube', 'S Dube', 'All-rounder', 87],
    ['Jamie Overton', 'J Overton', 'All-rounder', 82],
    ['Matthew Short', 'M Short', 'All-rounder', 83],
    ['Aman Khan', 'A Khan', 'All-rounder', 78],
    ['Khaleel Ahmed', 'K Ahmed', 'Bowler', 85],
    ['Noor Ahmad', 'N Ahmad', 'Bowler', 84],
    ['Anshul Kamboj', 'A Kamboj', 'Bowler', 79],
    ['Mukesh Choudhary', 'M Choudhary', 'Bowler', 80],
    ['Shreyas Gopal', 'S Gopal', 'Bowler', 80],
    ['Akeal Hosein', 'A Hosein', 'Bowler', 83],
    ['Matt Henry', 'M Henry', 'Bowler', 84],
    ['Spencer Johnson', 'S Johnson', 'Bowler', 83]
  ],
  'MI': [
    ['Hardik Pandya', 'H Pandya', 'All-rounder', 90],
    ['Rohit Sharma', 'R Sharma', 'Batsman', 91],
    ['Suryakumar Yadav', 'SKY', 'Batsman', 93],
    ['Tilak Varma', 'T Varma', 'Batsman', 86],
    ['Naman Dhir', 'N Dhir', 'Batsman', 79],
    ['Will Jacks', 'W Jacks', 'All-rounder', 85],
    ['Mitchell Santner', 'M Santner', 'All-rounder', 83],
    ['Shardul Thakur', 'S Thakur', 'All-rounder', 82],
    ['Quinton de Kock', 'Q de Kock', 'Wicket-keeper', 88],
    ['Ryan Rickelton', 'R Rickelton', 'Wicket-keeper', 81],
    ['Robin Minz', 'R Minz', 'Wicket-keeper', 78],
    ['Jasprit Bumrah', 'J Bumrah', 'Bowler', 94],
    ['Trent Boult', 'T Boult', 'Bowler', 89],
    ['Deepak Chahar', 'D Chahar', 'Bowler', 84],
    ['Allah Ghazanfar', 'A Ghazanfar', 'Bowler', 79],
    ['Mayank Markande', 'M Markande', 'Bowler', 80],
    ['Corbin Bosch', 'C Bosch', 'All-rounder', 78],
    ['Raj Angad Bawa', 'R Bawa', 'All-rounder', 77]
  ],
  'RCB': [
    ['Rajat Patidar', 'R Patidar', 'Batsman', 85],
    ['Virat Kohli', 'V Kohli', 'Batsman', 94],
    ['Devdutt Padikkal', 'D Padikkal', 'Batsman', 82],
    ['Venkatesh Iyer', 'V Iyer', 'All-rounder', 85],
    ['Tim David', 'T David', 'Batsman', 84],
    ['Romario Shepherd', 'R Shepherd', 'All-rounder', 82],
    ['Krunal Pandya', 'K Pandya', 'All-rounder', 83],
    ['Swapnil Singh', 'S Singh', 'All-rounder', 78],
    ['Phil Salt', 'P Salt', 'Wicket-keeper', 87],
    ['Jitesh Sharma', 'J Sharma', 'Wicket-keeper', 84],
    ['Jordan Cox', 'J Cox', 'Wicket-keeper', 79],
    ['Josh Hazlewood', 'J Hazlewood', 'Bowler', 88],
    ['Yash Dayal', 'Y Dayal', 'Bowler', 83],
    ['Bhuvneshwar Kumar', 'B Kumar', 'Bowler', 86],
    ['Nuwan Thushara', 'N Thushara', 'Bowler', 82],
    ['Rasikh Salam', 'R Salam', 'Bowler', 80],
    ['Suyash Sharma', 'S Sharma', 'Bowler', 81],
    ['Jacob Bethell', 'J Bethell', 'All-rounder', 78]
  ],
  'KKR': [
    ['Ajinkya Rahane', 'A Rahane', 'Batsman', 82],
    ['Rinku Singh', 'R Singh', 'Batsman', 88],
    ['Angkrish Raghuvanshi', 'A Raghuvanshi', 'Batsman', 81],
    ['Manish Pandey', 'M Pandey', 'Batsman', 80],
    ['Rahul Tripathi', 'R Tripathi', 'Batsman', 83],
    ['Sunil Narine', 'S Narine', 'All-rounder', 91],
    ['Cameron Green', 'C Green', 'All-rounder', 87],
    ['Ramandeep Singh', 'R Singh', 'All-rounder', 81],
    ['Anukul Roy', 'A Roy', 'All-rounder', 78],
    ['Rachin Ravindra', 'R Ravindra', 'All-rounder', 85],
    ['Rovman Powell', 'R Powell', 'Batsman', 84],
    ['Finn Allen', 'F Allen', 'Wicket-keeper', 83],
    ['Tim Seifert', 'T Seifert', 'Wicket-keeper', 80],
    ['Varun Chakaravarthy', 'V Chakaravarthy', 'Bowler', 86],
    ['Harshit Rana', 'H Rana', 'Bowler', 84],
    ['Vaibhav Arora', 'V Arora', 'Bowler', 81],
    ['Kartik Tyagi', 'K Tyagi', 'Bowler', 80],
    ['Matheesha Pathirana', 'M Pathirana', 'Bowler', 88]
  ],
  'SRH': [
    ['Pat Cummins', 'P Cummins', 'Bowler', 91],
    ['Abhishek Sharma', 'A Sharma', 'All-rounder', 88],
    ['Travis Head', 'T Head', 'Batsman', 90],
    ['Heinrich Klaasen', 'H Klaasen', 'Wicket-keeper', 92],
    ['Ishan Kishan', 'I Kishan', 'Wicket-keeper', 86],
    ['Nitish Kumar Reddy', 'N Reddy', 'All-rounder', 85],
    ['Liam Livingstone', 'L Livingstone', 'All-rounder', 86],
    ['Kamindu Mendis', 'K Mendis', 'All-rounder', 84],
    ['Harshal Patel', 'H Patel', 'Bowler', 85],
    ['Jaydev Unadkat', 'J Unadkat', 'Bowler', 80],
    ['Brydon Carse', 'B Carse', 'Bowler', 82],
    ['Shivam Mavi', 'S Mavi', 'Bowler', 81],
    ['Jack Edwards', 'J Edwards', 'All-rounder', 79],
    ['Eshan Malinga', 'E Malinga', 'Bowler', 77],
    ['Zeeshan Ansari', 'Z Ansari', 'Bowler', 76],
    ['R. Smaran', 'R Smaran', 'Batsman', 78],
    ['Harsh Dubey', 'H Dubey', 'All-rounder', 77],
    ['Aniket Verma', 'A Verma', 'Batsman', 76]
  ],
  'RR': [
    ['Riyan Parag', 'R Parag', 'All-rounder', 87],
    ['Yashasvi Jaiswal', 'Y Jaiswal', 'Batsman', 89],
    ['Shimron Hetmyer', 'S Hetmyer', 'Batsman', 85],
    ['Shubham Dubey', 'S Dubey', 'Batsman', 78],
    ['Vaibhav Sooryavanshi', 'V Sooryavanshi', 'Batsman', 84],
    ['Ravindra Jadeja', 'R Jadeja', 'All-rounder', 91],
    ['Sam Curran', 'S Curran', 'All-rounder', 88],
    ['Donovan Ferreira', 'D Ferreira', 'All-rounder', 80],
    ['Dhruv Jurel', 'D Jurel', 'Wicket-keeper', 84],
    ['Jonny Bairstow', 'J Bairstow', 'Wicket-keeper', 85],
    ['Lhuan-dre Pretorius', 'L Pretorius', 'Wicket-keeper', 78],
    ['Jofra Archer', 'J Archer', 'Bowler', 87],
    ['Sandeep Sharma', 'S Sharma', 'Bowler', 85],
    ['Tushar Deshpande', 'T Deshpande', 'Bowler', 82],
    ['Kwena Maphaka', 'K Maphaka', 'Bowler', 81],
    ['Nandre Burger', 'N Burger', 'Bowler', 83],
    ['Yudhvir Singh', 'Y Singh', 'Bowler', 79],
    ['Akash Deep', 'A Deep', 'Bowler', 82]
  ],
  'DC': [
    ['Axar Patel', 'A Patel', 'All-rounder', 88],
    ['KL Rahul', 'KL Rahul', 'Wicket-keeper', 89],
    ['Abishek Porel', 'A Porel', 'Wicket-keeper', 81],
    ['Ben Duckett', 'B Duckett', 'Batsman', 84],
    ['David Miller', 'D Miller', 'Batsman', 87],
    ['Pathum Nissanka', 'P Nissanka', 'Batsman', 85],
    ['Nitish Rana', 'N Rana', 'Batsman', 83],
    ['Ashutosh Sharma', 'A Sharma', 'Batsman', 82],
    ['Tristan Stubbs', 'T Stubbs', 'Wicket-keeper', 86],
    ['Sameer Rizvi', 'S Rizvi', 'All-rounder', 79],
    ['Auqib Nabi Dar', 'A Dar', 'All-rounder', 77],
    ['Kuldeep Yadav', 'K Yadav', 'Bowler', 89],
    ['Mitchell Starc', 'M Starc', 'Bowler', 88],
    ['T. Natarajan', 'T Natarajan', 'Bowler', 86],
    ['Mukesh Kumar', 'M Kumar', 'Bowler', 84],
    ['Dushmantha Chameera', 'D Chameera', 'Bowler', 82],
    ['Lungisani Ngidi', 'L Ngidi', 'Bowler', 84],
    ['Kyle Jamieson', 'K Jamieson', 'Bowler', 81]
  ],
  'PBKS': [
    ['Shreyas Iyer', 'S Iyer', 'Batsman', 88],
    ['Prabhsimran Singh', 'P Singh', 'Wicket-keeper', 82],
    ['Shashank Singh', 'S Singh', 'Batsman', 84],
    ['Nehal Wadhera', 'N Wadhera', 'Batsman', 82],
    ['Marcus Stoinis', 'M Stoinis', 'All-rounder', 87],
    ['Azmatullah Omarzai', 'A Omarzai', 'All-rounder', 84],
    ['Marco Jansen', 'M Jansen', 'All-rounder', 83],
    ['Harpreet Brar', 'H Brar', 'All-rounder', 82],
    ['Musheer Khan', 'M Khan', 'All-rounder', 80],
    ['Cooper Connolly', 'C Connolly', 'All-rounder', 79],
    ['Vishnu Vinod', 'V Vinod', 'Wicket-keeper', 78],
    ['Arshdeep Singh', 'A Singh', 'Bowler', 89],
    ['Yuzvendra Chahal', 'Y Chahal', 'Bowler', 88],
    ['Xavier Bartlett', 'X Bartlett', 'Bowler', 83],
    ['Lockie Ferguson', 'L Ferguson', 'Bowler', 84],
    ['Vyshak Vijaykumar', 'V Vijaykumar', 'Bowler', 80],
    ['Yash Thakur', 'Y Thakur', 'Bowler', 82],
    ['Ben Dwarshuis', 'B Dwarshuis', 'Bowler', 81]
  ],
  'LSG': [
    ['Rishabh Pant', 'R Pant', 'Wicket-keeper', 91],
    ['Nicholas Pooran', 'N Pooran', 'Wicket-keeper', 90],
    ['Josh Inglis', 'J Inglis', 'Wicket-keeper', 85],
    ['Aiden Markram', 'A Markram', 'Batsman', 86],
    ['Matthew Breetzke', 'M Breetzke', 'Batsman', 80],
    ['Ayush Badoni', 'A Badoni', 'Batsman', 83],
    ['Abdul Samad', 'A Samad', 'All-rounder', 81],
    ['Mitchell Marsh', 'M Marsh', 'All-rounder', 86],
    ['Shahbaz Ahmed', 'S Ahmed', 'All-rounder', 82],
    ['Wanindu Hasaranga', 'W Hasaranga', 'All-rounder', 87],
    ['Arshin Kulkarni', 'A Kulkarni', 'All-rounder', 79],
    ['Arjun Tendulkar', 'A Tendulkar', 'All-rounder', 77],
    ['Mayank Yadav', 'M Yadav', 'Bowler', 87],
    ['Avesh Khan', 'A Khan', 'Bowler', 85],
    ['Mohsin Khan', 'M Khan', 'Bowler', 84],
    ['Mohammed Shami', 'M Shami', 'Bowler', 89],
    ['Anrich Nortje', 'A Nortje', 'Bowler', 85],
    ['Manimaran Siddharth', 'M Siddharth', 'Bowler', 79]
  ],
  'GT': [
    ['Shubman Gill', 'S Gill', 'Batsman', 92],
    ['Sai Sudharsan', 'S Sudharsan', 'Batsman', 87],
    ['Jos Buttler', 'J Buttler', 'Wicket-keeper', 91],
    ['Tom Banton', 'T Banton', 'Wicket-keeper', 83],
    ['Anuj Rawat', 'A Rawat', 'Wicket-keeper', 79],
    ['Rahul Tewatia', 'R Tewatia', 'All-rounder', 85],
    ['Washington Sundar', 'W Sundar', 'All-rounder', 83],
    ['Jason Holder', 'J Holder', 'All-rounder', 84],
    ['Shahrukh Khan', 'S Khan', 'Batsman', 82],
    ['Glenn Phillips', 'G Phillips', 'Batsman', 84],
    ['Arshad Khan', 'A Khan', 'All-rounder', 79],
    ['Rashid Khan', 'R Khan', 'Bowler', 93],
    ['Kagiso Rabada', 'K Rabada', 'Bowler', 90],
    ['Mohammed Siraj', 'M Siraj', 'Bowler', 88],
    ['Prasidh Krishna', 'P Krishna', 'Bowler', 84],
    ['Ishant Sharma', 'I Sharma', 'Bowler', 82],
    ['Jayant Yadav', 'J Yadav', 'Bowler', 80],
    ['Luke Wood', 'L Wood', 'Bowler', 81]
  ]
};

function getTier(rating) {
  if (rating >= 90) return "Platinum";
  if (rating >= 86) return "Gold";
  if (rating >= 80) return "Silver";
  return "Bronze";
}

let allPlayers = [];

for (let teamCode of Object.keys(teamsData)) {
  let players = rawSquads[teamCode];
  for (let p of players) {
    allPlayers.push({
      name: p[0],
      short_name: p[1],
      team: teamsData[teamCode],
      team_code: teamCode,
      role: p[2],
      rating: p[3],
      tier: getTier(p[3])
    });
  }
}

allPlayers.sort((a, b) => b.rating - a.rating);

let csvContent = 'name,short_name,team,team_code,role,rating,tier\n';
for (let p of allPlayers) {
  csvContent += `${p.name},${p.short_name},${p.team},${p.team_code},${p.role},${p.rating},${p.tier}\n`;
}

fs.writeFileSync('ipl_players.csv', csvContent);
console.log('Generated fully updated ipl_players.csv for 2026');
