class_name AppLifecycle
extends Node
## Téléphone uniquement : cycle de vie Android.
## - Geste / bouton Retour : ferme la fiche de carte, sinon la surcouche ouverte (`go_back`),
##   sinon ouvre la pause en partie ; sur l'écran titre, demande avant de quitter.
## - Mise en arrière-plan (appel, notification, bouton d'accueil) : sauvegarde de la partie et du
##   profil, son coupé, pause ouverte en pleine partie ; au retour, le son revient.
## - Écran maintenu allumé pendant une partie (pas pendant les menus).
## - Retour en pleine épreuve (la pause n'existe qu'au tapis) : voile « touche pour reprendre »,
##   l'épreuve reste figée (`holding`, lu par le lancer comme les astuces bloquantes).

const MASTER_BUS: int = 0
const VEIL_LAYER: int = 95
const VEIL_ALPHA: float = 0.72

## Vrai tant que le voile de reprise est affiché : le mini-jeu de lancer ne progresse pas.
static var holding: bool = false

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
		if (root as RunScreen).state == RunScreen.UiState.BETTING:
			_send_action(&"pause_menu")
		else:
			_show_veil.call_deferred()  # notification reçue pendant la propagation dans l'arbre


func _to_foreground() -> void:
	if not _in_background:
		return
	_in_background = false
	if _muted_by_us:
		AudioServer.set_bus_mute(MASTER_BUS, false)
		_muted_by_us = false


func _on_screen(screen_id: StringName, _params: Dictionary) -> void:
	DisplayServer.screen_set_keep_on(screen_id == &"run")


## Voile plein écran : un toucher (ou une touche) referme et relance l'épreuve.
func _show_veil() -> void:
	if holding:
		return
	holding = true
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = VEIL_LAYER
	add_child(layer)
	var veil: ColorRect = ColorRect.new()
	veil.color = Color(Palette.INK, VEIL_ALPHA)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(veil)
	var v: VBoxContainer = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(v)
	var title: Label = UiKit.label(tr("PAUSE_TITLE"), UiKit.SIZE_H1, Palette.GOLD_LIGHT, "display")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var hint: Label = UiKit.label(tr("RESUME_TAP"), UiKit.SIZE_H2, Palette.IVORY)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	veil.gui_input.connect(func(ev: InputEvent) -> void:
		var mb: InputEventMouseButton = ev as InputEventMouseButton
		if mb != null and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_close_veil(layer)
	)


func _close_veil(layer: CanvasLayer) -> void:
	layer.queue_free()
	# Le relâcher du toucher qui ferme le voile ne doit pas compter dans l'épreuve.
	await get_tree().process_frame
	holding = false


## Appui puis relâcher d'une action, comme une touche.
func _send_action(action: StringName) -> void:
	for down: bool in [true, false]:
		var ev: InputEventAction = InputEventAction.new()
		ev.action = action
		ev.pressed = down
		Input.parse_input_event(ev)
