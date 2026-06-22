class_name BoardView
extends Node2D

signal player_action_requested(action_name: String, player_id: int)
signal network_action_requested(action_name: String)

const CELL_SIZE := 52.0
const CELL_GAP := 8.0
const CELL_STEP := CELL_SIZE + CELL_GAP
const BOARD_SIZE := 292.0
const LEFT_GRID_ORIGIN := Vector2(72.0, 160.0)
const RIGHT_GRID_ORIGIN := Vector2(916.0, 160.0)
const LEFT_PATH_X := 430.0
const RIGHT_PATH_X := 850.0
const PATH_TOP := 160.0
const PATH_BOTTOM := 480.0
const RELIC_CARD_SIZE := Vector2(150.0, 102.0)
const RELIC_CARD_GAP := 12.0
const LEFT_RELIC_ORIGIN := Vector2(50.0, 500.0)
const RIGHT_RELIC_ORIGIN := Vector2(760.0, 500.0)
const REROLL_SIZE := Vector2(474.0, 32.0)
const ACTION_BUTTON_SIZE := Vector2(84.0, 28.0)
const ACTION_BUTTON_GAP := 8.0
const LEFT_ACTION_ORIGIN := Vector2(58.0, 128.0)
const RIGHT_ACTION_ORIGIN := Vector2(852.0, 128.0)
const NETWORK_BUTTON_SIZE := Vector2(176.0, 28.0)
const NETWORK_BUTTON_GAP := 6.0
const NETWORK_BUTTON_ORIGIN := Vector2(552.0, 154.0)

var match_controller: MatchController
var tower_labels: Dictionary = {}
var relic_labels: Dictionary = {}
var reroll_labels: Dictionary = {}
var action_buttons: Dictionary = {}
var network_buttons: Dictionary = {}
var left_status_label: Label
var right_status_label: Label
var center_status_label: Label
var info_label: Label
var winner_label: Label


func _ready() -> void:
	_create_status_labels()
	_create_tower_labels()
	_create_relic_labels()
	_create_control_buttons()


func set_match_controller(controller: MatchController) -> void:
	match_controller = controller
	_update_labels()
	queue_redraw()


func _process(_delta: float) -> void:
	_update_labels()
	queue_redraw()


func get_cell_at_position(screen_position: Vector2) -> Array:
	for player_id in range(2):
		var origin := _get_grid_origin(player_id)
		var relative := screen_position - origin
		if relative.x < 0.0 or relative.y < 0.0:
			continue
		if relative.x > BOARD_SIZE or relative.y > BOARD_SIZE:
			continue

		var x := int(floor(relative.x / CELL_STEP))
		var y := int(floor(relative.y / CELL_STEP))
		var local_x := relative.x - float(x) * CELL_STEP
		var local_y := relative.y - float(y) * CELL_STEP

		if x < 0 or x >= PlayerState.GRID_SIZE:
			continue
		if y < 0 or y >= PlayerState.GRID_SIZE:
			continue
		if local_x > CELL_SIZE or local_y > CELL_SIZE:
			continue

		return [player_id, Vector2i(x, y)]

	return []


func get_relic_action_at_position(screen_position: Vector2) -> Dictionary:
	if match_controller == null:
		return {}
	if match_controller.phase != MatchController.MatchPhase.RELIC_SELECT:
		return {}

	for player_id in range(2):
		var player: PlayerState = match_controller.players[player_id]
		if player.relic_offer == null or player.relic_offer.selected:
			continue

		for option_index in range(player.relic_offer.options.size()):
			var card_rect := _get_relic_card_rect(player_id, option_index)
			if card_rect.has_point(screen_position):
				return {
					"action": "choose",
					"player_id": player_id,
					"index": option_index,
				}

		var reroll_rect := _get_reroll_rect(player_id)
		if reroll_rect.has_point(screen_position):
			return {
				"action": "reroll",
				"player_id": player_id,
			}

	return {}


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color(0.07, 0.08, 0.10), true)
	draw_line(Vector2(640.0, 92.0), Vector2(640.0, 650.0), Color(0.18, 0.20, 0.24), 2.0)

	if match_controller == null or match_controller.players.size() < 2:
		return

	_draw_player_area(match_controller.players[0], 0)
	_draw_player_area(match_controller.players[1], 1)

	if match_controller.phase == MatchController.MatchPhase.RELIC_SELECT:
		_draw_relic_select_area(match_controller.players[0], 0)
		_draw_relic_select_area(match_controller.players[1], 1)


