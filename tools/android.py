"""Package the small Java/JNI context bridge, using the pinned Godot classes."""
import io
import json
import os
from pathlib import Path
import re
import subprocess
import zipfile
from bootstrap import ROOT, VERSIONS, templates, DATA


def prepare():
    sdk = Path(os.environ["ANDROID_HOME"])
    java = Path(os.environ["JAVA_HOME"])
    work = ROOT / "build/android-bridge"
    work.mkdir(parents=True, exist_ok=True)
    classes = work / "classes"
    classes.mkdir(exist_ok=True)
    for path in classes.rglob("*.class"):
        path.unlink()
    source_zip = templates() / "android_source.zip"
    with zipfile.ZipFile(source_zip) as archive:
        library = archive.read("libs/release/godot-lib.template_release.aar")
        archive.extractall(ROOT / "android/build")
    (ROOT / "android/.build_version").write_text(VERSIONS["godot"].replace("-", ".") + "\n")
    (ROOT / "android/.gdignore").touch()
    if os.name != "nt":
        (ROOT / "android/build/gradlew").chmod(0o755)
    with zipfile.ZipFile(io.BytesIO(library)) as archive:
        (work / "godot.jar").write_bytes(archive.read("classes.jar"))
    suffix = ".exe" if os.name == "nt" else ""
    subprocess.run([str(java / "bin" / ("javac" + suffix)), "--release", "17", "-classpath",
                    os.pathsep.join([str(sdk / "platforms" / ("android-" + VERSIONS["android"]["sdk"]) / "android.jar"), str(work / "godot.jar")]),
                    "-d", str(classes), str(ROOT / "native/android/IrohAndroid.java")], check=True)
    jar = io.BytesIO()
    with zipfile.ZipFile(jar, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in classes.rglob("*.class"):
            archive.write(path, path.relative_to(classes))
    output = ROOT / "addons/iroh_android/bin/iroh-android.aar"
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("classes.jar", jar.getvalue())
        archive.write(ROOT / "native/android/AndroidManifest.xml", "AndroidManifest.xml")
        archive.writestr("R.txt", "")
    # All settings and signing material stay inside this project's ignored .tools.
    key = DATA / "debug.keystore"
    if not key.exists():
        subprocess.run([str(java / "bin" / ("keytool" + suffix)), "-genkeypair", "-keystore", str(key),
                        "-storepass", "android", "-keypass", "android", "-alias", "androiddebugkey",
                        "-dname", "CN=Godot Iroh Development", "-keyalg", "RSA", "-keysize", "2048", "-validity", "10000"], check=True)
    # This editor is self-contained, so these preferences belong only to this
    # checkout. Configure them while it is stopped, before import/export.
    version = ".".join(VERSIONS["godot"].split(".")[:2])
    settings = DATA / ("editor_settings-" + version + ".tres")
    text = settings.read_text() if settings.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    values = {"export/android/android_sdk_path": str(sdk), "export/android/java_sdk_path": str(java),
              "export/android/debug_keystore": str(key), "export/android/debug_keystore_user": "androiddebugkey",
              "export/android/debug_keystore_pass": "android"}
    for name, value in values.items():
        text = re.sub(r"^" + re.escape(name) + r"=.*\n?", "", text, flags=re.MULTILINE)
        text = text.rstrip() + "\n" + name + "=" + json.dumps(value) + "\n"
    settings.write_text(text)
    return sdk, java, key
