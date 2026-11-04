class_name TrialScratch
extends ThrowTrial
## LE GRATTAGE (écran dédié, 1.9, refait) : « Gratte les trois cases du ticket sans déborder ».
## Un ticket « Fortune du Zéro » argenté ; trois zones cerclées de pointillés dorés (trèfle,
## étoile, sept). On gratte pour de vrai : souris ou doigt en glissant, ou pièce déplacée au
## stick / aux flèches et bouton maintenu. Chaque zone se remplit à mesure ; ce qui est gratté
## hors des pointillés coûte des points.
## Note = part révélée des trois zones, moins la part de débord. Les symboles sont fixes : on
## note l'adresse, jamais le hasard (D-046).

const SYMBOLS: Array[String] = ["☘", "★", "7"]
const SYMBOL_COLORS: Array[Color] = [Color("2ee6a8"), Color("ffd23f"), Color("ff4d6d")]
## Ticket (coordonnées de maquette), pellicule argentée et grille du masque de grattage.
const TICKET: Rect2 = Rect2(400.0, 250.0, 1120.0, 560.0)
const FOIL: Rect2 = Rect2(440.0, 360.0, 1040.0, 400.0)
const CELL: float = 10.0
const FOIL_COLOR: Color = Color("b8b8c4")
const FOIL_DARK: Color = Color("8e8e9c")
## Bande tolérée de part et d'autre des pointillés (ni comptée, ni pénalisée), en pixels.
const RIM: float = 14.0
const RIM_IN: float = 6.0
## Décor : mètres par pixel du fond 3D, boîtes des étagères, poussière de grattage.
const PX3: float = 0.005
const SHELF_BOXES: int = 9
const BOX_COLORS: Array[Color] = [Color("8a1428"), Color("1f4f8a"), Color("c08a2a"), Color("2e6a3a"), Color("5a2a6a")]
const DUST_MAX: int = 160
const DUST_LIFE: float = 0.7
## Freinage du bot à l'approche de chaque point du parcours (constante de temps, s).
const BOT_LOOK: float = 0.2

var _cols: int = 0
var _rows: int = 0
## 0 : pellicule intacte ; 1 : gratté. Index = ligne * _cols + colonne.
var _mask: PackedByteArray = PackedByteArray()
## Zone de chaque cellule : 0..2 (dans les pointillés), -1 (hors zone, pénalisé), -2 (liseré toléré).
var _zone_of: PackedInt32Array = PackedInt32Array()
var _zone_total: Array[int] = [0, 0, 0]
var _zone_done: Array[int] = [0, 0, 0]
var _zone_complete: Array[bool] = [false, false, false]
var _outside_total: int = 0
var _outside: int = 0
var _centers: Array[Vector2] = []
var _coin: Vector2 = Vector2(960.0, 560.0)
var _scratching: bool = false
var _drag: bool = false
var _bot_v: Vector2 = Vector2.ZERO
var _bot_points: Array[Vector2] = []
var _sound_t: float = 0.0
var _ended: bool = false
var _end_t: float = -1.0
var _dust: Array[Vector3] = []
var _dust_v: Array[Vector2] = []
var _neon: Label3D = null


func begin() -> void:
	_cols = int(FOIL.size.x / CELL)
	_rows = int(FOIL.size.y / CELL)
	_mask.resize(_cols * _rows)
	_mask.fill(0)
	_zone_of.resize(_cols * _rows)
	var r: float = p("zone_radius")
	# Trois zones réparties sur la pellicule, légèrement décalées en hauteur.
	for k: int in 3:
		_centers.append(FOIL.position + Vector2(FOIL.size.x * (0.2 + 0.3 * float(k)), FOIL.size.y * (0.42 + 0.16 * float(k % 2))))
	for i: int in _cols * _rows:
		var c: Vector2 = _cell_center(i)
		var z: int = -1
		for k: int in 3:
			var d: float = c.distance_to(_centers[k])
			if d <= r - RIM_IN:
				z = k
			elif d <= r + RIM and z == -1:
				z = -2
		_zone_of[i] = z
		if z >= 0:
			_zone_total[z] += 1
		elif z == -1:
			_outside_total += 1
	_coin = FOIL.get_center() + Vector2(0, FOIL.size.y * 0.5 + 60.0)
	_bot_points = _plan_bot()
	_build_3d()


