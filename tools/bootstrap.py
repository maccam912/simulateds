#!/usr/bin/env python3
"""Project-local Godot installation, verified against pinned upstream SHA-512."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
(ROOT / "build").mkdir(exist_ok=True)
(ROOT / "build/.gdignore").touch()
VERSIONS = json.loads((ROOT / "tools/versions.json").read_text())
CACHE = ROOT / ".tools" / VERSIONS["godot"]
EDITOR = CACHE / sys.platform
DATA = EDITOR / "editor_data"
TEMPLATES = DATA / "export_templates" / VERSIONS["godot"].replace("-", ".")


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha512").hexdigest()


def download(key):
    asset = VERSIONS["assets"][key]
    path = CACHE / asset["file"]
    CACHE.mkdir(parents=True, exist_ok=True)
    if not path.exists() or digest(path) != asset["sha512"]:
        print("Downloading " + asset["file"], flush=True)
        temporary = path.with_suffix(".part")
        url = "https://github.com/godotengine/godot-builds/releases/download/" + VERSIONS["godot"] + "/" + asset["file"]
        with urllib.request.urlopen(url, timeout=120) as source, temporary.open("wb") as target:
            shutil.copyfileobj(source, target)
        if digest(temporary) != asset["sha512"]:
            temporary.unlink()
            raise RuntimeError("Godot checksum mismatch")
        temporary.replace(path)
    return path


def engine():
    filename = {"darwin": "Godot.app/Contents/MacOS/Godot",
                "linux": "Godot_v" + VERSIONS["godot"] + "_linux.x86_64",
                "win32": "Godot_v" + VERSIONS["godot"] + "_win64.exe"}[sys.platform]
    binary = EDITOR / filename
    if not binary.exists():
        with zipfile.ZipFile(download(sys.platform)) as archive:
            archive.extractall(EDITOR)
        if os.name != "nt":
            binary.chmod(binary.stat().st_mode | stat.S_IXUSR)
    # Alongside the .app on macOS; alongside the binary on Linux/Windows.
    (EDITOR / "_sc_").touch()
    return binary


def templates():
    engine()
    marker = TEMPLATES / ".template-sha512"
    checksum = VERSIONS["assets"]["templates"]["sha512"]
    if marker.exists() and marker.read_text() == checksum:
        return TEMPLATES
    with zipfile.ZipFile(download("templates")) as archive:
        for item in archive.infolist():
            relative = Path(item.filename).relative_to("templates")
            if item.is_dir() or not relative.parts:
                continue
            target = TEMPLATES / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.read(item))
            if not target.suffix:
                target.chmod(0o755)
    marker.write_text(checksum)
    return TEMPLATES


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--templates", action="store_true")
    args = parser.parse_args()
    binary = engine()
    if args.templates:
        templates()
    print(binary)
