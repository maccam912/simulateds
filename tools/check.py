#!/usr/bin/env python3
"""Validate simulation/protocol and real host + two-client Iroh play/reconnect."""
import argparse
from contextlib import ExitStack
from pathlib import Path
import shutil
import subprocess
import time
from bootstrap import ROOT, engine


def run(binary, arguments, timeout=60):
    result = subprocess.run([str(binary), "--headless", "--path", str(ROOT), *arguments],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=timeout)
    print(result.stdout, end="", flush=True)
    if result.returncode or any(marker in result.stdout for marker in ("SCRIPT ERROR:", "ERROR:", "Parse Error:", "TEST FAIL")):
        raise RuntimeError("Godot failed; see output above")
    return result.stdout


def smoke(binary, relay_only=False, codes=False):
    work = ROOT / "build" / ("smoke-codes" if codes else "smoke-relay" if relay_only else "smoke")
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)
    ticket = work / "ticket.txt"
    processes = []
    with ExitStack() as stack:
        def start(role, index):
            path = work / (role + str(index) + ".log")
            stream = stack.enter_context(path.open("w"))
            command = [str(binary), "--headless", "--path", str(ROOT), "--log-file", str(work / f"{role}{index}-engine.log"),
                       "--script", "res://tests/smoke_peer.gd", "--", role, str(ticket), str(index),
                       f"--save-path={work / f'{role}{index}-world.json'}", f"--profile-path={work / f'{role}{index}-profile.json'}",
                       "--family-name=" + ("Host family" if role == "host" else f"Client {index}")]
            if relay_only:
                command.append("--relay-only")
            if codes:
                command.append("--codes")
            process = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT)
            processes.append((process, path, role.upper() + "_PASS"))
            return process
        try:
            host = start("host", 0)
            deadline = time.monotonic() + 30
            while not ticket.exists() and time.monotonic() < deadline and host.poll() is None:
                time.sleep(0.1)
            if not ticket.exists():
                raise RuntimeError("Host did not publish a ticket:\n" + processes[0][1].read_text())
            start("client", 1)
            start("client", 2)
            for process, path, marker in processes:
                process.wait(timeout=100)
                text = path.read_text()
                if process.returncode or marker not in text or "ERROR:" in text:
                    raise RuntimeError("\n".join(p.read_text() for _, p, _ in processes))
            print("IROH_CODE_SMOKE_PASS" if codes else "IROH_RELAY_SMOKE_PASS" if relay_only else "IROH_SMOKE_PASS")
        finally:
            for process, _, _ in processes:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
            ticket.unlink(missing_ok=True)


def server_smoke(binary):
    import json
    work = ROOT / "build" / "server-smoke"
    work.mkdir(parents=True, exist_ok=True)
    output = run(binary, ["--quit-after", "90", "--max-fps", "60", "--log-file", str(work / "engine.log"),
                          "--", "--server", f"--save-path={work / 'world.json'}", f"--profile-path={work / 'profile.json'}"])
    if "SIMULATEDS_SERVER_READY ticket=" not in output:
        raise RuntimeError("Dedicated server did not start")
    world = json.loads((work / "world.json").read_text())
    if len(world["families"]) != 1 or any(f["online"] for f in world["families"].values()):
        raise RuntimeError("Dedicated host household did not remain in caretaker mode")
    print("SERVER_SMOKE_PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", type=Path, help="Use an explicitly supplied Godot; default is the pinned project engine")
    parser.add_argument("--relay-only", action="store_true", help="require public Iroh relay connectivity")
    parser.add_argument("--codes", action="store_true", help="exercise configured live short-code service and revocation")
    parser.add_argument("--unit-only", action="store_true", help="run model/protocol checks without network peers")
    args = parser.parse_args()
    binary = args.engine or engine()
    run(binary, ["--editor", "--quit-after", "180", "--max-fps", "60"], timeout=180)
    work = ROOT / "build" / "checks"
    work.mkdir(parents=True, exist_ok=True)
    for script, marker in [("world", "WORLD_PASS"), ("build_history", "BUILD_HISTORY_PASS"), ("wishes", "WISHES_PASS"), ("integration_world", "INTEGRATION_WORLD_PASS"), ("protocol", "PROTOCOL_PASS"), ("persistence", "PERSISTENCE_PASS"), ("ui_flow", "UI_FLOW_PASS"), ("preferences", "PREFERENCES_PASS"), ("save_debug", "SAVE_DEBUG_PASS"), ("console", "CONSOLE_PASS"), ("app_flow", "APP_FLOW_PASS")]:
        if not (ROOT / "tests" / f"{script}.gd").is_file():
            raise RuntimeError(f"Required test script missing: tests/{script}.gd")
        output = run(binary, ["--script", f"res://tests/{script}.gd", "--log-file", str(work / f"{script}-engine.log"),
                              "--", f"--save-path={work / f'{script}-save.json'}", f"--profile-path={work / f'{script}-profile.json'}"])
        if marker not in output:
            raise RuntimeError(script + " assertions did not finish")
    if not args.unit_only:
        smoke(binary, args.relay_only, args.codes)
        server_smoke(binary)
