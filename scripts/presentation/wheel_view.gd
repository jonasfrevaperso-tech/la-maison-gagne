class_name WheelView
extends Control
## Roue dessinée en vectoriel (pseudo-3D : anneaux, reflets, ombrage), taille variable.
## Modes : repos (rotation lente), visée (aiguille qui balaie), lancer (la bille raconte
## un résultat DÉJÀ tiré : décélération, rebonds, quasi-ratés au ralenti).

signal ball_settled(landing_index: int)
signal pocket_clicked(index: int)
signal pocket_hovered(index: int)

const IDLE_SPEED: float = 0.18
const SPIN_SPEED: float = 1.4
const BALL_REVS: float = 3.0
const BALL_START_SPEED_FACTOR: float = 1.0
const RIM_RATIO: float = 0.96
const POCKET_OUTER: float = 0.82
const POCKET_INNER: float = 0.58
const HUB_RATIO: float = 0.36
const BALL_ORBIT: float = 0.9
const BALL_RADIUS_RATIO: float = 0.028
const LABEL_RATIO: float = 0.74
const TRAIL_LENGTH: int = 18
const BOUNCE_COUNT: int = 3
const BOUNCE_HEIGHT: float = 0.06
const NEAR_MISS_SLOWMO: float = 0.45
const TILT: float = 0.82  # écrasement vertical pour l'effet 2.5D
const FONT_SIZE_RATIO: float = 0.045
const ASSIST_AIM_SLOWDOWN: float = 1.6
const TYPE_ICON_RATIO: float = 0.64
const ZOOM_MAX: float = 0.08
const ZOOM_START: float = 0.72
const TYPE_ICON_SIZE_RATIO: float = 0.085

var wheel: WheelModel = null
var db: ContentDB = null
var rotation_angle: float = 0.0
var aiming: bool = false
var aim_index: int = 0
var zone_width: int = 7
var highlight_numbers: Dictionary = {}  # numéro -> true (paris posés)
var flash_index: int = -1
var hover_index: int = -1
var probabilities: Array[float] = []

## Sens de rotation (−1 : roue inversée, créancier La Valseuse) et accélération de la visée.
var direction: float = 1.0
var aim_speed_mult: float = 1.0
var _aim_t: float = 0.0
var _aim_period: float = 2.4
var _ball_active: bool = false
var _ball_t: float = 0.0
var _ball_duration: float = 3.6
var _ball_angle_start: float = 0.0
var _ball_landing: int = 0
var _ball_near_miss: bool = false
var _ball_angle: float = 0.0
var _ball_radius: float = BALL_ORBIT
var _ball_resting: bool = false
var _trail: Array[Vector2] = []
var _wheel_speed: float = IDLE_SPEED
var _flash_t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5
	_aim_period = Balance.f("throw.pointer_period_seconds")


func setup(p_wheel: WheelModel, p_db: ContentDB) -> void:
	wheel = p_wheel
	db = p_db
	queue_redraw()


func radius() -> float:
	return minf(size.x, size.y / TILT) * 0.5 * RIM_RATIO


func center() -> Vector2:
	return size * 0.5


func pocket_angle_span() -> float:
	return TAU / float(maxi(wheel.size(), 1)) if wheel != null else TAU / 37.0


## Angle écran du centre de la case `i` (la roue tourne de `rotation_angle`).
func pocket_angle(i: int) -> float:
	return rotation_angle + (float(i) + 0.5) * pocket_angle_span() - PI * 0.5


func to_screen(angle: float, r: float) -> Vector2:
	return center() + Vector2(cos(angle) * r, sin(angle) * r * TILT)


func pocket_screen_pos(i: int) -> Vector2:
	return to_screen(pocket_angle(i), radius() * (POCKET_OUTER + POCKET_INNER) * 0.5)


func index_at_angle(screen_angle: float) -> int:
	var rel: float = fposmod(screen_angle + PI * 0.5 - rotation_angle, TAU)
	return int(rel / pocket_angle_span()) % maxi(wheel.size(), 1)


# --------------------------------------------------------------------------- visée


func start_aim() -> void:
	aiming = true
	_aim_t = 0.0
	_aim_period = Balance.f("throw.pointer_period_seconds") * (ASSIST_AIM_SLOWDOWN if Settings.b("game", "assist") else 1.0)


## Le pointeur est fixe en haut de l'écran (angle −90°) ; la roue tourne sous lui.
## La case visée est celle sous le pointeur au moment du relâchement.
func stop_aim() -> int:
	aiming = false
	return aim_index


