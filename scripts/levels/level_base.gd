extends Node2D


const GRID_ROWS := 5
const GRID_COLS := 8

const BOARD_ORIGIN := Vector2(20.0, 20.0)
const TRAY_ORIGIN := Vector2(392.0, 115.0)
const CELL_SIZE := 40.0

const TEX_PUZZLE_IN4 := preload("res://assets/puzzle/puzzle_in4.png")
const TEX_PUZZLE_CLOSE := preload("res://assets/puzzle/puzzle_close_part.png")
const TEX_PUZZLE_OUT := preload("res://assets/puzzle/puzzle_out_part.png")
const DOOR_SCENE := preload("res://scenes/door.tscn")

const WELCOME_SCENE := "res://scenes/welcome.tscn"
const PAUSE_MODAL_ANIM_DURATION := 0.2
const PAUSE_MODAL_SHOW_START_SCALE := 0.9
const PAUSE_MODAL_HIDE_END_SCALE := 1.08

const TEX_PLAYER_IDLE := preload("res://assets/player/idle.png")
const TEX_PLAYER_WALK := preload("res://assets/player/walk.png")
const TEX_PLAYER_RUN := preload("res://assets/player/run.png")
const TEX_PLAYER_JUMP_UP := preload("res://assets/player/jump_up.png")
const TEX_PLAYER_JUMP_DOWN := preload("res://assets/player/jump_down.png")

const SIDE_TOP := 0
const SIDE_RIGHT := 1
const SIDE_BOTTOM := 2
const SIDE_LEFT := 3

const SIDE_IN := 0
const SIDE_OUT := 1
const SIDE_CLOSED := 2

const POINTER_NONE := -999
const POINTER_MOUSE := -1
const POINTER_GRID_MOUSE := -2

const CAMERA_ZOOM_MIN := 0.55
const CAMERA_ZOOM_MAX := 2.2
const CAMERA_WHEEL_STEP := 0.9

const PLAYER_FRAME_SIZE := Vector2(24, 24)
const PLAYER_SCALE := 0.75
const PLAYER_WALK_SPEED := 70.0
const PLAYER_RUN_SPEED := 120.0
const PLAYER_JUMP_SPEED := 180.0
const PLAYER_GRAVITY := 420.0

const PLAYER_HITBOX_INSET_LEFT := 3.0
const PLAYER_HITBOX_INSET_RIGHT := 3.0
const PLAYER_HITBOX_INSET_TOP := 1.0
const PLAYER_HITBOX_INSET_BOTTOM := 1.0

const DOOR_LOCAL_RECT_POSITION := Vector2(-20.0, -23.0)
const DOOR_LOCAL_RECT_SIZE := Vector2(40.0, 40.0)

@onready var panel: Panel = $Panel
@onready var level_bar: Control = $LevelBar
@onready var level_label: Label = $LevelBar/LevelLabel
@onready var pause_button: TextureButton = $LevelBar/PauseButton
@onready var timer_label: Label = $LevelBar/LevelLabel/TimerLabel
@onready var scene_modal_pause: Control = get_node_or_null("ModalPause") as Control

var level_number := 1
var start_cell := Vector2i(2, 2)
var end_cell := Vector2i(4, 2)
var connector_spawn_position := TRAY_ORIGIN
var start_piece_sides: Array = [SIDE_CLOSED, SIDE_OUT, SIDE_CLOSED, SIDE_CLOSED]
var end_piece_sides: Array = [SIDE_CLOSED, SIDE_CLOSED, SIDE_CLOSED, SIDE_IN]
var connector_piece_sides: Array = [SIDE_CLOSED, SIDE_OUT, SIDE_CLOSED, SIDE_IN]
# Fallback anchor (used when door sprite bounds are not detectable).
var door_piece_local_position := Vector2(30.0, 33.0)
var door_snap_to_ground_right := true

var _base_piece_size := 50.0
var _piece_scale := 1.0

var _board_slots: Array = []
var _draggable_pieces: Array[Node2D] = []
var _piece_data := {}

var _start_piece: Node2D = null
var _end_piece: Node2D = null
var _connector_piece: Node2D = null
var _door_instance: Node2D = null
var _door_local_rect_position := DOOR_LOCAL_RECT_POSITION
var _door_local_rect_size := DOOR_LOCAL_RECT_SIZE

