extends RefCounted
class_name LevelProgress


const SAVE_PATH := "user://level_progress.cfg"
const SAVE_SECTION := "progress"
const KEY_HIGHEST_UNLOCKED := "highest_unlocked_level"
const KEY_HIGHEST_COMPLETED := "highest_completed_level"


static func get_highest_unlocked_level() -> int:
	var config := ConfigFile.new()
	var load_status := config.load(SAVE_PATH)
	if load_status != OK:
		return 1

	var value := int(config.get_value(SAVE_SECTION, KEY_HIGHEST_UNLOCKED, 1))
	return max(1, value)


static func get_highest_completed_level() -> int:
	var config := ConfigFile.new()
	var load_status := config.load(SAVE_PATH)
	if load_status != OK:
		return 0

	var value := int(config.get_value(SAVE_SECTION, KEY_HIGHEST_COMPLETED, 0))
	return max(0, value)


static func complete_level(level_number: int) -> void:
	if level_number <= 0:
		return

	var config := ConfigFile.new()
	config.load(SAVE_PATH)

	var highest_completed := int(config.get_value(SAVE_SECTION, KEY_HIGHEST_COMPLETED, 0))
	var highest_unlocked := int(config.get_value(SAVE_SECTION, KEY_HIGHEST_UNLOCKED, 1))

	highest_completed = max(highest_completed, level_number)
	highest_unlocked = max(highest_unlocked, level_number + 1)

	config.set_value(SAVE_SECTION, KEY_HIGHEST_COMPLETED, highest_completed)
	config.set_value(SAVE_SECTION, KEY_HIGHEST_UNLOCKED, max(1, highest_unlocked))
	config.save(SAVE_PATH)


static func unlock_up_to(level_number: int) -> void:
	if level_number <= 0:
		return

	var config := ConfigFile.new()
	config.load(SAVE_PATH)

	var highest_unlocked := int(config.get_value(SAVE_SECTION, KEY_HIGHEST_UNLOCKED, 1))
	highest_unlocked = max(highest_unlocked, level_number)
	config.set_value(SAVE_SECTION, KEY_HIGHEST_UNLOCKED, highest_unlocked)
	config.save(SAVE_PATH)


static func clear_progress() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)