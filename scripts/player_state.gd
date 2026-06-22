class_name PlayerState
extends RefCounted

const GRID_SIZE := 5
const START_HP := 20
const START_GOLD := 100
const SUMMON_COST := 25
const ATTACK_GAUGE_COST := 100.0
const START_LUCK := 10

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
var relics: Array = []
var relic_offer: RelicOffer = null
var luck: int = START_LUCK
var challenge_boss_used_this_stage: bool = false
var challenge_boss_instance_id: int = 0
var challenge_boss_timer: float = 0.0
var pending_boss_penalty_timer: float = 0.0
var curse_defense_stacks: int = 0


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

	if challenge_boss_timer > 0.0:
		challenge_boss_timer = maxf(0.0, challenge_boss_timer - delta)


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


func start_stage() -> void:
	challenge_boss_used_this_stage = false
	challenge_boss_instance_id = 0
	challenge_boss_timer = 0.0
	relic_offer = null

	if pending_boss_penalty_timer > 0.0:
		tower_slow_timer = maxf(tower_slow_timer, pending_boss_penalty_timer)
		pending_boss_penalty_timer = 0.0
		set_message("Boss penalty slowed towers.")


func add_relic(relic: RelicData) -> void:
	if relic == null:
		return
	if has_relic_id(relic.id):
		return
	relics.append(relic)
	set_message("Picked %s." % relic.relic_name)


func has_relic_id(relic_id: String) -> bool:
	for relic in relics:
		if relic.id == relic_id:
			return true
	return false


func get_relic_multiplier(effect_type: String, key: String, tower_type: int = RelicData.ANY_TOWER) -> float:
	var multiplier := 1.0
	for relic in relics:
		if relic.effect_type != effect_type:
			continue
		if not relic.targets_tower_type(tower_type):
			continue
		multiplier *= float(relic.values.get(key, 1.0))
	return multiplier


func get_relic_sum(effect_type: String, key: String, tower_type: int = RelicData.ANY_TOWER) -> float:
	var total := 0.0
	for relic in relics:
		if relic.effect_type != effect_type:
			continue
		if not relic.targets_tower_type(tower_type):
			continue
		total += float(relic.values.get(key, 0.0))
	return total


func get_relic_max(effect_type: String, key: String, tower_type: int = RelicData.ANY_TOWER) -> float:
	var best := 0.0
	for relic in relics:
		if relic.effect_type != effect_type:
			continue
		if not relic.targets_tower_type(tower_type):
			continue
		best = maxf(best, float(relic.values.get(key, 0.0)))
	return best


func get_relic_chance(effect_type: String, key: String, tower_type: int = RelicData.ANY_TOWER) -> float:
	return minf(0.95, get_relic_sum(effect_type, key, tower_type))


func get_reroll_discount() -> int:
	return int(get_relic_sum("reroll_discount", "amount"))


func get_free_reroll_chance() -> float:
	return minf(0.35, float(luck) * 0.01)


func get_boss_reward_multiplier() -> float:
	return get_relic_multiplier("boss_reward_mult", "multiplier")


func get_boss_penalty_multiplier() -> float:
	var reduction := get_relic_sum("boss_penalty_reduction", "reduction")
	return maxf(0.15, 1.0 - reduction)


func get_hex_duration_bonus() -> float:
	return get_relic_sum("hex_duration_bonus", "duration_bonus", TowerData.TowerType.CURSE)


func consume_curse_defense_reduction(incoming_count: int) -> int:
	if curse_defense_stacks <= 0:
		return incoming_count

	var reduced_count := maxi(1, incoming_count - curse_defense_stacks)
	curse_defense_stacks = 0
	set_message("Curse defense weakened an attack wave.")
	return reduced_count


func add_curse_defense_stack() -> void:
	var max_stacks := int(get_relic_max("curse_defense_stack", "max_stacks", TowerData.TowerType.CURSE))
	if max_stacks <= 0:
		return
	curse_defense_stacks = mini(max_stacks, curse_defense_stacks + 1)


func to_snapshot() -> Dictionary:
	return {
		"player_id": player_id,
		"display_name": display_name,
		"hp": hp,
		"gold": gold,
		"attack_gauge": attack_gauge,
		"board": _board_to_snapshot(),
		"monsters": _monsters_to_snapshot(),
		"selected_cell_x": selected_cell.x,
		"selected_cell_y": selected_cell.y,
		"locked_cell_x": locked_cell.x,
		"locked_cell_y": locked_cell.y,
		"locked_timer": locked_timer,
		"tower_slow_timer": tower_slow_timer,
		"message": message,
		"message_timer": message_timer,
		"relic_ids": _relic_ids_to_snapshot(),
		"relic_offer": _relic_offer_to_snapshot(),
		"luck": luck,
		"challenge_boss_used_this_stage": challenge_boss_used_this_stage,
		"challenge_boss_instance_id": challenge_boss_instance_id,
		"challenge_boss_timer": challenge_boss_timer,
		"pending_boss_penalty_timer": pending_boss_penalty_timer,
		"curse_defense_stacks": curse_defense_stacks,
	}


