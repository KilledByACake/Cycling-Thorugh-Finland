extends Control

const LEVEL1_SCENE_PATH := "res://Levels/level_1.tscn"
const MAIN_MENU_SCENE_PATH := "res://Levels/main_menu.tscn"

func set_result(_won: bool, energy: int, target: int, _player_name: String = "") -> void:
	var title := $CenterContainer/VBoxContainer/TitleLabel as Label
	var info  := $CenterContainer/VBoxContainer/InfoLabel as Label
	if title:
		title.text = "Results"
	if info:
		info.text = "Energy: %d / %d" % [energy, target]

func _on_retry_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL1_SCENE_PATH)

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
