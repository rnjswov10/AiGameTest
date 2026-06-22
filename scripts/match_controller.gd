class_name MatchController
extends Node

enum MatchPhase {
	COMBAT,
	CLEANUP,
	RELIC_SELECT,
	GAME_OVER,
}

const PATH_LENGTH := 320.0
const BASE_SPAWN_INTERVAL := 2.35
const STAGE_BASE_DURATION := 30.0
const STAGE_DURATION_GAIN := 2.0
const STAGE_COMPLETE_GOLD := 20
const ATTACK_WAVE_BASE_COUNT := 3
const EFFECT_MAX_AGE := 0.75
const EFFECT_MAX_COUNT := 80

var rng := RandomNumberGenerator.new()
var relic_library := RelicLibrary.new()
var match_seed: int = 0
var players: Array = []
var match_time: float = 0.0
var stage_number: int = 1
var wave_number: int = 1
var phase: int = MatchPhase.COMBAT
var stage_timer: float = 0.0
var spawn_timer: float = 0.0
var game_over: bool = false
var winner_text: String = ""
var last_event_text: String = ""
var simulation_active: bool = false
var network_status_text: String = "Local mode"
var network_mode_name: String = "Local"
var network_local_player_id: int = -1
var visual_effects: Array = []


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
	stage_number = 1
	wave_number = stage_number
	game_over = false
	winner_text = ""
	last_event_text = "Match seed %d" % match_seed
	simulation_active = true
	visual_effects.clear()
	_start_stage()


func reset_to_menu() -> void:
	players.clear()
	match_time = 0.0
	stage_number = 1
	wave_number = 1
	phase = MatchPhase.COMBAT
	stage_timer = 0.0
	spawn_timer = 0.0
	game_over = false
	winner_text = ""
	last_event_text = ""
	simulation_active = false
	network_mode_name = "Local"
	network_local_player_id = -1
	visual_effects.clear()


func _process(delta: float) -> void:
	if not simulation_active:
		return

	if game_over:
		return

	for player in players:
		player.tick(delta)

	if phase == MatchPhase.RELIC_SELECT:
		return

	match_time += delta
	_update_visual_effects(delta)
	_update_challenge_boss_timers()
	_update_combat(delta)
	_update_monsters(delta)
	_check_game_over()

	if game_over:
		return

	if phase == MatchPhase.COMBAT:
		_update_combat_phase(delta)
	elif phase == MatchPhase.CLEANUP:
		_update_cleanup_phase()


func select_cell(player_id: int, cell: Vector2i) -> void:
	if game_over or phase == MatchPhase.RELIC_SELECT:
		return
	if not _is_valid_player_id(player_id):
		return
	players[player_id].select_cell(cell)


func summon_tower(player_id: int) -> void:
	if game_over or phase == MatchPhase.RELIC_SELECT:
		return
	if not _is_valid_player_id(player_id):
		return
	players[player_id].summon_random_tower(rng)


func apply_player_command(command: Dictionary) -> void:
	var action := str(command.get("action", ""))
	var player_id := int(command.get("player_id", -1))

	match action:
		"select_cell":
			var cell := Vector2i(
				int(command.get("x", -1)),
				int(command.get("y", -1))
			)
			select_cell(player_id, cell)
		"summon":
			summon_tower(player_id)
		"merge":
			merge_selected_tower(player_id)
		"attack":
			send_attack_wave(player_id)
		"boss":
			summon_challenge_boss(player_id)
		"choose_relic":
			choose_relic(player_id, int(command.get("index", -1)))
		"reroll_relics":
			reroll_relics(player_id)
		"restart":
			start_match(int(command.get("seed", 0)))
		_:
			return


func merge_selected_tower(player_id: int) -> void:
	if game_over or phase == MatchPhase.RELIC_SELECT:
		return
	if not _is_valid_player_id(player_id):
		return
	players[player_id].merge_selected_tower()


