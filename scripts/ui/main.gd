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
	GameState.goto(&"title")


func _on_screen_requested(screen_id: StringName, params: Dictionary) -> void:
	if not SCREENS.has(screen_id):
		push_error("Écran inconnu : %s" % screen_id)
		return
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
