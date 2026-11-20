"""Verify the same structural candidate filter for all configured search roots."""

import hashlib
import json
import locale
import os
from pathlib import Path
import subprocess
import tempfile


PROJECT = Path(__file__).resolve().parents[4]
OUTPUT = PROJECT / "outputs/TASK-00.01.06"
JAR = PROJECT / "outputs/iasi-setup-dev.jar"
RUN = Path(tempfile.mkdtemp(prefix="discovery-", dir=OUTPUT / "build"))
RESULTS = []


def populate(root):
    (root / "machine-a/config-data").mkdir(parents=True)
    (root / "machine-b/config-data").mkdir(parents=True)
    (root / "machine-b/config-data/machine.toml").write_text("invalid = [", encoding="utf-8")
    (root / "unrelated/docs").mkdir(parents=True)
    (root / "marker-file").mkdir()
    (root / "marker-file/config-data").write_text("not a directory", encoding="utf-8")
    (root / "nested/docs/config-data").mkdir(parents=True)
    (root / "config-data").mkdir()
    (root / "notes.txt").write_text("not a machine", encoding="utf-8")


def snapshot(root):
    return {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
            if path.is_file() else "directory" for path in root.rglob("*")}


def check(name, mode, targets=(), empty=False, rc=0, expected=("machine-a", "machine-b")):
    cwd = RUN / name
    cwd.mkdir()
    root = cwd / ("definitions" if mode == "default" else f"{mode}-definitions")
    root.mkdir(exist_ok=True)
    if empty:
        (root / "unrelated").mkdir()
        (root / "notes.txt").write_text("not a machine", encoding="utf-8")
    else:
        populate(root)
    args = ["--machines", str(cwd / "test-machines")]
    environment = dict(os.environ)
    if mode == "cli":
        args += ["--definitions", str(root)]
    elif mode == "toml":
        (cwd / "settings.toml").write_text(f'definitions = "{root.as_posix()}"\n', encoding="utf-8")
        args += ["--config", "settings.toml"]
    elif mode == "environment":
        environment["IASI_DISCOVERY_DEFINITIONS"] = str(root)
        args += ["--env", "IASI_DISCOVERY"]
    args += list(targets)
    (cwd / "test-machines").mkdir()
    (cwd / "logs").mkdir()
    before = snapshot(cwd)
    process = subprocess.run(["java", "-jar", str(JAR), *args], cwd=cwd, env=environment,
                             capture_output=True, text=True, encoding=locale.getencoding(), timeout=30)
    assert process.returncode == rc, (name, process.returncode, process.stderr)
    line = next(line for line in process.stdout.splitlines() if line.strip().startswith("resolvedTargets ="))
    selection = line.partition("=")[2].strip()[1:-1]
    names = [Path(value.strip()).name for value in selection.split(",") if value.strip()]
    assert names == list(expected), (name, names)
    assert snapshot(cwd) == before, f"{name}: filesystem modified"
    if rc == 0:
        assert not process.stderr, (name, process.stderr)
    RESULTS.append(dict(name=name, args=args, rc=process.returncode, selected=names,
                        filesystem_unchanged=True, stdout=process.stdout, stderr=process.stderr))


for mode in ("default", "cli", "toml", "environment"):
    check(f"root-{mode}", mode)
check("empty-default", "default", empty=True, expected=())
check("empty-explicit", "cli", empty=True, expected=())
check("regex-selection", "cli", targets=("machine-.*", "machine-a"))
check("unqualified-target-warning", "cli", targets=("unrelated",), rc=4, expected=())

(OUTPUT / "qa/machine-discovery-checks.json").write_text(json.dumps(RESULTS, indent=2, ensure_ascii=False), encoding="utf-8")
print(f"{len(RESULTS)}/{len(RESULTS)} machine-discovery process checks passed")
