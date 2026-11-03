class_name Main
extends Node
## Racine du jeu : change d'écran sur demande d'EventBus, porte les couches globales
## (post-traitement CRT, toasts, transitions).

const SCREENS: Dictionary[StringName, String] = {
	&"title": "res://scenes/ui/title_screen.tscn",
	&"character_select": "res://scenes/ui/character_select.tscn",
	&"run": "res://scenes/run/run_screen.tscn",
	&"summary": "res://scenes/ui/run_summary.tscn",
	&"options": "res://scenes/ui/options_screen.tscn",
	&"credits": "res://scenes/ui/credits_screen.tscn",
	&"codex": "res://scenes/meta/codex_screen.tscn",
	&"hall": "res://scenes/meta/hall_screen.tscn",
	&"achievements": "res://scenes/meta/achievements_screen.tscn",
	&"stats": "res://scenes/meta/stats_screen.tscn",
	&"seed_race": "res://scenes/meta/seed_race_screen.tscn",
	&"intro": "res://scenes/ui/intro_cutscene.tscn",
}

## Écrans lourds : carton de chargement (chargement en tâche de fond, chauffe du rendu).
const HEAVY_SCREENS: Array[StringName] = [&"run", &"summary"]
## Images rendues derrière les rideaux fermés avant de les ouvrir (premières compilations) ;
## écran lourd : jusqu'à ce qu'aucun pipeline graphique ne se compile plus (borné).
const SETTLE_FRAMES: int = 3
const SETTLE_QUIET_FRAMES: int = 6
const SETTLE_MAX_MS: int = 2500
const SETTLE_LIGHT_MS: int = 700

## Surcouches modales qui reçoivent la navigation manette à la place de l'écran.
const MODAL_CLASSES: Array[String] = ["Overlay", "DialogueOverlay", "ActTitle"]

var _screen_layer: CanvasLayer = null
## Cadre des écrans (cf. UiLayout.fit_frame).
var _frame: Control = null
var _overlay_layer: CanvasLayer = null
var _current: Node = null
var _transition: ScreenTransition = null
var _loading: LoadingScreen = null


func _ready() -> void:
	_screen_layer = CanvasLayer.new()
	_screen_layer.layer = 0
	add_child(_screen_layer)
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_layer.add_child(_frame)
	_fit_frame()
	get_viewport().size_changed.connect(_fit_frame)
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 50
	add_child(_overlay_layer)
	_transition = ScreenTransition.new()
	_overlay_layer.add_child(_transition)
	_loading = LoadingScreen.new()
	_overlay_layer.add_child(_loading)
	var toasts: ToastLayer = ToastLayer.new()
	_overlay_layer.add_child(toasts)
	var post: PostFx = PostFx.new()
	add_child(post)
	add_child(HitchMonitor.new())
	if Platform.is_mobile():
		add_child(FrameGovernor.new())
		add_child(TouchHelper.new())
		var life: AppLifecycle = AppLifecycle.new()
		life.active_root = _active_root
		add_child(life)
	EventBus.screen_requested.connect(_on_screen_requested)
	EventBus.note_requested.connect(_open_note)
	var nav: PadNavigator = PadNavigator.new()
	nav.active_root = _active_root
	nav.frame_layer = _overlay_layer
	add_child(nav)
	move_child(nav, 0)  # reçoit les entrées non consommées en dernier
	# Dernier nœud de l'arbre : voit chaque entrée avant tous les écrans (stick, gâchettes).
	get_tree().root.add_child.call_deferred(StickRepeater.new())
	if not _dev_hooks():
		_splash()


## Écran « Conçu avec… » au lancement, puis l'écran titre (chargé derrière le fondu).
func _splash() -> void:
	var sp: SplashScreen = SplashScreen.new()
	_overlay_layer.add_child(sp)
	_overlay_layer.move_child(sp, 0)
	sp.finished.connect(func() -> void: GameState.goto(&"title"))


## Options de développement : chargées dynamiquement, absentes des exports (cf. DevMode).
func _dev_hooks() -> bool:
	if not DevMode.active():
		return false
	var hooks: Node = (load(DevMode.HOOKS_SCRIPT) as GDScript).new()
	add_child(hooks)
	return bool(hooks.call("start"))


