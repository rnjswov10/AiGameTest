class_name RelicLibrary
extends RefCounted

const OFFER_COUNT := 3

var relics: Array = []


func _init() -> void:
	_build_catalog()


func create_offer(rng: RandomNumberGenerator, player: PlayerState, stage_number: int) -> Array:
	var offer: Array = []
	var guard := 0

	while offer.size() < OFFER_COUNT and guard < 80:
		guard += 1
		var rarity := _roll_rarity(rng, player.luck, stage_number)
		var candidate := _pick_relic_by_rarity(rng, player, offer, rarity)
		if candidate == null:
			candidate = _pick_any_available_relic(rng, player, offer)
		if candidate != null and not _offer_has_relic(offer, candidate.id):
			offer.append(candidate)

	return offer


func get_relic_by_id(relic_id: String) -> RelicData:
	for relic in relics:
		if relic.id == relic_id:
			return relic
	return null


func _build_catalog() -> void:
	relics.clear()

	_add("fire_damage_common", "Kindling Core", RelicData.Rarity.COMMON, ["fire"], TowerData.TowerType.FIRE, "damage_multiplier", {"multiplier": 1.15}, "Fire towers deal +15% damage.")
	_add("fire_armored_rare", "Molten Drill", RelicData.Rarity.RARE, ["fire"], TowerData.TowerType.FIRE, "conditional_damage", {"monster_type": MonsterData.MonsterType.ARMORED, "multiplier": 1.35}, "Fire towers hit armored monsters harder.")
	_add("fire_focus_epic", "Furnace Focus", RelicData.Rarity.EPIC, ["fire"], TowerData.TowerType.FIRE, "repeat_target_damage", {"step": 0.15, "max_bonus": 0.45}, "Fire towers gain damage on repeated targets.")
	_add("fire_blast_legendary", "Phoenix Cinder", RelicData.Rarity.LEGENDARY, ["fire"], TowerData.TowerType.FIRE, "death_explosion", {"radius": 74.0, "damage": 34.0}, "Fire kills explode near the death point.")

	_add("poison_duration_common", "Long Venom", RelicData.Rarity.COMMON, ["poison"], TowerData.TowerType.POISON, "poison_duration_mult", {"multiplier": 1.25}, "Poison lasts +25% longer.")
	_add("poison_double_rare", "Split Toxin", RelicData.Rarity.RARE, ["poison"], TowerData.TowerType.POISON, "extra_poison_chance", {"chance": 0.25, "bonus_damage_ratio": 0.35}, "Poison has a 25% chance to bite again.")
	_add("poison_burst_epic", "Bursting Spores", RelicData.Rarity.EPIC, ["poison"], TowerData.TowerType.POISON, "poison_death_burst", {"pulses": 2, "radius": 78.0, "damage": 16.0, "duration": 2.8}, "Poisoned deaths burst poison twice nearby.")
	_add("poison_spread_legendary", "Plague Crown", RelicData.Rarity.LEGENDARY, ["poison"], TowerData.TowerType.POISON, "poison_spread_on_death", {"count": 2, "duration": 4.0, "dps": 14.0}, "Poisoned deaths spread poison to nearby monsters.")

	_add("ice_duration_common", "Cold Snap", RelicData.Rarity.COMMON, ["ice"], TowerData.TowerType.ICE, "slow_duration_mult", {"multiplier": 1.20}, "Ice slow lasts +20% longer.")
	_add("ice_vulnerable_rare", "Cracked Armor", RelicData.Rarity.RARE, ["ice"], TowerData.TowerType.ICE, "slow_damage_taken_mult", {"multiplier": 1.10}, "Slowed monsters take +10% damage.")
	_add("ice_freeze_epic", "Deep Freeze", RelicData.Rarity.EPIC, ["ice"], TowerData.TowerType.ICE, "ice_freeze_chance", {"chance": 0.18, "duration": 0.8}, "Ice attacks can briefly freeze.")
	_add("ice_shatter_legendary", "Shatter Wake", RelicData.Rarity.LEGENDARY, ["ice"], TowerData.TowerType.ICE, "freeze_death_slow", {"radius": 82.0, "duration": 2.6, "multiplier": 0.52}, "Frozen deaths slow nearby monsters.")

	_add("lightning_chain_damage_common", "Bright Coil", RelicData.Rarity.COMMON, ["lightning"], TowerData.TowerType.LIGHTNING, "chain_damage_mult", {"multiplier": 1.15}, "Chain lightning deals +15% damage.")
	_add("lightning_extra_jump_rare", "Forked Bolt", RelicData.Rarity.RARE, ["lightning"], TowerData.TowerType.LIGHTNING, "chain_extra_hits", {"extra_hits": 1}, "Lightning chains to one extra monster.")
	_add("lightning_overload_epic", "Overload Mark", RelicData.Rarity.EPIC, ["lightning"], TowerData.TowerType.LIGHTNING, "lightning_repeat_hit_explosion", {"threshold": 3, "radius": 68.0, "damage": 24.0}, "Repeated lightning hits trigger an explosion.")
	_add("lightning_gauge_legendary", "Storm Battery", RelicData.Rarity.LEGENDARY, ["lightning"], TowerData.TowerType.LIGHTNING, "lightning_kill_gauge", {"amount": 18.0}, "Lightning kills grant bonus attack gauge.")

	_add("curse_gauge_common", "Hex Talisman", RelicData.Rarity.COMMON, ["curse"], TowerData.TowerType.CURSE, "curse_gauge_mult", {"multiplier": 1.20}, "Curse towers gain +20% attack gauge.")
	_add("curse_guard_rare", "Warding Sigil", RelicData.Rarity.RARE, ["curse"], TowerData.TowerType.CURSE, "curse_defense_stack", {"max_stacks": 5}, "Curse hits build defense against attack waves.")
	_add("curse_hex_duration_epic", "Long Hex", RelicData.Rarity.EPIC, ["curse"], TowerData.TowerType.CURSE, "hex_duration_bonus", {"duration_bonus": 2.0}, "Hex monsters lock towers for longer.")
	_add("curse_extra_hex_legendary", "Second Omen", RelicData.Rarity.LEGENDARY, ["curse"], TowerData.TowerType.CURSE, "extra_hex_monster_chance", {"chance": 0.35}, "Attack waves can add an extra Hex monster.")

	_add("hybrid_fire_poison", "Burning Venom", RelicData.Rarity.RARE, ["fire", "poison", "hybrid"], RelicData.ANY_TOWER, "poison_immediate_damage_ratio", {"ratio": 0.35}, "Poison also deals a burst of immediate damage.")
	_add("hybrid_ice_lightning", "Charged Chill", RelicData.Rarity.RARE, ["ice", "lightning", "hybrid"], RelicData.ANY_TOWER, "chain_damage_vs_slow", {"multiplier": 1.25}, "Lightning chains hit slowed monsters harder.")
	_add("hybrid_poison_curse", "Plague Hex", RelicData.Rarity.EPIC, ["poison", "curse", "hybrid"], RelicData.ANY_TOWER, "toxic_wave_tower_slow", {"duration": 3.5}, "Toxic attack waves slow enemy towers.")
	_add("hybrid_fire_lightning", "Overclock Rune", RelicData.Rarity.EPIC, ["fire", "lightning", "hybrid"], RelicData.ANY_TOWER, "high_level_double_attack", {"chance": 0.12, "min_level": 3}, "High-level towers can attack twice.")

	_add("economy_stage_gold", "Collector's Seal", RelicData.Rarity.COMMON, ["economy"], RelicData.ANY_TOWER, "stage_gold_bonus", {"amount": 25}, "Gain extra gold after each stage.")
	_add("economy_reroll_discount", "Lucky Coupon", RelicData.Rarity.RARE, ["economy"], RelicData.ANY_TOWER, "reroll_discount", {"amount": 20}, "Relic rerolls cost less gold.")
	_add("boss_timer", "Long Hunt Map", RelicData.Rarity.COMMON, ["boss"], RelicData.ANY_TOWER, "boss_time_bonus", {"seconds": 6.0}, "Challenge bosses allow more time.")
	_add("boss_bounty", "Hunter Contract", RelicData.Rarity.RARE, ["boss"], RelicData.ANY_TOWER, "boss_reward_mult", {"multiplier": 1.35}, "Boss rewards are increased.")
	_add("boss_grace", "Emergency Charm", RelicData.Rarity.COMMON, ["boss"], RelicData.ANY_TOWER, "boss_penalty_reduction", {"reduction": 0.5}, "Failed boss penalties are reduced.")