func _create_status_labels() -> void:
	left_status_label = _make_label(Vector2(48.0, 30.0), Vector2(490.0, 56.0), 22, HORIZONTAL_ALIGNMENT_LEFT)
	right_status_label = _make_label(Vector2(742.0, 30.0), Vector2(490.0, 56.0), 22, HORIZONTAL_ALIGNMENT_RIGHT)
	center_status_label = _make_label(Vector2(440.0, 94.0), Vector2(400.0, 48.0), 18, HORIZONTAL_ALIGNMENT_CENTER)
	info_label = _make_label(Vector2(44.0, 664.0), Vector2(1192.0, 42.0), 16, HORIZONTAL_ALIGNMENT_CENTER)
	winner_label = _make_label(Vector2(390.0, 274.0), Vector2(500.0, 86.0), 42, HORIZONTAL_ALIGNMENT_CENTER)
	winner_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.28))


func _create_tower_labels() -> void:
	for player_id in range(2):
		for y in range(PlayerState.GRID_SIZE):
			for x in range(PlayerState.GRID_SIZE):
				var cell := Vector2i(x, y)
				var label := _make_label(_get_cell_position(player_id, cell), Vector2(CELL_SIZE, CELL_SIZE), 14, HORIZONTAL_ALIGNMENT_CENTER)
				label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				label.add_theme_color_override("font_color", Color.WHITE)
				label.add_theme_color_override("font_shadow_color", Color.BLACK)
				label.add_theme_constant_override("shadow_offset_x", 1)
				label.add_theme_constant_override("shadow_offset_y", 1)
				tower_labels[_label_key(player_id, cell)] = label


func _create_relic_labels() -> void:
	for player_id in range(2):
		for option_index in range(3):
			var card_rect := _get_relic_card_rect(player_id, option_index)
			var label := _make_label(card_rect.position + Vector2(8.0, 5.0), card_rect.size - Vector2(16.0, 10.0), 9, HORIZONTAL_ALIGNMENT_LEFT)
			label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.visible = false
			relic_labels[_relic_label_key(player_id, option_index)] = label

		var reroll_rect := _get_reroll_rect(player_id)
		var reroll_label := _make_label(reroll_rect.position, reroll_rect.size, 13, HORIZONTAL_ALIGNMENT_CENTER)
		reroll_label.visible = false
		reroll_labels[player_id] = reroll_label


func _make_label(label_position: Vector2, label_size: Vector2, font_size: int, alignment: int) -> Label:
	var label := Label.new()
	label.position = label_position
	label.size = label_size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	add_child(label)
	return label


func _create_control_buttons() -> void:
	_create_player_action_buttons(0)
	_create_player_action_buttons(1)
	_create_network_buttons()


func _create_player_action_buttons(player_id: int) -> void:
	var actions := [
		["summon", "Summon"],
		["merge", "Merge"],
		["attack", "Attack"],
		["boss", "Boss"],
	]
	var origin := LEFT_ACTION_ORIGIN
	if player_id == 1:
		origin = RIGHT_ACTION_ORIGIN

	for index in range(actions.size()):
		var action_name: String = actions[index][0]
		var label_text: String = actions[index][1]
		var button_position := origin + Vector2(float(index) * (ACTION_BUTTON_SIZE.x + ACTION_BUTTON_GAP), 0.0)
		var button := _make_button(button_position, ACTION_BUTTON_SIZE, label_text)
		button.pressed.connect(_on_player_action_button_pressed.bind(action_name, player_id))
		action_buttons[_action_button_key(player_id, action_name)] = button


func _create_network_buttons() -> void:
	var actions := [
		["host", "Host"],
		["find", "Find"],
		["join", "Join Code"],
		["copy", "Copy Code"],
		["leave", "Leave"],
		["restart", "Restart"],
	]

	for index in range(actions.size()):
		var action_name: String = actions[index][0]
		var label_text: String = actions[index][1]
		var button_position := NETWORK_BUTTON_ORIGIN + Vector2(0.0, float(index) * (NETWORK_BUTTON_SIZE.y + NETWORK_BUTTON_GAP))
		var button := _make_button(button_position, NETWORK_BUTTON_SIZE, label_text)
		button.pressed.connect(_on_network_button_pressed.bind(action_name))
		network_buttons[action_name] = button


