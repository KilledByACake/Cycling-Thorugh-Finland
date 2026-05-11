extends CharacterBody2D

signal pedal_tapped

# --- Tuning Configuration (Original kept) ---
@export_group("Manual Configuration")
@export var power_per_tap: float = 1.0
@export var power_decay: float = 2.5
@export var speed_per_power: float = 2000.0

@export_group("Wahoo Sensor Configuration")
# Multiplier to convert sensor power to in-game horizontal speed
@export var power_to_speed_multiplier: float = 5.0 
@export var max_speed: float = 2000.0

@export_group("Scoring")
@export var energy_per_tap: int = 5

# --- State Variables ---
var velocidad_sensor: float = 0.0                    # Sensor speed (km/h), kept for reference
var potencia_sensor: int = 0                         # Sensor power (watts), kept for reference
var tap_power: float = 0.0
var speed_x: float = 0.0                              # Driven by GlobalWahoo power
var energy_points: int = 0
var input_locked: bool = false
var frozen: bool = false

# Current AnimatedSprite2D used by the player visuals
@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

# Random skin selection: list of AnimatedSprite2D children and RNG
var _skins: Array[AnimatedSprite2D] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	# Keep original groups
	add_to_group("player")
	add_to_group("radler")
	add_to_group("input_receivers")
	add_to_group("freezable")
	velocity = Vector2.ZERO
	_update_energy_ui()

	# Randomly pick one AnimatedSprite2D child (e.g., Mikko/Hilla/Felix/Magdalena) and hide the others
	_collect_skins()
	_choose_random_skin()

	# --- COMMENTED OUT: local node hookup replaced by Global access (kept as reference) ---
	# await get_tree().process_frame 
	# var ruta_gestor = "/root/Main/HBoxContainer/Dashboard/Wahoo/GestorWahoo"
	# var gestor = get_node_or_null(ruta_gestor)
	# if gestor:
	# 	gestor.power_updated.connect(_on_power_from_sensor)
	# 	gestor.speed_updated.connect(_on_speed_from_sensor)
	# 	print("Player: Wahoo connection established")

func _physics_process(delta: float) -> void:
	if frozen: return

	# Use GlobalWahoo.power to drive horizontal speed (smoothed with lerp)
	var target_speed = GlobalWahoo.power * power_to_speed_multiplier
	speed_x = lerp(speed_x, target_speed, 2.0 * delta) 
	speed_x = clamp(speed_x, 0.0, max_speed)
	
	# Apply physics velocity (uncomment move_and_slide if using CharacterBody2D motion)
	velocity.x = speed_x
	#move_and_slide()

	# Award energy steadily while power is above a threshold
	if GlobalWahoo.power > 50:
		energy_points += 1
		_update_energy_ui()
	
	_update_animation()

# --- COMMENTED OUT: direct sensor signal handlers (kept as reference) ---
# func _on_power_from_sensor(watts: int) -> void:
# 	potencia_sensor = watts
# func _on_speed_from_sensor(kmh: float) -> void:
# 	velocidad_sensor = kmh

func on_pedal_tap() -> void:
	if input_locked or frozen: return
	tap_power += power_per_tap
	energy_points += energy_per_tap
	_update_energy_ui()
	emit_signal("pedal_tapped")

func _update_animation() -> void:
	if sprite == null: return
	# Drive animation from actual movement
	if abs(velocity.x) > 1.0:
		sprite.play("rollen")
		sprite.speed_scale = clamp(velocity.x / 300.0, 0.2, 8.0)
	else:
		sprite.stop()

func _update_energy_ui() -> void:
	var p: Node = get_parent()
	if p and p.has_method("update_energy_UI"):
		p.call("update_energy_UI", energy_points)

func lock_input(v: bool) -> void:
	input_locked = v

func freeze() -> void:
	frozen = true
	tap_power = 0.0
	speed_x = 0.0
	velocity = Vector2.ZERO

# -------- Random skin helpers (only addition) --------

func _collect_skins() -> void:
	# Gather direct AnimatedSprite2D children (e.g., Mikko, Hilla, Felix, Magdalena)
	_skins.clear()
	for c in get_children():
		if c is AnimatedSprite2D:
			_skins.append(c)

func _choose_random_skin() -> void:
	# Pick one at random and hide the others; update 'sprite' to the chosen one
	if _skins.is_empty():
		return
	_rng.randomize()
	var idx = _rng.randi_range(0, _skins.size() - 1)
	var chosen: AnimatedSprite2D = _skins[idx]
	for s in _skins:
		s.stop()
		s.visible = (s == chosen)
	sprite = chosen

func reshuffle_skin() -> void:
	# Public method to re-roll the visible skin if needed (e.g., on respawn)
	_choose_random_skin()