# --------------------------------------------------------------------------- lancer


func play_throw(landing_index: int, near_miss: bool) -> void:
	_ball_active = true
	_ball_resting = false
	_ball_t = 0.0
	_ball_landing = landing_index
	_ball_near_miss = near_miss
	_ball_duration = JuiceProfile.BALL_SPIN_TIME / maxf(Settings.speed(), 1.0)
	_ball_angle_start = -PI * 0.5
	_trail.clear()
	_wheel_speed = SPIN_SPEED
	AudioBus.play("ball_roll")


func is_ball_active() -> bool:
	return _ball_active


func skip_ball() -> void:
	if _ball_active:
		_ball_t = _ball_duration


func flash_pocket(i: int) -> void:
	flash_index = i
	_flash_t = 1.0


# --------------------------------------------------------------------------- boucle


func _process(delta: float) -> void:
	if wheel == null:
		return
	var dt: float = delta
	if _ball_active and _ball_near_miss and _ball_t > _ball_duration * 0.8:
		dt *= NEAR_MISS_SLOWMO if JuiceProfile.intensity() > 0.0 else 1.0
	if aiming:
		_wheel_speed = lerpf(_wheel_speed, direction * aim_speed_mult * TAU / _aim_period, delta * 4.0)
	elif not _ball_active:
		_wheel_speed = lerpf(_wheel_speed, direction * IDLE_SPEED, delta * 1.5)
	if _ball_active:
		_update_ball(dt)
	else:
		rotation_angle += _wheel_speed * dt
	if aiming:
		aim_index = index_at_angle(-PI * 0.5)
	if _flash_t > 0.0:
		_flash_t = maxf(_flash_t - delta * 1.5, 0.0)
	queue_redraw()


## La bille fait BALL_REVS tours en décélérant pendant que la roue ralentit par saccades,
## puis l'angle final est forcé sur la case gagnante (résultat déjà connu).
func _update_ball(dt: float) -> void:
	_ball_t += dt
	var u: float = clampf(_ball_t / _ball_duration, 0.0, 1.0)
	# Roue : décélération par saccades (ondulation sur la vitesse).
	var jitter: float = 0.15 * sin(u * 40.0) * (1.0 - u)
	_wheel_speed = lerpf(SPIN_SPEED, 0.15, u) * (1.0 + jitter)
	rotation_angle += _wheel_speed * dt
	# Bille : angle relatif (sens inverse) qui converge vers la case cible.
	var target_angle: float = pocket_angle(_ball_landing)
	var ease: float = 1.0 - pow(1.0 - u, 3.0)
	var revs: float = -BALL_REVS * TAU * (1.0 - ease)
	_ball_angle = target_angle + revs
	# Rayon : de l'orbite vers les cases, avec rebonds à la fin.
	var r_in: float = (POCKET_OUTER + POCKET_INNER) * 0.5
	var drop: float = smoothstep(0.55, 0.85, u)
	var bounce: float = 0.0
	if u > 0.7 and u < 0.97:
		var bu: float = (u - 0.7) / 0.27
		bounce = absf(sin(bu * PI * float(BOUNCE_COUNT))) * BOUNCE_HEIGHT * (1.0 - bu)
	_ball_radius = lerpf(BALL_ORBIT, r_in, drop) + bounce
	var z: float = 1.0 + ZOOM_MAX * smoothstep(ZOOM_START, 1.0, u) * JuiceProfile.intensity()
	scale = Vector2(z, z)
	if u > 0.7 and _trail.size() > 0 and bounce < 0.004 and RngService.cosmetic().randf() < 0.08:
		AudioBus.play("ball_bounce", 1.0 + RngService.cosmetic().randf_range(-0.1, 0.2))
	var p: Vector2 = to_screen(_ball_angle, radius() * _ball_radius)
	_trail.push_front(p)
	if _trail.size() > TRAIL_LENGTH:
		_trail.resize(TRAIL_LENGTH)
	if u >= 1.0:
		_ball_active = false
		_ball_resting = true
		_trail.clear()
		flash_pocket(_ball_landing)
		AudioBus.play("ball_land")
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		ball_settled.emit(_ball_landing)


# --------------------------------------------------------------------------- entrées


func _gui_input(event: InputEvent) -> void:
	if wheel == null:
		return
	if event is InputEventMouseMotion:
		var idx: int = _index_at_point((event as InputEventMouseMotion).position)
		if idx != hover_index:
			hover_index = idx
			pocket_hovered.emit(idx)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var i: int = _index_at_point(mb.position)
			if i >= 0:
				pocket_clicked.emit(i)


