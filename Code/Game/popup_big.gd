@tool
extends Node2D

# Text displayed in the popup
@export_multiline var popup_text: String = "Default Text. CHANGE ME!!":
	set(v):
		popup_text = v
		_update_label()

# Maximum width of the popup label
@export var max_width: float = 950.0:
	set(v):
		max_width = v
		_update_label()

#@export_group("Einblenden / Ausblenden")
# How long the popup stays visible before hiding (only if auto_hide is true)
#@export var display_duration: float = 3.0
# If true, popup hides automatically after display_duration
#@export var auto_hide: bool = true
# How close the player's x position needs to be to trigger the popup
@export var trigger_tolerance: float = 20.0

var _panel_container: PanelContainer
var _margin_container: MarginContainer
var _label: Label
var _tween: Tween
#var _hide_timer: Timer
var _triggered := false

func _ready() -> void:
	# Get references to the popup nodes
	_panel_container  = $PopupBig/PanelContainer
	_margin_container = $PopupBig/PanelContainer/MarginContainer
	_label            = $PopupBig/PanelContainer/MarginContainer/Label

	# Hide popup at game start, keep visible in editor
	if not Engine.is_editor_hint():
		_panel_container.modulate.a = 0.0

	_update_label()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Find player by group
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return

	var character = players[0]
	var trigger = $Trigger

	# Check if player x position is close enough to the trigger
	var diff = abs(character.global_position.x - trigger.global_position.x)

	if diff < trigger_tolerance and not _triggered:
		_show_popup()
	elif diff >= trigger_tolerance:
		# Reset so popup can trigger again if player passes again
		_triggered = false

func _update_label() -> void:
	# Try to get label reference if not set yet
	if not _label:
		_label = get_node_or_null("PopupBig/PanelContainer/MarginContainer/Label")
	if not _label:
		return

	_label.text = popup_text

	# Set max width via margin container
	if _margin_container:
		_margin_container.custom_minimum_size.x = max_width


func _show_popup() -> void:
	if _triggered:
		return
	_triggered = true

	if _tween:
		_tween.kill()

	# Fade in
	_panel_container.modulate.a = 0.0
	_panel_container.visible = true
	_tween = create_tween()
	_tween.tween_property(_panel_container, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)

	# Start hide timer if auto_hide is enabled
	#if auto_hide:
		#if _hide_timer:
			#_hide_timer.queue_free()
		#_hide_timer = Timer.new()
		#_hide_timer.wait_time = display_duration
		#_hide_timer.one_shot = true
		#add_child(_hide_timer)
		#_hide_timer.timeout.connect(_hide_popup)
		#_hide_timer.start()

#func _hide_popup() -> void:
	## Fade out and hide
	#if _tween:
		#_tween.kill()
	#_tween = create_tween()
	#_tween.tween_property(_panel_container, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	#_tween.tween_callback(func(): _panel_container.visible = false)

func _recalculate_size() -> void:
	# Reset panel size so Godot recalculates it from content
	if not _panel_container:
		_panel_container = $PopupBig/PanelContainer
	if _panel_container:
		_panel_container.reset_size()