func summon_challenge_boss(player_id: int) -> void:
	if game_over:
		return
	if not _is_valid_player_id(player_id):
		return

	var player: PlayerState = players[player_id]
	if phase != MatchPhase.COMBAT:
		player.set_message("Challenge bosses can only be summoned during combat.")
		return

	if player.challenge_boss_used_this_stage:
		player.set_message("Challenge boss already used this stage.")
		return

	var boss := MonsterData.new(MonsterData.MonsterType.CHALLENGE_BOSS, stage_number, 0.0)
	var time_bonus := player.get_relic_sum("boss_time_bonus", "seconds")
	boss.boss_time_limit += time_bonus
	player.monsters.append(boss)
	player.challenge_boss_used_this_stage = true
	player.challenge_boss_instance_id = boss.get_instance_id()
	player.challenge_boss_timer = boss.boss_time_limit
	player.set_message("Challenge boss summoned.")
	last_event_text = "%s challenged a boss." % player.display_name


func send_attack_wave(player_id: int) -> void:
	if game_over:
		return
	if not _is_valid_player_id(player_id):
		return

	var attacker: PlayerState = players[player_id]
	if phase != MatchPhase.COMBAT:
		attacker.set_message("Attack waves can only be sent during combat.")
		return

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

	var monster_count := ATTACK_WAVE_BASE_COUNT + int(floor(float(stage_number) / 3.0))
	monster_count = defender.consume_curse_defense_reduction(monster_count)

	for index in range(monster_count):
		var monster_type := primary_monster_type
		if secondary_tower_type >= 0 and index % 3 == 2:
			monster_type = secondary_monster_type
		_spawn_monster(defender, monster_type, 8.0 + float(index) * 12.0)

	if primary_monster_type == MonsterData.MonsterType.HEXED:
		defender.lock_random_tower(rng, 5.0 + attacker.get_hex_duration_bonus())

	if primary_monster_type == MonsterData.MonsterType.TOXIC:
		var slow_duration := attacker.get_relic_max("toxic_wave_tower_slow", "duration")
		if slow_duration > 0.0 and _player_has_tower_type(attacker, TowerData.TowerType.CURSE):
			defender.tower_slow_timer = maxf(defender.tower_slow_timer, slow_duration)
			defender.set_message("Plague Hex slowed towers.")

	var extra_hex_chance := attacker.get_relic_chance("extra_hex_monster_chance", "chance", TowerData.TowerType.CURSE)
	if extra_hex_chance > 0.0 and rng.randf() < extra_hex_chance:
		_spawn_monster(defender, MonsterData.MonsterType.HEXED, 48.0)

	var attack_name := MonsterData.get_display_name(primary_monster_type)
	last_event_text = "%s sent %s pressure to %s." % [
		attacker.display_name,
		attack_name,
		defender.display_name,
	]
	attacker.set_message("Sent %s wave." % attack_name)


func choose_relic(player_id: int, option_index: int) -> void:
	if phase != MatchPhase.RELIC_SELECT:
		return
	if not _is_valid_player_id(player_id):
		return

	var player: PlayerState = players[player_id]
	if player.relic_offer == null:
		return

	var relic := player.relic_offer.choose(option_index)
	if relic == null:
		return

	player.add_relic(relic)
	last_event_text = "%s picked %s." % [player.display_name, relic.relic_name]

	if _all_players_selected_relics():
		_start_next_stage()


func reroll_relics(player_id: int) -> void:
	if phase != MatchPhase.RELIC_SELECT:
		return
	if not _is_valid_player_id(player_id):
		return

	var player: PlayerState = players[player_id]
	if player.relic_offer == null or player.relic_offer.selected:
		return

	var cost := get_reroll_cost(player)
	var was_free := rng.randf() < player.get_free_reroll_chance()
	if not was_free:
		if player.gold < cost:
			player.set_message("Not enough gold to reroll.")
			return
		player.gold -= cost

	var new_options := relic_library.create_offer(rng, player, stage_number)
	player.relic_offer.replace_options(new_options, was_free)
	if was_free:
		player.set_message("Luck made reroll free.")
	else:
		player.set_message("Rerolled relics for %d gold." % cost)


