# Building and releasing

## Local development

Install Git LFS and hydrate assets with `git lfs install` and `git lfs pull`
before setup/import. After the 3D history migration, use a fresh clone; see
[LFS.md](LFS.md). Validate model sources with `python3 tools/check_models.py`.

`python3 tools/setup.py` installs the pinned engine and builds for the current CPU.
Use `python3 tools/godot.py --editor` so you get that engine rather than a different
Godot already on PATH. `python3 tools/godot.py` runs the game.

For Rust edits, close game/editor processes before rebuilding (especially Windows,
which locks loaded DLLs). Run `python3 tools/build_native.py --host-only` to rebuild
for development. Full macOS exports need both architectures; the export script
builds them automatically. `--debug` is available for unoptimized Rust debugging.

All Cargo builds use the committed lockfile. Editor/export binaries are verified
against the SHA-512 hashes committed in `tools/versions.json`. `.tools`, Rust's
`target`, exported games, and signing keys are ignored by Git. Do not commit them.

## Desktop exports

Run on the target operating system:

```sh
python3 tools/export.py linux
python3 tools/export.py windows
python3 tools/export.py macos
python3 tools/export.py server    # Linux host
```

`--skip-build` uses native libraries already built in this checkout. It does not
check whether those libraries match changed source; use it only immediately after
building them. macOS export rejects a one-architecture library.

The script downloads matching templates, imports the project, exports, starts the
exported executable to verify native hosting, and packages output/checksums in
`build/artifacts`. macOS additionally verifies its plist and every code-signing
architecture. The ad hoc signature is for development; external distribution
requires your Developer ID certificate and notarization. Windows executables are
unsigned. Do not describe either as a store-ready signed release.

## Android

Install JDK 17 and the Android command-line tools/Android Studio SDK. Set:

```sh
export JAVA_HOME=/path/to/jdk-17
export ANDROID_HOME=/path/to/Android/sdk
sdkmanager 'platform-tools' 'platforms;android-36' 'build-tools;35.0.1' 'ndk;28.1.13356709'
python3 tools/export.py android
```

On this Mac, typical existing paths are `/opt/homebrew/opt/openjdk@17` and
`$HOME/Library/Android/sdk`. On Windows, use environment settings or PowerShell
`$env:JAVA_HOME` / `$env:ANDROID_HOME`; the Python tools also support Windows paths.

The build compiles both a host extension (needed by the editor during export) and
Android ARM64 extension. It extracts Godot's matching Gradle template, builds the
small `IrohAndroid` Java plugin, and installs an application context through JNI
before Iroh starts. Removing this plugin can leave a compiling app with broken DNS.
The APK verifier checks the native library, Java bridge bytecode, and signature.

Install on a connected device with:

```sh
adb install -r build/artifacts/simulateds-android.apk
```

The app uses a project-local debug keystore under `.tools/.../editor_data/`.
CI caches that directory as a convenience, but caches are evictable: it is **not a
stable release identity**. If a fresh CI key differs, uninstall the previous development build
before installing. For store distribution, configure a separate release keystore,
use Godot's release export/signing settings and AAB export, and keep credentials in
GitHub secrets or local ignored credential files. Never ship the debug key as your
production signing identity.

Hosting is foreground-only. Backgrounding a mobile app closes its session and
attempts to revoke the code; rehost/rejoin on return. If the process is killed,
the service's expiry still bounds the code lifetime. Test real devices and network
changes for your game; a built APK does not prove device behavior.

## GitHub Actions

`.github/workflows/build.yml` runs for pushes, pull requests, and manual dispatch:

1. Native builds on Linux, Windows, macOS, plus Android cross-compilation on Linux.
2. Godot import, protocol checks, and one host plus two client processes on each runner.
3. Game exports, native-load checks for exported desktops, and Android package checks.
4. Game ZIP/APK artifacts, SHA-256 files, native libraries, and test logs.
5. A tag like `v0.1.0` creates a GitHub Release after all four matrix jobs pass.

The macOS job uses the standard `macos-15-intel` runner after repeated Apple
Silicon jobs expired without acquiring a runner. It still builds ARM64 and Intel
native libraries, combines them into the universal library, and verifies the
universal export and signatures. Hosted runtime checks execute the Intel slice;
native Apple Silicon playtests remain a separate check. Rust caches include the
runner architecture to keep host-built cache entries separate. Test artifacts
include local suite logs and all three Iroh scenarios.
See [GitHub's runner image labels](https://github.com/actions/runner-images#available-images).

The release job alone has `contents: write`. Build/PR jobs need no signing secrets
or access to private GitHub repositories. The default test exchanges full tickets
and does not call the owner's code service. Internet access is still needed for
dependency downloads, and Iroh may contact its configured discovery/relay services.

`relay-smoke.yml` is manual: it disables direct IP transport and requires relay
connectivity. It is separate so an external relay outage does not masquerade as a
source regression. Run the code-service test locally with `--codes`, or add it to
that manual workflow for your deployment; avoid hammering a shared service on PRs.

To release after publishing the repository:

```sh
git tag v0.1.0
git push origin v0.1.0
```

Increment the Android `version/code`, game version, and bundle metadata in
`export_presets.cfg` before subsequent installable releases. Tagging does not
automatically change those values. Downloads → Actions artifacts require a GitHub
login; Release assets follow your repository visibility.

## Updating tools

Change Godot's version and all four official download hashes in
`tools/versions.json` together. Match `project.godot`'s feature version and check
Godot's Android SDK/Gradle requirements. Change Iroh/gdext in Cargo.toml, regenerate
Cargo.lock, rebuild every platform, and rerun both direct and relay tests. Keep
the JNI bridge and Android context API in sync with Iroh. Regenerate dependency
notices with `python3 tools/licenses.py` after dependency updates.

Sources: [Godot Android export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html),
[godot-rust platform exports](https://godot-rust.github.io/book/toolchain/export-mac-and-ios.html).
