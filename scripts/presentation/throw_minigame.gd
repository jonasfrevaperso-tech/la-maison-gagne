class_name ThrowMinigame
extends Control
## Mini-jeu du lancer v3, après la visée (la case est figée) :
## deux ÉPREUVES tirées au hasard parmi neuf (ThrowTrial : cadre sous la roue ou écran dédié),
## chacune annoncée par un carton, puis le LÂCHER : l'anneau se referme sur la bille en
## accélérant, frapper au contact. Qualité = ThrowSkill.quality(épreuves, lâcher).
## Ce nœud enchaîne les étapes, lit les commandes et dessine l'anneau et le verdict.
## Temps réel : la vitesse de jeu ne fausse jamais le geste.

signal finished(quality: float)

enum Beat { IDLE, TRIAL, PAUSE, RELEASE, DONE }

const RING_START: float = 200.0
const BALL_R: float = 16.0
const GRADE_TIME: float = 1.8
## Cadre des épreuves « panel » : par-dessus le tapis (inutile pendant le lancer), la roue reste
## entièrement visible. Coordonnées de maquette (calque `full_host`).
const PANEL_RECT: Rect2 = Rect2(830.0, 330.0, 1060.0, 400.0)
## Téléphone, épreuve aux boutons : le cadre glisse à gauche pour laisser le pavé sous le pouce.
const PANEL_SHIFT_TOUCH_PAD: float = 560.0
## Téléphone : marge autour d'une épreuve agrandie, et agrandissement maximal.
const MOBILE_MARGIN: float = 30.0
const MOBILE_MAX_SCALE: float = 2.2
## Bandeau des étapes dessiné au-dessus d'une épreuve « panel » (px de maquette, avant agrandissement).
const PANEL_STEPS_H: float = 36.0
## Le fond et le décor 3D débordent largement de la scène : les bords de l'écran 20:9 hors
## scène (poinçon, coins) restent couverts.
const MOBILE_EDGE_BLEED: float = 320.0
## Repli sans calque (tests) : sous la roue, coordonnées locales.
const PANEL_H: float = 300.0
const PANEL_BELOW: float = 40.0
const PANEL_INSET: float = 6.0
const CONFIRM_ACTIONS: Array[StringName] = [&"ui_spin", &"bet_place", &"ui_accept"]
const TRIAL_SCRIPTS: String = "res://scripts/presentation/trials/trial_%s.gd"

var beat: Beat = Beat.IDLE
## Point de lâcher (local), là où la bille quitte la main.
var release_point: Vector2 = Vector2.ZERO
var hold: Callable = Callable()
## Calque plein écran (coordonnées de maquette) qui accueille les épreuves à écran dédié.
var full_host: Control = null
var trial_ids: Array[String] = []
var trial_scores: Array[float] = []
var release_score: float = 0.0
var quality: float = 0.0
var trial: ThrowTrial = null
var _index: int = 0
var _precision: int = 1
var _assist: bool = false
var _mouse: bool = false
var _t: float = 0.0
var _release_time: float = 1.0
## Téléphone : fond plein écran posé sous l'épreuve (toutes les épreuves y sont plein écran).
var _backdrop: Control = null
var _grade: ThrowSkill.Grade = ThrowSkill.Grade.MISS
var _grade_t: float = 0.0
var _control_delta: float = 0.0
var _pause_grade: ThrowSkill.Grade = ThrowSkill.Grade.MISS
var _last_ids: Array[String] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func start(precision: int, assist: bool, count: int = -1) -> void:
	_precision = precision
	_assist = assist
	_mouse = (GameInput.last_was_mouse or InputGlyphs.using_touch) and not InputGlyphs.using_pad
	_release_time = Balance.f("throw_game.release_seconds") * (Balance.f("throw_game.assist_slowdown") if assist else 1.0)
	var n: int = count if count > 0 else ThrowTrials.count_for(Settings.s("game", "throw_mode"))
	# Évite les épreuves des deux derniers lancers : plus de variété d'un lancer à l'autre.
	trial_ids = ThrowTrials.pick(DataRegistry.db, RngService.cosmetic(), n, _last_ids)
	_last_ids.append_array(trial_ids)
	while _last_ids.size() > n * Balance.i("throw_game.trial_memory_throws"):
		_last_ids.pop_front()
	trial_scores.clear()
	release_score = 0.0
	_grade_t = 0.0
	_index = 0
	AudioBus.play("whoosh", 1.2, -6.0)
	_open_trial()


