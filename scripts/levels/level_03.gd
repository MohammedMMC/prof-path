@tool
extends "res://scripts/levels/level_base.gd"


func _apply_level_config() -> void:
	level_number = 3
	door_piece_local_position = Vector2(30.0, 33.0)
	door_padding_right = 2.0
	door_padding_bottom = 1.0
	use_scene_level_pieces = true
	level_blocks = []
