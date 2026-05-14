extends CharacterBody2D

# --- Visuals ---
var sprite: AnimatedSprite2D
var _skins: Array[AnimatedSprite2D] = []
var _rng := RandomNumberGenerator.new()

@export var celebrate_anim_name: String = "Celebrate"
var celebrating: bool = false
var frozen: bool = false
var energy_points: int = 0

func _ready() -> void:
	# Register in groups
	add_to_group("player")
	add_to_group("radler")
	add_to_group("freezable")
	
	# Reset initial position
	position = Vector2.ZERO 
	
	# Skin initialization logic
	_collect_skins()
	_choose_random_skin()
	_update_energy_ui()

func _physics_process(_delta: float) -> void:
	if frozen:
		return
	_update_animation()

func _update_animation() -> void:
	# Safety check: if there is no sprite or we are celebrating, exit
	if sprite == null or celebrating:
		return
	
	var current_speed = 0.0
	# Check if we are under a PathFollow2D (common in racing/bike games)
	if get_parent() is PathFollow2D:
		current_speed = get_parent().speed_x
	
	# Animation control based on speed
	if current_speed > 1.0:
		if not sprite.is_playing():
			sprite.play("Cycle")
		# Adjust the animation speed based on actual movement speed
		sprite.speed_scale = clamp(current_speed / 300.0, 0.2, 8.0)
	else:
		sprite.stop()

# --- Skin Management ---

func _collect_skins() -> void:
	_skins.clear()
	# Look among direct children for any AnimatedSprite2D
	for c in get_children():
		if c is AnimatedSprite2D:
			_skins.append(c)

func _choose_random_skin() -> void:
	if _skins.is_empty():
		# If there are no sprites, try to find a default one as mentioned before
		var fallback = get_node_or_null("AnimatedSprite2D")
		if fallback:
			sprite = fallback
			sprite.visible = true
		else:
			print("Error: No AnimatedSprite2D children found in Player")
		return
		
	_rng.randomize()
	var idx = _rng.randi_range(0, _skins.size() - 1)
	var chosen = _skins[idx]
	
	# Hide all sprites except the randomly chosen one
	for s in _skins:
		s.stop()
		s.visible = (s == chosen)
	
	# Assign the active sprite to our main variable
	sprite = chosen
	print("Chosen skin: ", sprite.name)

func reshuffle_skin() -> void:
	_choose_random_skin()

# --- States and UI ---

func start_celebrate() -> void:
	celebrating = true
	if sprite:
		sprite.play(celebrate_anim_name)

func _update_energy_ui() -> void:
	# Search up the node tree to find who manages the UI
	var p = get_parent()
	while p:
		if p.has_method("update_energy_UI"):
			p.call("update_energy_UI", energy_points)
			break
		p = p.get_parent()

func freeze() -> void:
	frozen = true
	if sprite:
		sprite.stop()
