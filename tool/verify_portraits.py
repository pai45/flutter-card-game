from pathlib import Path
import re
text = Path("lib/models/cards.dart").read_text(encoding="utf-8")
cricket_ids = re.findall(r"id: '(cricket-[^']+)'", text)
portraits = re.findall(r"portraitAsset: 'assets/cricketer_images/([^']+)'", text)
files = list(Path("assets/cricketer_images").glob("*"))
print("cricket cards", len(cricket_ids))
print("portraitAsset refs", len(portraits))
print("files on disk", len(files))
# check each new portrait file exists
missing_files = [p for p in portraits if not (Path("assets/cricketer_images") / p).exists()]
print("missing files", len(missing_files), missing_files[:5])