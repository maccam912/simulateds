#!/usr/bin/env python3
"""Reject binary assets outside LFS and unhydrated LFS checkout files."""
import argparse
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
POINTER = re.compile(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n\Z")


def git(*args, **kwargs):
    return subprocess.check_output(["git", *args], cwd=ROOT, **kwargs)


def binary(data):
    if b"\0" in data:
        return True
    try:
        data.decode("utf-8")
        return False
    except UnicodeDecodeError:
        return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--worktree-only", action="store_true",
                        help="Check files/attributes before staging; otherwise verify index pointers too")
    args = parser.parse_args()
    tracked = set(git("ls-files", "-z").decode().rstrip("\0").split("\0"))
    new_assets = set(git("ls-files", "--others", "--exclude-standard", "-z", "--", "assets", "docs")
                     .decode().rstrip("\0").split("\0"))
    paths = sorted(path for path in tracked | new_assets if path and (ROOT / path).is_file())
    raw_attrs = git("check-attr", "--stdin", "-z", "filter", input="\0".join(paths).encode() + b"\0")
    fields = raw_attrs.decode().rstrip("\0").split("\0")
    attrs = {fields[i]: fields[i + 2] for i in range(0, len(fields), 3)}
    failures = []
    count = 0
    for path in paths:
        data = (ROOT / path).read_bytes()
        if POINTER.fullmatch(data):
            failures.append(f"{path}: LFS pointer in working tree; run git lfs pull")
            continue
        if attrs[path] == "lfs":
            count += 1
            if not args.worktree_only and path in tracked:
                staged = git("show", ":" + path)
                if not POINTER.fullmatch(staged):
                    failures.append(f"{path}: index stores raw data; git add --renormalize the file")
        elif binary(data):
            failures.append(f"{path}: binary asset lacks filter=lfs in .gitattributes")
    if failures:
        raise SystemExit("ASSET_STORAGE_FAIL\n" + "\n".join(failures))
    print(f"ASSET_STORAGE_PASS: {count} hydrated LFS assets; binary formats covered")


if __name__ == "__main__":
    main()
