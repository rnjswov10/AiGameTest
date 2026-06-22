class_name BoardView
extends Node2D

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

var match_controller: MatchController
var tower_labels: Dictionary = {}
var left_status_label: Label
var right_status_label: Label
var center_status_label: Label
var info_label: Label
var winner_label: Label


func _ready() -> void:
	_create_status_labels()
	_create_tower_labels()


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


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color(0.07, 0.08, 0.10), true)
	draw_line(Vector2(640.0, 92.0), Vector2(640.0, 650.0), Color(0.18, 0.20, 0.24), 2.0)

	if match_controller == null or match_controller.players.size() < 2:
		return

	_draw_player_area(match_controller.players[0], 0)
	_draw_player_area(match_controller.players[1], 1)


func _create_status_labels() -> void:
	left_status_label = _make_label(Vector2(48.0, 30.0), Vector2(490.0, 56.0), 22, HORIZONTAL_ALIGNMENT_LEFT)
	right_status_label = _make_label(Vector2(742.0, 30.0), Vector2(490.0, 56.0), 22, HORIZONTAL_ALIGNMENT_RIGHT)
	center_status_label = _make_label(Vector2(440.0, 94.0), Vector2(400.0, 48.0), 18, HORIZONTAL_ALIGNMENT_CENTER)
	info_label = _make_label(Vector2(44.0, 626.0), Vector2(1192.0, 54.0), 18, HORIZONTAL_ALIGNMENT_CENTER)
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


func _get_player_status_text(player: PlayerState) -> String:
	return "%s  HP %d  Gold %d  Gauge %d%%" % [
		player.display_name,
		maxi(player.hp, 0),
		player.gold,
		int(round(player.attack_gauge)),
	]


func _get_center_status_text() -> String:
	var seconds := int(floor(match_controller.match_time))
	var minutes := int(seconds / 60)
	var remaining_seconds := seconds % 60
	return "%02d:%02d   Wave %d   R: restart" % [
		minutes,
		remaining_seconds,
		match_controller.wave_number,
	]


func _get_info_text(player_a: PlayerState, player_b: PlayerState) -> String:
	if match_controller.game_over:
		return "Press R to restart."

	var message_text := match_controller.last_event_text
	if player_a.message != "":
		message_text = "%s | %s" % [message_text, player_a.message]
	if player_b.message != "":
		message_text = "%s | %s" % [message_text, player_b.message]

	return "A: click left board, Q summon, W merge, E attack | B: click right board, I summon, O merge, P attack | %s" % message_text


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
		draw_circle(monster_position, radius, MonsterData.get_color(monster.monster_type))
		draw_arc(monster_position, radius + 2.0, 0.0, TAU, 24, Color(0.05, 0.06, 0.08), 2.0)


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