## Force les épreuves (tests, outil de capture).
func start_with(ids: Array[String], precision: int, assist: bool) -> void:
	start(precision, assist, ids.size())
	_close_trial()
	trial_ids = ids
	_index = 0
	_open_trial()


func active() -> bool:
	return beat in [Beat.TRIAL, Beat.PAUSE, Beat.RELEASE]


func steps() -> Array[String]:
	var out: Array[String] = []
	for id: String in trial_ids:
		out.append(Localization.name_of("throw_trials", id))
	out.append(tr("THROW_BEAT_RELEASE"))
	return out


func _open_trial() -> void:
	var id: String = trial_ids[_index]
	HitchMonitor.mark("épreuve " + id)
	var scr: GDScript = load(TRIAL_SCRIPTS % id) as GDScript
	var e: Dictionary = DataRegistry.db.get_entry("throw_trials", id)
	SaveSystem.mark_seen("trials", id)  # le Codex montre les épreuves déjà jouées
	# Au doigt, une épreuve à symboles se joue comme à la manette, avec le pavé de boutons.
	var pad: Array[String] = []
	var stick: bool = InputGlyphs.using_touch and bool(e.get("touch_stick", false))
	var pad_layout: String = String(e.get("touch_layout", ""))
	if InputGlyphs.using_touch:
		for a: Variant in e.get("touch_pad", []):
			pad.append(String(a))
	trial = (scr.new() as ThrowTrial).setup(e, _precision, _assist, _mouse and pad.is_empty() and not stick)
	trial.touch_controls = not pad.is_empty() or stick
	if not pad.is_empty():
		trial.add_child(TouchPad.new().configure(pad, pad_layout, e.get("touch_labels", {}) as Dictionary))
	if stick:
		trial.add_child(TouchStick.new())
	trial.hold = hold
	trial.steps = steps()
	trial.step = _index
	trial.done.connect(_on_trial_done)
	if full_host != null and Platform.is_mobile():
		_place_mobile(pad, pad_layout, stick)
	elif full_host != null:
		var r: Rect2 = Rect2(Vector2.ZERO, UiLayout.DESIGN_SIZE) if trial.full() else PANEL_RECT
		# (gaucher : le pavé est à gauche, le cadre peut rester sur le tapis)
		if not pad.is_empty() and not trial.full() and not Settings.b("game", "left_handed"):
			r.position.x -= PANEL_SHIFT_TOUCH_PAD
		trial.position = r.position
		trial.size = r.size
		full_host.add_child(trial)
	else:
		trial.position = Vector2(PANEL_INSET, size.y + PANEL_BELOW - PANEL_H)
		trial.size = Vector2(size.x - PANEL_INSET * 2.0, PANEL_H)
		add_child(trial)
	beat = Beat.TRIAL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_t = 0.0


func _close_trial() -> void:
	if trial != null:
		trial.queue_free()
		trial = null
	if _backdrop != null:
		_backdrop.queue_free()
		_backdrop = null


