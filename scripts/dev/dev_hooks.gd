class_name DevHooks
extends Node
## Accès de développement (sources uniquement, exclu des exports) : captures d'écran,
## pilote automatique, accès direct à un écran ou une phase de run.
## Sauvegardes isolées dans `user://dev/` (cf. DevMode).
## -- --dev-run=lea [--dev-phase=shop|pact|summary|creditor|grigris] [--dev-debt-mult=0.5]
##    [--shot=user://shot.png] [--frames=120] [--dev-screen=options] [--dev-autoplay=N
##    --shot-dir=... --perf] [--quit-frames=N]


func start() -> bool:
	var args: Dictionary = DevMode.args()
	if Platform.is_emulated():
		_emulate_mobile()
	if args.has("dev-autoplay"):
		var ap: DevAutoplay = DevAutoplay.new()
		ap.spins_wanted = int(args["dev-autoplay"])
		ap.shot_dir = String(args.get("shot-dir", ""))
		ap.perf = args.has("perf")
		add_child(ap)
	if args.has("quit-frames"):
		_quit_later(int(args["quit-frames"]))
	if args.has("dev-mem"):
		_mem_report_later(int(args["dev-mem"]))
	if args.has("dev-hover"):
		_hover_later(String(args["dev-hover"]))
	if args.has("shot"):
		_capture_later(String(args["shot"]), int(args.get("frames", "120")))
	if args.has("dev-pad-run"):
		var pr: DevPadRun = DevPadRun.new()
		pr.spins_wanted = int(args["dev-pad-run"])
		pr.shot_dir = String(args.get("shot-dir", ""))
		pr.debt_mult = float(String(args.get("dev-debt-mult", "0")))
		add_child(pr)
		GameState.goto(&"title")
		return true
	if args.has("dev-trial-bench"):
		var tb: DevTrialBench = DevTrialBench.new()
		tb.runs = maxi(int(String(args["dev-trial-bench"])), 1) if String(args["dev-trial-bench"]) != "true" else 3
		add_child(tb)
		return true
	if args.has("dev-confirm-check"):
		add_child(DevConfirmCheck.new())
		return true
	if args.has("dev-ui-check"):
		add_child(DevUiCheck.new())
		return true
	if args.has("dev-screen"):
		var params: Dictionary = {}
		if args.has("dev-seed-code"):
			params["seed"] = String(args["dev-seed-code"])
		GameState.goto(StringName(String(args["dev-screen"])), params)
		return true
	if not args.has("dev-run"):
		return false
	GameState.controller = RunController.new(DataRegistry.db)
	GameState.controller.new_run(String(args["dev-run"]), int(args.get("dev-risk", "0")), int(args.get("dev-seed", "1")))
	var r: RunState = GameState.controller.run
	if args.has("dev-debt-mult"):
		r.flags["debt_mult"] = float(String(args["dev-debt-mult"]))
		r.debt = GameState.controller.debt_for(r.tier, r.deadline_idx)
	if args.has("dev-grigris"):
		for gid: String in String(args["dev-grigris"]).split(","):
			ShopModel.acquire_grigri(r, DataRegistry.db, gid, &"")
	if args.has("dev-locked"):
		for g: GrigriInstance in r.grigris:
			g.locked = true
	match String(args.get("dev-phase", "")):
		"shop":
			r.money = 30
			ShopModel.enter(r, DataRegistry.db)
		"pact":
			r.phase = RunState.Phase.PACT_OFFER
		"creditor":
			r.deadline_idx = 2
			GameState.controller.start_deadline()
		"grigris":
			r.total_spins = 1
			r.flags["act_intro_seen_1"] = true
			for gid: String in ["g_red_ribbon", "g_blueprint", "g_house_key", "g_ouroboros", "g_iou"]:
				ShopModel.acquire_grigri(r, DataRegistry.db, gid, &"holo" if gid == "g_house_key" else &"")
			r.fortunes = ["f_gild", "f_focus"]
			r.wheel.at(3).type_id = &"golden"
			r.wheel.at(4).type_id = &"glass"
			r.wheel.at(5).edition = &"polychrome"
			r.wheel.at(6).seal = &"seal_red"
			r.slip.place("red", 4)
			r.slip.place("straight:19", 2)
			r.slip.place("split:17-20", 1)
			r.slip.place("corner:1", 1)
	if String(args.get("dev-phase", "")) == "summary":
		GameState.end_run(false)
	else:
		GameState.goto(&"run")
	if String(args.get("dev-phase", "")) == "jackpot":
		r.flags["act_intro_seen_1"] = true
		r.flags["dev_rig"] = true
		r.flags["control_temp"] = 5.0
		r.flags["zone_width_override"] = 1
		r.debt = 1
	if String(args.get("dev-phase", "")) == "hud":
		r.flags["act_intro_seen_1"] = true
		r.flags["tutorial_off"] = true
	if String(args.get("dev-phase", "")) == "decor":
		r.flags["act_intro_seen_1"] = true
		_decor_demo.call_deferred()
	if String(args.get("dev-phase", "")) == "slot":
		r.flags["act_intro_seen_1"] = true
		_slot_later.call_deferred()
	if String(args.get("dev-phase", "")) == "bigscore":
		r.flags["act_intro_seen_1"] = true
		_bigscore_later.call_deferred()
	return true


