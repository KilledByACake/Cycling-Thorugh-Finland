extends Node

# Asynchronously loads the main game scene, shows a short countdown, then starts the game.

@export var game_scene_path: String = "res://Levels/Game.tscn"     # Path to the game scene
@export var words: PackedStringArray = ["Ready?", "Set..", "Go!"]  # Countdown words
@export var step_time: float = 1.0                                 # Delay between words

@onready var overlay: CanvasLayer = $Overlay
@onready var word_label: Label = $Overlay/CountdownTimer

var game_inst: Node = null
var ui_layer: CanvasLayer = null
var player: Node = null

# Called on enter tree; loads the game scene in a background thread and runs a countdown.
func _ready() -> void:
	# Show initial loading text
	word_label.text = "Loading..."
	await get_tree().process_frame

	# Start threaded load (keeps UI responsive)
	var err: int = ResourceLoader.load_threaded_request(game_scene_path)
	if err != OK:
		push_error("Failed to start threaded load: " + game_scene_path)
		return

	# Wait until the load finishes
	while ResourceLoader.load_threaded_get_status(game_scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame

	# Retrieve the loaded scene
	var packed: PackedScene = ResourceLoader.load_threaded_get(game_scene_path) as PackedScene
	if packed == null:
		push_error("Threaded load returned null: " + game_scene_path)
		return

	# Instance the game under this loader (overlay stays on top as it's a CanvasLayer)
	game_inst = packed.instantiate()
	add_child(game_inst)

	# Give the game one frame to enter tree, then hide UI and freeze player
	await get_tree().process_frame

	ui_layer = game_inst.get_node_or_null("UI") as CanvasLayer
	if ui_layer:
		ui_layer.visible = false

	# Try group first, fallback to known path
	player = get_tree().get_first_node_in_group("radler")
	if player == null:
		player = game_inst.get_node_or_null("Path2D/PathFollow2D/Player")
	if player:
		if player is CharacterBody2D:
			(player as CharacterBody2D).velocity = Vector2.ZERO
		if player.has_method("set_process"):
			player.call("set_process", false)
		if player.has_method("set_physics_process"):
			player.call("set_physics_process", false)

	# Countdown: Ready → Set → Go!
	for w in words:
		word_label.text = w
		await get_tree().create_timer(step_time).timeout

	# Unfreeze player and show UI, then remove overlay
	if player:
		if player.has_method("set_process"):
			player.call("set_process", true)
		if player.has_method("set_physics_process"):
			player.call("set_physics_process", true)
	if ui_layer:
		ui_layer.visible = true

	overlay.queue_free()  # Remove loading/countdown overlay
