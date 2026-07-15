# Final Over Art Bible

Final Over uses original, sponsor-free 2D arcade art. The written product specification is authoritative; its embedded mockups are composition references only.

## Palette

- Night navy `#0D111A`
- Primary cyan `#5CDFFF`
- Deep blue `#00285E`
- Success green `#45D61F`
- Warning yellow `#FFC400`
- Error red `#E62D2D`
- Main white `#F5F7FA`
- Muted blue-gray `#9FB0C4`
- Pitch brown `#B88A4A`
- Uniform orange `#FF8A1F`

## Characters

- Batter: right-handed, royal-blue kit, orange side panels, navy helmet, white pads and gloves, number 06.
- Non-striker: same original kit language, alternate number 12.
- Bowler: right-arm pace silhouette, deep-blue kit with cyan shoulders and orange seam accent.
- Umpire: charcoal neutral uniform and pale brimmed hat.
- Outfielders: red/orange circular markers with outline, chase stretch, catch ring, pickup core, and throw pulse states.

All actors are articulated code-native vector rigs. Feet are the world anchor; limbs rotate around explicit joints. No licensed likeness, team mark, sponsor, or national identifier is permitted.

## Environments

- Batting: portrait navy night stadium, cyan floodlights, quiet center/lower zones. The pitch, actors, ball, stumps, HUD, and controls are drawn at runtime.
- Fielding: square overhead striped green field with a navy/cyan perimeter. The pitch, markers, runners, ball, and trails are drawn at runtime.

## Readability

Every state uses shape and motion as well as color. Controls are at least 48 logical pixels. Backgrounds never contain gameplay-critical objects. Effects remain inside safe areas and never obscure the live ball.

## Typography

Final Over bundles Roboto Condensed Regular and Bold as `FinalOverCondensed` for a compact scoreboard voice. The files come from Flutter's material-font artifact, are licensed under Apache License 2.0, and are recorded in the asset provenance manifest. They are independent of the host application.