# --------------------------------------------------------------------------- décor 3D


## Bureau de tabac : boiseries, étagères garnies, enseigne néon, comptoir de laiton.
func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	st.env.background_color = Color("120a0c")
	st.env.ambient_light_energy = 0.4
	var r: Node3D = st.root
	var wood: StandardMaterial3D = Stage3D.mat(Color("3a2214"), 0.0, 0.55)
	var wood_d: StandardMaterial3D = Stage3D.mat(Color("2a160c"), 0.0, 0.6)
	Stage3D.box(r, Vector3(30, 14, 0.1), st.to3(Vector2(960, 540), -2.2), wood_d)
	for k: int in 12:
		Stage3D.box(r, Vector3(0.08, 14, 0.06), st.to3(Vector2(-1800.0 + float(k) * 400.0, 540.0), -2.12), wood)
	# Étagères de part et d'autre du ticket, garnies de boîtes et de rouleaux de tickets.
	for side: float in [-1.0, 1.0]:
		for row: int in 3:
			var y: float = 260.0 + float(row) * 230.0
			var cx: float = 960.0 + side * 780.0
			Stage3D.box(r, Vector3(900.0 * PX3, 16.0 * PX3, 0.5), st.to3(Vector2(cx, y), -1.8), wood)
			for b: int in SHELF_BOXES:
				var bx: float = cx - 400.0 + float(b) * 100.0
				var h: float = 70.0 + float((b * 7 + row * 3) % 5) * 14.0
				var col: Color = BOX_COLORS[(b + row * 2) % BOX_COLORS.size()]
				if (b + row) % 4 == 0:
					var roll: MeshInstance3D = Stage3D.cylinder(r, 30.0 * PX3, 0.3, st.to3(Vector2(bx, y - 38.0), -1.75),
						Stage3D.mat(Color("f4e7c8"), 0.0, 0.7))
					roll.rotation.x = PI * 0.5
				else:
					Stage3D.box(r, Vector3(80.0 * PX3, h * PX3, 0.36), st.to3(Vector2(bx, y - 8.0 - h * 0.5), -1.78),
						Stage3D.mat(col, 0.1, 0.5))
	# Enseigne néon au-dessus du ticket.
	_neon = Stage3D.text3d(r, "FORTUNE", st.to3(Vector2(200.0, 110.0), -1.9), 96, Color("ff4d6d"), Color("ff2e88"))
	_neon.pixel_size = 0.004
	Stage3D.omni(r, Color("ff4d6d"), 0.9, st.to3(Vector2(200.0, 130.0), -1.4), 3.5)
	var star: Label3D = Stage3D.text3d(r, "☘", st.to3(Vector2(1720.0, 110.0), -1.9), 140, Color("2ee6a8"), Color("1e9e5a"))
	star.pixel_size = 0.004
	Stage3D.omni(r, Color("2ee6a8"), 0.7, st.to3(Vector2(1720.0, 130.0), -1.4), 3.5)
	# Comptoir : plateau de bois sous le ticket, liseré de laiton, tapis de caisse.
	Stage3D.box(r, Vector3(30, 400.0 * PX3, 0.6), st.to3(Vector2(960.0, 1000.0), -0.3), Stage3D.mat(Color("4a2a18"), 0.0, 0.35))
	Stage3D.box(r, Vector3(30, 10.0 * PX3, 0.62), st.to3(Vector2(960.0, 806.0), -0.29), Stage3D.mat(Palette.GOLD_DARK, 0.45, 0.3))
	var lamp: OmniLight3D = Stage3D.omni(r, Color(1.0, 0.85, 0.6), 2.0, st.to3(Vector2(960.0, 300.0), 1.5), 8.0)
	lamp.shadow_enabled = RenderQuality.shadows()




# --------------------------------------------------------------------------- grattage


