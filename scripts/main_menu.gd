class_name MainMenu
extends Control

signal action_requested(action_name: String)
signal settings_changed(settings: Dictionary)
signal lobby_join_requested(lobby_id: int)

const RESOLUTION_OPTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

var status_label: Label
var steam_status_label: Label
var buttons: Dictionary = {}
var settings_panel: Control
var lobby_panel: Control
var lobby_code_input: LineEdit
var steam_account_label: Label
var lobby_id_label: Label
var lobby_status_label: Label
var ready_button: Button
var copy_lobby_button: Button
var leave_lobby_button: Button
var fullscreen_check: CheckButton
var borderless_check: CheckButton
var resolution_option: OptionButton
var vsync_check: CheckButton
var volume_slider: HSlider
var volume_value_label: Label
var current_settings: Dictionary = {}
var applying_settings: bool = false


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(1280.0, 720.0)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_create_background()
	_create_title()
	_create_buttons()
	_create_status_labels()


func set_status_text(text: String) -> void:
	if steam_status_label == null:
		return
	steam_status_label.text = text
	if steam_account_label != null:
		steam_account_label.text = text
	if lobby_status_label != null:
		lobby_status_label.text = text


func set_lobby_state(lobby_state: Dictionary) -> void:
	if ready_button == null:
		return

	var online := bool(lobby_state.get("online", false))
	var lobby_id := int(lobby_state.get("lobby_id", 0))
	var match_active := bool(lobby_state.get("match_active", false))
	var local_ready := bool(lobby_state.get("local_ready", false))

	if lobby_id > 0:
		lobby_id_label.text = "Lobby ID: %d" % lobby_id
	else:
		lobby_id_label.text = "Lobby ID: -"

	var local_name := str(lobby_state.get("local_name", "You"))
	var local_steam_id := int(lobby_state.get("local_steam_id", 0))
	var peer_name := str(lobby_state.get("peer_name", ""))
	var peer_steam_id := int(lobby_state.get("peer_steam_id", 0))
	var opponent_text := "Opponent: Waiting"
	if peer_steam_id != 0:
		if peer_name == "":
			peer_name = "Steam User"
		opponent_text = "Opponent: %s (%d)" % [peer_name, peer_steam_id]

	lobby_id_label.text = "%s\nYou: %s (%d)\n%s" % [
		lobby_id_label.text,
		local_name,
		local_steam_id,
		opponent_text,
	]

	ready_button.text = "Cancel Ready" if local_ready else "Ready"
	ready_button.disabled = not online or match_active
	copy_lobby_button.disabled = lobby_id <= 0
	leave_lobby_button.disabled = not online

	if lobby_status_label != null:
		lobby_status_label.text = str(lobby_state.get("status", ""))


func open_lobby_panel() -> void:
	_show_lobby_panel()


func set_menu_status(text: String) -> void:
	if status_label == null:
		return
	status_label.text = text


func set_settings(settings: Dictionary) -> void:
	current_settings = settings.duplicate()
	if fullscreen_check == null:
		return

	applying_settings = true
	fullscreen_check.button_pressed = bool(current_settings.get("fullscreen", false))
	borderless_check.button_pressed = bool(current_settings.get("borderless", false))
	resolution_option.select(_resolution_index_from_size(_get_resolution()))
	vsync_check.button_pressed = bool(current_settings.get("vsync", true))
	volume_slider.value = float(current_settings.get("master_volume", 80.0))
	_update_volume_label()
	applying_settings = false


func _create_background() -> void:
	var background := ColorRect.new()
	background.position = Vector2.ZERO
	background.size = Vector2(1280.0, 720.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.055, 0.065, 0.085)
	add_child(background)

	var divider := ColorRect.new()
	divider.position = Vector2(0.0, 520.0)
	divider.size = Vector2(1280.0, 2.0)
	divider.color = Color(0.18, 0.21, 0.27)
	add_child(divider)


func _create_title() -> void:
	var title := Label.new()
	title.position = Vector2(110.0, 108.0)
	title.size = Vector2(600.0, 72.0)
	title.text = "AiGameTest"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	add_child(title)

	var subtitle := Label.new()
	subtitle.position = Vector2(114.0, 178.0)
	subtitle.size = Vector2(600.0, 32.0)
	subtitle.text = "1v1 Roguelite Tower Defense"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.66, 0.72, 0.82))
	add_child(subtitle)


