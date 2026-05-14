# res://Code/Screens/view_highscores.gd
# High score viewer: browse categories with left/right and show score rows.

extends Control

# Scenes to load when pressing "Start Game".
const NAME_INPUT_SCENE_PATH: String = "res://Levels/NameInput.tscn"
const MAIN_SCENE_PATH: String = "res://Levels/Main.tscn"

# Signals for parent scene navigation.
signal back_pressed
signal start_game_pressed

# References to UI nodes (assigned in _ready).
var left_btn: Button
var right_btn: Button
var title_lbl: Label
var mid_area: Control
var back_btn: Button
var game_btn: Button

# Container that holds dynamically created rows.
var list_root: VBoxContainer

# Category definitions (order used for left/right cycling).
# n = number of entries to show for that category.
const CATEGORIES := [
	{"id": "today_all",     "title": "Today (all attempts)",  "n": 10},
	{"id": "today_best",    "title": "Today (best per name)", "n": 10}, # uses reset -> daily fallback
	{"id": "today_session", "title": "Today (session)",       "n": 10}, # reset-only
	{"id": "month",         "title": "This month",            "n": 10},
	{"id": "year",          "title": "This year",             "n": 10},
	{"id": "alltime",       "title": "All-time",              "n": 5},
]

# Index into CATEGORIES for the active category.
var cat_index: int = 0


# Called when the node enters the scene tree; set up signals and draw initial view.
func _ready() -> void:
	# Resolve node references at runtime.
	left_btn = get_node("VBoxContainer/TopButtons/Left") as Button
	right_btn = get_node("VBoxContainer/TopButtons/Right") as Button
	title_lbl = get_node("VBoxContainer/TopButtons/Type") as Label
	mid_area = get_node("VBoxContainer/Highscores") as Control
	back_btn = get_node("VBoxContainer/BottomButtons/Back") as Button
	game_btn = get_node("VBoxContainer/BottomButtons/Game") as Button

	# Connect signals only once (avoid "already connected" errors).
	if not left_btn.pressed.is_connected(_on_left_pressed):
		left_btn.pressed.connect(_on_left_pressed)
	if not right_btn.pressed.is_connected(_on_right_pressed):
		right_btn.pressed.connect(_on_right_pressed)
	if not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)
	if not game_btn.pressed.is_connected(_on_game_pressed):
		game_btn.pressed.connect(_on_game_pressed)

	# Ensure a VBoxContainer exists to hold the rows.
	list_root = _ensure_list_root()
	_refresh()


# Handle keyboard/gamepad left/right to switch categories from anywhere.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_on_left_pressed()
	elif event.is_action_pressed("ui_right"):
		_on_right_pressed()


# Find or create a VBoxContainer under mid_area to hold the score rows.
func _ensure_list_root() -> VBoxContainer:
	if mid_area is VBoxContainer:
		var vb: VBoxContainer = mid_area as VBoxContainer
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		return vb

	var existing: Node = mid_area.get_node_or_null("ScoresList")
	if existing is VBoxContainer:
		return existing as VBoxContainer

	var vb_new := VBoxContainer.new()
	vb_new.name = "ScoresList"
	vb_new.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb_new.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb_new.alignment = BoxContainer.ALIGNMENT_BEGIN
	vb_new.add_theme_constant_override("separation", 8)
	mid_area.add_child(vb_new)
	return vb_new


# Button: left arrow. Go to previous category (wrap) and refresh.
func _on_left_pressed() -> void:
	cat_index = (cat_index - 1 + CATEGORIES.size()) % CATEGORIES.size()
	_refresh()


# Button: right arrow. Go to next category (wrap) and refresh.
func _on_right_pressed() -> void:
	cat_index = (cat_index + 1) % CATEGORIES.size()
	_refresh()


# Button: Back. Emit to parent scene.
func _on_back_pressed() -> void:
	emit_signal("back_pressed")