func _add(
	id: String,
	name: String,
	rarity: int,
	tags: Array,
	target_tower_type: int,
	effect_type: String,
	values: Dictionary,
	description: String
) -> void:
	relics.append(RelicData.new(id, name, rarity, tags, target_tower_type, effect_type, values, description))


func _roll_rarity(rng: RandomNumberGenerator, luck: int, stage_number: int) -> int:
	var luck_value := float(luck)
	var stage_bonus := minf(0.04, float(stage_number - 1) * 0.002)
	var legendary_chance := minf(0.05, 0.02 + luck_value * 0.0006 + stage_bonus * 0.25)
	var epic_chance := minf(0.16, 0.08 + luck_value * 0.0015 + stage_bonus)
	var rare_chance := minf(0.34, 0.25 + luck_value * 0.0025 + stage_bonus)
	var roll := rng.randf()

	if roll < legendary_chance:
		return RelicData.Rarity.LEGENDARY
	if roll < legendary_chance + epic_chance:
		return RelicData.Rarity.EPIC
	if roll < legendary_chance + epic_chance + rare_chance:
		return RelicData.Rarity.RARE
	return RelicData.Rarity.COMMON


func _pick_relic_by_rarity(rng: RandomNumberGenerator, player: PlayerState, current_offer: Array, rarity: int) -> RelicData:
	var candidates := []
	for relic in relics:
		if relic.rarity != rarity:
			continue
		if player.has_relic_id(relic.id):
			continue
		if _offer_has_relic(current_offer, relic.id):
			continue
		candidates.append(relic)

	if candidates.is_empty():
		return null

	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _pick_any_available_relic(rng: RandomNumberGenerator, player: PlayerState, current_offer: Array) -> RelicData:
	var candidates := []
	for relic in relics:
		if player.has_relic_id(relic.id):
			continue
		if _offer_has_relic(current_offer, relic.id):
			continue
		candidates.append(relic)

	if candidates.is_empty():
		return null

	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _offer_has_relic(offer: Array, relic_id: String) -> bool:
	for relic in offer:
		if relic.id == relic_id:
			return true
	return false
