class_name CreditorIntro
extends Overlay
## Entrée théâtrale d'un Créancier : portrait, nom, réplique, règle spéciale.

const SLIDE_TIME: float = 0.5

var creditor: Dictionary = {}


func configure(c: Dictionary) -> CreditorIntro:
	creditor = c
	return self


func build() -> void:
	var col: Color = Color(String(creditor.get("color", "ff2e88")))
	panel.add_theme_stylebox_override("panel", UiKit.flat(Palette.INK, col, 4, 8, 24))
	var h: HBoxContainer = row()
	var portrait: PortraitView = PortraitView.new().configure(String(creditor.get("portrait", "")), col)
	h.add_child(portrait)
	var v: VBoxContainer = VBoxContainer.new()
	v.custom_minimum_size = Vector2(560, 0)
	h.add_child(v)
	v.add_child(UiKit.label(tr("CREDITOR_ARRIVES"), UiKit.SIZE_SMALL, Palette.SMOKE))
	var name_l: Label = UiKit.title(Localization.t(creditor, "name"), UiKit.SIZE_H1)
	name_l.add_theme_color_override("font_color", col)
	v.add_child(name_l)
	var quote: Label = UiKit.label("« %s »" % Localization.t(creditor, "intro"), UiKit.SIZE_H2, Palette.IVORY, "display")
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(quote)
	var rule: Label = UiKit.label(Localization.t(creditor, "desc"), UiKit.SIZE_BODY, Palette.GOLD_LIGHT)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(rule)
	var b: Button = UiKit.button(tr("CREDITOR_ACCEPT"), close)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(b)
	b.call_deferred("grab_focus")
	AudioBus.play("boss_enter")
	EventBus.juice_shake.emit(0.5)
	portrait.position.x = -400.0
	var tw: Tween = portrait.create_tween()
	tw.tween_property(portrait, "position:x", 0.0, SLIDE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
