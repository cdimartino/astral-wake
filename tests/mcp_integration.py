#!/usr/bin/env python3
"""Opt-in live main-scene integration: python3 tests/mcp_integration.py --godot PATH.

Uses isolated saves and retains engine logs in the printed temporary directory.
No injected scene, evaluation, or test-only game command is used.
"""
import argparse
import json
import os
from pathlib import Path
import queue
import secrets
import socket
import subprocess
import sys
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]


def assert_public(value):
    """Assert transport-level projection on successes, errors and resources."""
    if isinstance(value, dict):
        for key, item in value.items():
            assert key != "seed" and not key.lower().startswith("rng"), ("hidden field", key)
            if key == "battle" and isinstance(item, dict):
                assert "draw" not in item, "draw-pile identities exposed"
            assert_public(item)
        if "state" in value and isinstance(value["state"], dict):
            state = value["state"]
            if state.get("ui", {}).get("screen") == "combat":
                battle = state["run"]["battle"]
                assert type(battle.get("draw_count")) is int, "public draw_count missing"
    elif isinstance(value, list):
        for item in value:
            assert_public(item)


class Client:
    def __init__(self, port, token):
        self.process = subprocess.Popen(
            [sys.executable, str(ROOT / "tools/astral_mcp.py"), "--port", str(port)],
            env={**os.environ, "ASTRAL_MCP_TOKEN": token}, stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.messages = queue.Queue()
        self.events = []
        self.sequence = 0
        self.latencies = []
        threading.Thread(target=self.read, daemon=True).start()
        self.rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {},
                                "clientInfo": {"name": "live-integration", "version": "1"}})

    def read(self):
        for line in self.process.stdout:
            self.messages.put(json.loads(line))

    def rpc(self, method, params=None):
        self.sequence += 1
        self.process.stdin.write(json.dumps({"jsonrpc": "2.0", "id": self.sequence,
                                            "method": method, "params": params or {}}) + "\n")
        self.process.stdin.flush()
        start = time.monotonic()
        while True:
            message = self.messages.get(timeout=40)
            if message.get("id") == self.sequence:
                assert "error" not in message, message
                self.latencies.append((method, (time.monotonic() - start) * 1000))
                assert_public(message["result"])
                if method == "resources/read":
                    for content in message["result"]["contents"]:
                        state = json.loads(content["text"])
                        assert_public({"state": state})
                return message["result"]
            assert_public(message)
            self.events.append(message)

    def tool(self, name, args=None):
        return self.rpc("tools/call", {"name": name, "arguments": args or {}})["structuredContent"]

    def state(self):
        result = self.tool("get_state")
        assert result["ok"], result
        return result["state"]

    def settle(self):
        state = self.state()
        deadline = time.monotonic() + 35
        while state["busy"]:
            assert time.monotonic() < deadline, "presentation never settled"
            result = self.tool("wait_for_state", {"after_revision": state["revision"], "timeout_ms": 1000})
            assert result["ok"], result
            state = result["state"]
        return state

    def act(self, action, args=None):
        state = self.settle()
        legal = {entry["action"]: entry for entry in state["legal_actions"]}
        assert action in legal, (action, state)
        if args is None:
            options = legal[action].get("args", {}).get("index", {}).get("options", [])
            args = {"index": options[0]["index"]} if options else {}
        result = self.tool("act", {"action": action, "args": args, "expected_revision": state["revision"]})
        assert result["ok"], result
        assert result["state"]["revision"] >= state["revision"], result
        print("ACTION", action, json.dumps(result["state"]["ui"]), flush=True)
        return result["state"]

    def close(self):
        self.process.stdin.close()
        self.process.wait(timeout=5)
        diagnostics = self.process.stderr.read()
        self.process.stdout.close()
        self.process.stderr.close()
        assert self.process.returncode == 0, diagnostics


def options(state, action):
    entry = next((entry for entry in state["legal_actions"] if entry["action"] == action), None)
    assert entry is not None, (action, state)
    return entry.get("args", {}).get("index", {}).get("options", [])


def stage_route(client, depth=0):
    """Explore only visible semantic organ controls, undoing unsuccessful paths."""
    state = client.state()
    preview = client.tool("preview")
    if state["ui"]["selection"]["route"] and preview.get("ok") and preview.get("result", {}).get("ok"):
        return preview
    if depth >= 3:
        return None
    original = state["ui"]["selection"]["route"]
    for option in options(state, "select_organ"):
        # The game advertises these descriptions on the visible organ buttons.
        if "Available next organ." not in option.get("description", ""):
            continue
        next_state = client.act("select_organ", {"index": option["index"]})
        route = next_state["ui"]["selection"]["route"]
        assert len(route) == len(original) + 1 and route[:-1] == original, next_state
        preview = stage_route(client, depth + 1)
        if preview is not None:
            return preview
        restored = client.act("undo_route")
        assert restored["ui"]["selection"]["route"] == original, restored
    return None


def completion(client, immediate, before_run, label):
    assert immediate["run"] != before_run, (label, "logical state did not change", immediate)
    assert immediate["busy"], (label, "expected immediate presentation busy state", immediate)
    revision = immediate["revision"]
    blocked = client.tool("act", {"action": "end_turn", "args": {}, "expected_revision": revision})
    assert not blocked["ok"] and blocked["error"]["code"] in ("busy", "stale_revision"), blocked
    state = client.settle()
    assert not state["busy"] and state["revision"] > revision, (label, immediate, state)
    print("PASS", label, "logical mutation/busy/completion revisions", revision, state["revision"], flush=True)
    return state


