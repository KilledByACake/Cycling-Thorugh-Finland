extends Node

# Loads the main game scene asynchronously, displays a countdown ("Ready", "Set", "Go"),
# and then enables gameplay. Includes extra safety to ensure the countdown advances.

@export var game_scene_path: String = "res://Levels/Game.tscn"              # Main game scene path
@export var words: PackedStringArray = ["Ready?", "Set..", "Go!"]           # Countdown words
@export var step_time: float = 1.0                                           # Seconds between words
@export var overlay_path: NodePath = ^"Overlay"                              # Overlay (CanvasLayer) path
@export var word_label_path: NodePath = ^"Overlay/VBoxContainer/CountdownTimer"  # Label path (matches your scene tree)

@onready var overlay: CanvasLayer = get_node_or_null(overlay_path) as CanvasLayer  # Overlay kept on top
@onready var word_label: Label = get_node_or_null(word_label_path) as Label        # Label showing countdown text

var game_inst: Node = null       # Instanced main game scene
var ui_layer: CanvasLayer = null # In-game UI layer to hide/show
var player: Node = null          # Player to temporarily freeze


# Waits until a threaded load finishes and returns the final status (success/fail/invalid).
func _await_threaded_load(path: String) -> int:
	var status: int = ResourceLoader.load_threaded_get_status(path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(path)
	return status


# Waits 'seconds' using SceneTreeTimer; this will progress as long as the SceneTree is not paused.
# Keeping it simple (no extra flags) and ensuring the tree is unpaused before countdown starts.
func _wait_seconds(seconds: float) -> void:
	var s: float = max(seconds, 0.0)
	var stt: SceneTreeTimer = get_tree().create_timer(s)
	await stt.timeout


# Orchestrates loading, countdown, and enabling gameplay.
func _ready() -> void:
	# Show initial feedback
	if word_label:
		word_label.text = "Loading..."
	await get_tree().process_frame

	# Start threaded loading
	var req_err: int = ResourceLoader.load_threaded_request(game_scene_path)
	if req_err != OK:
		if word_label:
			word_label.text = "Failed to start load"
		push_error("Failed to start threaded load: " + game_scene_path)
		return

	# Await load completion
	var status: int = await _await_threaded_load(game_scene_path)
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		if word_label:
			word_label.text = "Failed to load scene. Check missing resources."
		push_error("Threaded load failed for: " + game_scene_path)
		return

	# Instance loaded scene
	var packed: PackedScene = ResourceLoader.load_threaded_get(game_scene_path) as PackedScene
	if packed == null:
		if word_label:
			word_label.text = "Loaded scene is null."
		push_error("Threaded load returned null: " + game_scene_path)
		return
	game_inst = packed.instantiate()
	add_child(game_inst)

	# Let the scene enter the tree
	await get_tree().process_frame

	# Ensure the SceneTree is not paused so timers advance
	get_tree().paused = false

	# Hide in-game UI for the countdown
	ui_layer = game_inst.get_node_or_null("UI") as CanvasLayer
	if ui_layer:
		ui_layer.visible = false

	# Freeze the player during countdown
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

	# Countdown loop — advances the label each step
	var delay: float = max(step_time, 0.0)
	for w in words:
		if word_label:
			word_label.text = w
		await _wait_seconds(delay)

	# Unfreeze the player and show the in-game UI
	if player:
		if player.has_method("set_process"):
			player.call("set_process", true)
		if player.has_method("set_physics_process"):
			player.call("set_physics_process", true)
	if ui_layer:
		ui_layer.visible = true

	# Remove the overlay (countdown done)
	if overlay:
		overlay.queue_free()
