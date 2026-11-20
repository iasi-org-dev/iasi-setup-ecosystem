"""Comprueba el JAR y guarda la salida de ayuda sin modificar máquinas."""

import hashlib
import json
import locale
from pathlib import Path
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile


PROJECT = Path(__file__).resolve().parents[4]
OUTPUT = PROJECT / "outputs/TASK-00.01.06"
QA = OUTPUT / "qa"
VERSION = ET.parse(PROJECT / "pom.xml").getroot().find("{*}version").text
JAR = PROJECT / "outputs/iasi-setup-dev.jar"
CWD = Path(tempfile.mkdtemp(prefix="help-", dir=OUTPUT / "build"))
(CWD / "machines/existing").mkdir(parents=True)
(CWD / "machines/existing/keep.txt").write_text("unchanged", encoding="utf-8")


def snapshot():
    return {str(path.relative_to(CWD)): hashlib.sha256(path.read_bytes()).hexdigest()
            if path.is_file() else "directory" for path in CWD.rglob("*")}


before = snapshot()
results = []
for name, language, args, rc in (
    ("help-es", "es", ["-h"], 0),
    ("help-en", "en", ["-h"], 0),
    ("help-skips-operations", "es", ["-afh", "--config", "absent.toml", "--logs", "new-logs"], 0),
    ("unsupported-long-help", "es", ["--help"], 16),
):
    result = subprocess.run(["java", f"-Duser.language={language}", "-jar", str(JAR), *args],
                            cwd=CWD, capture_output=True, text=True, encoding=locale.getencoding(), timeout=30)
    (QA / f"{name}.stdout.txt").write_text(result.stdout, encoding="utf-8")
    (QA / f"{name}.stderr.txt").write_text(result.stderr, encoding="utf-8")
    assert result.returncode == rc, (name, result.stderr)
    assert snapshot() == before, f"{name}: modified filesystem"
    if rc == 0:
        assert not result.stderr, (name, result.stderr)
        assert result.stdout.startswith(f"IASI Setup Dev {VERSION}\n")
        assert "--help" not in result.stdout
        assert "\x1b" not in result.stdout
        assert "Context:" not in result.stdout
        assert not re.search(r"(?m)^(?:\d{2}:\d{2}:\d{2}|[A-Z]{3}\d{5}|(?:INFO|WARNING|ERROR|DEBUG|TRACE)\b| - )", result.stdout)
        if language == "es":
            for section in ("USO", "FLAGS", "PARÁMETROS", "TARGETS", "VALORES POR DEFECTO", "CONFIGURACIÓN"):
                assert f"\n\n{section}\n" in result.stdout
    else:
        assert not result.stdout
        assert re.match(r"\d{2}:\d{2}:\d{2} - ", result.stderr)
    results.append(dict(name=name, args=args, rc=result.returncode, filesystem_unchanged=True))

with zipfile.ZipFile(JAR) as artifact:
    assert f"version={VERSION}" in artifact.read("org/iasi/setupdev/version.properties").decode("utf-8")
    assert artifact.read("org/iasi/setupdev/defaults.toml") == (PROJECT.parents[1] / "definitions/defaults.toml").read_bytes()
(QA / "help-checks.json").write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
print(f"{len(results)}/{len(results)} comprobaciones de ayuda correctas; versión {VERSION}")
