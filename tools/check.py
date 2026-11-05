#!/usr/bin/env python3
"""Validate simulation/protocol and real host + two-client Iroh play/reconnect."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from contextlib import ExitStack
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
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
    print(f"Running multiplayer scenario: {script}", flush=True)
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
            print("BUILD_OVERHAUL_IROH_PASS" if script == "build_overhaul_peer" else "CREATOR_IROH_PASS" if script == "creator_peer" else "PANTRY_IROH_PASS" if script == "pantry_peer" else "COMMISSIONS_IROH_PASS" if script == "commissions_peer" else "RECREATION_IROH_PASS" if script == "recreation_peer" else "MEALS_IROH_PASS" if script == "meals_peer" else "PAINTINGS_IROH_PASS" if script == "paintings_peer" else "IROH_CODE_SMOKE_PASS" if codes else "IROH_RELAY_SMOKE_PASS" if relay_only else "IROH_SMOKE_PASS", flush=True)
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


def test_shard(value):
    try:
        index, count = map(int, value.split("/"))
    except ValueError:
        raise argparse.ArgumentTypeError("expected INDEX/COUNT with 1 <= INDEX <= COUNT") from None
    if not 1 <= index <= count:
        raise argparse.ArgumentTypeError("expected INDEX/COUNT with 1 <= INDEX <= COUNT")
    return slice(index - 1, None, count)


def gameplay_checks(binary, shard):
    work = ROOT / "build" / "checks"
    work.mkdir(parents=True, exist_ok=True)
    tests = [("character_models", "CHARACTER_MODELS_PASS"), ("character_creator", "CHARACTER_CREATOR_PASS"), ("character_creator_ui", "CHARACTER_CREATOR_UI_PASS"), ("build_overhaul", "BUILD_OVERHAUL_PASS"), ("build_overhaul_ui", "BUILD_OVERHAUL_UI_PASS"), ("icons_ui", "ICONS_UI_PASS"), ("hud_discovery", "HUD_DISCOVERY_PASS"), ("context_input", "CONTEXT_INPUT_PASS"), ("context_actions", "CONTEXT_ACTIONS_PASS"), ("context_menu_ui", "CONTEXT_MENU_UI_PASS"), ("renderer_3d", "RENDERER_3D_PASS"), ("world", "WORLD_PASS"), ("build_history", "BUILD_HISTORY_PASS"), ("build_area_ui", "BUILD_AREA_UI_PASS"), ("rooms", "ROOMS_PASS"), ("room_copy", "ROOM_COPY_PASS"), ("room_copy_ui", "ROOM_COPY_UI_PASS"), ("room_library", "ROOM_LIBRARY_PASS"), ("room_library_ui", "ROOM_LIBRARY_UI_PASS"), ("clear_lot", "CLEAR_LOT_PASS"), ("clear_lot_ui", "CLEAR_LOT_UI_PASS"), ("construction_space", "CONSTRUCTION_SPACE_PASS"), ("construction_space_ui", "CONSTRUCTION_SPACE_UI_PASS"), ("build_access", "BUILD_ACCESS_PASS"), ("build_impact", "BUILD_IMPACT_PASS"), ("build_impact_ui", "BUILD_IMPACT_UI_PASS"), ("build_access_ui", "BUILD_ACCESS_UI_PASS"), ("household", "HOUSEHOLD_PASS"), ("household_travel", "HOUSEHOLD_TRAVEL_PASS"), ("household_travel_ui", "HOUSEHOLD_TRAVEL_UI_PASS"), ("neighborhood", "NEIGHBORHOOD_PASS"), ("neighborhood_ui", "NEIGHBORHOOD_UI_PASS"), ("pastimes", "PASTIMES_PASS"), ("friendships", "FRIENDSHIPS_PASS"), ("friendship_feedback", "FRIENDSHIP_FEEDBACK_PASS"), ("friendship_feedback_ui", "FRIENDSHIP_FEEDBACK_UI_PASS"), ("shared_friendships", "SHARED_FRIENDSHIPS_PASS"), ("shared_friendships_ui", "SHARED_FRIENDSHIPS_UI_PASS"), ("mailbox", "MAILBOX_PASS"), ("commission_feedback", "COMMISSION_FEEDBACK_PASS"), ("commission_feedback_ui", "COMMISSION_FEEDBACK_UI_PASS"), ("art_commissions", "ART_COMMISSIONS_PASS"), ("art_commissions_ui", "ART_COMMISSIONS_UI_PASS"), ("art_gifts", "ART_GIFTS_PASS"), ("art_gifts_ui", "ART_GIFTS_UI_PASS"), ("home_news", "HOME_NEWS_PASS"), ("home_news_ui", "HOME_NEWS_UI_PASS"), ("care", "CARE_PASS"), ("hobbies", "HOBBIES_PASS"), ("garden_overview", "GARDEN_OVERVIEW_PASS"), ("garden_overview_ui", "GARDEN_OVERVIEW_UI_PASS"), ("pantry", "PANTRY_PASS"), ("pantry_ui", "PANTRY_UI_PASS"), ("gardens", "GARDENS_PASS"), ("gardens_ui", "GARDENS_UI_PASS"), ("paintings", "PAINTINGS_PASS"), ("paintings_ui", "PAINTINGS_UI_PASS"), ("painting_hobby", "PAINTING_HOBBY_PASS"), ("painting_hobby_ui", "PAINTING_HOBBY_UI_PASS"), ("wall_art", "WALL_ART_PASS"), ("wall_art_ui", "WALL_ART_UI_PASS"), ("art_admiration", "ART_ADMIRATION_PASS"), ("art_admiration_ui", "ART_ADMIRATION_UI_PASS"), ("finishes", "FINISHES_PASS"), ("furniture_colors", "FURNITURE_COLORS_PASS"), ("furniture_colors_ui", "FURNITURE_COLORS_UI_PASS"), ("windows", "WINDOWS_PASS"), ("windows_ui", "WINDOWS_UI_PASS"), ("room_finishes", "ROOM_FINISHES_PASS"), ("room_finishes_ui", "ROOM_FINISHES_UI_PASS"), ("wishes", "WISHES_PASS"), ("presentation", "PRESENTATION_PASS"), ("resident_facing", "RESIDENT_FACING_PASS"), ("resident_facing_ui", "RESIDENT_FACING_UI_PASS"), ("walk_feedback", "WALK_FEEDBACK_PASS"), ("walk_feedback_ui", "WALK_FEEDBACK_UI_PASS"), ("activity_audio", "ACTIVITY_AUDIO_PASS"), ("activity_status", "ACTIVITY_STATUS_PASS"), ("resident_cues", "RESIDENT_CUES_PASS"), ("camera", "CAMERA_PASS"), ("plans", "PLANS_PASS"), ("activity_log", "ACTIVITY_LOG_PASS"), ("activity_log_ui", "ACTIVITY_LOG_UI_PASS"), ("routines", "ROUTINES_PASS"), ("routines_ui", "ROUTINES_UI_PASS"), ("routine_capture", "ROUTINE_CAPTURE_PASS"), ("routine_capture_ui", "ROUTINE_CAPTURE_UI_PASS"), ("meals", "MEALS_PASS"), ("meals_autonomy", "MEALS_AUTONOMY_PASS"), ("meal_choice", "MEAL_CHOICE_PASS"), ("meal_call", "MEAL_CALL_PASS"), ("meal_call_ui", "MEAL_CALL_UI_PASS"), ("meal_wishes", "MEAL_WISHES_PASS"), ("meal_wishes_ui", "MEAL_WISHES_UI_PASS"), ("meals_ui", "MEALS_UI_PASS"), ("company_time", "COMPANY_TIME_PASS"), ("company_time_ui", "COMPANY_TIME_UI_PASS"), ("recreation", "RECREATION_PASS"), ("recreation_ui", "RECREATION_UI_PASS"), ("tabletop", "TABLETOP_PASS"), ("tabletop_ui", "TABLETOP_UI_PASS"), ("dancing", "DANCING_PASS"), ("shared_spaces", "SHARED_SPACES_PASS"), ("shared_spaces_ui", "SHARED_SPACES_UI_PASS"), ("courtesy", "COURTESY_PASS"), ("courtesy_ui", "COURTESY_UI_PASS"), ("dancing_ui", "DANCING_UI_PASS"), ("join_game", "JOIN_GAME_PASS"), ("join_game_ui", "JOIN_GAME_UI_PASS"), ("plan_ui", "PLAN_UI_PASS"), ("integration_world", "INTEGRATION_WORLD_PASS"), ("protocol", "PROTOCOL_PASS"), ("persistence", "PERSISTENCE_PASS"), ("ui_flow", "UI_FLOW_PASS"), ("catalog_ui", "CATALOG_UI_PASS"), ("guide_ui", "GUIDE_UI_PASS"), ("preferences", "PREFERENCES_PASS"), ("accessibility_settings", "ACCESSIBILITY_SETTINGS_PASS"), ("play_clock", "PLAY_CLOCK_PASS"), ("play_clock_ui", "PLAY_CLOCK_UI_PASS"), ("save_debug", "SAVE_DEBUG_PASS"), ("console", "CONSOLE_PASS"), ("app_flow", "APP_FLOW_PASS")]
    for script, marker in tests[shard]:
        if not (ROOT / "tests" / f"{script}.gd").is_file():
            raise RuntimeError(f"Required test script missing: tests/{script}.gd")
        output = run(binary, ["--script", f"res://tests/{script}.gd", "--log-file", str(work / f"{script}-engine.log"),
                              "--", f"--save-path={work / f'{script}-save.json'}", f"--profile-path={work / f'{script}-profile.json'}",
                              f"--settings-path={work / f'{script}-settings.json'}"])
        if marker not in output:
            raise RuntimeError(script + " assertions did not finish")
        if script == "save_debug":
            save_continuity_checks(binary, work)


def save_continuity_checks(binary, work):
    # Use a fresh process with the same isolated profile and save to exercise
    # actual startup and orderly shutdown, not just a restore in memory.
    with tempfile.TemporaryDirectory(prefix="continuity-", dir=work) as directory:
        paths = [f"--{kind}-path={Path(directory) / (kind + '.json')}"
                 for kind in ("save", "profile", "settings")]
        for phase in ("write", "read"):
            output = run(binary, ["--script", "res://tests/save_continuity.gd",
                                  "--log-file", str(work / f"continuity-{phase}-engine.log"),
                                  "--", "--skip-splash", f"--continuity-{phase}", *paths])
            if f"SAVE_CONTINUITY_{phase.upper()}_PASS" not in output:
                raise RuntimeError(f"Save continuity {phase} assertions did not finish")


def network_checks(binary, args):
    scenarios = ["smoke_peer", "creator_peer", "build_overhaul_peer", "paintings_peer", "meals_peer", "recreation_peer", "commissions_peer", "pantry_peer"]
    for script in scenarios[args.shard]:
        smoke(binary, args.relay_only, args.codes, script=script)
    if args.shard.start in (None, 0):
        server_smoke(binary)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", type=Path, help="Use an explicitly supplied Godot; default is the pinned project engine")
    parser.add_argument("--relay-only", action="store_true", help="require public Iroh relay connectivity")
    parser.add_argument("--codes", action="store_true", help="exercise configured live short-code service and revocation")
    parser.add_argument("--unit-only", action="store_true", help="run model/protocol checks without network peers")
    parser.add_argument("--shard", type=test_shard, default=slice(None),
                        metavar="INDEX/COUNT", help="run one numbered share of the tests across parallel CI jobs")
    args = parser.parse_args()
    subprocess.run([sys.executable, str(ROOT / "tools" / "check_models.py")], check=True)
    binary = args.engine or engine()
    run(binary, ["--editor", "--quit-after", "180", "--max-fps", "60"], timeout=180)
    if args.unit_only or args.shard.step is None:
        gameplay_checks(binary, args.shard)
        if not args.unit_only:
            network_checks(binary, args)
    else:
        # Gameplay scripts and multiplayer scenarios use separate test profiles and saves.
        with ThreadPoolExecutor(max_workers=2) as executor:
            peers = executor.submit(network_checks, binary, args)
            gameplay_checks(binary, args.shard)
            peers.result()
