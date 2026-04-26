extends Control

const LEVEL1_SCENE_PATH: String = "res://Levels/level_1.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://Levels/main_menu.tscn"
const SHOW_TOP_N: int = 5

@onready var center: CenterContainer = $CenterContainer
@onready var vbox: VBoxContainer = $CenterContainer/VBoxContainer
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var info_label: Label = $CenterContainer/VBoxContainer/InfoLabel
@onready var retry_btn: Button = $CenterContainer/VBoxContainer/HBoxContainer/Retry
@onready var main_btn: Button = get_node("CenterContainer/VBoxContainer/HBoxContainer/Main Menu") as Button

func _ready() -> void:
	
	print("/root/HighScores exists: ", get_node_or_null("/root/HighScores") != null)
	# Labels should not capture the mouse
	if title_label: title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if info_label: info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Containers only pass events
	if center: center.mouse_filter = Control.MOUSE_FILTER_PASS
	if vbox: vbox.mouse_filter = Control.MOUSE_FILTER_PASS

	# Ensure buttons are clickable and connected once
	if retry_btn:
		retry_btn.disabled = false
		if not retry_btn.pressed.is_connected(_on_Retry_pressed):
			retry_btn.pressed.connect(_on_Retry_pressed)
	if main_btn:
		main_btn.disabled = false
		if not main_btn.pressed.is_connected(_on_Main_Menu_pressed):
			main_btn.pressed.connect(_on_Main_Menu_pressed)

func set_result(_won: bool, energy: int, target: int, player_name: String = "") -> void:
	var player_name_text := player_name
	if player_name_text == "" and get_tree().has_meta("player_name"):
		player_name_text = str(get_tree().get_meta("player_name"))
	if player_name_text == "":
		player_name_text = "Player"

	var hs := get_node_or_null("/root/HighScores")
	if hs:
		var entry := {
			"name": player_name_text,
			"score": float(energy),
			"date": _today_iso(),
			"energy_kj": float(energy),
			"duration_sec": 0,
			"avg_power_w": null,
			"avg_speed": null,
		}
		hs.call("add_score", entry)

	if title_label:
		title_label.text = "HIGH SCORES"

	# Build ranked list: "1. Name — Score"
	var list_txt := "No scores yet."
	if hs:
		var top: Array = hs.call("top_alltime", SHOW_TOP_N, true)
		if top.size() > 0:
			var lines: Array[String] = []
			for i in range(top.size()):
				var e: Dictionary = top[i]
				lines.append("%d. %s — %d" % [i + 1, str(e.get("name", "?")), int(e.get("score", 0))])
			var txt := ""
			for i in lines.size():
				if i > 0: txt += "\n"
				txt += lines[i]
			list_txt = txt

	if info_label:
		info_label.text = list_txt
		info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _on_Retry_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL1_SCENE_PATH)

func _on_Main_Menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _today_iso() -> String:
	var d: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]
