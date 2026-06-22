class_name SteamNetwork
extends Node

signal remote_command_received(command: Dictionary)
signal snapshot_received(snapshot: Dictionary)
signal status_changed(status_text: String)

enum NetworkMode {
	OFFLINE,
	HOST,
	CLIENT,
}

const PROTOCOL_VERSION := 1
const GAME_TAG := "AiGameTest"
const MAX_LOBBY_MEMBERS := 2
const LOBBY_TYPE_PUBLIC := 2
const P2P_SEND_RELIABLE := 2
const P2P_CHANNEL := 0
const SNAPSHOT_INTERVAL := 0.12

var steam: Object = null
var steam_ready: bool = false
var steam_logged_on: bool = false
var mode: int = NetworkMode.OFFLINE
var local_player_id: int = -1
var current_lobby_id: int = 0
var own_steam_id: int = 0
var persona_name: String = ""
var peer_steam_id: int = 0
var status_text: String = "Steam unavailable"
var match_controller: MatchController = null
var snapshot_timer: float = 0.0


func _ready() -> void:
	initialize()


func _process(delta: float) -> void:
	if not steam_ready:
		return

	_run_steam_callbacks()
	_read_packets()

	if mode == NetworkMode.HOST and peer_steam_id != 0 and match_controller != null:
		snapshot_timer -= delta
		if snapshot_timer <= 0.0:
			send_snapshot_now()
			snapshot_timer = SNAPSHOT_INTERVAL


func set_match_controller(controller: MatchController) -> void:
	match_controller = controller


func initialize() -> bool:
	if steam_ready:
		return refresh_account()

	if not Engine.has_singleton("Steam"):
		_set_status("Steam plugin not loaded. Local mode only.")
		return false

	steam = Engine.get_singleton("Steam")
	if steam == null:
		_set_status("Steam singleton missing. Local mode only.")
		return false

	if steam.has_method("steamInitEx"):
		var response: Variant = steam.call("steamInitEx")
		if response is Dictionary:
			if int(response.get("status", 1)) != 0:
				_set_status("Steam init failed: %s" % str(response))
				return false
	else:
		_set_status("Steam plugin has no steamInitEx method.")
		return false

	steam_ready = true
	_connect_steam_signals()
	return refresh_account()


func refresh_account() -> bool:
	if steam == null and not initialize():
		return false

	own_steam_id = _get_own_steam_id()
	persona_name = _get_persona_name()
	steam_logged_on = _is_logged_on()

	if not steam_logged_on:
		_set_status("Steam plugin loaded, but Steam is not logged in. Open Steam, log in, then click Connect Steam.")
		return false

	_set_status("Steam connected as %s\nSteam ID: %d\nUse Lobby to host, find, or join by id." % [
		_get_account_display_name(),
		own_steam_id,
	])
	return true


func is_online() -> bool:
	return mode == NetworkMode.HOST or mode == NetworkMode.CLIENT


func is_host() -> bool:
	return mode == NetworkMode.HOST


func is_client() -> bool:
	return mode == NetworkMode.CLIENT


func host_match() -> bool:
	if not _require_steam_session():
		return false

	mode = NetworkMode.HOST
	local_player_id = 0
	peer_steam_id = 0
	current_lobby_id = 0
	_set_status("Creating Steam lobby...")
	steam.call("createLobby", LOBBY_TYPE_PUBLIC, MAX_LOBBY_MEMBERS)
	return true


func find_public_lobby() -> bool:
	if not _require_steam_session():
		return false

	mode = NetworkMode.CLIENT
	local_player_id = 1
	_set_status("Searching Steam lobbies...")
	steam.call("requestLobbyList")
	return true


func join_lobby(lobby_id: int) -> bool:
	if not _require_steam_session():
		return false
	if lobby_id <= 0:
		_set_status("Invalid Steam lobby id.")
		return false

	mode = NetworkMode.CLIENT
	local_player_id = 1
	current_lobby_id = lobby_id
	_set_status("Joining Steam lobby %d..." % lobby_id)
	steam.call("joinLobby", lobby_id)
	return true


func join_lobby_from_clipboard() -> bool:
	var lobby_text := DisplayServer.clipboard_get().strip_edges()
	if not lobby_text.is_valid_int():
		_set_status("Clipboard does not contain a lobby id.")
		return false
	return join_lobby(int(lobby_text))


func copy_lobby_code() -> bool:
	if current_lobby_id <= 0:
		_set_status("No Steam lobby code to copy.")
		return false
	DisplayServer.clipboard_set(str(current_lobby_id))
	_set_status("Copied lobby id %d to clipboard." % current_lobby_id)
	return true


func leave_lobby() -> void:
	if steam_ready and current_lobby_id != 0:
		steam.call("leaveLobby", current_lobby_id)
	if steam_ready and peer_steam_id != 0:
		steam.call("closeP2PSessionWithUser", peer_steam_id)

	mode = NetworkMode.OFFLINE
	local_player_id = -1
	current_lobby_id = 0
	peer_steam_id = 0
	_set_status("Left Steam lobby. Local mode.")