func _make_button(button_position: Vector2, button_size: Vector2, label_text: String) -> Button:
	var button := Button.new()
	button.position = button_position
	button.size = button_size
	button.text = label_text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	add_child(button)
	return button


func _update_control_buttons() -> void:
	for player_id in range(2):
		var enabled := _is_player_action_enabled(player_id)
		for action_name in ["summon", "merge", "attack", "boss"]:
			var button: Button = action_buttons[_action_button_key(player_id, action_name)]
			button.disabled = not enabled

	var online := match_controller.network_local_player_id >= 0
	var is_client := match_controller.network_mode_name == "Steam Client"
	network_buttons["host"].disabled = online
	network_buttons["find"].disabled = online
	network_buttons["join"].disabled = online
	network_buttons["copy"].disabled = not online
	network_buttons["leave"].disabled = not online
	network_buttons["restart"].disabled = online and is_client


func _is_player_action_enabled(player_id: int) -> bool:
	if match_controller == null:
		return false
	if match_controller.game_over:
		return false
	if match_controller.phase == MatchController.MatchPhase.RELIC_SELECT:
		return false
	if match_controller.network_local_player_id >= 0 and match_controller.network_local_player_id != player_id:
		return false
	return true


func _on_player_action_button_pressed(action_name: String, player_id: int) -> void:
	player_action_requested.emit(action_name, player_id)


func _on_network_button_pressed(action_name: String) -> void:
	network_action_requested.emit(action_name)


func _update_labels() -> void:
	if match_controller == null or match_controller.players.size() < 2:
		return

	var player_a: PlayerState = match_controller.players[0]
	var player_b: PlayerState = match_controller.players[1]
	left_status_label.text = _get_player_status_text(player_a)
	right_status_label.text = _get_player_status_text(player_b)
	center_status_label.text = _get_center_status_text()
	info_label.text = _get_info_text(player_a, player_b)
	winner_label.text = match_controller.winner_text if match_controller.game_over else ""
	_update_relic_labels()
	_update_control_buttons()

	for player_id in range(2):
		var player: PlayerState = match_controller.players[player_id]
		for y in range(PlayerState.GRID_SIZE):
			for x in range(PlayerState.GRID_SIZE):
				var cell := Vector2i(x, y)
				var label: Label = tower_labels[_label_key(player_id, cell)]
				var tower := player.get_tower(cell)
				if tower == null:
					label.text = ""
				else:
					label.text = "Lv%d" % tower.level


func _update_relic_labels() -> void:
	var should_show := match_controller.phase == MatchController.MatchPhase.RELIC_SELECT

	for player_id in range(2):
		var player: PlayerState = match_controller.players[player_id]
		for option_index in range(3):
			var label: Label = relic_labels[_relic_label_key(player_id, option_index)]
			label.visible = should_show
			label.text = ""

			if not should_show:
				continue
			if player.relic_offer == null:
				continue
			if option_index >= player.relic_offer.options.size():
				continue

			var relic: RelicData = player.relic_offer.options[option_index]
			label.text = "%s\n%s\n%s" % [
				relic.relic_name,
				relic.description,
				RelicData.get_rarity_name(relic.rarity),
			]

		var reroll_label: Label = reroll_labels[player_id]
		reroll_label.visible = should_show
		if not should_show:
			reroll_label.text = ""
		elif player.relic_offer == null:
			reroll_label.text = ""
		elif player.relic_offer.selected:
			reroll_label.text = "Selected: %s" % player.relic_offer.selected_relic.relic_name
		else:
			var cost := match_controller.get_reroll_cost(player)
			var free_chance := int(round(player.get_free_reroll_chance() * 100.0))
			reroll_label.text = "Reroll %d Gold | %d%% free from Luck" % [cost, free_chance]


func _get_player_status_text(player: PlayerState) -> String:
	return "%s  HP %d  Gold %d  Gauge %d%%  Relics %d" % [
		player.display_name,
		maxi(player.hp, 0),
		player.gold,
		int(round(player.attack_gauge)),
		player.relics.size(),
	]


func _get_center_status_text() -> String:
	var seconds := int(floor(match_controller.match_time))
	var minutes := int(seconds / 60)
	var remaining_seconds := seconds % 60
	var stage_seconds := int(ceil(match_controller.stage_timer))
	var next_boss_stage := match_controller.get_next_event_boss_stage()
	return "%02d:%02d   Stage %d   %s   %ds   Event Boss %d" % [
		minutes,
		remaining_seconds,
		match_controller.stage_number,
		match_controller.get_phase_name(),
		maxi(0, stage_seconds),
		next_boss_stage,
	]


