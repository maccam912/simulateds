#!/usr/bin/env python3
"""One-command setup for development; exports build both Mac architectures."""
from bootstrap import engine
from build_native import HOST, build
from godot import run

if __name__ == "__main__":
    engine()
    build(HOST, universal=False)
    run(["--headless", "--editor", "--import"], timeout=180)
    print("Ready. Run: python3 tools/godot.py --editor")
