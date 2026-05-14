#High score viewer: logic only.
# Categories: Today (all attempts), Today (reset #N) per reset session (if any), This month, This year, All-time.
# Renders the entire list as multi-line text into the Label at "VBoxContainer/Highscores".

extends Control

const NAME_INPUT_SCENE_PATH: String = "res://Levels/NameInput.tscn"
const MAIN_SCENE_PATH: String = "res://Levels/Main.tscn"

signal back_pressed
signal start_game_pressed

# Node refs (wired in _ready)
var left_btn: Button
var right_btn: Button
var title_lbl: Label
var scores_label: Label  # Label at "VBoxContainer/Highscores"
var back_btn: Button
var game_btn: Button

# Built dynamically to include one per reset session today.
var CATEGORIES: Array = []
var cat_index: int = 0


func _ready() -> void:
	left_btn = get_node("VBoxContainer/TopButtons/Left") as Button
	right_btn = get_node("VBoxContainer/TopButtons/Right") as Button
	title_lbl = get_node("VBoxContainer/TopButtons/Type") as Label
	scores_label = get_node("VBoxContainer/Highscores") as Label
	back_btn = get_node("VBoxContainer/BottomButtons/Back") as Button
	game_btn = get_node("VBoxContainer/BottomButtons/Game") as Button

	if not left_btn.pressed.is_connected(_on_left_pressed):
		left_btn.pressed.connect(_on_left_pressed)
	if not right_btn.pressed.is_connected(_on_right_pressed):
		right_btn.pressed.connect(_on_right_pressed)
	if not back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.connect(_on_back_pressed)
	if not game_btn.pressed.is_connected(_on_game_pressed):
		game_btn.pressed.connect(_on_game_pressed)

	_rebuild_categories()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_on_left_pressed()
	elif event.is_action_pressed("ui_right"):
		_on_right_pressed()


# Categories:
# - Today (all attempts)
# - Today (reset #N) for each reset session today (only if at least one exists)
# - This month / This year / All-time
func _rebuild_categories() -> void:
	CATEGORIES.clear()

	CATEGORIES.append({"id": "today_all", "title": "Today's best", "n": 10})

	var hs: Node = _scores_api()
	if hs != null:
		var sessions: Array[int] = _get_today_reset_session_numbers(hs)
		for s in sessions:
			CATEGORIES.append({
				"id": "reset_%d" % s,
				"title": "Today (reset #%d)" % s,
				"n": 10
			})

	CATEGORIES.append({"id": "month",   "title": "This month", "n": 10})
	CATEGORIES.append({"id": "year",    "title": "This year",  "n": 10})
	CATEGORIES.append({"id": "alltime", "title": "All-time",   "n": 5})

	if CATEGORIES.size() > 0:
		cat_index = clamp(cat_index, 0, CATEGORIES.size() - 1)
	else:
		cat_index = 0


func _on_left_pressed() -> void:
	if CATEGORIES.is_empty():
		return
	cat_index = (cat_index - 1 + CATEGORIES.size()) % CATEGORIES.size()
	_refresh()


func _on_right_pressed() -> void:
	if CATEGORIES.is_empty():
		return
	cat_index = (cat_index + 1) % CATEGORIES.size()
	_refresh()


func _on_back_pressed() -> void:
	# Go straight to main menu from here (no parent needed).
	if ResourceLoader.exists(MAIN_SCENE_PATH):
		get_tree().change_scene_to_file(MAIN_SCENE_PATH)
		# Optional: keep the signal if any parent also listens.
		emit_signal("back_pressed")
	else:
		push_error("Main scene not found: " + MAIN_SCENE_PATH)


func _on_game_pressed() -> void:
	var target_path: String = NAME_INPUT_SCENE_PATH
	if not ResourceLoader.exists(target_path):
		target_path = MAIN_SCENE_PATH
	if ResourceLoader.exists(target_path):
		get_tree().change_scene_to_file(target_path)
		emit_signal("start_game_pressed")
	else:
		push_error("Neither NameInput nor Main scene found. Check paths.")


func _refresh() -> void:
	if CATEGORIES.is_empty():
		if title_lbl:
			title_lbl.text = "High Scores"
		_render_text([])
		return

	var cat: Dictionary = CATEGORIES[cat_index]
	if title_lbl:
		title_lbl.text = str(cat.get("title", "High Scores"))

	var items: Array = _fetch_scores(str(cat.get("id", "")), int(cat.get("n", 10)))
	_render_text(items)


# Locate Autoload provider.
func _scores_api() -> Node:
	var n: Node = get_node_or_null("/root/HighScores")
	if n == null:
		push_warning("Autoload 'HighScores' not found. Add high_scores.gd as an Autoload named 'HighScores'.")
	return n


