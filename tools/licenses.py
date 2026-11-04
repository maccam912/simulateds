#!/usr/bin/env python3
"""Collect notices from the locked Cargo dependency sources, without local paths."""
import json
from pathlib import Path
import subprocess
from bootstrap import ROOT


if __name__ == "__main__":
    metadata = json.loads(subprocess.check_output([
        "cargo", "metadata", "--locked", "--format-version", "1",
        "--manifest-path", str(ROOT / "native/iroh/Cargo.toml")], cwd=ROOT))
    lines = ["Rust dependency notices (Cargo.lock)\n"]
    for package in sorted(metadata["packages"], key=lambda item: (item["name"], item["version"])):
        if package["name"] == "template_iroh":
            continue
        lines += ["\n" + "=" * 72, package["name"] + " " + package["version"],
                  "License: " + (package.get("license") or "see package notices"),
                  "Source: " + (package.get("repository") or "https://crates.io/crates/" + package["name"])]
        base = Path(package["manifest_path"]).parent
        files = set()
        if package.get("license_file"):
            files.add(base / package["license_file"])
        for pattern in ("LICENSE*", "LICENCE*", "COPYING*", "NOTICE*", "COPYRIGHT*", "license*", "licenses/*"):
            files.update(path for path in base.glob(pattern) if path.is_file())
        for path in sorted(files):
            lines += ["\n--- " + path.name + " ---", path.read_text(errors="replace")]
        if not files:
            lines.append("No standalone notice in the crate archive; consult the source URL and declared license.")
    output = ROOT / "licenses/rust-dependencies.txt"
    output.write_text("\n".join(lines) + "\n")
    print(output)
