class_name RelicData
extends RefCounted

enum Rarity {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

const ANY_TOWER := -1

var id: String = ""
var relic_name: String = ""
var rarity: int = Rarity.COMMON
var tags: Array = []
var target_tower_type: int = ANY_TOWER
var effect_type: String = ""
var values: Dictionary = {}
var description: String = ""


func _init(
	initial_id: String = "",
	initial_name: String = "",
	initial_rarity: int = Rarity.COMMON,
	initial_tags: Array = [],
	initial_target_tower_type: int = ANY_TOWER,
	initial_effect_type: String = "",
	initial_values: Dictionary = {},
	initial_description: String = ""
) -> void:
	id = initial_id
	relic_name = initial_name
	rarity = initial_rarity
	tags = initial_tags.duplicate()
	target_tower_type = initial_target_tower_type
	effect_type = initial_effect_type
	values = initial_values.duplicate()
	description = initial_description


func targets_tower_type(tower_type: int) -> bool:
	return target_tower_type == ANY_TOWER or target_tower_type == tower_type


static func get_rarity_name(value: int) -> String:
	match value:
		Rarity.COMMON:
			return "Common"
		Rarity.RARE:
			return "Rare"
		Rarity.EPIC:
			return "Epic"
		Rarity.LEGENDARY:
			return "Legendary"
		_:
			return "Unknown"


static func get_rarity_color(value: int) -> Color:
	match value:
		Rarity.COMMON:
			return Color(0.78, 0.82, 0.86)
		Rarity.RARE:
			return Color(0.36, 0.62, 1.00)
		Rarity.EPIC:
			return Color(0.74, 0.36, 1.00)
		Rarity.LEGENDARY:
			return Color(1.00, 0.72, 0.20)
		_:
			return Color.WHITE
