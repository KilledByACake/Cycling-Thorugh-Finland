extends Node

const FILE_PATH: String = "user://highscores.json"

const TOPN_DAILY: int = 30
const TOPN_MONTHLY: int = 5
const TOPN_YEARLY: int = 5
const TOPN_ALLTIME: int = 5

var store: Dictionary = {}

func _ready() -> void:
	store = _load_store()

func _empty_store() -> Dictionary:
	return {
		"history": [],
		"daily": {},
		"monthly": {},
		"yearly": {},
		"alltime": []
	}

func _today_iso() -> String:
	var d: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

func _bucket_keys(datestr: String) -> Array:
	return [datestr, datestr.substr(0, 7), datestr.substr(0, 4)]

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
	return bucket.size() - idx  # 1 = best

func _load_store() -> Dictionary:
	if not FileAccess.file_exists(FILE_PATH):
		return _empty_store()
	var txt: String = FileAccess.get_file_as_string(FILE_PATH)
	var data: Variant = JSON.parse_string(txt)

	if typeof(data) == TYPE_DICTIONARY:
		var s: Dictionary = _empty_store()
		for e in (data as Dictionary).get("history", []):
			_add_score_internal(s, e as Dictionary, false)
		return s
	elif typeof(data) == TYPE_ARRAY:
		var s2: Dictionary = _empty_store()
		for e2 in (data as Array):
			_add_score_internal(s2, e2 as Dictionary, false)
		return s2
	return _empty_store()

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

func _add_score_internal(dst_store: Dictionary, entry: Dictionary, do_save: bool) -> Dictionary:
	var e: Dictionary = _normalize_entry(entry)
	dst_store["history"].append(e)

	var keys: Array = _bucket_keys(e["date"])
	var day_key: String = keys[0]
	var month_key: String = keys[1]
	var year_key: String = keys[2]

	var daily: Array = (dst_store["daily"].get(day_key, []) as Array)
	dst_store["daily"][day_key] = daily
	var di: int = _asc_insert_cap(daily, e, "score", TOPN_DAILY)

	var monthly: Array = (dst_store["monthly"].get(month_key, []) as Array)
	dst_store["monthly"][month_key] = monthly
	var mi: int = _asc_insert_cap(monthly, e, "score", TOPN_MONTHLY)

	var yearly: Array = (dst_store["yearly"].get(year_key, []) as Array)
	dst_store["yearly"][year_key] = yearly
	var yi: int = _asc_insert_cap(yearly, e, "score", TOPN_YEARLY)

	var alltime: Array = (dst_store.get("alltime", []) as Array)
	dst_store["alltime"] = alltime
	var ai: int = _asc_insert_cap(alltime, e, "score", TOPN_ALLTIME)

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
	var take: int = mini(n, bucket.size())
	var tail: Array = []
	for i in range(bucket.size() - take, bucket.size()):
		tail.append(bucket[i])
	if highest_first:
		tail.reverse()
	return tail