func send_local_command(command: Dictionary) -> bool:
	if mode == NetworkMode.CLIENT:
		return _send_packet_to_peer({
			"type": "command",
			"version": PROTOCOL_VERSION,
			"command": command,
		})

	return false


func send_snapshot_now() -> void:
	if mode != NetworkMode.HOST:
		return
	if peer_steam_id == 0 or match_controller == null:
		return

	_send_packet_to_peer({
		"type": "snapshot",
		"version": PROTOCOL_VERSION,
		"snapshot": match_controller.create_network_snapshot(),
	})


func get_mode_name() -> String:
	match mode:
		NetworkMode.HOST:
			return "Steam Host"
		NetworkMode.CLIENT:
			return "Steam Client"
		_:
			return "Local"


func get_status_text() -> String:
	return status_text


func is_steam_connected() -> bool:
	return steam_ready and steam_logged_on


func get_account_display_name() -> String:
	return _get_account_display_name()


func _require_steam_ready() -> bool:
	if steam_ready:
		return true
	return initialize()


func _require_steam_session() -> bool:
	if not _require_steam_ready():
		return false
	if refresh_account():
		return true

	_set_status("Steam login required. Open Steam, log in, then click Connect Steam.")
	return false


func _connect_steam_signals() -> void:
	_connect_signal_if_available("lobby_created", "_on_lobby_created")
	_connect_signal_if_available("lobby_joined", "_on_lobby_joined")
	_connect_signal_if_available("lobby_match_list", "_on_lobby_match_list")
	_connect_signal_if_available("lobby_chat_update", "_on_lobby_chat_update")
	_connect_signal_if_available("p2p_session_request", "_on_p2p_session_request")
	_connect_signal_if_available("p2p_session_connect_fail", "_on_p2p_session_connect_fail")


func _connect_signal_if_available(signal_name: String, method_name: String) -> void:
	if steam == null:
		return
	if not steam.has_signal(signal_name):
		return

	var callable := Callable(self, method_name)
	if steam.is_connected(signal_name, callable):
		return
	steam.connect(signal_name, callable)


func _run_steam_callbacks() -> void:
	if steam != null and steam.has_method("run_callbacks"):
		steam.call("run_callbacks")


func _read_packets() -> void:
	var packet_size := _get_available_packet_size()
	while packet_size > 0:
		var packet: Variant = steam.call("readP2PPacket", packet_size, P2P_CHANNEL)
		_handle_packet(packet)
		packet_size = _get_available_packet_size()


func _get_available_packet_size() -> int:
	if steam == null or not steam.has_method("getAvailableP2PPacketSize"):
		return 0

	var result: Variant = steam.call("getAvailableP2PPacketSize", P2P_CHANNEL)
	if result is Dictionary:
		return int(result.get("size", 0))
	return int(result)


func _handle_packet(packet: Variant) -> void:
	if not (packet is Dictionary):
		return

	var packet_data: Variant = packet.get("data", PackedByteArray())
	if not (packet_data is PackedByteArray):
		return

	var message: Variant = bytes_to_var(packet_data)
	if not (message is Dictionary):
		return

	var sender_id := _get_packet_sender(packet)
	if sender_id != 0 and peer_steam_id == 0:
		peer_steam_id = sender_id

	var message_type := str(message.get("type", ""))
	match message_type:
		"hello":
			_handle_hello_packet(sender_id)
		"command":
			_handle_command_packet(message)
		"snapshot":
			_handle_snapshot_packet(message)
		_:
			return


func _get_packet_sender(packet: Dictionary) -> int:
	if packet.has("steam_id"):
		return int(packet["steam_id"])
	if packet.has("remote_steam_id"):
		return int(packet["remote_steam_id"])
	return 0


func _handle_hello_packet(sender_id: int) -> void:
	if mode != NetworkMode.HOST:
		return
	if sender_id != 0:
		peer_steam_id = sender_id
	_set_status("Peer connected. Lobby %d." % current_lobby_id)
	send_snapshot_now()


func _handle_command_packet(message: Dictionary) -> void:
	if mode != NetworkMode.HOST:
		return
	var command: Variant = message.get("command", {})
	if command is Dictionary:
		remote_command_received.emit(command)


func _handle_snapshot_packet(message: Dictionary) -> void:
	if mode != NetworkMode.CLIENT:
		return
	var snapshot: Variant = message.get("snapshot", {})
	if snapshot is Dictionary:
		snapshot_received.emit(snapshot)


func _send_packet_to_peer(message: Dictionary) -> bool:
	if not steam_ready or peer_steam_id == 0:
		_set_status("No Steam peer connected.")
		return false

	var payload := var_to_bytes(message)
	steam.call("sendP2PPacket", peer_steam_id, payload, P2P_SEND_RELIABLE, P2P_CHANNEL)
	return true


