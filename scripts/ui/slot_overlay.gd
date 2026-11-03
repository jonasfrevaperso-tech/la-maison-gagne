class_name SlotOverlay
extends Control
## JACKPOT ! Lucette, la machine à sous du Grand Zéro, apparaît en 3D dans sa salle : 1 à 5
## tirages. Les combinaisons et leurs gains sont DÉJÀ résolus par le cœur (RunController →
## SlotMachine) ; cette surcouche les met en scène : levier, quatre rouleaux lancés à pleine
## vitesse qui s'arrêtent lentement l'un après l'autre (le dernier rampe case par case quand un
## brelan ou un carré est possible), ampoules, pièces qui tombent dans le bac, bannière de gain.
## Toute commande tire le levier / accélère / continue.

signal closed

enum Step { INTRO, WAIT_PULL, SPINNING, RESULT, SUMMARY }

## Téléphone : vibrations (ms) à l'arrêt d'un rouleau et au gros lot.
const HAPTIC_REEL_MS: int = 12
const HAPTIC_JACKPOT_MS: int = 60
const REELS: int = SlotCabinet3D.REELS
const INTRO_TIME: float = 1.6
const AUTO_PULL: float = 4.0
const RESULT_TIME: float = 2.6
const AUTO_CLOSE: float = 9.0
const LEVER_TIME: float = 0.7
const SPIN_SPEED: float = 16.0
const SPIN_ACCEL: float = 28.0
## Instant (après le levier) où chaque rouleau commence à freiner.
const STOP_AT: Array[float] = [1.5, 2.3, 3.1, 3.9]
const STOP_TIME: float = 1.3
## Freinage du rouleau sous tension : bien plus long, courbe plus douce (rampe case par case).
const TEASE_TIME: float = 3.2
const TEASE_POW: float = 5.0
const NORMAL_POW: float = 3.0
const HURRY_TIME: float = 0.5
const BOUNCE: float = 0.12
const COINS_BIG: int = 110
const COINS_SMALL: int = 30
const TRAY_COINS: Dictionary = {"pair": 5, "triple": 14, "quad": 30}

var _hurried: bool = false
var _spins: Array[Dictionary] = []
var _db: ContentDB = null
var _index: int = 0
var _step: Step = Step.INTRO
var _t: float = 0.0
var _phase: float = 0.0
var _win: float = 0.0
var _lever_t: float = -1.0
var _won: Array[Dictionary] = []
var _stage: Stage3D = null
var _cab: SlotCabinet3D = null
var _pos: Array[float] = []
var _speed: Array[float] = []
## Freinage en cours : départ, arrivée, durée, temps écoulé, exposant (-1 = tourne librement).
var _stop: Array[Dictionary] = []
var _done: Array[bool] = []
var _tease: int = -1
var _heart_t: float = 0.0
var _banner: Label = null
var _info: Label = null
var _prompt: RichTextLabel = null
var _summary: PanelContainer = null
var _blink_t: float = 2.0
var _rng: RandomNumberGenerator = null


func configure(spins: Array[Dictionary], db: ContentDB) -> SlotOverlay:
	_spins = spins
	_db = db
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()
	_rng = RngService.cosmetic()
	_stage = Stage3D.new()
	add_child(_stage)
	_stage.env.ambient_light_energy = 0.35
	_cab = SlotCabinet3D.new()
	_stage.root.add_child(_cab)
	var ids: Array[String] = []
	for s: Dictionary in _db.list("slot_symbols"):
		ids.append(String(s["id"]))
	_cab.build(ids, _rng)
	for k: int in REELS:
		_pos.append(float(_rng.randi_range(0, SlotCabinet3D.CELLS - 1)))
		_speed.append(0.0)
		_stop.append({})
		_done.append(true)
		_cab.set_reel(k, _pos[k])
	_build_texts()
	_stage.look(Vector3(0, 2.6, 7.5), Vector3(0, 1.6, 0), 40.0)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)
	AudioBus.play("jackpot", 1.0, 0.0)
	Platform.haptic(HAPTIC_JACKPOT_MS)
	AudioBus.play("slot_ring", 1.0, -3.0)
	EventBus.juice_flash.emit(Palette.GOLD_LIGHT, 0.4)
	EventBus.juice_shake.emit(0.5)
	EventBus.subtitle.emit(tr("SUB_SLOT"))


