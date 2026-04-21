extends Button

@onready var rtl: RichTextLabel = $RichTextLabel

func _ready() -> void:
	focus_entered.connect(_highlight)
	mouse_entered.connect(_highlight)
	focus_exited.connect(_unhighlight)
	mouse_exited.connect(_unhighlight)
	if rtl:
		rtl.bbcode_enabled = true

func _highlight() -> void:
	if rtl:
		rtl.modulate = Color("#009764")

func _unhighlight() -> void:
	if rtl:
		rtl.modulate = Color("#ffffff")
