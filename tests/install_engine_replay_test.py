"""Real counter-bearing replay and same-HEAD dirty-source rejection, isolated."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


engine = str(Path(sys.argv[1]).resolve())
repository = Path(__file__).resolve().parents[1]
directory = Path(tempfile.mkdtemp(prefix="astral-engine-replay-", dir=os.environ.get("TMPDIR")))
project = directory / "project"
project.mkdir()
# Change only disposable copies, never dirty an authoritative working-tree source.
for name in ("scripts", "tools", "data", "tests"):
    shutil.copytree(repository / name, project / name)
shutil.copy2(repository / "project.godot", project / "project.godot")
git_dir = subprocess.check_output(
    ["git", "-C", str(repository), "rev-parse", "--absolute-git-dir"], text=True,
).strip()
(project / ".git").write_text(f"gitdir: {git_dir}\n")
head = subprocess.check_output(["git", "-C", str(project), "rev-parse", "HEAD"], text=True).strip()
session = directory / "session"
checks = 0


def run(*args, target=session, code=0):
    global checks
    result = subprocess.run(
        [engine, "--headless", "--path", str(project), "--script", "tests/install_engine_driver.gd",
         "--", f"--session={target}", *args],
        capture_output=True, text=True, timeout=120,
    )
    assert result.returncode == code, (result.returncode, result.stdout, result.stderr)
    assert "SCRIPT ERROR" not in result.stderr, result.stderr
    rows = [json.loads(line) for line in result.stdout.splitlines() if line.startswith("{")]
    assert rows, result.stdout
    checks += 1
    return rows[-1]


view = run("--start=A1B2C3")


def send(op, **fields):
    return run("--resume=true", "--command=" + json.dumps({"op": op, "expect": view["expect"], **fields}))


def target(uid, route):
    return {"uid": uid, "route": route, "target": {"id": "cinder_mite", "slot": 0}}


view = send("play", **target(1, [3]))["view"]  # Atlas installation: zero stacks.
before = view
assert send("preview", **target(3, [4]))["result"]["damage"] == 10
assert run("--resume=true") == before  # Preview cannot mutate the ledger/RNG.
played = send("play", **target(3, [4]))
assert played["result"]["damage"] == 10
view = played["view"]
assert view["state"]["battle"]["engine_counters"][0]["stacks"] == 1
view = send("play", **target(2, [5]))["view"]  # Furnace installation.
assert [c["stacks"] for c in view["state"]["battle"]["engine_counters"]] == [1, 0]
view = send("end_turn")["view"]
assert view["state"]["battle"]["turn"] == 2
view = send("begin_selection", **target(4, [3]))["view"]
view = send("select_uid", choice_uid=5)["view"]
before = view
preview = send("selection_preview")
assert send("selection_preview") == preview and run("--resume=true") == before
committed = send("confirm_selection")
assert committed["result"] == preview["result"]
view = committed["view"]
battle = view["state"]["battle"]
assert [c["stacks"] for c in battle["engine_counters"]] == [1, 1]
assert battle["ward"] == 3 and battle["engine_counters"][1]["used"] is True
assert [card["uid"] for card in battle["exhausted"]] == [5, 4]  # Victim then source, one payout.
for base_damage, actual_damage in ((12, 16), (13, 17)):
    uid = view["hand"][0]["uid"]
    played = send("play", **target(uid, [4]))
    # The normal turn-2 Cinder Mite intent is exposed (+4 per hit).
    assert played["result"]["route_steps"][0]["payload_before"][0] == base_damage
    assert played["result"]["damage"] == actual_damage
    view = played["view"]
assert [c["stacks"] for c in view["state"]["battle"]["engine_counters"]] == [2, 1]
assert view["state"]["battle"]["engine_routes"] == [[3], [4]]

trace_path = session / "trace.json"
journal = json.loads(trace_path.read_text())
assert journal["environment"]["game_revision"] == head
for name in ("install_engines.gd", "known_selections.gd", "route_effects.gd"):
    path = f"scripts/{name}"
    assert journal["environment"]["sources"][path] == hashlib.sha256((project / path).read_bytes()).hexdigest()
verified = run(f"--replay={trace_path}", target=directory / "replay")
assert verified["verified_entries"] == 9 and verified["verified_errors"] == 0
assert verified["view"] == view
assert json.loads((directory / "replay" / "trace.json").read_text()) == journal

# Same revision, genuinely different bytes: rejection cannot rely on HEAD alone.
saved_files = {path.relative_to(session): path.read_bytes() for path in session.rglob("*") if path.is_file()}
for name in ("install_engines.gd", "known_selections.gd", "route_effects.gd"):
    source = project / "scripts" / name
    original = source.read_bytes()
    rejected_replay = directory / f"dirty-{name}"
    try:
        source.write_bytes(original + b"\n# Same-HEAD audit fingerprint regression.\n")
        assert subprocess.check_output(["git", "-C", str(project), "rev-parse", "HEAD"], text=True).strip() == head
        for rejected in (run("--resume=true", code=1), run(f"--replay={trace_path}", target=rejected_replay, code=1)):
            assert "source fingerprints" in rejected["error"]
        assert not rejected_replay.exists()  # Reject before starting a new expedition.
        assert {path.relative_to(session): path.read_bytes() for path in session.rglob("*") if path.is_file()} == saved_files
    finally:
        source.write_bytes(original)
    assert run("--resume=true") == view
    assert run(f"--replay={trace_path}", target=directory / f"restored-{name}")["view"] == view

print(f"INSTALL_ENGINE_REPLAY {checks} process checks passed; 9 counter-bearing entries; isolated artifacts: {directory}")
