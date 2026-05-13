extends CharacterBody2D

signal pedal_tapped

# --- Visuales ---
# Ya no usamos @onready aquí porque la skin se elige dinámicamente en _ready
var sprite: AnimatedSprite2D 
var _skins: Array[AnimatedSprite2D] = []
var _rng := RandomNumberGenerator.new()

@export var celebrate_anim_name: String = "Celebrate"
var celebrating: bool = false
var frozen: bool = false
var energy_points: int = 0

func _ready() -> void:
	# Registro en grupos
	add_to_group("player")
	add_to_group("radler")
	add_to_group("freezable")
	
	# Reset de posición inicial
	position = Vector2.ZERO 
	
	# Lógica de inicialización de skins
	_collect_skins()
	_choose_random_skin()
	_update_energy_ui()

func _physics_process(_delta: float) -> void:
	if frozen: 
		return
	_update_animation()

func _update_animation() -> void:
	# Verificación de seguridad: si no hay sprite o estamos celebrando, salimos
	if sprite == null or celebrating: 
		return
	
	var current_speed = 0.0
	# Verificamos si estamos en un PathFollow2D (común en juegos de carreras/bicis)
	if get_parent() is PathFollow2D:
		current_speed = get_parent().speed_x
	
	# Control de animaciones según velocidad
	if current_speed > 1.0:
		if not sprite.is_playing(): 
			sprite.play("rollen")
		# Ajusta la velocidad de la animación según la velocidad real del movimiento
		sprite.speed_scale = clamp(current_speed / 300.0, 0.2, 8.0)
	else:
		sprite.stop()

# --- Gestión de Skins ---

func _collect_skins() -> void:
	_skins.clear()
	# Buscamos entre los hijos directos cualquier AnimatedSprite2D
	for c in get_children():
		if c is AnimatedSprite2D:
			_skins.append(c)

func _choose_random_skin() -> void:
	if _skins.is_empty(): 
		# Si no hay sprites, intentamos buscar uno por defecto como mencionaste antes
		var fallback = get_node_or_null("AnimatedSprite2D")
		if fallback:
			sprite = fallback
			sprite.visible = true
		else:
			print("Error: No se encontraron AnimatedSprite2D hijos en Player")
		return
		
	_rng.randomize()
	var idx = _rng.randi_range(0, _skins.size() - 1)
	var chosen = _skins[idx]
	
	# Ocultamos todos los sprites excepto el elegido por el azar
	for s in _skins:
		s.stop()
		s.visible = (s == chosen)
	
	# Asignamos el sprite activo a nuestra variable principal
	sprite = chosen 
	print("Skin elegida: ", sprite.name)

func reshuffle_skin() -> void:
	_choose_random_skin()

# --- Estados y UI ---

func start_celebrate() -> void:
	celebrating = true
	if sprite:
		sprite.play(celebrate_anim_name)

func _update_energy_ui() -> void:
	# Busca hacia arriba en el árbol de nodos hasta encontrar quién maneja la UI
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
