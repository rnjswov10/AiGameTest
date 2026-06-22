extends Node2D

const SETTINGS_PATH := "user://settings.cfg"

var match_controller: MatchController
var board_view: BoardView
var steam_network: SteamNetwork
var main_menu: MainMenu
var game_started: bool = false
var current_settings: Dictionary = {}


func _ready() -> void:
	current_settings = _load_user_settings()
	_apply_user_settings(current_settings)

	match_controller = MatchController.new()
	add_child(match_controller)
	match_controller.reset_to_menu()

	steam_network = SteamNetwork.new()
	add_child(steam_network)
	steam_network.set_match_controller(match_controller)
	steam_network.remote_command_received.connect(_on_remote_command_received)
	steam_network.snapshot_received.connect(_on_snapshot_received)
	steam_network.status_changed.connect(_on_steam_status_changed)
	steam_network.online_match_started.connect(_on_online_match_started)

	board_view = BoardView.new()
	add_child(board_view)
	board_view.set_match_controller(match_controller)
	board_view.player_action_requested.connect(_on_player_action_button_requested)
	board_view.network_action_requested.connect(_on_network_button_requested)
	board_view.visible = false

	main_menu = MainMenu.new()
	add_child(main_menu)
	main_menu.action_requested.connect(_on_main_menu_action_requested)
	main_menu.lobby_join_requested.connect(_on_main_menu_lobby_join_requested)
	main_menu.settings_changed.connect(_on_menu_settings_changed)
	main_menu.set_settings(current_settings)
	main_menu.set_status_text(steam_network.get_status_text())


func _process(_delta: float) -> void:
	if steam_network == null:
		return
	match_controller.set_network_view(
		steam_network.get_mode_name(),
		steam_network.local_player_id,
		steam_network.get_status_text()
	)
	if main_menu != null and main_menu.visible:
		main_menu.set_status_text(steam_network.get_status_text())
		main_menu.set_lobby_state(steam_network.get_lobby_snapshot())


func _unhandled_input(event: InputEvent) -> void:
	if main_menu != null and main_menu.visible:
		return

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
		"steam_login":
			_refresh_steam_login()
		"host":
			_start_host_match()
		"find":
			_start_find_lobby()
		"join":
			_start_join_lobby()
		"ready":
			_toggle_lobby_ready()
		"copy":
			steam_network.copy_lobby_code()
		"invite":
			steam_network.invite_friends()
		"leave":
			_return_to_menu()
		"restart":
			if steam_network != null and steam_network.is_client():
				return
			var player_id := 0
			if steam_network != null and steam_network.local_player_id >= 0:
				player_id = steam_network.local_player_id
			_submit_command({"action": "restart", "player_id": player_id})
		_:
			return


func _start_local_match() -> void:
	if steam_network != null and steam_network.is_online():
		steam_network.leave_lobby()
	match_controller.start_match()
	match_controller.set_network_view("Local", -1, steam_network.get_status_text())
	_show_game()


func _refresh_steam_login() -> void:
	if steam_network == null:
		return
	steam_network.refresh_account()
	if main_menu != null:
		main_menu.set_status_text(steam_network.get_status_text())


func _start_host_match() -> void:
	if steam_network == null:
		return
	if steam_network.host_match():
		match_controller.reset_to_menu()
		_show_lobby_waiting("Creating Steam lobby...")
	else:
		_show_menu("Steam host failed.")


func _start_find_lobby() -> void:
	if steam_network == null:
		return
	if steam_network.find_public_lobby():
		match_controller.reset_to_menu()
		_show_lobby_waiting("Searching Steam lobbies...")
	else:
		_show_menu("Steam lobby search failed.")


func _start_join_lobby() -> void:
	if steam_network == null:
		return
	if steam_network.join_lobby_from_clipboard():
		match_controller.reset_to_menu()
		_show_lobby_waiting("Joining Steam lobby...")
	else:
		_show_menu("Steam lobby join failed.")


func _start_join_lobby_by_id(lobby_id: int) -> void:
	if steam_network == null:
		return
	if steam_network.join_lobby(lobby_id):
		match_controller.reset_to_menu()
		_show_lobby_waiting("Joining Steam lobby...")
	else:
		_show_menu("Steam lobby join failed.")


func _toggle_lobby_ready() -> void:
	if steam_network == null:
		return
	steam_network.toggle_local_ready()
	if main_menu != null:
		main_menu.set_status_text(steam_network.get_status_text())
		main_menu.set_lobby_state(steam_network.get_lobby_snapshot())


func _show_game() -> void:
	game_started = true
	board_view.visible = true
	main_menu.visible = false