func _build_texts() -> void:
	_info = UiKit.label("", UiKit.SIZE_H2, Palette.IVORY, "display")
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_info.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_info.position = Vector2(36, 24)
	_info.add_theme_color_override("font_outline_color", Palette.INK)
	_info.add_theme_constant_override("outline_size", 10)
	add_child(_info)
	_banner = UiKit.label("", UiKit.SIZE_H1, Palette.GOLD_LIGHT, "display")
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_banner.offset_top = -150.0
	_banner.offset_bottom = -70.0
	_banner.offset_left = 80.0
	_banner.offset_right = -80.0
	_banner.add_theme_color_override("font_outline_color", Palette.INK)
	_banner.add_theme_constant_override("outline_size", 14)
	_banner.pivot_offset = Vector2(0, 40)
	add_child(_banner)
	_prompt = UiKit.rich("", UiKit.SIZE_BODY + 4)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -64.0
	_prompt.offset_bottom = -16.0
	add_child(_prompt)


# --------------------------------------------------------------------------- déroulé


func _process(delta: float) -> void:
	_t += delta
	_phase += delta * (12.0 if _step == Step.SPINNING else 4.0)
	_win = maxf(_win - delta * 0.5, 0.0)
	_cab.bulbs(_phase, _win)
	_update_lever(delta)
	_update_reels(delta)
	_update_eyes(delta)
	_update_camera(delta)
	match _step:
		Step.INTRO:
			if _t >= INTRO_TIME:
				_wait_pull()
		Step.WAIT_PULL:
			var a: float = 0.55 + 0.45 * sin(_t * 6.0)
			_prompt.modulate.a = a
			if _t >= AUTO_PULL:
				_pull()
		Step.SPINNING:
			_tick_tension(delta)
			if _done.all(func(d: bool) -> bool: return d):
				_resolve()
		Step.RESULT:
			if _t >= RESULT_TIME:
				_index += 1
				if _index < _spins.size():
					_wait_pull()
				else:
					_show_summary()
		Step.SUMMARY:
			if _t >= AUTO_CLOSE:
				_close()


## Caméra : travelling d'entrée vers la machine, léger flottement, zoom sur la fenêtre au gain.
func _update_camera(delta: float) -> void:
	var near: Vector3 = Vector3(0.0, 1.95, 3.85)
	var at: Vector3 = Vector3(0.0, 1.82, 0.0)
	if _step == Step.INTRO:
		var u: float = clampf(_t / INTRO_TIME, 0.0, 1.0)
		var e: float = 1.0 - pow(1.0 - u, 3.0)
		_stage.look(Vector3(0, 2.6, 7.5).lerp(near, e), at, 40.0)
		return
	var sway: Vector3 = Vector3(sin(_t * 0.4) * 0.06, sin(_t * 0.31) * 0.03, 0.0)
	var zoom: float = 0.35 * _win if _step == Step.RESULT else 0.0
	var target: Vector3 = near + sway + Vector3(0, -0.2, -1.6) * zoom
	var cur: Vector3 = _stage.cam.position.lerp(target, clampf(delta * 3.0, 0.0, 1.0))
	_stage.look(cur, at.lerp(Vector3(0, SlotCabinet3D.REEL_Y, 0), zoom), 40.0)


func _update_lever(delta: float) -> void:
	if _lever_t < 0.0:
		return
	_lever_t += delta
	var u: float = _lever_t / LEVER_TIME
	_cab.lever(sin(clampf(u, 0.0, 1.0) * PI))
	if u >= 1.0:
		_lever_t = -1.0
		_cab.lever(0.0)


func _update_eyes(delta: float) -> void:
	_blink_t -= delta
	if _blink_t < -0.15:
		_blink_t = _rng.randf_range(1.5, 4.0)
	var look: float = 0.0
	if _step == Step.SPINNING:
		for k: int in REELS:
			if not _done[k]:
				look = (float(k) - 1.5) / 1.5
				break
	var closed: bool = _blink_t < 0.0 or (_step == Step.RESULT and _win > 0.3 and int(_t * 6.0) % 2 == 0)
	_cab.eyes(look, closed)


func _wait_pull() -> void:
	_step = Step.WAIT_PULL
	_t = 0.0
	_info.text = tr("SLOT_SPIN_COUNT") % [_index + 1, _spins.size()]
	_prompt.text = "[center]%s[/center]" % InputGlyphs.expand(tr("SLOT_PULL") % "{ui_spin}", 34)
	_banner.text = ""


func _pull() -> void:
	if _step != Step.WAIT_PULL:
		return
	_step = Step.SPINNING
	_t = 0.0
	_lever_t = 0.0
	_prompt.text = ""
	_banner.text = ""
	AudioBus.play("slot_lever")
	AudioBus.play("slot_spin", 1.0, -6.0)
	var reels: Array = _spins[_index]["reels"]
	_tease = _tease_reel(reels)
	_hurried = false
	for k: int in REELS:
		_done[k] = false
		_stop[k] = {}
		_speed[k] = 0.0


