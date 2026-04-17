extends "res://scripts/levels/level_base.gd"


func _apply_level_config() -> void:
	level_number = 1
	start_cell = Vector2i(2, 2)
	end_cell = Vector2i(4, 2)
	door_piece_local_position = Vector2(30.0, 33.0)