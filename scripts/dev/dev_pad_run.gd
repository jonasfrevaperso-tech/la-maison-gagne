class_name DevPadRun
extends Node
## Partie jouée UNIQUEMENT avec des événements de manette simulés (aucun clic, aucune touche) :
## titre → nouvelle partie → sélection → mises au curseur → lancer (RT) → relâcher → astuces →
## boutique (achat, vente, verrouillage, déplacement) → pacte / événement / récompense → pause →
## options (onglets, retour) → Codex (défilement) → … jusqu'à `spins_wanted` tours.
## Échoue (code 1) si l'écran ne progresse plus pendant STALL_SECONDS ou si une étape est
## impossible sans souris. Usage : godot --path . -- --dev-pad-run=12 [--shot-dir=…]

const STEP: float = 0.12
const STALL_SECONDS: float = 25.0
const MAX_SECONDS: float = 900.0

var spins_wanted: int = 10
## Multiplicateur de dette (0 = normal) : traverser toute la campagne rapidement.
var debt_mult: float = 0.0
var shot_dir: String = ""
var _log: Array[String] = []
var _last_progress: float = 0.0
var _last_signature: String = ""
var _elapsed: float = 0.0
var _visited: Dictionary[String, bool] = {}
var _shots: int = 0
var _bets_this_spin: int = 0
var _shop_actions: int = 0
var _aim_wait: float = 0.0
var _failed: bool = false


func _ready() -> void:
	Settings.set_value("game", "input_mode", "gamepad")
	Settings.speed_override = 4.0
	_drive()


# --------------------------------------------------------------------------- événements manette


func _button(idx: JoyButton) -> void:
	for down: bool in [true, false]:
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.button_index = idx
		e.pressed = down
		Input.parse_input_event(e)
		await get_tree().process_frame


func _axis(axis: JoyAxis) -> void:
	for v: float in [1.0, 0.0]:
		var e: InputEventJoypadMotion = InputEventJoypadMotion.new()
		e.axis = axis
		e.axis_value = v
		Input.parse_input_event(e)
		await get_tree().process_frame


func _press(name: String) -> void:
	_log.append(name)
	match name:
		"A":
			await _button(JOY_BUTTON_A)
		"B":
			await _button(JOY_BUTTON_B)
		"X":
			await _button(JOY_BUTTON_X)
		"Y":
			await _button(JOY_BUTTON_Y)
		"LB":
			await _button(JOY_BUTTON_LEFT_SHOULDER)
		"RB":
			await _button(JOY_BUTTON_RIGHT_SHOULDER)
		"START":
			await _button(JOY_BUTTON_START)
		"BACK":
			await _button(JOY_BUTTON_BACK)
		"UP":
			await _button(JOY_BUTTON_DPAD_UP)
		"DOWN":
			await _button(JOY_BUTTON_DPAD_DOWN)
		"LEFT":
			await _button(JOY_BUTTON_DPAD_LEFT)
		"RIGHT":
			await _button(JOY_BUTTON_DPAD_RIGHT)
		"RT":
			await _axis(JOY_AXIS_TRIGGER_RIGHT)
		"LT":
			await _axis(JOY_AXIS_TRIGGER_LEFT)


# --------------------------------------------------------------------------- pilote


func _drive() -> void:
	await get_tree().create_timer(1.0).timeout
	while _elapsed < MAX_SECONDS and not _failed:
		await get_tree().create_timer(STEP, true, false, true).timeout
		_elapsed += STEP
		var ctl: RunController = GameState.controller
		if ctl != null and ctl.run != null and ctl.run.total_spins >= spins_wanted:
			_finish(true, "objectif atteint : %d tours" % ctl.run.total_spins)
			return
		var sig: String = _signature()
		if sig != _last_signature:
			_last_signature = sig
			_last_progress = _elapsed
		elif _elapsed - _last_progress > STALL_SECONDS:
			_finish(false, "aucune progression depuis %.0f s sur : %s" % [STALL_SECONDS, sig])
			return
		await _act()
	_finish(false, "temps maximum dépassé")


