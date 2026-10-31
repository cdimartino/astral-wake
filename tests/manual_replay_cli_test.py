"""Exercise real JSON/process/save boundaries, without a gameplay policy."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


engine = sys.argv[1]
directory = Path(tempfile.mkdtemp(prefix="astral-manual-cli-", dir=os.environ.get("TMPDIR")))
session = directory / "session"
checks = 0


def run(*args, target=session, code=0):
    global checks
    result = subprocess.run(
        [engine, "--headless", "--path", ".", "--script", "tools/manual_replay.gd",
         "--", f"--session={target}", *args],
        capture_output=True, text=True, timeout=120,
    )
    assert result.returncode == code, (result.returncode, result.stdout, result.stderr)
    assert "SCRIPT ERROR" not in result.stderr, result.stderr
    rows = [json.loads(line) for line in result.stdout.splitlines() if line.startswith("{")]
    assert rows, result.stdout
    checks += 1
    return rows[-1]


def send(command, code=0):
    return run("--resume=true", "--command=" + json.dumps(command), code=code)


def trace():
    return json.loads((session / "trace.json").read_text())


view = run("--start=A1B2C3", "--ship=cartographer", "--unlocks=3")
start = {"op": "choose_node", "node": "r0-l0-c0", "expect": view["expect"]}
view = send(start)["view"]
assert view["state"]["mode"] == "combat"
original = trace()
preview = {
    "op": "preview", "uid": view["hand"][0]["uid"], "route": [0],
    "target": {"id": view["targets"][0]["id"], "slot": 0}, "expect": view["expect"],
}
assert send(preview)["view"] == view
assert trace() == original

preview["op"] = "play"
view = send(preview)["view"]
failed = send(start, code=1)
assert "Stale" in failed["result"]["error"]
assert failed["view"]["state"] == view["state"]
assert len(trace()["entries"]) == 2 and len(trace()["errors"]) == 1
view = failed["view"]

# A command file stops after its first failed command, not after executing later lines.
commands = directory / "commands.jsonl"
commands.write_text(json.dumps({"op": "unknown", "expect": view["expect"]}) + "\n"
                    + json.dumps({"op": "abandon", "expect": view["expect"]}) + "\n")
view = run("--resume=true", f"--commands={commands}", code=1)["view"]
assert view["state"]["mode"] == "combat" and len(trace()["errors"]) == 2

verified = run(f"--replay={session / 'trace.json'}", target=directory / "replay")
assert verified["verified_entries"] == 2 and verified["verified_errors"] == 2
assert verified["view"] == view
run("--start=ABC123", code=1)  # Existing active session must not restart.
assert run("--resume=true")["expect"] == view["expect"]
send({"op": "abandon", "expect": view["expect"]})
run(f"--replay={session / 'trace.json'}", target=directory / "replay-finished")

# A save/trace mismatch is not papered over by load or an implicit new_run.
damaged = trace()
damaged["entries"][-1]["after"]["hull"] -= 1
(session / "trace.json").write_text(json.dumps(damaged))
assert not run("--resume=true", code=1)["ok"]
print(f"MANUAL_REPLAY_CLI {checks} process checks passed; isolated artifacts: {directory}")
