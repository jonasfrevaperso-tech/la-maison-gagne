extends TestCase
## 1.3 : gâchettes (un appui = une action), curseur du tapis par demi-cases.


func _motion(axis: JoyAxis, v: float) -> InputEventJoypadMotion:
	var m: InputEventJoypadMotion = InputEventJoypadMotion.new()
	m.axis = axis
	m.axis_value = v
	return m


func test_trigger_counts_once_per_press() -> void:
	GameInput.reset()
	var hits: int = 0
	# Un appui analogique réel : des dizaines de valeurs croissantes puis décroissantes.
	for v: float in [0.1, 0.4, 0.62, 0.7, 0.85, 1.0, 0.95, 0.9, 0.5, 0.4, 0.35, 0.65, 0.8, 0.2, 0.0, 0.7, 1.0, 0.0]:
		var m: InputEventJoypadMotion = _motion(JOY_AXIS_TRIGGER_LEFT, v)
		if GameInput.pressed(m, "speed_toggle"):
			hits += 1
		# Un second gestionnaire qui lit le même événement obtient la même réponse.
		GameInput.pressed(m, "speed_toggle")
	eq(hits, 2, "deux appuis francs (le rebond à 0,35–0,65 ne compte pas)")
	check(not GameInput.pressed(_motion(JOY_AXIS_TRIGGER_RIGHT, 1.0), "speed_toggle"), "autre gâchette : autre action")


func _table() -> TableView:
	var t: TableView = TableView.new()
	t.size = Vector2(1400, 520)
	t._layout()
	return t


func test_half_step_cursor_reaches_inside_bets_quickly() -> void:
	var t: TableView = _table()
	t.move_cursor(0, 0)  # premier appui : active le curseur
	var start: String = t.cursor_spot()
	check(start.begins_with("straight:"), "départ sur un plein (%s)" % start)
	t.move_cursor(1, 0)
	check(t.cursor_spot().begins_with("split:"), "1 pas à droite : cheval (%s)" % t.cursor_spot())
	t.move_cursor(0, 1)
	check(t.cursor_spot().begins_with("corner:"), "1 pas en bas : carré (%s)" % t.cursor_spot())
	t.move_cursor(1, 0)
	check(t.cursor_spot().begins_with("split:"), "puis cheval vertical (%s)" % t.cursor_spot())
	for _i: int in 3:
		t.move_cursor(0, 1)
	check(t.cursor_spot().begins_with("dozen:"), "plus bas : douzaines (%s)" % t.cursor_spot())
	t.move_cursor(0, 1)
	check(BetCatalog.get_spot(t.cursor_spot()).outside, "puis chances simples (%s)" % t.cursor_spot())
	t.free()


func test_cursor_covers_every_bet_spot() -> void:
	var t: TableView = _table()
	var seen: Dictionary[String, bool] = {}
	for fy: int in TableView.FINE_Y_MAX + 1:
		for fx: int in range(TableView.FINE_X_MIN, TableView.FINE_X_MAX + 1):
			var sp: String = t._fine_spot(t._clamp_x(fx, fy), fy)
			if sp != "":
				seen[sp] = true
	var missing: Array[String] = []
	for s: BetSpot in BetCatalog.all():
		if not seen.has(s.id):
			missing.append(s.id)
	eq(missing, [] as Array[String], "tous les emplacements sont accessibles au curseur")
	t.free()
