import pandas as pd
import random
import csv
import time
import urllib.request
import sys
import io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

teams = [
    "Atlanta_Hawks", "Boston_Celtics", "Brooklyn_Nets", "Charlotte_Hornets",
    "Chicago_Bulls", "Cleveland_Cavaliers", "Dallas_Mavericks", "Denver_Nuggets",
    "Detroit_Pistons", "Golden_State_Warriors", "Houston_Rockets", "Indiana_Pacers",
    "Los_Angeles_Clippers", "Los_Angeles_Lakers", "Memphis_Grizzlies", "Miami_Heat",
    "Milwaukee_Bucks", "Minnesota_Timberwolves", "New_Orleans_Pelicans", "New_York_Knicks",
    "Oklahoma_City_Thunder", "Orlando_Magic", "Philadelphia_76ers", "Phoenix_Suns",
    "Portland_Trail_Blazers", "Sacramento_Kings", "San_Antonio_Spurs", "Toronto_Raptors",
    "Utah_Jazz", "Washington_Wizards"
]

players = []

for team_id in teams:
    url = f"https://en.wikipedia.org/wiki/Template:{team_id}_roster"
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        html = urllib.request.urlopen(req).read().decode('utf-8')
        tables = pd.read_html(html)
        
        for df in tables:
            if 'Pos.' in df.columns and 'Player' in df.columns:
                team_name = team_id.replace('_', ' ')
                for _, row in df.iterrows():
                    name = str(row['Player'])
                    pos = str(row['Pos.'])
                    
                    if '(' in name: name = name.split('(')[0]
                    if '[' in name: name = name.split('[')[0]
                    name = name.strip()
                    
                    if name.lower() != 'player' and name.lower() != 'nan':
                        players.append({
                            'name': name,
                            'position': pos.strip(),
                            'team': team_name
                        })
                break
        print(f"Scraped {team_id}")
    except Exception:
        print(f"Failed to scrape {team_id}")
    time.sleep(0.5)

print(f"Total players found: {len(players)}")

if len(players) > 200:
    players = random.sample(players, 200)

players.sort(key=lambda x: (x['team'], x['name']))

for p in players:
    parts = p['name'].split()
    if len(parts) >= 2:
        p['short_name'] = f"{parts[0][0]}. {' '.join(parts[1:])}"
    else:
        p['short_name'] = p['name']
    
    p['rating'] = random.randint(70, 99)

with open('nba_players.csv', 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=['name', 'short_name', 'position', 'team', 'rating'])
    writer.writeheader()
    for p in players:
        writer.writerow(p)

print("Saved to nba_players.csv")
