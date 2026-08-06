#!/usr/bin/env python3
from __future__ import annotations
import csv, json, subprocess, sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DUMP = ROOT / "tool" / "player_cards_dump.json"
MD_OUT = ROOT / "tool" / "players_by_sport.md"
CSV_OUT = ROOT / "tool" / "players_by_sport.csv"
COLUMNS = [
    "sport", "id", "name", "shortName", "role", "country", "countryCode",
    "position", "rating", "tier", "trait", "hasPortrait", "portraitAsset",
]
SPORT_ORDER = ["football", "cricket", "basketball", "tennis", "racing"]

def refresh_dump() -> None:
    extract = ROOT / "tool" / "extract_player_cards.py"
    subprocess.check_call([sys.executable, str(extract)], cwd=str(ROOT))

def load_rows():
    refresh_dump()
    return json.loads(DUMP.read_text(encoding="utf-8"))

def md_escape(value) -> str:
    s = "" if value is None else str(value)
    return s.replace("|", "\\|").replace("\n", " ")

def write_csv(rows):
    with CSV_OUT.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=COLUMNS, extrasaction="ignore")
        writer.writeheader()
        for r in rows:
            out = {k: r.get(k) for k in COLUMNS}
            out["hasPortrait"] = "yes" if r.get("hasPortrait") else "no"
            out["portraitAsset"] = r.get("portraitAsset") or ""
            writer.writerow(out)

def write_md(rows):
    by_sport = defaultdict(list)
    for r in rows:
        by_sport[r["sport"]].append(r)
    lines = [
        "# Players by sport",
        "",
        f"Total players: **{len(rows)}**",
        "",
        "## Summary",
        "",
        "| Sport | Count | With portrait | Missing portrait |",
        "| --- | ---: | ---: | ---: |",
    ]
    for sport in SPORT_ORDER:
        group = by_sport.get(sport, [])
        if not group:
            continue
        with_p = sum(1 for r in group if r.get("hasPortrait"))
        lines.append(f"| {sport} | {len(group)} | {with_p} | {len(group) - with_p} |")
    for sport, group in sorted(by_sport.items()):
        if sport in SPORT_ORDER:
            continue
        with_p = sum(1 for r in group if r.get("hasPortrait"))
        lines.append(f"| {sport} | {len(group)} | {with_p} | {len(group) - with_p} |")
    lines.extend(["", "---", ""])
    header = "| # | Name | Short | Role | Team / Country | Code | Pos | OVR | Tier | Trait | Image | Portrait asset | ID |"
    sep = "| ---: | --- | --- | --- | --- | --- | --- | ---: | --- | --- | --- | --- | --- |"
    order = SPORT_ORDER + [s for s in sorted(by_sport) if s not in SPORT_ORDER]
    for sport in order:
        group = by_sport.get(sport)
        if not group:
            continue
        with_p = sum(1 for r in group if r.get("hasPortrait"))
        lines.append(f"## {sport.title()} ({len(group)} players, {with_p} with image)")
        lines.append("")
        lines.append(header)
        lines.append(sep)
        for i, r in enumerate(group, 1):
            lines.append(
                "| "
                + " | ".join([
                    str(i),
                    md_escape(r.get("name")),
                    md_escape(r.get("shortName")),
                    md_escape(r.get("role")),
                    md_escape(r.get("country")),
                    md_escape(r.get("countryCode")),
                    md_escape(r.get("position")),
                    str(r.get("rating") or ""),
                    md_escape(r.get("tier")),
                    md_escape(r.get("trait")),
                    "yes" if r.get("hasPortrait") else "no",
                    md_escape(r.get("portraitAsset") or ""),
                    md_escape(r.get("id")),
                ])
                + " |"
            )
        lines.append("")
    MD_OUT.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")

def main():
    rows = load_rows()
    rows.sort(key=lambda r: (SPORT_ORDER.index(r["sport"]) if r["sport"] in SPORT_ORDER else 99, -r["rating"], r["name"]))
    write_csv(rows)
    write_md(rows)
    by_sport = defaultdict(int)
    for r in rows:
        by_sport[r["sport"]] += 1
    print(f"Wrote {CSV_OUT}")
    print(f"Wrote {MD_OUT}")
    print("counts:", dict(by_sport))

if __name__ == "__main__":
    main()