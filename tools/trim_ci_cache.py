#!/usr/bin/env python3
"""Keep verified Godot archives; discard extracted export templates after CI export.

The next export can unpack its checksum-verified archive again. Caching both
copies consumes runner space while actions/cache creates its temporary archive.
"""
import os
from pathlib import Path
import shutil
from bootstrap import ROOT


def trim_templates(cache_root: Path):
    cache_root = cache_root.resolve()
    removed = []
    for path in cache_root.glob("*/*/editor_data/export_templates"):
        if path.is_symlink() or not path.resolve().is_relative_to(cache_root):
            continue
        shutil.rmtree(path)
        removed.append(path)
    return removed


if __name__ == "__main__":
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise SystemExit("This cleanup is for disposable GitHub Actions checkouts.")
    for path in trim_templates(ROOT / ".tools"):
        print("Removed extracted templates:", path)
