import json, urllib.request

try:
    data = json.loads(urllib.request.urlopen('https://site.api.espn.com/apis/site/v2/sports/basketball/wnba/scoreboard?dates=20260713').read())
    events = data.get('events', [])
    print(f"Total events: {len(events)}")
    for event in events:
        print(f"Event ID: {event.get('id')}")
        comp = event.get('competitions', [None])[0]
        if not comp:
            print("No competition")
            continue
        competitors = comp.get('competitors', [])
        if len(competitors) < 2:
            print("Less than 2 competitors")
            continue
        home = next((c for c in competitors if c.get('homeAway') == 'home'), competitors[0])
        away = next((c for c in competitors if c.get('homeAway') == 'away'), competitors[1])
        try:
            print("Home:", home['team']['name'])
            print("Away:", away['team']['name'])
        except Exception as e:
            print("Error parsing teams:", e)
except Exception as e:
    print("Fetch error:", e)