## Super build simulé : Jetons et Mult gigantesques, pour vérifier formats compacts et flammes.
func _bigscore_later() -> void:
	for _i: int in 60:
		await get_tree().process_frame
	var panel: ScorePanel = get_tree().root.find_children("*", "ScorePanel", true, false)[0] as ScorePanel
	panel.set_values(48250.0, 12.0)
	for _i: int in 30:
		await get_tree().process_frame
	panel.set_values(3.2e6, 4800.0)
	panel.show_total(int(3.2e6 * 4800.0), 1.0)


## Machine à sous de démonstration : carré de 7, brelan de diamants, rien.
func _slot_later() -> void:
	for _i: int in 90:
		await get_tree().process_frame
	var rs: RunScreen = get_tree().root.find_children("*", "RunScreen", true, false)[0] as RunScreen
	var spins: Array[Dictionary] = [
		{"reels": ["seven", "seven", "seven", "seven"], "prize": "p_seven4"},
		{"reels": ["diamond", "diamond", "lemon", "diamond"], "prize": "p_diamond3"},
		{"reels": ["chip", "bell", "seven", "horseshoe"], "prize": ""},
	]
	rs.call("_show_overlay", SlotOverlay.new().configure(spins, DataRegistry.db))


## Mémoire vidéo : total, textures, tampons, et chaque SubViewport (taille, MSAA, mise à jour).
func _mem_report_later(frames: int) -> void:
	for _i: int in frames:
		await get_tree().process_frame
	var mb: float = 1024.0 * 1024.0
	print("MEM vidéo %.0f Mo · textures %.0f Mo · tampons %.0f Mo" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / mb,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / mb,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / mb,
	])
	var seen: Dictionary[RID, Array] = {}
	for n: Node in get_tree().root.find_children("*", "", true, false):
		_collect_textures(n, n, seen)
	var rows: Array = seen.values()
	rows.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) > int(y[0]))
	var total: float = 0.0
	for r: Array in rows:
		total += float(r[0])
	print("MEM textures atteignables : %d, ≈ %.0f Mo (RGBA8)" % [rows.size(), total / mb])
	for r: Array in rows.slice(0, 20):
		print("MEM  tex %5.1f Mo %s" % [float(r[0]) / mb, r[1]])
	for n: Node in get_tree().root.find_children("*", "SubViewport", true, false):
		var sv: SubViewport = n as SubViewport
		print("MEM  %s %s msaa=%d scale=%.2f hdr=%s maj=%d" % [
			sv.get_parent().name + "/" + sv.name, sv.size, sv.msaa_3d, sv.scaling_3d_scale, sv.use_hdr_2d, sv.render_target_update_mode,
		])


func _collect_textures(o: Object, owner_node: Node, seen: Dictionary[RID, Array], depth: int = 0) -> void:
	if o == null or depth > 3:
		return
	for prop: Dictionary in o.get_property_list():
		if int(prop["type"]) != TYPE_OBJECT or not (int(prop["usage"]) & PROPERTY_USAGE_STORAGE):
			continue
		var v: Variant = o.get(String(prop["name"]))
		if v is Texture2D and not (v is ViewportTexture):
			var t: Texture2D = v as Texture2D
			if not seen.has(t.get_rid()):
				var label: String = "%dx%d %s ← %s.%s" % [t.get_width(), t.get_height(), t.resource_path, owner_node.get_path(), prop["name"]]
				seen[t.get_rid()] = [t.get_width() * t.get_height() * 4, label]
		elif v is Material or v is Mesh or v is StyleBox or v is Theme:
			_collect_textures(v as Object, owner_node, seen, depth + 1)
	var sm: ShaderMaterial = o as ShaderMaterial
	if sm != null and sm.shader != null:
		for u: Dictionary in sm.shader.get_shader_uniform_list():
			var tv: Variant = sm.get_shader_parameter(String(u["name"]))
			if tv is Texture2D and not (tv is ViewportTexture) and not seen.has((tv as Texture2D).get_rid()):
				var tt: Texture2D = tv as Texture2D
				var what: String = "%dx%d shader %s ← %s" % [tt.get_width(), tt.get_height(), u["name"], owner_node.get_path()]
				seen[tt.get_rid()] = [tt.get_width() * tt.get_height() * 4, what]


