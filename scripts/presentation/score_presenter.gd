class_name ScorePresenter
extends Node
## Rejoue la liste de ScoreEvent pas à pas : chaque contribution apparaît à sa source
## (pari sur le tapis, case sur la roue, grigri dans la barre) avec son et animation.

signal finished(total: int)

var score_panel: ScorePanel = null
var float_layer: FloatLayer = null
var grigri_bar: GrigriBar = null
var wheel_view: WheelView = null
var table_view: TableView = null
var debt_remaining: int = 1

var _skip: bool = false
var _playing: bool = false
var _pitch: float = 1.0


func is_playing() -> bool:
	return _playing


func skip() -> void:
	_skip = true


func play(ctx: ScoreContext) -> void:
	_playing = true
	_skip = false
	_pitch = 1.0
	score_panel.reset()
	for e: ScoreEvent in ctx.events:
		await _play_event(e, ctx)
		if not is_inside_tree():
			return
	_playing = false
	finished.emit(ctx.total)


func _wait(t: float) -> void:
	if _skip or t <= 0.0:
		return
	await get_tree().create_timer(t).timeout


func _source_pos(e: ScoreEvent, ctx: ScoreContext) -> Vector2:
	match e.source_kind:
		ScoreEvent.SRC_BET:
			return UiLayout.canvas_point(table_view, table_view.spot_anchor(e.source_id))
		ScoreEvent.SRC_GRIGRI:
			return grigri_bar.card_center(e.source_uid)
		ScoreEvent.SRC_EDITION:
			if grigri_bar.card_for(e.source_uid) != null:
				return grigri_bar.card_center(e.source_uid)
	if ctx.landing_index >= 0 and wheel_view.wheel != null and ctx.landing_index < wheel_view.wheel.size():
		return UiLayout.canvas_point(wheel_view, wheel_view.pocket_screen_pos(ctx.landing_index))
	return UiLayout.canvas_point(wheel_view, wheel_view.size * 0.5)


func _play_event(e: ScoreEvent, ctx: ScoreContext) -> void:
	var step: float = JuiceProfile.step_time()
	var pos: Vector2 = _source_pos(e, ctx)
	if e.source_kind == ScoreEvent.SRC_GRIGRI or e.source_kind == ScoreEvent.SRC_EDITION:
		grigri_bar.bump(e.source_uid)
	match e.kind:
		ScoreEvent.BET_WIN:
			score_panel.set_values(e.chips_after, e.mult_after)
			float_layer.pop_text("+" + Localization.format_number(e.amount), pos, Palette.CHIPS_BLUE)
			float_layer.burst("coins", pos, 10)
			_sfx("chips_win")
			EventBus.subtitle.emit(tr("SUB_BET_WIN"))
			await _wait(step)
		ScoreEvent.BET_LOSE:
			float_layer.pop_text("×", pos, Palette.SMOKE, UiKit.SIZE_BODY)
			AudioBus.play("chip_lose", 1.0, -8.0)
			await _wait(step * 0.35)
		ScoreEvent.CHIPS:
			score_panel.set_values(e.chips_after, e.mult_after)
			float_layer.pop_text(("+" if e.amount >= 0.0 else "") + Localization.format_number(e.amount), pos, Palette.CHIPS_BLUE)
			_sfx("chips")
			await _wait(step)
		ScoreEvent.MULT_ADD:
			score_panel.set_values(e.chips_after, e.mult_after)
			float_layer.pop_text("%s%s Mult" % ["+" if e.amount >= 0.0 else "", ScorePanel._fmt_mult(e.amount)], pos, Palette.MULT_RED)
			_sfx("mult")
			await _wait(step)
		ScoreEvent.MULT_MUL:
			score_panel.set_values(e.chips_after, e.mult_after)
			float_layer.pop_text("×%s Mult" % ScorePanel._fmt_mult(e.amount), pos, Palette.MULT_RED, UiKit.SIZE_H1)
			float_layer.burst("sparks", pos, 18)
			_sfx("xmult")
			EventBus.juice_shake.emit(0.25)
			await _wait(step * 1.2)
		ScoreEvent.MONEY:
			var sign: String = "+" if e.amount >= 0.0 else "−"
			float_layer.pop_text("%s%d $" % [sign, absi(int(e.amount))], pos, Palette.GOLD_LIGHT)
			if e.amount > 0.0:
				float_layer.burst("coins", pos, 14)
				AudioBus.play("coins")
			else:
				AudioBus.play("coin_loss")
			EventBus.money_changed.emit(GameState.run().money if GameState.has_active_run() else 0)
			await _wait(step * 0.8)
		ScoreEvent.ZERO:
			float_layer.pop_text(tr("FX_ZERO"), UiLayout.canvas_point(wheel_view, wheel_view.size * 0.5), Palette.EMERALD, UiKit.SIZE_TITLE)
			EventBus.juice_flash.emit(Palette.ZERO_GREEN, 0.5)
			EventBus.juice_shake.emit(0.6)
			AudioBus.play("zero")
			EventBus.subtitle.emit(tr("SUB_ZERO"))
			await _wait(step * 2.0)
		ScoreEvent.DESTROY:
			float_layer.burst("smoke", pos, 20)
			float_layer.pop_text(_info_text(e), pos, Palette.DANGER)
			AudioBus.play("shatter")
			EventBus.subtitle.emit(tr("SUB_DESTROY"))
			EventBus.juice_shake.emit(0.35)
			await _wait(step)
		ScoreEvent.TRANSFORM:
			float_layer.burst("sparks", pos, 12)
			float_layer.pop_text(_info_text(e), pos, Palette.CYAN, UiKit.SIZE_BODY)
			AudioBus.play("transform")
			await _wait(step * 0.7)
		ScoreEvent.SPINS:
			float_layer.pop_text(tr("FX_SPINS") % int(e.amount), pos, Palette.EMERALD)
			AudioBus.play("clock")
			await _wait(step)
		ScoreEvent.COUNTER:
			float_layer.pop_text("↑", pos, Palette.EMERALD, UiKit.SIZE_BODY)
			await _wait(step * 0.4)
		ScoreEvent.TOTAL:
			await _play_total(int(e.amount))
		_:
			if e.text != "":
				float_layer.pop_text(_info_text(e), pos, Palette.IVORY, UiKit.SIZE_BODY)
				await _wait(step * 0.6)


