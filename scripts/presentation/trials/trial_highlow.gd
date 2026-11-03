class_name TrialHighLow
extends ThrowTrial
## PLUS HAUT, PLUS BAS : Odile a laissé ses cartes. Une carte est retournée (As à Roi) : la
## suivante sera-t-elle plus haute ou plus basse ? On juge la DÉCISION, pas la chance : choisir
## le pari le plus probable compte comme réussi, même si la carte suivante déjoue les calculs.
## Le temps de réflexion se resserre à chaque carte. Note = part des bons choix.

## Décor 3D : place de la carte en cours, de la suivante et du talon sur le tapis (m).
const CUR_AT: Vector3 = Vector3(-0.42, 0.01, 0.0)
const NEXT_AT: Vector3 = Vector3(0.42, 0.01, 0.0)
const DECK_AT: Vector3 = Vector3(1.25, 0.0, -0.3)
const SLIDE: float = 8.0

var _cards: Array[int] = []
var _i: int = 0
var _decide_t: float = 0.0
var _scores: Array[float] = []
var _reveal: float = -1.0
var _last_guess: int = 0
var _cur3: PlayingCard3D = null
var _next3: PlayingCard3D = null


func begin() -> void:
	for k: int in pi("cards") + 1:
		_cards.append(rng.randi_range(1, 13))
	_build_3d()
	AudioBus.play("card_flip", 1.0, -4.0)


# --------------------------------------------------------------------------- décor 3D


## Le guéridon d'Odile : tapis vert, talon, cendrier et verre, sous une lampe basse.
func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.env.background_color = Color(0.03, 0.02, 0.03)
	st.env.ambient_light_energy = 0.4
	st.key.light_energy = 0.25
	st.look(Vector3(0, 1.55, 1.05), Vector3(0, 0, 0.08), 40.0)
	var r: Node3D = st.root
	Stage3D.cylinder(r, 2.4, 0.08, Vector3(0, -0.05, 0), Stage3D.mat(Color(0.2, 0.08, 0.04), 0.1, 0.4))
	Stage3D.cylinder(r, 2.2, 0.08, Vector3(0, -0.04, 0), Stage3D.mat(Color(0.04, 0.24, 0.14), 0.0, 0.95))
	Stage3D.box(r, Vector3(12, 0.02, 8), Vector3(0, -0.12, 0), Stage3D.mat(Color(0.08, 0.04, 0.05), 0.0, 0.8))
	# Talon de cartes (dos bordeaux).
	for k: int in 8:
		var c: MeshInstance3D = Stage3D.box(r, Vector3(PlayingCard3D.SIZE.x, 0.012, PlayingCard3D.SIZE.y),
			DECK_AT + Vector3(0, 0.006 + 0.012 * float(k), 0),
			Stage3D.mat(Palette.ROULETTE_RED.darkened(0.4 + 0.02 * float(k % 2)), 0.1, 0.5))
		c.rotation.y = 0.15 + 0.03 * float(k % 3)
	# Cendrier et verre.
	Stage3D.cylinder(r, 0.2, 0.06, Vector3(-1.3, 0.03, -0.35), Stage3D.mat(Color(0.5, 0.52, 0.58), 0.45, 0.25))
	Stage3D.cylinder(r, 0.11, 0.22, Vector3(1.3, 0.11, 0.35), Stage3D.mat(Color(0.62, 0.34, 0.08), 0.0, 0.15))
	Stage3D.cylinder(r, 0.115, 0.03, Vector3(1.3, 0.235, 0.35), Stage3D.mat(Color(0.85, 0.88, 0.92), 0.1, 0.1))
	var lamp: OmniLight3D = Stage3D.omni(r, Color(1.0, 0.85, 0.6), 2.2, Vector3(0, 1.3, -0.1), 4.0)
	lamp.shadow_enabled = RenderQuality.shadows()
	_cur3 = _spawn(_cards[0])
	_cur3.position = CUR_AT
	_cur3.rotation.y = 0.0
	_cur3.face_up = true
	_next3 = _spawn(_cards[1])


func _spawn(rank: int) -> PlayingCard3D:
	var c: PlayingCard3D = PlayingCard3D.new()
	stage.root.add_child(c)
	# Couleurs de la règle : rang pair en cœur (rouge), impair en pique (noir).
	c.set_card(rank, 1 if rank % 2 == 0 else 0)
	c.position = DECK_AT + Vector3(0, 0.12, 0)
	c.rotation.y = 0.15
	c.face_up = false
	c.flip = 0.0
	return c


## Carte suivante : la carte retournée devient la carte en cours, une nouvelle sort du talon.
func _advance_3d() -> void:
	if stage == null or _i + 1 >= _cards.size():
		return
	_cur3.queue_free()
	_cur3 = _next3
	_next3 = _spawn(_cards[_i + 1])


