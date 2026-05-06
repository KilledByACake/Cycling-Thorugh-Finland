extends Control

const NAME_INPUT_SCENE_PATH: String = "res://Screen/NameInput.tscn"
const DASHBOARD_SCENE_PATH: String = "res://Levels/Dashboard.tscn" 

func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_file(NAME_INPUT_SCENE_PATH)

func _on_dashboard_pressed() -> void:
	get_tree().change_scene_to_file(DASHBOARD_SCENE_PATH)
	
	
