class_name PlayerState
extends RefCounted

const GRID_SIZE := 5
const START_HP := 20
const START_GOLD := 100
const SUMMON_COST := 25
const ATTACK_GAUGE_COST := 100.0

var player_id: int = 0
var display_name: String = ""
var hp: int = START_HP
var gold: int = START_GOLD
var attack_gauge: float = 0.0
var board: Array = []
var monsters: Array = []
var selected_cell: Vector2i = Vector2i(-1, -1)
var locked_cell: Vector2i = Vector2i(-1, -1)
var locked_timer: float = 0.0
var tower_slow_timer: float = 0.0
var message: String = ""
var message_timer: float = 0.0


func _init(initial_id: int = 0, initial_name: String = "Player") -> void:
	player_id = initial_id
	display_name = initial_name
	_reset_board()


func _reset_board() -> void:
	board.clear()
	for y in range(GRID_SIZE):
		var row: Array = []
		for x in range(GRID_SIZE):
			row.append(null)
		board.append(row)


func tick(delta: float) -> void:
	if locked_timer > 0.0:
		locked_timer = maxf(0.0, locked_timer - delta)
		if locked_timer <= 0.0:
			locked_cell = Vector2i(-1, -1)

	if tower_slow_timer > 0.0:
		tower_slow_timer = maxf(0.0, tower_slow_timer - delta)

	if message_timer > 0.0:
		message_timer = maxf(0.0, message_timer - delta)
		if message_timer <= 0.0:
			message = ""


func set_message(text: String) -> void:
	message = text
	message_timer = 2.2


func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_SIZE and cell.y >= 0 and cell.y < GRID_SIZE


func select_cell(cell: Vector2i) -> void:
	if is_valid_cell(cell):
		selected_cell = cell


func get_tower(cell: Vector2i) -> TowerData:
	if not is_valid_cell(cell):
		return null
	return board[cell.y][cell.x]


func is_cell_locked(cell: Vector2i) -> bool:
	return locked_timer > 0.0 and locked_cell == cell


func summon_random_tower(rng: RandomNumberGenerator) -> bool:
	if not is_valid_cell(selected_cell):
		set_message("Select a cell first.")
		return false

	if get_tower(selected_cell) != null:
		set_message("Cell is occupied.")
		return false

	if gold < SUMMON_COST:
		set_message("Not enough gold.")
		return false

	var tower_type := rng.randi_range(0, TowerData.TYPE_COUNT - 1)
	board[selected_cell.y][selected_cell.x] = TowerData.new(tower_type, 1)
	gold -= SUMMON_COST
	set_message("Summoned %s Lv1." % TowerData.get_display_name(tower_type))
	return true


func merge_selected_tower() -> bool:
	var selected_tower := get_tower(selected_cell)
	if selected_tower == null:
		set_message("Select a tower to merge.")
		return false

	var partner_cell := _find_merge_partner(selected_cell, selected_tower)
	if not is_valid_cell(partner_cell):
		set_message("No matching tower.")
		return false

	board[selected_cell.y][selected_cell.x] = selected_tower.make_upgraded()
	board[partner_cell.y][partner_cell.x] = null
	set_message("Merged into %s Lv%d." % [
		TowerData.get_display_name(selected_tower.tower_type),
		selected_tower.level + 1,
	])
	return true


func _find_merge_partner(source_cell: Vector2i, source_tower: TowerData) -> Vector2i:
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var cell := Vector2i(x, y)
			if cell == source_cell:
				continue
			var tower := get_tower(cell)
			if source_tower.can_merge_with(tower):
				return cell
	return Vector2i(-1, -1)


func add_rewards(reward_gold: int, reward_gauge: float) -> void:
	gold += reward_gold
	attack_gauge = minf(ATTACK_GAUGE_COST, attack_gauge + reward_gauge)


func spend_attack_gauge() -> bool:
	if attack_gauge < ATTACK_GAUGE_COST:
		set_message("Attack gauge is not ready.")
		return false
	attack_gauge -= ATTACK_GAUGE_COST
	return true


func get_tower_type_counts() -> Array:
	var counts := []
	for index in range(TowerData.TYPE_COUNT):
		counts.append(0)

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var tower: TowerData = board[y][x]
			if tower == null:
				continue
			counts[tower.tower_type] += tower.level

	return counts


func get_primary_tower_type() -> int:
	var counts := get_tower_type_counts()
	var best_type := TowerData.TowerType.FIRE
	var best_count := -1

	for index in range(counts.size()):
		if counts[index] > best_count:
			best_type = index
			best_count = counts[index]

	return best_type


func get_secondary_tower_type() -> int:
	var counts := get_tower_type_counts()
	var primary := get_primary_tower_type()
	var best_type := -1
	var best_count := 0

	for index in range(counts.size()):
		if index == primary:
			continue
		if counts[index] > best_count:
			best_type = index
			best_count = counts[index]

	return best_type


func lock_random_tower(rng: RandomNumberGenerator, duration: float) -> bool:
	var occupied_cells := []
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var cell := Vector2i(x, y)
			if get_tower(cell) != null:
				occupied_cells.append(cell)

	if occupied_cells.is_empty():
		return false

	var index := rng.randi_range(0, occupied_cells.size() - 1)
	locked_cell = occupied_cells[index]
	locked_timer = duration
	set_message("A tower was hexed.")
	return true


func get_tower_slow_multiplier() -> float:
	if tower_slow_timer > 0.0:
		return 1.35
	return 1.0
