extends Control
# Result screen showing daily high scores.
# Prefers today's display-only "reset-view" list; falls back to canonical daily list.
# Adding a score here does not modify how lists are chosen; HighScores controls that.

const LEVEL1_SCENE_PATH: String = "res://Levels/Game.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://Levels/Main.tscn"
const SHOW_TOP_N: int = 5

@onready var center: CenterContainer = get_node_or_null("CenterContainer") as CenterContainer
@onready var vbox: VBoxContainer = get_node_or_null("CenterContainer/VBoxContainer") as VBoxContainer
@onready var title_label: Label = get_node_or_null("CenterContainer/VBoxContainer/VBoxContainer/TitleLabel") as Label
@onready var info_label: Label = get_node_or_null("CenterContainer/VBoxContainer/VBoxContainer/InfoLabel") as Label
@onready var retry_btn: Button = get_node_or_null("CenterContainer/VBoxContainer/HBoxContainer/Retry") as Button
@onready var main_btn: Button = get_node_or_null("CenterContainer/VBoxContainer/HBoxContainer/Main Menu") as Button

var _score_added: bool = false # prevents double insertion of the same round

func _ready() -> void:
	# Ensure a single Result instance to avoid overlapping labels.
	add_to_group("ResultScreen")
	for n in get_tree().get_nodes_in_group("ResultScreen"):
		if n != self:
			n.queue_free()

	# Labels should not block input; containers only pass events through.
	if title_label: title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if info_label: info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if center: center.mouse_filter = Control.MOUSE_FILTER_PASS
	if vbox: vbox.mouse_filter = Control.MOUSE_FILTER_PASS

	# Wire buttons once.
	if retry_btn:
		retry_btn.disabled = false
		if not retry_btn.pressed.is_connected(_on_Retry_pressed):
			retry_btn.pressed.connect(_on_Retry_pressed)
	if main_btn:
		main_btn.disabled = false
		if not main_btn.pressed.is_connected(_on_Main_Menu_pressed):
			main_btn.pressed.connect(_on_Main_Menu_pressed)

func set_result(_won: bool, energy: int, _target: int, player_name: String = "") -> void:
	# Resolve player name (UI may pass empty).
	var player_name_text := player_name
	if player_name_text == "" and get_tree().root.has_meta("player_name"):
		player_name_text = str(get_tree().root.get_meta("player_name"))
	if player_name_text == "":
		player_name_text = "Player"

	# Add score only once and ignore zero energy (avoids duplicate/placeholder entries).
	var hs := get_node_or_null("/root/HighScores")
	if hs and energy > 0 and not _score_added:
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
		_score_added = true

	# Title
	if title_label:
		title_label.text = "DAILY HIGH SCORES"

	# Prefer today's reset-view list; fallback to canonical daily.
	var list_txt := "No scores yet today."
	if hs:
		var top: Array = hs.call("top_today_reset", SHOW_TOP_N, true)
		if top.size() == 0:
			top = hs.call("top_today", SHOW_TOP_N, true)
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

	# Render text
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
