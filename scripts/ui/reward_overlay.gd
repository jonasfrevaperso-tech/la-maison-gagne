class_name RewardOverlay
extends Overlay
## Échéance remboursée : détail de la récompense (base, tours restants, intérêts).

var reward: Dictionary = {}
var victory: bool = false


func configure(p_reward: Dictionary, p_victory: bool) -> RewardOverlay:
	reward = p_reward
	victory = p_victory
	return self


func build() -> void:
	heading(tr("REWARD_VICTORY") if victory else tr("REWARD_TITLE"))
	var lines: Array[Array] = [
		["REWARD_BASE", int(reward.get("base", 0))],
		["REWARD_SPINS", int(reward.get("spins", 0))],
		["REWARD_INTEREST", int(reward.get("interest", 0))],
	]
	var delay: float = 0.0
	for ln: Array in lines:
		var h: HBoxContainer = row()
		var a: Label = UiKit.label(tr(String(ln[0])), UiKit.SIZE_H2)
		a.custom_minimum_size = Vector2(520, 0)
		h.add_child(a)
		var b: Label = UiKit.label("+%d $" % int(ln[1]), UiKit.SIZE_H2, Palette.GOLD_LIGHT, "mono")
		h.add_child(b)
		h.modulate.a = 0.0
		var tw: Tween = h.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(h, "modulate:a", 1.0, 0.2)
		tw.tween_callback(AudioBus.play.bind("coin", 1.0 + delay))
		delay += 0.25 / maxf(Settings.speed(), 1.0)
	var total: Label = UiKit.title(tr("REWARD_TOTAL") % int(reward.get("total", 0)), UiKit.SIZE_H1)
	body.add_child(total)
	var btn: Button = UiKit.button(tr("BTN_CONTINUE"), close)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(btn)
	btn.call_deferred("grab_focus")