func _create_buttons() -> void:
	var button_defs := [
		["local", "Local 1v1"],
		["lobby", "Lobby"],
		["settings", "Settings"],
		["quit", "Quit"],
	]

	for index in range(button_defs.size()):
		var action_name: String = button_defs[index][0]
		var label_text: String = button_defs[index][1]
		var button := Button.new()
		button.position = Vector2(112.0, 258.0 + float(index) * 52.0)
		button.size = Vector2(260.0, 40.0)
		button.text = label_text
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_on_button_pressed.bind(action_name))
		add_child(button)
		buttons[action_name] = button

	_create_lobby_panel()
	_create_settings_panel()


func _create_status_labels() -> void:
	status_label = Label.new()
	status_label.position = Vector2(420.0, 258.0)
	status_label.size = Vector2(650.0, 40.0)
	status_label.text = "Select a mode to start."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(0.86, 0.89, 0.95))
	add_child(status_label)

	steam_status_label = Label.new()
	steam_status_label.position = Vector2(420.0, 312.0)
	steam_status_label.size = Vector2(690.0, 84.0)
	steam_status_label.text = ""
	steam_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	steam_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	steam_status_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	steam_status_label.add_theme_font_size_override("font_size", 14)
	steam_status_label.add_theme_color_override("font_color", Color(0.64, 0.70, 0.80))
	add_child(steam_status_label)


func _create_lobby_panel() -> void:
	lobby_panel = Control.new()
	lobby_panel.position = Vector2(420.0, 182.0)
	lobby_panel.size = Vector2(560.0, 408.0)
	lobby_panel.visible = false
	add_child(lobby_panel)

	var panel_background := ColorRect.new()
	panel_background.position = Vector2.ZERO
	panel_background.size = lobby_panel.size
	panel_background.color = Color(0.10, 0.12, 0.16)
	lobby_panel.add_child(panel_background)

	var title := _make_settings_label(Vector2(18.0, 12.0), Vector2(280.0, 28.0), "Steam Lobby", 20)
	lobby_panel.add_child(title)

	steam_account_label = _make_settings_label(Vector2(18.0, 46.0), Vector2(522.0, 58.0), "", 13)
	steam_account_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	steam_account_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lobby_panel.add_child(steam_account_label)

	var connect_button := _make_panel_button(Vector2(18.0, 116.0), Vector2(158.0, 36.0), "Connect Steam")
	connect_button.pressed.connect(_on_lobby_action_pressed.bind("steam_login"))
	lobby_panel.add_child(connect_button)

	var host_button := _make_panel_button(Vector2(190.0, 116.0), Vector2(158.0, 36.0), "Host Steam")
	host_button.pressed.connect(_on_lobby_action_pressed.bind("host"))
	lobby_panel.add_child(host_button)

	var find_button := _make_panel_button(Vector2(362.0, 116.0), Vector2(158.0, 36.0), "Find Public")
	find_button.pressed.connect(_on_lobby_action_pressed.bind("find"))
	lobby_panel.add_child(find_button)

	var paste_button := _make_panel_button(Vector2(362.0, 170.0), Vector2(158.0, 36.0), "Paste Code")
	paste_button.pressed.connect(_paste_lobby_code)
	lobby_panel.add_child(paste_button)

	var code_label := _make_settings_label(Vector2(18.0, 174.0), Vector2(140.0, 28.0), "Lobby ID", 14)
	lobby_panel.add_child(code_label)

	lobby_code_input = LineEdit.new()
	lobby_code_input.position = Vector2(116.0, 170.0)
	lobby_code_input.size = Vector2(232.0, 34.0)
	lobby_code_input.placeholder_text = "Paste or type Steam lobby id"
	lobby_code_input.focus_mode = Control.FOCUS_ALL
	lobby_code_input.text_submitted.connect(_on_lobby_code_submitted)
	lobby_panel.add_child(lobby_code_input)

	var join_button := _make_panel_button(Vector2(18.0, 222.0), Vector2(158.0, 34.0), "Join")
	join_button.pressed.connect(_join_lobby_from_input)
	lobby_panel.add_child(join_button)

	copy_lobby_button = _make_panel_button(Vector2(190.0, 222.0), Vector2(158.0, 34.0), "Copy Lobby ID")
	copy_lobby_button.pressed.connect(_on_lobby_action_pressed.bind("copy"))
	copy_lobby_button.disabled = true
	lobby_panel.add_child(copy_lobby_button)

	ready_button = _make_panel_button(Vector2(362.0, 222.0), Vector2(158.0, 34.0), "Ready")
	ready_button.pressed.connect(_on_lobby_action_pressed.bind("ready"))
	ready_button.disabled = true
	lobby_panel.add_child(ready_button)

	lobby_id_label = _make_settings_label(Vector2(18.0, 262.0), Vector2(522.0, 56.0), "Lobby ID: -", 13)
	lobby_id_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lobby_panel.add_child(lobby_id_label)

	lobby_status_label = _make_settings_label(Vector2(18.0, 320.0), Vector2(522.0, 28.0), "", 13)
	lobby_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_status_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lobby_panel.add_child(lobby_status_label)

	leave_lobby_button = _make_panel_button(Vector2(18.0, 354.0), Vector2(158.0, 30.0), "Leave Lobby")
	leave_lobby_button.pressed.connect(_on_lobby_action_pressed.bind("leave"))
	leave_lobby_button.disabled = true
	lobby_panel.add_child(leave_lobby_button)

	var back_button := _make_panel_button(Vector2(404.0, 354.0), Vector2(136.0, 30.0), "Back")
	back_button.pressed.connect(_hide_lobby_panel)
	lobby_panel.add_child(back_button)


