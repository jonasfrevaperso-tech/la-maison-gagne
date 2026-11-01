class_name PromptBadge
extends HBoxContainer
## Petite invite accrochée à un bouton (coin haut gauche) : montre la touche ou le bouton de
## manette qui l'actionne, pour le périphérique actif uniquement.

const BADGE_H: int = 32
const OFFSET: Vector2 = Vector2(-10, -16)

var action: String = ""


static func attach(button: Control, p_action: String) -> PromptBadge:
	var b: PromptBadge = PromptBadge.new()
	b.action = p_action
	button.add_child(b)
	return b


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = OFFSET
	EventBus.input_device_changed.connect(func(_pad: bool) -> void: _rebuild())
	_rebuild()


func _rebuild() -> void:
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	var p: Control = InputGlyphs.prompt(action, BADGE_H)
	if p != null:
		add_child(p)