func get_reroll_cost(player: PlayerState) -> int:
	return maxi(0, 50 + stage_number * 10 - player.get_reroll_discount())


func get_phase_name() -> String:
	match phase:
		MatchPhase.COMBAT:
			return "Combat"
		MatchPhase.CLEANUP:
			return "Cleanup"
		MatchPhase.RELIC_SELECT:
			return "Relic Select"
		MatchPhase.GAME_OVER:
			return "Game Over"
		_:
			return "Unknown"


func get_next_event_boss_stage() -> int:
	return int(ceil(float(stage_number) / 10.0)) * 10


func create_network_snapshot() -> Dictionary:
	var player_snapshots: Array = []
	for player in players:
		player_snapshots.append(player.to_snapshot())

	return {
		"match_seed": match_seed,
		"match_time": match_time,
		"stage_number": stage_number,
		"wave_number": wave_number,
		"phase": phase,
		"stage_timer": stage_timer,
		"spawn_timer": spawn_timer,
		"game_over": game_over,
		"winner_text": winner_text,
		"last_event_text": last_event_text,
		"players": player_snapshots,
		"visual_effects": visual_effects.duplicate(true),
	}


func apply_network_snapshot(snapshot: Dictionary) -> void:
	match_seed = int(snapshot.get("match_seed", match_seed))
	match_time = float(snapshot.get("match_time", 0.0))
	stage_number = int(snapshot.get("stage_number", 1))
	wave_number = int(snapshot.get("wave_number", stage_number))
	phase = int(snapshot.get("phase", MatchPhase.COMBAT))
	stage_timer = float(snapshot.get("stage_timer", 0.0))
	spawn_timer = float(snapshot.get("spawn_timer", 0.0))
	game_over = bool(snapshot.get("game_over", false))
	winner_text = str(snapshot.get("winner_text", ""))
	last_event_text = str(snapshot.get("last_event_text", ""))
	visual_effects = _snapshot_effects(snapshot.get("visual_effects", []))

	var player_snapshots: Variant = snapshot.get("players", [])
	if player_snapshots is Array:
		_ensure_player_count(player_snapshots.size())
		for index in range(mini(players.size(), player_snapshots.size())):
			if player_snapshots[index] is Dictionary:
				players[index].apply_snapshot(player_snapshots[index], relic_library)

	simulation_active = false


func set_network_view(mode_name: String, local_player_id: int, status_text: String) -> void:
	network_mode_name = mode_name
	network_local_player_id = local_player_id
	network_status_text = status_text


func _start_stage() -> void:
	phase = MatchPhase.COMBAT
	wave_number = stage_number
	stage_timer = _get_stage_duration()
	spawn_timer = 1.0

	for player in players:
		player.start_stage()

	if stage_number % 10 == 0:
		for player in players:
			_spawn_monster(player, MonsterData.MonsterType.EVENT_BOSS, 0.0)
		last_event_text = "Event bosses appeared."
	else:
		last_event_text = "Stage %d started." % stage_number


func _start_next_stage() -> void:
	stage_number += 1
	_start_stage()


func _get_stage_duration() -> float:
	return minf(48.0, STAGE_BASE_DURATION + float(stage_number - 1) * STAGE_DURATION_GAIN)


func _update_combat_phase(delta: float) -> void:
	stage_timer -= delta

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_regular_wave()
		spawn_timer = maxf(0.85, BASE_SPAWN_INTERVAL - float(stage_number - 1) * 0.06)

	if stage_timer <= 0.0:
		phase = MatchPhase.CLEANUP
		stage_timer = 0.0
		last_event_text = "Stage %d cleanup started." % stage_number


func _update_cleanup_phase() -> void:
	if _all_monsters_cleared():
		_enter_relic_select()


func _enter_relic_select() -> void:
	phase = MatchPhase.RELIC_SELECT
	for player in players:
		var bonus_gold := STAGE_COMPLETE_GOLD + int(player.get_relic_sum("stage_gold_bonus", "amount"))
		player.gold += bonus_gold
		player.relic_offer = RelicOffer.new(relic_library.create_offer(rng, player, stage_number))
		player.set_message("Stage clear +%d gold." % bonus_gold)
	last_event_text = "Both players choose a relic."


