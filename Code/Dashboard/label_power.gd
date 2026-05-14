extends Label
class_name LabelPower

@export var gauge_path: NodePath
@export var autoload_name: StringName = &"GlobalWahoo"

var _gauge: PedalGauge
var _autoload: Node
var _last_power: float = -INF

# Resolves the gauge and the autoload, then starts polling.
func _ready() -> void:
	_gauge = get_node_or_null(gauge_path) as PedalGauge
	_autoload = get_node_or_null("/root/%s" % String(autoload_name))
	text = "0 W"
	set_process(true)
	_apply_power(_read_power())

# Polls the autoload and updates when power changes.
func _process(_delta: float) -> void:
	var p: float = _read_power()
	if p != _last_power:
		_apply_power(p)

# Reads power safely from the autoload.
func _read_power() -> float:
	if _autoload:
		var v: Variant = _autoload.get("power")
		if typeof(v) == TYPE_INT:
			return float(v)
		elif typeof(v) == TYPE_FLOAT:
			return v
	return 0.0

# Updates the label and forwards the value to the gauge.
func _apply_power(power: float) -> void:
	_last_power = power
	text = str(int(power)) + " W"
	if _gauge:
		_gauge.value = power
