extends RigidBody2D

var maxSpeed: float = 100000 # max speed
var acceleration: float = 20000 # force perpedaling

var fuel: float = 100.0
var driving = 0

@onready var game_over_timer: Timer = $GameOverTimer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ground_ray: RayCast2D = $GroundRay



func _ready() -> void:
	#lock_rotation = true
	add_to_group("radler")
	_update_ui()

func _physics_process(delta: float) -> void:
	driving = 0
	
	var on_ground = ground_ray != null and ground_ray.is_colliding()
	#var on_ground = ground_ray.is_colliding()
	var tangent = Vector2.RIGHT
	
	if on_ground:
		var normal = ground_ray.get_collision_normal()
		tangent = Vector2(normal.y, -normal.x)
	
	if fuel > 0.0:
		if Input.is_action_just_pressed("ui_right"):
			driving = 1
			
			if linear_velocity.length() < maxSpeed:
				apply_central_force(tangent * acceleration)
			
	else:
		if game_over_timer.time_left <= 0.0:
			game_over_timer.start()
	
	
	
	#if fuel > 0.0:
		#if game_over_timer.time_left > 0.0:
			#game_over_timer.stop()
		#if Input.is_action_just_pressed("ui_right"):
			#driving += 1
			##simulates cycling, there is a push everytime the button is pressed
			#if linear_velocity.length() < maxSpeed:
				#apply_central_force(Vector2(acceleration, 0))		
	#else:
		#if game_over_timer.time_left <= 0.0:
			#game_over_timer.start()
			
	if on_ground:
		# leicht nach unten drücken (Grip)
		apply_central_force(Vector2(0, 200))
	else:
		# in der Luft → stärker runterziehen
		apply_central_force(Vector2(0, 800))
		
	#if driving == 0:
		#var brake_force = -linear_velocity.x * 0.3	
		#apply_central_force(Vector2(brake_force, 0))
	
	#move_and_slide()	
		
	if driving == 1:
		$EngineSFX.pitch_scale = lerp($EngineSFX.pitch_scale, 2.0, 2.0*delta)
		use_fuel(delta)
	else:
		$EngineSFX.pitch_scale = lerp($EngineSFX.pitch_scale, 1.0, 2.0*delta)
	_update_animation()
	
func _update_animation() -> void:
	var move_speed = abs(linear_velocity.x)
	
	if move_speed > 0:
		sprite.play("rollen") 
		# Animationsgeschwindigkeit an Fahrgeschwindigkeit koppeln
		sprite.speed_scale = clamp(move_speed / 50.0, 0.1, 50)
	else:
		sprite.stop()
	
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