## Rouleau à faire attendre : le dernier quand les trois premiers promettent un brelan ou un
## carré, sinon le troisième quand les deux premiers sont identiques.
static func _tease_reel(reels: Array) -> int:
	var counts: Dictionary = {}
	for k: int in 3:
		counts[String(reels[k])] = int(counts.get(String(reels[k]), 0)) + 1
	if counts.values().max() >= 2:
		return 3
	if String(reels[0]) == String(reels[1]):
		return 2
	return -1


func _update_reels(delta: float) -> void:
	if _step != Step.SPINNING:
		return
	var reels: Array = _spins[_index]["reels"]
	for k: int in REELS:
		if _done[k]:
			continue
		var st: Dictionary = _stop[k]
		if st.is_empty():
			# Lancement échelonné puis vitesse de croisière.
			if _t > 0.25 + 0.08 * float(k):
				_speed[k] = minf(_speed[k] + SPIN_ACCEL * delta, SPIN_SPEED)
				_advance(k, _speed[k] * delta)
			var at: float = STOP_AT[k] + (TEASE_TIME * 0.35 if k > _tease and _tease >= 0 else 0.0)
			if _t >= at and (k == 0 or not _stop[k - 1].is_empty()):
				_begin_stop(k, String(reels[k]), k == _tease)
			continue
		st["t"] = float(st["t"]) + delta
		var u: float = clampf(float(st["t"]) / float(st["dur"]), 0.0, 1.0)
		var e: float = 1.0 - pow(1.0 - u, float(st["pow"]))
		var p: float = lerpf(float(st["from"]), float(st["to"]), e)
		var after: float = float(st["t"]) - float(st["dur"])
		if after > 0.0:
			# Petit rebond mécanique à l'arrêt.
			p = float(st["to"]) - sin(clampf(after / BOUNCE, 0.0, 1.0) * PI) * 0.08
			if after >= BOUNCE:
				p = float(st["to"])
				_done[k] = true
				_on_reel_stopped(k)
		_advance(k, p - _pos[k])


func _advance(k: int, d: float) -> void:
	var before: int = int(floor(_pos[k] + 0.5))
	_pos[k] += d
	_cab.set_reel(k, _pos[k])
	# Cliquetis à chaque case qui passe quand le rouleau ralentit (tension audible).
	var after: int = int(floor(_pos[k] + 0.5))
	if after != before and not _stop[k].is_empty() and _speed[k] > 0.0:
		var slow_u: float = clampf(float(_stop[k]["t"]) / float(_stop[k]["dur"]), 0.0, 1.0)
		if slow_u > 0.35:
			AudioBus.play("tick", 0.8 + 0.6 * slow_u, -8.0)


## Freinage : on choisit la case d'arrivée pour que la vitesse reste continue (courbe
## 1 - (1-u)^n, de pente initiale n·distance/durée = vitesse actuelle).
func _begin_stop(k: int, symbol: String, tease: bool) -> void:
	var pw: float = TEASE_POW if tease else NORMAL_POW
	var dur: float = TEASE_TIME if tease else STOP_TIME
	var v: float = maxf(_speed[k], 1.0)
	var to: int = _cab.cell_for(k, symbol, _pos[k] + v * dur / pw)
	var real_dur: float = clampf((float(to) - _pos[k]) * pw / v, dur * 0.7, dur * 1.6)
	_stop[k] = {"from": _pos[k], "to": float(to), "dur": real_dur, "t": 0.0, "pow": pw}
	if tease:
		AudioBus.play("slot_tease")
		_heart_t = 0.0


func _tick_tension(delta: float) -> void:
	if _tease < 0 or _done[_tease] or _stop[_tease].is_empty():
		return
	_heart_t -= delta
	if _heart_t <= 0.0:
		_heart_t = 0.55
		AudioBus.play("heartbeat", 1.0, -4.0)
		EventBus.juice_shake.emit(0.06)


## Accélère la fin du tirage — une seule fois par tirage : marteler la touche ne doit pas
## relancer le freinage à chaque appui (les rouleaux ne s'arrêteraient jamais).
func _hurry() -> void:
	if _hurried:
		return
	_hurried = true
	var reels: Array = _spins[_index]["reels"]
	for k: int in REELS:
		if _done[k]:
			continue
		if _stop[k].is_empty():
			_speed[k] = SPIN_SPEED
		var to: int = _cab.cell_for(k, String(reels[k]), _pos[k] + 1.0)
		_stop[k] = {"from": _pos[k], "to": float(to), "dur": HURRY_TIME + 0.1 * float(k), "t": 0.0, "pow": NORMAL_POW}


