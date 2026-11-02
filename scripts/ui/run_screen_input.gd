class_name RunScreenInput
extends RefCounted
## Commandes de l'écran de run selon son état, pour la souris, le clavier et la manette
## (schéma décrit dans tools/gen_input_map.py). Séparé de RunScreen pour la lisibilité.

## Invites par état : [action ou repère, clé du libellé].
const PROMPTS: Dictionary[String, Array] = {
	"BETTING_KEYS":
	[
		["@click", "HINT_K_ADD"],
		["@shift_click", "HINT_K_ADD5"],
		["@right_click", "HINT_K_REMOVE"],
		["bet_cycle_prev+bet_cycle_next", "HINT_K_AMOUNT"],
		["item_panel", "HINT_K_ITEMS"],
	],
	"BETTING_PAD":
	[
		["@dpad", "HINT_K_CURSOR"],
		["bet_place", "HINT_K_ADD"],
		["bet_remove", "HINT_K_REMOVE"],
		["bet_cycle_prev+bet_cycle_next", "HINT_K_AMOUNT"],
		["item_panel", "HINT_K_ITEMS"],
	],
	"ITEMS":
	[
		["@dpad_lr", "HINT_K_SELECT"],
		["ui_accept", "HINT_K_USE"],
		["bet_repeat", "HINT_K_LOCK"],
		["bet_cycle_prev", "HINT_K_MOVE"],
		["ui_cancel", "HINT_K_BACK"],
	],
	"AIMING": [["ui_spin", "HINT_K_AIM"]],
	"THROWING": [["ui_spin", "HINT_K_HOLD"], ["qte_left+qte_up+qte_right+qte_down", "HINT_K_QTE"]],
	"BALL": [["skip_anim", "HINT_K_SKIP"], ["speed_toggle", "HINT_K_SPEED"]],
	"SCORING": [["skip_anim", "HINT_K_SKIP"], ["speed_toggle", "HINT_K_SPEED"]],
	"TARGETING": [["@dpad_lr", "HINT_K_SELECT"], ["ui_accept", "HINT_K_CONFIRM"], ["ui_cancel", "BTN_CANCEL_TARGET"]],
}

const AMOUNTS: Array[int] = [1, 2, 5, 10]

## Pichenette du joystick droit (inutilisé en jeu) : taquine un objet du décor.
const FLICK: float = 0.85
const FLICK_RESET: float = 0.3

var s: RunScreen = null
var _flicked: bool = false


func _init(screen: RunScreen) -> void:
	s = screen


