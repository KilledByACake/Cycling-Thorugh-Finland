# Energy.gd (Autoload)
extends Node
signal changed(total_kj: float, score_int: int)

var total_kj: float = 0.0      # precise float total (pedaling + pickups)
var score_int: int = 0         # whole kJ score for UI/Result/Highscore

func reset() -> void:
	total_kj = 0.0
	score_int = 0
	changed.emit(total_kj, score_int)

# Integrate pedaling energy: W * s / 1000 -> kJ
func integrate_power(delta: float, power_w: float) -> void:
	if power_w <= 0.0:
		return
	total_kj += power_w * delta / 1000.0
	_update_score_if_needed()

# Add a pickup (amount in kJ)
func add_pickup(amount_kj: int) -> void:
	if amount_kj <= 0:
		return
	total_kj += float(amount_kj)
	_update_score_if_needed()

func _update_score_if_needed() -> void:
	var new_int := int(floor(total_kj))
	if new_int != score_int:
		score_int = new_int
		changed.emit(total_kj, score_int)
