class_name EventOverlay
extends Overlay
## Événement entre deux actes : texte + choix à conséquences (effets on_use).

var ctl: RunController = null


func configure(p_ctl: RunController) -> EventOverlay:
	ctl = p_ctl
	return self


func build() -> void:
	var e: Dictionary = ctl.db.get_entry("events", ctl.run.pending_event_id)
	heading(Localization.t(e, "name"))
	var t: Label = UiKit.label(Localization.t(e, "desc"), UiKit.SIZE_BODY)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(t)
	var choices: Array = e.get("choices", [])
	for i: int in choices.size():
		var ch: Dictionary = choices[i]
		var b: Button = UiKit.button(Localization.t(ch, "text"), _pick.bind(i), Vector2(800, 56))
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		body.add_child(b)
		if i == 0:
			b.call_deferred("grab_focus")
	if choices.is_empty():
		body.add_child(UiKit.button(tr("BTN_CONTINUE"), _pick.bind(-1)))


func _pick(i: int) -> void:
	ctl.resolve_event(i)
	close()
