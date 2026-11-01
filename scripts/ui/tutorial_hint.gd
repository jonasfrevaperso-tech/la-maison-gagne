class_name TutorialHint
extends Overlay
## Bulle d'accueil du premier tour (le tutoriel complet est géré par TutorialDirector).


func build() -> void:
	panel_width = 980.0
	heading(tr("TUTO_WELCOME_TITLE"))
	for key: String in ["TUTO_WELCOME_1", "TUTO_WELCOME_2", "TUTO_WELCOME_3", "TUTO_WELCOME_4"]:
		var l: Label = UiKit.label(tr(key), UiKit.SIZE_BODY)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(l)
	var b: Button = UiKit.button(tr("BTN_UNDERSTOOD"), _done)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(b)
	b.call_deferred("grab_focus")


func _done() -> void:
	var tuto: Dictionary = SaveSystem.profile.get("tutorial", {})
	tuto["done"] = true
	SaveSystem.profile["tutorial"] = tuto
	SaveSystem.save_profile()
	close()
