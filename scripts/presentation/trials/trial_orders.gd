class_name TrialOrders
extends ThrowTrial
## LES COMMANDES (Cuisines, 2.0) : les bons arrivent sur le rail du passe. Chacun montre sa
## recette (gin, citron, sucre, glace, dans l'ordre) quelques instants, puis se retourne : il faut
## l'avoir retenue. Plusieurs bons attendent à la fois, chacun avec sa patience : choisir lequel
## servir, puis verser les ingrédients. Un mauvais ingrédient : le verre part à l'évier, on
## recommence. Un bon qui expire est perdu.
## Note = moyenne des bons (servi juste : plein moins une part du temps d'attente ; raté : rien).

const INGREDIENTS: int = 4
const ING_COLORS: Array[Color] = [Color("d8e8f0"), Color("ffe04a"), Color("f2efe8"), Color("8ad8ff")]
const ING_ACTIONS: Array[StringName] = [&"qte_left", &"qte_up", &"qte_right", &"qte_down"]
const ARROWS: Array[Vector2] = [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN]
const PX3: float = 0.005
const COUNTER_Y: float = 780.0
const RAIL_Y: float = 150.0
const TICKET: Vector2 = Vector2(250.0, 230.0)
const SLOTS: int = 3
const STATION_Y: float = 900.0
const STATION_W: float = 200.0

var _tickets: Array[Dictionary] = []  # {"recipe", "born", "slot", "done": -1 | note, "ruined"}
var _spawned: int = 0
var _next_t: float = 0.0
var _cursor: int = 0
var _poured: Array[int] = []
var _marks: Array[float] = []
var _ruins: int = 0
var _ended: bool = false
var _bot_queue: Array[Dictionary] = []
var _deco: Dictionary = {}
var _barman: Figure3D = null
var _glass_layers: Array[MeshInstance3D] = []
var _flash: Array[float] = [0.0, 0.0, 0.0, 0.0]


func begin() -> void:
	_next_t = p("first_ticket")
	_build_3d()


func _total() -> int:
	return pi("tickets")


func _patience() -> float:
	return p("patience") * slow


func _spawn() -> void:
	var used: Array[int] = []
	for tk: Dictionary in _tickets:
		if int(tk["done"]) < 0:
			used.append(int(tk["slot"]))
	var slot: int = -1
	for s: int in SLOTS:
		if not used.has(s):
			slot = s
			break
	if slot < 0:
		_next_t = t + 0.5
		return
	var n: int = int(pk("recipe_len", _spawned))
	var recipe: Array[int] = []
	for k: int in n:
		var ing: int = rng.randi_range(0, INGREDIENTS - 1)
		if k > 0 and ing == recipe[-1] and rng.randf() < 0.6:
			ing = (ing + 1 + rng.randi_range(0, INGREDIENTS - 2)) % INGREDIENTS
		recipe.append(ing)
	_tickets.append({"recipe": recipe, "born": t, "slot": slot, "done": -1, "ruined": 0, "name": rng.randi_range(0, 5)})
	_spawned += 1
	_next_t = t + p("ticket_every") * slow
	AudioBus.play("paper", 1.1, -6.0)
	if _active().size() == 1:
		_cursor = slot


func _active() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for tk: Dictionary in _tickets:
		if int(tk["done"]) < 0:
			out.append(tk)
	return out


func _ticket_at(slot: int) -> Dictionary:
	for tk: Dictionary in _active():
		if int(tk["slot"]) == slot:
			return tk
	return {}


func _peek(tk: Dictionary) -> bool:
	return t - float(tk["born"]) < p("peek_seconds") * slow


func tick(dt: float) -> void:
	for i: int in INGREDIENTS:
		_flash[i] = maxf(0.0, _flash[i] - dt * 4.0)
	_sync_3d(dt)
	if _ended:
		return
	if _spawned < _total() and t >= _next_t:
		_spawn()
	for tk: Dictionary in _active():
		if t - float(tk["born"]) > _patience():
			tk["done"] = 1
			_marks.append(0.0)
			pop(_slot_pos(int(tk["slot"])) + Vector2(0, 140.0), 0.0, "TRIAL_ORDERS_EXPIRED")
			AudioBus.play("lose_soft", 1.0, -6.0)
			if int(tk["slot"]) == _cursor:
				_poured.clear()
	if _spawned >= _total() and _active().is_empty():
		_ended = true
		finish(ThrowTrial.mean(_marks) if not _marks.is_empty() else 0.0)


