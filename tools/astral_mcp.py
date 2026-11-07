#!/usr/bin/env python3
"""Dependency-free MCP stdio adapter for Astral Wake's opt-in loopback bridge."""
import argparse
import json
import os
import socket
import sys
import threading
import time
import uuid

MAX_LINE = 1024 * 1024
VERSIONS = ("2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05")
INSTRUCTIONS = """Control Astral Wake only through this MCP connection. Read get_state first,
then choose a semantic action and arguments from that state's legal_actions. Call
act with that exact state's revision as expected_revision; refresh state after
stale_revision. Stage combat through visible card, route and target selections,
then preview the live selection before confirming. Use wait_for_state with
after_revision and timeout_ms <= 30000 for presentation completion; refresh state
and legal_actions before the next action. Never automatically retry a mutation
after disconnect or an uncertain outcome: read fresh state first. Do not inspect
secrets, credentials, save files or hidden game data to choose actions. Blind-play
protection depends on the connected game's state projection: the old v0.2.0 app
still exposes hidden data, so this host alone does not make that app fully blind.
Use only information the current game intentionally makes visible to the player.
The astral://state resource supports read/subscription updates."""


class BridgeError(Exception):
    pass


class InvalidRequest(ValueError):
    pass


def reject_constant(value):
    raise ValueError("non-finite JSON number: " + value)


class Bridge:
    def __init__(self, port, token, notify, timeout=5):
        self.port, self.token, self.notify, self.timeout = port, token, notify, timeout
        self.lock = threading.RLock()
        self.changed = threading.Condition(self.lock)
        self.sock = None
        self.pending = {}
        self.state = None

    def connect(self):
        with self.lock:
            if self.sock is not None:
                return
            sock = socket.create_connection(("127.0.0.1", self.port), self.timeout)
            sock.settimeout(None)
            self.sock = sock
            threading.Thread(target=self.read, args=(sock,), daemon=True).start()

    def read(self, sock):
        try:
            with sock.makefile("rb") as stream:
                while True:
                    line = stream.readline(MAX_LINE + 1)
                    if not line:
                        raise BridgeError("bridge disconnected")
                    if len(line) > MAX_LINE or not line.endswith(b"\n"):
                        raise BridgeError("oversized bridge response")
                    message = json.loads(line, parse_constant=reject_constant)
                    if not isinstance(message, dict):
                        raise BridgeError("malformed bridge response")
                    with self.lock:
                        state = message.get("state")
                        if isinstance(state, dict):
                            self.state = state
                            self.changed.notify_all()
                        if "id" in message:
                            pending = self.pending.get(message["id"])
                            if pending:
                                pending[1].append(message)
                                pending[0].set()
                    if message.get("event") == "state_changed" and isinstance(state, dict):
                        self.notify()
        except (OSError, ValueError, TypeError, BridgeError) as exc:
            print("Bridge connection ended: " + str(exc), file=sys.stderr)
        finally:
            with self.lock:
                if self.sock is sock:
                    self.sock = None
                    self.state = None
                    for event, responses in self.pending.values():
                        event.set()
                self.changed.notify_all()
            sock.close()

    def request(self, method, params):
        request_id = uuid.uuid4().hex
        event, responses = threading.Event(), []
        mutation = method == "act"
        sock = None
        try:
            self.connect()
            with self.lock:
                self.pending[request_id] = (event, responses)
                sock = self.sock
            wire = json.dumps({"id": request_id, "token": self.token,
                               "method": method, "params": params}).encode() + b"\n"
            if len(wire) > MAX_LINE:
                raise BridgeError("request exceeds bridge size limit")
            # A send timeout also bounds a bridge that stops reading requests.
            sock.settimeout(self.timeout)
            sock.sendall(wire)
            sock.settimeout(None)
            if not event.wait(self.timeout):
                sock.shutdown(socket.SHUT_RDWR)
                raise BridgeError("bridge response timed out")
            if not responses:
                raise BridgeError("bridge disconnected before response")
            response = responses[0]
            if type(response.get("ok")) is not bool:
                raise BridgeError("malformed bridge response")
            return response
        except (OSError, BridgeError) as exc:
            with self.lock:
                if sock is not None and self.sock is sock:
                    self.sock = None
                    self.state = None
                    self.changed.notify_all()
            if sock is not None:
                try:
                    sock.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass
                sock.close()
            suffix = (" Mutation outcome is uncertain; do not retry automatically. "
                      "Read fresh state before deciding what to do next.") if mutation else ""
            raise BridgeError(str(exc) + suffix) from exc
        finally:
            with self.lock:
                self.pending.pop(request_id, None)


