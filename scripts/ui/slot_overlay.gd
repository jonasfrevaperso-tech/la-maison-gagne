class_name SlotOverlay
extends Control
## JACKPOT ! Un plein gagnant fait surgir la machine à sous du casino : 1 à 3 tirages selon le
## verdict du mini-jeu de lancer. Les combinaisons et leurs gains sont DÉJÀ résolus par le cœur
## (RunController → SlotMachine) ; cette surcouche les met en scène : levier, rouleaux qui
## s'arrêtent un par un (ralenti quand deux symboles s'alignent), ampoules qui défilent puis
## clignotent, pluie de pièces 3D, bannière de gain. Toute commande tire le levier / continue.

signal closed

enum Step { INTRO, WAIT_PULL, SPINNING, RESULT, SUMMARY }

const MACHINE: Vector2 = Vector2(880, 800)
const WINDOW: Rect2 = Rect2(150, 250, 520, 330)
const REEL_W: float = 150.0
const REEL_GAP: float = 35.0
const BULBS: int = 34
const CHASE_SPEED: float = 9.0
const INTRO_TIME: float = 0.9
const AUTO_PULL: float = 3.5
const RESULT_TIME: float = 1.9
const AUTO_CLOSE: float = 7.0
const STOP_TIMES: Array[float] = [0.9, 1.35, 1.8]
const TEASE_EXTRA: float = 0.6
const LEVER_TIME: float = 0.45
const COINS_TRIPLE: int = 110
const COINS_PAIR: int = 30
const RAYS: int = 18
const SPARKS_TRIPLE: int = 70
const SPARKS_PAIR: int = 24
const TRAY: Rect2 = Rect2(170, 612, 480, 44)
const TRAY_COINS_TRIPLE: int = 14
const TRAY_COINS_PAIR: int = 5
const TRAY_MAX: int = 60

var _spins: Array[Dictionary] = []
var _db: ContentDB = null
var _index: int = 0
var _step: Step = Step.INTRO
var _t: float = 0.0
var _chase: float = 0.0
var _strobe: float = 0.0
var _lever: float = 0.0
var _won: Array[Dictionary] = []
var _machine: Control = null
var _reels: Array[SlotReel] = []
var _banner: String = ""
var _banner_col: Color = Palette.GOLD_LIGHT
var _banner_t: float = 0.0
var _stopped: int = 0
var _spin_sound_t: float = 0.0
var _summary: VBoxContainer = null
## Étincelles du gain : position, vitesse, durée de vie restante (repère de la surcouche).
var _sparks: Array[Dictionary] = []
## Pièces tombées dans le bac : x relatif et hauteur de pile (repère de la machine).
var _tray: Array[Vector2] = []
var _falling: Array[Dictionary] = []
var _rays: float = 0.0
var _blink_t: float = 2.0
var _back: Control = null


func configure(spins: Array[Dictionary], db: ContentDB) -> SlotOverlay:
	_spins = spins
	_db = db
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.03, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_machine = Control.new()
	_machine.size = MACHINE
	_machine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_machine.draw.connect(_draw_machine)
	_back = Control.new()
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.draw.connect(_draw_backdrop)
	add_child(_back)
	add_child(_machine)
	var ids: Array[String] = []
	for s: Dictionary in _db.list("slot_symbols"):
		ids.append(String(s["id"]))
	for k: int in 3:
		var r: SlotReel = SlotReel.new()
		r.position = WINDOW.position + Vector2(25.0 + float(k) * (REEL_W + REEL_GAP), 0.0)
		r.size = Vector2(REEL_W, WINDOW.size.y)
		r.setup(ids)
		r.stopped.connect(_on_reel_stopped.bind(k))
		_machine.add_child(r)
		_reels.append(r)
	resized.connect(_fit)
	_fit()
	_machine.scale = Vector2(0.2, 0.2) * _fit_scale()
	_machine.modulate.a = 0.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_machine, "scale", Vector2.ONE * _fit_scale(), INTRO_TIME * 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_machine, "modulate:a", 1.0, INTRO_TIME * 0.4)
	AudioBus.play("jackpot", 1.0, 0.0)
	AudioBus.play("slot_ring", 1.0, -3.0)
	EventBus.juice_flash.emit(Palette.GOLD_LIGHT, 0.4)
	EventBus.juice_shake.emit(0.5)
	EventBus.subtitle.emit(tr("SUB_SLOT"))


