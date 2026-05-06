extends Control
signal name_confirmed(name: String)

const MIN_NAME_CHARACTERS: int = 3
const MAX_NAME_CHARACTERS: int = 15

const MAIN_MENU_SCENE_PATH: String = "res://Levels/Main.tscn"
const LOADING_SCENE_PATH: String = "res://Levels/Loading.tscn"

# Dialog sizing used only when "_RESET" is typed
const DIALOG_LABEL_SIZE: int = 72
const DIALOG_BUTTON_SIZE: int = 64
const DIALOG_MIN_SIZE: Vector2i = Vector2i(900, 420)
const DIALOG_BTN_MIN: Vector2i = Vector2i(320, 130)
const DIALOG_BUTTONS_SEP: int = 40

# On-screen keyboard layout
var rows: Array = [
	["1","2","3","4","5","6","7","8","9","0"],
	["Q","W","E","R","T","Y","U","I","O","P"],
	["A","S","D","F","G","H","J","K","L","Å"],
	["Z","X","C","V","B","N","M","Ä","Ö","_"]
]
var indents: PackedInt32Array = [0, 0, 0, 0]

var name_text: String = ""

@onready var grid: GridContainer = $GridContainer
@onready var name_label: Label = $Label

# Reset-view dialogs (display-only daily list)
var _confirm_reset_dlg: ConfirmationDialog
var _info_dlg: AcceptDialog

func _ready() -> void:
	grid.columns = _calc_columns()
	_build_character_grid()
	await get_tree().process_frame
	_center_grid()
	_show_name_input()
	if get_tree().root.has_signal("size_changed"):
		get_tree().root.size_changed.connect(_center_grid)

func _calc_columns() -> int:
	var cols: int = 0
	for i in rows.size():
		cols = maxi(cols, indents[i] + (rows[i] as Array).size())
	return cols

func _build_character_grid() -> void:
	for c in grid.get_children():
		c.queue_free()
	var columns: int = _calc_columns()
	grid.columns = columns
	for i in rows.size():
		var indent: int = indents[i]
		_add_spacers(indent)
		for ch in (rows[i] as Array):
			var btn := Button.new()
			btn.text = String(ch)
			btn.pressed.connect(CharacterButtonPressed.bind(String(ch)))
			grid.add_child(btn)
		var trailing: int = columns - indent - (rows[i] as Array).size()
		_add_spacers(trailing)

func _add_spacers(count: int) -> void:
	for _i in count:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(40, 40)
		grid.add_child(spacer)

func _center_grid() -> void:
	grid.anchor_left = 0.5
	grid.anchor_top = 0.5
	grid.anchor_right = 0.5
	grid.anchor_bottom = 0.5
	var s := grid.get_combined_minimum_size()
	if s.x <= 0.0 or s.y <= 0.0:
		s = Vector2(560, 320)
	grid.offset_left = -s.x * 0.5
	grid.offset_top = -s.y * 0.5
	grid.offset_right = s.x * 0.5
	grid.offset_bottom = s.y * 0.5

func CharacterButtonPressed(ch: String) -> void:
	if name_text.length() >= MAX_NAME_CHARACTERS:
		_flash_name_label()
		return
	name_text += ch
	_update_name_label()

func _show_name_input() -> void:
	name_text = ""
	_update_name_label()
	await get_tree().process_frame
	var first := _first_focusable_button()
	if first:
		first.grab_focus()

func _first_focusable_button() -> Button:
	for c in grid.get_children():
		if c is Button and not (c as Button).disabled:
			return c
	return null

func _update_name_label() -> void:
	if name_label:
		name_label.text = name_text + ("_" if name_text.length() < MAX_NAME_CHARACTERS else "")

func _flash_name_label() -> void:
	if not name_label: return
	var original := name_label.modulate
	name_label.modulate = Color(1, 0.6, 0.6)
	await get_tree().create_timer(0.12).timeout
	name_label.modulate = original

func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _on_backspace_pressed() -> void:
	if name_text.length() > 0:
		name_text = name_text.substr(0, name_text.length() - 1)
	_update_name_label()

