extends Control

const LEVEL1_SCENE_PATH := "res://Levels/level_1.tscn"
const MAIN_MENU_SCENE_PATH := "res://Levels/main_menu.tscn"

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var info_label: Label = $CenterContainer/VBoxContainer/InfoLabel

func _ready() -> void:
	# Prevent clicks from reaching the game behind
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Populate from SceneTree meta if set_result() wasn’t called
	var won := bool(get_tree().get_meta("won", false))
	var energy := int(get_tree().get_meta("energy_points", 0))
	var target := int(get_tree().get_meta("target_energy", 200))
	var player_name := str(get_tree().get_meta("player_name", ""))
	set_result(won, energy, target, player_name)

func set_result(won: bool, energy: int, target: int, player_name: String) -> void:
	title_label.text = "You Won!" if won else "Game Over"
	var prefix := (player_name + " - ") if player_name != "" else ""
	info_label.text = prefix + "Energy: %d / %d" % [energy, target]

func _on_retry_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL1_SCENE_PATH)

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
