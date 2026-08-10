import csv
import random

players_data = [
    ("LeBron James", "LAL", "F"), ("Anthony Davis", "LAL", "F-C"), ("Stephen Curry", "GSW", "G"), ("Klay Thompson", "GSW", "G"), 
    ("Draymond Green", "GSW", "F"), ("Kevin Durant", "PHX", "F"), ("Devin Booker", "PHX", "G"), ("Bradley Beal", "PHX", "G"),
    ("Luka Doncic", "DAL", "G"), ("Kyrie Irving", "DAL", "G"), ("Nikola Jokic", "DEN", "C"), ("Jamal Murray", "DEN", "G"),
    ("Aaron Gordon", "DEN", "F"), ("Michael Porter Jr.", "DEN", "F"), ("Giannis Antetokounmpo", "MIL", "F"), ("Damian Lillard", "MIL", "G"),
    ("Khris Middleton", "MIL", "F"), ("Jayson Tatum", "BOS", "F"), ("Jaylen Brown", "BOS", "F"), ("Kristaps Porzingis", "BOS", "F-C"),
    ("Jrue Holiday", "BOS", "G"), ("Derrick White", "BOS", "G"), ("Joel Embiid", "PHI", "C"), ("Tyrese Maxey", "PHI", "G"),
    ("Tobias Harris", "PHI", "F"), ("Donovan Mitchell", "CLE", "G"), ("Darius Garland", "CLE", "G"), ("Evan Mobley", "CLE", "F-C"),
    ("Jarrett Allen", "CLE", "C"), ("Jalen Brunson", "NYK", "G"), ("Julius Randle", "NYK", "F"), ("OG Anunoby", "NYK", "F"),
    ("Mikal Bridges", "BKN", "F"), ("Cam Thomas", "BKN", "G"), ("Nic Claxton", "BKN", "C"), ("Trae Young", "ATL", "G"),
    ("Dejounte Murray", "ATL", "G"), ("Clint Capela", "ATL", "C"), ("Paolo Banchero", "ORL", "F"), ("Franz Wagner", "ORL", "F"),
    ("Jimmy Butler", "MIA", "F"), ("Bam Adebayo", "MIA", "C-F"), ("Tyler Herro", "MIA", "G"), ("Tyrese Haliburton", "IND", "G"),
    ("Pascal Siakam", "IND", "F"), ("Myles Turner", "IND", "C"), ("De'Aaron Fox", "SAC", "G"), ("Domantas Sabonis", "SAC", "F-C"),
    ("Keegan Murray", "SAC", "F"), ("Zion Williamson", "NOP", "F"), ("Brandon Ingram", "NOP", "F"), ("CJ McCollum", "NOP", "G"),
    ("Shai Gilgeous-Alexander", "OKC", "G"), ("Chet Holmgren", "OKC", "C-F"), ("Jalen Williams", "OKC", "F-G"),
    ("Anthony Edwards", "MIN", "G"), ("Karl-Anthony Towns", "MIN", "F-C"), ("Rudy Gobert", "MIN", "C"), ("Kawhi Leonard", "LAC", "F"),
    ("Paul George", "LAC", "F"), ("James Harden", "LAC", "G"), ("Lauri Markkanen", "UTA", "F"), ("Jordan Clarkson", "UTA", "G"),
    ("Victor Wembanyama", "SAS", "C-F"), ("Devin Vassell", "SAS", "G"), ("Keldon Johnson", "SAS", "F"), ("Ja Morant", "MEM", "G"),
    ("Desmond Bane", "MEM", "G"), ("Jaren Jackson Jr.", "MEM", "F-C"), ("DeMar DeRozan", "CHI", "F-G"), ("Zach LaVine", "CHI", "G"),
    ("Nikola Vucevic", "CHI", "C"), ("Coby White", "CHI", "G"), ("Scottie Barnes", "TOR", "F"), ("Immanuel Quickley", "TOR", "G"),
    ("RJ Barrett", "TOR", "G-F"), ("Cade Cunningham", "DET", "G"), ("Jaden Ivey", "DET", "G"), ("Jalen Duren", "DET", "C"),
    ("Alperen Sengun", "HOU", "C"), ("Jalen Green", "HOU", "G"), ("Fred VanVleet", "HOU", "G"), ("LaMelo Ball", "CHA", "G"),
    ("Miles Bridges", "CHA", "F"), ("Brandon Miller", "CHA", "F"), ("Kyle Kuzma", "WAS", "F"), ("Jordan Poole", "WAS", "G"),
    ("Deandre Ayton", "POR", "C"), ("Anfernee Simons", "POR", "G"), ("Jerami Grant", "POR", "F"), ("Austin Reaves", "LAL", "G"),
    ("D'Angelo Russell", "LAL", "G"), ("Rui Hachimura", "LAL", "F"), ("Jonathan Kuminga", "GSW", "F"), ("Andrew Wiggins", "GSW", "F"),
    ("Kevon Looney", "GSW", "C"), ("Jusuf Nurkic", "PHX", "C"), ("Grayson Allen", "PHX", "G"), ("Tim Hardaway Jr.", "DAL", "G"),
    ("Dereck Lively II", "DAL", "C"), ("Kentavious Caldwell-Pope", "DEN", "G"), ("Bobby Portis", "MIL", "F-C"),
    ("Brook Lopez", "MIL", "C"), ("Al Horford", "BOS", "C-F"), ("Payton Pritchard", "BOS", "G"), ("Kelly Oubre Jr.", "PHI", "F"),
    ("Paul Reed", "PHI", "F-C"), ("Caris LeVert", "CLE", "G"), ("Max Strus", "CLE", "G-F"), ("Josh Hart", "NYK", "G-F"),
    ("Donte DiVincenzo", "NYK", "G"), ("Cameron Johnson", "BKN", "F"), ("Dennis Schroder", "BKN", "G"), ("Bogdan Bogdanovic", "ATL", "G"),
    ("Jalen Johnson", "ATL", "F"), ("Wendell Carter Jr.", "ORL", "C"), ("Jalen Suggs", "ORL", "G"), ("Cole Anthony", "ORL", "G"),
    ("Duncan Robinson", "MIA", "G"), ("Bennedict Mathurin", "IND", "G"), ("Aaron Nesmith", "IND", "F"), ("Obi Toppin", "IND", "F"),
    ("Malik Monk", "SAC", "G"), ("Kevin Huerter", "SAC", "G"), ("Harrison Barnes", "SAC", "F"), ("Jonas Valanciunas", "NOP", "C"),
    ("Trey Murphy III", "NOP", "F"), ("Herbert Jones", "NOP", "F"), ("Josh Giddey", "OKC", "G"), ("Luguentz Dort", "OKC", "G"),
    ("Naz Reid", "MIN", "C-F"), ("Jaden McDaniels", "MIN", "F"), ("Mike Conley", "MIN", "G"), ("Norman Powell", "LAC", "G"),
    ("Ivica Zubac", "LAC", "C"), ("Terance Mann", "LAC", "G"), ("Collin Sexton", "UTA", "G"), ("John Collins", "UTA", "F"),
    ("Walker Kessler", "UTA", "C"), ("Tre Jones", "SAS", "G"), ("Jeremy Sochan", "SAS", "F"), ("Marcus Smart", "MEM", "G"),
    ("Luke Kennard", "MEM", "G"), ("Alex Caruso", "CHI", "G"), ("Patrick Williams", "CHI", "F"), ("Jakob Poeltl", "TOR", "C"),
    ("Gary Trent Jr.", "TOR", "G"), ("Isaiah Stewart", "DET", "F-C"), ("Ausar Thompson", "DET", "G-F"), ("Jabari Smith Jr.", "HOU", "F"),
    ("Dillon Brooks", "HOU", "F"), ("Amen Thompson", "HOU", "G"), ("Mark Williams", "CHA", "C"), ("Nick Richards", "CHA", "C"),
    ("Deni Avdija", "WAS", "F"), ("Corey Kispert", "WAS", "F"), ("Tyus Jones", "WAS", "G"), ("Malcolm Brogdon", "POR", "G"),
    ("Scoot Henderson", "POR", "G"), ("Shaedon Sharpe", "POR", "G"), ("Gabe Vincent", "LAL", "G"), ("Christian Wood", "LAL", "F"),
    ("Brandin Podziemski", "GSW", "G"), ("Trayce Jackson-Davis", "GSW", "F"), ("Eric Gordon", "PHX", "G"), ("Royce O'Neale", "PHX", "F"),
    ("Josh Green", "DAL", "G"), ("P.J. Washington", "DAL", "F"), ("Christian Braun", "DEN", "G"), ("Peyton Watson", "DEN", "F"),
    ("Pat Connaughton", "MIL", "G"), ("Malik Beasley", "MIL", "G"), ("Sam Hauser", "BOS", "F"), ("Luke Kornet", "BOS", "C"),
    ("Buddy Hield", "PHI", "G"), ("Nicolas Batum", "PHI", "F"), ("Isaac Okoro", "CLE", "G-F"), ("Georges Niang", "CLE", "F"),
    ("Isaiah Hartenstein", "NYK", "C"), ("Precious Achiuwa", "NYK", "F"), ("Dorian Finney-Smith", "BKN", "F"), ("Day'Ron Sharpe", "BKN", "C"),
    ("Saddiq Bey", "ATL", "F"), ("Onyeka Okongwu", "ATL", "C-F"), ("Jonathan Isaac", "ORL", "F"), ("Moritz Wagner", "ORL", "C-F"),
    ("Caleb Martin", "MIA", "F"), ("Jaime Jaquez Jr.", "MIA", "G-F")
]

# Ensure we have 200 players, pad if necessary
while len(players_data) < 200:
    players_data.append((f"Player {len(players_data)}", "UNK", "G"))

players_data = players_data[:200]

with open('nba_players.csv', 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=['name', 'short_name', 'position', 'team', 'rating'])
    writer.writeheader()
    for name, team, pos in players_data:
        parts = name.split()
        if len(parts) >= 2:
            short_name = f"{parts[0][0]}. {' '.join(parts[1:])}"
        else:
            short_name = name
        
        rating = random.randint(70, 99)
        writer.writerow({
            'name': name,
            'short_name': short_name,
            'position': pos,
            'team': team,
            'rating': rating
        })

print("Generated nba_players.csv with 200 players.")
