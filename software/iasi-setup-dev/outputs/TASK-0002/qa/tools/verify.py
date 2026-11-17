"""Task-local build, inventory, security, reproducibility and executable-JAR gate.

Python 3.10+, Windows Maven launcher, JDK 25. No full Maven debug dump is retained.
"""
import argparse
import csv
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import urllib.request
import uuid
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT.parents[1]
ECOSYSTEM = PROJECT.parents[1]
JAR = ROOT / "artifacts/iasi-setup-dev-0.1.0.jar"
NS = {"m": "http://maven.apache.org/POM/4.0.0"}
REALM = re.compile(r"Populating class realm plugin>([\w.\-]+):([\w.\-]+):([\w.\-]+)")
INCLUDED = re.compile(r"Included: ([\w.\-]+):([\w.\-]+):(jar|maven-plugin):([\w.\-]+)")
COORDINATE = re.compile(r"([\w.\-]+):([\w.\-]+):(?:jar|maven-plugin):([\w.\-]+)")


def write(path, text):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8", newline="\n")


def write_json(path, data):
    write(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def snapshot(directory):
    return {str(p.relative_to(directory)): sha(p) for p in directory.rglob("*") if p.is_file()}


def maven(goals, debug, log_name):
    switches = ["-B", "-ntp"] + (["-X"] if debug else [])
    command = [os.environ.get("COMSPEC", "cmd.exe"), "/d", "/c", "mvn", *switches, *goals]
    child = subprocess.Popen(command, cwd=PROJECT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             text=True, encoding="utf-8", errors="replace")
    realms, log = [], []
    for line in child.stdout:
        found = REALM.search(line)
        if found:
            group, artifact, version = found.groups()
            realms.append(f"   {group}:{artifact}:maven-plugin:{version}")
        found = INCLUDED.search(line)
        if found:
            realms.append("      " + ":".join(found.groups()))
        if "provider classpath:" in line:
            realms.append("   org.apache.maven.plugins:maven-surefire-plugin:maven-plugin:3.5.0")
            for relative in re.findall(r"[\\/]repository[\\/]([^;\r\n]+?\.jar)", line):
                parts = re.split(r"[\\/]", relative.strip())
                if len(parts) >= 4:
                    group, artifact, version = ".".join(parts[:-3]), parts[-3], parts[-2]
                    if re.fullmatch(r"[\w.\-]+", group + artifact + version):
                        realms.append(f"      {group}:{artifact}:jar:{version}")
        if not debug or re.match(r"^\[(INFO|WARNING|ERROR)]", line) or line.startswith("IASI SourceGate"):
            log.append(line.rstrip())
    result = child.wait()
    write(log_name, "\n".join(log) + "\n")
    if result:
        raise RuntimeError(f"Maven failed: {result}; see {log_name}")
    return realms


def inventory(realms):
    pom = ET.parse(PROJECT / "pom.xml")
    active = {p.findtext("m:groupId", namespaces=NS) + ":" + p.findtext("m:artifactId", namespaces=NS)
              for p in pom.findall("m:build/m:plugins/m:plugin", NS)}
    items = {}

    def add(match, context):
        group, artifact, version = match.groups()
        items.setdefault((group + ":" + artifact, version), set()).add(context)

    for line in (ROOT / "qa/dependency-tree.txt").read_text(encoding="utf-8").splitlines()[1:]:
        found = COORDINATE.search(line)
        if found:
            add(found, "test" if line.endswith(":test") else "runtime")
    owner = None
    for line in realms:
        found = COORDINATE.search(line)
        if not found:
            continue
        if len(line) - len(line.lstrip()) == 3:
            owner = found.group(1) + ":" + found.group(2)
        if owner in active:
            add(found, "plugin:" + owner)
    return [{"package": name, "version": version, "contexts": sorted(contexts)}
            for (name, version), contexts in sorted(items.items())]


def security_gate(packages, initialize):
    baseline = ROOT / "qa/config/dependency-baseline.json"
    if baseline.exists():
        assert not initialize, "Initial baseline already exists; do not overwrite it automatically"
        assert json.loads(baseline.read_text(encoding="utf-8")) == packages, "Effective inventory changed"
    elif not initialize:
        raise RuntimeError("Missing candidate baseline; review and record the initial selection explicitly")
    queries = [{"package": {"ecosystem": "Maven", "name": p["package"]}, "version": p["version"]} for p in packages]
    results = []
    for start in range(0, len(queries), 100):
        request = urllib.request.Request("https://api.osv.dev/v1/querybatch",
                                         data=json.dumps({"queries": queries[start:start + 100]}).encode(),
                                         headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(request, timeout=40) as response:
            results.extend(json.load(response)["results"])
    findings = [{"package": package, "advisories": result.get("vulns", [])}
                for package, result in zip(packages, results, strict=True) if result.get("vulns")]
    evidence = {"checked_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                "source": "https://api.osv.dev/v1/querybatch", "packages": packages, "results": results, "findings": findings}
    write_json("qa/security/osv-results.json", evidence)
    assert not findings, "OSV returned findings; review qa/security/osv-results.json"
    if initialize:
        write_json("qa/config/dependency-baseline.json", packages)
    return evidence


def process_case(directory, arguments, expected, jar=JAR):
    directory.mkdir(parents=True, exist_ok=False)
    result = subprocess.run(["java", "-Duser.language=es", "-Duser.country=ES", "-jar", str(jar), *arguments],
                            cwd=directory, capture_output=True, text=True, encoding="utf-8", errors="strict")
    assert result.returncode == expected, (arguments, result.returncode, result.stderr)
    return {"arguments": arguments, "exit_code": result.returncode, "stdout": result.stdout, "stderr": result.stderr,
            "cwd": str(directory.relative_to(ROOT)), "jar": str(jar.relative_to(ROOT))}


def smoke_tests():
    base = ROOT / "qa/smoke" / str(uuid.uuid4())
    cases = []
    commands = [(["help"], 0), (["workflow", "help"], 0), (["create", "-h"], 0),
                (["workflow", "release", "-h"], 0),
                (["platform", "-h", "--config", "missing.toml", "--logs", "unused"], 0),
                (["--help"], 16), (["help", "workflow"], 16), (["platform"], 0),
                (["platform", "-v", "-s", "-V"], 0), (["platform", "-V", "-s"], 0),
                (["platform", "-vsVf", "--machines", "unused-machines"], 0),
                (["create"], 16), (["workflow", "release"], 16)]
    for index, (arguments, expected) in enumerate(commands):
        directory = base / str(index)
        case = process_case(directory, arguments, expected)
        logs = list(directory.glob("*.log"))
        if index < 7:
            assert not list(directory.iterdir()), "Help/invalid CLI caused side effects"
        else:
            assert len(logs) == 1
            contents = logs[0].read_text(encoding="utf-8")
            assert "\x1b" not in contents and "DEBUG" in contents
            assert ("SUCCESS" in contents) == (expected == 0)
        if index == 9:
            assert not case["stdout"] and not case["stderr"]
        if index in [8, 10]:
            assert "SYS01004" in case["stdout"], "Last verbosity was not VERY_VERBOSE"
        if index == 10:
            assert "force=true" in case["stdout"]
        if index == 0:
            assert "PARÁMETROS" in case["stdout"]
        assert not (directory / "unused-machines").exists()
        cases.append(case)
    # The actual machine-specific external defaults are loaded without packaging them.
    config = ROOT / "qa/inputs/defaults.toml"
    case = process_case(base / "external", ["platform", "--config", str(config), "--logs", "audit", "-V", "-s"], 0)
    external_cwd = ROOT / case["cwd"]
    assert not case["stdout"] and len(list((external_cwd / "audit").glob("*.log"))) == 1
    cases.append(case)
    # A scratch JAR variant exercises the optional internal layer without changing the candidate.
    variant = ROOT / "build/internal-layer-test.jar"
    shutil.copyfile(JAR, variant)
    with zipfile.ZipFile(variant, "a") as archive:
        archive.writestr("org/iasi/setupdev/defaults.toml", "definitions='internal-definitions'\nverbose=true\nlogs='internal-logs'\n")
    case = process_case(base / "internal", ["platform"], 0, variant)
    assert "internal-definitions" in case["stdout"] and "force=false" in case["stdout"]
    cases.append(case)
    case = process_case(base / "layered", ["platform", "--config", str(config), "--logs", "explicit", "-s", "-V"], 0, variant)
    assert "internal-definitions" not in case["stdout"] and "explicit" in case["stdout"]
    assert "SYS01004" in case["stdout"] and "force=false" in case["stdout"]
    cases.append(case)
    write_json("qa/smoke-results.json", cases)
    return len(cases)



def return_code_tests():
    base = ROOT / "qa/rc-processes" / str(uuid.uuid4())
    harness = ROOT / "build/rc-process-harness.jar"
    entry = "org/iasi/setupdev/ReturnCodeProcessMain.class"
    with zipfile.ZipFile(JAR) as source, zipfile.ZipFile(harness, "w") as target:
        for item in source.infolist():
            data = source.read(item.filename)
            if item.filename == "META-INF/MANIFEST.MF":
                data = data.replace(b"Main-Class: org.iasi.setupdev.Main", b"Main-Class: org.iasi.setupdev.ReturnCodeProcessMain")
            target.writestr(item, data)
        target.write(ROOT / "build/target/test-classes" / entry, entry)
    scenarios = [("OK", 0), ("NOTHING_TO_DO", 1), ("INFO", 2), ("WARNING", 4), ("ATTENTION", 8),
                 ("ERROR", 16), ("SEVERE", 32), ("FATAL", 64), ("INFO+WARNING", 6),
                 ("WARNING+ATTENTION", 12), ("ERROR+WARNING", 20), ("INFO+ERROR", 18),
                 ("INFO+INFO", 2), ("NOTHING_TO_DO+INFO+WARNING+ATTENTION+ERROR+SEVERE+FATAL", 127)]
    cases = []
    for index, (scenario, expected) in enumerate(scenarios):
        case = process_case(base / str(index), [scenario, "platform"], expected, harness)
        directory = ROOT / case["cwd"]
        logs = list(directory.glob("*.log"))
        assert len(logs) == 1
        content = logs[0].read_text(encoding="utf-8")
        assert "exit code=" + str(expected) in content
        assert ("SUCCESS" in content) == (expected < 16 and "NOTHING_TO_DO" not in scenario)
        case["is_error"] = expected > 15
        cases.append(case)
    # Explicit failure of configuration in the real candidate uses the standard Error bit.
    missing = process_case(base / "missing-config", ["platform", "--config", "missing.toml"], 16)
    assert "SYS01009" in missing["stderr"]
    cases.append(missing)
    write_json("qa/rc-process-results.json", cases)
    return len(cases)


def artifact_checks():
    with zipfile.ZipFile(JAR) as archive:
        names = archive.namelist()
        assert int.from_bytes(archive.read("org/iasi/setupdev/Main.class")[6:8], "big") == 69
        assert "Main-Class: org.iasi.setupdev.Main" in archive.read("META-INF/MANIFEST.MF").decode()
        assert not any(name.endswith("defaults.toml") or name.startswith("org/junit/") or name.endswith(".java") for name in names)
        assert "org/iasi/setupdev/ReturnCodeProcessMain.class" not in names
        assert "META-INF/licenses/ANTLR-LICENSE.txt" in names
        assert "META-INF/licenses/CHECKER-QUAL-LICENSE.txt" in names
    assert all(p.suffix == ".jar" for p in (ROOT / "artifacts").iterdir())
    assert not (PROJECT / "target").exists() and not (ECOSYSTEM / "target").exists()
    assert not (PROJECT / "iasi/outputs").exists() and not (ROOT / "target").exists()


def source_bytes():
    paths = list((PROJECT / "src").rglob("*")) + list((ROOT / "qa/tools").glob("*"))
    paths += list((ROOT / "qa/config").glob("*")) + list(ROOT.glob("*.md")) + [PROJECT / "pom.xml"]
    for path in paths:
        if not path.is_file():
            continue
        text = path.read_bytes().decode("utf-8", errors="strict")
        assert not text.startswith("\ufeff") and "\r" not in text and text.endswith("\n"), str(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--record-baseline", action="store_true")
    args = parser.parse_args()
    governance = snapshot(PROJECT / "iasi")
    task1 = snapshot(PROJECT / "outputs/TASK-0001")
    releases = [snapshot(PROJECT / "release"), snapshot(ECOSYSTEM / "release")]
    realms = maven(["clean", "verify"], True, "qa/logs/build.log")
    realms += maven(["org.apache.maven.plugins:maven-dependency-plugin:3.8.1:tree", "-DoutputFile=outputs/TASK-0002/qa/dependency-tree.txt"],
                    True, "qa/logs/dependencies.log")
    write("qa/plugin-realms.txt", "\n".join(realms) + "\n")
    packages = inventory(realms)
    security = security_gate(packages, args.record_baseline)
    first = sha(JAR)
    maven(["clean", "verify"], False, "qa/logs/reproducibility.log")
    assert first == sha(JAR), "Clean builds differ"
    smoke = smoke_tests()
    rc_cases = return_code_tests()
    artifact_checks()
    source_bytes()
    assert governance == snapshot(PROJECT / "iasi"), "Governance changed"
    assert task1 == snapshot(PROJECT / "outputs/TASK-0001"), "TASK-0001 changed"
    write_json("qa/task-0001-preserved.json", task1)
    assert releases == [snapshot(PROJECT / "release"), snapshot(ECOSYSTEM / "release")], "Release changed"
    suites = [ET.parse(p).getroot() for p in (ROOT / "qa/test-results").glob("TEST-*.xml")]
    counts = {key: sum(int(s.attrib[key]) for s in suites) for key in ["tests", "failures", "errors", "skipped"]}
    metrics = list(csv.DictReader((ROOT / "qa/metrics.csv").open(encoding="utf-8")))
    maxima = {key: max(int(row[key]) for row in metrics) for key in ["effectiveLines", "nesting", "cyclomatic", "cognitive"]}
    evidence = {"status": "pass", "candidate_sha256": first, "tests": counts, "smoke_cases": smoke, "rc_process_cases": rc_cases,
                "maxima": maxima, "scored_callables": len(metrics), "effective_packages": len(packages),
                "osv_findings": len(security["findings"]), "reproducible": True,
                "governance_unchanged": True, "task_0001_unchanged": True, "release_unchanged": True, "output_isolation": True, "utf8_lf": True}
    write_json("qa/result.json", evidence)
    write("qa/candidate.sha256", first + "  artifacts/iasi-setup-dev-0.1.0.jar\n")
    print(json.dumps(evidence))


if __name__ == "__main__":
    main()