func _spawn_regular_wave() -> void:
	for player in players:
		_spawn_monster(player, MonsterData.MonsterType.BASIC, rng.randf_range(-8.0, 8.0))


func _spawn_monster(player: PlayerState, monster_type: int, lane_offset: float = 0.0) -> void:
	var monster := MonsterData.new(monster_type, stage_number, lane_offset)
	player.monsters.append(monster)
	_add_monster_effect("spawn", player.player_id, monster, monster_type, 22.0)


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

			_apply_tower_attack(player, cell, tower, target)
			if not target.is_dead() and _should_double_attack(player, tower):
				_apply_tower_attack(player, cell, tower, target)
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


func _apply_tower_attack(player: PlayerState, cell: Vector2i, tower: TowerData, target: MonsterData) -> void:
	var damage := tower.get_damage()
	damage *= _get_tower_damage_multiplier(player, tower, target)
	damage *= _get_repeat_target_multiplier(player, tower, target)

	target.last_hit_tower_type = tower.tower_type
	target.take_damage(damage)
	_add_attack_effect(player.player_id, cell, target, tower.tower_type)

	if tower.tower_type == TowerData.TowerType.CURSE:
		var gauge_bonus := tower.get_gauge_bonus()
		gauge_bonus *= player.get_relic_multiplier("curse_gauge_mult", "multiplier", TowerData.TowerType.CURSE)
		player.attack_gauge = minf(PlayerState.ATTACK_GAUGE_COST, player.attack_gauge + gauge_bonus)
		player.add_curse_defense_stack()
	else:
		player.attack_gauge = minf(PlayerState.ATTACK_GAUGE_COST, player.attack_gauge + tower.get_gauge_bonus())

	match tower.tower_type:
		TowerData.TowerType.POISON:
			_apply_poison_attack(player, tower, target, damage)
		TowerData.TowerType.ICE:
			_apply_ice_attack(player, tower, target)
		TowerData.TowerType.LIGHTNING:
			_apply_lightning_attack(player, target, damage)
		TowerData.TowerType.CURSE:
			target.add_slow(0.8, 0.78)
			_add_burst_effect(player.player_id, target, tower.tower_type, 30.0)


func _apply_poison_attack(player: PlayerState, tower: TowerData, target: MonsterData, damage: float) -> void:
	var duration := 3.0 * player.get_relic_multiplier("poison_duration_mult", "multiplier", TowerData.TowerType.POISON)
	var poison_damage := damage * 0.35
	target.add_poison(duration, poison_damage)
	_add_burst_effect(player.player_id, target, TowerData.TowerType.POISON, 24.0)

	var immediate_ratio := player.get_relic_max("poison_immediate_damage_ratio", "ratio")
	if immediate_ratio > 0.0 and _player_has_tower_type(player, TowerData.TowerType.FIRE):
		target.take_damage(damage * immediate_ratio)

	var extra_chance := player.get_relic_chance("extra_poison_chance", "chance", TowerData.TowerType.POISON)
	if extra_chance > 0.0 and rng.randf() < extra_chance:
		var bonus_damage_ratio := player.get_relic_max("extra_poison_chance", "bonus_damage_ratio", TowerData.TowerType.POISON)
		target.take_damage(damage * bonus_damage_ratio)
		target.add_poison(duration, poison_damage * 1.35)


func _apply_ice_attack(player: PlayerState, tower: TowerData, target: MonsterData) -> void:
	var duration := (1.4 + float(tower.level) * 0.2)
	duration *= player.get_relic_multiplier("slow_duration_mult", "multiplier", TowerData.TowerType.ICE)
	target.add_slow(duration, 0.58)
	_add_burst_effect(player.player_id, target, TowerData.TowerType.ICE, 26.0)

	var freeze_chance := player.get_relic_chance("ice_freeze_chance", "chance", TowerData.TowerType.ICE)
	if freeze_chance > 0.0 and rng.randf() < freeze_chance:
		var freeze_duration := player.get_relic_max("ice_freeze_chance", "duration", TowerData.TowerType.ICE)
		target.add_freeze(freeze_duration)