func _fit_scale() -> float:
	var room: Vector2 = size * 0.94
	if room.x <= 0.0:
		room = get_viewport_rect().size * 0.94
	return minf(1.0, minf(room.x / MACHINE.x, room.y / MACHINE.y))


func _fit() -> void:
	var s: float = _fit_scale()
	if _step != Step.INTRO:
		_machine.scale = Vector2(s, s)
	var vs: Vector2 = size if size.x > 0.0 else get_viewport_rect().size
	_machine.position = (vs - MACHINE * s) * 0.5
	_machine.pivot_offset = Vector2.ZERO


# --------------------------------------------------------------------------- déroulé


func _process(delta: float) -> void:
	_t += delta
	_chase += delta * CHASE_SPEED * (3.0 if _step == Step.SPINNING else 1.0)
	_strobe = maxf(_strobe - delta, 0.0)
	_banner_t = maxf(_banner_t - delta, 0.0)
	_lever = maxf(_lever - delta / LEVER_TIME, 0.0)
	_rays = lerpf(_rays, 1.0 if _strobe > 0.0 else 0.25, clampf(delta * 3.0, 0.0, 1.0))
	_blink_t -= delta
	if _blink_t < -0.15:
		_blink_t = RngService.cosmetic().randf_range(1.5, 4.0)
	_update_particles(delta)
	match _step:
		Step.INTRO:
			if _t >= INTRO_TIME:
				_fit()
				_wait_pull()
		Step.WAIT_PULL:
			if _t >= AUTO_PULL:
				_pull()
		Step.SPINNING:
			_spin_sound_t -= delta
			if _spin_sound_t <= 0.0:
				_spin_sound_t = 1.0
				AudioBus.play("slot_spin", 1.0, -6.0)
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
	_machine.queue_redraw()
	_back.queue_redraw()


func _wait_pull() -> void:
	_step = Step.WAIT_PULL
	_t = 0.0


func _pull() -> void:
	if _step != Step.WAIT_PULL:
		return
	_step = Step.SPINNING
	_t = 0.0
	_lever = 1.0
	_stopped = 0
	_banner = ""
	AudioBus.play("slot_lever")
	var reels: Array = _spins[_index]["reels"]
	var tease: bool = String(reels[0]) == String(reels[1])
	for k: int in 3:
		var after: float = STOP_TIMES[k] + (TEASE_EXTRA if tease and k == 2 else 0.0)
		_reels[k].spin(String(reels[k]), after, tease and k == 2)
	_spin_sound_t = 0.0


func _on_reel_stopped(k: int) -> void:
	_stopped += 1
	AudioBus.play("slot_stop", 0.9 + 0.1 * float(k))
	EventBus.juice_shake.emit(0.15)
	var reels: Array = _spins[_index]["reels"]
	if k == 1 and String(reels[0]) == String(reels[1]):
		AudioBus.play("slot_tease")
	if _stopped >= 3:
		_resolve()


func _resolve() -> void:
	_step = Step.RESULT
	_t = 0.0
	var pid: String = String(_spins[_index]["prize"])
	var at: Vector2 = _machine.get_global_transform() * (WINDOW.get_center())
	if pid == "":
		_banner = tr("SLOT_NOTHING")
		_banner_col = Palette.SMOKE
		AudioBus.play("lose_soft")
	else:
		var prize: Dictionary = _db.get_entry("slot_prizes", pid)
		_won.append(prize)
		_banner = Localization.t(prize, "name")
		var triple: bool = String(prize.get("match", "")) == "triple"
		_banner_col = Palette.GOLD_LIGHT if triple else Palette.EMERALD
		_strobe = 2.0 if triple else 0.9
		for r: SlotReel in _reels:
			r.flash()
		AudioBus.play("slot_big" if triple else "slot_win")
		AudioBus.play("coins", 1.0, -4.0)
		EventBus.juice_flash.emit(Palette.GOLD_LIGHT, 0.5 if triple else 0.25)
		EventBus.juice_shake.emit(0.8 if triple else 0.3)
		ChipBurst3D.spawn(self, get_global_transform().affine_inverse() * at, COINS_TRIPLE if triple else COINS_PAIR, true)
	_banner_t = RESULT_TIME


