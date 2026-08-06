import re

content = open('lib/services/prediction_repository.dart', 'r').read()

matches = re.finditer(r"id:\s*'([^']+)',\s*name:\s*'([^']+)',\s*shortName:\s*'([^']+)',\s*color:\s*Color\((0x[0-9a-fA-F]+)\)", content)

dart_file = '''import 'package:flutter/material.dart';

const Map<String, Color> kTeamColors = {
'''

seen = set()
for m in matches:
    team_id = m.group(1)
    name = m.group(2)
    short_name = m.group(3)
    color = m.group(4)
    if short_name not in seen:
        dart_file += f"  '{short_name}': Color({color}), // {name}\n"
        seen.add(short_name)

dart_file += '};\n'

with open('lib/data/team_colors.dart', 'w') as f:
    f.write(dart_file)
