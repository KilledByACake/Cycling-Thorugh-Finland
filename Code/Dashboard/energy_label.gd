extends Label

# Number of decimals to display (0 = integer)
@export var digits: int = 0
# Exponential smoothing time constant in seconds (0 = no smoothing)
@export var smoothing_tau_sec: float = 0.1

# Internal smoothed value
var _display_w: float = 0.0

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	# Read current power (W). Cast to float to avoid Variant propagation.
	var w: float = (GlobalWahoo.power as float)
	if w < 0.0:
		w = 0.0

	if smoothing_tau_sec > 0.0:
		var alpha: float = 1.0 - exp(-delta / smoothing_tau_sec)
		_display_w = lerp(_display_w, w, alpha)
	else:
		_display_w = w

	# Update the label text
	if digits <= 0:
		text = str(int(round(_display_w)))
	else:
		text = ("%." + str(digits) + "f") % _display_w
