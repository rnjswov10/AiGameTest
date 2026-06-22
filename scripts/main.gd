extends Node2D

@onready var status_label: Label = $Status


func _ready() -> void:
	status_label.text = "Godot 4.7 GDScript collaboration setup is ready."


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("player_interact"):
		status_label.text = "Input OK: player_interact"