func _show_summary() -> void:
	_step = Step.SUMMARY
	_t = 0.0
	_summary = VBoxContainer.new()
	_summary.add_theme_constant_override("separation", 6)
	_summary.position = Vector2(WINDOW.position.x, WINDOW.end.y + 84)
	_summary.custom_minimum_size = Vector2(WINDOW.size.x + 50, 0)
	_machine.add_child(_summary)
	var head_txt: String = tr("SLOT_SUMMARY") if not _won.is_empty() else tr("SLOT_SUMMARY_NONE")
	var head: Label = UiKit.label(head_txt, UiKit.SIZE_BODY + 4, Palette.GOLD_LIGHT, "display")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.add_child(head)
	for p: Dictionary in _won:
		var l: Label = UiKit.label("✦ " + Localization.t(p, "name"), UiKit.SIZE_BODY, Palette.IVORY)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_summary.add_child(l)
	var b: Button = UiKit.button(tr("SLOT_CONTINUE"), _close, Vector2(260, 52))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	PromptBadge.attach(b, "ui_accept")
	_summary.add_child(b)
	b.grab_focus.call_deferred()


func _close() -> void:
	if _step == Step.INTRO:
		return
	_step = Step.INTRO
	set_process(false)
	AudioBus.ui("panel_close")
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_machine, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(closed.emit)


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
			for r: SlotReel in _reels:
				r.hurry()
		Step.RESULT:
			_t = maxf(_t, RESULT_TIME - 0.35)
		Step.SUMMARY:
			if _t > 0.4:
				_close()
		_:
			return
	get_viewport().set_input_as_handled()


# --------------------------------------------------------------------------- dessin


func _draw_machine() -> void:
	var m: Control = _machine
	var body: Rect2 = Rect2(70, 150, 680, 620)
	m.draw_rect(Rect2(body.position + Vector2(14, 18), body.size), Color(0, 0, 0, 0.5))
	m.draw_style_box(UiKit.flat(Color("5a0e1e"), Palette.GOLD, 6, 28, 0), body)
	# Laque en dégradé (bandes horizontales) et reflet chromé.
	for k: int in 12:
		var bh: float = (body.size.y - 16) / 12.0
		var band: Rect2 = Rect2(body.position.x + 8, body.position.y + 8 + k * bh, body.size.x - 16, bh)
		m.draw_rect(band, Color("7a1428").darkened(float(k) / 16.0))
	m.draw_style_box(UiKit.flat(Color(0, 0, 0, 0), Palette.GOLD_DARK, 2, 22, 0), body.grow(-14))
	# Colonnes lumineuses : chenillard vertical de chaque côté.
	for side: int in 2:
		var x: float = body.position.x + 30.0 if side == 0 else body.end.x - 42.0
		m.draw_rect(Rect2(x, body.position.y + 40, 12, body.size.y - 80), Color(Palette.GOLD_LIGHT, 0.18))
		for j: int in 11:
			var y: float = body.position.y + 60 + j * (body.size.y - 120) / 10.0
			var chase: bool = posmod(j + int(_chase * (1.0 if side == 0 else -1.0)), 4) == 0
			var on: bool = chase or (_strobe > 0.0 and int(_t * 12.0) % 2 == j % 2)
			m.draw_circle(Vector2(x + 6, y), 6.0, Palette.MAGENTA if on else Color("3a1020"))
			if on:
				m.draw_circle(Vector2(x + 6, y), 12.0, Color(Palette.MAGENTA, 0.25))
	# Rivets dorés.
	var rivets: Array[Vector2] = [
		body.position + Vector2(22, 22),
		Vector2(body.end.x - 22, body.position.y + 22),
		body.end - Vector2(22, 22),
		Vector2(body.position.x + 22, body.end.y - 22),
	]
	for c: Vector2 in rivets:
		m.draw_circle(c, 7.0, Palette.GOLD)
		m.draw_circle(c + Vector2(-2, -2), 2.5, Palette.GOLD_LIGHT)
	_draw_marquee(m)
	_draw_face(m)
	if _step != Step.SUMMARY:
		_draw_tray(m)
	# Fenêtre des rouleaux et ligne de paiement.
	m.draw_rect(WINDOW.grow(18), Palette.INK)
	m.draw_rect(WINDOW.grow(18), Palette.GOLD, false, 4.0)
	m.draw_rect(WINDOW.grow(10), Palette.GOLD_DARK, false, 2.0)
	var mid: float = WINDOW.get_center().y
	var line_col: Color = Palette.MAGENTA.lerp(Palette.GOLD_LIGHT, clampf(_strobe, 0.0, 1.0))
	m.draw_line(Vector2(WINDOW.position.x - 30, mid), Vector2(WINDOW.position.x - 6, mid), line_col, 6.0)
	m.draw_line(Vector2(WINDOW.end.x + 6, mid), Vector2(WINDOW.end.x + 30, mid), line_col, 6.0)
	var wx: float = WINDOW.position.x
	m.draw_colored_polygon(PackedVector2Array([Vector2(wx - 4, mid), Vector2(wx - 22, mid - 14), Vector2(wx - 22, mid + 14)]), line_col)
	if _strobe > 0.0:
		var glow: float = clampf(_strobe, 0.0, 1.0) * (0.6 + 0.4 * sin(_t * 18.0))
		m.draw_rect(Rect2(WINDOW.position.x, mid - 6, WINDOW.size.x, 12), Color(Palette.GOLD_LIGHT, 0.35 * glow))
		m.draw_rect(WINDOW.grow(18), Color(Palette.GOLD_LIGHT, glow), false, 6.0)
	_draw_lever(m)
	_draw_texts(m)