func _quit_later(frames: int) -> void:
	for _i: int in frames:
		await get_tree().process_frame
	GameState.quit_game()


func _capture_later(path: String, frames: int) -> void:
	for _i: int in frames:
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("Capture : ", ProjectSettings.globalize_path(path))
	GameState.quit_game()


## Survole une suite de points « x,y;x,y » (coordonnées fenêtre), 1,5 s chacun : QA des infobulles.
## « x,y,l » ou « x,y,r » clique (gauche/droit) avant de survoler.
func _hover_later(points: String) -> void:
	for _i: int in 90:
		await get_tree().process_frame
	for p: String in points.split(";"):
		var xy: PackedStringArray = p.split(",")
		# p = appuyer, r = relâcher, m = glisser bouton enfoncé (gestes au doigt émulés).
		if xy.size() == 3 and xy[2] in ["p", "r", "m"]:
			await _pointer_step(Vector2(float(xy[0]), float(xy[1])), xy[2])
			continue
		if xy.size() == 3:
			for down: bool in [true, false]:
				var b: InputEventMouseButton = InputEventMouseButton.new()
				b.button_index = MOUSE_BUTTON_LEFT if xy[2] == "l" else MOUSE_BUTTON_RIGHT
				b.pressed = down
				b.position = Vector2(float(xy[0]), float(xy[1]))
				b.global_position = b.position
				Input.parse_input_event(b)
				await get_tree().process_frame
		var ev: InputEventMouseMotion = InputEventMouseMotion.new()
		ev.position = Vector2(float(xy[0]), float(xy[1]))
		ev.global_position = ev.position
		ev.relative = Vector2(3, 3)
		Input.parse_input_event(ev)
		await get_tree().create_timer(1.5).timeout


func _pointer_step(at: Vector2, step: String) -> void:
	if step == "m":
		var mm: InputEventMouseMotion = InputEventMouseMotion.new()
		mm.position = at
		mm.global_position = at
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		mm.relative = Vector2(4, 4)
		Input.parse_input_event(mm)
	else:
		var b: InputEventMouseButton = InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = step == "p"
		b.position = at
		b.global_position = at
		Input.parse_input_event(b)
	for _i: int in 20:
		await get_tree().process_frame


## Démonstration du décor : chaque objet est secoué tour à tour (bouteille et jetons : jusqu'à la chute).
func _decor_demo() -> void:
	for _i: int in 60:
		await get_tree().process_frame
	var rs: RunScreen = get_tree().root.find_children("*", "RunScreen", true, false)[0] as RunScreen
	if rs.decor == null:
		return
	for pr: DecorProp in rs.decor.props:
		if pr is DecorCritter:
			(pr as DecorCritter).call("set", "_timer", 0.0)
	for pr2: DecorProp in rs.decor.props:
		var n: int = 4 if pr2.kind == "bottle" else (3 if pr2.kind == "chips" else 1)
		for _k: int in n:
			pr2.poke()
			await get_tree().create_timer(0.25).timeout
		await get_tree().create_timer(0.6).timeout


## Émulation mobile : fenêtre au format du téléphone (réduite pour tenir à l'écran), toucher
## émulé par la souris. Le profil tactile et la zone sûre simulée viennent de `Platform`.
func _emulate_mobile() -> void:
	Input.emulate_touch_from_mouse = true
	if DisplayServer.get_name() == "headless":
		return
	var phone: Vector2 = Vector2(Platform.emulated_size())
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var k: float = minf(1.0, minf(float(usable.size.x) * 0.95 / phone.x, float(usable.size.y) * 0.9 / phone.y))
	if DevMode.args().has("shot"):
		k = 1.0  # captures à la définition réelle du téléphone
	var win: Vector2i = Vector2i((phone * k).round())
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(win)
	DisplayServer.window_set_position(usable.position + (usable.size - win) / 2)
