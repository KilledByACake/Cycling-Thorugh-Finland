extends RigidBody2D

# --- Wheels & state ---
var wheels: Array = []
@export var max_speed: float = 80.0

# --- Tap-to-drive ---
@export var per_tap_add: float = 0.3          # charge gained per Space press
@export var tap_decay: float = 1.2            # charge lost per second
@export var torque_per_charge: float = 15000  # torque generated per charge unit
@export var body_tilt_torque: float = -2500   # small body torque for feel (0 to disable)
@export var charge_max: float = 2.0           # cap for pedal_charge
@export var energy_per_tap: int = 5           # points earned per tap

var pedal_charge: float = 0.0
var energy_points: int = 0

@onready var engine_sfx: AudioStreamPlayer = get_node_or_null("EngineSFX") as AudioStreamPlayer

func _ready() -> void:
	add_to_group("player")
	wheels = get_tree().get_nodes_in_group("wheel")
	# Ensure wheels can report contacts (Godot 4 property names)
	for w in wheels:
		if w is RigidBody2D:
			var rb := w as RigidBody2D
			rb.contact_monitor = true
			rb.max_contacts_reported = 4
	_update_energy_ui()

func _unhandled_input(event: InputEvent) -> void:
	# Space/Enter -> ui_accept
	if event.is_action_pressed("ui_accept"):
		on_pedal_tap()

func on_pedal_tap() -> void:
	pedal_charge = clamp(pedal_charge + per_tap_add, 0.0, charge_max)
	energy_points += energy_per_tap
	_update_energy_ui()

func _physics_process(delta: float) -> void:
	# decay when not tapping
	pedal_charge = max(0.0, pedal_charge - tap_decay * delta)

	# Only drive if at least one wheel is grounded
	var grounded := _any_wheel_grounded()
	if pedal_charge > 0.0 and wheels.size() > 0 and grounded:
		var impulse: float = torque_per_charge * pedal_charge * delta * 60.0
		for wheel in wheels:
			if wheel is RigidBody2D:
				var rb := wheel as RigidBody2D
				if rb.angular_velocity < max_speed:
					rb.apply_torque_impulse(impulse)
		if body_tilt_torque != 0.0:
			apply_torque_impulse(body_tilt_torque * delta * 60.0)

	# Optional sound feedback
	if engine_sfx:
		var target := 2.0 if (pedal_charge > 0.0 and grounded) else 1.0
		engine_sfx.pitch_scale = lerp(engine_sfx.pitch_scale, target, 2.0 * delta)

func _any_wheel_grounded() -> bool:
	for wheel in wheels:
		if wheel is RigidBody2D:
			if (wheel as RigidBody2D).get_contact_count() > 0:
				return true
	return false

func _update_energy_ui() -> void:
	var p := get_parent()
	if p and p.has_method("update_energy_UI"):
		p.update_energy_UI(energy_points)