func _draw_marquee(m: Control) -> void:
	var r: Rect2 = Rect2(40, 14, 740, 172)
	m.draw_style_box(UiKit.flat(Palette.INK, Palette.GOLD, 5, 60, 0), r)
	var f: Font = UiKit.font("display")
	var fs: int = UiKit.fs(UiKit.SIZE_TITLE)
	var txt: String = tr("SLOT_TITLE")
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pulse: float = 0.5 + 0.5 * sin(_t * 8.0)
	var col: Color = Palette.GOLD_LIGHT.lerp(Palette.MAGENTA, pulse * 0.5 if _strobe > 0.0 else 0.0)
	var pos: Vector2 = Vector2(r.get_center().x - w * 0.5, r.get_center().y + fs * 0.33)
	m.draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, Palette.MAGENTA.darkened(0.4))
	m.draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	# Ampoules du pourtour : chenillard, puis stroboscope sur un gain.
	var per: float = (r.size.x + r.size.y) * 2.0
	for i: int in BULBS:
		var d: float = per * float(i) / float(BULBS)
		var p: Vector2 = _perimeter(r.grow(-14), d)
		var lit: bool = (i + int(_chase)) % 3 == 0
		if _strobe > 0.0:
			lit = int(_t * 14.0) % 2 == i % 2
		m.draw_circle(p, 9.0, Color("3a2a10"))
		if lit:
			m.draw_circle(p, 14.0, Color(Palette.GOLD_LIGHT, 0.25))
			m.draw_circle(p, 8.0, Palette.GOLD_LIGHT)


