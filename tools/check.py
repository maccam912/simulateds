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
    try:
        result = subprocess.run([str(binary), "--headless", "--path", str(ROOT), *arguments],
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        output = error.stdout or ""
        print(output.decode(errors="replace") if isinstance(output, bytes) else output, end="", flush=True)
        raise RuntimeError("Godot test timed out; see its assertion output above") from error
    print(result.stdout, end="", flush=True)
    if result.returncode or any(marker in result.stdout for marker in ("SCRIPT ERROR:", "ERROR:", "Parse Error:", "TEST FAIL")):
        raise RuntimeError("Godot failed; see output above")
    return result.stdout


def smoke(binary, relay_only=False, codes=False, script="smoke_peer"):
    work = ROOT / "build" / ("smoke-codes" if codes else "smoke-relay" if relay_only else "smoke")
    if script != "smoke_peer":
        work = ROOT / "build" / script
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
                       "--script", f"res://tests/{script}.gd", "--", role, str(ticket), str(index),
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
            deadline = time.monotonic() + 100
            while any(process.poll() is None for process, _, _ in processes):
                logs = [path.read_text() for _, path, _ in processes]
                if any("ERROR:" in text for text in logs) or any(process.poll() not in (None, 0) for process, _, _ in processes):
                    raise RuntimeError("\n".join(logs))
                if time.monotonic() >= deadline:
                    raise RuntimeError("Peer test timed out:\n" + "\n".join(logs))
                time.sleep(0.1)
            for process, path, marker in processes:
                text = path.read_text()
                if process.returncode or marker not in text or "ERROR:" in text:
                    raise RuntimeError("\n".join(p.read_text() for _, p, _ in processes))
            print("PAINTINGS_IROH_PASS" if script == "paintings_peer" else "IROH_CODE_SMOKE_PASS" if codes else "IROH_RELAY_SMOKE_PASS" if relay_only else "IROH_SMOKE_PASS")
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
    for script, marker in [("world", "WORLD_PASS"), ("build_history", "BUILD_HISTORY_PASS"), ("rooms", "ROOMS_PASS"), ("room_copy", "ROOM_COPY_PASS"), ("room_copy_ui", "ROOM_COPY_UI_PASS"), ("build_access", "BUILD_ACCESS_PASS"), ("build_impact", "BUILD_IMPACT_PASS"), ("build_impact_ui", "BUILD_IMPACT_UI_PASS"), ("build_access_ui", "BUILD_ACCESS_UI_PASS"), ("household", "HOUSEHOLD_PASS"), ("pastimes", "PASTIMES_PASS"), ("friendships", "FRIENDSHIPS_PASS"), ("shared_friendships", "SHARED_FRIENDSHIPS_PASS"), ("shared_friendships_ui", "SHARED_FRIENDSHIPS_UI_PASS"), ("mailbox", "MAILBOX_PASS"), ("home_news", "HOME_NEWS_PASS"), ("home_news_ui", "HOME_NEWS_UI_PASS"), ("care", "CARE_PASS"), ("hobbies", "HOBBIES_PASS"), ("gardens", "GARDENS_PASS"), ("gardens_ui", "GARDENS_UI_PASS"), ("paintings", "PAINTINGS_PASS"), ("paintings_ui", "PAINTINGS_UI_PASS"), ("wall_art", "WALL_ART_PASS"), ("wall_art_ui", "WALL_ART_UI_PASS"), ("finishes", "FINISHES_PASS"), ("furniture_colors", "FURNITURE_COLORS_PASS"), ("furniture_colors_ui", "FURNITURE_COLORS_UI_PASS"), ("windows", "WINDOWS_PASS"), ("windows_ui", "WINDOWS_UI_PASS"), ("room_finishes", "ROOM_FINISHES_PASS"), ("room_finishes_ui", "ROOM_FINISHES_UI_PASS"), ("wishes", "WISHES_PASS"), ("presentation", "PRESENTATION_PASS"), ("resident_facing", "RESIDENT_FACING_PASS"), ("resident_facing_ui", "RESIDENT_FACING_UI_PASS"), ("walk_feedback", "WALK_FEEDBACK_PASS"), ("walk_feedback_ui", "WALK_FEEDBACK_UI_PASS"), ("activity_audio", "ACTIVITY_AUDIO_PASS"), ("activity_status", "ACTIVITY_STATUS_PASS"), ("resident_cues", "RESIDENT_CUES_PASS"), ("camera", "CAMERA_PASS"), ("plans", "PLANS_PASS"), ("activity_log", "ACTIVITY_LOG_PASS"), ("activity_log_ui", "ACTIVITY_LOG_UI_PASS"), ("routines", "ROUTINES_PASS"), ("routines_ui", "ROUTINES_UI_PASS"), ("routine_capture", "ROUTINE_CAPTURE_PASS"), ("routine_capture_ui", "ROUTINE_CAPTURE_UI_PASS"), ("tabletop", "TABLETOP_PASS"), ("tabletop_ui", "TABLETOP_UI_PASS"), ("dancing", "DANCING_PASS"), ("shared_spaces", "SHARED_SPACES_PASS"), ("shared_spaces_ui", "SHARED_SPACES_UI_PASS"), ("courtesy", "COURTESY_PASS"), ("courtesy_ui", "COURTESY_UI_PASS"), ("dancing_ui", "DANCING_UI_PASS"), ("join_game", "JOIN_GAME_PASS"), ("join_game_ui", "JOIN_GAME_UI_PASS"), ("plan_ui", "PLAN_UI_PASS"), ("integration_world", "INTEGRATION_WORLD_PASS"), ("protocol", "PROTOCOL_PASS"), ("persistence", "PERSISTENCE_PASS"), ("ui_flow", "UI_FLOW_PASS"), ("catalog_ui", "CATALOG_UI_PASS"), ("guide_ui", "GUIDE_UI_PASS"), ("preferences", "PREFERENCES_PASS"), ("play_clock", "PLAY_CLOCK_PASS"), ("play_clock_ui", "PLAY_CLOCK_UI_PASS"), ("save_debug", "SAVE_DEBUG_PASS"), ("console", "CONSOLE_PASS"), ("app_flow", "APP_FLOW_PASS")]:
        if not (ROOT / "tests" / f"{script}.gd").is_file():
            raise RuntimeError(f"Required test script missing: tests/{script}.gd")
        output = run(binary, ["--script", f"res://tests/{script}.gd", "--log-file", str(work / f"{script}-engine.log"),
                              "--", f"--save-path={work / f'{script}-save.json'}", f"--profile-path={work / f'{script}-profile.json'}"])
        if marker not in output:
            raise RuntimeError(script + " assertions did not finish")
    if not args.unit_only:
        smoke(binary, args.relay_only, args.codes)
        smoke(binary, args.relay_only, args.codes, script="paintings_peer")
        server_smoke(binary)
