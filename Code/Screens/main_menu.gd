extends Control

# Main menu screen: handles navigation to name input and dashboard scenes.

const NAME_INPUT_SCENE_PATH: String = "res://Levels/InputName.tscn"
const DASHBOARD_SCENE_PATH: String = "res://Levels/Dashboard.tscn"

# Called by the Start Game button; goes to the name input screen.
func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_file(NAME_INPUT_SCENE_PATH)

# Called by the Dashboard button; goes to the dashboard scene.
func _on_dashboard_pressed() -> void:
	get_tree().change_scene_to_file(DASHBOARD_SCENE_PATH)
