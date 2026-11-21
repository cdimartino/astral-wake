"""Exercise the shipped PCK and its packaged macOS executable in fresh saves."""
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
from mcp_integration import Client, free_port, listening, stop


def verify():
    app = ROOT / "dist/Astral Wake.app/Contents"
    with tempfile.TemporaryDirectory(prefix="astral-hull-export-") as temp:
        folder = Path(temp).resolve()
        env = dict(os.environ, ASTRAL_SAVE_DIR=str(folder), ASTRAL_SKIP_INTRO="1")
        # Ship only the portable bank, exactly as a composer would copy it.
        bank = folder / "hull_audio/banks/listening"
        shutil.copytree(ROOT / "audio/hull", bank, ignore=shutil.ignore_patterns("*.import"))
        script = shutil.copy(ROOT / "tests/exported_hull_test.gd", folder)
        run = subprocess.run([ROOT / ".tools/Godot.app/Contents/MacOS/Godot",
            "--headless", "--main-pack", app / "Resources/Astral Wake.pck", "--script", script,
            "--quit-after", "1200"], cwd=folder, env=env, capture_output=True, text=True, timeout=40)
        print(run.stdout, run.stderr, end="")
        assert run.returncode == 0 and "EXPORTED SOUND WORKSHOP: 0 failures" in run.stdout
        assert "SCRIPT ERROR" not in run.stderr
        port, token = free_port(), secrets.token_hex(32)
        env.update(ASTRAL_MCP_PORT=str(port), ASTRAL_MCP_TOKEN=token)
        with (folder / "launch.log").open("w") as out:
            process = subprocess.Popen([app / "MacOS/Astral Wake", "--headless"], cwd=folder,
                                       env=env, stdout=out, stderr=out)
            client = None
            try:
                deadline = time.monotonic() + 20
                while not listening(port):
                    assert process.poll() is None and time.monotonic() < deadline
                    time.sleep(.1)
                client = Client(port, token)
                assert client.settle()["ui"]["screen"] == "title"
                assert client.act("open_settings")["ui"]["overlay"] == "Settings"
            finally:
                if client: client.close()
                stop(process)
        assert "SCRIPT ERROR" not in (folder / "launch.log").read_text()
        print("PASS: signed app boots and exposes ordinary player settings; exported bank hot-swap verified.")


if __name__ == "__main__":
    verify()
