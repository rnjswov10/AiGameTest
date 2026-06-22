extends Node2D

var match_controller: MatchController
var board_view: BoardView


func _ready() -> void:
	match_controller = MatchController.new()
	add_child(match_controller)
	match_controller.start_match()

	board_view = BoardView.new()
	add_child(board_view)
	board_view.set_match_controller(match_controller)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_input(event)
		return

	if event is InputEventKey:
		_handle_key_input(event)


func _handle_mouse_input(event: InputEventMouseButton) -> void:
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return

	var hit_result := board_view.get_cell_at_position(event.position)
	if hit_result.is_empty():
		return

	var player_id: int = hit_result[0]
	var cell: Vector2i = hit_result[1]
	match_controller.select_cell(player_id, cell)
	get_viewport().set_input_as_handled()


func _handle_key_input(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_Q:
			match_controller.summon_tower(0)
		KEY_W:
			match_controller.merge_selected_tower(0)
		KEY_E:
			match_controller.send_attack_wave(0)
		KEY_I:
			match_controller.summon_tower(1)
		KEY_O:
			match_controller.merge_selected_tower(1)
		KEY_P:
			match_controller.send_attack_wave(1)
		KEY_R:
			match_controller.start_match()
		_:
			return

	get_viewport().set_input_as_handled()
