"""Counter-bearing fixture CLI across processes; same-HEAD dirty rules reject."""
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
directory = Path(tempfile.mkdtemp(prefix="astral-defense-replay-", dir=os.environ.get("TMPDIR")))
project = directory / "project"
project.mkdir()
for name in ("scripts", "tools", "data", "tests"):
    shutil.copytree(repository / name, project / name)
shutil.copy2(repository / "project.godot", project / "project.godot")
git_dir = subprocess.check_output(["git", "-C", str(repository), "rev-parse", "--absolute-git-dir"], text=True).strip()
(project / ".git").write_text(f"gitdir: {git_dir}\n")
head = subprocess.check_output(["git", "-C", str(project), "rev-parse", "HEAD"], text=True).strip()
session = directory / "session"
checks = 0


def run(*args, target=session, code=0):
    global checks
    result = subprocess.run(
        [engine, "--headless", "--path", str(project), "--script", "tests/defense_engine_driver.gd",
         "--", f"--session={target}", *args], capture_output=True, text=True, timeout=120,
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


view = send("play", **target(1, [0, 1]))["view"]
assert view["state"]["battle"]["engine_counters"][0]["used"] is False
view = send("begin_selection", **target(4, [3]))["view"]
view = send("select_uid", choice_uid=5)["view"]
before = view
preview = send("selection_preview")
assert send("selection_preview") == preview and run("--resume=true") == before
assert before["state"]["battle"]["ward"] == 0
view = send("cancel_selection")["view"]
assert view["state"]["battle"]["ward"] == 0
view = send("begin_selection", **target(4, [3]))["view"]
view = send("select_uid", choice_uid=5)["view"]
committed = send("confirm_selection")
assert committed["result"] == preview["result"]
view = committed["view"]
assert view["state"]["battle"]["ward"] == 5
assert view["state"]["battle"]["engine_counters"][0]["used"] is True
assert run("--resume=true") == view
view = send("end_turn")["view"]
assert view["state"]["battle"]["engine_counters"][0]["used"] is False
view = send("play", **target(2, [3]))["view"]
assert [c["stacks"] for c in view["state"]["battle"]["engine_counters"]] == [0, 0]
view = send("end_turn")["view"]  # Cinder turn 2 is strain, not an attack.
view = send("play", **target(3, [5]))["view"]
phase = send("end_turn")
view = phase["view"]
events = [e for e in phase["result"]["presentation"] if e.get("engine") == "redirect_retaliation"]
assert len(events) == 1 and events[0]["source_uid"] == 2 and events[0]["target_index"] == 1
assert all(not c["used"] for c in view["state"]["battle"]["engine_counters"])

trace_path = session / "trace.json"
journal = json.loads(trace_path.read_text())
assert journal["environment"]["game_revision"] == head
sources = ("game.gd", "install_engines.gd", "known_selections.gd", "route_effects.gd")
for name in sources:
    path = f"scripts/{name}"
    assert journal["environment"]["sources"][path] == hashlib.sha256((project / path).read_bytes()).hexdigest()
verified = run(f"--replay={trace_path}", target=directory / "replay")
assert verified["verified_entries"] == len(journal["entries"]) and verified["verified_errors"] == 0
assert verified["view"] == view
assert json.loads((directory / "replay" / "trace.json").read_text()) == journal

saved_files = {p.relative_to(session): p.read_bytes() for p in session.rglob("*") if p.is_file()}
for name in sources:
    source = project / "scripts" / name
    original = source.read_bytes()
    rejected_replay = directory / f"dirty-{name}"
    try:
        source.write_bytes(original + b"\n# Same-HEAD defense engine fingerprint regression.\n")
        assert subprocess.check_output(["git", "-C", str(project), "rev-parse", "HEAD"], text=True).strip() == head
        for rejected in (run("--resume=true", code=1), run(f"--replay={trace_path}", target=rejected_replay, code=1)):
            assert "source fingerprints" in rejected["error"]
        assert not rejected_replay.exists()
        assert {p.relative_to(session): p.read_bytes() for p in session.rglob("*") if p.is_file()} == saved_files
    finally:
        source.write_bytes(original)
    assert run("--resume=true") == view
    assert run(f"--replay={trace_path}", target=directory / f"restored-{name}")["view"] == view

print(f"DEFENSE_ENGINE_REPLAY {checks} process checks passed; {len(journal['entries'])} entries; isolated artifacts: {directory}")