## Zone qui reçoit la navigation manette : la surcouche visible la plus récente, sinon l'écran.
func _active_root() -> Control:
	var best: Control = null
	for layer: Node in [_current, _overlay_layer]:
		if layer == null:
			continue
		for cls: String in MODAL_CLASSES:
			for o: Node in layer.find_children("*", cls, true, false):
				if (o as Control).is_visible_in_tree() and not o.is_queued_for_deletion():
					best = o as Control
	return best if best != null else _current as Control


## Périphérique courant (invites), note de test (F8 / R3), plein écran (F11, Alt+Entrée).
func _input(event: InputEvent) -> void:
	if InputGlyphs.note_event(event):
		EventBus.input_device_changed.emit(InputGlyphs.using_pad)
	if GameInput.pressed(event, "playtest_note"):
		_open_note()
		get_viewport().set_input_as_handled()
		return
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
		var windowed: bool = Settings.s("video", "window_mode") == "windowed"
		Settings.set_value("video", "window_mode", "fullscreen" if windowed else "windowed")
		get_viewport().set_input_as_handled()


func _fit_frame() -> void:
	if Platform.is_mobile():
		# Téléphone : les écrans restent dans la zone sûre (poinçon de la caméra, barre de gestes).
		var safe: Rect2 = Platform.safe_rect(get_viewport())
		UiLayout.fit_frame(_frame, safe.size)
		_frame.position = safe.position
		return
	UiLayout.fit_frame(_frame, get_viewport().get_visible_rect().size)


## Note de test : capture l'écran tel quel, puis ouvre le formulaire par-dessus.
func _open_note() -> void:
	if _overlay_layer.get_children().any(func(c: Node) -> bool: return c is NoteOverlay):
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var o: NoteOverlay = NoteOverlay.new().configure(img, String(GameState.current_screen))
	_overlay_layer.add_child(o)


func _exit_tree() -> void:
	InputGlyphs.clear_cache()
	UiKit.clear_cache()
	IconLibrary.clear_cache()


func _on_screen_requested(screen_id: StringName, params: Dictionary) -> void:
	if not SCREENS.has(screen_id):
		push_error("Écran inconnu : %s" % screen_id)
		return
	_transition.style = "crt" if screen_id in [&"title", &"summary"] else "curtains"
	await _transition.close()
	HitchMonitor.mark("écran " + String(screen_id))
	if _current != null:
		_current.queue_free()
		_current = null
	var heavy: bool = screen_id in HEAVY_SCREENS
	if heavy:
		await _loading.show_card()
	var packed: PackedScene = await _load_scene(SCREENS[screen_id], heavy)
	if heavy and screen_id == &"run":
		await Warmup.run(_frame, func(p: float) -> void: _loading.set_progress(0.3 + 0.6 * p))
	_current = packed.instantiate()
	if _current.has_method("setup"):
		_current.call("setup", params)
	_frame.add_child(_current)
	for _i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	await _settle_pipelines(SETTLE_MAX_MS if heavy else SETTLE_LIGHT_MS)
	if heavy:
		await _loading.hide_card()
	HitchMonitor.mark("ouverture " + String(screen_id))
	await _transition.open()


func _settle_pipelines(max_ms: int) -> void:
	var t0: int = Time.get_ticks_msec()
	var quiet: int = 0
	var last: int = HitchMonitor._pipeline_count()
	while quiet < SETTLE_QUIET_FRAMES and Time.get_ticks_msec() - t0 < max_ms:
		await get_tree().process_frame
		var now: int = HitchMonitor._pipeline_count()
		quiet = quiet + 1 if now == last else 0
		last = now
	_loading.set_progress(1.0)


## Chargement en tâche de fond (la barre du carton avance), sinon chargement direct.
func _load_scene(path: String, show_progress: bool) -> PackedScene:
	if not show_progress or ResourceLoader.has_cached(path):
		return load(path) as PackedScene
	ResourceLoader.load_threaded_request(path, "PackedScene", true)
	var prog: Array = []
	while ResourceLoader.load_threaded_get_status(path, prog) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if not prog.is_empty():
			_loading.set_progress(0.3 * float(prog[0]))
		await get_tree().process_frame
	var res: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene
	return res if res != null else load(path) as PackedScene