func _index_at_point(p: Vector2) -> int:
	var d: Vector2 = p - center()
	d.y /= TILT
	var r: float = d.length() / maxf(radius(), 1.0)
	if r < POCKET_INNER or r > POCKET_OUTER:
		return -1
	return index_at_angle(d.angle())


func _get_tooltip(at_position: Vector2) -> String:
	var i: int = _index_at_point(at_position)
	if i < 0 or wheel == null or db == null:
		return ""
	return PocketInfo.describe(wheel.at(i), db, probabilities[i] if i < probabilities.size() else -1.0)


# --------------------------------------------------------------------------- dessin


func _draw() -> void:
	if wheel == null:
		return
	var c: Vector2 = center()
	var r: float = radius()
	var n: int = wheel.size()
	var span: float = pocket_angle_span()
	# Ombre portée et caisse en bois
	_draw_ellipse(c + Vector2(0, r * 0.06), r * 1.04, Color(0, 0, 0, 0.55))
	_draw_ellipse(c, r, Palette.VELVET.darkened(0.4))
	_draw_ellipse(c, r * 0.985, Palette.GOLD_DARK)
	_draw_ellipse(c, r * 0.95, Palette.INK)
	# Cases
	for i: int in n:
		var p: Pocket = wheel.at(i)
		var a0: float = rotation_angle + float(i) * span - PI * 0.5
		var a1: float = a0 + span
		var col: Color = Palette.pocket_color(p.color())
		var tdef: Dictionary = db.get_entry("pocket_types", String(p.type_id)) if db != null else {}
		if highlight_numbers.has(p.number):
			col = col.lightened(0.25)
		if i == flash_index and _flash_t > 0.0:
			col = col.lerp(Palette.GOLD_LIGHT, _flash_t * 0.8)
		if i == hover_index:
			col = col.lightened(0.15)
		_draw_ring_sector(c, r * POCKET_INNER, r * POCKET_OUTER, a0, a1, col)
		if p.type_id != Pocket.TYPE_STANDARD:
			var tcol: Color = Color(String(tdef.get("color", "f2d27a"))) if tdef.has("color") else PocketInfo.type_color(p.type_id)
			_draw_ring_sector(c, r * (POCKET_OUTER - 0.05), r * POCKET_OUTER, a0, a1, tcol)
		if p.edition != &"":
			var ecol: Color = PocketInfo.edition_color(p.edition)
			ecol.a = 0.35 + 0.25 * sin(Time.get_ticks_msec() * 0.004 + float(i))
			_draw_ring_sector(c, r * POCKET_INNER, r * POCKET_OUTER, a0, a1, ecol)
		# séparateur
		draw_line(to_screen(a0, r * POCKET_INNER), to_screen(a0, r * POCKET_OUTER), Palette.GOLD_DARK, 1.5, true)
		_draw_number(i, p, r)
		if p.type_id != Pocket.TYPE_STANDARD:
			_draw_type_icon(i, p, r)
		if p.seal != &"":
			draw_circle(to_screen(a0 + span * 0.5, r * (POCKET_INNER + 0.04)), r * 0.016, PocketInfo.seal_color(p.seal))
	# Zone de visée
	if aiming:
		var half: int = zone_width / 2
		for o: int in range(-half, half + 1):
			var ii: int = posmod(aim_index + o, n)
			var a0z: float = rotation_angle + float(ii) * span - PI * 0.5
			var zc: Color = Palette.CYAN
			zc.a = 0.45 if o == 0 else 0.22
			# Les cases misées dans la zone ressortent en or : on voit ce que couvre le lancer.
			if highlight_numbers.has(wheel.at(ii).number):
				zc = Palette.GOLD_LIGHT
				zc.a = 0.75
			_draw_ring_sector(c, r * POCKET_OUTER, r * (POCKET_OUTER + 0.06), a0z, a0z + span, zc)
		var tip: Vector2 = to_screen(-PI * 0.5, r * (POCKET_OUTER + 0.02))
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-14, -30), tip + Vector2(14, -30)]), Palette.CYAN)
	# Probabilités (Dr Khan / option)
	if not probabilities.is_empty() and not _ball_active:
		var pmax: float = 0.0
		for x: float in probabilities:
			pmax = maxf(pmax, x)
		for i2: int in mini(n, probabilities.size()):
			var a0p: float = rotation_angle + float(i2) * span - PI * 0.5
			var h: float = 0.08 * probabilities[i2] / maxf(pmax, 0.0001)
			var pc: Color = Palette.EMERALD
			pc.a = 0.7
			_draw_ring_sector(c, r * (POCKET_INNER - h), r * POCKET_INNER, a0p, a0p + span, pc)
	# Moyeu
	_draw_ellipse(c, r * HUB_RATIO * 1.5, Palette.VELVET_DEEP)
	_draw_ellipse(c, r * HUB_RATIO, Palette.GOLD_DARK)
	for k: int in 8:
		var a: float = rotation_angle * 1.0 + float(k) * TAU / 8.0
		draw_line(c, to_screen(a, r * HUB_RATIO * 1.45), Palette.GOLD, 3.0, true)
	_draw_ellipse(c, r * HUB_RATIO * 0.35, Palette.GOLD_LIGHT)
	# Reflet
	var hl: Color = Palette.IVORY
	hl.a = 0.06
	_draw_ellipse(c + Vector2(-r * 0.2, -r * 0.25 * TILT), r * 0.5, hl)
	# Bille
	if _ball_active or _ball_resting:
		var bp: Vector2
		if _ball_active:
			bp = to_screen(_ball_angle, radius() * _ball_radius)
		else:
			bp = pocket_screen_pos(_ball_landing)
		for t: int in _trail.size():
			var tc: Color = Palette.GOLD_LIGHT
			tc.a = 0.35 * (1.0 - float(t) / float(TRAIL_LENGTH)) * JuiceProfile.intensity()
			draw_circle(_trail[t], r * BALL_RADIUS_RATIO * (1.0 - float(t) / float(TRAIL_LENGTH)), tc)
		draw_circle(bp + Vector2(2, 3), r * BALL_RADIUS_RATIO, Color(0, 0, 0, 0.5))
		var btex: Texture2D = IconLibrary.sprite("ball")
		var br: float = r * BALL_RADIUS_RATIO * 1.15
		if btex != null:
			draw_texture_rect(btex, Rect2(bp - Vector2(br, br), Vector2(br, br) * 2.0), false)
		else:
			draw_circle(bp, r * BALL_RADIUS_RATIO, Palette.IVORY)