## Commandes de l'écran de run selon l'état ; vrai si l'événement est consommé.
func handle(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion and _decor_flick(event as InputEventJoypadMotion):
		return true
	if GameInput.pressed(event, "pause_menu"):
		if s.state == RunScreen.UiState.TARGETING:
			cancel_targeting()
		elif s._items_mode:
			set_items_mode(false)
		else:
			s._on_menu()
		return true
	if s._items_mode:
		if GameInput.pressed(event, "ui_cancel") or GameInput.pressed(event, "item_panel") or GameInput.pressed(event, "bet_remove"):
			set_items_mode(false)
			return true
		return false
	match s.state:
		RunScreen.UiState.BETTING:
			return input_betting(event)
		RunScreen.UiState.AIMING:
			if GameInput.pressed(event, "ui_spin") or GameInput.pressed(event, "bet_place"):
				s._on_spin_pressed()
				return true
		RunScreen.UiState.THROWING:
			return s.throw_game.handle(event)
		RunScreen.UiState.BALL, RunScreen.UiState.SCORING:
			if GameInput.pressed(event, "skip_anim"):
				s._skip_animations()
				return true
			if GameInput.pressed(event, "speed_toggle"):
				s._on_speed()
				return true
		RunScreen.UiState.RETHROW:
			if GameInput.pressed(event, "ui_spin"):
				s._on_rethrow()
				return true
			if GameInput.pressed(event, "skip_anim"):
				s._on_keep()
				return true
		RunScreen.UiState.TARGETING:
			return input_targeting(event)
	return false


func input_betting(event: InputEvent) -> bool:
	if gamepad_table(event):
		return true
	var actions: Dictionary[String, Callable] = {
		"ui_spin": s._on_spin_pressed,
		"bet_undo": s._on_undo,
		"bet_repeat": s._on_repeat,
		"bet_clear": s._on_clear,
		"speed_toggle": s._on_speed,
		"item_panel": set_items_mode.bind(true),
	}
	for a: String in actions.keys():
		if GameInput.pressed(event, a):
			actions[a].call()
			return true
	if GameInput.pressed(event, "bet_remove"):
		var spot: String = s.table_view.cursor_spot() if s.table_view.cursor_active else s.table_view.hover_spot
		if spot != "":
			s._on_spot_changed(spot, -1)
		return true
	return false


## Ciblage d'une carte Fortune sans souris : la croix parcourt la roue, A valide, B annule.
func input_targeting(event: InputEvent) -> bool:
	var n: int = s.ctl.run.wheel.size()
	if GameInput.pressed(event, "ui_left", true) or GameInput.pressed(event, "ui_up", true):
		move_target(-1, n)
		return true
	if GameInput.pressed(event, "ui_right", true) or GameInput.pressed(event, "ui_down", true):
		move_target(1, n)
		return true
	if GameInput.pressed(event, "ui_accept") or GameInput.pressed(event, "bet_place"):
		if s.wheel_view.hover_index >= 0:
			s._on_pocket_clicked(s.wheel_view.hover_index)
		return true
	if GameInput.pressed(event, "ui_cancel") or GameInput.pressed(event, "bet_remove"):
		cancel_targeting()
		return true
	return false


func move_target(d: int, n: int) -> void:
	var i: int = s.wheel_view.hover_index if s.wheel_view.hover_index >= 0 else maxi(s.ctl.run.last_landing_index, 0)
	s.wheel_view.hover_index = posmod(i + d, n)
	s.wheel_view.queue_redraw()
	AudioBus.ui("hover")
	s._cards.show_pocket(s.wheel_view.hover_index)


func cancel_targeting() -> void:
	s._target_fortune_slot = -1
	s.wheel_view.hover_index = -1
	s._cards.show_pocket(-1)
	s._set_state(RunScreen.UiState.BETTING)


## Mode « objets » (manette) : la sélection passe sur les grigris et cartes Fortune.
func set_items_mode(on: bool) -> void:
	if on:
		s._cards.hide_bet()
		var first: Control = PadNavigator.first_focusable(s.grigri_bar)
		if first == null:
			first = PadNavigator.first_focusable(s.fortune_bar)
		if first == null:
			EventBus.toast.emit(s.tr("TOAST_NO_ITEMS"), &"info")
			return
		s._items_mode = true
		first.grab_focus()
		AudioBus.ui("panel_open")
	else:
		s._items_mode = false
		s.get_viewport().gui_release_focus()
		AudioBus.ui("panel_close")
	s._refresh_hint()


## Taille de la mise posée par A / clic : 1, 2, 5, 10 (bornée par le budget du tour).
func change_amount(d: int) -> void:
	var steps: Array[int] = AMOUNTS
	var i: int = steps.find(s.table_view.bet_amount)
	i = clampi((i if i >= 0 else 0) + d, 0, steps.size() - 1)
	if steps[i] == s.table_view.bet_amount:
		AudioBus.ui("error")
		return
	s.table_view.bet_amount = steps[i]
	s.table_view.queue_redraw()
	AudioBus.ui("click")
	s._refresh_amount()


## Jeu au tapis sans souris (manette, Steam Deck, clavier) : renvoie true si l'événement est consommé.
func gamepad_table(event: InputEvent) -> bool:
	var dirs: Dictionary = {"ui_left": Vector2i(-1, 0), "ui_right": Vector2i(1, 0), "ui_up": Vector2i(0, -1), "ui_down": Vector2i(0, 1)}
	for a: String in dirs.keys():
		if GameInput.pressed(event, a, true):
			var d: Vector2i = dirs[a]
			s.table_view.move_cursor(d.x, d.y)
			AudioBus.ui("hover")
			return true
	if GameInput.pressed(event, "bet_cycle_prev", true):
		change_amount(-1)
		return true
	if GameInput.pressed(event, "bet_cycle_next", true):
		change_amount(1)
		return true
	if GameInput.pressed(event, "bet_place") and s.table_view.cursor_active:
		s._on_spot_changed(s.table_view.cursor_spot(), s.table_view.bet_amount)
		return true
	return false


func _decor_flick(m: InputEventJoypadMotion) -> bool:
	if m.axis != JOY_AXIS_RIGHT_X and m.axis != JOY_AXIS_RIGHT_Y:
		return false
	var v: float = absf(m.axis_value)
	if _flicked and v < FLICK_RESET:
		_flicked = false
	elif not _flicked and v > FLICK and s.decor != null:
		_flicked = true
		s.decor.poke_random()
	return true