func _get_info_text(player_a: PlayerState, player_b: PlayerState) -> String:
	if match_controller.game_over:
		return "Press R to restart."

	var message_text := match_controller.last_event_text
	if player_a.message != "":
		message_text = "%s | %s" % [message_text, player_a.message]
	if player_b.message != "":
		message_text = "%s | %s" % [message_text, player_b.message]

	if match_controller.phase == MatchController.MatchPhase.RELIC_SELECT:
		return "Choose one relic each. Click a card or reroll. | %s | %s" % [
			message_text,
			match_controller.network_status_text,
		]

	if match_controller.network_local_player_id >= 0:
		var local_name := "Player A"
		if match_controller.network_local_player_id == 1:
			local_name = "Player B"
		return "Online %s: Q summon, W merge, E attack, A boss | H host, L find, C copy, V join, Esc leave | %s | %s" % [
			local_name,
			message_text,
			match_controller.network_status_text,
		]

	return "A: Q summon, W merge, E attack, A boss | B: I summon, O merge, P attack, J boss | H host, L find, C copy, V join | R restart | %s | %s" % [
		message_text,
		match_controller.network_status_text,
	]


func _draw_player_area(player: PlayerState, player_id: int) -> void:
	var origin := _get_grid_origin(player_id)
	var panel_rect := Rect2(origin - Vector2(24.0, 34.0), Vector2(BOARD_SIZE + 132.0, BOARD_SIZE + 134.0))
	var panel_color := Color(0.11, 0.13, 0.17)
	if player_id == 1:
		panel_rect.position = panel_rect.position - Vector2(108.0, 0.0)
	draw_rect(panel_rect, panel_color, true)
	draw_rect(panel_rect, Color(0.26, 0.29, 0.34), false, 2.0)

	_draw_grid(player, player_id)
	_draw_path_and_base(player_id)
	_draw_monsters(player, player_id)
	_draw_build_profile(player, player_id)


func _draw_grid(player: PlayerState, player_id: int) -> void:
	for y in range(PlayerState.GRID_SIZE):
		for x in range(PlayerState.GRID_SIZE):
			var cell := Vector2i(x, y)
			var cell_rect := Rect2(_get_cell_position(player_id, cell), Vector2(CELL_SIZE, CELL_SIZE))
			var fill_color := Color(0.16, 0.18, 0.22)
			if player.selected_cell == cell:
				fill_color = Color(0.25, 0.29, 0.36)
			draw_rect(cell_rect, fill_color, true)
			draw_rect(cell_rect, Color(0.35, 0.38, 0.44), false, 1.0)

			var tower := player.get_tower(cell)
			if tower != null:
				var tower_rect := cell_rect.grow(-7.0)
				draw_rect(tower_rect, TowerData.get_color(tower.tower_type), true)
				draw_rect(tower_rect, Color(0.95, 0.96, 0.98), false, 1.5)

			if player.is_cell_locked(cell):
				draw_rect(cell_rect.grow(-3.0), Color(0.08, 0.06, 0.11, 0.72), true)
				draw_line(cell_rect.position + Vector2(6.0, 6.0), cell_rect.end - Vector2(6.0, 6.0), Color(0.85, 0.75, 1.0), 3.0)
				draw_line(Vector2(cell_rect.end.x - 6.0, cell_rect.position.y + 6.0), Vector2(cell_rect.position.x + 6.0, cell_rect.end.y - 6.0), Color(0.85, 0.75, 1.0), 3.0)


func _draw_path_and_base(player_id: int) -> void:
	var path_x := _get_path_x(player_id)
	draw_line(Vector2(path_x, PATH_TOP), Vector2(path_x, PATH_BOTTOM), Color(0.27, 0.30, 0.36), 12.0)
	draw_line(Vector2(path_x, PATH_TOP), Vector2(path_x, PATH_BOTTOM), Color(0.10, 0.11, 0.14), 4.0)

	var base_rect := Rect2(Vector2(path_x - 42.0, PATH_BOTTOM + 20.0), Vector2(84.0, 54.0))
	var base_color := Color(0.18, 0.36, 0.78) if player_id == 0 else Color(0.78, 0.28, 0.24)
	draw_rect(base_rect, base_color, true)
	draw_rect(base_rect, Color(0.95, 0.95, 0.98), false, 2.0)