func _show_lobby_waiting(status_text: String) -> void:
	game_started = false
	board_view.visible = false
	main_menu.visible = true
	main_menu.set_menu_status(status_text)
	main_menu.set_status_text(steam_network.get_status_text())
	main_menu.set_lobby_state(steam_network.get_lobby_snapshot())
	main_menu.open_lobby_panel()


func _show_menu(status_text: String = "Select a mode to start.") -> void:
	game_started = false
	board_view.visible = false
	main_menu.visible = true
	main_menu.set_menu_status(status_text)
	main_menu.set_status_text(steam_network.get_status_text())


func _return_to_menu() -> void:
	if steam_network != null and steam_network.is_online():
		steam_network.leave_lobby()
	match_controller.reset_to_menu()
	_show_menu()


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


func _on_main_menu_action_requested(action_name: String) -> void:
	match action_name:
		"local":
			_start_local_match()
		"steam_login":
			_refresh_steam_login()
		"host":
			_start_host_match()
		"find":
			_start_find_lobby()
		"join":
			_start_join_lobby()
		"ready":
			_toggle_lobby_ready()
		"copy":
			steam_network.copy_lobby_code()
		"invite":
			steam_network.invite_friends()
		"leave":
			_return_to_menu()
		"quit":
			get_tree().quit()
		_:
			return


func _on_main_menu_lobby_join_requested(lobby_id: int) -> void:
	_start_join_lobby_by_id(lobby_id)


func _on_steam_status_changed(status_text: String) -> void:
	if main_menu != null and main_menu.visible:
		main_menu.set_status_text(status_text)
		main_menu.set_lobby_state(steam_network.get_lobby_snapshot())


func _on_online_match_started() -> void:
	_show_game()


func _on_menu_settings_changed(settings: Dictionary) -> void:
	current_settings = settings.duplicate()
	_apply_user_settings(current_settings)
	_save_user_settings(current_settings)


func _get_default_settings() -> Dictionary:
	return {
		"fullscreen": false,
		"borderless": false,
		"resolution_width": 1280,
		"resolution_height": 720,
		"vsync": true,
		"master_volume": 80.0,
	}


func _load_user_settings() -> Dictionary:
	var settings := _get_default_settings()
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)
	if error != OK:
		return settings

	settings["fullscreen"] = bool(config.get_value("display", "fullscreen", settings["fullscreen"]))
	settings["borderless"] = bool(config.get_value("display", "borderless", settings["borderless"]))
	settings["resolution_width"] = int(config.get_value("display", "resolution_width", settings["resolution_width"]))
	settings["resolution_height"] = int(config.get_value("display", "resolution_height", settings["resolution_height"]))
	settings["vsync"] = bool(config.get_value("display", "vsync", settings["vsync"]))
	settings["master_volume"] = float(config.get_value("audio", "master_volume", settings["master_volume"]))
	return settings


func _save_user_settings(settings: Dictionary) -> void:
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", bool(settings.get("fullscreen", false)))
	config.set_value("display", "borderless", bool(settings.get("borderless", false)))
	config.set_value("display", "resolution_width", int(settings.get("resolution_width", 1280)))
	config.set_value("display", "resolution_height", int(settings.get("resolution_height", 720)))
	config.set_value("display", "vsync", bool(settings.get("vsync", true)))
	config.set_value("audio", "master_volume", float(settings.get("master_volume", 80.0)))
	config.save(SETTINGS_PATH)


func _apply_user_settings(settings: Dictionary) -> void:
	var fullscreen := bool(settings.get("fullscreen", false))
	var borderless := bool(settings.get("borderless", false))
	var resolution := Vector2i(
		int(settings.get("resolution_width", 1280)),
		int(settings.get("resolution_height", 720))
	)

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, borderless)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolution)
		_center_window(resolution)

	var vsync_mode := DisplayServer.VSYNC_ENABLED
	if not bool(settings.get("vsync", true)):
		vsync_mode = DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)

	var volume := clampf(float(settings.get("master_volume", 80.0)), 0.0, 100.0)
	AudioServer.set_bus_mute(0, volume <= 0.0)
	if volume > 0.0:
		AudioServer.set_bus_volume_db(0, linear_to_db(volume / 100.0))


func _center_window(window_size: Vector2i) -> void:
	var screen_size := DisplayServer.screen_get_size()
	var window_position := Vector2i(
		maxi(0, int((screen_size.x - window_size.x) / 2)),
		maxi(0, int((screen_size.y - window_size.y) / 2))
	)
	DisplayServer.window_set_position(window_position)