def integer(value, minimum, maximum):
    return type(value) is int and minimum <= value <= maximum


class Server:
    def __init__(self, port, token, timeout):
        self.output_lock = threading.Lock()
        self.subscribed = False
        self.initialized = False
        self.bridge = Bridge(port, token, self.updated, timeout)

    def send(self, message):
        with self.output_lock:
            sys.stdout.write(json.dumps(message, separators=(",", ":")) + "\n")
            sys.stdout.flush()

    def updated(self):
        if self.subscribed:
            self.send({"jsonrpc": "2.0", "method": "notifications/resources/updated",
                       "params": {"uri": "astral://state"}})

    def tools(self):
        definitions = [
            ("get_state", "Read authoritative live state and legal_actions.", {}, []),
            ("preview", "Preview the live selection without mutation.", {}, []),
            ("act", "Perform a semantic action from state.legal_actions; game validates arguments.",
             {"action": {"type": "string", "minLength": 1, "maxLength": 128},
              "args": {"type": "object"}, "expected_revision": {"type": "integer", "minimum": 0}},
             ["action", "args", "expected_revision"]),
            ("wait_for_state", "Wait for a revision newer than after_revision.",
             {"after_revision": {"type": "integer", "minimum": 0},
              "timeout_ms": {"type": "integer", "minimum": 0, "maximum": 30000}},
             ["after_revision"])]
        return [{"name": name, "description": desc,
                 "inputSchema": {"type": "object", "properties": props,
                                 "required": required, "additionalProperties": False}}
                for name, desc, props, required in definitions]

    def call(self, name, args):
        definitions = {tool["name"]: tool["inputSchema"] for tool in self.tools()}
        if name not in definitions:
            raise ValueError("unknown tool")
        schema = definitions[name]
        if not isinstance(args, dict) or set(args) - set(schema["properties"]) or any(
                key not in args for key in schema["required"]):
            raise ValueError("invalid tool arguments")
        if name == "act":
            if (not isinstance(args["action"], str) or not 1 <= len(args["action"]) <= 128
                    or not isinstance(args["args"], dict)
                    or not integer(args["expected_revision"], 0, 2**63 - 1)):
                raise ValueError("invalid action arguments")
        if name == "wait_for_state":
            if (not integer(args["after_revision"], 0, 2**63 - 1)
                    or not integer(args.get("timeout_ms", 30000), 0, 30000)):
                raise ValueError("invalid wait arguments")
        try:
            if name != "wait_for_state":
                result = self.bridge.request(name, args)
            else:
                result = self.bridge.request("get_state", {})
                if result.get("ok"):
                    deadline = time.monotonic() + args.get("timeout_ms", 30000) / 1000
                    with self.bridge.changed:
                        while True:
                            state = self.bridge.state
                            if state is None:
                                raise BridgeError("bridge disconnected while waiting; read fresh state")
                            revision = state.get("revision")
                            if not integer(revision, 0, 2**63 - 1):
                                raise BridgeError("invalid state revision")
                            remaining = deadline - time.monotonic()
                            if revision > args["after_revision"] or remaining <= 0:
                                result = {"ok": True, "state": state,
                                          "result": {"timed_out": revision <= args["after_revision"]}}
                                break
                            self.bridge.changed.wait(remaining)
            result.pop("id", None)
        except BridgeError as exc:
            result = {"ok": False, "error": {"code": "bridge_unavailable", "message": str(exc)}}
        return {"content": [{"type": "text", "text": json.dumps(result)}],
                "structuredContent": result, "isError": not result.get("ok", False)}

    def dispatch(self, method, params):
        if not isinstance(params, dict):
            raise ValueError("params must be an object")
        if method == "initialize":
            if not isinstance(params.get("protocolVersion"), str):
                raise ValueError("protocolVersion is required")
            self.initialized = True
            version = params["protocolVersion"]
            return {"protocolVersion": version if version in VERSIONS else VERSIONS[0],
                    "instructions": INSTRUCTIONS,
                    "capabilities": {"tools": {}, "resources": {"subscribe": True}},
                    "serverInfo": {"name": "astral-wake", "version": "1.0.0"}}
        if not self.initialized:
            raise ValueError("initialize first")
        if method == "ping":
            return {}
        if method == "tools/list":
            return {"tools": self.tools()}
        if method == "tools/call":
            if set(params) - {"name", "arguments", "_meta"} or not isinstance(params.get("name"), str):
                raise ValueError("invalid tool call")
            return self.call(params["name"], params.get("arguments", {}))
        if method == "resources/list":
            return {"resources": [{"uri": "astral://state", "name": "Live game state",
                                   "mimeType": "application/json"}]}
        if method in ("resources/read", "resources/subscribe", "resources/unsubscribe"):
            if params.get("uri") != "astral://state":
                raise ValueError("unknown resource URI")
            if method == "resources/unsubscribe":
                self.subscribed = False
                return {}
            result = self.bridge.request("get_state", {})
            if not result.get("ok"):
                raise BridgeError(json.dumps(result.get("error")))
            if method == "resources/subscribe":
                self.subscribed = True
                return {}
            return {"contents": [{"uri": "astral://state", "mimeType": "application/json",
                                  "text": json.dumps(result["state"])}]}
        raise LookupError("method not found")

    def run(self):
        while True:
            line = sys.stdin.buffer.readline(MAX_LINE + 1)
            if not line:
                return
            request_id = None
            try:
                if len(line) > MAX_LINE:
                    self.send({"jsonrpc": "2.0", "id": None,
                               "error": {"code": -32600, "message": "input exceeds 1 MiB"}})
                    return
                message = json.loads(line, parse_constant=reject_constant)
                if (not isinstance(message, dict) or message.get("jsonrpc") != "2.0"
                        or not isinstance(message.get("method"), str)
                        or ("id" in message and type(message["id"]) not in (str, int))):
                    raise InvalidRequest("invalid JSON-RPC request")
                request_id = message.get("id")
                if "id" not in message:
                    continue
                result = self.dispatch(message["method"], message.get("params", {}))
                self.send({"jsonrpc": "2.0", "id": request_id, "result": result})
            except (ValueError, LookupError, BridgeError, OSError) as exc:
                code = (-32700 if isinstance(exc, (json.JSONDecodeError, UnicodeDecodeError)) else
                        -32600 if isinstance(exc, InvalidRequest) else
                        -32601 if isinstance(exc, LookupError) else
                        -32603 if isinstance(exc, (BridgeError, OSError)) else -32602)
                self.send({"jsonrpc": "2.0", "id": request_id,
                           "error": {"code": code, "message": str(exc)}})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--bridge-timeout", type=float, default=5, help="bridge deadline in seconds (0.1–30)")
    args = parser.parse_args()
    token = os.environ.get("ASTRAL_MCP_TOKEN", "")
    if not 1 <= args.port <= 65535 or not 0.1 <= args.bridge_timeout <= 30 or len(token) < 32:
        parser.error("port must be 1–65535, timeout 0.1–30, and ASTRAL_MCP_TOKEN at least 32 characters")
    Server(args.port, token, args.bridge_timeout).run()


if __name__ == "__main__":
    main()