var _drag_piece: Node2D = null
var _drag_pointer_id := POINTER_NONE
var _drag_offset := Vector2.ZERO
var _drag_origin_cell := Vector2i(-1, -1)
var _drag_origin_pos := Vector2.ZERO

var _player_piece: Node2D = null
var _player_root: Node2D = null
var _player_sprite: AnimatedSprite2D = null
var _player_velocity := Vector2.ZERO
var _player_facing := 1
var _level_complete := false

var _grid_root: Node2D = null
var _grid_pan_active := false
var _grid_pan_pointer_id := POINTER_NONE
var _grid_pan_last_screen_position := Vector2.ZERO

var _elapsed_seconds := 0.0
var _is_paused := false
var _pause_transition_active := false
var _modal_pause: Control = null
var _pause_canvas_layer: CanvasLayer = null


func _apply_level_config() -> void:
	pass


func _ready() -> void:
	_apply_level_config()

	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if $Panel/Background is Control:
		($Panel/Background as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	_base_piece_size = float(TEX_PUZZLE_IN4.get_height())
	_piece_scale = CELL_SIZE / _base_piece_size

	_setup_grid_root()
	_init_board_slots()
	_build_level_layout()
	_setup_player()
	_setup_level_ui()
	_update_timer_label()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _is_paused:
		return
	_update_player(delta)


func _process(delta: float) -> void:
	if _is_paused or _level_complete:
		return

	_elapsed_seconds += delta
	_update_timer_label()


func _draw() -> void:
	if _grid_root == null:
		return

	var grid_scale := _grid_root.scale.x
	var board_size_local := Vector2(float(GRID_COLS) * CELL_SIZE, float(GRID_ROWS) * CELL_SIZE)
	var board_origin_world := _grid_to_world(BOARD_ORIGIN)
	var board_size_world := board_size_local * grid_scale

	draw_rect(Rect2(board_origin_world, board_size_world), Color(0.0, 0.0, 0.0, 0.12), true)
	draw_rect(Rect2(_grid_to_world(_board_cell_to_position(start_cell)), Vector2.ONE * CELL_SIZE * grid_scale), Color(0.2, 0.75, 0.35, 0.16), true)
	draw_rect(Rect2(_grid_to_world(_board_cell_to_position(end_cell)), Vector2.ONE * CELL_SIZE * grid_scale), Color(0.85, 0.2, 0.2, 0.16), true)

	for row in range(GRID_ROWS + 1):
		var y := board_origin_world.y + float(row) * CELL_SIZE * grid_scale
		draw_line(Vector2(board_origin_world.x, y), Vector2(board_origin_world.x + board_size_world.x, y), Color(0.0, 0.0, 0.0, 0.35), 1.0)

	for col in range(GRID_COLS + 1):
		var x := board_origin_world.x + float(col) * CELL_SIZE * grid_scale
		draw_line(Vector2(x, board_origin_world.y), Vector2(x, board_origin_world.y + board_size_world.y), Color(0.0, 0.0, 0.0, 0.35), 1.0)

	draw_rect(Rect2(_grid_to_world(connector_spawn_position), Vector2.ONE * CELL_SIZE * grid_scale), Color(0.0, 0.0, 0.0, 0.3), false, maxf(1.0, 2.0 * grid_scale))


func _unhandled_input(event: InputEvent) -> void:
	if _is_paused:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_grid(CAMERA_WHEEL_STEP, event.position)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_grid(1.0 / CAMERA_WHEEL_STEP, event.position)
			return

		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_begin_grid_pan(POINTER_GRID_MOUSE, event.position)
			else:
				_end_grid_pan(POINTER_GRID_MOUSE)
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var did_begin_drag := _try_begin_drag(event.position, POINTER_MOUSE)
				if not did_begin_drag:
					_begin_grid_pan(POINTER_MOUSE, event.position)
			else:
				if _drag_pointer_id == POINTER_MOUSE:
					_end_drag(event.position, POINTER_MOUSE)
				_end_grid_pan(POINTER_MOUSE)
			return

	if event is InputEventMouseMotion:
		if _drag_pointer_id == POINTER_MOUSE:
			_update_drag(event.position, POINTER_MOUSE)
			return
		if _grid_pan_active and _grid_pan_pointer_id == POINTER_MOUSE:
			_update_grid_pan(event.position, POINTER_MOUSE)
			return
		if _grid_pan_active and _grid_pan_pointer_id == POINTER_GRID_MOUSE:
			_update_grid_pan(event.position, POINTER_GRID_MOUSE)
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			var did_begin_drag := _try_begin_drag(event.position, event.index)
			if not did_begin_drag:
				_begin_grid_pan(event.index, event.position)
		else:
			if _drag_pointer_id == event.index:
				_end_drag(event.position, event.index)
			_end_grid_pan(event.index)
		return

	if event is InputEventScreenDrag:
		if _drag_pointer_id == event.index:
			_update_drag(event.position, event.index)
		elif _grid_pan_active and _grid_pan_pointer_id == event.index:
			_update_grid_pan(event.position, event.index)
		return

	if event is InputEventMagnifyGesture:
		var factor: float = 1.0 / maxf(event.factor, 0.01)
		_zoom_grid(factor, event.position)
		return


func _setup_grid_root() -> void:
	_grid_root = Node2D.new()
	_grid_root.name = "GridRoot"
	add_child(_grid_root)


func _init_board_slots() -> void:
	_board_slots.clear()
	for row in range(GRID_ROWS):
		var row_slots: Array = []
		for col in range(GRID_COLS):
			row_slots.append(null)
		_board_slots.append(row_slots)


func _build_level_layout() -> void:
	var start_sides: Array = start_piece_sides.duplicate()
	var end_sides: Array = end_piece_sides.duplicate()
	var connector_sides: Array = connector_piece_sides.duplicate()

	_start_piece = _create_piece("StartPiece", start_sides, false)
	_end_piece = _create_piece("EndPiece", end_sides, false)
	_connector_piece = _create_piece("ConnectorPiece", connector_sides, true)

	_register_piece(_start_piece, start_sides, start_cell)
	_register_piece(_end_piece, end_sides, end_cell)
	_register_piece(_connector_piece, connector_sides, Vector2i(-1, -1))

	_place_fixed_piece(_start_piece, start_cell)
	_place_fixed_piece(_end_piece, end_cell)
	_connector_piece.position = connector_spawn_position
	_setup_end_door()


func _create_piece(piece_name: String, sides: Array, draggable: bool) -> Node2D:
	var piece := Node2D.new()
	piece.name = piece_name
	piece.scale = Vector2.ONE * _piece_scale
	piece.z_index = 2 if draggable else 1

	var base_sprite := Sprite2D.new()
	base_sprite.texture = TEX_PUZZLE_IN4
	base_sprite.centered = false
	piece.add_child(base_sprite)

	_add_side_overlay_if_needed(piece, sides[SIDE_TOP], SIDE_TOP)
	_add_side_overlay_if_needed(piece, sides[SIDE_RIGHT], SIDE_RIGHT)
	_add_side_overlay_if_needed(piece, sides[SIDE_BOTTOM], SIDE_BOTTOM)
	_add_side_overlay_if_needed(piece, sides[SIDE_LEFT], SIDE_LEFT)

	_grid_root.add_child(piece)
	if draggable:
		_draggable_pieces.append(piece)

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


func _register_piece(piece: Node2D, sides: Array, cell: Vector2i) -> void:
	_piece_data[piece] = {
		"sides": sides.duplicate(),
		"cell": cell,
	}


func _place_fixed_piece(piece: Node2D, cell: Vector2i) -> void:
	piece.position = _board_cell_to_position(cell)
	_board_slots[cell.y][cell.x] = piece


func _setup_end_door() -> void:
	if _door_instance != null:
		_door_instance.queue_free()

	var instance := DOOR_SCENE.instantiate()
	if instance is Node2D:
		var final_position := door_piece_local_position
		_door_local_rect_position = DOOR_LOCAL_RECT_POSITION
		_door_local_rect_size = DOOR_LOCAL_RECT_SIZE

		var sprite_rect := _door_visual_rect_from_instance(instance)
		if sprite_rect.size.x > 0.0 and sprite_rect.size.y > 0.0:
			_door_local_rect_position = sprite_rect.position
			_door_local_rect_size = sprite_rect.size
			if door_snap_to_ground_right:
				final_position = Vector2(
					_base_piece_size - (sprite_rect.position.x + sprite_rect.size.x),
					_base_piece_size - (sprite_rect.position.y + sprite_rect.size.y)
				)

		_door_instance = instance as Node2D
		_door_instance.position = final_position
		_door_instance.z_index = 12
		_end_piece.add_child(_door_instance)
		if _door_instance.has_node("Panel"):
			var door_panel := _door_instance.get_node("Panel")
			if door_panel is Control:
				(door_panel as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _door_visual_rect_from_instance(instance: Node) -> Rect2:
	var door_sprite: Sprite2D = instance.get_node_or_null("Door") as Sprite2D
	if door_sprite == null or door_sprite.texture == null:
		return Rect2()

	var sprite_scale := Vector2(absf(door_sprite.scale.x), absf(door_sprite.scale.y))
	var size := door_sprite.texture.get_size() * sprite_scale
	var origin := door_sprite.position
	if door_sprite.centered:
		origin -= size * 0.5

	return Rect2(origin, size)


func _setup_level_ui() -> void:
	level_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	level_label.text = "Level %d" % level_number
	pause_button.pressed.connect(_on_pause_button_pressed)

	if _pause_canvas_layer == null:
		_pause_canvas_layer = CanvasLayer.new()
		_pause_canvas_layer.name = "PauseCanvasLayer"
		_pause_canvas_layer.layer = 100
		add_child(_pause_canvas_layer)

	_modal_pause = scene_modal_pause
	if _modal_pause == null:
		return

	if _modal_pause.get_parent() != _pause_canvas_layer:
		_modal_pause.reparent(_pause_canvas_layer)

	_modal_pause.z_as_relative = false
	_modal_pause.z_index = 10_000
	_modal_pause.visible = false
	_modal_pause.modulate = Color(1, 1, 1, 0)
	_modal_pause.scale = Vector2.ONE * PAUSE_MODAL_SHOW_START_SCALE
	_modal_pause.pivot_offset = _modal_pause.size * 0.5
	_modal_pause.mouse_filter = Control.MOUSE_FILTER_STOP

	var continue_button: TextureButton = _modal_pause.get_node_or_null("ContinueButton") as TextureButton
	if continue_button != null:
		continue_button.pressed.connect(_on_continue_button_pressed)

	var retry_button: TextureButton = _modal_pause.get_node_or_null("RetryButton") as TextureButton
	if retry_button != null:
		retry_button.pressed.connect(_on_retry_button_pressed)

	var exit_button: TextureButton = _modal_pause.get_node_or_null("ExitButton") as TextureButton
	if exit_button != null:
		exit_button.pressed.connect(_on_exit_button_pressed)


func _update_timer_label() -> void:
	var total_seconds: int = int(floor(_elapsed_seconds))
	var minutes: int = int(total_seconds / 60.0)
	var seconds: int = total_seconds % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]


func _set_pause_state(paused: bool) -> void:
	_is_paused = paused
	pause_button.disabled = paused


func _on_pause_button_pressed() -> void:
	if _is_paused or _pause_transition_active or _modal_pause == null:
		return

	_set_pause_state(true)
	_show_pause_modal_animated()


func _on_continue_button_pressed() -> void:
	if not _is_paused or _pause_transition_active:
		return

	_hide_pause_modal_animated(func() -> void:
		_set_pause_state(false)
	)


func _on_retry_button_pressed() -> void:
	if _pause_transition_active:
		return

	_set_pause_state(false)
	get_tree().reload_current_scene()


func _on_exit_button_pressed() -> void:
	if _pause_transition_active:
		return

	_set_pause_state(false)
	get_tree().change_scene_to_file(WELCOME_SCENE)


func _show_pause_modal_animated() -> void:
	if _modal_pause == null:
		return

	_pause_transition_active = true
	_modal_pause.visible = true
	_modal_pause.move_to_front()
	_modal_pause.modulate = Color(1, 1, 1, 0)
	_modal_pause.scale = Vector2.ONE * PAUSE_MODAL_SHOW_START_SCALE
	_modal_pause.pivot_offset = _modal_pause.size * 0.5

	var tween := create_tween()
	tween.tween_property(_modal_pause, "modulate:a", 1.0, PAUSE_MODAL_ANIM_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_modal_pause, "scale", Vector2.ONE, PAUSE_MODAL_ANIM_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		_pause_transition_active = false
	)


func _hide_pause_modal_animated(after_hide: Callable = Callable()) -> void:
	if _modal_pause == null:
		if after_hide.is_valid():
			after_hide.call()
		return

	_pause_transition_active = true
	var tween := create_tween()
	tween.tween_property(_modal_pause, "modulate:a", 0.0, PAUSE_MODAL_ANIM_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_modal_pause, "scale", Vector2.ONE * PAUSE_MODAL_HIDE_END_SCALE, PAUSE_MODAL_ANIM_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		_modal_pause.visible = false
		_modal_pause.scale = Vector2.ONE * PAUSE_MODAL_SHOW_START_SCALE
		_pause_transition_active = false
		if after_hide.is_valid():
			after_hide.call()
	)


func _setup_player() -> void:
	_player_root = Node2D.new()
	_player_root.name = "Player"
	_player_root.z_index = 20

	_player_sprite = AnimatedSprite2D.new()
	_player_sprite.centered = false
	_player_sprite.scale = Vector2.ONE * PLAYER_SCALE
	_player_sprite.sprite_frames = _build_player_frames()
	_player_sprite.play("idle")
	_player_root.add_child(_player_sprite)

	_set_player_piece(_start_piece, Vector2(2.0, _player_floor_root_y()))


func _build_player_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()

	_add_animation_frames(frames, "idle", TEX_PLAYER_IDLE, 2, 4.0)
	_add_animation_frames(frames, "walk", TEX_PLAYER_WALK, 4, 8.0)
	_add_animation_frames(frames, "run", TEX_PLAYER_RUN, 4, 12.0)
	_add_animation_frames(frames, "jump_up", TEX_PLAYER_JUMP_UP, 4, 10.0)
	_add_animation_frames(frames, "jump_down", TEX_PLAYER_JUMP_DOWN, 4, 10.0)

	return frames


func _add_animation_frames(frames: SpriteFrames, animation: String, texture: Texture2D, frame_count: int, fps: float) -> void:
	frames.add_animation(animation)
	frames.set_animation_loop(animation, animation != "jump_up" and animation != "jump_down")
	frames.set_animation_speed(animation, fps)

	for frame_index in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(frame_index * int(PLAYER_FRAME_SIZE.x), 0, int(PLAYER_FRAME_SIZE.x), int(PLAYER_FRAME_SIZE.y))
		frames.add_frame(animation, atlas)


func _set_player_piece(piece: Node2D, local_position: Vector2) -> void:
	if _player_root.get_parent() != null:
		_player_root.get_parent().remove_child(_player_root)

	piece.add_child(_player_root)
	_player_piece = piece
	_player_root.position = local_position


func _try_begin_drag(screen_position: Vector2, pointer_id: int) -> bool:
	if _drag_pointer_id != POINTER_NONE or _grid_pan_active:
		return false

	var piece := _draggable_piece_at_screen_position(screen_position)
	if piece == null:
		return false

	_drag_piece = piece
	_drag_pointer_id = pointer_id
	_drag_origin_pos = piece.position

	var piece_info: Dictionary = _piece_data[piece]
	_drag_origin_cell = piece_info["cell"]
	if _is_valid_cell(_drag_origin_cell):
		_board_slots[_drag_origin_cell.y][_drag_origin_cell.x] = null
		piece_info["cell"] = Vector2i(-1, -1)
		_piece_data[piece] = piece_info

	var grid_position := _screen_to_grid(screen_position)
	_drag_offset = piece.position - grid_position
	piece.z_index = 100
	piece.move_to_front()
	return true


func _update_drag(screen_position: Vector2, pointer_id: int) -> void:
	if _drag_piece == null or _drag_pointer_id != pointer_id:
		return

	var grid_position := _screen_to_grid(screen_position)
	_drag_piece.position = grid_position + _drag_offset


func _end_drag(screen_position: Vector2, pointer_id: int) -> void:
	if _drag_piece == null or _drag_pointer_id != pointer_id:
		return

	var target_cell := _board_cell_from_screen_position(screen_position)
	if _is_valid_drop_for_piece(_drag_piece, target_cell):
		_place_piece_at(_drag_piece, target_cell)
	else:
		_revert_drag_piece()

	_drag_piece.z_index = 2
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


func _is_valid_drop_for_piece(_piece: Node2D, cell: Vector2i) -> bool:
	if not _is_valid_cell(cell):
		return false
	return _board_slots[cell.y][cell.x] == null


func _update_player(delta: float) -> void:
	if _player_piece == null or _player_root == null:
		return

	var direction := Input.get_axis("ui_left", "ui_right")
	var wants_run := Input.is_key_pressed(KEY_SHIFT)
	var move_speed := PLAYER_RUN_SPEED if wants_run else PLAYER_WALK_SPEED
	_player_velocity.x = direction * move_speed

	if direction < 0.0:
		_player_facing = -1
	elif direction > 0.0:
		_player_facing = 1

	if _is_player_on_floor() and (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")):
		_player_velocity.y = -PLAYER_JUMP_SPEED

	_player_velocity.y += PLAYER_GRAVITY * delta

	var new_pos := _player_root.position + _player_velocity * delta
	new_pos = _resolve_horizontal_transition(new_pos)
	var floor_y := _player_floor_root_y()

	if new_pos.y >= floor_y:
		new_pos.y = floor_y
		if _player_velocity.y > 0.0:
			_player_velocity.y = 0.0

	_player_root.position = new_pos
	_update_player_animation(direction, wants_run)

	if not _level_complete and _is_player_in_door():
		_level_complete = true
		print("Level %d complete" % level_number)


func _resolve_horizontal_transition(new_pos: Vector2) -> Vector2:
	var min_x := _player_min_x()
	var max_x := _player_max_x()

	if new_pos.x > max_x:
		if _player_velocity.x > 0.0:
			var next_piece_x := new_pos.x - _base_piece_size
			if _try_transfer_player_to_neighbor(SIDE_RIGHT, next_piece_x, new_pos.y):
				return _player_root.position
			new_pos.x = max_x
		elif is_zero_approx(_player_velocity.x):
			new_pos.x = max_x
	elif new_pos.x < min_x:
		if _player_velocity.x < 0.0:
			var next_piece_x_left := new_pos.x + _base_piece_size
			if _try_transfer_player_to_neighbor(SIDE_LEFT, next_piece_x_left, new_pos.y):
				return _player_root.position
			new_pos.x = min_x
		elif is_zero_approx(_player_velocity.x):
			new_pos.x = min_x

	return new_pos


func _try_transfer_player_to_neighbor(side: int, next_piece_x: float, y_value: float) -> bool:
	var current_info: Dictionary = _piece_data.get(_player_piece, {})
	if current_info.is_empty():
		return false

	var current_cell: Vector2i = current_info["cell"]
	if not _is_valid_cell(current_cell):
		return false

	var offset := Vector2i(1, 0) if side == SIDE_RIGHT else Vector2i(-1, 0)
	var neighbor_cell := current_cell + offset
	if not _is_valid_cell(neighbor_cell):
		return false

	var neighbor_piece: Node2D = _board_slots[neighbor_cell.y][neighbor_cell.x]
	if neighbor_piece == null:
		return false

	var current_sides: Array = current_info["sides"]
	var neighbor_info: Dictionary = _piece_data[neighbor_piece]
	var neighbor_sides: Array = neighbor_info["sides"]
	var opposite_side := SIDE_LEFT if side == SIDE_RIGHT else SIDE_RIGHT

	if not _sides_match(current_sides[side], neighbor_sides[opposite_side]):
		return false

	var clamped_x: float = clampf(next_piece_x, -_base_piece_size, _base_piece_size)
	var clamped_y: float = minf(y_value, _player_floor_root_y())
	_set_player_piece(neighbor_piece, Vector2(clamped_x, clamped_y))
	return true


func _is_player_on_floor() -> bool:
	return _player_root.position.y >= _player_floor_root_y() - 0.01


func _update_player_animation(direction: float, wants_run: bool) -> void:
	var animation := "idle"

	if not _is_player_on_floor():
		animation = "jump_up" if _player_velocity.y < 0.0 else "jump_down"
	elif abs(direction) > 0.01:
		animation = "run" if wants_run else "walk"

	_player_sprite.flip_h = _player_facing < 0
	if _player_sprite.animation != animation:
		_player_sprite.play(animation)
	elif not _player_sprite.is_playing():
		_player_sprite.play(animation)


func _draggable_piece_at_screen_position(screen_position: Vector2) -> Node2D:
	var world_position := _screen_to_world(screen_position)
	var pick_rect := Rect2(Vector2(-9.0, -9.0), Vector2(_base_piece_size + 18.0, _base_piece_size + 18.0))

	for index in range(_draggable_pieces.size() - 1, -1, -1):
		var piece: Node2D = _draggable_pieces[index]
		var piece_local := piece.to_local(world_position)
		if pick_rect.has_point(piece_local):
			return piece

	return null


func _sides_match(a: int, b: int) -> bool:
	return (a == SIDE_OUT and b == SIDE_IN) or (a == SIDE_IN and b == SIDE_OUT)


func _board_cell_from_screen_position(screen_position: Vector2) -> Vector2i:
	var local_position := _screen_to_grid(screen_position)
	var board_size := Vector2(float(GRID_COLS) * CELL_SIZE, float(GRID_ROWS) * CELL_SIZE)
	var board_rect := Rect2(BOARD_ORIGIN, board_size)

	if not board_rect.has_point(local_position):
		return Vector2i(-1, -1)

	var col := int((local_position.x - BOARD_ORIGIN.x) / CELL_SIZE)
	var row := int((local_position.y - BOARD_ORIGIN.y) / CELL_SIZE)
	return Vector2i(col, row)


func _board_cell_to_position(cell: Vector2i) -> Vector2:
	return BOARD_ORIGIN + Vector2(float(cell.x) * CELL_SIZE, float(cell.y) * CELL_SIZE)


func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_COLS and cell.y >= 0 and cell.y < GRID_ROWS


func _player_visual_size() -> Vector2:
	return PLAYER_FRAME_SIZE * PLAYER_SCALE


func _player_hitbox_offset() -> Vector2:
	return Vector2(PLAYER_HITBOX_INSET_LEFT, PLAYER_HITBOX_INSET_TOP)


func _player_hitbox_size() -> Vector2:
	var visual := _player_visual_size()
	return Vector2(
		visual.x - PLAYER_HITBOX_INSET_LEFT - PLAYER_HITBOX_INSET_RIGHT,
		visual.y - PLAYER_HITBOX_INSET_TOP - PLAYER_HITBOX_INSET_BOTTOM
	)


func _player_min_x() -> float:
	return -PLAYER_HITBOX_INSET_LEFT


func _player_max_x() -> float:
	var visual := _player_visual_size()
	return _base_piece_size - visual.x + PLAYER_HITBOX_INSET_RIGHT


func _player_floor_root_y() -> float:
	var visual := _player_visual_size()
	return _base_piece_size - visual.y + PLAYER_HITBOX_INSET_BOTTOM


func _player_hitbox_rect(root_position: Vector2) -> Rect2:
	return Rect2(root_position + _player_hitbox_offset(), _player_hitbox_size())


func _is_player_in_door() -> bool:
	if _player_piece != _end_piece or _door_instance == null:
		return false

	var player_rect := _player_hitbox_rect(_player_root.position)
	var door_rect := Rect2(_door_instance.position + _door_local_rect_position, _door_local_rect_size)
	return player_rect.intersects(door_rect)


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position


func _screen_to_grid(screen_position: Vector2) -> Vector2:
	return _grid_root.to_local(_screen_to_world(screen_position))


func _grid_to_world(grid_position: Vector2) -> Vector2:
	return _grid_root.to_global(grid_position)


func _begin_grid_pan(pointer_id: int, screen_position: Vector2) -> void:
	if _drag_piece != null or _grid_pan_active:
		return

	_grid_pan_active = true
	_grid_pan_pointer_id = pointer_id
	_grid_pan_last_screen_position = screen_position


func _update_grid_pan(screen_position: Vector2, pointer_id: int) -> void:
	if not _grid_pan_active or _grid_pan_pointer_id != pointer_id:
		return

	var previous_world := _screen_to_world(_grid_pan_last_screen_position)
	var current_world := _screen_to_world(screen_position)
	var delta := current_world - previous_world
	_grid_root.position += delta
	_grid_pan_last_screen_position = screen_position
	queue_redraw()


func _end_grid_pan(pointer_id: int) -> void:
	if not _grid_pan_active or _grid_pan_pointer_id != pointer_id:
		return

	_grid_pan_active = false
	_grid_pan_pointer_id = POINTER_NONE


func _zoom_grid(zoom_factor: float, anchor_screen_position: Vector2) -> void:
	if _grid_root == null:
		return

	var anchor_world := _screen_to_world(anchor_screen_position)
	var local_before := _grid_root.to_local(anchor_world)
	var new_zoom: float = clampf(_grid_root.scale.x * zoom_factor, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
	_grid_root.scale = Vector2.ONE * new_zoom
	var anchor_after := _grid_root.to_global(local_before)
	_grid_root.position += anchor_world - anchor_after
	queue_redraw()
