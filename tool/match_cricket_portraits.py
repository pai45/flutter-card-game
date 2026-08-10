import json, re, shutil
from pathlib import Path

SRC = Path(r"C:\Users\priya\.cursor\projects\c-Users-priya-OneDrive-Desktop-flutter-projects-card-game\assets")
DEST = Path("assets/cricketer_images")
DEST.mkdir(parents=True, exist_ok=True)

UUID_RE = re.compile(
    r"c__Users_priya_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_(.+)-"
    r"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.png$",
    re.I,
)

RACING_SKIP = {
    "mercedes", "ferrari", "mclaren", "red_bull", "aston_martin", "alpine",
    "williams", "haas", "sauber", "racing_bulls", "kick_sauber", "rb",
}

def slugify(s: str) -> str:
    s = s.lower().replace("&", "and")
    s = re.sub(r"[^a-z0-9]+", "_", s)
    return s.strip("_")

def parse_upload(path: Path):
    m = UUID_RE.match(path.name)
    label = m.group(1) if m else path.stem
    label = re.sub(r"^\d+_", "", label)  # strip 01_
    return label, slugify(label)

uploads = []
for p in sorted(SRC.glob("c__Users_priya_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_*.png")):
    label, slug = parse_upload(p)
    if slug in RACING_SKIP:
        continue
    if any(x in slug for x in ("mercedes", "ferrari", "mclaren", "red_bull")):
        continue
    uploads.append((label, slug, p))

rows = json.loads(Path("tool/player_cards_dump.json").read_text(encoding="utf-8"))
cricket = [r for r in rows if r["sport"] == "cricket"]

# Build lookup from many name variants -> card
by_slug = {}
for r in cricket:
    variants = set()
    variants.add(slugify(r["name"]))
    # from id: cricket-rcb-virat-kohli -> virat_kohli
    id_tail = r["id"].split("-", 2)[-1] if r["id"].startswith("cricket-") else r["id"]
    variants.add(slugify(id_tail.replace("-", "_")))
    parts = r["name"].replace(".", " ").split()
    if len(parts) >= 2:
        variants.add(slugify(parts[-1]))  # last name only - careful
        variants.add(slugify("_".join(parts)))
        # KL Rahul style
        if all(len(p) <= 2 for p in parts[:-1]):
            variants.add(slugify("".join(p[0] for p in parts[:-1]) + "_" + parts[-1]))
            variants.add(slugify("_".join(p[0] for p in parts[:-1]) + "_" + parts[-1]))
    for v in variants:
        by_slug.setdefault(v, []).append(r)

# Prefer unique full-name matches; avoid last-name-only collisions for matching
full_name_slugs = {slugify(r["name"]): r for r in cricket}
id_slugs = {}
for r in cricket:
    id_tail = r["id"].split("-", 2)[-1] if r["id"].startswith("cricket-") else r["id"]
    id_slugs[slugify(id_tail.replace("-", "_"))] = r

matched_new = []
matched_existing = []
unmatched = []
used_card_ids = set()

for label, slug, path in uploads:
    card = full_name_slugs.get(slug) or id_slugs.get(slug)
    if card is None:
        # try fuzzy: remove middle names / initials
        # e.g. varun_chakaravarthy vs varun_chakravarthy
        candidates = []
        for r in cricket:
            ns = slugify(r["name"])
            if ns == slug or ns.replace("chakar", "chakrav") == slug.replace("chakar", "chakrav"):
                candidates.append(r)
            elif slug.endswith("_" + ns.split("_")[-1]) and ns.split("_")[-1] == slug.split("_")[-1]:
                # same last name and first token overlap
                if ns.split("_")[0] == slug.split("_")[0]:
                    candidates.append(r)
        card = candidates[0] if len(candidates) == 1 else None
    if card is None:
        unmatched.append((label, slug))
        continue
    if card["id"] in used_card_ids:
        unmatched.append((label, slug + " (dup card)"))
        continue
    used_card_ids.add(card["id"])
    entry = {
        "label": label,
        "slug": slugify(card["name"]) if False else slugify(
            card["id"].split("-", 2)[-1].replace("-", "_") if card["id"].startswith("cricket-") else card["name"]
        ),
        "asset_stem": slugify(card["id"].split("-", 2)[-1].replace("-", "_")) if card["id"].startswith("cricket-") else slugify(card["name"]),
        "card_id": card["id"],
        "card_name": card["name"],
        "had_portrait": card["hasPortrait"],
        "src": str(path),
        "existing_asset": card.get("portraitAsset"),
    }
    # Prefer existing naming convention from id
    id_tail = card["id"].split("-", 2)[-1] if card["id"].startswith("cricket-") else slugify(card["name"])
    entry["asset_stem"] = slugify(id_tail.replace("-", "_"))

    if card["hasPortrait"]:
        matched_existing.append(entry)
    else:
        matched_new.append(entry)

print(f"uploads cricket-ish: {len(uploads)}")
print(f"new fills: {len(matched_new)}")
print(f"already had: {len(matched_existing)}")
print(f"unmatched: {len(unmatched)}")
for u in unmatched:
    print("  UNMATCH", u[0], "->", u[1])

# Cards still missing
missing = [r for r in cricket if not r["hasPortrait"] and r["id"] not in {m["card_id"] for m in matched_new}]
print(f"still missing portraits: {len(missing)}")
for r in missing:
    print("  MISS", r["name"], r["id"])

Path("tool/cricket_portrait_plan.json").write_text(
    json.dumps({"new": matched_new, "existing": matched_existing, "unmatched": unmatched, "still_missing": missing}, indent=2, ensure_ascii=False),
    encoding="utf-8",
)
print("wrote tool/cricket_portrait_plan.json")