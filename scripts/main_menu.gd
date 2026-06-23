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
const DESIGN_SIZE := Vector2(1280.0, 720.0)

var status_label: Label
var steam_status_label: Label
var buttons: Dictionary = {}
var settings_panel: Control
var lobby_panel: Control
var lobby_setup_section: Control
var lobby_loading_section: Control
var lobby_failure_section: Control
var lobby_room_section: Control
var lobby_view_state: String = "setup"
var lobby_code_input: LineEdit
var steam_account_label: Label
var lobby_id_label: Label
var lobby_status_label: Label
var lobby_title_label: Label
var lobby_subtitle_label: Label
var lobby_mode_label: Label
var lobby_connect_button: Button
var lobby_host_button: Button
var lobby_find_button: Button
var lobby_join_button: Button
var lobby_invite_button: Button
var lobby_room_code_label: Label
var lobby_room_status_label: Label
var lobby_loading_status_label: Label
var lobby_failure_status_label: Label
var lobby_local_name_label: Label
var lobby_local_meta_label: Label
var lobby_local_ready_label: Label
var lobby_peer_name_label: Label
var lobby_peer_meta_label: Label
var lobby_peer_ready_label: Label
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
	size = DESIGN_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_update_screen_layout)
	_update_screen_layout()
	_create_background()
	_create_title()
	_create_buttons()
	_create_status_labels()


func _update_screen_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var ui_scale := minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	scale = Vector2(ui_scale, ui_scale)
	position = (viewport_size - DESIGN_SIZE * ui_scale) * 0.5


func set_status_text(text: String) -> void:
	if steam_status_label == null:
		return
	steam_status_label.text = text
	if steam_account_label != null:
		steam_account_label.text = text
	if lobby_status_label != null:
		lobby_status_label.text = text
	if lobby_room_status_label != null:
		lobby_room_status_label.text = text
	if lobby_loading_status_label != null:
		lobby_loading_status_label.text = text
	if lobby_failure_status_label != null:
		lobby_failure_status_label.text = text