## Téléphone : l'épreuve occupe tout l'écran. Fond plein écran (le plateau dort dessous) ;
## épreuve « full » à sa taille de maquette, son décor 3D élargi aux bords ; épreuve « panel »
## agrandie au maximum à côté des commandes tactiles (joystick, pavé) ou au-dessus d'elles.
func _place_mobile(pad: Array[String], pad_layout: String, stick: bool) -> void:
	var host_parent: Control = full_host.get_parent() as Control
	var area: Rect2 = Rect2(Vector2(-full_host.position.x, 0.0), host_parent.size if host_parent != null else UiLayout.DESIGN_SIZE)
	_backdrop = Control.new()
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP  # le doigt hors de l'épreuve n'atteint pas le tapis
	_backdrop.position = area.position - Vector2(MOBILE_EDGE_BLEED, MOBILE_EDGE_BLEED)
	_backdrop.size = area.size + Vector2.ONE * MOBILE_EDGE_BLEED * 2.0
	var deco: DecoBackground = DecoBackground.new()
	deco.origin_ratio = Vector2(0.5, 0.5)
	_backdrop.add_child(deco)
	RenderQuality.cover(true)
	_backdrop.tree_exiting.connect(RenderQuality.cover.bind(false))
	full_host.add_child(_backdrop)
	if trial.full():
		trial.position = Vector2.ZERO
		trial.size = UiLayout.DESIGN_SIZE
		trial.bleed_x = full_host.position.x + MOBILE_EDGE_BLEED
		full_host.add_child(trial)
		return
	trial.size = PANEL_RECT.size
	trial.scale = Vector2.ONE * _mobile_fit(area, pad, pad_layout, stick)
	full_host.add_child(trial)


## Échelle et position d'une épreuve « panel » : meilleure de deux dispositions (commandes à
## côté, ou bande de commandes en bas).
func _mobile_fit(area: Rect2, pad: Array[String], pad_layout: String, stick: bool) -> float:
	var m: float = MOBILE_MARGIN
	var pad_box: Vector2 = TouchPad.box_size(pad, pad_layout) if not pad.is_empty() else Vector2.ZERO
	var stick_box: Vector2 = TouchStick.box_size() if stick else Vector2.ZERO
	var split: bool = pad_layout == "split"
	var left_hand: bool = Settings.b("game", "left_handed")
	# Côté : le pavé d'un côté (pouce droit), le joystick de l'autre.
	var side_l: float = stick_box.x if not left_hand else (pad_box.x if not split else 0.0)
	var side_r: float = (pad_box.x if not split else 0.0) if not left_hand else stick_box.x
	var side: Rect2 = Rect2(area.position + Vector2(side_l + m, m), area.size - Vector2(side_l + side_r + m * 2.0, m * 2.0))
	if split:
		side.size.x = 0.0
	var band_h: float = maxf(pad_box.y, stick_box.y)
	var band: Rect2 = Rect2(area.position + Vector2(m, m), area.size - Vector2(m * 2.0, band_h + m * 2.0))
	var best: Rect2 = side if _fit(side) >= _fit(band) else band
	# Le bandeau des étapes dépasse au-dessus du cadre : place réservée en haut.
	best.position.y += PANEL_STEPS_H * _fit(best)
	best.size.y -= PANEL_STEPS_H * _fit(best)
	var k: float = _fit(best)
	trial.position = best.position + (best.size - PANEL_RECT.size * k) * 0.5
	return k


func _fit(r: Rect2) -> float:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return 0.0
	return minf(minf(r.size.x / PANEL_RECT.size.x, r.size.y / PANEL_RECT.size.y), MOBILE_MAX_SCALE)


func _on_trial_done(sc: float) -> void:
	trial_scores.append(sc)
	_pause_grade = ThrowSkill.beat_grade(sc)
	if trial != null:
		trial.show_verdict(_pause_grade)
	beat = Beat.PAUSE
	_t = 0.0
	match _pause_grade:
		ThrowSkill.Grade.PERFECT:
			AudioBus.play("jackpot", 1.3, -8.0)
		ThrowSkill.Grade.GREAT, ThrowSkill.Grade.GOOD:
			AudioBus.play("chime", 0.9 + sc * 0.3, -4.0)
		_:
			AudioBus.play("lose_soft", 1.0, -4.0)


