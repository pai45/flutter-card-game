import random
import csv
import re

with open('scratch/nba_players.html', 'r', encoding='utf-8') as f:
    html = f.read()

# Extract all TR elements
trs = re.findall(r'<tr[^>]*>(.*?)</tr>', html, re.IGNORECASE | re.DOTALL)

players = []
for tr in trs:
    # Extract all TD/TH
    cols = re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', tr, re.IGNORECASE | re.DOTALL)
    
    # We expect a row for a player to have at least 4 columns: Name, Team, Number, Position...
    if len(cols) >= 4:
        # Strip all HTML tags
        clean_cols = [re.sub(r'<[^>]+>', '', c).strip() for c in cols]
        
        name = clean_cols[0]
        team = clean_cols[1]
        pos = clean_cols[3]
        
        # Remove footnote links like [1]
        name = re.sub(r'\[\d+\]', '', name).strip()
        team = re.sub(r'\[\d+\]', '', team).strip()
        pos = re.sub(r'\[\d+\]', '', pos).strip()
        
        # Heuristics to skip header rows:
        if name.lower() == 'player' or name.lower() == 'name':
            continue
            
        if name and team:
            players.append({'name': name, 'team': team, 'position': pos})

# Sort and filter empty or bad parses
# Usually there are around 400+ players.
valid_players = [p for p in players if p['position'] in ['PG', 'SG', 'SF', 'PF', 'C', 'G', 'F', 'G-F', 'F-C', 'C-F', 'F-G']]

print(f"Parsed {len(valid_players)} valid players.")

if len(valid_players) > 200:
    valid_players = random.sample(valid_players, 200)
else:
    # If not enough players parsed correctly, this will fail gracefully.
    print("Warning: less than 200 players parsed.")

# Sort them just to have some order, maybe by name
valid_players.sort(key=lambda x: x['name'])

# Generate short names and ratings
for p in valid_players:
    parts = p['name'].split()
    if len(parts) >= 2:
        p['short_name'] = f"{parts[0][0]}. {' '.join(parts[1:])}"
    else:
        p['short_name'] = p['name']
        
    p['rating'] = random.randint(70, 99)

with open('nba_players.csv', 'w', newline='', encoding='utf-8') as f:
    writer = csv.DictWriter(f, fieldnames=['name', 'short_name', 'position', 'team', 'rating'])
    writer.writeheader()
    for p in valid_players:
        writer.writerow(p)

print("Saved to nba_players.csv")