func _draw_number(i: int, p: Pocket, r: float) -> void:
	var f: Font = UiKit.font("mono")
	var fs: int = UiKit.fs(int(r * FONT_SIZE_RATIO * 37.0 / maxf(float(wheel.size()), 20.0)))
	var pos: Vector2 = to_screen(pocket_angle(i), r * LABEL_RATIO)
	var txt: String = str(p.number)
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_string(f, pos + Vector2(-w * 0.5, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Palette.IVORY)
	if p.level > 0:
		draw_string(
			f, pos + Vector2(-w * 0.5, fs * 1.3), "+" + str(p.level), HORIZONTAL_ALIGNMENT_CENTER, -1, UiKit.fs(int(fs * 0.7)), Palette.GOLD_LIGHT
		)


func _draw_type_icon(i: int, p: Pocket, r: float) -> void:
	var tdef: Dictionary = db.get_entry("pocket_types", String(p.type_id)) if db != null else {}
	var tex: Texture2D = IconLibrary.icon(String(tdef.get("icon", "")))
	if tex == null:
		return
	var sz: float = r * TYPE_ICON_SIZE_RATIO * clampf(37.0 / float(maxi(wheel.size(), 1)), 0.6, 1.2)
	var pos: Vector2 = to_screen(pocket_angle(i), r * TYPE_ICON_RATIO)
	draw_texture_rect(tex, Rect2(pos - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false)


func _draw_ellipse(c: Vector2, r: float, col: Color) -> void:
	var pts: PackedVector2Array = []
	var seg: int = 72
	for k: int in seg:
		var a: float = float(k) / float(seg) * TAU
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * TILT))
	draw_colored_polygon(pts, col)


func _draw_ring_sector(c: Vector2, r0: float, r1: float, a0: float, a1: float, col: Color) -> void:
	var pts: PackedVector2Array = []
	var steps: int = 4
	for k: int in steps + 1:
		var a: float = lerpf(a0, a1, float(k) / float(steps))
		pts.append(c + Vector2(cos(a) * r1, sin(a) * r1 * TILT))
	for k: int in range(steps, -1, -1):
		var a2: float = lerpf(a0, a1, float(k) / float(steps))
		pts.append(c + Vector2(cos(a2) * r0, sin(a2) * r0 * TILT))
	draw_colored_polygon(pts, col)
