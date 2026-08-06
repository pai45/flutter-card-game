import urllib.request
from bs4 import BeautifulSoup
import json
import random

url = "https://en.wikipedia.org/wiki/List_of_current_NBA_team_rosters"
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
html = urllib.request.urlopen(req).read()

soup = BeautifulSoup(html, 'html.parser')

players = []
# On this page, each team has a table with class "toccolours"
tables = soup.find_all('table', class_='toccolours')

for table in tables:
    # Get team name from the table header or caption
    caption = table.find('caption')
    if not caption:
        continue
    team_name_tag = caption.find('a')
    if not team_name_tag:
        continue
    team_name = team_name_tag.text.strip()
    
    # Find the player roster table which is usually inside this table
    roster_table = table.find('table', class_='sortable')
    if not roster_table:
        continue
        
    rows = roster_table.find_all('tr')[1:] # Skip header
    for row in rows:
        cols = row.find_all(['td', 'th'])
        if len(cols) >= 3:
            # Pos is usually column 0
            pos = cols[0].text.strip()
            # Name is usually column 2
            name_tag = cols[2].find('a')
            if name_tag:
                name = name_tag.text.strip()
            else:
                name = cols[2].text.strip()
                
            # Remove any trailing citations like [1]
            if '[' in name:
                name = name.split('[')[0].strip()
                
            players.append({
                'name': name,
                'team': team_name,
                'position': pos
            })

print(f"Found {len(players)} players.")

# We need exactly 200 players
if len(players) > 200:
    players = random.sample(players, 200)

# Sort them just to have some order, maybe by team then name
players.sort(key=lambda x: (x['team'], x['name']))

# Generate short names and ratings
for p in players:
    parts = p['name'].split()
    if len(parts) >= 2:
        p['short_name'] = f"{parts[0][0]}. {parts[-1]}"
    else:
        p['short_name'] = p['name']
        
    # Rating between 70 and 99
    p['rating'] = random.randint(70, 99)

# Write to CSV
import csv
with open('nba_players.csv', 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=['name', 'short_name', 'position', 'team', 'rating'])
    writer.writeheader()
    for p in players:
        writer.writerow(p)

print("Saved to nba_players.csv")
