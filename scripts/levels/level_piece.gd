@tool
extends Node2D
class_name LevelPiece


enum PieceRole {
	START,
	END,
	NORMAL,
}

enum SideType {
	IN,
	OUT,
	CLOSED,
}

enum PlacementMode {
	BOARD_CELL,
	SPAWN_CELL,
	TRAY_CELL,
	POSITION,
}

const BOARD_ORIGIN := Vector2(20.0, 20.0)
const TRAY_ORIGIN := Vector2(392.0, 115.0)
const CELL_SIZE := 40.0
const PIECE_SIZE := 50.0
const PIECE_SCALE := CELL_SIZE / PIECE_SIZE

const DEFAULT_BASE_TEXTURE := preload("res://assets/puzzle/puzzle_in4.png")
const DEFAULT_OUT_TEXTURE := preload("res://assets/puzzle/puzzle_out_part.png")
const DEFAULT_CLOSE_TEXTURE := preload("res://assets/puzzle/puzzle_close_part.png")
const DEFAULT_WALL_TILE_TEXTURE := preload("res://assets/tilemap.png")

@export var role: PieceRole = PieceRole.NORMAL
@export var draggable := true

@export var side_top: SideType = SideType.CLOSED
@export var side_right: SideType = SideType.CLOSED
@export var side_bottom: SideType = SideType.CLOSED
@export var side_left: SideType = SideType.CLOSED

@export var placement_mode: PlacementMode = PlacementMode.POSITION
@export var board_cell := Vector2i.ZERO
@export var spawn_cell := Vector2i.ZERO
@export var tray_cell := Vector2i.ZERO
@export var explicit_position := Vector2.ZERO

@export var wall_map: String = ""

@export var base_texture: Texture2D = DEFAULT_BASE_TEXTURE
@export var out_texture: Texture2D = DEFAULT_OUT_TEXTURE
@export var close_texture: Texture2D = DEFAULT_CLOSE_TEXTURE

var _base_sprite: Sprite2D = null
var _side_top_sprite: Sprite2D = null
var _side_right_sprite: Sprite2D = null
var _side_bottom_sprite: Sprite2D = null
var _side_left_sprite: Sprite2D = null
var _editor_last_position := Vector2.ZERO
var _editor_sync_ready := false


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
		_ensure_preview_nodes()
		_ensure_wall_map_node()
		_sync_position_from_mode()
		_editor_last_position = position
		_editor_sync_ready = true
		_refresh_preview_visuals()
	else:
		visible = false
		set_process(false)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return

	_ensure_preview_nodes()
	_ensure_wall_map_node()

	if not _editor_sync_ready:
		_sync_position_from_mode()
		_editor_last_position = position
		_editor_sync_ready = true

	if not position.is_equal_approx(_editor_last_position):
		_sync_mode_from_position()

	_sync_position_from_mode()
	_editor_last_position = position
	_refresh_preview_visuals()


func _sync_position_from_mode() -> void:
	match placement_mode:
		PlacementMode.BOARD_CELL:
			position = _cell_to_position(BOARD_ORIGIN, board_cell)
		PlacementMode.SPAWN_CELL:
			position = _cell_to_position(BOARD_ORIGIN, spawn_cell)
		PlacementMode.TRAY_CELL:
			position = _cell_to_position(TRAY_ORIGIN, tray_cell)
		PlacementMode.POSITION:
			position = explicit_position


func _sync_mode_from_position() -> void:
	match placement_mode:
		PlacementMode.BOARD_CELL:
			board_cell = _cell_from_position(BOARD_ORIGIN, position)
		PlacementMode.SPAWN_CELL:
			spawn_cell = _cell_from_position(BOARD_ORIGIN, position)
		PlacementMode.TRAY_CELL:
			tray_cell = _cell_from_position(TRAY_ORIGIN, position)
		PlacementMode.POSITION:
			explicit_position = position


func _cell_to_position(origin: Vector2, cell: Vector2i) -> Vector2:
	return origin + Vector2(float(cell.x) * CELL_SIZE, float(cell.y) * CELL_SIZE)


func _cell_from_position(origin: Vector2, world_pos: Vector2) -> Vector2i:
	return Vector2i(
		roundi((world_pos.x - origin.x) / CELL_SIZE),
		roundi((world_pos.y - origin.y) / CELL_SIZE)
	)


func _ensure_preview_nodes() -> void:
	if _base_sprite == null:
		var existing_base := get_node_or_null("BaseSprite")
		if existing_base is Sprite2D:
			_base_sprite = existing_base as Sprite2D
		else:
			_base_sprite = Sprite2D.new()
			_base_sprite.name = "BaseSprite"
			_base_sprite.centered = false
			add_child(_base_sprite)

	if _side_top_sprite == null:
		_side_top_sprite = _ensure_side_sprite("SideTop")
	if _side_right_sprite == null:
		_side_right_sprite = _ensure_side_sprite("SideRight")
	if _side_bottom_sprite == null:
		_side_bottom_sprite = _ensure_side_sprite("SideBottom")
	if _side_left_sprite == null:
		_side_left_sprite = _ensure_side_sprite("SideLeft")