# Safe dynamic call that passes only the provided args.
func _call_array(hs: Node, method: StringName, a0: Variant = null, a1: Variant = null) -> Array:
	var args: Array = []
	if a0 != null:
		args.append(a0)
	if a1 != null:
		args.append(a1)
	var v: Variant = hs.callv(method, args)
	if typeof(v) == TYPE_ARRAY:
		return v as Array
	return []


# Fetch entries for a category; arrays returned high-to-low by score.
func _fetch_scores(id: String, n: int) -> Array:
	var hs: Node = _scores_api()
	if hs == null:
		return []

	match id:
		"today_all":
			return _top_today_all_attempts(hs, n)
		"month":
			return _call_array(hs, "top_month", n, true)
		"year":
			return _call_array(hs, "top_year", n, true)
		"alltime":
			return _call_array(hs, "top_alltime", n, true)
		_:
			if id.begins_with("reset_"):
				var sess_str: String = id.substr(6, id.length() - 6)
				var sess_idx: int = int(sess_str)
				return _top_today_reset_for(hs, sess_idx, n)
			return []


# Date as "YYYY-MM-DD".
func _today_iso() -> String:
	var d: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


# All attempts today from history (not unique per name), sorted desc, limited to n.
func _top_today_all_attempts(hs: Node, n: int) -> Array:
	var store_v: Variant = hs.get("store")
	if typeof(store_v) != TYPE_DICTIONARY:
		return []
	var store: Dictionary = store_v

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


# Top N from a specific reset session today (highest first).
func _top_today_reset_for(hs: Node, session_idx: int, n: int) -> Array:
	var store_v: Variant = hs.get("store")
	if typeof(store_v) != TYPE_DICTIONARY:
		return []
	var store: Dictionary = store_v

	var daily_reset_v: Variant = store.get("daily_reset", {})
	if typeof(daily_reset_v) != TYPE_DICTIONARY:
		return []
	var daily_reset: Dictionary = daily_reset_v

	var key: String = "%s#%d" % [_today_iso(), session_idx]
	var bucket_v: Variant = daily_reset.get(key, [])
	var bucket: Array = bucket_v as Array
	return _pick_top_from_bucket(bucket, n)


# Gather available reset session numbers for today (sorted ascending).
func _get_today_reset_session_numbers(hs: Node) -> Array[int]:
	var store_v: Variant = hs.get("store")
	if typeof(store_v) != TYPE_DICTIONARY:
		return []

	var store: Dictionary = store_v
	var daily_reset_v: Variant = store.get("daily_reset", {})
	if typeof(daily_reset_v) != TYPE_DICTIONARY:
		return []

	var daily_reset: Dictionary = daily_reset_v
	var today: String = _today_iso()

	var sessions: Array[int] = []
	for k in daily_reset.keys():
		var key_str: String = str(k)
		if key_str.begins_with(today + "#"):
			var hash_pos: int = key_str.find("#")
			if hash_pos >= 0 and hash_pos + 1 < key_str.length():
				var s_num: int = int(key_str.substr(hash_pos + 1, key_str.length() - (hash_pos + 1)))
				if not sessions.has(s_num):
					sessions.append(s_num)

	sessions.sort()
	return sessions


# Mimic HighScores._top_from_bucket (take last n, reverse to highest-first).
func _pick_top_from_bucket(bucket: Array, n: int) -> Array:
	var take: int = min(n, bucket.size())
	var tail: Array = []
	for i in range(bucket.size() - take, bucket.size()):
		tail.append(bucket[i])
	tail.reverse()
	return tail


# Render list into the Highscores Label without header.
# Each line: "1.  <score>  <player name>"
func _render_text(items: Array) -> void:
	if scores_label == null:
		return

	if items.is_empty():
		scores_label.text = "No Scores Yet"
		return

	var names: Array[String] = []
	var scores: Array[String] = []
	for e in items:
		var d: Dictionary = e
		names.append(str(d.get("name", "?")))
		scores.append(str(int(d.get("score", 0))))

	var rank_w: int = str(items.size()).length() + 1
	var score_w: int = max(1, _max_len_in(scores))

	var lines: Array[String] = []
	for i in range(items.size()):
		var rank_txt: String = str(i + 1) + "."
		var score_txt: String = scores[i]
		var name_txt: String = names[i]
		var line: String = _rpad(rank_txt, rank_w) + "  " + _lpad(score_txt, score_w) + "  " + name_txt
		lines.append(line)

	scores_label.text = "\n".join(lines)


# Helpers for padding/alignment (spaces only)
func _rpad(s: String, w: int) -> String:
	var out: String = s
	while out.length() < w:
		out += " "
	return out

func _lpad(s: String, w: int) -> String:
	var out: String = s
	while out.length() < w:
		out = " " + out
	return out

func _max_len_in(arr: Array[String]) -> int:
	var m: int = 0
	for s in arr:
		var L: int = s.length()
		if L > m:
			m = L
	return m
