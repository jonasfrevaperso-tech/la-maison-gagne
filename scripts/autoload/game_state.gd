extends Node
## Machine à états de haut niveau : écrans, run en cours, sauvegarde automatique, méta.

const SCREEN_TITLE: StringName = &"title"
const SCREEN_CHARACTER: StringName = &"character_select"
const SCREEN_RUN: StringName = &"run"
const SCREEN_SUMMARY: StringName = &"summary"
const SCREEN_OPTIONS: StringName = &"options"
const SCREEN_CREDITS: StringName = &"credits"
const SCREEN_CODEX: StringName = &"codex"
const SCREEN_HALL: StringName = &"hall"
const SCREEN_ACHIEVEMENTS: StringName = &"achievements"
const SCREEN_STATS: StringName = &"stats"

var controller: RunController = null
var current_screen: StringName = &""
var last_run_victory: bool = false
var replay_log: Array[Dictionary] = []


func _ready() -> void:
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


## Sortie propre : sauvegarde, coupe l'audio, laisse deux frames au thread audio, puis quitte.
func quit_game() -> void:
	autosave()
	SaveSystem.save_profile()
	AudioBus.shutdown()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()


func goto(screen_id: StringName, params: Dictionary = {}) -> void:
	current_screen = screen_id
	EventBus.screen_requested.emit(screen_id, params)


func start_new_run(character_id: String, risk_level: int, seed_value: int, challenge_id: String = "", daily: bool = false) -> void:
	controller = RunController.new(DataRegistry.db)
	controller.new_run(character_id, risk_level, seed_value, challenge_id)
	controller.run.daily = daily
	replay_log.clear()
	SaveSystem.add_stat("runs", 1)
	SaveSystem.save_profile()
	autosave()
	EventBus.run_started.emit(controller.run)
	goto(SCREEN_RUN)


func continue_run() -> bool:
	var state: RunState = SaveSystem.load_run()
	if state == null:
		return false
	controller = RunController.new(DataRegistry.db)
	controller.load_run(state)
	EventBus.run_loaded.emit(state)
	goto(SCREEN_RUN)
	return true


func has_active_run() -> bool:
	return controller != null and controller.run != null


func run() -> RunState:
	return controller.run if controller != null else null


## Sauvegarde automatique aux points stables (paris, boutique, pacte, événement).
func autosave() -> void:
	if not has_active_run():
		return
	var ph: RunState.Phase = controller.run.phase
	if ph == RunState.Phase.GAME_OVER or ph == RunState.Phase.VICTORY:
		SaveSystem.clear_run()
		return
	SaveSystem.save_run(controller.run)


func log_input(entry: Dictionary) -> void:
	replay_log.append(entry)


## Fin de run : statistiques de profil, déblocages, puis résumé.
func end_run(victory: bool) -> void:
	if not has_active_run():
		return
	var r: RunState = controller.run
	last_run_victory = victory
	SaveSystem.add_stat("spins", r.total_spins)
	SaveSystem.add_stat("zeros", r.zeros_hit)
	SaveSystem.max_stat("best_spin", r.best_spin)
	if victory:
		SaveSystem.add_stat("wins", 1)
		var mr: Dictionary = SaveSystem.profile["max_risk"]
		var prev: int = int(mr.get(r.character_id, -1))
		mr[r.character_id] = maxi(prev, r.risk_level + 1)
	var camp: Dictionary = SaveSystem.profile["campaign"]
	camp["act_reached"] = maxi(int(camp.get("act_reached", 1)), r.act())
	SaveSystem.save_profile()
	SaveSystem.clear_run()
	EventBus.run_ended.emit(r, victory)
	goto(SCREEN_SUMMARY, {"victory": victory})


func abandon_run() -> void:
	if has_active_run():
		SaveSystem.clear_run()
	controller = null
	goto(SCREEN_TITLE)