func _draw_monsters(player: PlayerState, player_id: int) -> void:
	for monster in player.monsters:
		var monster_position := _get_monster_position(player_id, monster)
		var radius := 12.0
		if monster.monster_type == MonsterData.MonsterType.ARMORED:
			radius = 15.0
		elif monster.monster_type == MonsterData.MonsterType.CHALLENGE_BOSS:
			radius = 22.0
		elif monster.monster_type == MonsterData.MonsterType.EVENT_BOSS:
			radius = 26.0
		draw_circle(monster_position, radius, MonsterData.get_color(monster.monster_type))
		draw_arc(monster_position, radius + 2.0, 0.0, TAU, 24, Color(0.05, 0.06, 0.08), 2.0)


func _draw_relic_select_area(player: PlayerState, player_id: int) -> void:
	if player.relic_offer == null:
		return

	for option_index in range(player.relic_offer.options.size()):
		var relic: RelicData = player.relic_offer.options[option_index]
		var card_rect := _get_relic_card_rect(player_id, option_index)
		var fill_color := Color(0.10, 0.11, 0.14)
		if player.relic_offer.selected:
			fill_color = Color(0.08, 0.09, 0.11)
		draw_rect(card_rect, fill_color, true)
		draw_rect(card_rect, RelicData.get_rarity_color(relic.rarity), false, 2.0)

	var reroll_rect := _get_reroll_rect(player_id)
	var reroll_color := Color(0.17, 0.19, 0.24)
	if player.relic_offer.selected:
		reroll_color = Color(0.10, 0.12, 0.15)
	draw_rect(reroll_rect, reroll_color, true)
	draw_rect(reroll_rect, Color(0.42, 0.46, 0.54), false, 1.0)


func _draw_build_profile(player: PlayerState, player_id: int) -> void:
	var origin := _get_grid_origin(player_id)
	var start_x := origin.x
	var start_y := origin.y + BOARD_SIZE + 24.0
	var counts := player.get_tower_type_counts()

	for index in range(counts.size()):
		var swatch_rect := Rect2(Vector2(start_x + float(index) * 36.0, start_y), Vector2(24.0, 18.0))
		var alpha := 1.0 if counts[index] > 0 else 0.25
		var color := TowerData.get_color(index)
		color.a = alpha
		draw_rect(swatch_rect, color, true)
		draw_rect(swatch_rect, Color(0.85, 0.88, 0.92), false, 1.0)


func _get_grid_origin(player_id: int) -> Vector2:
	if player_id == 0:
		return LEFT_GRID_ORIGIN
	return RIGHT_GRID_ORIGIN


func _get_path_x(player_id: int) -> float:
	if player_id == 0:
		return LEFT_PATH_X
	return RIGHT_PATH_X


func _get_cell_position(player_id: int, cell: Vector2i) -> Vector2:
	return _get_grid_origin(player_id) + Vector2(float(cell.x) * CELL_STEP, float(cell.y) * CELL_STEP)


func _get_monster_position(player_id: int, monster: MonsterData) -> Vector2:
	var path_x := _get_path_x(player_id)
	var progress_ratio := clampf(monster.progress / MatchController.PATH_LENGTH, 0.0, 1.0)
	var y := lerpf(PATH_TOP, PATH_BOTTOM, progress_ratio)
	var x := path_x + monster.lane_offset
	return Vector2(x, y)


func _label_key(player_id: int, cell: Vector2i) -> String:
	return "%d_%d_%d" % [player_id, cell.x, cell.y]


func _action_button_key(player_id: int, action_name: String) -> String:
	return "%d_%s" % [player_id, action_name]


func _relic_label_key(player_id: int, option_index: int) -> String:
	return "%d_relic_%d" % [player_id, option_index]


func _get_relic_origin(player_id: int) -> Vector2:
	if player_id == 0:
		return LEFT_RELIC_ORIGIN
	return RIGHT_RELIC_ORIGIN


func _get_relic_card_rect(player_id: int, option_index: int) -> Rect2:
	var origin := _get_relic_origin(player_id)
	var x := origin.x + float(option_index) * (RELIC_CARD_SIZE.x + RELIC_CARD_GAP)
	return Rect2(Vector2(x, origin.y), RELIC_CARD_SIZE)


func _get_reroll_rect(player_id: int) -> Rect2:
	var origin := _get_relic_origin(player_id)
	return Rect2(origin + Vector2(0.0, RELIC_CARD_SIZE.y + 8.0), REROLL_SIZE)