func _info_text(e: ScoreEvent) -> String:
	if e.text == "":
		return ""
	var key: String = "FX_" + e.text.to_upper()
	var t: String = tr(key)
	if t != key:
		return t
	# Identifiant de contenu (grigri/fortune créé) : on affiche son nom.
	for cat: String in ["grigris", "fortunes"]:
		if DataRegistry.db.has_entry(cat, e.text):
			return Localization.name_of(cat, e.text)
	return e.text


func _sfx(id: String) -> void:
	AudioBus.play(id, _pitch)
	_pitch = minf(_pitch + JuiceProfile.PITCH_STEP, JuiceProfile.PITCH_MAX)


func _play_total(total: int) -> void:
	var count_time: float = JuiceProfile.COUNT_UP_TIME / maxf(Settings.speed(), 1.0)
	if _skip:
		count_time = 0.01
	score_panel.show_total(total, count_time)
	AudioBus.play("count_up", 1.0)
	var ratio: float = float(total) / maxf(float(debt_remaining), 1.0)
	var tier: int = -1
	for i: int in JuiceProfile.CELEBRATION_TIERS.size():
		if ratio >= JuiceProfile.CELEBRATION_TIERS[i]:
			tier = i
	await _wait(count_time)
	if tier >= 0:
		var center: Vector2 = UiLayout.canvas_point(score_panel, score_panel.size * 0.5) + Vector2(0, 120)
		var sizes: Array[int] = [UiKit.SIZE_H2, UiKit.SIZE_H1, UiKit.SIZE_TITLE, UiKit.SIZE_TITLE]
		float_layer.pop_text(
			tr(JuiceProfile.CELEBRATION_KEYS[tier]),
			center,
			[Palette.EMERALD, Palette.CYAN, Palette.GOLD_LIGHT, Palette.MAGENTA][tier],
			sizes[tier]
		)
		if tier >= 1:
			float_layer.burst("confetti", center, 30 * (tier + 1))
			EventBus.juice_shake.emit(0.2 * float(tier + 1))
		if tier >= 2:
			EventBus.juice_hitstop.emit(JuiceProfile.HITSTOP_MAX * float(tier - 1) * 0.5)
			EventBus.juice_flash.emit(Palette.GOLD_LIGHT, 0.3 * float(tier - 1))
			AudioBus.play("jackpot")
			EventBus.subtitle.emit(tr("SUB_JACKPOT"))
		else:
			AudioBus.play("celebrate")
		await _wait(JuiceProfile.step_time() * 2.0)
