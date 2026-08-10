import pandas as pd
import random
import csv

try:
    tables = pd.read_html('scratch/nba_players.html')
except Exception as e:
    print("Error reading html:", e)
    exit(1)

players = []

for df in tables:
    if 'Name' in df.columns and 'Team' in df.columns and 'Pos.' in df.columns:
        for _, row in df.iterrows():
            name = str(row['Name'])
            team = str(row['Team'])
            pos = str(row['Pos.'])
            
            # Skip header rows that might be duplicated
            if name.lower() == 'name': continue
            
            # Remove brackets in name and team
            if '[' in name: name = name.split('[')[0].strip()
            if '[' in team: team = team.split('[')[0].strip()
            if '[' in pos: pos = pos.split('[')[0].strip()
            
            # Pandas sometimes puts NaN
            if name != 'nan' and team != 'nan':
                players.append({
                    'name': name.strip(),
                    'position': pos.strip(),
                    'team': team.strip()
                })

print(f"Found {len(players)} players.")
if len(players) > 200:
    players = random.sample(players, 200)

players.sort(key=lambda x: x['name'])

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