func set_lobby_state(lobby_state: Dictionary) -> void:
	if ready_button == null:
		return

	var online := bool(lobby_state.get("online", false))
	var lobby_id := int(lobby_state.get("lobby_id", 0))
	var match_active := bool(lobby_state.get("match_active", false))
	var local_ready := bool(lobby_state.get("local_ready", false))
	var peer_ready := bool(lobby_state.get("peer_ready", false))
	var network_mode := int(lobby_state.get("mode", 0))
	var status_text := str(lobby_state.get("status", ""))
	var local_name := str(lobby_state.get("local_name", "You"))
	var local_steam_id := int(lobby_state.get("local_steam_id", 0))
	var peer_name := str(lobby_state.get("peer_name", ""))
	var peer_steam_id := int(lobby_state.get("peer_steam_id", 0))
	var steam_connected := local_steam_id != 0

	if online:
		if lobby_id > 0:
			lobby_view_state = "room"
		elif lobby_view_state != "loading":
			lobby_view_state = "loading"
	elif lobby_view_state != "failure":
		lobby_view_state = "setup"
	_sync_lobby_sections()

	if lobby_title_label != null:
		lobby_title_label.text = "Steam 로비"
	if lobby_subtitle_label != null:
		if online:
			lobby_subtitle_label.text = "대기실에서 플레이어 상태를 확인합니다."
		else:
			lobby_subtitle_label.text = "친구와 1v1 매치를 준비합니다."
	if lobby_mode_label != null:
		if online:
			lobby_mode_label.text = "HOST" if network_mode == 1 else "CLIENT"
		else:
			lobby_mode_label.text = "OFFLINE"

	if lobby_connect_button != null:
		lobby_connect_button.text = "Steam 재확인" if steam_connected else "Steam 연결"
	if lobby_host_button != null:
		lobby_host_button.disabled = online
	if lobby_find_button != null:
		lobby_find_button.disabled = online
	if lobby_join_button != null:
		lobby_join_button.disabled = online

	if lobby_id > 0:
		lobby_id_label.text = "Lobby ID: %d" % lobby_id
	else:
		lobby_id_label.text = "Lobby ID: -"

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

	if lobby_room_code_label != null:
		if lobby_id > 0:
			lobby_room_code_label.text = "로비 코드\n%d" % lobby_id
		elif online:
			if network_mode == 1:
				lobby_room_code_label.text = "로비 생성 중\nSteam 응답 대기"
			else:
				lobby_room_code_label.text = "로비 참가 중\nSteam 응답 대기"
		else:
			lobby_room_code_label.text = "로비 코드\n-"

	if lobby_local_name_label != null:
		lobby_local_name_label.text = local_name
	if lobby_local_meta_label != null:
		if local_steam_id != 0:
			lobby_local_meta_label.text = "Steam ID %d" % local_steam_id
		else:
			lobby_local_meta_label.text = "Steam 계정 확인 필요"
	if lobby_local_ready_label != null:
		if match_active:
			lobby_local_ready_label.text = "게임 시작됨"
		elif local_ready:
			lobby_local_ready_label.text = "준비 완료"
		elif online:
			lobby_local_ready_label.text = "준비 전"
		else:
			lobby_local_ready_label.text = "대기"

	if lobby_peer_name_label != null:
		if peer_steam_id != 0:
			lobby_peer_name_label.text = peer_name
		else:
			lobby_peer_name_label.text = "빈 슬롯"
	if lobby_peer_meta_label != null:
		if peer_steam_id != 0:
			lobby_peer_meta_label.text = "Steam ID %d" % peer_steam_id
		elif lobby_id > 0:
			lobby_peer_meta_label.text = "친구 대기"
		else:
			lobby_peer_meta_label.text = "초대 가능"
	if lobby_peer_ready_label != null:
		if peer_steam_id == 0:
			lobby_peer_ready_label.text = "친구 대기"
		elif peer_ready:
			lobby_peer_ready_label.text = "준비 완료"
		else:
			lobby_peer_ready_label.text = "준비 전"

	ready_button.text = "준비 취소" if local_ready else "준비 완료"
	ready_button.disabled = not online or match_active or lobby_id <= 0
	copy_lobby_button.disabled = lobby_id <= 0
	if lobby_invite_button != null:
		lobby_invite_button.disabled = lobby_id <= 0
	leave_lobby_button.disabled = not online

	if lobby_status_label != null:
		lobby_status_label.text = status_text
	if lobby_room_status_label != null:
		lobby_room_status_label.text = status_text


func open_lobby_panel() -> void:
	if lobby_view_state == "":
		lobby_view_state = "setup"
	_show_lobby_panel()


func show_lobby_loading(text: String) -> void:
	lobby_view_state = "loading"
	_set_lobby_feedback(text)
	_show_lobby_panel()


func show_lobby_failure(text: String) -> void:
	lobby_view_state = "failure"
	_set_lobby_feedback(text)
	_show_lobby_panel()


func show_lobby_setup() -> void:
	lobby_view_state = "setup"
	_sync_lobby_sections()