func _get_own_steam_id() -> int:
	if steam != null and steam.has_method("getSteamID"):
		return int(steam.call("getSteamID"))
	return 0


func _get_persona_name() -> String:
	if steam != null and steam.has_method("getPersonaName"):
		return str(steam.call("getPersonaName"))
	return ""


func _is_logged_on() -> bool:
	if steam != null and steam.has_method("loggedOn"):
		return bool(steam.call("loggedOn"))
	if steam != null and steam.has_method("isLoggedOn"):
		return bool(steam.call("isLoggedOn"))
	return own_steam_id != 0


func _get_account_display_name() -> String:
	if persona_name.strip_edges() != "":
		return persona_name
	if own_steam_id != 0:
		return "Steam User %d" % own_steam_id
	return "Unknown Steam User"


func _set_lobby_data(lobby_id: int) -> void:
	steam.call("setLobbyData", lobby_id, "game", GAME_TAG)
	steam.call("setLobbyData", lobby_id, "protocol", str(PROTOCOL_VERSION))
	steam.call("setLobbyData", lobby_id, "mode", "1v1")
	steam.call("setLobbyData", lobby_id, "host_name", _get_account_display_name())
	steam.call("setLobbyData", lobby_id, "host_id", str(own_steam_id))
	steam.call("setLobbyData", lobby_id, "game_version", "0.1.0")
	if match_controller != null:
		steam.call("setLobbyData", lobby_id, "seed", str(match_controller.match_seed))
	steam.call("setLobbyJoinable", lobby_id, true)


func _get_lobby_owner(lobby_id: int) -> int:
	if steam != null and steam.has_method("getLobbyOwner"):
		return int(steam.call("getLobbyOwner", lobby_id))
	return 0


func _lobby_matches_game(lobby_id: int) -> bool:
	var game_value := str(steam.call("getLobbyData", lobby_id, "game"))
	var protocol_value := str(steam.call("getLobbyData", lobby_id, "protocol"))
	return game_value == GAME_TAG and protocol_value == str(PROTOCOL_VERSION)


func _on_lobby_created(result: int, lobby_id: int) -> void:
	if result != 1:
		mode = NetworkMode.OFFLINE
		local_player_id = -1
		_set_status("Steam lobby creation failed: %d" % result)
		return

	current_lobby_id = lobby_id
	_set_lobby_data(lobby_id)
	DisplayServer.clipboard_set(str(lobby_id))
	_set_status("Hosting lobby %d as %s. Code copied." % [
		lobby_id,
		_get_account_display_name(),
	])


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != 1:
		mode = NetworkMode.OFFLINE
		local_player_id = -1
		_set_status("Steam lobby join failed: %d" % response)
		return

	current_lobby_id = lobby_id
	if mode == NetworkMode.HOST:
		_set_status("Hosting lobby %d as %s." % [
			lobby_id,
			_get_account_display_name(),
		])
		return

	mode = NetworkMode.CLIENT
	local_player_id = 1
	peer_steam_id = _get_lobby_owner(lobby_id)
	var host_name := str(steam.call("getLobbyData", lobby_id, "host_name"))
	if host_name == "":
		host_name = "host"
	_set_status("Joined %s's lobby %d. Waiting for host snapshot." % [
		host_name,
		lobby_id,
	])
	_send_packet_to_peer({
		"type": "hello",
		"version": PROTOCOL_VERSION,
	})


func _on_lobby_match_list(lobbies: Array) -> void:
	if lobbies.is_empty():
		_set_status("No Steam lobbies found.")
		return

	for lobby_id_value in lobbies:
		var lobby_id := int(lobby_id_value)
		if _lobby_matches_game(lobby_id):
			join_lobby(lobby_id)
			return

	_set_status("No AiGameTest lobbies found.")


func _on_lobby_chat_update(
	lobby_id: int,
	changed_id: int,
	_making_change_id: int,
	_chat_state: int
) -> void:
	if lobby_id != current_lobby_id:
		return
	if mode != NetworkMode.HOST:
		return
	if changed_id == own_steam_id:
		return

	peer_steam_id = changed_id
	_set_status("Peer joined lobby %d." % current_lobby_id)
	send_snapshot_now()


func _on_p2p_session_request(remote_steam_id: int) -> void:
	if steam == null:
		return
	steam.call("acceptP2PSessionWithUser", remote_steam_id)
	if peer_steam_id == 0:
		peer_steam_id = remote_steam_id
	_set_status("Accepted Steam P2P session.")


func _on_p2p_session_connect_fail(remote_steam_id: int, session_error: int) -> void:
	_set_status("Steam P2P failed with %d: %d" % [remote_steam_id, session_error])


func _set_status(text: String) -> void:
	status_text = text
	status_changed.emit(status_text)
