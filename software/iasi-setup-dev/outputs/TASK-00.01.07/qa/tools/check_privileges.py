"""Check the real privilege boundary without requesting or bypassing elevation."""

import ctypes
import json
import locale
import os
from pathlib import Path
import re
import subprocess
import tempfile


PROJECT = Path(__file__).resolve().parents[4]
OUTPUT = PROJECT / "outputs/TASK-00.01.07"
JAR = PROJECT / "outputs/iasi-setup-dev.jar"
CWD = Path(tempfile.mkdtemp(prefix="privileges-", dir=OUTPUT / "build"))
elevated = bool(ctypes.windll.shell32.IsUserAnAdmin()) if os.name == "nt" else os.geteuid() == 0
cases = [
    ("help", ["-h"]),
    ("before-configuration", ["-h", "--config", "missing.toml", "--logs", "new-logs"]),
]
if not elevated:
    cases += [("no-arguments", []), ("before-syntax", ["-"]), ("before-directories", ["--logs", "new-logs"])]
results = []
for name, args in cases:
    process = subprocess.run(["java", "-Duser.language=es", "-jar", str(JAR), *args], cwd=CWD,
                             capture_output=True, text=True, encoding=locale.getencoding(), timeout=30)
    if elevated:
        assert process.returncode == 0, (name, process.stderr)
        assert process.stdout.startswith("IASI Setup Dev "), (name, process.stdout)
        assert not process.stderr
    else:
        assert process.returncode == 16, (name, process.returncode, process.stderr)
        assert not process.stdout
        assert "La aplicación debe ejecutarse como administrador." in process.stderr
        assert re.match(r"\d{2}:\d{2}:\d{2} - ", process.stderr)
    assert not list(CWD.iterdir()), f"{name}: startup modified the filesystem"
    results.append(dict(name=name, args=args, rc=process.returncode, stdout=process.stdout, stderr=process.stderr))
unsupported = subprocess.run(["java", "-Duser.language=es", "-Dos.name=IASI_UNSUPPORTED", "-jar", str(JAR)],
                             cwd=CWD, capture_output=True, text=True, encoding=locale.getencoding(), timeout=30)
assert unsupported.returncode == 16, unsupported.stderr
assert not unsupported.stdout
assert "El sistema operativo no está soportado." in unsupported.stderr
assert "La aplicación debe ejecutarse como administrador." not in unsupported.stderr
assert not list(CWD.iterdir())
results.append(dict(name="unsupported-os-before-administrator", rc=unsupported.returncode,
                    stdout=unsupported.stdout, stderr=unsupported.stderr))
(OUTPUT / "qa/privilege-checks.json").write_text(json.dumps(dict(elevated=elevated, cases=results), ensure_ascii=False, indent=2), encoding="utf-8")
print(f"{len(results)}/{len(results)} privilege checks passed; elevated={elevated}")
