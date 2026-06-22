class_name RelicOffer
extends RefCounted

var options: Array = []
var selected: bool = false
var selected_relic: RelicData = null
var reroll_count: int = 0
var last_reroll_was_free: bool = false


func _init(initial_options: Array = []) -> void:
	options = initial_options.duplicate()


func choose(index: int) -> RelicData:
	if selected:
		return null
	if index < 0 or index >= options.size():
		return null

	selected = true
	selected_relic = options[index]
	return selected_relic


func replace_options(new_options: Array, was_free: bool) -> void:
	options = new_options.duplicate()
	selected = false
	selected_relic = null
	reroll_count += 1
	last_reroll_was_free = was_free