## Lucette en personne : deux yeux au-dessus des rouleaux, qui clignent, suivent les rouleaux
## et deviennent des cœurs sur un gain.
func _draw_face(m: Control) -> void:
	var cy: float = WINDOW.position.y - 52.0
	var happy: bool = _strobe > 0.0
	var look: float = sin(_t * 14.0) * 8.0 if _step == Step.SPINNING else 0.0
	for k: int in 2:
		var c: Vector2 = Vector2(MACHINE.x * 0.5 - 30 + (-170.0 if k == 0 else 170.0), cy)
		# Orbite sombre et cerclage doré : les yeux de Lucette se lisent de loin.
		m.draw_circle(c, 27.0, Palette.GOLD_DARK)
		m.draw_circle(c, 24.0, Palette.INK)
		if happy:
			var hc: Color = Palette.MAGENTA.lightened(0.2)
			m.draw_circle(c + Vector2(-8, -5), 10.0, hc)
			m.draw_circle(c + Vector2(8, -5), 10.0, hc)
			m.draw_colored_polygon(PackedVector2Array([c + Vector2(-17, -2), c + Vector2(17, -2), c + Vector2(0, 17)]), hc)
		elif _blink_t < 0.0:
			m.draw_line(c - Vector2(17, 0), c + Vector2(17, 0), Palette.GOLD_LIGHT, 4.0)
		else:
			m.draw_circle(c, 19.0, Palette.IVORY)
			m.draw_circle(c + Vector2(look, 2), 10.0, Palette.INK)
			m.draw_circle(c + Vector2(look - 3, -2), 3.0, Palette.IVORY)
		# Cils de diva.
		for j: int in 3:
			var a0: float = -PI * 0.5 + (float(j) - 1.0) * 0.45 + (-0.25 if k == 0 else 0.25)
			m.draw_line(c + Vector2(cos(a0), sin(a0)) * 26.0, c + Vector2(cos(a0), sin(a0)) * 36.0, Palette.GOLD_LIGHT, 3.0)


## Bac à pièces : chaque gain y fait tomber des pièces qui s'empilent.
func _draw_tray(m: Control) -> void:
	m.draw_rect(TRAY.grow(6), Palette.GOLD_DARK)
	m.draw_rect(TRAY, Color("1a0a10"))
	m.draw_rect(Rect2(TRAY.position, Vector2(TRAY.size.x, 6)), Color(Palette.GOLD_LIGHT, 0.4))
	for c: Vector2 in _tray:
		var p: Vector2 = Vector2(TRAY.position.x + c.x, TRAY.end.y - 8.0 - c.y)
		m.draw_rect(Rect2(p - Vector2(13, 5), Vector2(26, 10)), Palette.GOLD_DARK)
		m.draw_rect(Rect2(p - Vector2(13, 7), Vector2(26, 6)), Palette.GOLD_LIGHT)
	for f: Dictionary in _falling:
		var fp: Vector2 = f["p"]
		m.draw_circle(fp, 10.0, Palette.GOLD)
		m.draw_circle(fp + Vector2(-3, -3), 3.0, Palette.GOLD_LIGHT)


func _drop_coins(n: int) -> void:
	var rng: RandomNumberGenerator = RngService.cosmetic()
	for i: int in n:
		var start: Vector2 = Vector2(rng.randf_range(TRAY.position.x + 20, TRAY.end.x - 20), WINDOW.end.y - 10.0 - float(i) * 14.0)
		_falling.append({"p": start, "v": rng.randf_range(0.0, 80.0)})


func _burst(at: Vector2, n: int) -> void:
	var rng: RandomNumberGenerator = RngService.cosmetic()
	for i: int in n:
		var a: float = rng.randf() * TAU
		var sp: float = rng.randf_range(200.0, 900.0)
		var col: Color = [Palette.GOLD_LIGHT, Palette.MAGENTA, Palette.CYAN, Palette.IVORY][i % 4]
		_sparks.append({"p": at, "v": Vector2(cos(a), sin(a)) * sp, "l": rng.randf_range(0.5, 1.3), "c": col})


func _update_particles(delta: float) -> void:
	for sp: Dictionary in _sparks:
		sp["v"] = (sp["v"] as Vector2) * (1.0 - delta * 1.5) + Vector2(0, 700.0 * delta)
		sp["p"] = (sp["p"] as Vector2) + (sp["v"] as Vector2) * delta
		sp["l"] = float(sp["l"]) - delta
	_sparks = _sparks.filter(func(q: Dictionary) -> bool: return float(q["l"]) > 0.0)
	var landed: Array[Dictionary] = []
	for f: Dictionary in _falling:
		f["v"] = float(f["v"]) + 1600.0 * delta
		var fp: Vector2 = f["p"]
		fp.y += float(f["v"]) * delta
		f["p"] = fp
		if fp.y >= TRAY.end.y - 10.0:
			landed.append(f)
	for f2: Dictionary in landed:
		_falling.erase(f2)
		if _tray.size() < TRAY_MAX:
			var x: float = (f2["p"] as Vector2).x - TRAY.position.x
			var h: float = 0.0
			for c: Vector2 in _tray:
				if absf(c.x - x) < 22.0:
					h = maxf(h, c.y + 7.0)
			_tray.append(Vector2(x, minf(h, TRAY.size.y - 12.0)))
		AudioBus.play("coin", RngService.cosmetic().randf_range(0.9, 1.3), -10.0)


