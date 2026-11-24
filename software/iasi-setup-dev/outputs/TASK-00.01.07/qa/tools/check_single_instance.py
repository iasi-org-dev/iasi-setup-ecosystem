"""Exercise production NIO locking from renamed JARs using a test-only holding entry point."""

import json
import locale
import os
from pathlib import Path
import queue
import re
import subprocess
import tempfile
import threading
import zipfile


PROJECT = Path(__file__).resolve().parents[4]
OUTPUT = PROJECT / "outputs/TASK-00.01.07"
PRODUCTION_JAR = PROJECT / "outputs/iasi-setup-dev.jar"
RUN = Path(tempfile.mkdtemp(prefix="single-instance-", dir=OUTPUT / "build"))
PROBE_CLASS = "org/iasi/common/process/LockProbe.class"
RESULTS = []


def runtime_java():
    settings = subprocess.run(["java", "-XshowSettings:properties", "-version"], capture_output=True,
                              text=True, encoding=locale.getencoding(), timeout=10)
    home = re.search(r"(?m)^\s*java.home = (.+)$", settings.stderr)
    assert home is not None, "Cannot locate the owning JVM executable"
    return Path(home.group(1).strip()) / "bin" / ("java.exe" if os.name == "nt" else "java")


JAVA = runtime_java()


def test_jar(name):
    destination = RUN / name
    with zipfile.ZipFile(PRODUCTION_JAR) as source, zipfile.ZipFile(destination, "w") as target:
        for entry in source.infolist():
            if entry.filename.upper() != "META-INF/MANIFEST.MF":
                target.writestr(entry, source.read(entry.filename))
        target.writestr("META-INF/MANIFEST.MF", "Manifest-Version: 1.0\r\nMain-Class: org.iasi.common.process.LockProbe\r\n\r\n")
        target.writestr(PROBE_CLASS, (OUTPUT / "build/target/test-classes" / PROBE_CLASS).read_bytes())
    return destination


FIRST = test_jar("setup.jar")
SECOND = test_jar("setup2.jar")
NAMESPACE = RUN / "temporary"
NAMESPACE.mkdir()
LOCK = NAMESPACE / "iasi.lock"
LOCK.write_text("persistent file; never delete", encoding="utf-8")
original_identity = LOCK.stat().st_ino
resources = NAMESPACE / "iasi"
resources.mkdir()
sentinel = resources / "active-resources.txt"
sentinel.write_text("must survive rejection", encoding="utf-8")


def start(jar, mode, marker, namespace=NAMESPACE):
    return subprocess.Popen([str(JAVA), f"-Djava.io.tmpdir={namespace}", "-jar", str(jar), mode, "iasi", str(marker)],
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, encoding=locale.getencoding())


def await_owner(process):
    ready = queue.Queue()
    threading.Thread(target=lambda: ready.put(process.stdout.readline()), daemon=True).start()
    assert ready.get(timeout=10).strip() == "LOCKED"


def attempt(name, jar, expected_rc, expected_output, namespace=NAMESPACE):
    marker = namespace / name
    process = start(jar, "try", marker, namespace)
    try:
        stdout, stderr = process.communicate(timeout=10)
        assert process.returncode == expected_rc, (name, process.returncode, stdout, stderr)
        assert stdout.strip() == expected_output, (name, stdout, stderr)
        assert marker.exists() == (expected_rc == 0), name
        RESULTS.append(dict(name=name, jar=jar.name, rc=process.returncode, stdout=stdout, stderr=stderr))
    finally:
        if process.poll() is None:
            process.kill()
        process.wait(timeout=10)


owner = start(FIRST, "hold", NAMESPACE / "owner-work")
try:
    await_owner(owner)
    attempt("same-jar-rejected", FIRST, 16, "BUSY")
    attempt("renamed-jar-rejected", SECOND, 16, "BUSY")
    assert owner.poll() is None
    assert sentinel.read_text(encoding="utf-8") == "must survive rejection"
    owner.communicate(input="\n", timeout=10)
    assert owner.returncode == 0
finally:
    if owner.poll() is None:
        owner.kill()
    owner.wait(timeout=10)
assert LOCK.exists()
attempt("after-controlled-release", SECOND, 0, "LOCKED")

owner = start(SECOND, "hold", NAMESPACE / "crash-owner-work")
try:
    await_owner(owner)
    owner.kill()
    owner.wait(timeout=10)
    attempt("after-force-kill", FIRST, 0, "LOCKED")
finally:
    if owner.poll() is None:
        owner.kill()
    owner.wait(timeout=10)

bad_namespace = RUN / "unusable-lock"
(bad_namespace / "iasi.lock").mkdir(parents=True)
attempt("io-error-prevents-work", SECOND, 16, "IO_ERROR", bad_namespace)
assert LOCK.read_text(encoding="utf-8") == "persistent file; never delete"
assert LOCK.stat().st_ino == original_identity
assert sentinel.read_text(encoding="utf-8") == "must survive rejection"
(OUTPUT / "qa/single-instance-checks.json").write_text(json.dumps(dict(
    harness="Test-only holding entry point; unchanged production SingleInstanceLock bytecode from the delivered JAR",
    lock=str(LOCK), persistent_file_preserved=True, cases=RESULTS), indent=2, ensure_ascii=False), encoding="utf-8")
print(f"{len(RESULTS)}/{len(RESULTS)} single-instance checks passed, including renamed JAR and force-kill recovery")
