class_name AppLifecycle
extends Node
## Téléphone uniquement : cycle de vie Android.
## - Geste / bouton Retour : ferme la fiche de carte, sinon la surcouche ouverte (`go_back`),
##   sinon ouvre la pause en partie ; sur l'écran titre, demande avant de quitter.
## - Mise en arrière-plan (appel, notification, bouton d'accueil) : sauvegarde de la partie et du
##   profil, son coupé, pause ouverte en pleine partie ; au retour, le son revient.
## - Écran maintenu allumé pendant une partie (pas pendant les menus).

const MASTER_BUS: int = 0

## Zone active (surcouche la plus haute, sinon l'écran) : fournie par Main.
var active_root: Callable = Callable()
var _muted_by_us: bool = false
var _in_background: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.screen_requested.connect(_on_screen)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			back()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_to_background()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_to_foreground()


func back() -> void:
	if CardSheet.is_open():
		CardSheet.close_current()
		return
	var root: Control = active_root.call() as Control if active_root.is_valid() else null
	if root == null:
		return
	if root is TitleScreen:
		(root as TitleScreen).ask_quit()
	elif root is RunScreen:
		_send_action(&"pause_menu")
	elif root.has_method("go_back"):
		root.call("go_back")


func _to_background() -> void:
	if _in_background:
		return
	_in_background = true
	GameState.autosave()
	SaveSystem.save_profile()
	if not AudioServer.is_bus_mute(MASTER_BUS):
		AudioServer.set_bus_mute(MASTER_BUS, true)
		_muted_by_us = true
	# En pleine partie (lancer, épreuve…), la pause attend le retour du joueur.
	var root: Control = active_root.call() as Control if active_root.is_valid() else null
	if root is RunScreen:
		_send_action(&"pause_menu")


func _to_foreground() -> void:
	if not _in_background:
		return
	_in_background = false
	if _muted_by_us:
		AudioServer.set_bus_mute(MASTER_BUS, false)
		_muted_by_us = false


func _on_screen(screen_id: StringName, _params: Dictionary) -> void:
	DisplayServer.screen_set_keep_on(screen_id == &"run")


## Appui puis relâcher d'une action, comme une touche.
func _send_action(action: StringName) -> void:
	for down: bool in [true, false]:
		var ev: InputEventAction = InputEventAction.new()
		ev.action = action
		ev.pressed = down
		Input.parse_input_event(ev)
