#!/usr/bin/env python3
"""Run the pinned Godot editor/game without replacing a system installation."""
import subprocess
import sys
from bootstrap import ROOT, engine


def run(arguments, timeout=None):
    # Let deferred extension registration finish before the editor shuts down.
    if "--import" in arguments:
        arguments = [arg for arg in arguments if arg not in ("--import", "--quit")]
        arguments += ["--quit-after", "180", "--max-fps", "60"]
    result = subprocess.run([str(engine()), "--path", str(ROOT), *arguments],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=timeout)
    print(result.stdout, end="", flush=True)
    if result.returncode or any(marker in result.stdout for marker in ("SCRIPT ERROR:", "ERROR:", "Parse Error:", "TEST FAIL")):
        raise RuntimeError("Godot failed; see output above")
    return result.stdout


if __name__ == "__main__":
    # Interactive use streams directly; checks/exports use run() for diagnostics.
    raise SystemExit(subprocess.call([str(engine()), "--path", str(ROOT), *sys.argv[1:]]))
