extends Node2D


const GRID_ROWS := 5
const GRID_COLS := 8

const BOARD_ORIGIN := Vector2(8.0, 10.0)
const TRAY_ORIGIN := Vector2(248.0, 10.0)
const CELL_SIZE := 28.0

const TEX_PUZZLE_IN4 := preload("res://assets/puzzle/puzzle_in4.png")
const TEX_PUZZLE_CLOSE := preload("res://assets/puzzle/puzzle_close_part.png")
const TEX_PUZZLE_OUT := preload("res://assets/puzzle/puzzle_out_part.png")

const SIDE_TOP := 0
const SIDE_RIGHT := 1
const SIDE_BOTTOM := 2
const SIDE_LEFT := 3

const SIDE_IN := 0
const SIDE_OUT := 1
const SIDE_CLOSED := 2

const POINTER_NONE := -999
const POINTER_MOUSE := -1

@onready var panel: Panel = $Panel

var _rng := RandomNumberGenerator.new()
var _base_piece_size := 50.0
var _piece_scale := 1.0

var _pieces: Array[Node2D] = []
var _piece_data := {}
var _board_slots: Array = []

var _drag_piece: Node2D = null
var _drag_pointer_id := POINTER_NONE
var _drag_offset := Vector2.ZERO
var _drag_origin_cell := Vector2i(-1, -1)
var _drag_origin_pos := Vector2.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if $Panel/Background is Control:
		($Panel/Background as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	_rng.randomize()
	_base_piece_size = float(TEX_PUZZLE_IN4.get_height())
	_piece_scale = CELL_SIZE / _base_piece_size

	_init_board_slots()
	_build_piece_nodes()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_begin_drag(event.position, POINTER_MOUSE)
		else:
			_end_drag(event.position, POINTER_MOUSE)
		return

	if event is InputEventMouseMotion:
		_update_drag(event.position, POINTER_MOUSE)
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_try_begin_drag(event.position, event.index)
		else:
			_end_drag(event.position, event.index)
		return

	if event is InputEventScreenDrag:
		_update_drag(event.position, event.index)


func _init_board_slots() -> void:
	_board_slots.clear()
	for row in GRID_ROWS:
		var row_slots: Array = []
		for col in GRID_COLS:
			row_slots.append(null)
		_board_slots.append(row_slots)


func _build_piece_nodes() -> void:
	var side_map := _generate_side_map()
	var tray_cells: Array[Vector2i] = []

	for row in GRID_ROWS:
		for col in GRID_COLS:
			tray_cells.append(Vector2i(col, row))

	tray_cells.shuffle()

	var piece_id := 0
	for row in GRID_ROWS:
		for col in GRID_COLS:
			var sides: Array = side_map[row][col]
			var piece := _create_piece(piece_id, sides)
			_pieces.append(piece)
			add_child(piece)

			var tray_cell: Vector2i = tray_cells[piece_id]
			piece.position = _tray_cell_to_position(tray_cell)

			_piece_data[piece] = {
				"sides": sides.duplicate(),
				"cell": Vector2i(-1, -1),
			}

			piece_id += 1


func _create_piece(piece_id: int, sides: Array) -> Node2D:
	var piece := Node2D.new()
	piece.name = "Piece_%02d" % piece_id
	piece.scale = Vector2.ONE * _piece_scale
	piece.z_index = 1

	var base_sprite := Sprite2D.new()
	base_sprite.texture = TEX_PUZZLE_IN4
	base_sprite.centered = false
	piece.add_child(base_sprite)

	_add_side_overlay_if_needed(piece, sides[SIDE_TOP], SIDE_TOP)
	_add_side_overlay_if_needed(piece, sides[SIDE_RIGHT], SIDE_RIGHT)
	_add_side_overlay_if_needed(piece, sides[SIDE_BOTTOM], SIDE_BOTTOM)
	_add_side_overlay_if_needed(piece, sides[SIDE_LEFT], SIDE_LEFT)

	return piece


func _add_side_overlay_if_needed(piece: Node2D, side_kind: int, side: int) -> void:
	if side_kind == SIDE_IN:
		return

	var is_out := side_kind == SIDE_OUT
	var texture := TEX_PUZZLE_OUT if is_out else TEX_PUZZLE_CLOSE
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true

	var side_rotation := _rotation_for_side(side)
	sprite.rotation = side_rotation

	var texture_width := float(texture.get_width())
	var right_offset_x := (_base_piece_size * 0.5) if is_out else (_base_piece_size * 0.5 - texture_width * 0.5)
	var center := Vector2(_base_piece_size * 0.5, _base_piece_size * 0.5)
	var rotated_offset := Vector2(right_offset_x, 0.0).rotated(side_rotation)
	sprite.position = center + rotated_offset

	piece.add_child(sprite)


func _rotation_for_side(side: int) -> float:
	match side:
		SIDE_TOP:
			return -PI * 0.5
		SIDE_RIGHT:
			return 0.0
		SIDE_BOTTOM:
			return PI * 0.5
		SIDE_LEFT:
			return PI
		_:
			return 0.0


func _generate_side_map() -> Array:
	var side_map: Array = []

	for row in GRID_ROWS:
		var side_row: Array = []
		for col in GRID_COLS:
			side_row.append([SIDE_IN, SIDE_IN, SIDE_IN, SIDE_IN])
		side_map.append(side_row)

	for row in GRID_ROWS:
		side_map[row][0][SIDE_LEFT] = SIDE_CLOSED
		side_map[row][GRID_COLS - 1][SIDE_RIGHT] = SIDE_CLOSED

	for col in GRID_COLS:
		side_map[0][col][SIDE_TOP] = SIDE_CLOSED
		side_map[GRID_ROWS - 1][col][SIDE_BOTTOM] = SIDE_CLOSED

	for row in GRID_ROWS:
		for col in GRID_COLS - 1:
			var right_is_out := _rng.randi_range(0, 1) == 1
			side_map[row][col][SIDE_RIGHT] = SIDE_OUT if right_is_out else SIDE_IN
			side_map[row][col + 1][SIDE_LEFT] = SIDE_IN if right_is_out else SIDE_OUT

	for row in GRID_ROWS - 1:
		for col in GRID_COLS:
			var bottom_is_out := _rng.randi_range(0, 1) == 1
			side_map[row][col][SIDE_BOTTOM] = SIDE_OUT if bottom_is_out else SIDE_IN
			side_map[row + 1][col][SIDE_TOP] = SIDE_IN if bottom_is_out else SIDE_OUT

	return side_map


func _try_begin_drag(screen_position: Vector2, pointer_id: int) -> void:
	if _drag_pointer_id != POINTER_NONE:
		return

	var piece := _piece_at_screen_position(screen_position)
	if piece == null:
		return

	_drag_piece = piece
	_drag_pointer_id = pointer_id
	_drag_origin_pos = piece.position

	var piece_info: Dictionary = _piece_data[piece]
	_drag_origin_cell = piece_info["cell"]
	if _is_valid_cell(_drag_origin_cell):
		_board_slots[_drag_origin_cell.y][_drag_origin_cell.x] = null
		piece_info["cell"] = Vector2i(-1, -1)
		_piece_data[piece] = piece_info

	_drag_offset = piece.position - to_local(screen_position)
	piece.z_index = 100
	piece.move_to_front()

	_pieces.erase(piece)
	_pieces.append(piece)


func _update_drag(screen_position: Vector2, pointer_id: int) -> void:
	if _drag_piece == null or _drag_pointer_id != pointer_id:
		return

	_drag_piece.position = to_local(screen_position) + _drag_offset


func _end_drag(screen_position: Vector2, pointer_id: int) -> void:
	if _drag_piece == null or _drag_pointer_id != pointer_id:
		return

	var target_cell := _board_cell_from_screen_position(screen_position)
	if _is_valid_cell(target_cell) and _board_slots[target_cell.y][target_cell.x] == null and _can_place_at(_drag_piece, target_cell):
		_place_piece_at(_drag_piece, target_cell)
	else:
		_revert_drag_piece()

	_drag_piece.z_index = 1
	_drag_piece = null
	_drag_pointer_id = POINTER_NONE
	_drag_origin_cell = Vector2i(-1, -1)


func _revert_drag_piece() -> void:
	_drag_piece.position = _drag_origin_pos

	if _is_valid_cell(_drag_origin_cell):
		_board_slots[_drag_origin_cell.y][_drag_origin_cell.x] = _drag_piece
		var piece_info: Dictionary = _piece_data[_drag_piece]
		piece_info["cell"] = _drag_origin_cell
		_piece_data[_drag_piece] = piece_info


func _place_piece_at(piece: Node2D, cell: Vector2i) -> void:
	piece.position = _board_cell_to_position(cell)
	_board_slots[cell.y][cell.x] = piece

	var piece_info: Dictionary = _piece_data[piece]
	piece_info["cell"] = cell
	_piece_data[piece] = piece_info


func _can_place_at(piece: Node2D, cell: Vector2i) -> bool:
	var piece_info: Dictionary = _piece_data[piece]
	var sides: Array = piece_info["sides"]

	if not _edges_are_valid_for_cell(sides, cell):
		return false

	if not _matches_neighbor(sides[SIDE_TOP], cell + Vector2i(0, -1), SIDE_BOTTOM):
		return false
	if not _matches_neighbor(sides[SIDE_RIGHT], cell + Vector2i(1, 0), SIDE_LEFT):
		return false
	if not _matches_neighbor(sides[SIDE_BOTTOM], cell + Vector2i(0, 1), SIDE_TOP):
		return false
	if not _matches_neighbor(sides[SIDE_LEFT], cell + Vector2i(-1, 0), SIDE_RIGHT):
		return false

	return true


func _edges_are_valid_for_cell(sides: Array, cell: Vector2i) -> bool:
	if cell.y == 0:
		if sides[SIDE_TOP] != SIDE_CLOSED:
			return false
	elif sides[SIDE_TOP] == SIDE_CLOSED:
		return false

	if cell.x == GRID_COLS - 1:
		if sides[SIDE_RIGHT] != SIDE_CLOSED:
			return false
	elif sides[SIDE_RIGHT] == SIDE_CLOSED:
		return false

	if cell.y == GRID_ROWS - 1:
		if sides[SIDE_BOTTOM] != SIDE_CLOSED:
			return false
	elif sides[SIDE_BOTTOM] == SIDE_CLOSED:
		return false

	if cell.x == 0:
		if sides[SIDE_LEFT] != SIDE_CLOSED:
			return false
	elif sides[SIDE_LEFT] == SIDE_CLOSED:
		return false

	return true


func _matches_neighbor(my_side: int, neighbor_cell: Vector2i, neighbor_side: int) -> bool:
	if not _is_valid_cell(neighbor_cell):
		return true

	var neighbor_piece: Node2D = _board_slots[neighbor_cell.y][neighbor_cell.x]
	if neighbor_piece == null:
		return true

	var neighbor_info: Dictionary = _piece_data[neighbor_piece]
	var neighbor_sides: Array = neighbor_info["sides"]
	return _sides_match(my_side, neighbor_sides[neighbor_side])


func _sides_match(a: int, b: int) -> bool:
	if a == SIDE_CLOSED or b == SIDE_CLOSED:
		return a == SIDE_CLOSED and b == SIDE_CLOSED

	return (a == SIDE_OUT and b == SIDE_IN) or (a == SIDE_IN and b == SIDE_OUT)


func _piece_at_screen_position(screen_position: Vector2) -> Node2D:
	var local_position := to_local(screen_position)
	var piece_bounds := Rect2(Vector2.ZERO, Vector2(_base_piece_size, _base_piece_size))

	for index in range(_pieces.size() - 1, -1, -1):
		var piece := _pieces[index]
		var piece_local := piece.to_local(local_position)
		if piece_bounds.has_point(piece_local):
			return piece

	return null


func _board_cell_from_screen_position(screen_position: Vector2) -> Vector2i:
	var local_position := to_local(screen_position)
	var board_size := Vector2(float(GRID_COLS) * CELL_SIZE, float(GRID_ROWS) * CELL_SIZE)
	var board_rect := Rect2(BOARD_ORIGIN, board_size)

	if not board_rect.has_point(local_position):
		return Vector2i(-1, -1)

	var col := int((local_position.x - BOARD_ORIGIN.x) / CELL_SIZE)
	var row := int((local_position.y - BOARD_ORIGIN.y) / CELL_SIZE)
	return Vector2i(col, row)


func _board_cell_to_position(cell: Vector2i) -> Vector2:
	return BOARD_ORIGIN + Vector2(float(cell.x) * CELL_SIZE, float(cell.y) * CELL_SIZE)


func _tray_cell_to_position(cell: Vector2i) -> Vector2:
	return TRAY_ORIGIN + Vector2(float(cell.x) * CELL_SIZE, float(cell.y) * CELL_SIZE)


func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_COLS and cell.y >= 0 and cell.y < GRID_ROWS
