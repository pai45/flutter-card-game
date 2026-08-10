import csv
import random

# Real prominent players
prominent_players = [
    # CSK
    ("MS Dhoni", "MSD", "CSK", "Wicket-keeper", 90),
    ("Ruturaj Gaikwad", "R Gaikwad", "CSK", "Batsman", 88),
    ("Ravindra Jadeja", "R Jadeja", "CSK", "All-rounder", 91),
    ("Matheesha Pathirana", "M Pathirana", "CSK", "Bowler", 87),
    ("Shivam Dube", "S Dube", "CSK", "All-rounder", 86),
    # MI
    ("Rohit Sharma", "R Sharma", "MI", "Batsman", 91),
    ("Suryakumar Yadav", "SKY", "MI", "Batsman", 93),
    ("Jasprit Bumrah", "J Bumrah", "MI", "Bowler", 94),
    ("Hardik Pandya", "H Pandya", "MI", "All-rounder", 89),
    ("Ishan Kishan", "I Kishan", "MI", "Wicket-keeper", 86),
    # RCB
    ("Virat Kohli", "V Kohli", "RCB", "Batsman", 94),
    ("Faf du Plessis", "F du Plessis", "RCB", "Batsman", 88),
    ("Glenn Maxwell", "G Maxwell", "RCB", "All-rounder", 89),
    ("Mohammed Siraj", "M Siraj", "RCB", "Bowler", 87),
    ("Rajat Patidar", "R Patidar", "RCB", "Batsman", 85),
    # KKR
    ("Shreyas Iyer", "S Iyer", "KKR", "Batsman", 87),
    ("Andre Russell", "A Russell", "KKR", "All-rounder", 90),
    ("Sunil Narine", "S Narine", "KKR", "All-rounder", 91),
    ("Mitchell Starc", "M Starc", "KKR", "Bowler", 89),
    ("Rinku Singh", "R Singh", "KKR", "Batsman", 88),
    # SRH
    ("Pat Cummins", "P Cummins", "SRH", "Bowler", 91),
    ("Travis Head", "T Head", "SRH", "Batsman", 90),
    ("Abhishek Sharma", "A Sharma", "SRH", "All-rounder", 87),
    ("Heinrich Klaasen", "H Klaasen", "SRH", "Wicket-keeper", 92),
    ("Bhuvneshwar Kumar", "B Kumar", "SRH", "Bowler", 86),
    # RR
    ("Sanju Samson", "S Samson", "RR", "Wicket-keeper", 89),
    ("Jos Buttler", "J Buttler", "RR", "Wicket-keeper", 91),
    ("Yuzvendra Chahal", "Y Chahal", "RR", "Bowler", 88),
    ("Trent Boult", "T Boult", "RR", "Bowler", 89),
    ("Yashasvi Jaiswal", "Y Jaiswal", "RR", "Batsman", 88),
    # DC
    ("Rishabh Pant", "R Pant", "DC", "Wicket-keeper", 90),
    ("David Warner", "D Warner", "DC", "Batsman", 88),
    ("Axar Patel", "A Patel", "DC", "All-rounder", 87),
    ("Kuldeep Yadav", "K Yadav", "DC", "Bowler", 89),
    ("Jake Fraser-McGurk", "J Fraser", "DC", "Batsman", 87),
    # PBKS
    ("Shikhar Dhawan", "S Dhawan", "PBKS", "Batsman", 86),
    ("Sam Curran", "S Curran", "PBKS", "All-rounder", 87),
    ("Kagiso Rabada", "K Rabada", "PBKS", "Bowler", 89),
    ("Arshdeep Singh", "A Singh", "PBKS", "Bowler", 88),
    ("Liam Livingstone", "L Livingstone", "PBKS", "All-rounder", 86),
    # LSG
    ("KL Rahul", "KL Rahul", "LSG", "Wicket-keeper", 89),
    ("Quinton de Kock", "Q de Kock", "LSG", "Wicket-keeper", 88),
    ("Marcus Stoinis", "M Stoinis", "LSG", "All-rounder", 88),
    ("Nicholas Pooran", "N Pooran", "LSG", "Wicket-keeper", 90),
    ("Ravi Bishnoi", "R Bishnoi", "LSG", "Bowler", 87),
    # GT
    ("Shubman Gill", "S Gill", "GT", "Batsman", 91),
    ("Rashid Khan", "R Khan", "GT", "Bowler", 93),
    ("David Miller", "D Miller", "GT", "Batsman", 88),
    ("Mohammed Shami", "M Shami", "GT", "Bowler", 89),
    ("Sai Sudharsan", "S Sudharsan", "GT", "Batsman", 86)
]

