extends Button

# Highlights an attached RichTextLabel when the button is focused or hovered.

@onready var rtl: RichTextLabel = $RichTextLabel

# Called when the node enters the scene; connects signals and enables BBCode on the label.
func _ready() -> void:
	focus_entered.connect(_highlight)
	mouse_entered.connect(_highlight)
	focus_exited.connect(_unhighlight)
	mouse_exited.connect(_unhighlight)
	if rtl:
		rtl.bbcode_enabled = true

# Sets the label color to the highlight color.
func _highlight() -> void:
	if rtl:
		rtl.modulate = Color("#009764")

# Restores the label color to white.
func _unhighlight() -> void:
	if rtl:
		rtl.modulate = Color("#ffffff")