func _sync_3d(dt: float) -> void:
	if stage == null:
		return
	var w: float = 1.0 - exp(-SLIDE * dt)
	_cur3.position = _cur3.position.lerp(CUR_AT, w)
	_cur3.rotation.y = lerp_angle(_cur3.rotation.y, 0.0, w)
	_cur3.face_up = true
	_next3.position = _next3.position.lerp(NEXT_AT, w)
	_next3.rotation.y = lerp_angle(_next3.rotation.y, 0.0, w)
	_next3.face_up = _reveal >= 0.0


func _limit() -> float:
	return lerpf(p("decide_start"), p("decide_end"), float(_i) / maxf(float(pi("cards") - 1), 1.0)) * slow


func handle(event: InputEvent) -> bool:
	if _reveal >= 0.0:
		return dir_pressed(event) != Vector2i.ZERO or sym_pressed(event) >= 0
	var d: Vector2i = dir_pressed(event)
	if d.y != 0:
		guess(-d.y)
		return true
	if mouse:
		var k: int = sym_pressed(event)
		if k >= 0:
			guess(1 if k == 0 else -1)
			return true
	return false


## +1 : plus haut, -1 : plus bas. Bon choix = le plus probable (égalité : les deux).
func guess(dir: int) -> void:
	if _reveal >= 0.0 or _i >= pi("cards"):
		return
	var cur: int = _cards[_i]
	var higher: int = 13 - cur
	var lower: int = cur - 1
	var good: bool = (dir > 0 and higher >= lower) or (dir < 0 and lower >= higher)
	_last_guess = dir
	_finish_card(1.0 if good else 0.0)


func _finish_card(sc: float) -> void:
	_scores.append(sc)
	_reveal = 0.0
	AudioBus.play("card_flip", 1.1, -2.0)
	var nxt: int = _cards[_i + 1]
	var lucky: bool = (_last_guess > 0 and nxt > _cards[_i]) or (_last_guess < 0 and nxt < _cards[_i])
	AudioBus.play("chips_win" if lucky else "chip_lose", 1.0, -6.0)
	pop(Vector2(size.x * 0.5, 60.0), sc, "TRIAL_HIGHLOW_GOOD" if sc >= 1.0 else "TRIAL_HIGHLOW_BAD")


func tick(dt: float) -> void:
	_sync_3d(dt)
	if _reveal >= 0.0:
		_reveal += dt
		if _reveal > p("reveal_seconds") * slow:
			_reveal = -1.0
			_i += 1
			_advance_3d()
			_decide_t = 0.0
			if _i >= pi("cards"):
				finish(mean(_scores))
		return
	_decide_t += dt
	if _decide_t > _limit():
		_last_guess = 0
		_finish_card(0.0)


func bot_wants() -> Dictionary:
	if _reveal >= 0.0 or _i >= pi("cards") or _decide_t < 0.2:
		return {"do": ""}
	var cur: int = _cards[_i]
	return {"do": "dir", "dir": Vector2i(0, -1 if 13 - cur >= cur - 1 else 1)}


func bot_apply(want: Dictionary) -> void:
	if String(want.get("do", "")) == "dir":
		guess(-(want["dir"] as Vector2i).y)


func paint() -> void:
	var r: Rect2 = play_rect()
	var cx: float = r.get_center().x
	if stage == null:
		return
	var nxt: Vector2 = stage.project(NEXT_AT)
	var cur: Vector2 = stage.project(CUR_AT)
	# Flèches de choix et compte à rebours.
	if _reveal < 0.0 and _i < pi("cards"):
		var left: float = clampf(1.0 - _decide_t / _limit(), 0.0, 1.0)
		draw_rect(Rect2(cx - 150, r.position.y + 30, 300, 8), Color(Palette.INK, 0.7))
		draw_rect(Rect2(cx - 150, r.position.y + 30, 300 * left, 8), Palette.GOLD if left > 0.3 else Palette.DANGER)
		var ax: float = nxt.x + (nxt.x - cur.x) * 0.75
		_arrow(Vector2(ax, nxt.y - 70.0), -1.0, Palette.EMERALD)
		_arrow(Vector2(ax, nxt.y + 70.0), 1.0, Palette.CYAN)
		text(Vector2(ax + 110.0, nxt.y - 70.0), tr("TRIAL_HIGHLOW_UP"), UiKit.SIZE_BODY, Palette.EMERALD)
		text(Vector2(ax + 110.0, nxt.y + 70.0), tr("TRIAL_HIGHLOW_DOWN"), UiKit.SIZE_BODY, Palette.CYAN)
	pips(Vector2(cur.x - (nxt.x - cur.x) * 1.1, cur.y), _scores, pi("cards"))


## Flèche pleine (dir -1 vers le haut, +1 vers le bas) sur pastille sombre.
func _arrow(at: Vector2, dir: float, col: Color) -> void:
	draw_circle(at, 30.0, Color(Palette.INK, 0.8))
	draw_arc(at, 30.0, 0, TAU, 28, col, 2.0)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, dir * 16.0), at + Vector2(-14, -dir * 10.0), at + Vector2(14, -dir * 10.0)]),
		col)