func apply_snapshot(data: Dictionary, library: RelicLibrary) -> void:
	player_id = int(data.get("player_id", player_id))
	display_name = str(data.get("display_name", display_name))
	hp = int(data.get("hp", START_HP))
	gold = int(data.get("gold", START_GOLD))
	attack_gauge = float(data.get("attack_gauge", 0.0))
	selected_cell = Vector2i(
		int(data.get("selected_cell_x", -1)),
		int(data.get("selected_cell_y", -1))
	)
	locked_cell = Vector2i(
		int(data.get("locked_cell_x", -1)),
		int(data.get("locked_cell_y", -1))
	)
	locked_timer = float(data.get("locked_timer", 0.0))
	tower_slow_timer = float(data.get("tower_slow_timer", 0.0))
	message = str(data.get("message", ""))
	message_timer = float(data.get("message_timer", 0.0))
	luck = int(data.get("luck", START_LUCK))
	challenge_boss_used_this_stage = bool(data.get("challenge_boss_used_this_stage", false))
	challenge_boss_instance_id = int(data.get("challenge_boss_instance_id", 0))
	challenge_boss_timer = float(data.get("challenge_boss_timer", 0.0))
	pending_boss_penalty_timer = float(data.get("pending_boss_penalty_timer", 0.0))
	curse_defense_stacks = int(data.get("curse_defense_stacks", 0))
	_apply_board_snapshot(data.get("board", []))
	_apply_monsters_snapshot(data.get("monsters", []))
	_apply_relics_snapshot(data.get("relic_ids", []), library)
	_apply_relic_offer_snapshot(data.get("relic_offer", {}), library)


func _board_to_snapshot() -> Array:
	var board_snapshot: Array = []
	for y in range(GRID_SIZE):
		var row_snapshot: Array = []
		for x in range(GRID_SIZE):
			var tower: TowerData = board[y][x]
			if tower == null:
				row_snapshot.append({})
			else:
				row_snapshot.append(tower.to_snapshot())
		board_snapshot.append(row_snapshot)
	return board_snapshot


func _monsters_to_snapshot() -> Array:
	var monster_snapshot: Array = []
	for monster in monsters:
		monster_snapshot.append(monster.to_snapshot())
	return monster_snapshot


func _relic_ids_to_snapshot() -> Array:
	var relic_ids: Array = []
	for relic in relics:
		relic_ids.append(relic.id)
	return relic_ids


func _relic_offer_to_snapshot() -> Dictionary:
	if relic_offer == null:
		return {}

	var option_ids: Array = []
	for relic in relic_offer.options:
		option_ids.append(relic.id)

	var selected_id := ""
	if relic_offer.selected_relic != null:
		selected_id = relic_offer.selected_relic.id

	return {
		"option_ids": option_ids,
		"selected": relic_offer.selected,
		"selected_relic_id": selected_id,
		"reroll_count": relic_offer.reroll_count,
		"last_reroll_was_free": relic_offer.last_reroll_was_free,
	}


func _apply_board_snapshot(board_snapshot: Variant) -> void:
	_reset_board()
	if not (board_snapshot is Array):
		return

	for y in range(mini(GRID_SIZE, board_snapshot.size())):
		var row_snapshot: Variant = board_snapshot[y]
		if not (row_snapshot is Array):
			continue
		for x in range(mini(GRID_SIZE, row_snapshot.size())):
			var tower_snapshot: Variant = row_snapshot[x]
			if not (tower_snapshot is Dictionary):
				continue
			if tower_snapshot.is_empty():
				continue
			board[y][x] = TowerData.from_snapshot(tower_snapshot)


func _apply_monsters_snapshot(monster_snapshot: Variant) -> void:
	monsters.clear()
	if not (monster_snapshot is Array):
		return

	for monster_data in monster_snapshot:
		if monster_data is Dictionary:
			monsters.append(MonsterData.from_snapshot(monster_data))


func _apply_relics_snapshot(relic_ids: Variant, library: RelicLibrary) -> void:
	relics.clear()
	if library == null or not (relic_ids is Array):
		return

	for relic_id in relic_ids:
		var relic := library.get_relic_by_id(str(relic_id))
		if relic != null:
			relics.append(relic)


func _apply_relic_offer_snapshot(offer_snapshot: Variant, library: RelicLibrary) -> void:
	relic_offer = null
	if library == null or not (offer_snapshot is Dictionary):
		return
	if offer_snapshot.is_empty():
		return

	var options: Array = []
	var option_ids: Variant = offer_snapshot.get("option_ids", [])
	if option_ids is Array:
		for relic_id in option_ids:
			var relic := library.get_relic_by_id(str(relic_id))
			if relic != null:
				options.append(relic)

	relic_offer = RelicOffer.new(options)
	relic_offer.selected = bool(offer_snapshot.get("selected", false))
	relic_offer.reroll_count = int(offer_snapshot.get("reroll_count", 0))
	relic_offer.last_reroll_was_free = bool(offer_snapshot.get("last_reroll_was_free", false))

	var selected_relic_id := str(offer_snapshot.get("selected_relic_id", ""))
	if selected_relic_id != "":
		relic_offer.selected_relic = library.get_relic_by_id(selected_relic_id)
