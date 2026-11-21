"""Record a Glass Beyond map and combat take from the real audio mixer via MCP.

Usage: python3 tools/capture_listening_scene.py OUTPUT [--project BASELINE_PATH]
The same tests/listening_scene.gd must be present in both projects.
"""
import argparse
import os
from pathlib import Path
import secrets
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
from mcp_integration import Client, free_port, listening, options, stop


def record(project, output):
    output.mkdir(parents=True, exist_ok=False)
    port, token = free_port(), secrets.token_hex(32)
    with tempfile.TemporaryDirectory(prefix="hull-listen-") as save, (output / "engine.log").open("w") as log:
        env = dict(os.environ, ASTRAL_SAVE_DIR=save, ASTRAL_LISTEN_DIR=str(output),
                   ASTRAL_MCP_PORT=str(port), ASTRAL_MCP_TOKEN=token, ASTRAL_SKIP_INTRO="1")
        process = subprocess.Popen([str(ROOT / ".tools/Godot.app/Contents/MacOS/Godot"),
            "--headless", "--audio-driver", "Dummy", "--path", str(project),
            "--script", "tests/listening_scene.gd"], env=env, stdout=log, stderr=log)
        client = None
        try:
            start = time.monotonic()
            while not listening(port):
                assert process.poll() is None and time.monotonic() - start < 30, log.name
                time.sleep(.1)
            client = Client(port, token)
            assert client.settle()["ui"]["screen"] == "map"
            time.sleep(6)
            client.act("choose_node")
            assert client.settle()["ui"]["screen"] == "combat"
            time.sleep(2)
            state = client.state()
            cards = options(state, "select_card")
            card = next((c for c in cards if "Deal 9 damage" in c["description"]), cards[0])
            client.act("select_card", {"index": card["index"]})
            for organ in ["Lens", "Fork", "Echo"]:
                available = options(client.state(), "select_organ")
                hit = next((o for o in available if organ in o["description"].splitlines()[0] and "Available next organ." in o["description"]), None)
                if not hit: break
                client.act("select_organ", {"index": hit["index"]})
                time.sleep(.55)
            preview = client.tool("preview")
            assert preview.get("result", {}).get("ok"), preview
            client.act("confirm")
            state = client.settle()
            if state["ui"]["screen"] == "combat":
                time.sleep(1)
                client.act("end_turn")
                client.settle()
            time.sleep(5)
            (output / "stop").touch()
            assert process.wait(timeout=20) == 0 and (output / "take.wav").is_file(), log.name
        finally:
            if client: client.close()
            if process.poll() is None: stop(process)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--project", type=Path, default=ROOT)
    args = parser.parse_args()
    record(args.project.resolve(), args.output.resolve())