func _after_pause() -> void:
	_close_trial()
	_index += 1
	if _index < trial_ids.size():
		_open_trial()
		return
	beat = Beat.RELEASE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_t = 0.0


# --------------------------------------------------------------------------- commandes


func _held() -> bool:
	return hold.is_valid() and bool(hold.call())


## Lit une commande (clavier, manette, souris) ; vrai si elle est consommée.
func handle(event: InputEvent) -> bool:
	if not active() or _held():
		return active()
	match beat:
		Beat.TRIAL:
			if trial != null and trial.feed(event):
				return true
		Beat.RELEASE:
			if _is_confirm(event):
				strike()
				return true
	# Pendant le mini-jeu, les autres commandes de jeu sont ignorées (pas de menu par erreur).
	return not event.is_action_pressed("pause_menu")


func _is_confirm(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	for a: StringName in CONFIRM_ACTIONS:
		if GameInput.pressed(event, a):
			return true
	return false


## Bouton à l'écran : fait avancer le carton d'annonce ou frappe le lâcher.
func press() -> void:
	if beat == Beat.RELEASE:
		strike()
	elif beat == Beat.TRIAL and trial != null and trial.in_intro():
		trial.act({"do": "confirm"})


func strike() -> void:
	if beat != Beat.RELEASE:
		return
	_finish_release(_t - _release_time)


func _finish_release(error_s: float) -> void:
	release_score = ThrowSkill.release_score(error_s, _assist)
	quality = ThrowSkill.quality(trial_scores, release_score)
	_grade = ThrowSkill.grade(quality)
	_control_delta = ThrowSkill.control_bonus(quality)
	_grade_t = GRADE_TIME
	beat = Beat.DONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	AudioBus.play("click" if release_score < 0.7 else "chip_place", 0.8 + release_score * 0.6)
	match _grade:
		ThrowSkill.Grade.PERFECT:
			AudioBus.play("jackpot", 1.2, -4.0)
			EventBus.juice_flash.emit(Palette.GOLD_LIGHT, 0.35)
			EventBus.juice_shake.emit(0.4)
		ThrowSkill.Grade.GREAT:
			AudioBus.play("chime", 1.1)
		ThrowSkill.Grade.GOOD:
			AudioBus.play("chime", 0.85, -4.0)
		_:
			AudioBus.play("lose_soft", 1.0, -4.0)
	finished.emit(quality)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and active() and handle(event):
		accept_event()


# --------------------------------------------------------------------------- bots (tests)


## Geste idéal du moment ({"do": "confirm"|"hold"|"release"|"sym"|"dir"|"axis"|""}), cf. ThrowTrial.
func bot_wants() -> Dictionary:
	match beat:
		Beat.TRIAL:
			if trial != null and not _held():
				return trial.want()
		Beat.RELEASE:
			if _t >= _release_time - 0.01:
				return {"do": "confirm"}
	return {"do": ""}


func bot_apply(want: Dictionary) -> void:
	match beat:
		Beat.TRIAL:
			if trial != null:
				trial.act(want)
		Beat.RELEASE:
			if String(want.get("do", "")) == "confirm":
				strike()


# --------------------------------------------------------------------------- temps


func _process(delta: float) -> void:
	if beat == Beat.IDLE:
		return
	if active() and _held():
		return
	var dt: float = delta / maxf(Engine.time_scale, 0.0001)
	_t += dt
	match beat:
		Beat.PAUSE:
			if _t >= Balance.f("throw_game.trial_pause_seconds"):
				_after_pause()
		Beat.RELEASE:
			if _t > _release_time + ThrowSkill.tap_window(_assist):
				_finish_release(ThrowSkill.tap_window(_assist) * 2.0)  # trop tard : lâcher raté
		Beat.DONE:
			_grade_t -= dt
			if _grade_t <= 0.0:
				beat = Beat.IDLE
	queue_redraw()


# --------------------------------------------------------------------------- dessin


func _draw() -> void:
	match beat:
		Beat.RELEASE:
			_draw_release_hint()
			_draw_ring()
		Beat.DONE:
			_draw_grade()


func _text(at: Vector2, txt: String, sz: int, col: Color, outline: int = 8) -> void:
	var f: Font = UiKit.font("display")
	var fs: int = UiKit.fs(sz)
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos: Vector2 = Vector2(at.x - w * 0.5, at.y + fs * 0.35)
	draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, Color(Palette.INK, col.a))
	draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _charge_name() -> String:
	if _mouse:
		return tr("THROW_CLICK")
	return InputGlyphs.plain("ui_spin")


