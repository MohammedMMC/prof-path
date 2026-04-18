extends Control


const LEVELS_SCENE := "res://scenes/levels.tscn"
const FADE_DURATION := 0.35

@onready var play_button: TextureButton = $PlayButton
@onready var exit_button: TextureButton = $ExitButton
@onready var fade_rect: ColorRect = $FadeRect

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)
	fade_rect.color = Color(0, 0, 0, 0)


func _on_play_button_pressed() -> void:
	_set_buttons_enabled(false)
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, FADE_DURATION)
	tween.finished.connect(func() -> void:
		get_tree().change_scene_to_file(LEVELS_SCENE)
	)


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _set_buttons_enabled(enabled: bool) -> void:
	play_button.disabled = not enabled
	exit_button.disabled = not enabled