func _create_settings_panel() -> void:
	settings_panel = Control.new()
	settings_panel.position = Vector2(420.0, 244.0)
	settings_panel.size = Vector2(500.0, 278.0)
	settings_panel.visible = false
	add_child(settings_panel)

	var panel_background := ColorRect.new()
	panel_background.position = Vector2.ZERO
	panel_background.size = settings_panel.size
	panel_background.color = Color(0.10, 0.12, 0.16)
	settings_panel.add_child(panel_background)

	var title := _make_settings_label(Vector2(18.0, 12.0), Vector2(280.0, 28.0), "Settings", 20)
	settings_panel.add_child(title)

	fullscreen_check = _make_check_button(Vector2(18.0, 56.0), "Fullscreen")
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	settings_panel.add_child(fullscreen_check)

	borderless_check = _make_check_button(Vector2(210.0, 56.0), "Borderless")
	borderless_check.toggled.connect(_on_borderless_toggled)
	settings_panel.add_child(borderless_check)

	var resolution_label := _make_settings_label(Vector2(18.0, 108.0), Vector2(140.0, 28.0), "Resolution", 14)
	settings_panel.add_child(resolution_label)

	resolution_option = OptionButton.new()
	resolution_option.position = Vector2(160.0, 104.0)
	resolution_option.size = Vector2(180.0, 34.0)
	resolution_option.focus_mode = Control.FOCUS_NONE
	for resolution in RESOLUTION_OPTIONS:
		resolution_option.add_item("%dx%d" % [resolution.x, resolution.y])
	resolution_option.item_selected.connect(_on_resolution_selected)
	settings_panel.add_child(resolution_option)

	vsync_check = _make_check_button(Vector2(18.0, 154.0), "VSync")
	vsync_check.toggled.connect(_on_vsync_toggled)
	settings_panel.add_child(vsync_check)

	var volume_label := _make_settings_label(Vector2(18.0, 206.0), Vector2(140.0, 28.0), "Master Volume", 14)
	settings_panel.add_child(volume_label)

	volume_slider = HSlider.new()
	volume_slider.position = Vector2(160.0, 208.0)
	volume_slider.size = Vector2(210.0, 24.0)
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.focus_mode = Control.FOCUS_NONE
	volume_slider.value_changed.connect(_on_volume_changed)
	settings_panel.add_child(volume_slider)

	volume_value_label = _make_settings_label(Vector2(382.0, 204.0), Vector2(72.0, 28.0), "", 14)
	settings_panel.add_child(volume_value_label)

	var back_button := Button.new()
	back_button.position = Vector2(334.0, 236.0)
	back_button.size = Vector2(136.0, 30.0)
	back_button.text = "Back"
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.pressed.connect(_hide_settings_panel)
	settings_panel.add_child(back_button)