func select(slot: int) -> void:
	if slot == _cursor or _ended:
		return
	_cursor = clampi(slot, 0, SLOTS - 1)
	_poured.clear()
	AudioBus.play("tick", 1.3, -10.0)


func pour(ing: int) -> void:
	if _ended:
		return
	_flash[ing] = 1.0
	var tk: Dictionary = _ticket_at(_cursor)
	if tk.is_empty():
		AudioBus.play("sticky", 1.2, -10.0)
		return
	var recipe: Array[int] = tk["recipe"]
	AudioBus.play("decor_bottle", 1.0 + 0.1 * float(ing), -6.0)
	if recipe[_poured.size()] != ing:
		_poured.clear()
		tk["ruined"] = int(tk["ruined"]) + 1
		_ruins += 1
		pop(_slot_pos(_cursor) + Vector2(0, 140.0), 0.0, "TRIAL_ORDERS_WRONG")
		AudioBus.play("glass", 0.8, -4.0)
		return
	_poured.append(ing)
	if _poured.size() == recipe.size():
		var waited: float = (t - float(tk["born"])) / _patience()
		var late: float = p("wait_weight") * maxf(0.0, waited - p("grace"))
		var q: float = clampf(1.0 - late - p("ruin_penalty") * float(tk["ruined"]), 0.0, 1.0)
		tk["done"] = 1
		_marks.append(q)
		_poured.clear()
		pop(_slot_pos(_cursor) + Vector2(0, 140.0), q, "TRIAL_ORDERS_SERVED")
		AudioBus.play("chime", 1.2, -4.0)
		# Le curseur passe au bon suivant le plus pressé.
		var best: Dictionary = {}
		for o: Dictionary in _active():
			if best.is_empty() or float(o["born"]) < float(best["born"]):
				best = o
		if not best.is_empty():
			_cursor = int(best["slot"])


