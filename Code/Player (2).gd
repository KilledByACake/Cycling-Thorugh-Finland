extends RigidBody2D

# --- Wheels & state ---
var wheels: Array = []
@export var max_speed: float = 80.0

# --- Tap-to-drive ---
@export var per_tap_add: float = 0.3
@export var tap_decay: float = 1.2
@export var torque_per_charge: float = 15000
@export var body_tilt_torque: float = -2500
@export var charge_max: float = 2.0
@export var energy_per_tap: int = 5

var pedal_charge: float = 0.0
var energy_points: int = 0

# --- Freeze / input lock ---
var input_locked: bool = false
var frozen: bool = false

@onready var engine_sfx: AudioStreamPlayer = get_node_or_null("EngineSFX") as AudioStreamPlayer

func _ready() -> void:
	add_to_group("player")
	add_to_group("input_receivers") # LevelManager will call lock_input(true)
	add_to_group("freezable")       # LevelManager can call freeze() on this group too

	wheels = get_tree().get_nodes_in_group("wheel")
	for w in wheels:
		if w is RigidBody2D:
			var rb := w as RigidBody2D
			rb.contact_monitor = true
			rb.max_contacts_reported = 4
	_update_energy_ui()

func _unhandled_input(event: InputEvent) -> void:
	if input_locked or frozen:
		return
	if event.is_action_pressed("ui_accept"):
		on_pedal_tap()

func on_pedal_tap() -> void:
	if input_locked or frozen:
		return
	pedal_charge = clamp(pedal_charge + per_tap_add, 0.0, charge_max)
	energy_points += energy_per_tap
	_update_energy_ui()

func _physics_process(delta: float) -> void:
<<<<<<< HEAD
	
	driving = 0
	
	if fuel > 0.0:
		if game_over_timer.time_left > 0.0:
			game_over_timer.stop()
		if Input.is_action_pressed("ui_right"):
			driving += 1
			#to do backflips
			apply_torque_impulse(-6000 * delta * 60)
			for wheel in wheels:
				if wheel.angular_velocity < max_speed:
					wheel.apply_torque_impulse(speed * delta * 60.0)
		if Input.is_action_pressed("ui_left"):
			driving += 1
			#to do backflips
			apply_torque_impulse(-6000 * delta * 60)
			#for wheel in wheels:
				#if wheel.angular_velocity > -max_speed:
					#wheel.apply_torque_impulse(-speed * delta * 60.0)
	else:
		if game_over_timer.time_left <= 0.0:
			game_over_timer.start()
			
	if driving == 1:
		$EngineSFX.pitch_scale = lerp($EngineSFX.pitch_scale, 2.0, 2.0*delta)
		use_fuel(delta)
	else:
		$EngineSFX.pitch_scale = lerp($EngineSFX.pitch_scale, 1.0, 2.0*delta)
=======
	if frozen:
		# Keep everything stopped while frozen
		pedal_charge = 0.0
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		sleeping = true
		for wheel in wheels:
			if wheel is RigidBody2D:
				var rb := wheel as RigidBody2D
				rb.angular_velocity = 0.0
				rb.linear_velocity = Vector2.ZERO
				rb.sleeping = true
		if engine_sfx:
			engine_sfx.pitch_scale = 1.0
		return
>>>>>>> 4ef045b51012a9f1f49c263a5e4195bc0d31ce55

	# Normal driving
	pedal_charge = max(0.0, pedal_charge - tap_decay * delta)

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

# --- Called by LevelManager ---

func lock_input(v: bool) -> void:
	input_locked = v

func freeze() -> void:
	frozen = true
	pedal_charge = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	sleeping = true
	for wheel in wheels:
		if wheel is RigidBody2D:
			var rb := wheel as RigidBody2D
			rb.angular_velocity = 0.0
			rb.linear_velocity = Vector2.ZERO
			rb.sleeping = true
	if engine_sfx:
		engine_sfx.pitch_scale = 1.0