## Empreinte de l'état visible : sert à détecter un blocage.
func _signature() -> String:
	var root: Control = _active()
	var f: Control = get_viewport().gui_get_focus_owner()
	var ctl: RunController = GameState.controller
	var run_sig: String = ""
	if ctl != null and ctl.run != null:
		run_sig = "%d/%d/%d/%d/%d" % [ctl.run.total_spins, ctl.run.phase, ctl.run.slip.total(), ctl.run.money, ctl.run.grigris.size()]
	var rs: RunScreen = _run_screen()
	return "%s|%s|%s|%s" % [
		root.get_class() + ":" + String(root.name) if root != null else "-",
		String(f.name) if f != null else "-",
		run_sig,
		str(rs.state) if rs != null else "-",
	]


func _main() -> Node:
	return get_tree().current_scene


func _active() -> Control:
	return _main().call("_active_root") as Control


func _run_screen() -> RunScreen:
	var root: Node = _main()
	for n: Node in root.find_children("*", "RunScreen", true, false):
		return n as RunScreen
	return null


func _act() -> void:
	var root: Control = _active()
	if root == null:
		return
	_mark(root)
	var tip_open: bool = _tip_open()
	if tip_open:
		await _press("A")
		return
	if root is TitleScreen:
		await _title()
	elif root is CharacterSelect:
		await _press("A")
	elif root is RunScreen:
		await _run(root as RunScreen)
	elif root is ShopOverlay:
		await _shop(root as ShopOverlay)
	elif root is PauseMenu:
		await _press("B")
	elif root is OptionsScreen:
		await _press("RB")
		await _press("RB")
		await _press("DOWN")
		await _press("B")
	elif root is CodexScreen:
		await _press("UP")
		await _press("UP")
		await _press("B")
	elif root is RunSummary:
		if GameState.last_run_victory:
			_finish(true, "campagne gagnée à la manette (%d tours)" % _spins_seen())
		else:
			_finish(false, "run terminé avant l'objectif (résumé atteint)")
	elif root is ConfirmBox or root is VirtualKeyboard:
		await _press("A")
	else:
		await _press("A")


func _mark(root: Control) -> void:
	var key: String = root.get_class() + (":" + root.get_script().get_global_name() if root.get_script() != null else "")
	if not _visited.has(key):
		_visited[key] = true
		_shot(key)


func _tip_open() -> bool:
	var rs: RunScreen = _run_screen()
	return rs != null and rs.tutorial != null and rs.tutorial.get("_bubble") != null


func _title() -> void:
	# Parcours des menus une fois (options, codex) avant de lancer la partie.
	if not _visited.has("Control:OptionsScreen"):
		if await _focus_text(tr("MENU_OPTIONS")):
			await _press("A")
			return
	if not _visited.has("Control:CodexScreen"):
		if await _focus_text(tr("MENU_CODEX")):
			await _press("A")
			return
	if await _focus_text(tr("MENU_NEW_RUN")):
		await _press("A")


## Déplace le focus à la croix jusqu'au bouton portant ce texte (pas à pas vers sa position).
func _focus_text(text: String) -> bool:
	var target: Button = null
	for n: Node in _active().find_children("*", "Button", true, false):
		if (n as Button).text == text and (n as Button).is_visible_in_tree():
			target = n as Button
	if target == null:
		_log.append("bouton absent : " + text)
		return false
	for _i: int in 30:
		var f: Control = get_viewport().gui_get_focus_owner()
		if f == target:
			return true
		if f == null:
			await _press("DOWN")
			continue
		var d: Vector2 = UiLayout.canvas_rect(target).get_center() - UiLayout.canvas_rect(f).get_center()
		if absf(d.y) > 8.0:
			await _press("DOWN" if d.y > 0.0 else "UP")
		else:
			await _press("RIGHT" if d.x > 0.0 else "LEFT")
	_log.append("inaccessible à la croix : " + text)
	return false


