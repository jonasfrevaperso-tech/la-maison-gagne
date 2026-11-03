class_name TrialScratch
extends ThrowTrial
## LE GRATTAGE (écran dédié) : un ticket « Fortune du Zéro » de 9 cases ; trois cachent le
## trèfle d'or, et on n'a le droit d'en gratter que quatre. Le reflet doré qui balaie le ticket
## trahit le trèfle : il fait scintiller les trois bonnes cases à CHAQUE passage, les autres
## seulement de temps en temps. Observer, puis gratter (souris ou doigt sur la case, ou curseur
## et bouton maintenu à la manette / au clavier).
## Note = trèfles trouvés / 3, moins une part pour la lenteur. Le tirage ne note rien : seul
## l'œil compte (les bonnes cases scintillent toujours).

const GRID: int = 3
const CELL: Vector2 = Vector2(220.0, 180.0)
const GAP: float = 24.0
const TICKET_Y: float = 250.0
const SYMBOLS: Array[String] = ["☘", "♠", "♦", "★", "☾", "♥"]
const SCRATCH_DOTS: int = 7
## Décor : mètres par pixel du fond 3D, boîtes des étagères, poussière de grattage.
const PX3: float = 0.005
const SHELF_BOXES: int = 9
const BOX_COLORS: Array[Color] = [Color("8a1428"), Color("1f4f8a"), Color("c08a2a"), Color("2e6a3a"), Color("5a2a6a")]
const DUST_MAX: int = 120
const DUST_LIFE: float = 0.9
const FOIL: Color = Color("b8b8c4")

var _targets: Array[int] = []
var _cells: Array[String] = []
var _scratch: Array[float] = []
var _done: Array[bool] = []
var _tries: int = 0
var _found: int = 0
var _cursor: int = 4
var _holding: bool = false
var _drag: bool = false
var _sweep: float = 0.0
var _passes: int = 0
var _sparkle: Array[float] = []
var _seen: Array[int] = []
var _decoys: Array[bool] = []
var _ended: bool = false
var _end_t: float = -1.0
var _dust: Array[Vector3] = []
var _dust_v: Array[Vector2] = []
var _neon: Label3D = null


func begin() -> void:
	var idx: Array[int] = []
	for i: int in GRID * GRID:
		idx.append(i)
	for i2: int in range(idx.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i2)
		var tmp: int = idx[i2]
		idx[i2] = idx[j]
		idx[j] = tmp
	_targets = idx.slice(0, 3)
	for i3: int in GRID * GRID:
		_cells.append(SYMBOLS[0] if _targets.has(i3) else SYMBOLS[rng.randi_range(1, SYMBOLS.size() - 1)])
		_scratch.append(0.0)
		_done.append(false)
		_sparkle.append(0.0)
		_seen.append(0)
		_decoys.append(false)
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


func _ticket_origin() -> Vector2:
	var w: float = float(GRID) * CELL.x + float(GRID - 1) * GAP
	return Vector2(size.x * 0.5 - w * 0.5, TICKET_Y)


func _cell_rect(i: int) -> Rect2:
	var o: Vector2 = _ticket_origin()
	return Rect2(o + Vector2(float(i % GRID) * (CELL.x + GAP), floorf(float(i) / GRID) * (CELL.y + GAP)), CELL)


func _cell_at(pos: Vector2) -> int:
	for i: int in GRID * GRID:
		if _cell_rect(i).has_point(pos):
			return i
	return -1