func handle(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_click(mb.position)
		return true
	var ea: InputEventAction = event as InputEventAction
	if ea != null and ING_ACTIONS.has(ea.action):
		if ea.pressed:
			pour(ING_ACTIONS.find(ea.action))
		return true
	var s: int = sym_pressed(event)
	if s >= 0:
		pour(s)
		return true
	var d: Vector2i = dir_pressed(event)
	if d.x != 0:
		select(posmod(_cursor + d.x, SLOTS))
		return true
	return false


func _click(pos: Vector2) -> void:
	for s: int in SLOTS:
		if Rect2(_slot_pos(s) - TICKET * 0.5, TICKET).has_point(pos):
			select(s)
			return
	for i: int in INGREDIENTS:
		if _station_rect(i).grow(10.0).has_point(pos):
			pour(i)
			return


func direct_input(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_click(mb.position)
	return true


func journal() -> Dictionary:
	return {"tickets": _total(), "ruined": _ruins}


# --------------------------------------------------------------------------- bot


## Sert le bon le plus ancien : s'y placer, puis verser sa recette (qu'il a « retenue »).
func bot_wants() -> Dictionary:
	var act: Array[Dictionary] = _active()
	if act.is_empty():
		return {"do": ""}
	var best: Dictionary = act[0]
	for o: Dictionary in act:
		if float(o["born"]) < float(best["born"]):
			best = o
	var slot: int = int(best["slot"])
	if slot != _cursor:
		var cur: Dictionary = _ticket_at(_cursor)
		if cur.is_empty() or _poured.is_empty():
			return {"do": "dir", "dir": Vector2i(1 if slot > _cursor else -1, 0)}
		best = cur
	var recipe: Array[int] = best["recipe"]
	return {"do": "sym", "symbol": recipe[_poured.size()]}


func bot_apply(w: Dictionary) -> void:
	match String(w.get("do", "")):
		"sym":
			pour(int(w["symbol"]))
		"dir":
			select(posmod(_cursor + (w["dir"] as Vector2i).x, SLOTS))


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	_deco = KitchenSet.build(st, COUNTER_Y)
	var r: Node3D = st.root
	_barman = KitchenSet.chef(1.8, true)
	_barman.position = st.to3(Vector2(960.0, COUNTER_Y), -1.0)
	r.add_child(_barman)
	# Les quatre postes : bouteille de gin, citrons, sucrier, seau à glace.
	var glass_m: StandardMaterial3D = Stage3D.mat(Color(0.85, 0.95, 1.0, 0.5), 0.0, 0.05)
	glass_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var brass: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.8, 0.3)
	for i: int in INGREDIENTS:
		var at: Vector3 = st.to3(Vector2(_station_rect(i).get_center().x, COUNTER_Y), 0.0)
		match i:
			0:
				Stage3D.cylinder(r, 0.1, 0.42, at + Vector3(0, 0.21, 0), glass_m)
				Stage3D.cylinder(r, 0.03, 0.16, at + Vector3(0, 0.5, 0), glass_m)
				Stage3D.box(r, Vector3(0.16, 0.12, 0.01), at + Vector3(0, 0.22, 0.1), Stage3D.mat(Palette.IVORY, 0.0, 0.8))
			1:
				Stage3D.cylinder(r, 0.18, 0.08, at + Vector3(0, 0.04, 0), Stage3D.mat(Color("f2efe8"), 0.0, 0.3), 0.14)
				for k: int in 4:
					var lemon: MeshInstance3D = Stage3D.sphere(r, 0.06, at + Vector3(-0.06 + 0.04 * float(k), 0.11 + 0.03 * float(k % 2), 0.02 * float(k)),
						Stage3D.mat(ING_COLORS[1], 0.0, 0.5))
					lemon.scale = Vector3(1.3, 1.0, 1.0)
			2:
				Stage3D.cylinder(r, 0.1, 0.18, at + Vector3(0, 0.09, 0), Stage3D.mat(Color("e8e8f0"), 0.2, 0.2))
				Stage3D.sphere(r, 0.1, at + Vector3(0, 0.18, 0), Stage3D.mat(Color("e8e8f0"), 0.2, 0.2))
				Stage3D.sphere(r, 0.025, at + Vector3(0, 0.29, 0), brass)
			3:
				Stage3D.cylinder(r, 0.15, 0.24, at + Vector3(0, 0.12, 0), Stage3D.mat(Color("c8ccd4"), 0.9, 0.25), 0.12)
				for k2: int in 5:
					Stage3D.box(r, Vector3(0.06, 0.06, 0.06), at + Vector3(-0.08 + 0.04 * float(k2), 0.26, 0.02 * float(k2 % 2)), glass_m)
	# Le verre à cocktail au centre : il se remplit couche par couche.
	var g_at: Vector3 = st.to3(Vector2(960.0, COUNTER_Y), 0.2)
	Stage3D.cylinder(r, 0.07, 0.01, g_at + Vector3(0, 0.005, 0), glass_m)
	Stage3D.cylinder(r, 0.01, 0.14, g_at + Vector3(0, 0.08, 0), glass_m)
	Stage3D.cylinder(r, 0.15, 0.16, g_at + Vector3(0, 0.23, 0), glass_m, 0.02)
	for k3: int in 4:
		var layer: MeshInstance3D = Stage3D.cylinder(r, 0.04 + 0.028 * float(k3 + 1), 0.04, g_at + Vector3(0, 0.17 + 0.04 * float(k3), 0),
			Stage3D.mat(Color.WHITE, 0.0, 0.3), 0.04 + 0.028 * float(k3))
		layer.visible = false
		_glass_layers.append(layer)


func _sync_3d(dt: float) -> void:
	if _barman == null:
		return
	for k: int in _glass_layers.size():
		_glass_layers[k].visible = k < _poured.size()
		if k < _poured.size():
			(_glass_layers[k].material_override as StandardMaterial3D).albedo_color = ING_COLORS[_poured[k]].darkened(0.1)
	var target_x: float = _station_rect(_poured[-1]).get_center().x if not _poured.is_empty() else 960.0
	var bx: Vector3 = stage.to3(Vector2(target_x, COUNTER_Y), -1.0)
	_barman.position.x = lerpf(_barman.position.x, bx.x, minf(1.0, dt * 6.0))
	var busy: float = _flash.max()
	_barman.animate(&"throw" if busy > 0.0 else &"idle", 1.0 - busy, dt)
	KitchenSet.animate(_deco, stage, COUNTER_Y, t, 0.5)


# --------------------------------------------------------------------------- dessin


func _slot_pos(s: int) -> Vector2:
	return Vector2(960.0 + (float(s) - 1.0) * (TICKET.x + 60.0), RAIL_Y + TICKET.y * 0.5 + 20.0)


func _station_rect(i: int) -> Rect2:
	var x0: float = 960.0 - 2.0 * STATION_W - 60.0 + float(i) * (STATION_W + 40.0)
	if i >= 2:
		x0 += 120.0
	return Rect2(x0, STATION_Y, STATION_W, 96.0)


func paint() -> void:
	# Rail du passe, bons accrochés : recette visible un instant, puis seulement le nom.
	draw_rect(Rect2(480.0, RAIL_Y, 960.0, 8.0), Color("c8ccd4"))
	for s: int in SLOTS:
		var tk: Dictionary = _ticket_at(s)
		var c: Vector2 = _slot_pos(s)
		var rr: Rect2 = Rect2(c - TICKET * 0.5, TICKET)
		if tk.is_empty():
			draw_rect(rr, Color(Palette.INK, 0.35), false, 2.0)
			continue
		var left: float = clampf(1.0 - (t - float(tk["born"])) / _patience(), 0.0, 1.0)
		draw_rect(rr, Color("f4ecd8"))
		draw_rect(Rect2(rr.position, Vector2(rr.size.x, 30.0)), Palette.ROULETTE_RED if left < 0.3 else Color("2a2a34"))
		draw_rect(Rect2(rr.position + Vector2(0, 30.0), Vector2(rr.size.x * left, 6.0)), Palette.EMERALD if left >= 0.3 else Palette.ROULETTE_RED)
		var title: String = tr("TRIAL_ORDERS_NAME_%d" % int(tk["name"]))
		text(rr.position + Vector2(rr.size.x * 0.5, 15.0), title, UiKit.SIZE_SMALL, Palette.IVORY, "body", 4)
		var recipe: Array[int] = tk["recipe"]
		var show: bool = _peek(tk)
		for k: int in recipe.size():
			var at: Vector2 = rr.position + Vector2(rr.size.x * (float(k) + 0.5) / float(recipe.size()), 110.0)
			var done: bool = s == _cursor and k < _poured.size()
			if show or done:
				_ingredient(at, recipe[k], 24.0)
			else:
				draw_circle(at, 22.0, Color("d8ccb0"))
				text(at, "?", UiKit.SIZE_BODY, Color("8a7a5a"), "display", 0)
			if done:
				draw_arc(at, 28.0, 0, TAU, 24, Palette.EMERALD, 4.0)
		if show:
			var peek: float = 1.0 - (t - float(tk["born"])) / (p("peek_seconds") * slow)
			draw_rect(Rect2(rr.position + Vector2(10, rr.size.y - 40.0), Vector2((rr.size.x - 20) * peek, 8.0)), Palette.GOLD)
			text(rr.position + Vector2(rr.size.x * 0.5, rr.size.y - 60.0), tr("TRIAL_ORDERS_REMEMBER"), UiKit.SIZE_SMALL, Color("8a5a1a"), "body", 0)
		if s == _cursor:
			draw_rect(rr.grow(8.0), Palette.GOLD_LIGHT, false, 5.0)
	# Postes d'ingrédients.
	for i: int in INGREDIENTS:
		var sr: Rect2 = _station_rect(i)
		draw_rect(sr, Color(Palette.INK, 0.82))
		draw_rect(sr, Color(ING_COLORS[i], 0.4 + 0.6 * _flash[i]), false, 3.0 + 3.0 * _flash[i])
		_key(sr.position + Vector2(40.0, sr.size.y * 0.5), i)
		text(sr.position + Vector2(sr.size.x * 0.62, sr.size.y * 0.5), tr("TRIAL_ORDERS_ING_%d" % i), UiKit.SIZE_SMALL, Palette.IVORY, "body", 4)
	text(Vector2(960.0, 105.0), tr("TRIAL_ORDERS_STATUS") % [_marks.size(), _total()], UiKit.SIZE_BODY, Palette.IVORY)


## Ingrédient dessiné : pastille colorée et forme distincte (lisible sans les couleurs).
func _ingredient(at: Vector2, i: int, r: float) -> void:
	draw_circle(at, r, ING_COLORS[i])
	draw_arc(at, r, 0, TAU, 24, Color(Palette.INK, 0.6), 2.0)
	var ink: Color = Color(Palette.INK, 0.8)
	match i:
		0:
			draw_rect(Rect2(at - Vector2(5, 12), Vector2(10, 24)), ink)
		1:
			draw_circle(at, r * 0.45, ink)
		2:
			draw_rect(Rect2(at - Vector2(9, 9), Vector2(18, 18)), ink, false, 4.0)
		_:
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -11), at + Vector2(10, 7), at + Vector2(-10, 7)]), ink)


func _key(at: Vector2, i: int) -> void:
	if InputGlyphs.using_pad:
		for part: String in InputGlyphs.parts_for(String(ING_ACTIONS[i])):
			var tex: Texture2D = InputGlyphs.texture(part)
			if tex != null:
				draw_texture_rect(tex, Rect2(at - Vector2(22, 22), Vector2(44, 44)), false)
				return
	_ingredient(at, i, 22.0)
	var d: Vector2 = ARROWS[i]
	draw_line(at - d * 30.0, at - d * 40.0, Palette.GOLD_LIGHT, 4.0)