## Manette : en grattant, les pointillés retiennent la pièce (la pellicule « résiste » au bord) ;
## on peut toujours sortir en relâchant. Souris et doigt restent libres.
func _hold_in(prev: Vector2, to: Vector2) -> Vector2:
	var lim: float = p("zone_radius") + RIM - p("brush")
	for k: int in 3:
		if prev.distance_to(_centers[k]) <= lim + 1.0:
			var off: Vector2 = to - _centers[k]
			return _centers[k] + off.limit_length(lim)
	return to


func _cell_center(i: int) -> Vector2:
	return FOIL.position + Vector2((float(i % _cols) + 0.5) * CELL, (float(i / _cols) + 0.5) * CELL)


## Gratte un disque de rayon `brush` autour de `at` ; vrai si au moins une cellule est partie.
func _stamp(at: Vector2) -> bool:
	var br: float = p("brush")
	var x0: int = clampi(int((at.x - br - FOIL.position.x) / CELL), 0, _cols - 1)
	var x1: int = clampi(int((at.x + br - FOIL.position.x) / CELL), 0, _cols - 1)
	var y0: int = clampi(int((at.y - br - FOIL.position.y) / CELL), 0, _rows - 1)
	var y1: int = clampi(int((at.y + br - FOIL.position.y) / CELL), 0, _rows - 1)
	if at.x + br < FOIL.position.x or at.x - br > FOIL.end.x or at.y + br < FOIL.position.y or at.y - br > FOIL.end.y:
		return false
	var any: bool = false
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var i: int = y * _cols + x
			if _mask[i] == 1 or _cell_center(i).distance_to(at) > br:
				continue
			_mask[i] = 1
			any = true
			var z: int = _zone_of[i]
			if z >= 0:
				_zone_done[z] += 1
			elif z == -1:
				_outside += 1
	return any


## Gratte le long d'un trait (le geste rapide ne saute pas de cellules).
func _scratch_line(from: Vector2, to: Vector2) -> void:
	var n: int = maxi(1, ceili(from.distance_to(to) / (p("brush") * 0.4)))
	var any: bool = false
	for k: int in n + 1:
		any = _stamp(from.lerp(to, float(k) / float(n))) or any
	if any:
		_on_scratched(to)


func _on_scratched(at: Vector2) -> void:
	if _sound_t <= 0.0:
		AudioBus.play("paper", 1.3 + rng.randf() * 0.4, -12.0)
		_sound_t = 0.07
	_spawn_dust(at)
	for k: int in 3:
		if not _zone_complete[k] and zone_share(k) >= p("zone_full"):
			_zone_complete[k] = true
			AudioBus.play("coins", 1.0 + 0.15 * float(k), -6.0)
			pop(_centers[k] + Vector2(0, -p("zone_radius") - 30.0), 1.0, "TRIAL_SCRATCH_REVEALED")
	if _zone_complete.count(true) == 3 and not _ended:
		_end()


## Part révélée de la zone k (0..1), ramenée à 1 dès le seuil « zone_full ».
func zone_share(k: int) -> float:
	return float(_zone_done[k]) / float(maxi(_zone_total[k], 1))


## Débord : cellules grattées hors des pointillés, rapportées à l'aire des trois zones.
func overflow() -> float:
	var zone_cells: int = _zone_total[0] + _zone_total[1] + _zone_total[2]
	return float(_outside) / float(maxi(zone_cells, 1))


func current_score() -> float:
	var rev: float = 0.0
	for k: int in 3:
		rev += clampf(zone_share(k) / p("zone_full"), 0.0, 1.0)
	return clampf(rev / 3.0 - overflow() * p("overflow_penalty"), 0.0, 1.0)


func _end() -> void:
	_ended = true
	_scratching = false
	_drag = false
	_end_t = p("end_seconds")
	var sc: float = current_score()
	pop(FOIL.get_center() + Vector2(0, -FOIL.size.y * 0.5 - 40.0), sc)


func handle(event: InputEvent) -> bool:
	if _ended:
		return true
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
			if _drag:
				_coin = mb.position
				_scratch_line(_coin, _coin)
		return true
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		var prev: Vector2 = _coin
		_coin = mm.position
		if _drag:
			_scratch_line(prev, _coin)
		return true
	if confirm_pressed(event):
		_scratching = true
		return true
	if confirm_released(event):
		_scratching = false
		return true
	return false