func handle(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
			var c: int = _cell_at(mb.position)
			if c >= 0:
				_cursor = c
		return true
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		var c2: int = _cell_at(mm.position)
		if c2 >= 0:
			_cursor = c2
		return true
	var d: Vector2i = dir_pressed(event)
	if d != Vector2i.ZERO:
		var x: int = clampi(_cursor % GRID + d.x, 0, GRID - 1)
		var y: int = clampi(floori(float(_cursor) / GRID) + d.y, 0, GRID - 1)
		_cursor = y * GRID + x
		AudioBus.play("tick", 1.2, -10.0)
		return true
	if confirm_pressed(event) or sym_pressed(event) == 3:
		_holding = true
		return true
	if confirm_released(event) or GameInput.released(event, &"qte_down"):
		_holding = false
		return true
	return false


func tick(dt: float) -> void:
	if _ended:
		return
	if _end_t >= 0.0:
		_end_t -= dt
		if _end_t <= 0.0:
			_ended = true
			var sc: float = float(_found) / 3.0
			var late: float = clampf(t / (p("duration") * slow), 0.0, 1.0)
			finish(clampf(sc * (1.0 - p("time_weight") * late), 0.0, 1.0))
		return
	_reflect(dt)
	var rubbing: bool = _holding or _drag
	if rubbing and not _done[_cursor] and _tries < pi("tries"):
		_scratch[_cursor] = minf(1.0, _scratch[_cursor] + dt / (p("scratch_seconds") * slow))
		if rng.randf() < 0.3:
			AudioBus.play("paper", 1.4 + rng.randf() * 0.3, -14.0)
		_spawn_dust(_cell_rect(_cursor))
		if _scratch[_cursor] >= 1.0:
			_reveal(_cursor)
	_tick_dust(dt)
	if t >= p("duration") * slow and _end_t < 0.0:
		_end_t = 0.6


## Poussière argentée qui s'envole sous la pièce (pseudo-hasard du temps : purement visuel).
func _spawn_dust(r: Rect2) -> void:
	for k: int in 2:
		var h: float = _hash(t * 37.0 + float(k) * 11.0)
		var h2: float = _hash(t * 53.0 + float(k) * 7.0)
		var x: float = r.position.x + r.size.x * (1.0 - _scratch[_cursor]) + (h - 0.5) * 60.0
		_dust.append(Vector3(clampf(x, r.position.x, r.end.x), r.position.y + r.size.y * h2, DUST_LIFE))
		_dust_v.append(Vector2((h2 - 0.5) * 220.0, -60.0 - h * 120.0))
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


static func _hash(x: float) -> float:
	return fposmod(sin(x * 12.9898) * 43758.5453, 1.0)


## Reflet : une bande dorée balaie le ticket de gauche à droite. Les trèfles scintillent à
## chaque passage, les leurres une fois sur `decoy_chance` (tirés à l'entrée du reflet).
func _reflect(dt: float) -> void:
	var period: float = p("sweep_seconds") * slow
	var prev: float = _sweep
	_sweep = fmod(_sweep + dt / period, 1.0)
	if _sweep < prev:
		_passes += 1
		for i: int in GRID * GRID:
			_decoys[i] = rng.randf() < p("decoy_chance")
	var o: Vector2 = _ticket_origin()
	var w: float = float(GRID) * (CELL.x + GAP)
	for i2: int in GRID * GRID:
		_sparkle[i2] = maxf(0.0, _sparkle[i2] - dt * 2.5)
		var cx: float = (_cell_rect(i2).get_center().x - o.x) / w
		if prev < cx and _sweep >= cx and (_targets.has(i2) or _decoys[i2]) and not _done[i2]:
			_sparkle[i2] = 1.0
			_seen[i2] += 1
			if _targets.has(i2):
				AudioBus.play("shimmer", 1.6, -16.0)


func _reveal(i: int) -> void:
	_done[i] = true
	_tries += 1
	if _targets.has(i):
		_found += 1
		pop(_cell_rect(i).get_center() + Vector2(0, -80), 1.0, "TRIAL_SCRATCH_CLOVER")
		AudioBus.play("coins", 1.2, -4.0)
	else:
		pop(_cell_rect(i).get_center() + Vector2(0, -80), 0.0, "TRIAL_SCRATCH_BLANK")
		AudioBus.play("lose_soft", 1.0, -6.0)
	if _found >= 3 or _tries >= pi("tries"):
		_end_t = 0.8


# --------------------------------------------------------------------------- bot


func bot_wants() -> Dictionary:
	# Observe deux passages, puis gratte les cases qui ont scintillé à chaque passage.
	if _passes < 3:
		return {"do": ""}
	var best: int = -1
	var best_seen: int = -1
	for i: int in GRID * GRID:
		if not _done[i] and _seen[i] > best_seen:
			best_seen = _seen[i]
			best = i
	# Gestes de manette : relâcher, déplacer le curseur case par case, puis maintenir.
	if best != _cursor:
		if _holding:
			return {"do": "release"}
		var dx: int = best % GRID - _cursor % GRID
		var dy: int = floori(float(best) / GRID) - floori(float(_cursor) / GRID)
		return {"do": "dir", "dir": Vector2i(signi(dx), 0) if dx != 0 else Vector2i(0, signi(dy))}
	return {"do": "hold"}


func bot_apply(w: Dictionary) -> void:
	match String(w.get("do", "")):
		"hold":
			_holding = true
		"release":
			_holding = false
		"dir":
			var d: Vector2i = w["dir"] as Vector2i
			var x: int = clampi(_cursor % GRID + d.x, 0, GRID - 1)
			var y: int = clampi(floori(float(_cursor) / GRID) + d.y, 0, GRID - 1)
			_cursor = y * GRID + x


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	if stage == null:
		return
	if _neon != null:
		_neon.modulate.a = 0.85 + 0.15 * sin(t * 23.0) * sin(t * 3.0)
	var o: Vector2 = _ticket_origin()
	var w: float = float(GRID) * CELL.x + float(GRID - 1) * GAP
	var ticket: Rect2 = Rect2(o - Vector2(40, 110), Vector2(w + 80, float(GRID) * (CELL.y + GAP) + 140))
	_draw_ticket(ticket)
	text(Vector2(size.x * 0.5, o.y - 60.0), tr("TRIAL_SCRATCH_TICKET"), UiKit.SIZE_H2, Palette.GOLD_LIGHT, "display", 0)
	for i: int in GRID * GRID:
		var r: Rect2 = _cell_rect(i)
		draw_rect(r, Color("fffaf0"))
		draw_rect(r.grow(-6), Color(Palette.GOLD, 0.15), false, 1.0)
		if _done[i] or _scratch[i] > 0.0:
			var col: Color = Palette.EMERALD if _targets.has(i) else Palette.SMOKE_DARK
			text(r.get_center(), _cells[i], UiKit.SIZE_H1, col, "ui", 0)
		if not _done[i]:
			_draw_foil(r, 1.0 - _scratch[i], i)
			var s: float = _sparkle[i]
			if s > 0.0:
				var c: Vector2 = r.get_center()
				draw_line(c - Vector2(50 * s, 0), c + Vector2(50 * s, 0), Color(1, 0.95, 0.7, s), 4.0)
				draw_line(c - Vector2(0, 50 * s), c + Vector2(0, 50 * s), Color(1, 0.95, 0.7, s), 4.0)
				draw_circle(c, 14.0 * s, Color(1, 1, 0.85, s))
		var sel: bool = i == _cursor and not mouse
		draw_rect(r, Palette.CYAN if sel else Palette.GOLD_DARK, false, 5.0 if sel else 2.0)
	# Reflet qui balaie le ticket.
	var sx: float = o.x + _sweep * float(GRID) * (CELL.x + GAP)
	draw_colored_polygon(PackedVector2Array([Vector2(sx - 10, ticket.position.y + 20), Vector2(sx + 34, ticket.position.y + 20),
		Vector2(sx + 10, ticket.end.y - 20), Vector2(sx - 34, ticket.end.y - 20)]), Color(1, 0.9, 0.5, 0.12))
	for k: int in _dust.size():
		var d: Vector3 = _dust[k]
		draw_rect(Rect2(d.x - 2.0, d.y - 2.0, 4.0, 4.0), Color(FOIL, clampf(d.z / DUST_LIFE, 0.0, 1.0)))
	# Pièce qui gratte.
	if (_holding or _drag) and not _done[_cursor]:
		var cr: Rect2 = _cell_rect(_cursor)
		var cp: Vector2 = Vector2(cr.position.x + cr.size.x * (1.0 - _scratch[_cursor]), cr.get_center().y + sin(t * 30.0) * 40.0)
		draw_circle(cp + Vector2(4, 6), 30.0, Color(0, 0, 0, 0.35))
		draw_circle(cp, 30.0, Palette.GOLD)
		draw_arc(cp, 24.0, 0, TAU, 28, Palette.GOLD_DARK, 3.0)
		text(cp, "0", UiKit.SIZE_BODY, Palette.GOLD_DARK, "display", 0)
	var left: int = pi("tries") - _tries
	text(Vector2(size.x * 0.5, ticket.end.y + 50.0), tr("TRIAL_SCRATCH_STATUS") % [left, _found], UiKit.SIZE_BODY, Palette.IVORY)
	var tl: float = clampf(1.0 - t / (p("duration") * slow), 0.0, 1.0)
	draw_rect(Rect2(size.x * 0.5 - 300, ticket.end.y + 90.0, 600, 8), Color(Palette.INK, 0.7))
	draw_rect(Rect2(size.x * 0.5 - 300, ticket.end.y + 90.0, 600 * tl, 8), Palette.GOLD)


## Ticket : papier crème guilloché, bandeau bordeaux, perforations, numéro de série.
func _draw_ticket(tk: Rect2) -> void:
	draw_rect(Rect2(tk.position + Vector2(12, 16), tk.size), Color(0, 0, 0, 0.45))
	draw_rect(tk, Color("f4e7c8"))
	var band: Rect2 = Rect2(tk.position, Vector2(tk.size.x, 96.0))
	draw_rect(band, Palette.VELVET)
	draw_rect(Rect2(band.position.x, band.end.y - 6.0, band.size.x, 6.0), Palette.GOLD)
	# Guillochis : ondes croisées très pâles sous la grille.
	for k: int in 14:
		var pts: PackedVector2Array = PackedVector2Array()
		var y0: float = band.end.y + 20.0 + float(k) * (tk.size.y - 130.0) / 14.0
		for j: int in 33:
			var x: float = tk.position.x + tk.size.x * float(j) / 32.0
			pts.append(Vector2(x, y0 + sin(float(j) * 0.7 + float(k)) * 10.0))
		draw_polyline(pts, Color(Palette.VELVET, 0.07), 2.0)
	# Perforations des bords (demi-cercles sombres).
	for k2: int in 18:
		var px: float = tk.position.x + 20.0 + (tk.size.x - 40.0) * float(k2) / 17.0
		draw_circle(Vector2(px, tk.end.y), 6.0, Color("2a160c"))
	draw_rect(tk.grow(-10), Palette.GOLD, false, 3.0)
	text(Vector2(tk.end.x - 110.0, tk.end.y - 26.0), "N° 0%06d" % (int(_hash(float(pi("tries")) + float(_targets[0])) * 999999.0)),
		UiKit.SIZE_SMALL, Color(Palette.INK, 0.5), "ui", 0)


## Pellicule argentée moirée, grattée de droite à gauche en bandes irrégulières.
func _draw_foil(r: Rect2, cover: float, i: int) -> void:
	var bh: float = r.size.y / float(SCRATCH_DOTS)
	for b: int in SCRATCH_DOTS:
		var bw: float = r.size.x * clampf(cover * 1.4 - float(b % 3) * 0.2, 0.0, 1.0)
		var shade: float = 0.06 * sin(float(b) * 1.7 + float(i))
		draw_rect(Rect2(r.position + Vector2(r.size.x - bw, float(b) * bh), Vector2(bw, bh + 1.0)), FOIL.lightened(shade + 0.04))
		# Grain : quelques reflets fixes sur la part non grattée.
		for g: int in 6:
			var gx: float = _hash(float(i * 97 + b * 13 + g)) * r.size.x
			if gx > r.size.x - bw:
				draw_rect(Rect2(r.position + Vector2(gx, float(b) * bh + _hash(float(g + i)) * bh), Vector2(3, 3)), Color(1, 1, 1, 0.35))
	if cover >= 1.0:
		text(r.get_center(), "?", UiKit.SIZE_H1, Color(FOIL.darkened(0.3), 0.8), "display", 0)
