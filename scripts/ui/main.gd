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
}

var _screen_layer: CanvasLayer = null
var _overlay_layer: CanvasLayer = null
var _current: Node = null
var _transition: ScreenTransition = null


func _ready() -> void:
	_screen_layer = CanvasLayer.new()
	_screen_layer.layer = 0
	add_child(_screen_layer)
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 50
	add_child(_overlay_layer)
	_transition = ScreenTransition.new()
	_overlay_layer.add_child(_transition)
	var toasts: ToastLayer = ToastLayer.new()
	_overlay_layer.add_child(toasts)
	var post: PostFx = PostFx.new()
	add_child(post)
	EventBus.screen_requested.connect(_on_screen_requested)
	if not _dev_hooks():
		GameState.goto(&"title")


## Options de développement (captures d'écran automatisées, accès direct) :
## -- --dev-run=lea [--dev-phase=shop|pact|summary|creditor] [--shot=user://shot.png] [--frames=120]
##    --dev-screen=options
func _dev_hooks() -> bool:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	if args.has("dev-autoplay"):
		var ap: DevAutoplay = DevAutoplay.new()
		ap.spins_wanted = int(args["dev-autoplay"])
		ap.shot_dir = String(args.get("shot-dir", ""))
		ap.perf = args.has("perf")
		add_child(ap)
	if args.has("quit-frames"):
		_quit_later(int(args["quit-frames"]))
	if args.has("shot"):
		_capture_later(String(args["shot"]), int(args.get("frames", "120")))
	if args.has("dev-screen"):
		GameState.goto(StringName(String(args["dev-screen"])))
		return true
	if not args.has("dev-run"):
		return false
	GameState.controller = RunController.new(DataRegistry.db)
	GameState.controller.new_run(String(args["dev-run"]), int(args.get("dev-risk", "0")), int(args.get("dev-seed", "1")))
	var r: RunState = GameState.controller.run
	if args.has("dev-debt-mult"):
		r.flags["debt_mult"] = float(String(args["dev-debt-mult"]))
		r.debt = GameState.controller.debt_for(r.tier, r.deadline_idx)
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
	return true


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


func _exit_tree() -> void:
	UiKit.clear_cache()
	IconLibrary.clear_cache()


func _on_screen_requested(screen_id: StringName, params: Dictionary) -> void:
	if not SCREENS.has(screen_id):
		push_error("Écran inconnu : %s" % screen_id)
		return
	_transition.style = "crt" if screen_id in [&"title", &"summary"] else "curtains"
	await _transition.close()
	if _current != null:
		_current.queue_free()
		_current = null
	var packed: PackedScene = load(SCREENS[screen_id]) as PackedScene
	_current = packed.instantiate()
	if _current.has_method("setup"):
		_current.call("setup", params)
	_screen_layer.add_child(_current)
	await _transition.open()