func tick(dt: float) -> void:
	_sound_t -= dt
	_tick_dust(dt)
	if _ended:
		_end_t -= dt
		if _end_t <= 0.0 and not finished:
			finish(current_score())
		return
	if t >= p("duration") * slow:
		_end()
		return
	# Pièce au stick / aux flèches (la souris et le doigt la posent directement).
	var v: Vector2 = held_vector() + _bot_v
	if v.length() > 1.0:
		v = v.normalized()
	if v.length() > 0.0:
		var prev: Vector2 = _coin
		_coin = (_coin + v * p("coin_speed") * dt).clamp(TICKET.position, TICKET.end)
		if _scratching:
			_coin = _hold_in(prev, _coin)
			_scratch_line(prev, _coin)
	elif _scratching:
		_scratch_line(_coin, _coin)


# --------------------------------------------------------------------------- bot


## Parcours idéal : balayage en lignes de chaque zone, en restant dans les pointillés.
func _plan_bot() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var r: float = p("zone_radius") - p("brush") * p("bot_inset")
	var stepy: float = p("brush") * 1.2
	for k: int in 3:
		var c: Vector2 = _centers[k]
		var y: float = -r
		var row: int = 0
		while y <= r + 0.01:
			var hw: float = sqrt(maxf(r * r - y * y, 0.0))
			var a: Vector2 = c + Vector2(-hw, y)
			var b: Vector2 = c + Vector2(hw, y)
			out.append(a if row % 2 == 0 else b)
			out.append(b if row % 2 == 0 else a)
			y += stepy
			row += 1
	return out


func _bot_target() -> int:
	# Saute les points déjà grattés (et ceux d'une zone déjà complète).
	while not _bot_points.is_empty():
		var pt: Vector2 = _bot_points[0]
		var z: int = _nearest_zone(pt)
		if _zone_complete[z] or (_coin.distance_to(pt) < p("brush") * 0.6):
			_bot_points.pop_front()
			continue
		return z
	return -1


func _nearest_zone(pt: Vector2) -> int:
	var best: int = 0
	for k: int in 3:
		if pt.distance_to(_centers[k]) < pt.distance_to(_centers[best]):
			best = k
	return best


func bot_wants() -> Dictionary:
	if _ended:
		return {"do": "release"} if _scratching else {"do": ""}
	var z: int = _bot_target()
	if z < 0:
		return {"do": "release"} if _scratching else {"do": ""}
	var pt: Vector2 = _bot_points[0]
	var inside: bool = _coin.distance_to(_centers[z]) <= p("zone_radius") - p("brush") * 0.3
	# Relâcher AVANT de quitter la zone (et attendre que ce soit fait), sinon on déborde.
	if _scratching and not inside:
		return {"do": "release"}
	if not _scratching and inside:
		return {"do": "hold"}
	var d: Vector2 = pt - _coin
	return {"do": "axis", "v": d.normalized() * clampf(d.length() / (p("coin_speed") * BOT_LOOK), 0.2, 1.0)}


func bot_apply(w: Dictionary) -> void:
	var act: String = String(w.get("do", ""))
	_bot_v = (w.get("v", Vector2.ZERO) as Vector2) if act in ["axis", "hold"] else Vector2.ZERO
	if act == "hold":
		_scratching = true
	elif act == "release":
		_scratching = false


# --------------------------------------------------------------------------- copeaux


func _spawn_dust(at: Vector2) -> void:
	for k: int in 3:
		_dust.append(Vector3(at.x + rng.randf_range(-12.0, 12.0), at.y + rng.randf_range(-8.0, 8.0), DUST_LIFE))
		_dust_v.append(Vector2(rng.randf_range(-160.0, 160.0), rng.randf_range(-180.0, -40.0)))
	while _dust.size() > DUST_MAX:
		_dust.pop_front()
		_dust_v.pop_front()


