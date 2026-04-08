extends RigidBody2D

var wheels: Array = []
var speed: float = 60000.0
var max_speed: float = 50.0
var fuel: float = 100.0
var driving = 0

@onready var game_over_timer: Timer = $GameOverTimer

func _ready() -> void:
	add_to_group("player")
	wheels = get_tree().get_nodes_in_group("wheel")
	_update_ui()

func _physics_process(delta: float) -> void:
	
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
			for wheel in wheels:
				if wheel.angular_velocity > -max_speed:
					wheel.apply_torque_impulse(-speed * delta * 60.0)
	else:
		if game_over_timer.time_left <= 0.0:
			game_over_timer.start()
			
	if driving == 1:
		$EngineSFX.pitch_scale = lerp($EngineSFX.pitch_scale, 2.0, 2.0*delta)
		use_fuel(delta)
	else:
		$EngineSFX.pitch_scale = lerp($EngineSFX.pitch_scale, 1.0, 2.0*delta)

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
