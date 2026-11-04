#!/usr/bin/env python3
"""Build/export a platform and package distributable files with checksums."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile
from bootstrap import ROOT, templates
from build_native import HOST, BIN, NAMES, build
from godot import run

PRESETS = {"linux": ("Linux", "simulateds.x86_64"), "windows": ("Windows", "simulateds.exe"),
           "macos": ("macOS", "simulateds.zip"), "android": ("Android", "simulateds.apk"),
           "server": ("Server", "simulateds-server.x86_64")}


def native_smoke(executable):
    # Export verification must never create or load the player's normal profile.
    with tempfile.TemporaryDirectory(prefix="simulateds-export-smoke-") as temporary:
        work = Path(temporary)
        result = subprocess.run([str(executable), "--headless", "--", "--native-smoke",
                                 f"--profile-path={work / 'profile.json'}",
                                 f"--save-path={work / 'world.json'}"],
                                capture_output=True, text=True, timeout=30)
        if result.returncode or "ERROR:" in result.stdout + result.stderr or "NATIVE_RUNTIME_PASS" not in result.stdout:
            raise RuntimeError(result.stdout + result.stderr)
        print("EXPORTED_NATIVE_RUNTIME_PASS", flush=True)


def export(platform, skip_build=False):
    native_platform = "linux" if platform == "server" else platform
    if native_platform not in (HOST, "android"):
        raise RuntimeError("Export on the native platform; Android can also export on desktop")
    templates()
    if not skip_build:
        build(HOST)
        if native_platform != HOST:
            build(native_platform)
    for required in {HOST, native_platform}:
        if not (BIN / NAMES[required]).exists():
            raise RuntimeError("Missing native library for " + required)
    if platform == "macos":
        architectures = subprocess.check_output(["lipo", "-archs", str(BIN / NAMES[HOST])], text=True).split()
        if not {"arm64", "x86_64"}.issubset(architectures):
            raise RuntimeError("macOS export needs both ARM64 and Intel; rebuild without --host-only")
    if platform == "android":
        from android import prepare
        _, _, key = prepare()
        os.environ["TEMPLATE_DEBUG_KEYSTORE"] = str(key)
    run(["--headless", "--editor", "--import"], timeout=180)
    preset, name = PRESETS[platform]
    destination = ROOT / "build" / platform
    destination.mkdir(parents=True, exist_ok=True)
    output = destination / name
    # Android is intentionally a development-signed APK; no store credentials needed.
    run(["--headless", "--export-debug" if platform == "android" else "--export-release", preset, str(output)], timeout=900)
    if not output.exists() or output.stat().st_size == 0:
        raise RuntimeError("Godot did not produce " + str(output))
    if platform == "android":
        with zipfile.ZipFile(output) as archive:
            if "lib/arm64-v8a/" + NAMES["android"] not in archive.namelist():
                raise RuntimeError("APK is missing Iroh ARM64 library")
            dex = [name for name in archive.namelist() if name.endswith(".dex")]
            if not any(b"Ldev/godotiroh/template/IrohAndroid;" in archive.read(name) for name in dex):
                raise RuntimeError("APK is missing the Android DNS bridge")
        sdk = Path(os.environ["ANDROID_HOME"])
        from bootstrap import VERSIONS
        signer = sdk / "build-tools" / VERSIONS["android"]["build_tools"] / ("apksigner.bat" if os.name == "nt" else "apksigner")
        subprocess.run([str(signer), "verify", "--verbose", str(output)], check=True)
    if platform == "macos":
        verification = ROOT / "build/macos-verify"
        if verification.exists():
            shutil.rmtree(verification)
        subprocess.run(["ditto", "-x", "-k", str(output), str(verification)], check=True)
        apps = list(verification.glob("*.app"))
        if len(apps) != 1:
            raise RuntimeError("Expected one macOS application")
        subprocess.run(["plutil", "-lint", str(apps[0] / "Contents/Info.plist")], check=True)
        subprocess.run(["codesign", "--verify", "--deep", "--strict", "--all-architectures", str(apps[0])], check=True)
        # Check the shipped app can load the native extension, not just the editor.
        executable = next((apps[0] / "Contents/MacOS").iterdir())
        native_smoke(executable)
    if platform in ("linux", "windows", "server"):
        output.chmod(output.stat().st_mode | 0o111)
        native_smoke(output)
    release = ROOT / "build/artifacts"
    release.mkdir(parents=True, exist_ok=True)
    artifact = release / ("simulateds-" + platform + (".apk" if platform == "android" else ".zip"))
    if platform in ("macos", "android"):
        shutil.copyfile(output, artifact)
    else:
        with zipfile.ZipFile(artifact, "w", zipfile.ZIP_DEFLATED) as archive:
            for path in destination.rglob("*"):
                if path.is_file():
                    archive.write(path, path.relative_to(destination))
    checksum = hashlib.sha256(artifact.read_bytes()).hexdigest()
    artifact.with_suffix(artifact.suffix + ".sha256").write_text(checksum + "  " + artifact.name + "\n")
    print(artifact)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("platform", choices=list(PRESETS))
    parser.add_argument("--skip-build", action="store_true", help="use libraries already built in this checkout")
    args = parser.parse_args()
    export(args.platform, args.skip_build)
