class_name ConfirmBox
extends Overlay
## Confirmation avant une action irréversible.

signal confirmed
signal declined

var message: String = ""


func configure(p_message: String) -> ConfirmBox:
	message = p_message
	panel_width = 700.0
	return self


func build() -> void:
	var l: Label = UiKit.label(message, UiKit.SIZE_H2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(l)
	var h: HBoxContainer = row()
	var yes: Button = UiKit.button(tr("BTN_YES"), _yes)
	h.add_child(yes)
	var no: Button = UiKit.button(tr("BTN_NO"), _no)
	h.add_child(no)
	# Oui ↔ Non seulement : la manette ne quitte jamais la confirmation.
	for pair: Array in [[yes, no], [no, yes]]:
		var a: Button = pair[0] as Button
		var b: NodePath = a.get_path_to(pair[1] as Button)
		a.focus_neighbor_left = b
		a.focus_neighbor_right = b
		a.focus_next = b
		a.focus_previous = b
		a.focus_neighbor_top = NodePath(".")
		a.focus_neighbor_bottom = NodePath(".")
	yes.call_deferred("grab_focus")
	closed.connect(queue_free)


func _yes() -> void:
	confirmed.emit()
	close()


func _no() -> void:
	declined.emit()
	close()


func go_back() -> void:
	_no()
