from bs4 import BeautifulSoup
import random
import csv

with open('scratch/nba_players.html', 'r', encoding='utf-8') as f:
    html = f.read()

soup = BeautifulSoup(html, 'html.parser')

players = []
# Find the large table
tables = soup.find_all('table', class_='sortable')
print(f"Found {len(tables)} sortable tables.")

if not tables:
    print("No sortable table found!")
    exit(1)

table = tables[0]
rows = table.find_all('tr')[1:] # skip header
for row in rows:
    cols = row.find_all(['td', 'th'])
    if len(cols) >= 4:
        # Player name is typically in cols[0]
        name_col = cols[0]
        # sometimes it has a span for sortkey
        a_tag = name_col.find('a')
        name = a_tag.text.strip() if a_tag else name_col.text.strip()
        
        # Team is cols[1]
        team_col = cols[1]
        team_a = team_col.find('a')
        team = team_a.text.strip() if team_a else team_col.text.strip()
        
        # Position is usually cols[3]
        pos_col = cols[3]
        pos = pos_col.text.strip()
        
        # Clean up
        if '[' in name: name = name.split('[')[0].strip()
        if '[' in team: team = team.split('[')[0].strip()
        if '[' in pos: pos = pos.split('[')[0].strip()
        
        if name and team:
            players.append({'name': name, 'team': team, 'position': pos})

print(f"Found {len(players)} players.")

# We need exactly 200 players
if len(players) > 200:
    players = random.sample(players, 200)

players.sort(key=lambda x: x['name'])

# Generate short names and ratings
for p in players:
    parts = p['name'].split()
    if len(parts) >= 2:
        p['short_name'] = f"{parts[0][0]}. {parts[-1]}"
    else:
        p['short_name'] = p['name']
        
    p['rating'] = random.randint(70, 99)

with open('nba_players.csv', 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=['name', 'short_name', 'position', 'team', 'rating'])
    writer.writeheader()
    for p in players:
        writer.writerow(p)

print("Saved to nba_players.csv")
