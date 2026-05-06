extends Node
# TO RESET DAILY HIGH SCORE, FILL OUT _RESET

const FILE_PATH: String = "user://highscores.json"

const TOPN_DAILY: int = 30
const TOPN_MONTHLY: int = 5
const TOPN_YEARLY: int = 5
const TOPN_ALLTIME: int = 5

var store: Dictionary = {}

func _ready() -> void:
	store = _load_store()
	_rollover_if_new_day()

func _empty_store() -> Dictionary:
	return {
		"history": [],
		"daily": {},
		"monthly": {},
		"yearly": {},
		"alltime": [],
		"daily_reset": {},          # buckets keyed by "YYYY-MM-DD#session"
		"daily_reset_session": {},  # date -> current session index (0 means none)
		"last_seen_date": ""
	}

func _today_iso() -> String:
	var d: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

func _bucket_keys(datestr: String) -> Array:
	return [datestr, datestr.substr(0, 7), datestr.substr(0, 4)]

# Insert ascending by key with a cap; returns inserted index or -1 if dropped.
func _asc_insert_cap(arr: Array, entry: Dictionary, key: String = "score", cap: int = 5) -> int:
	arr.append(entry)
	var i: int = arr.size() - 1
	while i > 0 and float((arr[i] as Dictionary)[key]) < float((arr[i - 1] as Dictionary)[key]):
		var tmp: Dictionary = arr[i - 1] as Dictionary
		arr[i - 1] = arr[i]
		arr[i] = tmp
		i -= 1
	if arr.size() > cap:
		var extras: int = arr.size() - cap
		var kept: bool = i >= extras
		for _j in range(extras):
			arr.remove_at(0)
		i = (i - extras) if kept else -1
	return i

func _idx_to_rank(idx: int, bucket: Array) -> Variant:
	if idx < 0:
		return null
	return bucket.size() - idx # 1 = best

func _save_store() -> void:
	var f: FileAccess = FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(store, "\t"))

func _normalize_entry(entry: Dictionary) -> Dictionary:
	return {
		"name": str(entry.get("name", "Unknown")),
		"score": float(entry.get("score", 0.0)),
		"date": str(entry.get("date", _today_iso())),
		"energy_kj": float(entry.get("energy_kj", entry.get("score", 0.0))),
		"duration_sec": int(entry.get("duration_sec", 0)),
		"avg_power_w": entry.get("avg_power_w", null),
		"avg_speed": entry.get("avg_speed", null),
	}

# Normalize a name key (trim whitespace).
func _name_key(raw_name: String) -> String:
	return raw_name.strip_edges(true, true)

# Find the index for a name in a bucket (returns -1 if not found).
func _index_of_name(arr: Array, player_name: String) -> int:
	var k: String = _name_key(player_name)
	for i in range(arr.size()):
		var it: Dictionary = arr[i]
		if _name_key(str(it.get("name", ""))) == k:
			return i
	return -1

# Unique per name per bucket:
# - Keep the best score per name (higher is better).
# - Returns the index of the new entry, or -1 if dropped (existing was better/equal).
func _upsert_unique_by_name(arr: Array, entry: Dictionary, cap: int) -> int:
	var k: String = _name_key(str(entry.get("name", "")))
	var existing_idx: int = -1
	var existing_score: float = -1e30

	for i in range(arr.size()):
		var it: Dictionary = arr[i]
		if _name_key(str(it.get("name", ""))) == k:
			existing_idx = i
			existing_score = float(it.get("score", 0.0))
			break

	var new_score: float = float(entry.get("score", 0.0))

	# Keep best score per name
	if existing_idx >= 0 and existing_score >= new_score:
		return -1

	if existing_idx >= 0:
		arr.remove_at(existing_idx)

	return _asc_insert_cap(arr, entry, "score", cap)

# Helper: compose the reset key for today’s active session.
func _reset_key_for(day_key: String, sessions: Dictionary) -> String:
	var sess: int = int(sessions.get(day_key, 0))
	if sess <= 0:
		return ""
	return "%s#%d" % [day_key, sess]

# Ensure a fresh session pointer when the day changes.
func _rollover_if_new_day() -> void:
	var today: String = _today_iso()
	var last: String = str(store.get("last_seen_date", ""))
	if last != today:
		store["last_seen_date"] = today
		var sessions: Dictionary = (store.get("daily_reset_session", {}) as Dictionary)
		var new_sessions: Dictionary = {}
		if sessions.has(today):
			new_sessions[today] = int(sessions[today]) # keep today only
		store["daily_reset_session"] = new_sessions
		_save_store()

# Rebuild canonical buckets from history.
func _load_store() -> Dictionary:
	if not FileAccess.file_exists(FILE_PATH):
		return _empty_store()
	var txt: String = FileAccess.get_file_as_string(FILE_PATH)
	var data: Variant = JSON.parse_string(txt)

	if typeof(data) == TYPE_DICTIONARY:
		var s: Dictionary = _empty_store()
		for e in (data as Dictionary).get("history", []):
			_add_score_internal(s, e as Dictionary, false)
		# carry optional fields if present
		if (data as Dictionary).has("daily_reset"):
			s["daily_reset"] = (data as Dictionary)["daily_reset"]
		if (data as Dictionary).has("daily_reset_session"):
			s["daily_reset_session"] = (data as Dictionary)["daily_reset_session"]
		if (data as Dictionary).has("last_seen_date"):
			s["last_seen_date"] = (data as Dictionary)["last_seen_date"]
		return s
	elif typeof(data) == TYPE_ARRAY:
		var s2: Dictionary = _empty_store()
		for e2 in (data as Array):
			_add_score_internal(s2, e2 as Dictionary, false)
		return s2
	return _empty_store()

