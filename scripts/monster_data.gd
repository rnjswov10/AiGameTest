class_name MonsterData
extends RefCounted

enum MonsterType {
	BASIC,
	ARMORED,
	TOXIC,
	FROST,
	BLINK,
	HEXED,
	CHALLENGE_BOSS,
	EVENT_BOSS,
}

var monster_type: int = MonsterType.BASIC
var max_hp: float = 40.0
var hp: float = 40.0
var speed: float = 35.0
var reward_gold: int = 8
var reward_gauge: float = 8.0
var damage_to_base: int = 1
var progress: float = 0.0
var lane_offset: float = 0.0
var poison_timer: float = 0.0
var poison_damage_per_second: float = 0.0
var slow_timer: float = 0.0
var slow_multiplier: float = 1.0
var freeze_timer: float = 0.0
var blink_timer: float = 2.2
var was_poisoned: bool = false
var was_frozen: bool = false
var last_hit_tower_type: int = -1
var lightning_hit_count: int = 0
var boss_time_limit: float = 0.0
var boss_elapsed_time: float = 0.0


func _init(initial_type: int = MonsterType.BASIC, wave_level: int = 1, offset: float = 0.0) -> void:
	monster_type = initial_type
	lane_offset = offset
	_apply_stats(wave_level)


func _apply_stats(wave_level: int) -> void:
	var wave_scale := 1.0 + float(maxi(wave_level - 1, 0)) * 0.16

	match monster_type:
		MonsterType.BASIC:
			max_hp = 42.0 * wave_scale
			speed = 35.0
			reward_gold = 8
			reward_gauge = 7.0
		MonsterType.ARMORED:
			max_hp = 84.0 * wave_scale
			speed = 25.0
			reward_gold = 13
			reward_gauge = 12.0
		MonsterType.TOXIC:
			max_hp = 52.0 * wave_scale
			speed = 32.0
			reward_gold = 10
			reward_gauge = 10.0
		MonsterType.FROST:
			max_hp = 68.0 * wave_scale
			speed = 24.0
			reward_gold = 12
			reward_gauge = 11.0
		MonsterType.BLINK:
			max_hp = 40.0 * wave_scale
			speed = 41.0
			reward_gold = 11
			reward_gauge = 11.0
			blink_timer = 1.8
		MonsterType.HEXED:
			max_hp = 58.0 * wave_scale
			speed = 29.0
			reward_gold = 12
			reward_gauge = 13.0
		MonsterType.CHALLENGE_BOSS:
			max_hp = 220.0 * wave_scale
			speed = 13.0
			reward_gold = 90
			reward_gauge = 55.0
			damage_to_base = 3
			boss_time_limit = 28.0
		MonsterType.EVENT_BOSS:
			max_hp = 360.0 * wave_scale
			speed = 11.0
			reward_gold = 130
			reward_gauge = 75.0
			damage_to_base = 5
			boss_time_limit = 0.0

	hp = max_hp


func update_effects(delta: float) -> void:
	if poison_timer > 0.0:
		hp -= poison_damage_per_second * delta
		poison_timer = maxf(0.0, poison_timer - delta)

	if slow_timer > 0.0:
		slow_timer = maxf(0.0, slow_timer - delta)
		if slow_timer <= 0.0:
			slow_multiplier = 1.0

	if freeze_timer > 0.0:
		freeze_timer = maxf(0.0, freeze_timer - delta)


func advance(delta: float) -> void:
	if freeze_timer > 0.0:
		return

	var speed_multiplier := slow_multiplier
	progress += speed * speed_multiplier * delta

	if monster_type == MonsterType.BLINK:
		blink_timer -= delta
		if blink_timer <= 0.0:
			progress += 24.0
			blink_timer = 2.2


func take_damage(amount: float) -> void:
	hp -= amount


func add_poison(duration: float, damage_per_second: float) -> void:
	was_poisoned = true
	poison_timer = maxf(poison_timer, duration)
	poison_damage_per_second = maxf(poison_damage_per_second, damage_per_second)


func add_slow(duration: float, multiplier: float) -> void:
	slow_timer = maxf(slow_timer, duration)
	slow_multiplier = minf(slow_multiplier, multiplier)


func add_freeze(duration: float) -> void:
	was_frozen = true
	freeze_timer = maxf(freeze_timer, duration)


func is_dead() -> bool:
	return hp <= 0.0


static func get_color(value: int) -> Color:
	match value:
		MonsterType.BASIC:
			return Color(0.85, 0.87, 0.90)
		MonsterType.ARMORED:
			return Color(0.95, 0.36, 0.25)
		MonsterType.TOXIC:
			return Color(0.25, 0.95, 0.38)
		MonsterType.FROST:
			return Color(0.30, 0.72, 1.00)
		MonsterType.BLINK:
			return Color(1.00, 0.88, 0.18)
		MonsterType.HEXED:
			return Color(0.72, 0.38, 1.00)
		MonsterType.CHALLENGE_BOSS:
			return Color(1.00, 0.43, 0.16)
		MonsterType.EVENT_BOSS:
			return Color(1.00, 0.12, 0.32)
		_:
			return Color.WHITE


static func get_display_name(value: int) -> String:
	match value:
		MonsterType.BASIC:
			return "Basic"
		MonsterType.ARMORED:
			return "Armored"
		MonsterType.TOXIC:
			return "Toxic"
		MonsterType.FROST:
			return "Frost"
		MonsterType.BLINK:
			return "Blink"
		MonsterType.HEXED:
			return "Hex"
		MonsterType.CHALLENGE_BOSS:
			return "Boss"
		MonsterType.EVENT_BOSS:
			return "Event Boss"
		_:
			return "Unknown"