func _apply_lightning_attack(player: PlayerState, target: MonsterData, damage: float) -> void:
	_register_lightning_hit(player, target)
	var chain_damage := damage * 0.45
	chain_damage *= player.get_relic_multiplier("chain_damage_mult", "multiplier", TowerData.TowerType.LIGHTNING)
	if target.slow_timer > 0.0 and _player_has_tower_type(player, TowerData.TowerType.ICE):
		chain_damage *= player.get_relic_multiplier("chain_damage_vs_slow", "multiplier")
	_chain_lightning(player, target, chain_damage)


func _get_tower_damage_multiplier(player: PlayerState, tower: TowerData, target: MonsterData) -> float:
	var multiplier := player.get_relic_multiplier("damage_multiplier", "multiplier", tower.tower_type)

	for relic in player.relics:
		if relic.effect_type == "conditional_damage" and relic.targets_tower_type(tower.tower_type):
			if int(relic.values.get("monster_type", -1)) == target.monster_type:
				multiplier *= float(relic.values.get("multiplier", 1.0))

	if target.slow_timer > 0.0:
		multiplier *= player.get_relic_multiplier("slow_damage_taken_mult", "multiplier", TowerData.TowerType.ICE)

	return multiplier


func _get_repeat_target_multiplier(player: PlayerState, tower: TowerData, target: MonsterData) -> float:
	if tower.tower_type != TowerData.TowerType.FIRE:
		return 1.0

	var target_id := target.get_instance_id()
	if tower.last_target_instance_id == target_id:
		tower.repeat_target_hits += 1
	else:
		tower.last_target_instance_id = target_id
		tower.repeat_target_hits = 1

	var step := player.get_relic_max("repeat_target_damage", "step", TowerData.TowerType.FIRE)
	var max_bonus := player.get_relic_max("repeat_target_damage", "max_bonus", TowerData.TowerType.FIRE)
	if step <= 0.0:
		return 1.0

	return 1.0 + minf(max_bonus, step * float(maxi(0, tower.repeat_target_hits - 1)))


func _should_double_attack(player: PlayerState, tower: TowerData) -> bool:
	var min_level := int(player.get_relic_max("high_level_double_attack", "min_level"))
	if min_level <= 0 or tower.level < min_level:
		return false
	if not _player_has_tower_type(player, TowerData.TowerType.FIRE):
		return false
	if not _player_has_tower_type(player, TowerData.TowerType.LIGHTNING):
		return false

	var chance := player.get_relic_chance("high_level_double_attack", "chance")
	return chance > 0.0 and rng.randf() < chance


func _register_lightning_hit(player: PlayerState, target: MonsterData) -> void:
	target.lightning_hit_count += 1
	var threshold := int(player.get_relic_max("lightning_repeat_hit_explosion", "threshold", TowerData.TowerType.LIGHTNING))
	if threshold <= 0 or target.lightning_hit_count < threshold:
		return

	target.lightning_hit_count = 0
	var damage := player.get_relic_max("lightning_repeat_hit_explosion", "damage", TowerData.TowerType.LIGHTNING)
	var radius := player.get_relic_max("lightning_repeat_hit_explosion", "radius", TowerData.TowerType.LIGHTNING)
	_damage_monsters_near_progress(player, target.progress, radius, damage, target)
	_add_burst_effect(player.player_id, target, TowerData.TowerType.LIGHTNING, radius)


