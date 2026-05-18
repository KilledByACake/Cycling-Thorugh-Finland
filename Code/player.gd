extends CharacterBody2D

# Active sprite used for this player.
var sprite: AnimatedSprite2D
# All AnimatedSprite2D children (skins) found under this node.
var _skins: Array[AnimatedSprite2D] = []
# RNG used to pick a random skin.
var _rng := RandomNumberGenerator.new()

@export var celebrate_anim_name: String = "Celebrate"
var celebrating: bool = false
var frozen: bool = false
var energy_points: int = 0

# Called when the node enters the scene: registers groups, resets position, picks a skin, and updates UI.
func _ready() -> void:
	add_to_group("player")
	add_to_group("radler")
	add_to_group("freezable")
	position = Vector2.ZERO
	_collect_skins()
	_choose_random_skin()
	_update_energy_ui()

# Physics tick: updates animation if not frozen.
func _physics_process(_delta: float) -> void:
	if frozen:
		return
	_update_animation()

# Drives the cycling animation based on movement speed along a PathFollow2D (if present).
func _update_animation() -> void:
	if sprite == null or celebrating:
		return

	var current_speed := 0.0
	if get_parent() is PathFollow2D:
		current_speed = get_parent().speed_x

	if current_speed > 1.0:
		if not sprite.is_playing():
			sprite.play("Cycle")
		sprite.speed_scale = clamp(current_speed / 300.0, 0.2, 8.0)
	else:
		sprite.stop()

# Gathers all AnimatedSprite2D children as available skins.
func _collect_skins() -> void:
	_skins.clear()
	for c in get_children():
		if c is AnimatedSprite2D:
			_skins.append(c)

# Selects one skin at random, makes it visible, and hides the others.
func _choose_random_skin() -> void:
	if _skins.is_empty():
		var fallback := get_node_or_null("AnimatedSprite2D")
		if fallback:
			sprite = fallback
			sprite.visible = true
		else:
			print("Error: No AnimatedSprite2D children found in Player")
		return

	_rng.randomize()
	var idx := _rng.randi_range(0, _skins.size() - 1)
	var chosen := _skins[idx]

	for s in _skins:
		s.stop()
		s.visible = (s == chosen)

	sprite = chosen
	print("Chosen skin: ", sprite.name)

# Public method to re-pick a random skin at runtime.
func reshuffle_skin() -> void:
	_choose_random_skin()

# Enters celebration state and plays the configured celebration animation.
func start_celebrate() -> void:
	celebrating = true
	if sprite:
		sprite.play(celebrate_anim_name)

# Pushes the current energy value to a parent UI controller if found.
func _update_energy_ui() -> void:
	var p := get_parent()
	while p:
		if p.has_method("update_energy_UI"):
			p.call("update_energy_UI", energy_points)
			break
		p = p.get_parent()

# Freezes the player and stops animation updates.
func freeze() -> void:
	frozen = true
	if sprite:
		sprite.stop()
