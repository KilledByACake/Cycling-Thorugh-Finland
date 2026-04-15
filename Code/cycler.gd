extends CharacterBody2D

var speed: float = 5000
#var max_speed: float = 50.0
var fuel: float = 100.0
var driving = 0
const GRAVITY = 980.0

@onready var game_over_timer: Timer = $GameOverTimer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	#lock_rotation = true
	add_to_group("cycler")
	_update_ui()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		var normal = get_floor_normal()
		var target_angle = normal.angle() + PI / 2
		sprite.rotation = lerp_angle(sprite.rotation, target_angle, 10.0 * delta)
	
	driving = 0
	
	if fuel > 0.0:
		if game_over_timer.time_left > 0.0:
			game_over_timer.stop()
		if Input.is_action_pressed("ui_right"):
			driving += 1
			velocity.x = speed
		
	else:
		if game_over_timer.time_left <= 0.0:
			game_over_timer.start()
		
	if driving == 0:
		velocity.x = move_toward(velocity.x, 0, speed * delta * 3)
	
	move_and_slide()	
		
	if driving == 1:
		$EngineSFX.pitch_scale = lerp($EngineSFX.pitch_scale, 2.0, 2.0*delta)
		use_fuel(delta)
	else:
		$EngineSFX.pitch_scale = lerp($EngineSFX.pitch_scale, 1.0, 2.0*delta)
	_update_animation()
	
func _update_animation() -> void:
	# nur horizontale Geschwindigkeit – Drehung soll Animation nicht beeinflussen
	var move_speed = abs(velocity.x)
	
	if move_speed > 5.0:
		sprite.play("rollen") 
		# Animationsgeschwindigkeit an Fahrgeschwindigkeit koppeln
		sprite.speed_scale = clamp(move_speed / 50.0, 0.1, 5.0)
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