func _sync_lobby_sections() -> void:
	if lobby_setup_section != null:
		lobby_setup_section.visible = lobby_view_state == "setup"
	if lobby_loading_section != null:
		lobby_loading_section.visible = lobby_view_state == "loading"
	if lobby_failure_section != null:
		lobby_failure_section.visible = lobby_view_state == "failure"
	if lobby_room_section != null:
		lobby_room_section.visible = lobby_view_state == "room"


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
		["local", "로컬 1v1"],
		["lobby", "Steam 로비"],
		["settings", "설정"],
		["quit", "종료"],
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
	lobby_panel.position = Vector2.ZERO
	lobby_panel.size = Vector2(1280.0, 720.0)
	lobby_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby_panel.visible = false
	add_child(lobby_panel)

	var background := ColorRect.new()
	background.position = Vector2.ZERO
	background.size = lobby_panel.size
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.055, 0.060, 0.070)
	lobby_panel.add_child(background)

	var header_band := ColorRect.new()
	header_band.position = Vector2.ZERO
	header_band.size = Vector2(1280.0, 118.0)
	header_band.color = Color(0.080, 0.095, 0.110)
	lobby_panel.add_child(header_band)

	lobby_title_label = _make_settings_label(Vector2(88.0, 34.0), Vector2(420.0, 48.0), "Steam 로비", 34)
	lobby_title_label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	lobby_panel.add_child(lobby_title_label)

	lobby_subtitle_label = _make_settings_label(
		Vector2(92.0, 82.0),
		Vector2(760.0, 26.0),
		"친구와 1v1 매치를 준비합니다.",
		15
	)
	lobby_subtitle_label.add_theme_color_override("font_color", Color(0.66, 0.74, 0.80))
	lobby_panel.add_child(lobby_subtitle_label)

	lobby_mode_label = _make_settings_label(Vector2(952.0, 46.0), Vector2(116.0, 30.0), "OFFLINE", 15)
	lobby_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_mode_label.add_theme_color_override("font_color", Color(0.44, 0.86, 0.78))
	lobby_panel.add_child(lobby_mode_label)

	var close_button := _make_panel_button(Vector2(1082.0, 44.0), Vector2(112.0, 34.0), "뒤로")
	close_button.pressed.connect(_hide_lobby_panel)
	lobby_panel.add_child(close_button)

	lobby_setup_section = Control.new()
	lobby_setup_section.position = Vector2(88.0, 152.0)
	lobby_setup_section.size = Vector2(1104.0, 486.0)
	lobby_panel.add_child(lobby_setup_section)

	var setup_left := ColorRect.new()
	setup_left.position = Vector2.ZERO
	setup_left.size = Vector2(640.0, 486.0)
	setup_left.color = Color(0.105, 0.120, 0.130)
	lobby_setup_section.add_child(setup_left)

	var setup_right := ColorRect.new()
	setup_right.position = Vector2(672.0, 0.0)
	setup_right.size = Vector2(432.0, 486.0)
	setup_right.color = Color(0.095, 0.110, 0.125)
	lobby_setup_section.add_child(setup_right)

	var setup_title := _make_settings_label(Vector2(30.0, 24.0), Vector2(560.0, 42.0), "로비 만들기", 26)
	lobby_setup_section.add_child(setup_title)

	steam_account_label = _make_settings_label(Vector2(32.0, 78.0), Vector2(560.0, 70.0), "", 14)
	steam_account_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	steam_account_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	steam_account_label.add_theme_color_override("font_color", Color(0.70, 0.77, 0.83))
	lobby_setup_section.add_child(steam_account_label)

	lobby_connect_button = _make_panel_button(Vector2(32.0, 174.0), Vector2(172.0, 42.0), "Steam 연결")
	lobby_connect_button.pressed.connect(_on_lobby_action_pressed.bind("steam_login"))
	lobby_setup_section.add_child(lobby_connect_button)

	lobby_host_button = _make_panel_button(Vector2(224.0, 174.0), Vector2(172.0, 42.0), "로비 만들기")
	lobby_host_button.pressed.connect(_on_lobby_action_pressed.bind("host"))
	lobby_setup_section.add_child(lobby_host_button)

	lobby_find_button = _make_panel_button(Vector2(416.0, 174.0), Vector2(172.0, 42.0), "공개 로비 찾기")
	lobby_find_button.pressed.connect(_on_lobby_action_pressed.bind("find"))
	lobby_setup_section.add_child(lobby_find_button)

	var code_title := _make_settings_label(Vector2(32.0, 258.0), Vector2(220.0, 26.0), "클립보드로 참가", 17)
	lobby_setup_section.add_child(code_title)

	var code_label := _make_settings_label(Vector2(32.0, 306.0), Vector2(90.0, 32.0), "Lobby ID", 14)
	lobby_setup_section.add_child(code_label)

	lobby_code_input = LineEdit.new()
	lobby_code_input.position = Vector2(128.0, 304.0)
	lobby_code_input.size = Vector2(276.0, 36.0)
	lobby_code_input.placeholder_text = "클립보드에서 로비 ID 가져오기"
	lobby_code_input.editable = false
	lobby_code_input.focus_mode = Control.FOCUS_NONE
	lobby_setup_section.add_child(lobby_code_input)

	var paste_button := _make_panel_button(Vector2(420.0, 304.0), Vector2(92.0, 36.0), "붙여넣기")
	paste_button.pressed.connect(_paste_lobby_code)
	lobby_setup_section.add_child(paste_button)

	lobby_join_button = _make_panel_button(Vector2(528.0, 304.0), Vector2(60.0, 36.0), "참가")
	lobby_join_button.pressed.connect(_join_lobby_from_input)
	lobby_setup_section.add_child(lobby_join_button)

	var setup_note := _make_settings_label(
		Vector2(32.0, 380.0),
		Vector2(560.0, 62.0),
		"1v1 Steam 매치 대기실",
		14
	)
	setup_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setup_note.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	setup_note.add_theme_color_override("font_color", Color(0.70, 0.77, 0.83))
	lobby_setup_section.add_child(setup_note)

	var flow_title := _make_settings_label(Vector2(704.0, 30.0), Vector2(360.0, 36.0), "현재 상태", 22)
	lobby_setup_section.add_child(flow_title)

	var flow_copy := _make_settings_label(
		Vector2(706.0, 84.0),
		Vector2(340.0, 150.0),
		"세션: OFFLINE\n상대 슬롯: 비어 있음\n준비 상태: 대기",
		16
	)
	flow_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flow_copy.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	flow_copy.add_theme_color_override("font_color", Color(0.78, 0.84, 0.88))
	lobby_setup_section.add_child(flow_copy)

	lobby_status_label = _make_settings_label(Vector2(704.0, 286.0), Vector2(340.0, 128.0), "", 14)
	lobby_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_status_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lobby_status_label.add_theme_color_override("font_color", Color(0.72, 0.80, 0.86))
	lobby_setup_section.add_child(lobby_status_label)

	lobby_loading_section = Control.new()
	lobby_loading_section.position = Vector2(88.0, 152.0)
	lobby_loading_section.size = Vector2(1104.0, 486.0)
	lobby_loading_section.visible = false
	lobby_panel.add_child(lobby_loading_section)

	var loading_background := ColorRect.new()
	loading_background.position = Vector2.ZERO
	loading_background.size = lobby_loading_section.size
	loading_background.color = Color(0.095, 0.110, 0.125)
	lobby_loading_section.add_child(loading_background)

	var loading_title := _make_settings_label(Vector2(60.0, 128.0), Vector2(760.0, 48.0), "로비 연결 중", 32)
	loading_title.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	lobby_loading_section.add_child(loading_title)

	var loading_subtitle := _make_settings_label(Vector2(62.0, 188.0), Vector2(760.0, 34.0), "Steam 응답을 기다리는 중입니다.", 17)
	loading_subtitle.add_theme_color_override("font_color", Color(0.66, 0.74, 0.80))
	lobby_loading_section.add_child(loading_subtitle)

	lobby_loading_status_label = _make_settings_label(Vector2(62.0, 254.0), Vector2(940.0, 84.0), "", 15)
	lobby_loading_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_loading_status_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lobby_loading_status_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.88))
	lobby_loading_section.add_child(lobby_loading_status_label)

	var loading_back_button := _make_panel_button(Vector2(62.0, 382.0), Vector2(150.0, 42.0), "취소")
	loading_back_button.pressed.connect(_on_lobby_action_pressed.bind("leave"))
	lobby_loading_section.add_child(loading_back_button)

	lobby_failure_section = Control.new()
	lobby_failure_section.position = Vector2(88.0, 152.0)
	lobby_failure_section.size = Vector2(1104.0, 486.0)
	lobby_failure_section.visible = false
	lobby_panel.add_child(lobby_failure_section)

	var failure_background := ColorRect.new()
	failure_background.position = Vector2.ZERO
	failure_background.size = lobby_failure_section.size
	failure_background.color = Color(0.130, 0.095, 0.095)
	lobby_failure_section.add_child(failure_background)

	var failure_title := _make_settings_label(Vector2(60.0, 118.0), Vector2(760.0, 48.0), "로비 연결 실패", 32)
	failure_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.80))
	lobby_failure_section.add_child(failure_title)

	lobby_failure_status_label = _make_settings_label(Vector2(62.0, 196.0), Vector2(940.0, 104.0), "", 15)
	lobby_failure_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_failure_status_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lobby_failure_status_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.74))
	lobby_failure_section.add_child(lobby_failure_status_label)

	var failure_setup_button := _make_panel_button(Vector2(62.0, 358.0), Vector2(158.0, 42.0), "로비 선택으로")
	failure_setup_button.pressed.connect(show_lobby_setup)
	lobby_failure_section.add_child(failure_setup_button)

	var failure_steam_button := _make_panel_button(Vector2(242.0, 358.0), Vector2(150.0, 42.0), "Steam 재확인")
	failure_steam_button.pressed.connect(_on_lobby_action_pressed.bind("steam_login"))
	lobby_failure_section.add_child(failure_steam_button)

	lobby_room_section = Control.new()
	lobby_room_section.position = Vector2(88.0, 150.0)
	lobby_room_section.size = Vector2(1104.0, 504.0)
	lobby_room_section.visible = false
	lobby_panel.add_child(lobby_room_section)

	var room_code_background := ColorRect.new()
	room_code_background.position = Vector2.ZERO
	room_code_background.size = Vector2(284.0, 78.0)
	room_code_background.color = Color(0.095, 0.130, 0.130)
	lobby_room_section.add_child(room_code_background)

	lobby_room_code_label = _make_settings_label(Vector2(22.0, 12.0), Vector2(240.0, 54.0), "로비 코드\n-", 19)
	lobby_room_code_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lobby_room_section.add_child(lobby_room_code_label)

	var room_status_background := ColorRect.new()
	room_status_background.position = Vector2(316.0, 0.0)
	room_status_background.size = Vector2(788.0, 78.0)
	room_status_background.color = Color(0.095, 0.110, 0.125)
	lobby_room_section.add_child(room_status_background)

	lobby_id_label = _make_settings_label(Vector2(338.0, 12.0), Vector2(744.0, 54.0), "Lobby ID: -", 14)
	lobby_id_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_id_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lobby_id_label.add_theme_color_override("font_color", Color(0.72, 0.80, 0.86))
	lobby_room_section.add_child(lobby_id_label)

	var local_card := ColorRect.new()
	local_card.position = Vector2(0.0, 112.0)
	local_card.size = Vector2(520.0, 188.0)
	local_card.color = Color(0.105, 0.120, 0.130)
	lobby_room_section.add_child(local_card)

	var local_title := _make_settings_label(Vector2(26.0, 132.0), Vector2(220.0, 28.0), "내 슬롯", 16)
	local_title.add_theme_color_override("font_color", Color(0.44, 0.86, 0.78))
	lobby_room_section.add_child(local_title)

	lobby_local_name_label = _make_settings_label(Vector2(26.0, 170.0), Vector2(420.0, 38.0), "Unknown Steam User", 26)
	lobby_room_section.add_child(lobby_local_name_label)

	lobby_local_meta_label = _make_settings_label(Vector2(28.0, 214.0), Vector2(430.0, 24.0), "Steam 계정 확인 필요", 14)
	lobby_local_meta_label.add_theme_color_override("font_color", Color(0.66, 0.74, 0.80))
	lobby_room_section.add_child(lobby_local_meta_label)

	lobby_local_ready_label = _make_settings_label(Vector2(28.0, 252.0), Vector2(220.0, 28.0), "대기", 16)
	lobby_local_ready_label.add_theme_color_override("font_color", Color(0.90, 0.76, 0.36))
	lobby_room_section.add_child(lobby_local_ready_label)

	var peer_card := ColorRect.new()
	peer_card.position = Vector2(584.0, 112.0)
	peer_card.size = Vector2(520.0, 188.0)
	peer_card.color = Color(0.105, 0.120, 0.130)
	lobby_room_section.add_child(peer_card)

	var peer_title := _make_settings_label(Vector2(610.0, 132.0), Vector2(220.0, 28.0), "상대 슬롯", 16)
	peer_title.add_theme_color_override("font_color", Color(0.90, 0.62, 0.44))
	lobby_room_section.add_child(peer_title)

	lobby_peer_name_label = _make_settings_label(Vector2(610.0, 170.0), Vector2(330.0, 38.0), "빈 슬롯", 26)
	lobby_room_section.add_child(lobby_peer_name_label)

	lobby_peer_meta_label = _make_settings_label(Vector2(612.0, 214.0), Vector2(330.0, 24.0), "로비 생성 후 초대 가능", 14)
	lobby_peer_meta_label.add_theme_color_override("font_color", Color(0.66, 0.74, 0.80))
	lobby_room_section.add_child(lobby_peer_meta_label)

	lobby_peer_ready_label = _make_settings_label(Vector2(612.0, 252.0), Vector2(220.0, 28.0), "친구 대기", 16)
	lobby_peer_ready_label.add_theme_color_override("font_color", Color(0.90, 0.76, 0.36))
	lobby_room_section.add_child(lobby_peer_ready_label)

	lobby_invite_button = _make_panel_button(Vector2(986.0, 178.0), Vector2(90.0, 58.0), "+ 초대")
	lobby_invite_button.tooltip_text = "Steam 친구 초대"
	lobby_invite_button.pressed.connect(_on_lobby_action_pressed.bind("invite"))
	lobby_invite_button.disabled = true
	lobby_invite_button.add_theme_font_size_override("font_size", 22)
	lobby_room_section.add_child(lobby_invite_button)

	ready_button = _make_panel_button(Vector2(0.0, 342.0), Vector2(174.0, 42.0), "준비 완료")
	ready_button.pressed.connect(_on_lobby_action_pressed.bind("ready"))
	ready_button.disabled = true
	lobby_room_section.add_child(ready_button)

	copy_lobby_button = _make_panel_button(Vector2(198.0, 342.0), Vector2(150.0, 42.0), "코드 복사")
	copy_lobby_button.pressed.connect(_on_lobby_action_pressed.bind("copy"))
	copy_lobby_button.disabled = true
	lobby_room_section.add_child(copy_lobby_button)

	leave_lobby_button = _make_panel_button(Vector2(372.0, 342.0), Vector2(150.0, 42.0), "로비 나가기")
	leave_lobby_button.pressed.connect(_on_lobby_action_pressed.bind("leave"))
	leave_lobby_button.disabled = true
	lobby_room_section.add_child(leave_lobby_button)

	var back_button := _make_panel_button(Vector2(950.0, 342.0), Vector2(154.0, 42.0), "메인 메뉴")
	back_button.pressed.connect(_hide_lobby_panel)
	lobby_room_section.add_child(back_button)

	var room_message_background := ColorRect.new()
	room_message_background.position = Vector2(0.0, 416.0)
	room_message_background.size = Vector2(1104.0, 78.0)
	room_message_background.color = Color(0.090, 0.104, 0.118)
	lobby_room_section.add_child(room_message_background)

	lobby_room_status_label = _make_settings_label(Vector2(22.0, 426.0), Vector2(1060.0, 56.0), "", 14)
	lobby_room_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_room_status_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lobby_room_status_label.add_theme_color_override("font_color", Color(0.72, 0.80, 0.86))
	lobby_room_section.add_child(lobby_room_status_label)


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
	_sync_lobby_sections()
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


func _set_lobby_feedback(text: String) -> void:
	if lobby_status_label != null:
		lobby_status_label.text = text
	if lobby_room_status_label != null:
		lobby_room_status_label.text = text


func _paste_lobby_code() -> void:
	lobby_code_input.text = DisplayServer.clipboard_get().strip_edges()
	if lobby_code_input.text.is_valid_int():
		_set_lobby_feedback("클립보드에서 로비 ID를 가져왔습니다.")
	else:
		_set_lobby_feedback("클립보드에 숫자 로비 ID가 없습니다.")


func _join_lobby_from_input() -> void:
	var lobby_text := lobby_code_input.text.strip_edges()
	if not lobby_text.is_valid_int():
		_set_lobby_feedback("클립보드에서 숫자 로비 ID를 먼저 가져와 주세요.")
		return

	var lobby_id := int(lobby_text)
	if lobby_id <= 0:
		_set_lobby_feedback("로비 ID는 0보다 커야 합니다.")
		return

	lobby_join_requested.emit(lobby_id)


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