func _chain_lightning(player: PlayerState, first_target: MonsterData, damage: float) -> void:
	var hit_count := 0
	var hit_limit := 2 + int(player.get_relic_sum("chain_extra_hits", "extra_hits", TowerData.TowerType.LIGHTNING))

	for monster in player.monsters:
		if monster == first_target:
			continue
		if absf(monster.progress - first_target.progress) > 65.0:
			continue
		var chain_damage := damage
		if monster.slow_timer > 0.0 and _player_has_tower_type(player, TowerData.TowerType.ICE):
			chain_damage *= player.get_relic_multiplier("chain_damage_vs_slow", "multiplier")
		monster.last_hit_tower_type = TowerData.TowerType.LIGHTNING
		monster.take_damage(chain_damage)
		_register_lightning_hit(player, monster)
		_add_chain_effect(player.player_id, first_target, monster, TowerData.TowerType.LIGHTNING)
		hit_count += 1
		if hit_count >= hit_limit:
			return


func _update_monsters(delta: float) -> void:
	for player in players:
		for index in range(player.monsters.size() - 1, -1, -1):
			var monster: MonsterData = player.monsters[index]
			monster.update_effects(delta)
			monster.advance(delta)

			if monster.is_dead():
				_handle_monster_death(player, monster)
				_add_monster_effect("death", player.player_id, monster, monster.monster_type, 34.0)
				player.monsters.remove_at(index)
				continue

			if monster.progress >= PATH_LENGTH:
				player.hp -= monster.damage_to_base
				if _is_active_challenge_boss(player, monster):
					_fail_challenge_boss(player)
				else:
					player.set_message("%s leaked." % MonsterData.get_display_name(monster.monster_type))
				_add_monster_effect("leak", player.player_id, monster, monster.monster_type, 42.0)
				player.monsters.remove_at(index)


func _handle_monster_death(player: PlayerState, monster: MonsterData) -> void:
	var reward_gold := monster.reward_gold
	var reward_gauge := monster.reward_gauge

	if monster.monster_type == MonsterData.MonsterType.CHALLENGE_BOSS:
		var boss_multiplier := player.get_boss_reward_multiplier()
		var time_ratio := 0.0
		if monster.boss_time_limit > 0.0:
			time_ratio = clampf(player.challenge_boss_timer / monster.boss_time_limit, 0.0, 1.0)
		reward_gold += int((40.0 + 60.0 * time_ratio) * boss_multiplier)
		reward_gauge += (25.0 + 35.0 * time_ratio) * boss_multiplier
		player.challenge_boss_instance_id = 0
		player.challenge_boss_timer = 0.0
		player.set_message("Challenge boss defeated.")
	elif monster.monster_type == MonsterData.MonsterType.EVENT_BOSS:
		var event_multiplier := player.get_boss_reward_multiplier()
		reward_gold += int(90.0 * event_multiplier)
		reward_gauge += 55.0 * event_multiplier
		player.set_message("Event boss defeated.")

	player.add_rewards(reward_gold, reward_gauge)

	if monster.last_hit_tower_type == TowerData.TowerType.FIRE:
		_apply_fire_death_effects(player, monster)
	elif monster.last_hit_tower_type == TowerData.TowerType.LIGHTNING:
		var gauge_bonus := player.get_relic_sum("lightning_kill_gauge", "amount", TowerData.TowerType.LIGHTNING)
		if gauge_bonus > 0.0:
			player.attack_gauge = minf(PlayerState.ATTACK_GAUGE_COST, player.attack_gauge + gauge_bonus)

	if monster.was_poisoned:
		_apply_poison_death_effects(player, monster)

	if monster.was_frozen:
		_apply_frozen_death_effects(player, monster)

	if monster.monster_type == MonsterData.MonsterType.TOXIC:
		player.tower_slow_timer = maxf(player.tower_slow_timer, 3.0)
		player.set_message("Toxic residue slowed towers.")
	elif monster.monster_type == MonsterData.MonsterType.FROST:
		player.tower_slow_timer = maxf(player.tower_slow_timer, 2.0)
		player.set_message("Frost armor chilled towers.")


func _apply_fire_death_effects(player: PlayerState, monster: MonsterData) -> void:
	var damage := player.get_relic_max("death_explosion", "damage", TowerData.TowerType.FIRE)
	var radius := player.get_relic_max("death_explosion", "radius", TowerData.TowerType.FIRE)
	if damage <= 0.0 or radius <= 0.0:
		return
	_damage_monsters_near_progress(player, monster.progress, radius, damage, monster)


