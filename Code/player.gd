extends CharacterBody2D

signal pedal_tapped

# --- Tuning Configuration (Original kept) ---
@export_group("Manual Configuration")
@export var power_per_tap: float = 1.0
@export var power_decay: float = 2.5
@export var speed_per_power: float = 2000.0

@export_group("Wahoo Sensor Configuration")
# Multiplicador para ajustar la relación entre Watts y avance en el juego
@export var power_to_speed_multiplier: float = 5.0 
@export var max_speed: float = 2000.0

@export_group("Scoring")
@export var energy_per_tap: int = 5

# Animation
@export var pedal_anim_name: String = "Cycle"  # Name of the pedaling animation present in every skin

# Runtime state
var tap_power: float = 0.0                   # Accumulated input power
var speed_x: float = 0.0                     # Current horizontal speed (pixels/sec)
var energy_points: int = 0                   # Score counter
var input_locked: bool = false               # If true, input is ignored
var frozen: bool = false                     # If true, motion/animation are stopped

# The currently selected AnimatedSprite2D skin (picked at startup)
var sprite: AnimatedSprite2D                 # Set by _choose_random_skin()

# All AnimatedSprite2D children treated as skins (e.g., Felix, Magdalena, Hilla, Mikko)
var _skins: Array[AnimatedSprite2D] = []

# Random generator used to pick a skin
var _rng := RandomNumberGenerator.new()

# Keeps the last chosen skin name to avoid immediate repeats within a session
static var _last_skin_name: String = ""


func _ready() -> void:
	add_to_group("player")
	add_to_group("radler")
	add_to_group("input_receivers")
	add_to_group("freezable")

	velocity = Vector2.ZERO

	_collect_skins()
	_choose_random_skin()

	_update_energy_ui()

	# --- COMENTADO: Ya no buscamos el nodo localmente porque usamos el Global ---
	# await get_tree().process_frame 
	# var ruta_gestor = "/root/Main/HBoxContainer/Dashboard/Wahoo/GestorWahoo"
	# var gestor = get_node_or_null(ruta_gestor)
	# if gestor:
	# 	gestor.power_updated.connect(_on_power_from_sensor)
	# 	gestor.speed_updated.connect(_on_speed_from_sensor)
	# 	print("Player: Wahoo connection established")

func _physics_process(delta: float) -> void:
	if not input_locked and not frozen and Input.is_action_just_pressed("ui_accept"):
		on_pedal_tap()

	tap_power = max(0.0, tap_power - power_decay * delta)
	speed_x = clamp(tap_power * speed_per_power, 0.0, max_speed)

	_update_animation()

# --- COMENTADO: Ya no usamos estas señales porque leemos directo del GlobalWahoo ---
# func _on_power_from_sensor(watts: int) -> void:
# 	potencia_sensor = watts
# func _on_speed_from_sensor(kmh: float) -> void:
# 	velocidad_sensor = kmh

func on_pedal_tap() -> void:
	if input_locked or frozen:
		return

	tap_power += power_per_tap
	energy_points += energy_per_tap
	_update_energy_ui()

	emit_signal("pedal_tapped")

func _update_animation() -> void:
	if sprite == null:
		return

	var s: float = speed_x
	if s > 1.0:
		# Resolve which animation to play on this skin (fallback to the first available)
		var name := pedal_anim_name
		if sprite.sprite_frames and not sprite.sprite_frames.has_animation(name):
			var names := sprite.sprite_frames.get_animation_names()
			if names.size() > 0:
				name = names[0]
		# Start playing if needed (AnimatedSprite2D in Godot 4 uses is_playing())
		if sprite.animation != name or not sprite.is_playing():
			sprite.play(name)
		sprite.speed_scale = clamp(s / 120.0, 0.2, 8.0)
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


# -------- Skin management --------

func _collect_skins() -> void:
	# Collect AnimatedSprite2D skins that are either direct children,
	# or nested inside a child scene (first AnimatedSprite2D found).
	_skins.clear()

	for c in get_children():
		if c is AnimatedSprite2D:
			_skins.append(c)
			continue

		var nested := c.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if nested:
			_skins.append(nested)
			continue

		var found := _find_first_animated_sprite2d(c)
		if found:
			_skins.append(found)


func _find_first_animated_sprite2d(root: Node) -> AnimatedSprite2D:
	for ch in root.get_children():
		if ch is AnimatedSprite2D:
			return ch
		var deeper := _find_first_animated_sprite2d(ch)
		if deeper:
			return deeper
	return null


func _choose_random_skin() -> void:
	if _skins.is_empty():
		sprite = null
		return

	var candidates: Array[AnimatedSprite2D] = _skins.duplicate()
	if candidates.size() > 1 and _last_skin_name != "":
		candidates = candidates.filter(func(s): return s.name != _last_skin_name)

	_rng.randomize()
	var idx := _rng.randi_range(0, candidates.size() - 1)
	var chosen := candidates[idx]

	for s in _skins:
		s.stop()
		s.visible = (s == chosen)

	sprite = chosen
	_last_skin_name = chosen.name


func reshuffle_skin() -> void:
	_choose_random_skin()
