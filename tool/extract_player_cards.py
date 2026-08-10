#!/usr/bin/env python3
from __future__ import annotations
import json, re
from pathlib import Path

ROOT = Path(r"c:\Users\priya\OneDrive\Desktop\flutter_projects\card_game")
OUT = ROOT / "tool" / "player_cards_dump.json"
COMPACT = ROOT / "tool" / "player_cards_compact.json"

def extract_ctors(text: str, name: str) -> list[str]:
    """Extract top-level Constructor(...) blocks with nested paren awareness."""
    blocks = []
    needle = name + "("
    i = 0
    while True:
        j = text.find(needle, i)
        if j < 0:
            break
        start = j + len(name)
        # start at '('
        depth = 0
        k = start
        while k < len(text):
            ch = text[k]
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    blocks.append(text[start + 1 : k])
                    i = k + 1
                    break
            k += 1
        else:
            break
    return blocks

def field_str(block: str, key: str) -> str | None:
    m = re.search(rf"{key}:\s*'((?:\\'|[^'])*)'", block)
    if m:
        return m.group(1).replace("\\'", "'")
    m = re.search(rf'{key}:\s*"((?:\\"|[^"]*)*)"', block)
    if m:
        return m.group(1)
    return None

def field_ident(block: str, key: str) -> str | None:
    m = re.search(rf"{key}:\s*([A-Za-z0-9_./]+)", block)
    return m.group(1) if m else None

def field_int(block: str, key: str) -> int:
    m = re.search(rf"{key}:\s*(\d+)", block)
    return int(m.group(1)) if m else 0

def pack_rarity(ovr: int) -> str:
    if ovr >= 90: return "platinum"
    if ovr >= 86: return "gold"
    if ovr >= 80: return "silver"
    return "bronze"

def basketball_tier(ovr: int) -> str:
    if ovr >= 92: return "platinum"
    if ovr >= 87: return "gold"
    if ovr >= 80: return "silver"
    return "bronze"

def short_name(name: str, basketball: bool = False) -> str:
    clean = name.replace(".", "") if basketball else name
    parts = [p for p in clean.split(" ") if p]
    if len(parts) == 1:
        return parts[0].upper()
    return f"{parts[0][0].upper()} {parts[-1].upper()}"