func _make_settings_label(label_position: Vector2, label_size: Vector2, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.position = label_position
	label.size = label_size
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.88, 0.91, 0.96))
	return label


func _make_check_button(button_position: Vector2, label_text: String) -> CheckButton:
	var button := CheckButton.new()
	button.position = button_position
	button.size = Vector2(170.0, 34.0)
	button.text = label_text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	return button


func _make_panel_button(button_position: Vector2, button_size: Vector2, label_text: String) -> Button:
	var button := Button.new()
	button.position = button_position
	button.size = button_size
	button.text = label_text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	return button


func _show_settings_panel() -> void:
	_hide_lobby_panel()
	settings_panel.visible = true
	status_label.visible = false
	steam_status_label.visible = false


func _hide_settings_panel() -> void:
	settings_panel.visible = false
	status_label.visible = true
	steam_status_label.visible = true


func _show_lobby_panel() -> void:
	_hide_settings_panel()
	lobby_panel.visible = true
	status_label.visible = false
	steam_status_label.visible = false
	steam_account_label.text = steam_status_label.text
	lobby_status_label.text = steam_status_label.text


func _hide_lobby_panel() -> void:
	if lobby_panel == null:
		return
	lobby_panel.visible = false
	status_label.visible = true
	steam_status_label.visible = true


func _on_button_pressed(action_name: String) -> void:
	if action_name == "lobby":
		_show_lobby_panel()
		return
	if action_name == "settings":
		_show_settings_panel()
		return
	action_requested.emit(action_name)


func _on_lobby_action_pressed(action_name: String) -> void:
	action_requested.emit(action_name)


func _paste_lobby_code() -> void:
	lobby_code_input.text = DisplayServer.clipboard_get().strip_edges()


func _join_lobby_from_input() -> void:
	var lobby_text := lobby_code_input.text.strip_edges()
	if not lobby_text.is_valid_int():
		lobby_status_label.text = "Enter a numeric Steam lobby id."
		return

	var lobby_id := int(lobby_text)
	if lobby_id <= 0:
		lobby_status_label.text = "Lobby id must be greater than 0."
		return

	lobby_join_requested.emit(lobby_id)


func _on_lobby_code_submitted(_text: String) -> void:
	_join_lobby_from_input()


func _on_fullscreen_toggled(enabled: bool) -> void:
	_update_setting("fullscreen", enabled)


func _on_borderless_toggled(enabled: bool) -> void:
	_update_setting("borderless", enabled)


func _on_resolution_selected(index: int) -> void:
	if index < 0 or index >= RESOLUTION_OPTIONS.size():
		return
	var resolution: Vector2i = RESOLUTION_OPTIONS[index]
	current_settings["resolution_width"] = resolution.x
	current_settings["resolution_height"] = resolution.y
	_emit_settings_changed()


func _on_vsync_toggled(enabled: bool) -> void:
	_update_setting("vsync", enabled)


func _on_volume_changed(value: float) -> void:
	current_settings["master_volume"] = value
	_update_volume_label()
	_emit_settings_changed()


func _update_setting(key: String, value: Variant) -> void:
	current_settings[key] = value
	_emit_settings_changed()


func _emit_settings_changed() -> void:
	if applying_settings:
		return
	settings_changed.emit(current_settings.duplicate())


func _update_volume_label() -> void:
	if volume_value_label == null:
		return
	volume_value_label.text = "%d%%" % int(round(float(current_settings.get("master_volume", 80.0))))


func _get_resolution() -> Vector2i:
	return Vector2i(
		int(current_settings.get("resolution_width", 1280)),
		int(current_settings.get("resolution_height", 720))
	)


func _resolution_index_from_size(size_value: Vector2i) -> int:
	for index in range(RESOLUTION_OPTIONS.size()):
		if RESOLUTION_OPTIONS[index] == size_value:
			return index
	return 0
