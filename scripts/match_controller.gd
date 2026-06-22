class_name MatchController
extends Node

const PATH_LENGTH := 320.0
const BASE_SPAWN_INTERVAL := 2.35
const WAVE_DURATION := 24.0

var rng := RandomNumberGenerator.new()
var match_seed: int = 0
var players: Array = []
var match_time: float = 0.0
var wave_number: int = 1
var spawn_timer: float = 0.0
var wave_timer: float = 0.0
var game_over: bool = false
var winner_text: String = ""
var last_event_text: String = ""


func start_match(initial_seed: int = 0) -> void:
	if initial_seed == 0:
		rng.randomize()
		match_seed = rng.randi()
	else:
		match_seed = initial_seed

	rng.seed = match_seed
	players.clear()
	players.append(PlayerState.new(0, "Player A"))
	players.append(PlayerState.new(1, "Player B"))
	match_time = 0.0
	wave_number = 1
	spawn_timer = 3.0
	wave_timer = 0.0
	game_over = false
	winner_text = ""
	last_event_text = "Match seed %d" % match_seed


func _process(delta: float) -> void:
	if game_over:
		return

	match_time += delta
	wave_timer += delta

	for player in players:
		player.tick(delta)

	if wave_timer >= WAVE_DURATION:
		wave_timer = 0.0
		wave_number += 1
		last_event_text = "Wave %d started." % wave_number

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_regular_wave()
		spawn_timer = maxf(0.85, BASE_SPAWN_INTERVAL - float(wave_number - 1) * 0.07)

	_update_combat(delta)
	_update_monsters(delta)
	_check_game_over()


func select_cell(player_id: int, cell: Vector2i) -> void:
	if game_over:
		return
	if not _is_valid_player_id(player_id):
		return
	players[player_id].select_cell(cell)


func summon_tower(player_id: int) -> void:
	if game_over:
		return
	if not _is_valid_player_id(player_id):
		return
	players[player_id].summon_random_tower(rng)


func merge_selected_tower(player_id: int) -> void:
	if game_over:
		return
	if not _is_valid_player_id(player_id):
		return
	players[player_id].merge_selected_tower()


func send_attack_wave(player_id: int) -> void:
	if game_over:
		return
	if not _is_valid_player_id(player_id):
		return

	var attacker: PlayerState = players[player_id]
	if not attacker.spend_attack_gauge():
		return

	var defender_id := 1 - player_id
	var defender: PlayerState = players[defender_id]
	var primary_tower_type := attacker.get_primary_tower_type()
	var secondary_tower_type := attacker.get_secondary_tower_type()
	var primary_monster_type := _monster_type_for_tower_type(primary_tower_type)
	var secondary_monster_type := primary_monster_type

	if secondary_tower_type >= 0:
		secondary_monster_type = _monster_type_for_tower_type(secondary_tower_type)

	var monster_count := 3 + int(floor(float(wave_number) / 3.0))
	for index in range(monster_count):
		var monster_type := primary_monster_type
		if secondary_tower_type >= 0 and index % 3 == 2:
			monster_type = secondary_monster_type
		_spawn_monster(defender, monster_type, 8.0 + float(index) * 12.0)

	if primary_monster_type == MonsterData.MonsterType.HEXED:
		defender.lock_random_tower(rng, 5.0)

	var attack_name := MonsterData.get_display_name(primary_monster_type)
	last_event_text = "%s sent %s pressure to %s." % [
		attacker.display_name,
		attack_name,
		defender.display_name,
	]
	attacker.set_message("Sent %s wave." % attack_name)


func _spawn_regular_wave() -> void:
	for player in players:
		_spawn_monster(player, MonsterData.MonsterType.BASIC, rng.randf_range(-8.0, 8.0))


func _spawn_monster(player: PlayerState, monster_type: int, lane_offset: float = 0.0) -> void:
	player.monsters.append(MonsterData.new(monster_type, wave_number, lane_offset))


func _update_combat(delta: float) -> void:
	for player in players:
		_update_player_towers(player, delta)


func _update_player_towers(player: PlayerState, delta: float) -> void:
	for y in range(PlayerState.GRID_SIZE):
		for x in range(PlayerState.GRID_SIZE):
			var cell := Vector2i(x, y)
			var tower := player.get_tower(cell)
			if tower == null:
				continue

			if player.is_cell_locked(cell):
				continue

			tower.cooldown -= delta
			if tower.cooldown > 0.0:
				continue

			var target := _find_target_for_tower(player, cell, tower)
			if target == null:
				continue

			_apply_tower_attack(player, tower, target)
			tower.cooldown = tower.get_attack_interval() * player.get_tower_slow_multiplier()