func _ensure_side_sprite(node_name: String) -> Sprite2D:
	var existing := get_node_or_null(node_name)
	if existing is Sprite2D:
		return existing as Sprite2D

	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.centered = true
	add_child(sprite)
	return sprite


func _refresh_preview_visuals() -> void:
	scale = Vector2.ONE * PIECE_SCALE
	if _base_sprite != null:
		_base_sprite.texture = base_texture if base_texture != null else DEFAULT_BASE_TEXTURE
		_base_sprite.position = Vector2.ZERO

	_refresh_side_sprite(_side_top_sprite, side_top, -PI * 0.5)
	_refresh_side_sprite(_side_right_sprite, side_right, 0.0)
	_refresh_side_sprite(_side_bottom_sprite, side_bottom, PI * 0.5)
	_refresh_side_sprite(_side_left_sprite, side_left, PI)


func _refresh_side_sprite(sprite: Sprite2D, side: SideType, side_rotation: float) -> void:
	if sprite == null:
		return
	if side == SideType.IN:
		sprite.visible = false
		return

	var is_out := side == SideType.OUT
	var texture := out_texture if is_out else close_texture
	if texture == null:
		texture = DEFAULT_OUT_TEXTURE if is_out else DEFAULT_CLOSE_TEXTURE
	if texture == null:
		sprite.visible = false
		return

	sprite.visible = true
	sprite.texture = texture
	sprite.rotation = side_rotation

	var texture_width := float(texture.get_width())
	var right_offset_x := (PIECE_SIZE * 0.5) if is_out else (PIECE_SIZE * 0.5 - texture_width * 0.5)
	var center := Vector2(PIECE_SIZE * 0.5, PIECE_SIZE * 0.5)
	var rotated_offset := Vector2(right_offset_x, 0.0).rotated(side_rotation)
	sprite.position = center + rotated_offset


func _ensure_wall_map_node() -> void:
	var existing := get_node_or_null("WallMap")
	if existing == null:
		var created := _create_wall_map_node()
		if created == null:
			return

		created.name = "WallMap"
		if created is Node2D:
			(created as Node2D).position = Vector2.ZERO
			(created as Node2D).z_index = 4
		add_child(created)

		var scene_root := get_tree().edited_scene_root
		if scene_root != null:
			(created as Node).owner = scene_root
		existing = created

	_assign_default_wall_tileset(existing)


func _create_wall_map_node() -> Node:
	if ClassDB.class_exists("TileMapLayer"):
		var layer_value: Variant = ClassDB.instantiate("TileMapLayer")
		if layer_value is Node:
			return layer_value as Node

	if ClassDB.class_exists("TileMap"):
		var tile_map_value: Variant = ClassDB.instantiate("TileMap")
		if tile_map_value is Node:
			return tile_map_value as Node

	return null


func _assign_default_wall_tileset(wall_map_node: Node) -> void:
	if wall_map_node == null:
		return
	var tile_set_value: Variant = wall_map_node.get("tile_set")
	if tile_set_value != null:
		return

	var tileset := _build_default_wall_tileset()
	if tileset != null:
		wall_map_node.set("tile_set", tileset)


func _build_default_wall_tileset() -> TileSet:
	if DEFAULT_WALL_TILE_TEXTURE == null:
		return null

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(int(PIECE_SIZE), int(PIECE_SIZE))

	var atlas := TileSetAtlasSource.new()
	atlas.texture = DEFAULT_WALL_TILE_TEXTURE
	atlas.texture_region_size = Vector2i(int(PIECE_SIZE), int(PIECE_SIZE))
	atlas.create_tile(Vector2i.ZERO)
	tileset.add_source(atlas)
	return tileset


func to_block_dict() -> Dictionary:
	var block := {
		"name": name,
		"role": _role_to_string(role),
		"sides": [int(side_top), int(side_right), int(side_bottom), int(side_left)],
		"draggable": draggable,
	}

	match placement_mode:
		PlacementMode.BOARD_CELL:
			block["cell"] = board_cell
		PlacementMode.SPAWN_CELL:
			block["spawn_cell"] = spawn_cell
		PlacementMode.TRAY_CELL:
			block["tray_cell"] = tray_cell
		PlacementMode.POSITION:
			block["position"] = explicit_position

	var wall_map_name := wall_map.strip_edges()
	if wall_map_name.is_empty():
		wall_map_name = name
	block["wall_map"] = wall_map_name

	var style := {}
	if base_texture != null:
		style["base_texture"] = base_texture
	if out_texture != null:
		style["out_texture"] = out_texture
	if close_texture != null:
		style["close_texture"] = close_texture
	if not style.is_empty():
		block["style"] = style

	return block


func _role_to_string(piece_role: PieceRole) -> String:
	match piece_role:
		PieceRole.START:
			return "start"
		PieceRole.END:
			return "end"
		_:
			return "normal"
