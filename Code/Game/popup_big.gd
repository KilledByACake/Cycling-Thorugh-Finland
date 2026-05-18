@tool
extends Node2D

# Popup text shown in the label.
@export_multiline var popup_text: String = "Default Text. CHANGE ME!!":
	set(v):
		popup_text = v
		_update_label()

# Maximum width (pixels) for the popup label area.
@export var max_width: float = 950.0:
	set(v):
		max_width = v
		_update_label()

# Distance (pixels) on X before the popup is shown.
@export var trigger_tolerance: float = 20.0

# Cached node references and state.
var _panel_container: PanelContainer
var _margin_container: MarginContainer
var _label: Label
var _tween: Tween
var _triggered := false

# Initializes references and sets initial visibility (hidden in game, visible in editor).
func _ready() -> void:
	_panel_container  = $PopupBig/PanelContainer
	_margin_container = $PopupBig/PanelContainer/MarginContainer
	_label            = $PopupBig/PanelContainer/MarginContainer/Label

	if not Engine.is_editor_hint():
		_panel_container.modulate.a = 0.0

	_update_label()

# In-game loop: checks player distance to the Trigger node and shows the popup when close.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Find the first player in the "player" group.
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return

	var character = players[0]
	var trigger = $Trigger

	# Horizontal distance from player to trigger anchor.
	var diff = abs(character.global_position.x - trigger.global_position.x)

	# Show once when within tolerance; reset when out of range.
	if diff < trigger_tolerance and not _triggered:
		_show_popup()
	elif diff >= trigger_tolerance:
		_triggered = false

# Updates label text and width constraints from exported properties.
func _update_label() -> void:
	# Lazy resolve if needed.
	if not _label:
		_label = get_node_or_null("PopupBig/PanelContainer/MarginContainer/Label")
	if not _label:
		return

	_label.text = popup_text

	# Enforce maximum width via the margin container.
	if _margin_container:
		_margin_container.custom_minimum_size.x = max_width

# Plays a fade-in tween to reveal the popup.
func _show_popup() -> void:
	if _triggered:
		return
	_triggered = true

	# Stop any previous tween.
	if _tween:
		_tween.kill()

	# Fade in the panel container.
	_panel_container.modulate.a = 0.0
	_panel_container.visible = true
	_tween = create_tween()
	_tween.tween_property(_panel_container, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)

# Forces a size recalculation for the panel container.
func _recalculate_size() -> void:
	if not _panel_container:
		_panel_container = $PopupBig/PanelContainer
	if _panel_container:
		_panel_container.reset_size()
