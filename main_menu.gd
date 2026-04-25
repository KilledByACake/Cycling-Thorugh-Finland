extends Control

const NAME_INPUT_SCENE_PATH := "res://Levels/name_input.tscn"    # replace with your exact path
const DASHBOARD_SCENE_PATH := "res://Levels/dashboard.tscn"       # replace or remove if not used

func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_file(NAME_INPUT_SCENE_PATH)

func _on_dashboard_pressed() -> void:
	get_tree().change_scene_to_file(DASHBOARD_SCENE_PATH)
