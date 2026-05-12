extends Node
signal solar2_changed(value: float)

@export var url: String = "https://iot.novia.fi/data/meteoria_energy.html"
@export var poll_interval_sec: float = 30.0
@export var request_timeout_sec: float = 10.0
@export var debug_log: bool = false

var _http: HTTPRequest
var _timer: Timer
var _inflight: bool = false

# Sets up HTTP and schedules the first request.
func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = request_timeout_sec
	_http.use_threads = true
	add_child(_http)
	_http.request_completed.connect(_on_http_completed)

	_timer = Timer.new()
	_timer.wait_time = poll_interval_sec
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_request_now)

	_request_now()

# Starts a new request only if none is currently running.
func _request_now() -> void:
	if _inflight:
		return
	var err := _http.request(url)
	if err == OK:
		_inflight = true
		if debug_log: print("SolarData: requesting ", url)
	else:
		if debug_log: push_error("HTTP request start failed: %s" % err)
		_timer.start()

# Handles completion, parses value, emits signal, and schedules next poll.
func _on_http_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_inflight = false
	if debug_log: print("SolarData: completed result=", result, " code=", response_code)
	if result != OK or response_code != 200:
		_timer.start()
		return

	var text := body.get_string_from_utf8()
	var value := parse_solar2_value(text)
	if debug_log: print("SolarData: parsed value=", value)
	if is_finite(value):
		emit_signal("solar2_changed", value)

	_timer.start()

# Extracts the live value for "Solar 2 Charge" in watts.
func parse_solar2_value(text: String) -> float:
	var v := _parse_now_at_sentence(text)
	if is_finite(v):
		return v
	v = _parse_from_dt_array(text)
	if is_finite(v):
		return v
	return NAN

# Parses "... Solar 2 Charge ... now at (...) is <number> <W|kW>" and returns watts.
func _parse_now_at_sentence(text: String) -> float:
	var lower := text.to_lower()
	var anchor := lower.find("solar 2 charge")
	if anchor == -1:
		return NAN
	var idx_now := lower.find("now at", anchor)
	if idx_now == -1:
		return NAN

	var idx_is := lower.find(" is ", idx_now)
	var is_len := 4
	if idx_is == -1:
		idx_is = lower.find("is", idx_now)
		is_len = 2
	if idx_is == -1:
		return NAN

	var i := idx_is + is_len
	while i < text.length() and _is_ws(text.substr(i, 1)):
		i += 1

	var start := i
	while i < text.length():
		var ch := text.substr(i, 1)
		if _is_digit(ch) or ch == "." or ch == ",":
			i += 1
		else:
			break
	if i == start:
		return NAN

	var num_str := text.substr(start, i - start).replace(",", ".")
	var val := float(num_str)

	while i < text.length() and _is_ws(text.substr(i, 1)):
		i += 1

	var unit_start := i
	while i < text.length() and _is_alpha(text.substr(i, 1)):
		i += 1
	var unit := text.substr(unit_start, i - unit_start).to_lower()

	if unit == "kw":
		val *= 1000.0
	return val

# Finds an array tied to "Solar 2 Charge" and returns the last number; supports nested pairs [time,value].
func _parse_from_dt_array(text: String) -> float:
	var key_pos := text.find("\"Solar 2 Charge\"")
	if key_pos == -1:
		key_pos = text.find("'Solar 2 Charge'")
	if key_pos == -1:
		return NAN

	var arr_start := text.find("[", key_pos)
	if arr_start == -1:
		return NAN

	var depth := 0
	var pos := arr_start
	while pos < text.length():
		var ch := text.substr(pos, 1)
		if ch == "[":
			depth += 1
		elif ch == "]":
			depth -= 1
			if depth == 0:
				var arr_src := text.substr(arr_start, pos - arr_start + 1)
				return _extract_last_number(arr_src)
		pos += 1

	return NAN

# Extracts the last numeric literal from a JS-like array source; returns NAN if none found.
func _extract_last_number(src: String) -> float:
	var i := src.length() - 1
	while i >= 0 and not _is_digit(src.substr(i, 1)):
		i -= 1
	if i < 0:
		return NAN
	var end_i := i + 1
	i -= 1
	while i >= 0:
		var ch := src.substr(i, 1)
		if _is_digit(ch) or ch == "." or ch == ",":
			i -= 1
		else:
			break
	var start_i := i + 1
	var s := src.substr(start_i, end_i - start_i).replace(",", ".")
	return float(s)

# Returns true for ASCII whitespace: space, tab, newline, carriage return.
func _is_ws(ch: String) -> bool:
	return ch == " " or ch == "\t" or ch == "\n" or ch == "\r"

# Returns true if ch is an ASCII digit 0–9.
func _is_digit(ch: String) -> bool:
	return ch >= "0" and ch <= "9"

# Returns true if ch is an ASCII letter a–z or A–Z.
func _is_alpha(ch: String) -> bool:
	var c := ch.to_lower()
	return c >= "a" and c <= "z"

# Cancels any in-flight request on cleanup.
func _exit_tree() -> void:
	if _http:
		_http.cancel_request()
