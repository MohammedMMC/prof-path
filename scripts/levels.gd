extends Control


const LEVEL_SCENE_DIR := "res://scenes/levels/"
const FADE_DURATION := 0.35

@onready var fade_rect: ColorRect = $FadeRect
@onready var level_buttons: Array[TextureButton] = [
	$GridContainer/Level01,
	$GridContainer/Level02,
	$GridContainer/Level03,
	$GridContainer/Level04,
	$GridContainer/Level05,
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	fade_rect.color = Color(0, 0, 0, 0)

	for button in level_buttons:
		var scene_path := _scene_path_for_button(button)
		var scene_exists := ResourceLoader.exists(scene_path)
		button.disabled = not scene_exists
		if scene_exists:
			button.pressed.connect(_on_level_button_pressed.bind(scene_path))


func _on_level_button_pressed(scene_path: String) -> void:
	_set_level_buttons_enabled(false)
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, FADE_DURATION)
	tween.finished.connect(func() -> void:
		get_tree().change_scene_to_file(scene_path)
	)


func _set_level_buttons_enabled(enabled: bool) -> void:
	for button in level_buttons:
		if ResourceLoader.exists(_scene_path_for_button(button)):
			button.disabled = not enabled


func _scene_path_for_button(button: TextureButton) -> String:
	return LEVEL_SCENE_DIR + button.name.to_lower() + ".tscn"
