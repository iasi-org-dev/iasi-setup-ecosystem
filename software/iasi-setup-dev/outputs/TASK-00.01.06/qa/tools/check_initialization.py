"""Pruebas de ejecución del esqueleto; cada caso usa su propio CWD."""

import json
import locale
import os
from pathlib import Path
import subprocess
import tempfile


PROJECT = Path(__file__).resolve().parents[4]
OUTPUT = PROJECT / "outputs/TASK-00.01.06"
JAR = PROJECT / "outputs/iasi-setup-dev.jar"
FIXTURES = OUTPUT / "build/initialization-checks"
FIXTURES.mkdir(parents=True, exist_ok=True)
RUN = Path(tempfile.mkdtemp(prefix="run-", dir=FIXTURES))
RESULTS = []


def check(name, prepare, rc=0, expected=None, env=None, selected=None, help_output=False, language=None, diagnostic=None):
    cwd = RUN / name
    cwd.mkdir()
    args = prepare(cwd)
    if "--machines" not in args:
        args = ["--machines", str(cwd / "test-machines"), *args]
    environment = dict(os.environ)
    environment.update(env or {})
    process = subprocess.run(
        ["java", *([f"-Duser.language={language}"] if language else []), "-jar", str(JAR), *args], cwd=cwd, env=environment,
        capture_output=True, text=True, encoding=locale.getencoding(), timeout=30,
    )
    summary = {}
    for line in process.stdout.splitlines():
        key, separator, value = line.strip().partition("=")
        if separator:
            summary[key.strip()] = value.strip()
    failures = []
    if process.returncode != rc:
        failures.append(f"RC esperado {rc}, recibido {process.returncode}")
    for key, value in (expected or {}).items():
        if summary.get(key) != value:
            failures.append(f"{key}: esperado {value!r}, recibido {summary.get(key)!r}")
    if name == "defaults" and rc == 0:
        for key in ("definitions", "logs"):
            if summary.get(key) != str(cwd / key):
                failures.append(f"No se aplicó el default interno de {key}")
    if rc == 16 and "Context:" in process.stdout:
        failures.append("Un error de inicialización mostró un contexto válido")
    if diagnostic and diagnostic not in process.stderr:
        failures.append(f"Diagnóstico esperado: {diagnostic}")
    if help_output:
        if "--config" not in process.stdout or "--definitions" not in process.stdout or "-a" not in process.stdout:
            failures.append("La ayuda no contiene los argumentos actuales")
        if "Context:" in process.stdout:
            failures.append("La ayuda continuó con el resumen operativo")
        if process.stderr:
            failures.append("La ayuda produjo diagnósticos de error")
        if (cwd / "should-not-exist").exists():
            failures.append("La ayuda preparó un directorio operativo")
    if selected is not None:
        resolved = summary.get("resolvedTargets", "")
        for target in selected:
            if target not in resolved:
                failures.append(f"Target no seleccionado: {target}")
    RESULTS.append(dict(name=name, args=args, cwd=str(cwd), rc=process.returncode,
                        stdout=process.stdout, stderr=process.stderr, failures=failures))


def configuration(cwd):
    (cwd / "settings.toml").write_text('env="IASI_TEST"\nlogs="from-config"\nverbose=1\n', encoding="utf-8")
    return ["--config", "settings.toml", "--logs", "from-cli", "-V"]


def targets(cwd):
    for name in ("iasi-dev-api", "iasi-dev-ui", "otra-maquina"):
        (cwd / "defs" / name / "config-data").mkdir(parents=True)
    return ["--definitions", "defs", "iasi-dev-.*", "inexistente"]


def malformed(cwd):
    (cwd / "settings.toml").write_text("logs=[", encoding="utf-8")
    return ["--config", "settings.toml"]


check("defaults", lambda cwd: [], expected={"verbose": "1", "force": "false", "autostart": "false", "targets": "[]"})
check("flags", lambda cwd: ["-af", "-v", "-s", "-V"], expected={"verbose": "3", "force": "true", "autostart": "true"})
check("last-silent", lambda cwd: ["-Vs"], expected={"verbose": "0"})
check("precedence", configuration, expected={"verbose": "3"}, env={"IASI_TEST_VERBOSE": "incorrecto", "IASI_TEST_LOGS": "from-env"})
check("environment", lambda cwd: ["--env", "IASI_TEST"], expected={"verbose": "2"}, env={"IASI_TEST_VERBOSE": "2", "IASI_TEST_LOGS": "from-env"})
check("targets", targets, rc=4, expected={"targets": "[iasi-dev-.*, inexistente]"}, selected=["iasi-dev-api", "iasi-dev-ui"])
check("two-configs", lambda cwd: ["--config", "one.toml,two.toml"], rc=16)
check("missing-config", lambda cwd: ["--config", "missing.toml"], rc=16, language="es",
      diagnostic="No existe el fichero o directorio especificado por --config.")
check("config-is-directory", lambda cwd: ["--config", "."], rc=16, language="es",
      diagnostic="La ruta especificada por --config no es un fichero.")
check("malformed-toml", malformed, rc=16)
check("unknown-flag", lambda cwd: ["-z"], rc=16)
check("missing-value", lambda cwd: ["--logs", "-v"], rc=16)
check("invalid-environment", lambda cwd: ["--env", "IASI_TEST"], rc=16, env={"IASI_TEST_VERBOSE": "incorrecto"})
check("quoted-comma", lambda cwd: ["--logs", '"logs,folder"'])
check("help", lambda cwd: ["-h"], help_output=True)
check("grouped-help", lambda cwd: ["-sh"], help_output=True)
check("help-skips-configuration", lambda cwd: ["-h", "--config", "missing.toml", "--logs", "should-not-exist"], help_output=True)

report = OUTPUT / "qa/initialization-checks.json"
report.write_text(json.dumps(RESULTS, ensure_ascii=False, indent=2), encoding="utf-8")
failed = [result for result in RESULTS if result["failures"]]
for result in failed:
    print(result["name"], result["failures"], result["stderr"])
print(f"{len(RESULTS) - len(failed)}/{len(RESULTS)} comprobaciones correctas")
raise SystemExit(bool(failed))