func _run(rs: RunScreen) -> void:
	var r: RunState = rs.ctl.run
	if debt_mult > 0.0 and not r.flags.has("debt_mult"):
		r.flags["debt_mult"] = debt_mult
		r.debt = rs.ctl.debt_for(r.tier, r.deadline_idx)
	match rs.state:
		RunScreen.UiState.BETTING:
			if rs.get("_items_mode"):
				if not r.fortunes.is_empty() and not _visited.has("fortune_used"):
					_visited["fortune_used"] = true
					for _k: int in 8:
						await _press("RIGHT")
					await _press("A")  # utiliser la carte Fortune sélectionnée
					return
				await _press("Y")
				await _press("RB")
				await _press("B")
				return
			if r.slip.remaining() > 0 and _bets_this_spin < 12:
				_bets_this_spin += 1
				var moves: Array[String] = ["RIGHT", "DOWN", "LEFT", "UP", "RB", "RIGHT", "LB"]
				await _press(moves[_bets_this_spin % moves.size()])
				await _press("A")
				if _bets_this_spin == 3:
					await _press("B")  # retirer un jeton
					await _press("X")  # annuler
				return
			if r.total_spins == 2 and not _visited.has("items_mode") and not r.grigris.is_empty():
				_visited["items_mode"] = true
				await _press("BACK")
				return
			if not r.fortunes.is_empty() and not _visited.has("fortune_used"):
				await _press("BACK")
				return
			if r.total_spins == 1 and not _visited.has("pause"):
				_visited["pause"] = true
				await _press("START")
				return
			_bets_this_spin = 0
			_aim_wait = 0.0
			await _press("RT")
		RunScreen.UiState.AIMING:
			_aim_wait += STEP
			if _aim_wait > 0.6:
				await _press("RT")
		RunScreen.UiState.THROWING:
			# Mini-jeu à la gâchette : on attend le bon moment image par image, puis RT.
			var g: ThrowMinigame = rs.throw_game
			for _f: int in 240:
				var ready: bool = false
				if g.beat == ThrowMinigame.Beat.POWER:
					ready = absf(float(g.get("_needle")) - 0.5) < 0.04
				elif g.beat == ThrowMinigame.Beat.RELEASE:
					ready = float(g.get("_t")) >= float(g.get("_release_time")) - 0.02
				else:
					return
				if ready:
					await _press("RT")
					return
				await get_tree().process_frame
		RunScreen.UiState.BALL, RunScreen.UiState.SCORING:
			await _press("A")
		RunScreen.UiState.RETHROW:
			await _press("A")
		RunScreen.UiState.TARGETING:
			await _press("RIGHT")
			await _press("A")
		_:
			await _press("A")


func _shop(shop: ShopOverlay) -> void:
	_shop_actions += 1
	var f: Control = get_viewport().gui_get_focus_owner()
	if f == null:
		_finish(false, "boutique : aucun élément sélectionné à la manette")
		return
	if not (shop.ctl.run.shop_state.get("open_pack", {}) as Dictionary).is_empty():
		_visited["pack_opened"] = true
		await _press("A")  # choisir dans le paquet ouvert
		return
	match _shop_actions % 7:
		6:
			for _k: int in 4:
				await _press("RIGHT")
			await _press("A")  # acheter un paquet
		1:
			await _press("A")  # acheter l'offre sélectionnée
		2:
			await _press("DOWN")
			await _press("Y")  # verrouiller un grigri possédé (si sélectionné)
		3:
			await _press("RB")  # déplacer
		4:
			await _press("Y")
		5:
			await _press("UP")
		0:
			await _press("START")  # retour à la table
			_visited["shop_left"] = true
	if not is_instance_valid(shop) or shop.is_queued_for_deletion():
		_shop_actions = 0


func _shot(tag: String) -> void:
	if shot_dir == "":
		return
	await RenderingServer.frame_post_draw
	_shots += 1
	DirAccess.make_dir_recursive_absolute(shot_dir)
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join("%02d_%s.png" % [_shots, tag.replace(":", "_")]))


func _finish(ok: bool, why: String) -> void:
	if _failed:
		return
	_failed = not ok
	print(("Partie à la manette : OK — %s" if ok else "Partie à la manette : ÉCHEC — %s") % why)
	print("Écrans et surcouches traversés : ", ", ".join(_visited.keys()))
	if not ok:
		print("Dernières commandes : ", " ".join(_log.slice(maxi(_log.size() - 30, 0))))
		_shot("echec")
	_failed = true
	Settings.speed_override = 0.0
	Settings.set_value("game", "input_mode", "auto")
	GameState.quit_game(0 if ok else 1)


func _spins_seen() -> int:
	var ctl: RunController = GameState.controller
	return ctl.run.total_spins if ctl != null and ctl.run != null else -1
