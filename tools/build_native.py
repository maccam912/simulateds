#!/usr/bin/env python3
"""Build Rust + Iroh for this host, universal macOS, or Android ARM64."""
import argparse
import os
from pathlib import Path
import platform as host_platform
import shutil
import subprocess
import sys
from bootstrap import ROOT, VERSIONS

HOST = {"darwin": "macos", "linux": "linux", "win32": "windows"}[sys.platform]
SOURCE = ROOT / "native/iroh"
BIN = ROOT / "native/bin"
TARGETS = {"macos": ["aarch64-apple-darwin", "x86_64-apple-darwin"],
           "linux": ["x86_64-unknown-linux-gnu"], "windows": ["x86_64-pc-windows-msvc"],
           "android": ["aarch64-linux-android"]}
NAMES = {"macos": "libtemplate_iroh.macos.universal.dylib", "linux": "libtemplate_iroh.linux.x86_64.so",
         "windows": "template_iroh.windows.x86_64.dll", "android": "libtemplate_iroh.android.arm64.so"}


def build(platform, universal=True, debug=False):
    if platform not in (HOST, "android"):
        raise RuntimeError("Build desktop libraries on their native OS")
    environment = dict(os.environ)
    environment["MACOSX_DEPLOYMENT_TARGET"] = "13.0"
    if platform == "android":
        if not environment.get("ANDROID_HOME"):
            raise RuntimeError("Set ANDROID_HOME to your Android SDK directory")
        ndk = Path(environment["ANDROID_HOME"]) / "ndk" / VERSIONS["android"]["ndk"]
        tag = {"darwin": "darwin-x86_64", "linux": "linux-x86_64", "win32": "windows-x86_64"}[sys.platform]
        tool = ndk / "toolchains/llvm/prebuilt" / tag / "bin"
        linker = tool / ("aarch64-linux-android%d-clang" % VERSIONS["android"]["min_sdk"] + (".cmd" if os.name == "nt" else ""))
        if not linker.exists():
            raise RuntimeError("Install NDK " + VERSIONS["android"]["ndk"] + ": missing " + str(linker))
        environment.update(CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER=str(linker), CC_aarch64_linux_android=str(linker),
                           AR_aarch64_linux_android=str(tool / ("llvm-ar.exe" if os.name == "nt" else "llvm-ar")))
    targets = TARGETS[platform]
    if platform == "macos" and not universal:
        targets = ["aarch64-apple-darwin" if host_platform.machine() == "arm64" else "x86_64-apple-darwin"]
    outputs = []
    profile = "debug" if debug else "release"
    for target in targets:
        subprocess.run(["rustup", "target", "add", target], cwd=ROOT, check=True)
        command = ["cargo", "build", "--locked", "--manifest-path", str(SOURCE / "Cargo.toml"), "--target", target, "-j", "4"]
        if not debug:
            command.append("--release")
        subprocess.run(command, cwd=ROOT, env=environment, check=True)
        filename = "template_iroh.dll" if platform == "windows" else "libtemplate_iroh." + ("dylib" if platform == "macos" else "so")
        outputs.append(SOURCE / "target" / target / profile / filename)
    BIN.mkdir(parents=True, exist_ok=True)
    output = BIN / NAMES[platform]
    if len(outputs) == 2:
        subprocess.run(["lipo", "-create", *map(str, outputs), "-output", str(output)], check=True)
    else:
        shutil.copyfile(outputs[0], output)
    if platform == "macos":
        subprocess.run(["codesign", "--force", "--sign", "-", str(output)], check=True)
    # Import only after a host library exists; fresh projects still open offline.
    if (BIN / NAMES[HOST]).exists():
        shutil.copyfile(ROOT / "addons/iroh/iroh.gdextension.in", ROOT / "addons/iroh/iroh.gdextension")
    print(output)
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("platform", choices=["host", *TARGETS], default="host", nargs="?")
    parser.add_argument("--host-only", action="store_true", help="macOS development: compile only this CPU architecture")
    parser.add_argument("--debug", action="store_true")
    args = parser.parse_args()
    build(HOST if args.platform == "host" else args.platform, not args.host_only, args.debug)
