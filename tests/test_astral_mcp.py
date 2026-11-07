"""Real subprocess MCP transport tests; no Godot or third-party packages needed."""
import json
import os
from pathlib import Path
import queue
import socket
import subprocess
import sys
import threading
import time
import unittest

HOST = Path(__file__).resolve().parents[1] / "tools" / "astral_mcp.py"
TOKEN = "test-secret-" * 4


class FakeBridge:
    def __init__(self):
        self.listener = socket.socket()
        self.listener.bind(("127.0.0.1", 0))
        self.listener.listen()
        self.port = self.listener.getsockname()[1]
        self.requests = []
        self.connections = []
        self.mode = "normal"
        self.state = {"revision": 1, "busy": False, "legal_actions": []}
        self.stopped = False
        threading.Thread(target=self.accept, daemon=True).start()

    def accept(self):
        while not self.stopped:
            try:
                conn, _ = self.listener.accept()
            except OSError:
                return
            self.connections.append(conn)
            threading.Thread(target=self.serve, args=(conn,), daemon=True).start()

    def serve(self, conn):
        try:
            with conn.makefile("rb") as stream:
                for line in stream:
                    request = json.loads(line)
                    self.requests.append(request)
                    mode = self.mode
                    if mode == "disconnect":
                        conn.shutdown(socket.SHUT_RDWR)
                        return
                    if mode == "timeout":
                        continue
                    if mode == "malformed":
                        conn.sendall(b"not json\n")
                        return
                    response = {"id": request["id"], "ok": True, "state": self.state.copy()}
                    if request["token"] != TOKEN or mode == "unauthorized":
                        response = {"id": request["id"], "ok": False,
                                    "error": {"code": "unauthorized", "message": "denied"}}
                    elif mode in ("busy", "stale_revision", "invalid_args", "unknown_action"):
                        response.update(ok=False, error={"code": mode, "message": mode})
                    conn.sendall(json.dumps(response).encode() + b"\n")
        except OSError:
            pass
        finally:
            conn.close()

    def change(self, revision):
        self.state["revision"] = revision
        wire = json.dumps({"event": "state_changed", "state": self.state}).encode() + b"\n"
        for conn in self.connections:
            try:
                conn.sendall(wire)
            except OSError:
                pass

    def close(self):
        self.stopped = True
        self.listener.close()
        for conn in self.connections:
            try:
                conn.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            conn.close()