func _apply_poison_death_effects(player: PlayerState, monster: MonsterData) -> void:
	var burst_damage := player.get_relic_max("poison_death_burst", "damage", TowerData.TowerType.POISON)
	var burst_radius := player.get_relic_max("poison_death_burst", "radius", TowerData.TowerType.POISON)
	var pulses := int(player.get_relic_max("poison_death_burst", "pulses", TowerData.TowerType.POISON))
	var duration := player.get_relic_max("poison_death_burst", "duration", TowerData.TowerType.POISON)
	if burst_damage > 0.0 and burst_radius > 0.0:
		for pulse_index in range(maxi(1, pulses)):
			_poison_monsters_near_progress(player, monster.progress, burst_radius, burst_damage, duration, monster)

	var spread_count := int(player.get_relic_max("poison_spread_on_death", "count", TowerData.TowerType.POISON))
	if spread_count <= 0:
		return

	var spread_duration := player.get_relic_max("poison_spread_on_death", "duration", TowerData.TowerType.POISON)
	var spread_dps := player.get_relic_max("poison_spread_on_death", "dps", TowerData.TowerType.POISON)
	var nearest := _find_nearest_monsters(player, monster.progress, spread_count, monster)
	for target in nearest:
		target.add_poison(spread_duration, spread_dps)


func _apply_frozen_death_effects(player: PlayerState, monster: MonsterData) -> void:
	var radius := player.get_relic_max("freeze_death_slow", "radius", TowerData.TowerType.ICE)
	var duration := player.get_relic_max("freeze_death_slow", "duration", TowerData.TowerType.ICE)
	var multiplier := player.get_relic_max("freeze_death_slow", "multiplier", TowerData.TowerType.ICE)
	if radius <= 0.0 or duration <= 0.0:
		return

	for target in player.monsters:
		if target == monster:
			continue
		if absf(target.progress - monster.progress) > radius:
			continue
		target.add_slow(duration, multiplier)


func _damage_monsters_near_progress(
	player: PlayerState,
	origin_progress: float,
	radius: float,
	damage: float,
	source: MonsterData
) -> void:
	for target in player.monsters:
		if target == source:
			continue
		if absf(target.progress - origin_progress) > radius:
			continue
		target.take_damage(damage)


func _poison_monsters_near_progress(
	player: PlayerState,
	origin_progress: float,
	radius: float,
	damage: float,
	duration: float,
	source: MonsterData
) -> void:
	for target in player.monsters:
		if target == source:
			continue
		if absf(target.progress - origin_progress) > radius:
			continue
		target.take_damage(damage)
		target.add_poison(duration, damage * 0.25)


func _find_nearest_monsters(player: PlayerState, origin_progress: float, count: int, source: MonsterData) -> Array:
	var nearest: Array = []
	for target in player.monsters:
		if target == source:
			continue
		_insert_nearest_monster(nearest, target, origin_progress, count)
	return nearest


func _update_visual_effects(delta: float) -> void:
	for index in range(visual_effects.size() - 1, -1, -1):
		var effect: Dictionary = visual_effects[index]
		effect["age"] = float(effect.get("age", 0.0)) + delta
		if float(effect["age"]) >= float(effect.get("duration", EFFECT_MAX_AGE)):
			visual_effects.remove_at(index)
		else:
			visual_effects[index] = effect


func _add_attack_effect(player_id: int, cell: Vector2i, target: MonsterData, tower_type: int) -> void:
	_add_effect({
		"kind": "attack",
		"player_id": player_id,
		"tower_type": tower_type,
		"cell_x": cell.x,
		"cell_y": cell.y,
		"progress": target.progress,
		"lane_offset": target.lane_offset,
		"age": 0.0,
		"duration": 0.28,
		"radius": 18.0,
	})


