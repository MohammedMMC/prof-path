extends Control


const LEVEL_SCENE_DIR := "res://scenes/levels/"
const FADE_DURATION := 0.35
const LEVEL_PROGRESS := preload("res://scripts/level_progress.gd")
const SECRET_UNLOCK_CODE := "test1234"
const SECRET_RESET_CODE := "reset"

@onready var fade_rect: ColorRect = $FadeRect
var level_buttons: Array[TextureButton] = []

var _secret_buffer := ""
var _force_unlock_all := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	fade_rect.color = Color(0, 0, 0, 0)
	set_process_unhandled_input(true)
	_collect_level_buttons()

	for button in level_buttons:
		var scene_path := _scene_path_for_button(button)
		var scene_exists := ResourceLoader.exists(scene_path)
		if scene_exists:
			button.pressed.connect(_on_level_button_pressed.bind(scene_path))

	_refresh_level_button_states()


func _on_level_button_pressed(scene_path: String) -> void:
	_set_level_buttons_enabled(false)
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, FADE_DURATION)
	tween.finished.connect(func() -> void:
		get_tree().change_scene_to_file(scene_path)
	)


func _set_level_buttons_enabled(enabled: bool) -> void:
	for button in level_buttons:
		button.disabled = not enabled


func _refresh_level_button_states() -> void:
	var highest_unlocked := LEVEL_PROGRESS.get_highest_unlocked_level()
	for button in level_buttons:
		var button_level := _level_number_from_button_name(button.name)
		if button_level <= 0:
			button.disabled = true
			continue

		var scene_path := _scene_path_for_button(button)
		var scene_exists := ResourceLoader.exists(scene_path)
		if not scene_exists:
			button.disabled = true
			continue

		var is_unlocked := _force_unlock_all or button_level <= highest_unlocked
		button.disabled = not is_unlocked


func _collect_level_buttons() -> void:
	level_buttons.clear()
	var grid := get_node_or_null("GridContainer")
	if not (grid is GridContainer):
		return

	for child in (grid as GridContainer).get_children():
		if child is TextureButton:
			var button := child as TextureButton
			if _level_number_from_button_name(button.name) > 0:
				level_buttons.append(button)


func _scene_path_for_button(button: TextureButton) -> String:
	return LEVEL_SCENE_DIR + button.name.to_lower() + ".tscn"


func _level_number_from_button_name(button_name: String) -> int:
	var regex := RegEx.new()
	if regex.compile("(?i)level(\\d+)") != OK:
		return -1

	var found := regex.search(button_name)
	if found == null:
		return -1

	var digits := found.get_string(1)
	if not digits.is_valid_int():
		return -1

	return int(digits)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	var typed := key_event.as_text_key_label().to_lower()
	if typed.length() != 1:
		return

	var code := typed.unicode_at(0)
	var is_letter := code >= 97 and code <= 122
	var is_digit := code >= 48 and code <= 57
	if not is_letter and not is_digit:
		return

	_secret_buffer += typed
	var max_secret_length: int = maxi(SECRET_UNLOCK_CODE.length(), SECRET_RESET_CODE.length())
	if _secret_buffer.length() > max_secret_length:
		_secret_buffer = _secret_buffer.substr(_secret_buffer.length() - max_secret_length)

	if _secret_buffer.ends_with(SECRET_RESET_CODE):
		LEVEL_PROGRESS.clear_progress()
		_force_unlock_all = false
		_secret_buffer = ""
		_refresh_level_button_states()
		return

	if _secret_buffer.ends_with(SECRET_UNLOCK_CODE):
		_force_unlock_all = true
		_secret_buffer = ""
		_refresh_level_button_states()
