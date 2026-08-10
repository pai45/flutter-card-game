import json, re, shutil
from pathlib import Path

plan = json.loads(Path("tool/cricket_portrait_plan.json").read_text(encoding="utf-8"))
new = plan["new"]
DEST = Path("assets/cricketer_images")
DEST.mkdir(parents=True, exist_ok=True)

# Try pillow for webp to match existing convention
try:
    from PIL import Image
    USE_WEBP = True
except ImportError:
    USE_WEBP = False
print("webp convert:", USE_WEBP)

copied = []
for m in new:
    src = Path(m["src"])
    stem = m["asset_stem"]
    if USE_WEBP:
        dest = DEST / f"{stem}.webp"
        img = Image.open(src).convert("RGBA")
        img.save(dest, "WEBP", quality=90, method=6)
        asset = f"assets/cricketer_images/{stem}.webp"
    else:
        dest = DEST / f"{stem}.png"
        shutil.copy2(src, dest)
        asset = f"assets/cricketer_images/{stem}.png"
    m["dest"] = str(dest)
    m["portraitAsset"] = asset
    copied.append(m)
    print("copied", m["card_name"], "->", dest.name)

# Patch cards.dart
cards_path = Path("lib/models/cards.dart")
text = cards_path.read_text(encoding="utf-8")

added = 0
skipped = 0
for m in copied:
    cid = m["card_id"]
    asset = m["portraitAsset"]
    # Find PlayerCard starting at this id
    needle = f"id: '{cid}',"
    idx = text.find(needle)
    if idx < 0:
        print("MISSING ID IN CARDS", cid)
        continue
    # Find end of this PlayerCard — next "  )," after icon line, before next PlayerCard
    # Limit search window
    window_end = text.find("PlayerCard(", idx + 1)
    if window_end < 0:
        window_end = idx + 800
    block = text[idx:window_end]
    if "portraitAsset:" in block:
        print("already has portraitAsset", cid)
        skipped += 1
        continue
    # Insert before closing of card: after icon line
    # Pattern inside block: icon: Icons.sports_cricket,\n  ),
    # But the ), might be after more fields - for these cards icon is last
    icon_pat = "icon: Icons.sports_cricket,"
    icon_pos = block.find(icon_pat)
    if icon_pos < 0:
        print("no icon line", cid)
        continue
    insert_at = idx + icon_pos + len(icon_pat)
    insertion = f"\n    portraitAsset: '{asset}',"
    text = text[:insert_at] + insertion + text[insert_at:]
    added += 1

cards_path.write_text(text, encoding="utf-8")
Path("tool/cricket_portrait_plan.json").write_text(
    json.dumps({"new": copied, "existing": plan["existing"], "unmatched": plan["unmatched"], "still_missing": plan["still_missing"]}, indent=2, ensure_ascii=False),
    encoding="utf-8",
)
print(f"DONE added={added} skipped={skipped} files={len(copied)}")