func _add_chain_effect(player_id: int, source: MonsterData, target: MonsterData, tower_type: int) -> void:
	_add_effect({
		"kind": "chain",
		"player_id": player_id,
		"tower_type": tower_type,
		"from_progress": source.progress,
		"from_lane_offset": source.lane_offset,
		"progress": target.progress,
		"lane_offset": target.lane_offset,
		"age": 0.0,
		"duration": 0.24,
		"radius": 18.0,
	})


func _add_burst_effect(player_id: int, target: MonsterData, tower_type: int, radius: float) -> void:
	_add_effect({
		"kind": "burst",
		"player_id": player_id,
		"tower_type": tower_type,
		"progress": target.progress,
		"lane_offset": target.lane_offset,
		"age": 0.0,
		"duration": 0.42,
		"radius": radius,
	})


func _add_monster_effect(kind: String, player_id: int, monster: MonsterData, monster_type: int, radius: float) -> void:
	_add_effect({
		"kind": kind,
		"player_id": player_id,
		"monster_type": monster_type,
		"progress": monster.progress,
		"lane_offset": monster.lane_offset,
		"age": 0.0,
		"duration": 0.45,
		"radius": radius,
	})


func _add_effect(effect: Dictionary) -> void:
	visual_effects.append(effect)
	while visual_effects.size() > EFFECT_MAX_COUNT:
		visual_effects.pop_front()


func _snapshot_effects(value: Variant) -> Array:
	var effects: Array = []
	if not (value is Array):
		return effects

	for effect in value:
		if effect is Dictionary:
			effects.append(effect.duplicate(true))
	return effects


func _insert_nearest_monster(nearest: Array, target: MonsterData, origin_progress: float, limit: int) -> void:
	var inserted := false
	var distance := absf(target.progress - origin_progress)
	for index in range(nearest.size()):
		var existing: MonsterData = nearest[index]
		var existing_distance := absf(existing.progress - origin_progress)
		if distance < existing_distance:
			nearest.insert(index, target)
			inserted = true
			break

	if not inserted:
		nearest.append(target)

	while nearest.size() > limit:
		nearest.pop_back()


func _update_challenge_boss_timers() -> void:
	for player in players:
		if player.challenge_boss_instance_id == 0:
			continue
		if player.challenge_boss_timer > 0.0:
			continue

		var boss := _find_monster_by_instance_id(player, player.challenge_boss_instance_id)
		if boss != null:
			player.monsters.erase(boss)

		_fail_challenge_boss(player)


func _find_monster_by_instance_id(player: PlayerState, instance_id: int) -> MonsterData:
	for monster in player.monsters:
		if monster.get_instance_id() == instance_id:
			return monster
	return null


func _is_active_challenge_boss(player: PlayerState, monster: MonsterData) -> bool:
	return player.challenge_boss_instance_id != 0 and monster.get_instance_id() == player.challenge_boss_instance_id


func _fail_challenge_boss(player: PlayerState) -> void:
	var penalty_duration := 8.0 * player.get_boss_penalty_multiplier()
	player.pending_boss_penalty_timer = maxf(player.pending_boss_penalty_timer, penalty_duration)
	player.challenge_boss_instance_id = 0
	player.challenge_boss_timer = 0.0
	player.set_message("Boss failed. Next stage penalty queued.")


func _all_monsters_cleared() -> bool:
	for player in players:
		if not player.monsters.is_empty():
			return false
	return true


func _all_players_selected_relics() -> bool:
	for player in players:
		if player.relic_offer == null:
			return false
		if not player.relic_offer.selected:
			return false
	return true


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
		phase = MatchPhase.GAME_OVER
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


func _player_has_tower_type(player: PlayerState, tower_type: int) -> bool:
	for y in range(PlayerState.GRID_SIZE):
		for x in range(PlayerState.GRID_SIZE):
			var tower := player.get_tower(Vector2i(x, y))
			if tower != null and tower.tower_type == tower_type:
				return true
	return false


func _ensure_player_count(count: int) -> void:
	while players.size() < count:
		var player_id := players.size()
		players.append(PlayerState.new(player_id, "Player %d" % (player_id + 1)))


func _is_valid_player_id(player_id: int) -> bool:
	return player_id >= 0 and player_id < players.size()
