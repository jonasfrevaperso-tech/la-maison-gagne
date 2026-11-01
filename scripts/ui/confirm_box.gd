class_name ConfirmBox
extends Overlay
## Confirmation avant une action irréversible.

signal confirmed

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
	h.add_child(UiKit.button(tr("BTN_NO"), _no))
	yes.call_deferred("grab_focus")
	closed.connect(queue_free)


func _yes() -> void:
	confirmed.emit()
	close()


func _no() -> void:
	close()
