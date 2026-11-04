#!/usr/bin/env python3
"""Verify every mapped migration tree preserves file bytes through LFS pointers.

Run while pre-migration Git objects are still available (do not prune first).
The CSV is produced by git lfs migrate import --object-map=/outside/repo/map.csv.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import subprocess
from check_assets import binary

ROOT = Path(__file__).resolve().parents[1]
POINTER = re.compile(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n\Z")


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def tree(commit):
    entries = {}
    for entry in git("ls-tree", "-rz", commit).split(b"\0"):
        if entry:
            metadata, path = entry.split(b"\t", 1)
            mode, kind, oid = metadata.decode().split()
            entries[path] = (mode, kind, oid)
    return entries


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("object_map", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    with args.object_map.open(newline="") as stream:
        pairs = [row for row in csv.reader(stream) if len(row) == 2 and re.fullmatch(r"[0-9a-f]{40}", row[0])]
    if not pairs:
        raise SystemExit("No commit mappings found")
    mapping = dict(pairs)
    verified = set()
    verified_objects = set()
    blobs = {}
    lfs_dir = Path(git("rev-parse", "--git-path", "lfs/objects").decode().strip())
    if not lfs_dir.is_absolute():
        lfs_dir = ROOT / lfs_dir

    def blob(oid):
        if oid not in blobs:
            blobs[oid] = git("cat-file", "blob", oid)
        return blobs[oid]

    def verify_object(pointer):
        digest, size = pointer.group(1).decode(), int(pointer.group(2))
        if digest not in verified_objects:
            hydrated = lfs_dir / digest[:2] / digest[2:4] / digest
            if not hydrated.is_file():
                raise SystemExit(f"Missing local LFS object: {digest}")
            data = hydrated.read_bytes()
            if len(data) != size or hashlib.sha256(data).hexdigest() != digest:
                raise SystemExit(f"Corrupt local LFS object: {digest}")
            verified_objects.add(digest)
        return digest, size

    for before, after in pairs:
        old, new = tree(before), tree(after)
        old.pop(b".gitattributes", None)
        new.pop(b".gitattributes", None)
        if old.keys() != new.keys():
            raise SystemExit(f"Changed file list: {before} -> {after}")
        for path, (mode, kind, oid) in old.items():
            new_mode, new_kind, new_oid = new[path]
            if (mode, kind) != (new_mode, new_kind):
                raise SystemExit(f"Changed file type/mode: {path!r}")
            if kind != "blob":
                if oid != new_oid:
                    raise SystemExit(f"Changed non-blob entry: {path!r}")
                continue
            if oid == new_oid:
                data = blob(oid)
                pointer = POINTER.fullmatch(data)
                if pointer:
                    verify_object(pointer)
                elif binary(data):
                    raise SystemExit(f"Binary escaped LFS migration: {path!r}")
                continue
            if (oid, new_oid) in verified:
                continue
            source, pointer = blob(oid), POINTER.fullmatch(blob(new_oid))
            if not pointer:
                raise SystemExit(f"Changed non-LFS file: {path!r}")
            digest, size = verify_object(pointer)
            if len(source) != size or hashlib.sha256(source).hexdigest() != digest:
                raise SystemExit(f"Changed asset bytes: {path!r}")
            verified.add((oid, new_oid))
        old_commit = git("cat-file", "commit", before)
        new_commit = git("cat-file", "commit", after)
        def metadata(data, remap):
            headers, message = data.split(b"\n\n", 1)
            lines = []
            for line in headers.split(b"\n"):
                if line.startswith(b"tree "):
                    continue
                if line.startswith(b"parent ") and remap:
                    parent = line[7:].decode()
                    line = b"parent " + mapping.get(parent, parent).encode()
                lines.append(line)
            return b"\n".join(lines), message
        if metadata(old_commit, True) != metadata(new_commit, False):
            raise SystemExit(f"Changed commit metadata: {before}")
    report = {"commits_verified": len(pairs), "unique_binary_conversions_verified": len(verified),
              "lfs_objects_verified": len(verified_objects), "no_raw_binary_blobs": True,
              "non_attribute_file_contents_preserved": True, "commit_metadata_preserved": True}
    text = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.write_text(text)
    print(text, end="")


if __name__ == "__main__":
    main()
