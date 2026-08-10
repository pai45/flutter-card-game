#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
compact = (ROOT / "tool" / "player_cards_compact.json").read_text(encoding="utf-8")
rows = json.loads(compact)
by_sport: dict[str, int] = {}
portraits: dict[str, int] = {}
for r in rows:
    by_sport[r["sport"]] = by_sport.get(r["sport"], 0) + 1
    if r["img"]:
        portraits[r["sport"]] = portraits.get(r["sport"], 0) + 1

header = """import {
  BarChart,
  Callout,
  Card,
  CardBody,
  CardHeader,
  Divider,
  Grid,
  H1,
  H2,
  Pill,
  Row,
  Select,
  Spacer,
  Stack,
  Stat,
  Table,
  Text,
  TextInput,
  useCanvasState,
  useHostTheme,
} from 'cursor/canvas';

type PlayerRow = {
  id: string;
  name: string;
  sport: string;
  role: string;
  teamOrCountry: string;
  code: string;
  pos: string;
  ovr: number;
  tier: string;
  trait: string;
  img: boolean;
  portrait: string;
};

const PLAYERS: PlayerRow[] = """

footer = """;

const SPORTS = ['all', 'football', 'cricket', 'basketball', 'tennis', 'racing'] as const;

const SPORT_COUNTS: Record<string, number> = %(sport)s;
const PORTRAIT_COUNTS: Record<string, number> = %(portrait)s;

function titleCase(s: string) {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

export default function PlayerCardsDatabase() {
  const theme = useHostTheme();
  const [sport, setSport] = useCanvasState<string>('sport', 'all');
  const [query, setQuery] = useCanvasState<string>('query', '');
  const [imgOnly, setImgOnly] = useCanvasState<string>('imgOnly', 'any');
  const [tier, setTier] = useCanvasState<string>('tier', 'all');

  const filtered = PLAYERS.filter((p) => {
    if (sport !== 'all' && p.sport !== sport) return false;
    if (imgOnly === 'yes' && !p.img) return false;
    if (imgOnly === 'no' && p.img) return false;
    if (tier !== 'all' && p.tier !== tier) return false;
    if (query.trim()) {
      const q = query.trim().toLowerCase();
      const hay = (
        p.name +
        ' ' +
        p.id +
        ' ' +
        p.teamOrCountry +
        ' ' +
        p.code +
        ' ' +
        p.pos +
        ' ' +
        p.role +
        ' ' +
        p.trait
      ).toLowerCase();
      if (!hay.includes(q)) return false;
    }
    return true;
  });

  const withImg = PLAYERS.filter((p) => p.img).length;
  const sportOrder = ['football', 'cricket', 'basketball', 'tennis', 'racing'];
  const chartCats = sportOrder.map(titleCase);
  const cardSeries = sportOrder.map((s) => SPORT_COUNTS[s] ?? 0);
  const portraitSeries = sportOrder.map((s) => PORTRAIT_COUNTS[s] ?? 0);

  return (
    <Stack gap={20} style={{ padding: 20, maxWidth: 1100 }}>
      <Stack gap={6}>
        <H1>Player card database</H1>
        <Text tone="secondary">
          Compile-time catalog behind allPlayerCards — not a remote SQL DB.
          Ownership stores card IDs only.
        </Text>
      </Stack>

      <Grid columns={4} gap={12}>
        <Stat value={String(PLAYERS.length)} label="Total collectible cards" />
        <Stat
          value={String(withImg)}
          label="Cards with portrait art"
          tone="success"
        />
        <Stat value="5" label="Sports mapped" />
        <Stat value={String(filtered.length)} label="Rows matching filters" />
      </Grid>

      <Card>
        <CardHeader>Cards vs portrait coverage by sport</CardHeader>
        <CardBody>
          <BarChart
            categories={chartCats}
            series={[
              { name: 'Cards', data: cardSeries },
              { name: 'Portraits', data: portraitSeries },
            ]}
            height={220}
          />
          <Text size="small" tone="secondary" style={{ marginTop: 8 }}>
            Source: Dart catalogs. Football 180/180 portraits, cricket 65/180,
            racing 22/105 real F1 art. Basketball and tennis have no player
            photos.
          </Text>
        </CardBody>
      </Card>

      <Callout tone="info" title="How sport and image map">
        Sport comes from PlayerRole. Football portraits resolve via shortName to
        playerPortraitAssets. Cricket sets portraitAsset inline. Racing always
        has a path; only 22 F1 IDs ship real art. Basketball and tennis use
        procedural or monogram UI.
      </Callout>

      <H2>Browse roster</H2>
      <Row gap={10} style={{ flexWrap: 'wrap', alignItems: 'flex-end' }}>
        <Stack gap={4} style={{ minWidth: 140 }}>
          <Text size="small" tone="secondary">
            Sport
          </Text>
          <Select
            value={sport}
            onChange={setSport}
            options={SPORTS.map((s) => ({
              value: s,
              label: s === 'all' ? 'All sports' : titleCase(s),
            }))}
          />
        </Stack>
        <Stack gap={4} style={{ minWidth: 140 }}>
          <Text size="small" tone="secondary">
            Portrait
          </Text>
          <Select
            value={imgOnly}
            onChange={setImgOnly}
            options={[
              { value: 'any', label: 'Any' },
              { value: 'yes', label: 'Has image' },
              { value: 'no', label: 'No image' },
            ]}
          />
        </Stack>
        <Stack gap={4} style={{ minWidth: 140 }}>
          <Text size="small" tone="secondary">
            Tier
          </Text>
          <Select
            value={tier}
            onChange={setTier}
            options={[
              { value: 'all', label: 'All tiers' },
              { value: 'platinum', label: 'Platinum' },
              { value: 'gold', label: 'Gold' },
              { value: 'silver', label: 'Silver' },
              { value: 'bronze', label: 'Bronze' },
            ]}
          />
        </Stack>
        <Stack gap={4} style={{ flex: 1, minWidth: 200 }}>
          <Text size="small" tone="secondary">
            Search
          </Text>
          <TextInput
            value={query}
            onChange={setQuery}
            placeholder="Name, id, team, country, trait"
          />
        </Stack>
      </Row>

      <Row gap={8} style={{ flexWrap: 'wrap' }}>
        {sportOrder.map((s) => (
          <Pill
            key={s}
            active={sport === s}
            onClick={() => setSport(sport === s ? 'all' : s)}
          >
            {titleCase(s)} · {SPORT_COUNTS[s]}
          </Pill>
        ))}
      </Row>

      <Table
        stickyHeader
        columns={[
          { id: 'name', header: 'Player', sortable: true },
          { id: 'sport', header: 'Sport', sortable: true, width: 100 },
          { id: 'role', header: 'Role', sortable: true, width: 120 },
          { id: 'team', header: 'Team / country', sortable: true },
          { id: 'pos', header: 'Pos', width: 90 },
          {
            id: 'ovr',
            header: 'OVR',
            sortable: true,
            align: 'right',
            width: 70,
          },
          { id: 'tier', header: 'Tier', sortable: true, width: 90 },
          { id: 'img', header: 'Image', sortable: true, width: 80 },
          { id: 'portrait', header: 'Portrait asset' },
        ]}
        rows={filtered.slice(0, 400).map((p) => {
          const team =
            p.code && p.code !== p.teamOrCountry
              ? p.teamOrCountry + ' (' + p.code + ')'
              : p.teamOrCountry;
          return {
            key: p.id,
            cells: [
              p.name,
              titleCase(p.sport),
              p.role,
              team,
              p.pos,
              p.ovr,
              p.tier,
              p.img ? 'Yes' : '—',
              p.portrait || '—',
            ],
          };
        })}
      />
      <Text tone="secondary" size="small">
        {filtered.length > 400
          ? 'Showing first 400 of ' +
            filtered.length +
            ' matches — narrow filters to see the rest.'
          : filtered.length + ' rows · ids match runtime allPlayerCards'}
      </Text>

      <Divider />
      <H2>Schema (PlayerCard)</H2>
      <Text tone="secondary" size="small">
        id, name, shortName, country, countryCode, position, role, rating,
        trait, tier, icon, portraitAsset. Helpers: resolvedPortraitAsset,
        hasPortrait. Sport is inferred from role.
      </Text>
      <Spacer height={8} />
      <Text size="small" style={{ color: theme.textSecondary }}>
        Key files: lib/models/cards.dart, lib/data/basketball_athletes.dart,
        lib/data/tennis_athletes.dart, lib/data/racing_drivers.dart,
        lib/data/racing_portraits.dart, assets/player_images,
        assets/cricketer_images, assets/racing_driver_images
      </Text>
    </Stack>
  );
}
""" % {
    "sport": json.dumps(by_sport),
    "portrait": json.dumps(portraits),
}

out_dir = Path(
    r"C:\Users\priya\.cursor\projects\c-Users-priya-OneDrive-Desktop-flutter-projects-card-game\canvases"
)
out_dir.mkdir(parents=True, exist_ok=True)
out = out_dir / "player-cards-database.canvas.tsx"
out.write_text(header + compact + footer, encoding="utf-8")
print("wrote", out)
print("bytes", out.stat().st_size)
print("players", len(rows))