func _tick_dust(dt: float) -> void:
	for k: int in range(_dust.size() - 1, -1, -1):
		_dust_v[k].y += 900.0 * dt
		_dust[k] = Vector3(_dust[k].x + _dust_v[k].x * dt, _dust[k].y + _dust_v[k].y * dt, _dust[k].z - dt)
		if _dust[k].z <= 0.0:
			_dust.remove_at(k)
			_dust_v.remove_at(k)


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	if _cols == 0:
		return
	# Ticket : carton crème, liseré doré, titre.
	draw_rect(TICKET.grow(8.0), Palette.GOLD_DARK)
	draw_rect(TICKET, Color("f4e7c8"))
	draw_rect(TICKET.grow(-10.0), Color("c8102e"), false, 3.0)
	text(Vector2(TICKET.get_center().x, TICKET.position.y + 56.0), tr("TRIAL_SCRATCH_TICKET"), UiKit.SIZE_H1, Color("8a1428"), "display", 0)
	# Dessous : papier, symboles (révélés en grattant).
	draw_rect(FOIL, Color("fff6dc"))
	for k: int in 3:
		var glow: float = 1.0 if _zone_complete[k] else 0.75
		text(_centers[k], SYMBOLS[k], UiKit.SIZE_H1 * 2, Color(SYMBOL_COLORS[k], glow), "display", 6)
	# Pellicule : une bande par suite de cellules intactes sur chaque ligne.
	for y: int in _rows:
		var x: int = 0
		while x < _cols:
			if _mask[y * _cols + x] == 1:
				x += 1
				continue
			var x0: int = x
			while x < _cols and _mask[y * _cols + x] == 0:
				x += 1
			var col: Color = FOIL_COLOR if (y / 4) % 2 == 0 else FOIL_COLOR.lerp(FOIL_DARK, 0.25)
			draw_rect(Rect2(FOIL.position + Vector2(float(x0) * CELL, float(y) * CELL), Vector2(float(x - x0) * CELL, CELL)), col)
	# Pointillés dorés des trois zones et part révélée.
	var r: float = p("zone_radius")
	for k: int in 3:
		var dots: int = 36
		for d: int in dots:
			var a: float = TAU * float(d) / float(dots) + t * 0.4
			draw_circle(_centers[k] + Vector2.from_angle(a) * r, 4.0, Palette.GOLD if not _zone_complete[k] else Palette.EMERALD)
		var share: float = clampf(zone_share(k) / p("zone_full"), 0.0, 1.0)
		draw_arc(_centers[k], r + 20.0, -PI * 0.5, -PI * 0.5 + TAU * share, 48, Palette.EMERALD if _zone_complete[k] else Palette.GOLD_LIGHT,
			6.0)
	# Copeaux argentés.
	for k2: int in _dust.size():
		var dd: Vector3 = _dust[k2]
		draw_rect(Rect2(dd.x - 3.0, dd.y - 3.0, 6.0, 6.0), Color(FOIL_COLOR, clampf(dd.z / DUST_LIFE, 0.0, 1.0)))
	# Pièce de grattage.
	var br: float = p("brush")
	draw_circle(_coin + Vector2(4, 6), br, Color(0, 0, 0, 0.3))
	draw_circle(_coin, br, Palette.GOLD_DARK if not (_scratching or _drag) else Palette.GOLD)
	draw_circle(_coin, br * 0.78, Palette.GOLD_LIGHT)
	text(_coin, "0", UiKit.SIZE_BODY, Palette.GOLD_DARK, "display", 0)
	# Jauges : temps restant et débord.
	var left: float = clampf(1.0 - t / maxf(p("duration") * slow, 0.01), 0.0, 1.0)
	var bar: Rect2 = Rect2(TICKET.position.x, TICKET.end.y + 30.0, TICKET.size.x, 10.0)
	draw_rect(bar, Palette.VELVET_DEEP)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), Palette.GOLD)
	var ov: float = overflow() * p("overflow_penalty")
	text(Vector2(TICKET.end.x - 140.0, TICKET.end.y + 70.0), tr("TRIAL_SCRATCH_OVERFLOW") % roundi(ov * 100.0), UiKit.SIZE_SMALL,
		Palette.MULT_RED if ov > 0.05 else Palette.SMOKE)