func _draw_release_hint() -> void:
	var r: Rect2 = Rect2(Vector2(PANEL_INSET, size.y + PANEL_BELOW - 70.0), Vector2(size.x - PANEL_INSET * 2.0, 60.0))
	draw_rect(r, Color(Palette.INK, 0.9))
	draw_rect(r, Palette.GOLD, false, 2.0)
	var st: Array[String] = steps()
	_text(Vector2(r.get_center().x, r.position.y - 16.0), "%d · %s" % [st.size(), st[-1]], UiKit.SIZE_SMALL, Palette.GOLD_LIGHT, 6)
	_text(r.get_center(), tr("THROW_STRIKE_ON_CONTACT") % _charge_name(), UiKit.SIZE_BODY - 2, Palette.IVORY, 6)


func _draw_ring() -> void:
	var u: float = ThrowSkill.ring_progress(_t, _release_time)
	var rad: float = lerpf(BALL_R, RING_START, u)
	if _t > _release_time:
		rad = BALL_R * maxf(1.0 - (_t - _release_time) * 4.0, 0.0)
	var close: float = 1.0 - clampf(absf(_t - _release_time) / maxf(ThrowSkill.tap_window(_assist), 0.001), 0.0, 1.0)
	var col: Color = Palette.CYAN.lerp(Palette.GOLD_LIGHT, close)
	draw_circle(release_point, BALL_R + 10.0, Color(Palette.INK, 0.6))
	draw_arc(release_point, BALL_R + 2.0, 0.0, TAU, 32, Palette.GOLD_DARK, 2.0, true)
	draw_circle(release_point, BALL_R * 0.7, Palette.IVORY)
	if rad > 1.0:
		draw_arc(release_point, rad, 0.0, TAU, 48, col, 4.0 + 4.0 * close, true)
		draw_arc(release_point, rad + 9.0, 0.0, TAU, 48, Color(col, 0.25), 2.0, true)


func _draw_grade() -> void:
	var u: float = 1.0 - _grade_t / GRADE_TIME
	var txt: String = tr(ThrowSkill.grade_key(_grade))
	var pop: float = 1.0 + 0.25 * (1.0 - clampf(u * 4.0, 0.0, 1.0))
	var col: Color = ThrowTrial.GRADE_COLORS[int(_grade)]
	col.a = clampf((1.0 - u) * 2.0, 0.0, 1.0)
	var pt: Vector2 = release_point + Vector2(0, 70 - 30 * u)
	_text(pt, txt, int(UiKit.SIZE_H1 * pop), col)
	# Une pastille par étape : note de chaque épreuve puis du lâcher.
	var scores: Array[float] = trial_scores.duplicate()
	scores.append(release_score)
	for k: int in scores.size():
		var g: int = int(ThrowSkill.beat_grade(scores[k]))
		var c: Color = ThrowTrial.GRADE_COLORS[g]
		draw_circle(pt + Vector2((float(k) - (scores.size() - 1) * 0.5) * 36.0, 34.0), 9.0, Color(c, col.a))
	var sub: String = tr("THROW_CONTROL_DELTA") % ("%+d" % roundi(_control_delta * 100.0))
	var scol: Color = (Palette.EMERALD if _control_delta >= 0.0 else Palette.DANGER)
	scol.a = col.a
	_text(pt + Vector2(0, 66), sub, UiKit.SIZE_SMALL, scol, 6)