func _add_score_internal(dst_store: Dictionary, entry: Dictionary, do_save: bool) -> Dictionary:
	var e: Dictionary = _normalize_entry(entry)
	dst_store["history"].append(e)

	var keys: Array = _bucket_keys(e["date"])
	var day_key: String = keys[0]
	var month_key: String = keys[1]
	var year_key: String = keys[2]

	# Canonical buckets
	var daily: Array = (dst_store["daily"].get(day_key, []) as Array)
	dst_store["daily"][day_key] = daily
	var di: int = _upsert_unique_by_name(daily, e, TOPN_DAILY)
	if di == -1:
		di = _index_of_name(daily, e["name"])

	var monthly: Array = (dst_store["monthly"].get(month_key, []) as Array)
	dst_store["monthly"][month_key] = monthly
	var mi: int = _upsert_unique_by_name(monthly, e, TOPN_MONTHLY)
	if mi == -1:
		mi = _index_of_name(monthly, e["name"])

	var yearly: Array = (dst_store["yearly"].get(year_key, []) as Array)
	dst_store["yearly"][year_key] = yearly
	var yi: int = _upsert_unique_by_name(yearly, e, TOPN_YEARLY)
	if yi == -1:
		yi = _index_of_name(yearly, e["name"])

	var alltime: Array = (dst_store.get("alltime", []) as Array)
	dst_store["alltime"] = alltime
	var ai: int = _upsert_unique_by_name(alltime, e, TOPN_ALLTIME)
	if ai == -1:
		ai = _index_of_name(alltime, e["name"])

	# Display-only: add to active reset session for that day if any
	var daily_reset: Dictionary = (dst_store.get("daily_reset", {}) as Dictionary)
	dst_store["daily_reset"] = daily_reset
	var sessions: Dictionary = (dst_store.get("daily_reset_session", {}) as Dictionary)
	dst_store["daily_reset_session"] = sessions
	var reset_key: String = _reset_key_for(day_key, sessions)
	if reset_key != "":
		var dr: Array = (daily_reset.get(reset_key, []) as Array)
		daily_reset[reset_key] = dr
		_upsert_unique_by_name(dr, e, TOPN_DAILY)

	if do_save:
		_save_store()

	return {
		"daily_rank": _idx_to_rank(di, daily),
		"monthly_rank": _idx_to_rank(mi, monthly),
		"yearly_rank": _idx_to_rank(yi, yearly),
		"alltime_rank": _idx_to_rank(ai, alltime),
	}

# Public API

func add_score(entry: Dictionary) -> Dictionary:
	return _add_score_internal(store, entry, true)

# Start a new display-only session for today
func reset_today_view() -> void:
	var today: String = _today_iso()
	var sessions: Dictionary = (store.get("daily_reset_session", {}) as Dictionary)
	store["daily_reset_session"] = sessions
	var next_sess: int = int(sessions.get(today, 0)) + 1
	sessions[today] = next_sess
	var key: String = "%s#%d" % [today, next_sess]
	var daily_reset: Dictionary = (store.get("daily_reset", {}) as Dictionary)
	store["daily_reset"] = daily_reset
	daily_reset[key] = []
	store["last_seen_date"] = today
	_save_store()

# Read only the newest session for today (or empty if none)
func top_today_reset(n: int = 5, highest_first: bool = true) -> Array:
	var today: String = _today_iso()
	var sessions: Dictionary = (store.get("daily_reset_session", {}) as Dictionary)
	var sess: int = int(sessions.get(today, 0))
	if sess <= 0:
		return []
	var key: String = "%s#%d" % [today, sess]
	var bucket: Array = (store.get("daily_reset", {}) as Dictionary).get(key, []) as Array
	return _top_from_bucket(bucket, n, highest_first)

func top_today(n: int = 5, highest_first: bool = true) -> Array:
	var bucket: Array = store["daily"].get(_today_iso(), []) as Array
	return _top_from_bucket(bucket, n, highest_first)

func top_month(n: int = 5, highest_first: bool = true) -> Array:
	var d: Dictionary = Time.get_date_dict_from_system()
	var key: String = "%04d-%02d" % [d.year, d.month]
	var bucket: Array = store["monthly"].get(key, []) as Array
	return _top_from_bucket(bucket, n, highest_first)

func top_year(n: int = 5, highest_first: bool = true) -> Array:
	var d: Dictionary = Time.get_date_dict_from_system()
	var key: String = "%04d" % [d.year]
	var bucket: Array = store["yearly"].get(key, []) as Array
	return _top_from_bucket(bucket, n, highest_first)

func top_alltime(n: int = 5, highest_first: bool = true) -> Array:
	var bucket: Array = store.get("alltime", []) as Array
	return _top_from_bucket(bucket, n, highest_first)

func alltime_count() -> int:
	return (store.get("alltime", []) as Array).size()

func _top_from_bucket(bucket: Array, n: int, highest_first: bool) -> Array:
	var take: int = min(n, bucket.size())
	var tail: Array = []
	for i in range(bucket.size() - take, bucket.size()):
		tail.append(bucket[i])
	if highest_first:
		tail.reverse()
	return tail
