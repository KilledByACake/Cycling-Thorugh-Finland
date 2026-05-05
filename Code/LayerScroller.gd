extends Node2D

@export var folder_path: String = "res://Images/Design/Layer1/"
@export var chunk_width: float = 5296.0
@export var chunk_height: float = 2979.0
@export var camera: Camera2D
@export var chunks_ahead: int = 3
@export var start_x: float = -500.0
@export var start_y: float = -2160/2 + 220

var chunks: Array = []
var loaded: Dictionary = {}

func _ready():
	await get_tree().process_frame
	await get_tree().process_frame
	
	var dir = DirAccess.open(folder_path)
	if dir == null:
		push_error("Ordner nicht gefunden: " + folder_path)
		return
	
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".png"):
			chunks.append(file)
		file = dir.get_next()
	chunks.sort()
	
	print(folder_path, " -> ", chunks.size(), " chunks gefunden")

func _process(_delta):
	if chunks.is_empty() or camera == null:
		return
	
	var cam_x = camera.global_position.x
	
	# Welcher Chunk ist gerade sichtbar basierend auf Kamera X
	var needed = max(0, int((cam_x - start_x) / chunk_width))
	
	# Einen hinter + chunks_ahead vor der Kamera laden
	for i in range(max(0, needed - 1), min(chunks.size(), needed + chunks_ahead)):
		if not loaded.has(i):
			_load(i)
	
	# Weit zurückliegende Chunks entladen
	for key in loaded.keys().duplicate():
		if key < needed - 1:
			loaded[key].queue_free()
			loaded.erase(key)

func _load(index: int):
	var tex = load(folder_path + chunks[index])
	if tex == null:
		return
	
	var sprite = Sprite2D.new()
	sprite.texture = tex
	# Position basiert auf start_x — komplett unabhängig von der Kamera
	sprite.position.x = start_x + index * chunk_width + chunk_width / 2.0
	sprite.position.y = start_y + chunk_height / 2.0
	add_child(sprite)
	loaded[index] = sprite