class StdioTest(unittest.TestCase):
    def setUp(self):
        self.bridge = FakeBridge()
        self.process = subprocess.Popen(
            [sys.executable, str(HOST), "--port", str(self.bridge.port), "--bridge-timeout", "0.2"],
            env={**os.environ, "ASTRAL_MCP_TOKEN": TOKEN}, stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.messages = queue.Queue()
        self.sequence = 0
        threading.Thread(target=self.read, daemon=True).start()
        self.rpc("initialize", {"protocolVersion": "2024-11-05", "capabilities": {},
                                "clientInfo": {"name": "test", "version": "1"}})

    def read(self):
        for line in self.process.stdout:
            self.messages.put(json.loads(line))

    def tearDown(self):
        self.process.stdin.close()
        self.process.wait(timeout=3)
        self.bridge.close()
        self.process.stdout.close()
        self.process.stderr.close()
        self.assertEqual(self.process.returncode, 0)

    def send(self, method, params=None):
        self.sequence += 1
        self.process.stdin.write(json.dumps({"jsonrpc": "2.0", "id": self.sequence,
                                            "method": method, "params": params or {}}) + "\n")
        self.process.stdin.flush()
        return self.sequence

    def rpc(self, method, params=None):
        request_id = self.send(method, params)
        while True:
            message = self.messages.get(timeout=3)
            if message.get("id") == request_id:
                return message

    def tool(self, name, args=None):
        return self.rpc("tools/call", {"name": name, "arguments": args or {}})

    def test_discovery_negotiation_and_results(self):
        result = self.rpc("initialize", {"protocolVersion": "future"})["result"]
        self.assertEqual(result["protocolVersion"], "2025-11-25")
        self.assertIn("legal_actions", result["instructions"])
        self.assertIn("expected_revision", result["instructions"])
        self.assertIn("v0.2.0", result["instructions"])
        tools = self.rpc("tools/list")["result"]["tools"]
        self.assertEqual({tool["name"] for tool in tools}, {"get_state", "act", "preview", "wait_for_state"})
        for name in ("get_state", "preview"):
            result = self.tool(name)["result"]
            self.assertEqual(json.loads(result["content"][0]["text"]), result["structuredContent"])
            self.assertFalse(result["isError"])
        state = self.rpc("resources/read", {"uri": "astral://state"})["result"]
        self.assertEqual(json.loads(state["contents"][0]["text"])["revision"], 1)

    def test_validation_never_reaches_bridge(self):
        cases = [("act", {"action": "x", "args": {}, "expected_revision": True}),
                 ("act", {"action": "", "args": {}, "expected_revision": 1}),
                 ("act", {"action": "x", "args": [], "expected_revision": 1}),
                 ("get_state", {"extra": 1}), ("preview", {"args": {}}),
                 ("wait_for_state", {"after_revision": False}),
                 ("wait_for_state", {"after_revision": 0, "timeout_ms": True}),
                 ("wait_for_state", {"after_revision": 0, "timeout_ms": 30001})]
        for name, args in cases:
            with self.subTest(name=name, args=args):
                self.assertEqual(self.tool(name, args)["error"]["code"], -32602)
        self.assertEqual(self.bridge.requests, [])

    def test_opencode_session_metadata_is_not_bridge_authentication(self):
        result = self.rpc("tools/call", {"name": "get_state", "arguments": {},
                                        "_meta": {"sessionID": "ses_opencode_test"}})
        self.assertFalse(result["result"]["isError"])
        request = self.bridge.requests[-1]
        self.assertEqual(request["token"], TOKEN)
        self.assertEqual(request["params"], {})
        self.assertNotIn("_meta", request)
        self.assertNotIn("ses_opencode_test", json.dumps(request))

    def test_game_errors_and_semantic_forwarding(self):
        for mode in ("busy", "stale_revision", "unauthorized", "invalid_args", "unknown_action"):
            self.bridge.mode = mode
            result = self.tool("act", {"action": "choose", "args": {"index": 2},
                                       "expected_revision": 1})["result"]
            self.assertTrue(result["isError"])
            self.assertEqual(result["structuredContent"]["error"]["code"], mode)
            if mode == "unauthorized":
                self.assertNotIn("state", result["structuredContent"])
        self.assertEqual(self.bridge.requests[-1]["params"],
                         {"action": "choose", "args": {"index": 2}, "expected_revision": 1})

    def test_disconnect_timeout_malformed_no_mutation_retry(self):
        for mode in ("disconnect", "timeout", "malformed"):
            self.bridge.mode = mode
            before = len(self.bridge.requests)
            result = self.tool("act", {"action": "choose", "args": {},
                                       "expected_revision": 1})["result"]
            self.assertTrue(result["isError"])
            self.assertIn("uncertain", result["structuredContent"]["error"]["message"])
            self.assertEqual(len(self.bridge.requests), before + 1)
            self.bridge.mode = "normal"
            self.assertFalse(self.tool("get_state")["result"]["isError"])

    def test_wait_and_subscription_events(self):
        self.rpc("resources/subscribe", {"uri": "astral://state"})
        self.bridge.change(2)
        self.assertEqual(self.messages.get(timeout=2)["method"], "notifications/resources/updated")
        result = self.tool("wait_for_state", {"after_revision": 1, "timeout_ms": 0})["result"]
        self.assertFalse(result["structuredContent"]["result"]["timed_out"])
        start = time.monotonic()
        result = self.tool("wait_for_state", {"after_revision": 2, "timeout_ms": 50})["result"]
        self.assertTrue(result["structuredContent"]["result"]["timed_out"])
        self.assertGreaterEqual(time.monotonic() - start, .04)
        request_id = self.send("tools/call", {"name": "wait_for_state", "arguments":
                                            {"after_revision": 2, "timeout_ms": 2000}})
        self.bridge.change(3)
        seen = [self.messages.get(timeout=3), self.messages.get(timeout=3)]
        result = next(message for message in seen if message.get("id") == request_id)
        self.assertEqual(result["result"]["structuredContent"]["state"]["revision"], 3)
        self.rpc("resources/unsubscribe", {"uri": "astral://state"})
        self.bridge.change(4)
        self.assertTrue(self.messages.empty())

    def test_malformed_stdio_and_notification(self):
        self.process.stdin.write("not json\n")
        self.process.stdin.flush()
        self.assertEqual(self.messages.get(timeout=2)["error"]["code"], -32700)
        self.process.stdin.write(json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}) + "\n")
        self.process.stdin.flush()
        self.assertEqual(self.rpc("ping")["result"], {})

    def test_invalid_envelope_and_startup_configuration(self):
        self.process.stdin.write('{"jsonrpc":"2.0","id":true,"method":"ping"}\n')
        self.process.stdin.flush()
        self.assertEqual(self.messages.get(timeout=2)["error"]["code"], -32600)
        result = subprocess.run([sys.executable, str(HOST), "--port", "0"],
                                env={**os.environ, "ASTRAL_MCP_TOKEN": "short"},
                                capture_output=True, text=True, timeout=3)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, "")
        self.assertIn("ASTRAL_MCP_TOKEN", result.stderr)

    def test_oversized_stdio_is_bounded(self):
        self.process.stdin.write("x" * (1024 * 1024) + "\n")
        self.process.stdin.flush()
        self.assertEqual(self.messages.get(timeout=2)["error"]["code"], -32600)
        self.process.wait(timeout=3)


if __name__ == "__main__":
    unittest.main()
