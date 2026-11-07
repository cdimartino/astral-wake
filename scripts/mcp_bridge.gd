extends Node

const LIMIT := 1048576
var controller
var server := TCPServer.new()
var clients: Array = []
var token := ""
var last_revision := -1
var active_port := 0
var session_only := true
var last_error := ""

func _ready() -> void:
	var port := OS.get_environment("ASTRAL_MCP_PORT")
	token = OS.get_environment("ASTRAL_MCP_TOKEN")
	if port.is_valid_int() and int(port) >= 1 and int(port) <= 65535 and token.length() >= 32:
		enable(int(port), token)
	else:
		set_process(false)
		var settings: Dictionary = controller.main.game.profile.get("settings", {})
		if settings.get("mcp_enabled", false) is bool and settings.get("mcp_enabled", false):
			var saved_port = settings.get("mcp_port", 0)
			if not (saved_port is int or saved_port is float) or not is_finite(float(saved_port)) or saved_port != floor(saved_port) or saved_port < 0 or saved_port > 65535:
				last_error = "Invalid saved port; choose a port in Settings"
				session_only = false
			else: enable_saved(int(saved_port))

# Low-level nonpersisting entry point used by automation and focused tests.
func enable(port: int = 0, credential: String = "") -> Dictionary:
	disable()
	token = credential if credential.length() >= 32 else Crypto.new().generate_random_bytes(32).hex_encode()
	if port < 0 or port > 65535:
		last_error = "Invalid port"
		return {"ok":false, "error":last_error}
	var status := server.listen(port, "127.0.0.1")
	if status != OK:
		token = ""
		last_error = "Loopback port unavailable"
		return {"ok":false, "error":last_error}
	active_port = server.get_local_port()
	set_process(true)
	return {"ok":true, "connection":connection_info()}

func enable_saved(port: int = 0) -> Dictionary:
	var settings: Dictionary = controller.main.game.profile.get("settings", {})
	var saved_token = settings.get("mcp_token", "")
	var credential: String = saved_token if saved_token is String else ""
	if credential.length() < 32 or credential.length() > 4096: credential = Crypto.new().generate_random_bytes(32).hex_encode()
	var result := enable(port, credential)
	session_only = false
	controller.main.game.set_mcp_settings(true, active_port if result.ok else port, credential)
	if result.ok: result["connection"] = connection_info()
	return result

func disable_saved() -> void:
	var settings: Dictionary = controller.main.game.profile.get("settings", {})
	var credential = settings.get("mcp_token", "")
	if not credential is String or credential.length() < 32 or credential.length() > 4096: credential = Crypto.new().generate_random_bytes(32).hex_encode()
	var port = settings.get("mcp_port", 0)
	if not (port is int or port is float) or not is_finite(float(port)) or port < 0 or port > 65535: port = 0
	disable()
	controller.main.game.set_mcp_settings(false, int(port), credential)
	session_only = false

func disable() -> void:
	server.stop()
	for client in clients: client.peer.disconnect_from_host()
	clients.clear()
	active_port = 0
	token = ""
	last_revision = -1
	last_error = ""
	session_only = true
	set_process(false)

func connection_info() -> Dictionary:
	return {"enabled":server.is_listening(), "host":"127.0.0.1", "port":active_port, "token":token, "session_only":session_only, "error":last_error}

func _exit_tree() -> void:
	disable()

func _process(_delta: float) -> void:
	# Fixed connection, byte and request budgets; slow readers are disconnected.
	if server.is_connection_available():
		var peer := server.take_connection()
		if clients.size() >= 4: peer.disconnect_from_host()
		else: clients.append({"peer":peer, "input":PackedByteArray(), "output":PackedByteArray(), "cache":{}, "order":[], "authenticated":false})
	var budget := 8
	for client in clients.duplicate():
		var peer: StreamPeerTCP = client.peer
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			clients.erase(client)
			continue
		var available := mini(65536, peer.get_available_bytes())
		if available > 0:
			var data := peer.get_data(available)
			if data[0] != OK:
				_drop(client)
				continue
			client.input.append_array(data[1])
		if client.input.size() > LIMIT:
			_drop(client)
			continue
		while budget > 0:
			var newline: int = client.input.find(10)
			if newline < 0: break
			var line: PackedByteArray = client.input.slice(0, newline)
			client.input = client.input.slice(newline + 1)
			budget -= 1
			var text := line.get_string_from_utf8()
			if text.to_utf8_buffer() != line:
				_queue(client, _failure(null, "invalid_request", "Expected UTF-8"))
			else: _handle(client, text)
		if client.output.size() > LIMIT * 2:
			_drop(client)
			continue
		if not client.output.is_empty():
			var sent := peer.put_partial_data(client.output.slice(0, 65536))
			if sent[0] != OK: _drop(client)
			else: client.output = client.output.slice(sent[1])
	var state: Dictionary = controller.snapshot()
	if state.revision != last_revision:
		last_revision = state.revision
		for client in clients:
			if client.authenticated: _queue(client, {"event":"state_changed", "state":state})

func _drop(client: Dictionary) -> void:
	client.peer.disconnect_from_host()
	clients.erase(client)

func _queue(client: Dictionary, message: Dictionary) -> void:
	client.output.append_array((JSON.stringify(message) + "\n").to_utf8_buffer())

func _failure(id, code: String, message: String) -> Dictionary:
	return {"id":id, "ok":false, "error":{"code":code, "message":message}}

func _handle(client: Dictionary, line: String) -> void:
	var parser := JSON.new()
	if parser.parse(line) != OK or not parser.data is Dictionary:
		_queue(client, _failure(null, "invalid_request", "Expected JSON object"))
		return
	var request: Dictionary = parser.data
	var id = request.get("id")
	if not request.get("token") is String or request.token != token:
		_queue(client, _failure(id if id is String else null, "unauthorized", "Authentication required"))
		return
	client.authenticated = true
	if not id is String or id.is_empty() or id.length() > 256 or request.size() != 4 or not request.get("method") is String or not request.get("params") is Dictionary:
		_queue(client, _failure(id if id is String else null, "invalid_request", "Expected id, token, method and params"))
		return
	if client.cache.has(id):
		var cached: Dictionary = client.cache[id]
		_queue(client, cached.response if cached.request == request else _failure(id, "duplicate_id", "ID already used for different request"))
		return
	var response: Dictionary = controller.request(request.method, request.params)
	response["id"] = id
	client.cache[id] = {"request":request, "response":response}
	client.order.append(id)
	if client.order.size() > 128: client.cache.erase(client.order.pop_front())
	_queue(client, response)