def combat_flow(client):
    state = client.settle()
    # Navigate advertised map/event controls only; no hidden seed or evaluator.
    for _ in range(16):
        if state["ui"]["screen"] == "combat":
            break
        legal = {entry["action"] for entry in state["legal_actions"]}
        action = next((name for name in ("choose_node", "event_choice", "leave_location", "skip_reward")
                       if name in legal), None)
        assert action, ("cannot reach combat through legal actions", state)
        client.act(action)
        state = client.settle()
    assert state["ui"]["screen"] == "combat", "combat not reached within bounded navigation"
    client.rpc("resources/read", {"uri": "astral://state"})
    initial_cards = options(state, "select_card")
    preview = None
    for card in initial_cards:
        selected = client.act("select_card", {"index": card["index"]})
        assert selected["ui"]["selection"]["card"] == card["index"], selected
        preview = stage_route(client)
        if preview is not None:
            # Explicit target stage after routing, even when target zero is default.
            routed = client.state()
            targets = options(routed, "select_target")
            assert targets, routed
            target = targets[0]
            selected = client.act("select_target", {"index": target["index"]})
            assert selected["ui"]["selection"]["target"] == target["index"], selected
            break
        client.act("cancel_selection")
    assert preview is not None, "no legal routed card preview found"
    before = client.state()
    repeated = client.tool("preview")
    after = client.state()
    assert repeated["ok"] and repeated["result"]["ok"], repeated
    assert before == after, "preview mutated state"
    print("PASS staged card/route/target and nonmutating preview", json.dumps(repeated["result"]), flush=True)
    immediate = client.act("confirm")
    state = completion(client, immediate, before["run"], "confirm")
    assert state["ui"]["screen"] == "combat", "first routed card unexpectedly ended combat"
    immediate = client.act("end_turn")
    completion(client, immediate, state["run"], "end_turn")


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def listening(port):
    try:
        with socket.create_connection(("127.0.0.1", port), .2):
            return True
    except OSError:
        return False


def stop(process):
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--visible", action="store_true")
    args = parser.parse_args()
    evidence = Path(tempfile.mkdtemp(prefix="astral-mcp-integration-"))
    print("EVIDENCE", evidence, flush=True)
    port, token = free_port(), secrets.token_hex(32)
    env = {key: value for key, value in os.environ.items()
           if key not in ("ASTRAL_MCP_PORT", "ASTRAL_MCP_TOKEN", "ASTRAL_SAVE_DIR")}
    env["ASTRAL_SAVE_DIR"] = str(evidence / "saves")
    command = [args.godot, "--path", str(ROOT)]
    if not args.visible:
        command.append("--headless")
    with (evidence / "default.log").open("w") as log:
        process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
        try:
            time.sleep(2)
            assert process.poll() is None, "default engine exited; inspect default.log"
            assert not listening(port), "unexpected default bridge listener"
            print("PASS default launch does not listen on probe port", flush=True)
        finally:
            stop(process)
    env.update(ASTRAL_MCP_PORT=str(port), ASTRAL_MCP_TOKEN=token)
    clients = []
    with (evidence / "engine.log").open("w") as log:
        process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 20
            while not listening(port):
                assert process.poll() is None, "engine exited; inspect engine.log"
                assert time.monotonic() < deadline, "bridge startup timeout; inspect engine.log"
                time.sleep(.1)
            bad = Client(port, "incorrect-token-" * 4)
            clients.append(bad)
            denied = bad.tool("get_state")
            assert not denied["ok"] and denied["error"]["code"] == "unauthorized", denied
            assert "state" not in denied, denied
            bad.close()
            clients.remove(bad)
            client = Client(port, token)
            clients.append(client)
            state = client.settle()
            assert state["ui"]["screen"] == "title", state
            client.rpc("resources/subscribe", {"uri": "astral://state"})
            initial_revision = state["revision"]
            state = client.act("open_settings")
            assert state["ui"]["overlay"] == "Settings", state
            client.act("set_setting", {"key": "reduced_motion", "value": False})
            state = client.state()
            stale = client.tool("act", {"action": "close_overlay", "args": {},
                                        "expected_revision": initial_revision})
            assert not stale["ok"] and stale["error"]["code"] == "stale_revision", stale
            invalid = client.tool("act", {"action": "not_a_game_action", "args": {},
                                          "expected_revision": state["revision"]})
            assert not invalid["ok"] and invalid["error"]["code"] == "unknown_action", invalid
            state = client.act("close_overlay")
            assert not state["ui"]["overlay"], state
            state = client.act("new_expedition")
            assert state["ui"]["screen"] == "character", state
            state = client.act("select_character")
            assert state["ui"]["selection"]["character"] is not None, state
            state = client.act("begin_expedition")
            assert state["run"], state
            state = client.settle()
            assert state["ui"]["screen"] not in ("title", "character"), state
            combat_flow(client)
            client.state()  # drain asynchronous notifications before reporting
            assert any(event.get("method") == "notifications/resources/updated" for event in client.events), client.events
            client.rpc("resources/read", {"uri": "astral://state"})
            print("PASS public projection on tool success/error/preview and subscription-triggered resource refresh", flush=True)
            print("PASS resource notifications", len(client.events), flush=True)
            print("LATENCY_MS", json.dumps(client.latencies), flush=True)
            print("SKIP manual-input event: requires human interaction; no synthetic injection", flush=True)
            print("PASS real stdio → authenticated loopback → live main scene", flush=True)
        finally:
            for client in clients:
                client.close()
            stop(process)
    assert not listening(port), "bridge still listening after shutdown"
    print("PASS shutdown closes listener", flush=True)


if __name__ == "__main__":
    main()
