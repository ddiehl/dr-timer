"""Copies exported XCTest attachments into the output dir under their test names.

`xcresulttool export attachments` writes opaque file names plus a manifest that
carries the name each attachment was given in the test; this maps one to the
other so the output is 01-counting.png and friends.
"""
import json, pathlib, re, shutil, sys

src, dest = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
dest.mkdir(parents=True, exist_ok=True)
manifest = json.loads((src / "manifest.json").read_text())

count = 0
for entry in manifest:
    for att in entry.get("attachments", []):
        name = att.get("suggestedHumanReadableName") or att.get("exportedFileName")
        # XCTest appends "_<index>_<uuid>" to the name given in the test.
        name = re.sub(r"_\d+_[0-9A-Fa-f-]{36}", "", name or "")
        exported = src / att["exportedFileName"]
        if not exported.exists() or not name:
            continue
        if not name.lower().endswith(".png"):
            name += ".png"
        shutil.copy2(exported, dest / name)
        print(f"  {name}")
        count += 1
if not count:
    sys.exit("no attachments found in manifest")
