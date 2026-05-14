extends Node2D

# Streams and reuses large background chunks as the camera moves horizontally.

@export var folder_path: String = "res://Images/Design/Layer1/smaller/"
@export var chunk_width: float = 5296.0
@export var chunk_height: float = 2979.0
@export var camera: Camera2D
@export var chunks_ahead: int = 3
@export var start_x: float = -500.0
@export var start_y: float = -2160.0 / 2.0 + 220.0  # avoid integer division

var chunks: Array = []          # File names of available chunks (sorted)
var loaded: Dictionary = {}     # index -> Sprite2D of loaded chunks

# Called when ready; scans the folder and prepares the chunk list.
func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	
	var dir: DirAccess = DirAccess.open(folder_path)
	if dir == null:
		push_error("Folder not found: " + folder_path)
		return
	
	dir.list_dir_begin()
	var file: String = dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".png") or file.ends_with(".PNG"):
			chunks.append(file)
		file = dir.get_next()
	dir.list_dir_end()
	chunks.sort()
	
	print("first chunk: ", chunks[0])
	
	print(folder_path, " -> ", chunks.size(), " chunks found")

# Runs every frame; loads needed chunks and unloads those far behind.
func _process(_delta: float) -> void:
	if chunks.is_empty() or camera == null:
		print("Bailing - chunks: ", chunks.size(), "camera: ", camera)
		return
	
	var cam_x: float = camera.global_position.x
	
	# Determine which chunk index is currently needed based on camera X.
	var needed: int = max(0, int((cam_x - start_x) / chunk_width))
	
	print ("needed:", needed, "laoded: ", loaded.keys())
	
	# Load one behind and a few ahead of the camera.
	for i in range(max(0, needed - 1), min(chunks.size(), needed + chunks_ahead)):
		if not loaded.has(i):
			_load(i)
	
	# Unload chunks far behind the camera.
	for key in loaded.keys().duplicate():
		if key < needed - 1:
			print("unlaoding chunck ", key, " because needed is ", needed)
			loaded[key].queue_free()
			loaded.erase(key)

# Loads a single chunk sprite at the correct position.
func _load(index: int) -> void:
	var tex: Texture2D = load(folder_path + chunks[index]) as Texture2D
	if tex == null:
		return
	
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex
	# Position based on start_x, independent of the camera.
	sprite.position.x = start_x + index * chunk_width + chunk_width / 2.0
	sprite.position.y = start_y + chunk_height / 2.0
	add_child(sprite)
	loaded[index] = sprite