teams_data = {
    "CSK": "Chennai Super Kings",
    "MI": "Mumbai Indians",
    "RCB": "Royal Challengers Bengaluru",
    "KKR": "Kolkata Knight Riders",
    "SRH": "Sunrisers Hyderabad",
    "RR": "Rajasthan Royals",
    "DC": "Delhi Capitals",
    "PBKS": "Punjab Kings",
    "LSG": "Lucknow Super Giants",
    "GT": "Gujarat Titans"
}

first_names_ind = ["Rahul", "Amit", "Rohan", "Sandeep", "Deepak", "Ravi", "Manish", "Piyush", "Ishant", "Mohit", "Varun", "Washington", "Krunal", "Devdutt", "Prithvi", "Navdeep", "Tushar", "Harshal", "Avesh", "Umran", "Mukesh", "Prasidh", "Shahrukh", "Nitish", "Ayush"]
last_names_ind = ["Sharma", "Singh", "Patel", "Kumar", "Yadav", "Chahar", "Pandey", "Chawla", "Sundar", "Gowtham", "Padikkal", "Shaw", "Saini", "Deshpande", "Patel", "Khan", "Malik", "Krishna", "Rana", "Badoni", "Garg", "Tewatia", "Thakur", "Karthik", "Kishan"]

first_names_os = ["Ben", "Jofra", "Tim", "Jason", "Kane", "Jonny", "Aiden", "Marco", "Quinton", "Kagiso", "Anrich", "Moeen", "Dawid", "Phil", "Kyle", "Romario", "Alzarri", "Rovman", "Rahmanullah", "Fazalhaq", "Naveen"]
last_names_os = ["Stokes", "Archer", "David", "Holder", "Williamson", "Bairstow", "Markram", "Jansen", "Nortje", "Ali", "Malan", "Salt", "Mayers", "Shepherd", "Joseph", "Powell", "Gurbaz", "Farooqi", "ul-Haq", "Curran", "Brook"]

roles = ["Batsman", "Bowler", "All-rounder", "Wicket-keeper"]

players_by_team = {team: [] for team in teams_data.keys()}

# Add prominent players
for p in prominent_players:
    players_by_team[p[2]].append(p)

# Generate remaining players
def get_tier(rating):
    if rating >= 90: return "Platinum"
    elif rating >= 86: return "Gold"
    elif rating >= 80: return "Silver"
    else: return "Bronze"

generated_players = []

for team_code in teams_data.keys():
    needed = 18 - len(players_by_team[team_code])
    for i in range(needed):
        is_overseas = random.random() < 0.3
        if is_overseas:
            fname = random.choice(first_names_os)
            lname = random.choice(last_names_os)
        else:
            fname = random.choice(first_names_ind)
            lname = random.choice(last_names_ind)
        
        name = f"{fname} {lname}"
        short_name = f"{fname[0]} {lname}"
        
        role = random.choices(roles, weights=[4, 4, 2, 1])[0]
        
        # Ratings distribution
        # Some silvers (80-85), mostly bronzes (75-79) for generated
        rating = random.randint(75, 84)
        players_by_team[team_code].append((name, short_name, team_code, role, rating))

all_players = []
for team_code, players in players_by_team.items():
    team_name = teams_data[team_code]
    for p in players:
        name = p[0]
        short_name = p[1]
        role = p[3]
        rating = p[4]
        tier = get_tier(rating)
        all_players.append({
            "name": name,
            "short_name": short_name,
            "team": team_name,
            "team_code": team_code,
            "role": role,
            "rating": rating,
            "tier": tier
        })

# Sort by rating descending
all_players.sort(key=lambda x: x["rating"], reverse=True)

with open("ipl_players.csv", "w", newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=["name", "short_name", "team", "team_code", "role", "rating", "tier"])
    writer.writeheader()
    writer.writerows(all_players)

print("Generated ipl_players.csv with 180 players.")
