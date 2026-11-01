class_name PactOverlay
extends Overlay
## Échec : La Maison propose un Pacte (un tour de plus contre un sacrifice).

var ctl: RunController = null


func configure(p_ctl: RunController) -> PactOverlay:
	ctl = p_ctl
	return self


func build() -> void:
	heading(tr("PACT_TITLE"))
	var r: RunState = ctl.run
	var l: Label = UiKit.label(
		(
			tr("PACT_TEXT")
			% [
				Localization.format_number(float(r.deadline_score)),
				Localization.format_number(float(r.debt)),
				Balance.i("pact.extra_spins")
			]
		),
		UiKit.SIZE_BODY
	)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(l)
	var first: Button = null
	for o: Dictionary in ctl.pact_options():
		var txt: String = ""
		match String(o["kind"]):
			"grigri":
				var g: GrigriInstance = r.grigri_by_uid(int(o["uid"]))
				txt = tr("PACT_GRIGRI") % Localization.name_of("grigris", g.id)
			"pocket":
				txt = tr("PACT_POCKET")
			"budget":
				txt = tr("PACT_BUDGET") % int(o["amount"])
		var b: Button = UiKit.button(txt, _accept.bind(o), Vector2(700, 60))
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		body.add_child(b)
		if first == null:
			first = b
	var decline: Button = UiKit.button(tr("PACT_DECLINE"), _decline, Vector2(700, 60))
	decline.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(decline)
	(first if first != null else decline).call_deferred("grab_focus")
	AudioBus.play("pact")


func _accept(o: Dictionary) -> void:
	if ctl.accept_pact(o):
		AudioBus.play("curse")
	close()


func _decline() -> void:
	ctl.decline_pact()
	close()
