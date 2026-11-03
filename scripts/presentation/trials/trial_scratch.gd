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
		if _scratch[_cursor] >= 1.0:
			_reveal(_cursor)
	if t >= p("duration") * slow and _end_t < 0.0:
		_end_t = 0.6


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
	draw_rect(Rect2(-size.x, 0, size.x * 3.0, size.y), Color("1a0f14"))
	# Comptoir du buraliste : bois, tickets épinglés, néon « FORTUNE ».
	draw_rect(Rect2(-size.x, size.y * 0.78, size.x * 3.0, size.y * 0.22), Color("3a2214"))
	for k: int in 8:
		var tx: float = 80.0 + float(k) * 240.0
		if absf(tx - size.x * 0.5) < 420.0:
			continue
		draw_rect(Rect2(tx, 160.0 + float(k % 2) * 60.0, 140, 200), Color(Palette.IVORY, 0.12))
	var o: Vector2 = _ticket_origin()
	var w: float = float(GRID) * CELL.x + float(GRID - 1) * GAP
	var ticket: Rect2 = Rect2(o - Vector2(40, 110), Vector2(w + 80, float(GRID) * (CELL.y + GAP) + 140))
	draw_rect(Rect2(ticket.position + Vector2(10, 14), ticket.size), Color(0, 0, 0, 0.4))
	draw_rect(ticket, Color("f4e7c8"))
	draw_rect(ticket.grow(-10), Palette.GOLD, false, 4.0)
	text(Vector2(size.x * 0.5, o.y - 60.0), tr("TRIAL_SCRATCH_TICKET"), UiKit.SIZE_H2, Palette.VELVET, "display", 0)
	for i: int in GRID * GRID:
		var r: Rect2 = _cell_rect(i)
		draw_rect(r, Color("fffaf0"))
		if _done[i] or _scratch[i] > 0.0:
			var col: Color = Palette.EMERALD if _targets.has(i) else Palette.SMOKE_DARK
			text(r.get_center(), _cells[i], UiKit.SIZE_H1, col, "ui", 0)
		if not _done[i]:
			# Pellicule argentée, grattée en bandes ; la part grattée laisse voir le symbole.
			var cover: float = 1.0 - _scratch[i]
			for b: int in SCRATCH_DOTS:
				var bh: float = r.size.y / float(SCRATCH_DOTS)
				var bw: float = r.size.x * clampf(cover * 1.4 - float(b % 3) * 0.2, 0.0, 1.0)
				draw_rect(Rect2(r.position + Vector2(r.size.x - bw, float(b) * bh), Vector2(bw, bh + 1.0)), Color("b8b8c4"))
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
	draw_rect(Rect2(sx - 18, ticket.position.y + 20, 36, ticket.size.y - 40), Color(1, 0.9, 0.5, 0.12))
	var left: int = pi("tries") - _tries
	text(Vector2(size.x * 0.5, ticket.end.y + 50.0), tr("TRIAL_SCRATCH_STATUS") % [left, _found], UiKit.SIZE_BODY, Palette.IVORY)
	var tl: float = clampf(1.0 - t / (p("duration") * slow), 0.0, 1.0)
	draw_rect(Rect2(size.x * 0.5 - 300, ticket.end.y + 90.0, 600 * tl, 8), Palette.GOLD)
