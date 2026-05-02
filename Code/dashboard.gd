extends Control

const MAIN_MENU := "res://Levels/MainMenu.tscn"

func _on_dashboard_pressed() -> void:
	if get_tree().paused:
		get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)
