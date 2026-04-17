extends "res://scripts/levels/level_base.gd"


func _apply_level_config() -> void:
	level_number = 1
	door_piece_local_position = Vector2(30.0, 33.0)
	door_padding_right = 2.0
	door_padding_bottom = 1.0

	# Add or remove entries here to change block count for this level.
	level_blocks = [
		{
			"name": "StartPiece",
			"role": BLOCK_ROLE_START,
			"sides": [SIDE_CLOSED, SIDE_OUT, SIDE_CLOSED, SIDE_CLOSED],
			"draggable": false,
			"cell": Vector2i(3, 3),
		},
		{
			"name": "EndPiece",
			"role": BLOCK_ROLE_END,
			"sides": [SIDE_CLOSED, SIDE_CLOSED, SIDE_CLOSED, SIDE_IN],
			"draggable": false,
			"cell": Vector2i(5, 3),
		},
		{
			"name": "Connector01",
			"role": BLOCK_ROLE_NORMAL,
			"sides": [SIDE_CLOSED, SIDE_OUT, SIDE_CLOSED, SIDE_IN],
			"draggable": true,
			"spawn_cell": Vector2i(6, 2),
			# Optional style override per block:
			# "style": {
			# 	"base_texture": TEX_PUZZLE_IN4,
			# 	"out_texture": TEX_PUZZLE_OUT,
			# 	"close_texture": TEX_PUZZLE_CLOSE,
			# },
		},
	]