func _on_done_pressed() -> void:
	var trimmed := name_text.strip_edges()
	# Special command to reset today's display-only list
	if trimmed == "_RESET":
		_show_reset_confirm()
		return
	if trimmed.length() < MIN_NAME_CHARACTERS:
		_flash_name_label()
		return
	# Store player name and go to the Loading scene
	get_tree().root.set_meta("player_name", trimmed)
	emit_signal("name_confirmed", trimmed)
	get_tree().change_scene_to_file(LOADING_SCENE_PATH)

# --- styling used only when "_RESET" is typed ---

func _style_confirm_dialog(dlg: ConfirmationDialog) -> void:
	var lbl := dlg.get_label()
	if lbl:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", DIALOG_LABEL_SIZE)
	var ok := dlg.get_ok_button()
	if ok:
		ok.text = "Yes"
		ok.custom_minimum_size = DIALOG_BTN_MIN
		ok.add_theme_font_size_override("font_size", DIALOG_BUTTON_SIZE)
	var cancel := dlg.get_cancel_button()
	if cancel:
		cancel.text = "No"
		cancel.custom_minimum_size = DIALOG_BTN_MIN
		cancel.add_theme_font_size_override("font_size", DIALOG_BUTTON_SIZE)
	if ok and ok.get_parent() is BoxContainer:
		var box := ok.get_parent() as BoxContainer
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", DIALOG_BUTTONS_SEP)

func _style_info_dialog(dlg: AcceptDialog) -> void:
	var lbl := dlg.get_label()
	if lbl:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", DIALOG_LABEL_SIZE)
	var ok := dlg.get_ok_button()
	if ok:
		ok.custom_minimum_size = DIALOG_BTN_MIN
		ok.add_theme_font_size_override("font_size", DIALOG_BUTTON_SIZE)
	if ok and ok.get_parent() is BoxContainer:
		var box := ok.get_parent() as BoxContainer
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", DIALOG_BUTTONS_SEP)

# Reset-view confirmation flow (design applies only here)
func _show_reset_confirm() -> void:
	if _confirm_reset_dlg == null:
		_confirm_reset_dlg = ConfirmationDialog.new()
		_confirm_reset_dlg.title = "Confirm"
		_confirm_reset_dlg.dialog_text = "Are you sure you want to reset today's high score list?"
		add_child(_confirm_reset_dlg)
		if not _confirm_reset_dlg.confirmed.is_connected(_on_reset_confirmed):
			_confirm_reset_dlg.confirmed.connect(_on_reset_confirmed)
		var cancel_btn := _confirm_reset_dlg.get_cancel_button()
		if cancel_btn and not cancel_btn.pressed.is_connected(_on_reset_canceled):
			cancel_btn.pressed.connect(_on_reset_canceled)
		_confirm_reset_dlg.get_ok_button().text = "Yes"
		_confirm_reset_dlg.get_cancel_button().text = "No"
		_style_confirm_dialog(_confirm_reset_dlg)
	_confirm_reset_dlg.popup_centered_clamped(DIALOG_MIN_SIZE, 0.9)

func _on_reset_confirmed() -> void:
	var hs := get_node_or_null("/root/HighScores")
	if hs:
		hs.call("reset_today_view")
	_show_info_and_return()

func _on_reset_canceled() -> void:
	name_text = ""
	_update_name_label()
	var first := _first_focusable_button()
	if first:
		first.grab_focus()

func _show_info_and_return() -> void:
	if _info_dlg == null:
		_info_dlg = AcceptDialog.new()
		_info_dlg.title = "Info"
		_info_dlg.dialog_text = "Daily high score list is reset."
		add_child(_info_dlg)
		if not _info_dlg.confirmed.is_connected(_on_info_ok):
			_info_dlg.confirmed.connect(_on_info_ok)
		_style_info_dialog(_info_dlg)
	_info_dlg.popup_centered_clamped(DIALOG_MIN_SIZE, 0.9)

func _on_info_ok() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
