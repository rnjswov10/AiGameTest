class_name TowerData
extends RefCounted

enum TowerType {
	FIRE,
	POISON,
	ICE,
	LIGHTNING,
	CURSE,
}

const TYPE_COUNT := 5
const MAX_LEVEL := 5

var tower_type: int = TowerType.FIRE
var level: int = 1
var cooldown: float = 0.0


func _init(initial_type: int = TowerType.FIRE, initial_level: int = 1) -> void:
	tower_type = initial_type
	level = clampi(initial_level, 1, MAX_LEVEL)


func can_merge_with(other: TowerData) -> bool:
	if other == null:
		return false
	if level >= MAX_LEVEL:
		return false
	return tower_type == other.tower_type and level == other.level


func make_upgraded() -> TowerData:
	return TowerData.new(tower_type, level + 1)


func get_damage() -> float:
	var base_damage := 10.0
	match tower_type:
		TowerType.FIRE:
			base_damage = 17.0
		TowerType.POISON:
			base_damage = 8.0
		TowerType.ICE:
			base_damage = 9.0
		TowerType.LIGHTNING:
			base_damage = 11.0
		TowerType.CURSE:
			base_damage = 7.0

	return base_damage * pow(1.55, float(level - 1))


func get_attack_interval() -> float:
	var base_interval := 0.85
	match tower_type:
		TowerType.FIRE:
			base_interval = 1.05
		TowerType.POISON:
			base_interval = 0.95
		TowerType.ICE:
			base_interval = 1.05
		TowerType.LIGHTNING:
			base_interval = 0.80
		TowerType.CURSE:
			base_interval = 0.75

	return maxf(0.28, base_interval - float(level - 1) * 0.07)


func get_range_cells() -> float:
	return 6.0 + float(level) * 0.15


func get_gauge_bonus() -> float:
	if tower_type == TowerType.CURSE:
		return 2.0 + float(level) * 0.5
	return 0.0


static func get_color(value: int) -> Color:
	match value:
		TowerType.FIRE:
			return Color(0.95, 0.23, 0.15)
		TowerType.POISON:
			return Color(0.20, 0.80, 0.32)
		TowerType.ICE:
			return Color(0.20, 0.55, 1.00)
		TowerType.LIGHTNING:
			return Color(1.00, 0.83, 0.18)
		TowerType.CURSE:
			return Color(0.62, 0.28, 0.95)
		_:
			return Color.WHITE


static func get_display_name(value: int) -> String:
	match value:
		TowerType.FIRE:
			return "Fire"
		TowerType.POISON:
			return "Poison"
		TowerType.ICE:
			return "Ice"
		TowerType.LIGHTNING:
			return "Lightning"
		TowerType.CURSE:
			return "Curse"
		_:
			return "Unknown"
