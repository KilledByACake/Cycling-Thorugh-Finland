extends Control

# Main menu screen: handles navigation to name input and dashboard scenes.

const NAME_INPUT_SCENE_PATH: String = "res://Levels/NameInput.tscn"
const DASHBOARD_SCENE_PATH: String = "res://Levels/dashboard.tscn"
const HIGHSCORES_SCENE_PATH: String = "res://Levels/Highscores.tscn"

# Called by the Start Game button; goes to the name input screen.
func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_file(NAME_INPUT_SCENE_PATH)

# Called by the Dashboard button; goes to the dashboard scene.
func _on_dashboard_pressed() -> void:
	get_tree().change_scene_to_file(DASHBOARD_SCENE_PATH)

# Called by the Highscores button; goes to the highscore scene.
func _on_highscores_pressed() -> void:
	get_tree().change_scene_to_file(HIGHSCORES_SCENE_PATH)