## Arrière-plan plein écran : rayons de lumière qui tournent derrière la machine, étincelles.
func _draw_backdrop() -> void:
	var c: Vector2 = _machine.position + MACHINE * _machine.scale * 0.5
	var r: float = size.length()
	for i: int in RAYS:
		var a0: float = _t * 0.35 + TAU * float(i) / float(RAYS)
		var a1: float = a0 + TAU / float(RAYS) * 0.45
		var col: Color = Color(Palette.GOLD_LIGHT if i % 2 == 0 else Palette.MAGENTA, 0.06 + 0.12 * _rays)
		_back.draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * r, c + Vector2(cos(a1), sin(a1)) * r]), col)
	for sp: Dictionary in _sparks:
		var p: Vector2 = sp["p"]
		var l: float = clampf(float(sp["l"]), 0.0, 1.0)
		var col2: Color = sp["c"]
		_back.draw_rect(Rect2(p - Vector2(4, 4) * l, Vector2(8, 8) * l), Color(col2, l))


func _perimeter(r: Rect2, d: float) -> Vector2:
	var w: float = r.size.x
	var h: float = r.size.y
	d = fposmod(d, (w + h) * 2.0)
	if d < w:
		return r.position + Vector2(d, 0)
	if d < w + h:
		return r.position + Vector2(w, d - w)
	if d < w * 2.0 + h:
		return r.position + Vector2(w - (d - w - h), h)
	return r.position + Vector2(0, h - (d - w * 2.0 - h))


func _draw_lever(m: Control) -> void:
	var base: Vector2 = Vector2(770, 420)
	m.draw_rect(Rect2(base - Vector2(10, 40), Vector2(40, 80)), Palette.GOLD_DARK)
	var pull: float = sin(_lever * PI)
	var top: Vector2 = base + Vector2(40, -170 + 260 * pull)
	m.draw_line(base + Vector2(30, 0), top, Palette.GOLD_LIGHT, 10.0)
	m.draw_circle(top, 26.0, Color("b81d3a"))
	m.draw_circle(top + Vector2(-8, -8), 8.0, Color(1, 1, 1, 0.5))


func _draw_texts(m: Control) -> void:
	var f: Font = UiKit.font("display")
	var fs: int = UiKit.fs(UiKit.SIZE_BODY)
	var info: String = tr("SLOT_SPIN_COUNT") % [mini(_index + 1, _spins.size()), _spins.size()]
	_text_center(m, f, fs, info, Vector2(MACHINE.x * 0.5 - 30, WINDOW.position.y - 34), Palette.IVORY)
	if _step == Step.WAIT_PULL:
		var a: float = 0.55 + 0.45 * sin(_t * 6.0)
		var pull: String = tr("SLOT_PULL") % InputGlyphs.plain("ui_spin")
		_text_center(m, f, fs, pull, Vector2(MACHINE.x * 0.5 - 30, TRAY.end.y + 52), Color(Palette.GOLD_LIGHT, a))
	if _banner != "" and _step == Step.RESULT:
		var u: float = 1.0 - _banner_t / RESULT_TIME
		var pop: float = 1.0 + 0.3 * (1.0 - clampf(u * 5.0, 0.0, 1.0))
		var bfs: int = int(UiKit.fs(UiKit.SIZE_H2) * pop)
		_text_center(m, f, bfs, _banner, Vector2(MACHINE.x * 0.5 - 30, TRAY.end.y + 60), _banner_col)


func _text_center(m: Control, f: Font, fs: int, txt: String, at: Vector2, col: Color) -> void:
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var maxw: float = WINDOW.size.x + 120.0
	if w > maxw:
		fs = int(float(fs) * maxw / w)
		w = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	m.draw_string_outline(f, at - Vector2(w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Palette.INK)
	m.draw_string(f, at - Vector2(w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