func _find_target_for_tower(player: PlayerState, cell: Vector2i, tower: TowerData) -> MonsterData:
	var best_target: MonsterData = null
	var best_progress := -1.0
	var tower_position := Vector2(float(cell.x), float(cell.y))

	for monster in player.monsters:
		var monster_position := _get_virtual_monster_position(monster)
		var distance := tower_position.distance_to(monster_position)
		if distance > tower.get_range_cells():
			continue
		if monster.progress > best_progress:
			best_target = monster
			best_progress = monster.progress

	return best_target


func _get_virtual_monster_position(monster: MonsterData) -> Vector2:
	var y_position := clampf(monster.progress / PATH_LENGTH, 0.0, 1.0) * float(PlayerState.GRID_SIZE - 1)
	return Vector2(5.4, y_position)


func _apply_tower_attack(player: PlayerState, tower: TowerData, target: MonsterData) -> void:
	var damage := tower.get_damage()
	target.take_damage(damage)
	player.attack_gauge = minf(PlayerState.ATTACK_GAUGE_COST, player.attack_gauge + tower.get_gauge_bonus())

	match tower.tower_type:
		TowerData.TowerType.POISON:
			target.add_poison(3.0, damage * 0.35)
		TowerData.TowerType.ICE:
			target.add_slow(1.4 + float(tower.level) * 0.2, 0.58)
		TowerData.TowerType.LIGHTNING:
			_chain_lightning(player, target, damage * 0.45)
		TowerData.TowerType.CURSE:
			target.add_slow(0.8, 0.78)


func _chain_lightning(player: PlayerState, first_target: MonsterData, damage: float) -> void:
	var hit_count := 0
	for monster in player.monsters:
		if monster == first_target:
			continue
		if absf(monster.progress - first_target.progress) > 65.0:
			continue
		monster.take_damage(damage)
		hit_count += 1
		if hit_count >= 2:
			return


func _update_monsters(delta: float) -> void:
	for player in players:
		for index in range(player.monsters.size() - 1, -1, -1):
			var monster: MonsterData = player.monsters[index]
			monster.update_effects(delta)
			monster.advance(delta)

			if monster.is_dead():
				_handle_monster_death(player, monster)
				player.monsters.remove_at(index)
				continue

			if monster.progress >= PATH_LENGTH:
				player.hp -= monster.damage_to_base
				player.set_message("%s leaked." % MonsterData.get_display_name(monster.monster_type))
				player.monsters.remove_at(index)


func _handle_monster_death(player: PlayerState, monster: MonsterData) -> void:
	player.add_rewards(monster.reward_gold, monster.reward_gauge)

	if monster.monster_type == MonsterData.MonsterType.TOXIC:
		player.tower_slow_timer = maxf(player.tower_slow_timer, 3.0)
		player.set_message("Toxic residue slowed towers.")
	elif monster.monster_type == MonsterData.MonsterType.FROST:
		player.tower_slow_timer = maxf(player.tower_slow_timer, 2.0)
		player.set_message("Frost armor chilled towers.")


func _check_game_over() -> void:
	var player_a: PlayerState = players[0]
	var player_b: PlayerState = players[1]

	if player_a.hp <= 0 and player_b.hp <= 0:
		game_over = true
		winner_text = "Draw"
	elif player_a.hp <= 0:
		game_over = true
		winner_text = "Player B wins"
	elif player_b.hp <= 0:
		game_over = true
		winner_text = "Player A wins"

	if game_over:
		last_event_text = winner_text


func _monster_type_for_tower_type(tower_type: int) -> int:
	match tower_type:
		TowerData.TowerType.FIRE:
			return MonsterData.MonsterType.ARMORED
		TowerData.TowerType.POISON:
			return MonsterData.MonsterType.TOXIC
		TowerData.TowerType.ICE:
			return MonsterData.MonsterType.FROST
		TowerData.TowerType.LIGHTNING:
			return MonsterData.MonsterType.BLINK
		TowerData.TowerType.CURSE:
			return MonsterData.MonsterType.HEXED
		_:
			return MonsterData.MonsterType.BASIC


func _is_valid_player_id(player_id: int) -> bool:
	return player_id >= 0 and player_id < players.size()
