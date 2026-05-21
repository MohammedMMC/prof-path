extends Node

const MUSIC_STREAM := preload("res://audio/background.mp3")
const FADE_IN_DURATION := 1.2
const START_VOLUME_DB := -30.0
const TARGET_VOLUME_DB := -8.0
 
var _player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "BackgroundMusic"
	_player.stream = MUSIC_STREAM
	_player.volume_db = START_VOLUME_DB
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)

	var mp3_stream := MUSIC_STREAM as AudioStreamMP3
	if mp3_stream:
		mp3_stream.loop = true

	if not _player.playing:
		_player.play()
		var tween := create_tween()
		var tweener := tween.tween_property(_player, "volume_db", TARGET_VOLUME_DB, FADE_IN_DURATION)
		tweener.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
