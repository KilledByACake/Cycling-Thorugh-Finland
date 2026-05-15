extends CanvasLayer
@onready var lbl_speed: Label  = %SpeedLabel
@onready var lbl_energy: Label = %EnergyLabel
@onready var lbl_timer: Label  = %TimerLabel
@onready var lbl_name:  Label  = %PlayerNameLabel

func set_speed(kmh: float) -> void:
	lbl_speed.text = "%.1f" % kmh

func set_energy_total_kj(kj: float) -> void:
	lbl_energy.text = "%.1f" % kj

func set_timer_text(txt: String) -> void:
	lbl_timer.text = txt

func set_player_name(n: String) -> void:
	lbl_name.text = n
