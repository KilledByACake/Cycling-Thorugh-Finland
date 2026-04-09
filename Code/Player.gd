extends RigidBody2D

var wheels: Array = []
var max_speed: float = 50.0
var fuel: float = 100.0
var driving := 0

@onready var game_over_timer: Timer = get_node_or_null("GameOverTimer")
@onready var engine_sfx: Node = get_node_or_null("EngineSFX")

# --- Tap-to-drive tuning ---
@export var per_tap_add: float = 0.35        # charge gained per Space press
@export var tap_decay: float = 1.3           # charge lost per second
@export var torque_per_charge: float = 4500  # torque per charge unit
@export var body_tilt_torque: float = -3000  # small tilt (set 0 to disable)
@export var charge_max: float = 1.0          # cap charge

# --- Slope resistance tuning ---
@export var slope_resistance_factor: float = 30.0   # uphill gets heavier
@export var downhill_bonus_factor: float = 0.3      # downhill bonus (0 to disable)

@onready var slope_left: RayCast2D  = get_node_or_null("SlopeLeft")
@onready var slope_right: RayCast2D = get_node_or_null("SlopeRight")

var pedal_charge := 0.0

func _ready() -> void:
	add_to_group("player")
	# collect all wheel instances from the "wheel" group (your Wheel.tscn already has this)
	wheels = get_tree().get_nodes_in_group("wheel")
	_update_ui()

# Space press (ui_accept) adds pedal charge
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		on_pedal_tap()

func on_pedal_tap() -> void:
	pedal_charge = clamp(pedal_charge + per_tap_add, 0.0, charge_max)

func _physics_process(delta: float) -> void:
	driving = 0
	# decay charge when you stop tapping
	pedal_charge = max(0.0, pedal_charge - tap_decay * delta)

	if fuel > 0.0:
		if game_over_timer and game_over_timer.time_left > 0.0:
			game_over_timer.stop()

		var grade := get_grade()  # positive = uphill to the right
		var resistance := 1.0
		if grade > 0.0:
			resistance += grade * slope_resistance_factor
		elif grade < 0.0:
			resistance = max(0.5, resistance + grade * downhill_bonus_factor)

		if pedal_charge > 0.0 and wheels.size() > 0:
			var impulse := (torque_per_charge * pedal_charge * delta * 60.0) / resistance
			var any_wheel_drove := false

			for wheel in wheels:
				if wheel is RigidBody2D and wheel.angular_velocity < max_speed:
					wheel.apply_torque_impulse(impulse)
					any_wheel_drove = true

			if any_wheel_drove and body_tilt_torque != 0.0:
				apply_torque_impulse(body_tilt_torque * delta * 60.0)

			if any_wheel_drove:
				driving = 1
	else:
		if game_over_timer and game_over_timer.time_left <= 0.0:
			game_over_timer.start()

	# sound + fuel
	if driving == 1:
		if engine_sfx and "pitch_scale" in engine_sfx:
			engine_sfx.pitch_scale = lerp(engine_sfx.pitch_scale, 2.0, 2.0 * delta)
		use_fuel(delta)  # remove this call if you don’t want fuel mechanics
	else:
		if engine_sfx and "pitch_scale" in engine_sfx:
			engine_sfx.pitch_scale = lerp(engine_sfx.pitch_scale, 1.0, 2.0 * delta)

func get_grade() -> float:
	# returns dy/dx; positive means ground rises to the right (uphill)
	if slope_left and slope_right and slope_left.is_colliding() and slope_right.is_colliding():
		var pL: Vector2 = slope_left.get_collision_point()
		var pR: Vector2 = slope_right.get_collision_point()
		var dx := pR.x - pL.x
		if abs(dx) > 0.001:
			var dy := pL.y - pR.y  # Godot Y goes downward; this makes uphill positive
			return dy / dx
	return 0.0

func refuel() -> void:
	fuel = 100.0
	_update_ui()

func use_fuel(delta: float) -> void:
	fuel = clamp(fuel - 10.0 * delta, 0.0, 100.0)
	_update_ui()

func _update_ui() -> void:
	var p := get_parent()
	if p and p.has_method("update_fuel_UI"):
		p.update_fuel_UI(fuel)

func _on_game_over_timer_timeout() -> void:
	get_tree().reload_current_scene()
