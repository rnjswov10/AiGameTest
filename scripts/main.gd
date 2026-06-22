extends Node2D

var match_controller: MatchController
var board_view: BoardView
var steam_network: SteamNetwork


func _ready() -> void:
	match_controller = MatchController.new()
	add_child(match_controller)
	match_controller.start_match()

	steam_network = SteamNetwork.new()
	add_child(steam_network)
	steam_network.set_match_controller(match_controller)
	steam_network.remote_command_received.connect(_on_remote_command_received)
	steam_network.snapshot_received.connect(_on_snapshot_received)

	board_view = BoardView.new()
	add_child(board_view)
	board_view.set_match_controller(match_controller)
	board_view.player_action_requested.connect(_on_player_action_button_requested)
	board_view.network_action_requested.connect(_on_network_button_requested)


func _process(_delta: float) -> void:
	if steam_network == null:
		return
	match_controller.set_network_view(
		steam_network.get_mode_name(),
		steam_network.local_player_id,
		steam_network.get_status_text()
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_input(event)
		return

	if event is InputEventKey:
		_handle_key_input(event)


func _handle_mouse_input(event: InputEventMouseButton) -> void:
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return

	var relic_action := board_view.get_relic_action_at_position(event.position)
	if not relic_action.is_empty():
		var action_name: String = relic_action["action"]
		var player_id: int = relic_action["player_id"]
		if not _can_control_player(player_id):
			return

		if action_name == "choose":
			_submit_command({
				"action": "choose_relic",
				"player_id": player_id,
				"index": relic_action["index"],
			})
		elif action_name == "reroll":
			_submit_command({
				"action": "reroll_relics",
				"player_id": player_id,
			})
		get_viewport().set_input_as_handled()
		return

	var hit_result := board_view.get_cell_at_position(event.position)
	if hit_result.is_empty():
		return

	var player_id: int = hit_result[0]
	var cell: Vector2i = hit_result[1]
	if not _can_control_player(player_id):
		return

	_submit_command({
		"action": "select_cell",
		"player_id": player_id,
		"x": cell.x,
		"y": cell.y,
	})
	get_viewport().set_input_as_handled()


func _handle_key_input(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return

	if _handle_network_key_input(event.keycode):
		get_viewport().set_input_as_handled()
		return

	if steam_network != null and steam_network.is_online():
		_handle_online_key_input(event.keycode)
		get_viewport().set_input_as_handled()
		return

	match event.keycode:
		KEY_Q:
			_submit_command({"action": "summon", "player_id": 0})
		KEY_W:
			_submit_command({"action": "merge", "player_id": 0})
		KEY_E:
			_submit_command({"action": "attack", "player_id": 0})
		KEY_A:
			_submit_command({"action": "boss", "player_id": 0})
		KEY_I:
			_submit_command({"action": "summon", "player_id": 1})
		KEY_O:
			_submit_command({"action": "merge", "player_id": 1})
		KEY_P:
			_submit_command({"action": "attack", "player_id": 1})
		KEY_J:
			_submit_command({"action": "boss", "player_id": 1})
		KEY_R:
			_submit_command({"action": "restart", "player_id": 0})
		_:
			return

	get_viewport().set_input_as_handled()


func _handle_network_key_input(keycode: int) -> bool:
	match keycode:
		KEY_H:
			_run_network_action("host")
		KEY_L:
			_run_network_action("find")
		KEY_V:
			_run_network_action("join")
		KEY_C:
			_run_network_action("copy")
		KEY_ESCAPE:
			_run_network_action("leave")
		_:
			return false

	return true


func _handle_online_key_input(keycode: int) -> void:
	var player_id := steam_network.local_player_id
	if player_id < 0:
		return

	match keycode:
		KEY_Q:
			_submit_command({"action": "summon", "player_id": player_id})
		KEY_W:
			_submit_command({"action": "merge", "player_id": player_id})
		KEY_E:
			_submit_command({"action": "attack", "player_id": player_id})
		KEY_A:
			_submit_command({"action": "boss", "player_id": player_id})
		KEY_R:
			_run_network_action("restart")
		_:
			return


func _run_network_action(action_name: String) -> void:
	match action_name:
		"host":
			match_controller.start_match()
			steam_network.host_match()
		"find":
			steam_network.find_public_lobby()
		"join":
			steam_network.join_lobby_from_clipboard()
		"copy":
			steam_network.copy_lobby_code()
		"leave":
			steam_network.leave_lobby()
			match_controller.start_match()
		"restart":
			if steam_network != null and steam_network.is_client():
				return
			var player_id := 0
			if steam_network != null and steam_network.local_player_id >= 0:
				player_id = steam_network.local_player_id
			_submit_command({"action": "restart", "player_id": player_id})
		_:
			return


func _can_control_player(player_id: int) -> bool:
	if steam_network == null or not steam_network.is_online():
		return true
	return player_id == steam_network.local_player_id


func _submit_command(command: Dictionary) -> void:
	if steam_network != null and steam_network.is_client():
		steam_network.send_local_command(command)
		return

	match_controller.apply_player_command(command)

	if steam_network != null and steam_network.is_host():
		steam_network.send_snapshot_now()


func _on_remote_command_received(command: Dictionary) -> void:
	if steam_network == null or not steam_network.is_host():
		return

	match_controller.apply_player_command(command)
	steam_network.send_snapshot_now()


func _on_snapshot_received(snapshot: Dictionary) -> void:
	match_controller.apply_network_snapshot(snapshot)


func _on_player_action_button_requested(action_name: String, player_id: int) -> void:
	if not _can_control_player(player_id):
		return
	_submit_command({
		"action": action_name,
		"player_id": player_id,
	})


func _on_network_button_requested(action_name: String) -> void:
	_run_network_action(action_name)