def slugify(name: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", name.lower())
    return s.strip("-")

def parse_portrait_map(text: str) -> dict[str, str]:
    m = re.search(r"playerPortraitAssets\s*=\s*\{(.*?)\};", text, re.S)
    if not m:
        return {}
    return dict(re.findall(r"'((?:\\'|[^'])*)'\s*:\s*'((?:\\'|[^'])*)'", m.group(1)))

def main() -> None:
    cards_text = (ROOT / "lib/models/cards.dart").read_text(encoding="utf-8")
    portraits = parse_portrait_map(cards_text)

    football, cricket = [], []
    for block in extract_ctors(cards_text, "PlayerCard"):
        role = (field_ident(block, "role") or "").replace("PlayerRole.", "")
        short = field_str(block, "shortName") or ""
        portrait = field_str(block, "portraitAsset")
        row = {
            "id": field_str(block, "id") or "",
            "name": field_str(block, "name") or "",
            "shortName": short,
            "role": role,
            "country": field_str(block, "country") or "",
            "countryCode": field_str(block, "countryCode") or "",
            "position": field_str(block, "position") or "",
            "rating": field_int(block, "rating"),
            "trait": field_str(block, "trait") or "",
            "tier": (field_ident(block, "tier") or "").replace("CardTier.", ""),
            "portraitAsset": portrait,
            "hasPortrait": False,
        }
        if role in {"attacker", "defender", "goalkeeper"}:
            asset = portrait or portraits.get(short)
            row["sport"] = "football"
            row["portraitAsset"] = asset
            row["hasPortrait"] = asset is not None
            football.append(row)
        elif role in {"batsman", "bowler"}:
            row["sport"] = "cricket"
            row["hasPortrait"] = portrait is not None
            cricket.append(row)

    # Basketball
    bb = (ROOT / "lib/data/basketball_athletes.dart").read_text(encoding="utf-8")
    team_names = dict(re.findall(r"'([A-Z]{2,3})'\s*:\s*'((?:\\'|[^'])*)'", bb))
    role_map = {
        "BasketballCardRole.guard": "basketballGuard",
        "BasketballCardRole.wing": "basketballWing",
        "BasketballCardRole.big": "basketballBig",
    }
    basketball = []
    for m in re.finditer(
        r"_Seed\(\s*'([^']+)'\s*,\s*'((?:\\'|[^'])*)'\s*,\s*'((?:\\'|[^'])*)'\s*,\s*(BasketballCardRole\.\w+)\s*,\s*(\d+)\s*\)",
        bb,
    ):
        team, name, pos, role, ovr = m.groups()
        ovr_i = int(ovr)
        basketball.append({
            "id": f"{team.lower()}-{slugify(name)}",
            "name": name,
            "shortName": short_name(name, basketball=True),
            "sport": "basketball",
            "role": role_map[role],
            "country": team_names.get(team, team),
            "countryCode": team,
            "position": pos,
            "rating": ovr_i,
            "trait": "",
            "tier": basketball_tier(ovr_i),
            "portraitAsset": None,
            "hasPortrait": False,
        })

    # Tennis
    tennis_text = (ROOT / "lib/data/tennis_athletes.dart").read_text(encoding="utf-8")
    cmap_path = ROOT / "lib/utils/tennis_country_map.dart"
    country_map = {}
    if cmap_path.exists():
        country_map = dict(re.findall(r"'((?:\\'|[^'])*)'\s*:\s*'([A-Z]{2,3})'", cmap_path.read_text(encoding="utf-8")))
    tennis = []
    for block in extract_ctors(tennis_text, "TennisPlayer"):
        name = field_str(block, "name") or ""
        ovr = field_int(block, "overallRating")
        arch = (field_ident(block, "archetype") or "").replace("TennisArchetype.", "")
        country = country_map.get(name, "INT")
        tennis.append({
            "id": field_str(block, "id") or slugify(name),
            "name": name,
            "shortName": short_name(name),
            "sport": "tennis",
            "role": "tennisSingles",
            "country": country,
            "countryCode": country,
            "position": arch,
            "rating": ovr,
            "trait": field_str(block, "signature") or "",
            "tier": pack_rarity(ovr),
            "portraitAsset": None,
            "hasPortrait": False,
        })

    # Racing
    racing_text = (ROOT / "lib/data/racing_drivers.dart").read_text(encoding="utf-8")
    portraits_text = (ROOT / "lib/data/racing_portraits.dart").read_text(encoding="utf-8")
    art_section = portraits_text.split("kRacingPortraitArtIds")[1].split(";")[0]
    art_ids = set(re.findall(r"'([a-z0-9-]+)'", art_section))
    series_role = {
        "RacingSeries.f1": "f1Driver",
        "RacingSeries.f2": "f2Driver",
        "RacingSeries.nascar": "nascarDriver",
        "RacingSeries.indycar": "indycarDriver",
    }
    racing = []
    for block in extract_ctors(racing_text, "RacingDriver"):
        did = field_str(block, "id") or ""
        name = field_str(block, "name") or ""
        ovr = field_int(block, "overallRating")
        series = field_ident(block, "series") or ""
        has_art = did in art_ids
        portrait = f"assets/racing_driver_images/{did}.png"
        racing.append({
            "id": did,
            "name": name,
            "shortName": short_name(name),
            "sport": "racing",
            "role": series_role.get(series, series.replace("RacingSeries.", "")),
            "country": field_str(block, "country") or "",
            "countryCode": field_str(block, "countryCode") or "",
            "position": field_str(block, "team") or "",
            "rating": ovr,
            "trait": field_str(block, "signature") or "",
            "tier": pack_rarity(ovr),
            "portraitAsset": portrait,
            "hasPortrait": has_art,
        })

    rows = football + cricket + basketball + tennis + racing
    rows.sort(key=lambda r: (r["sport"], -r["rating"], r["name"]))
    OUT.write_text(json.dumps(rows, indent=2, ensure_ascii=False), encoding="utf-8")

    compact = [{
        "id": r["id"],
        "name": r["name"],
        "sport": r["sport"],
        "role": r["role"],
        "teamOrCountry": r["country"],
        "code": r["countryCode"],
        "pos": r["position"],
        "ovr": r["rating"],
        "tier": r["tier"],
        "trait": (r.get("trait") or "")[:80],
        "img": bool(r["hasPortrait"]),
        "portrait": r.get("portraitAsset") or "",
    } for r in rows]
    COMPACT.write_text(json.dumps(compact, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    by_sport, portraits_by = {}, {}
    for r in rows:
        by_sport[r["sport"]] = by_sport.get(r["sport"], 0) + 1
        if r["hasPortrait"]:
            portraits_by[r["sport"]] = portraits_by.get(r["sport"], 0) + 1
    print(f"Wrote {len(rows)}")
    print("counts", by_sport)
    print("portraits", portraits_by)
    # sanity
    albon = next(r for r in rows if r["id"] == "alexander-albon")
    jokic = next(r for r in rows if "jokic" in r["id"])
    mbappe = next(r for r in rows if "mbappe" in r["id"])
    print("albon", albon["rating"], albon["hasPortrait"])
    print("jokic", jokic["country"], jokic["rating"])
    print("mbappe", mbappe["name"], mbappe["portraitAsset"])

if __name__ == "__main__":
    main()