# Button: Start Game. Prefer NameInput scene; fall back to Main if missing.
func _on_game_pressed() -> void:
	var target_path: String = NAME_INPUT_SCENE_PATH
	if not ResourceLoader.exists(target_path):
		target_path = MAIN_SCENE_PATH
	if ResourceLoader.exists(target_path):
		get_tree().change_scene_to_file(target_path)
		emit_signal("start_game_pressed")
	else:
		push_error("Neither NameInput nor Main scene found. Check paths.")


# Update title and repopulate rows for the active category.
func _refresh() -> void:
	var cat: Dictionary = CATEGORIES[cat_index]
	title_lbl.text = str(cat["title"])
	var items: Array = _fetch_scores(str(cat["id"]), int(cat["n"]))
	_populate(items)


# Get the high score provider Autoload (“/root/HighScores”), or null if missing.
func _scores_api() -> Node:
	var n: Node = get_node_or_null("/root/HighScores")
	if n == null:
		push_warning("Autoload 'HighScores' not found. Add high_scores.gd as an Autoload named 'HighScores'.")
	return n


# Helper to call a HighScores method and return Array safely.
func _call_array(hs: Node, method: StringName, a0: Variant = null, a1: Variant = null, a2: Variant = null) -> Array:
	var v: Variant = hs.call(method, a0, a1, a2)
	if typeof(v) == TYPE_ARRAY:
		return v as Array
	return []


# Fetch entries for a category; arrays are returned high-to-low by score.
func _fetch_scores(id: String, n: int) -> Array:
	var hs: Node = _scores_api()
	if hs == null:
		return []

	match id:
		"today_all":
			return _top_today_all_attempts(hs, n)
		"today_best":
			# Same logic as result.gd: prefer reset-view, fallback to canonical daily
			var arr: Array = _call_array(hs, "top_today_reset", n, true)
			if arr.is_empty():
				arr = _call_array(hs, "top_today", n, true)
			return arr
		"today_session":
			return _call_array(hs, "top_today_reset", n, true)
		"month":
			return _call_array(hs, "top_month", n, true)
		"year":
			return _call_array(hs, "top_year", n, true)
		"alltime":
			return _call_array(hs, "top_alltime", n, true)
		_:
			return []


# Return today's date as "YYYY-MM-DD".
func _today_iso() -> String:
	var d: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


# Build “all attempts today” from history, sort by score desc, limit to n.
func _top_today_all_attempts(hs: Node, n: int) -> Array:
	# Read store as Variant, then verify the type and assign to a Dictionary.
	var store_v: Variant = hs.get("store")
	if typeof(store_v) != TYPE_DICTIONARY:
		return []
	var store: Dictionary = store_v

	# Read history as Variant and cast to Array for type safety.
	var history_v: Variant = store.get("history", [])
	var hist: Array = history_v as Array

	var today: String = _today_iso()
	var out: Array = []

	for e in hist:
		var ed: Dictionary = e
		if str(ed.get("date", "")) == today:
			out.append(ed)

	out.sort_custom(func(a, b):
		return float((a as Dictionary).get("score", 0.0)) > float((b as Dictionary).get("score", 0.0))
	)

	if out.size() > n:
		out.resize(n)
	return out


# Remove old rows and create one row per entry (rank, name, score).
func _populate(items: Array) -> void:
	for c in list_root.get_children():
		c.queue_free()

	if items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No data"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list_root.add_child(empty_lbl)
		return

	var rank: int = 1
	for e in items:
		var entry: Dictionary = e

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 12)

		var rank_lbl := Label.new()
		rank_lbl.text = str(rank) + "."
		rank_lbl.custom_minimum_size.x = 40

		var name_lbl := Label.new()
		var raw_name: Variant = entry.get("name", "Unknown")
		# Convert any type to text safely (avoids String(...) ctor errors).
		var name_text: String = str(raw_name)
		name_lbl.text = name_text
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var score_lbl := Label.new()
		var raw_score: Variant = entry.get("score", 0)
		var score_text: String = str(int(raw_score))
		score_lbl.text = score_text
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_lbl.custom_minimum_size.x = 120

		row.add_child(rank_lbl)
		row.add_child(name_lbl)
		row.add_child(score_lbl)

		list_root.add_child(row)
		rank += 1