func _on_reel_stopped(k: int) -> void:
	AudioBus.play("slot_stop", 0.85 + 0.1 * float(k))
	Platform.haptic(HAPTIC_REEL_MS)
	EventBus.juice_shake.emit(0.18 if k != _tease else 0.4)
	_speed[k] = 0.0


func _resolve() -> void:
	_step = Step.RESULT
	_t = 0.0
	var pid: String = String(_spins[_index]["prize"])
	if pid == "":
		_banner.text = tr("SLOT_NOTHING")
		_banner.add_theme_color_override("font_color", Palette.SMOKE)
		AudioBus.play("lose_soft")
		return
	var prize: Dictionary = _db.get_entry("slot_prizes", pid)
	_won.append(prize)
	var match_kind: String = String(prize.get("match", ""))
	var big: bool = match_kind != "pair"
	_banner.text = Localization.t(prize, "name")
	_banner.add_theme_color_override("font_color", Palette.GOLD_LIGHT if big else Palette.EMERALD)
	_banner.scale = Vector2(0.4, 0.4)
	_banner.pivot_offset = Vector2(_banner.size.x * 0.5, 40.0)
	_banner.create_tween().tween_property(_banner, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_win = 1.0 if big else 0.6
	_cab.drop_coins(int(TRAY_COINS.get(match_kind, 5)), _rng)
	AudioBus.play("slot_big" if big else "slot_win")
	Platform.haptic(HAPTIC_JACKPOT_MS if big else HAPTIC_REEL_MS * 2)
	AudioBus.play("coins", 1.0, -4.0)
	if match_kind == "quad":
		AudioBus.play("choir", 1.0, -2.0)
	EventBus.juice_flash.emit(Palette.GOLD_LIGHT, 0.5 if big else 0.25)
	EventBus.juice_shake.emit(0.8 if big else 0.3)
	var at: Vector2 = _stage.project(Vector3(0, SlotCabinet3D.REEL_Y, 0.4))
	ChipBurst3D.spawn(self, at, COINS_BIG if big else COINS_SMALL, true)
	move_child(_banner, get_child_count() - 1)


func _show_summary() -> void:
	_step = Step.SUMMARY
	_t = 0.0
	_banner.text = ""
	_prompt.text = ""
	_info.text = ""
	_summary = UiKit.panel(Color(Palette.INK, 0.88), Palette.GOLD)
	_summary.custom_minimum_size = Vector2(720, 0)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_summary.add_child(v)
	var head_txt: String = tr("SLOT_SUMMARY") if not _won.is_empty() else tr("SLOT_SUMMARY_NONE")
	var head: Label = UiKit.label(head_txt, UiKit.SIZE_H2, Palette.GOLD_LIGHT, "display")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(head)
	for p: Dictionary in _won:
		var l: Label = UiKit.label("✦ " + Localization.t(p, "name"), UiKit.SIZE_BODY, Palette.IVORY)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var b: Button = UiKit.button(tr("SLOT_CONTINUE"), _close, Vector2(260, 52))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	PromptBadge.attach(b, "ui_accept")
	v.add_child(b)
	add_child(_summary)
	_place_summary.call_deferred()
	b.grab_focus.call_deferred()


## Bilan centré dans le bas de l'écran (sous la fenêtre des rouleaux), toujours dans l'écran.
func _place_summary() -> void:
	if _summary == null:
		return
	var vs: Vector2 = size if size.x > 0.0 else get_viewport_rect().size
	var w: float = minf(720.0, vs.x - 40.0)
	_summary.custom_minimum_size.x = w
	var sz: Vector2 = _summary.get_combined_minimum_size()
	_summary.size = sz
	_summary.position = Vector2((vs.x - sz.x) * 0.5, clampf(vs.y - sz.y - 30.0, 20.0, vs.y - sz.y - 10.0))


func _close() -> void:
	if _step == Step.INTRO:
		return
	_step = Step.INTRO
	set_process(false)
	AudioBus.ui("panel_close")
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(closed.emit)


# --------------------------------------------------------------------------- commandes


func _input(event: InputEvent) -> void:
	var go: bool = (
		GameInput.pressed(event, "ui_spin")
		or GameInput.pressed(event, "ui_accept")
		or GameInput.pressed(event, "bet_place")
		or GameInput.pressed(event, "skip_anim")
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	)
	if not go:
		return
	match _step:
		Step.WAIT_PULL:
			_pull()
		Step.SPINNING:
			if _t > 0.6:
				_hurry()
		Step.RESULT:
			_t = maxf(_t, RESULT_TIME - 0.35)
		Step.SUMMARY:
			if _t > 0.4:
				_close()
		_:
			return
	get_viewport().set_input_as_handled()
