"""Separate-process explicit branch save/resume/replay, fixture content only."""
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

engine = sys.argv[1]
directory = Path(tempfile.mkdtemp(prefix="astral-evolution-replay-", dir=os.environ.get("TMPDIR")))
session = directory / "session"
checks = 0


def run(*args, target=session, code=0):
    global checks
    result = subprocess.run([engine, "--headless", "--path", ".", "--script",
                             "tests/evolution_driver.gd", "--", f"--session={target}", *args],
                            capture_output=True, text=True, timeout=120)
    assert result.returncode == code, (result.stdout, result.stderr)
    assert "SCRIPT ERROR" not in result.stderr, result.stderr
    checks += 1
    return [json.loads(line) for line in result.stdout.splitlines() if line.startswith("{")][-1]


view = run("--start=A1B2C3", "--ship=cartographer", "--unlocks=0")
uid = view["state"]["deck"][0]["uid"]
assert {c["branch"] for c in view["evolutions"][0]["choices"]} == {"impact", "flow"}
before = view["state"]
for extra in ({}, {"branch": "legacy"}, {"branch": "unknown"}, {"branch": ""}):
    response = run("--resume=true", "--command=" + json.dumps(
        {"op": "modify", "uid": uid, "expect": view["expect"], **extra}), code=1)
    view = response["view"]
    assert view["state"] == before
response = run("--resume=true", "--command=" + json.dumps(
    {"op": "modify", "uid": uid, "branch": "flow", "expect": view["expect"]}))
view = response["view"]
assert view["state"]["deck"][0]["evolution"] == "flow"
assert run("--resume=true")["state"] == view["state"]
verified = run(f"--replay={session / 'trace.json'}", target=directory / "verified")
assert verified["view"] == view and verified["verified_errors"] == 4
trace = json.loads((session / "trace.json").read_text())
assert trace["entries"][-1]["effective_card"]["draw"] == 1
assert trace["entries"][-1]["effective_card"]["damage"] == 10
assert trace["environment"]["sources"]["scripts/evolutions.gd"] == hashlib.sha256(Path("scripts/evolutions.gd").read_bytes()).hexdigest()
# Stale source fingerprint is rejected independently of the Git revision.
changed = copy.deepcopy(trace)
changed["environment"]["sources"]["scripts/evolutions.gd"] = "dirty-authoritative-module"
(session / "trace.json").write_text(json.dumps(changed))
assert not run("--resume=true", code=1)["ok"]
assert not run(f"--replay={session / 'trace.json'}", target=directory / "dirty", code=1)["ok"]
print(f"EVOLUTION_REPLAY {checks} process checks passed; artifacts: {directory}")
