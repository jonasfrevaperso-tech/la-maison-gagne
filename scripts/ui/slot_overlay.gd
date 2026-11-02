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
	_summary.position = Vector2(WINDOW.position.x, WINDOW.end.y + 70)
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
	m.draw_style_box(UiKit.flat(Color(0, 0, 0, 0), Palette.GOLD_DARK, 2, 22, 0), body.grow(-14))
	# Bandes chromées verticales.
	for x: float in [body.position.x + 40.0, body.end.x - 52.0]:
		m.draw_rect(Rect2(x, body.position.y + 40, 12, body.size.y - 80), Color(Palette.GOLD_LIGHT, 0.25))
	_draw_marquee(m)
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
		_text_center(m, f, fs, pull, Vector2(MACHINE.x * 0.5 - 30, WINDOW.end.y + 70), Color(Palette.GOLD_LIGHT, a))
	if _banner != "" and _step == Step.RESULT:
		var u: float = 1.0 - _banner_t / RESULT_TIME
		var pop: float = 1.0 + 0.3 * (1.0 - clampf(u * 5.0, 0.0, 1.0))
		var bfs: int = int(UiKit.fs(UiKit.SIZE_H2) * pop)
		_text_center(m, f, bfs, _banner, Vector2(MACHINE.x * 0.5 - 30, WINDOW.end.y + 80), _banner_col)


func _text_center(m: Control, f: Font, fs: int, txt: String, at: Vector2, col: Color) -> void:
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var maxw: float = WINDOW.size.x + 120.0
	if w > maxw:
		fs = int(float(fs) * maxw / w)
		w = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	m.draw_string_outline(f, at - Vector2(w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Palette.INK)
	m.draw_string(f, at - Vector2(w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
