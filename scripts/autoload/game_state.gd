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
const SCREEN_RACE: StringName = &"seed_race"
const SCREEN_INTRO: StringName = &"intro"

## Délai laissé au thread audio pour libérer les lectures avant de quitter.
const QUIT_AUDIO_GRACE: float = 0.35

var controller: RunController = null
var current_screen: StringName = &""
var last_run_victory: bool = false
var replay_log: Array[Dictionary] = []


func _ready() -> void:
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			quit_game()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			# Mise en veille (Steam Deck), changement de fenêtre : rien ne doit se perdre.
			autosave()
			SaveSystem.save_profile()


## Sortie propre : sauvegarde, coupe l'audio, laisse deux frames au thread audio, puis quitte.
func quit_game(exit_code: int = 0) -> void:
	autosave()
	SaveSystem.save_profile()
	AudioBus.shutdown()
	await get_tree().create_timer(QUIT_AUDIO_GRACE, true, false, true).timeout
	get_tree().quit(exit_code)


func goto(screen_id: StringName, params: Dictionary = {}) -> void:
	current_screen = screen_id
	EventBus.screen_requested.emit(screen_id, params)


func start_new_run(character_id: String, risk_level: int, seed_value: int, challenge_id: String = "", daily: bool = false) -> void:
	if challenge_id != "":
		character_id = String(DataRegistry.db.get_entry("challenges", challenge_id).get("character", character_id))
	controller = RunController.new(DataRegistry.db)
	if not bool((SaveSystem.profile.get("tutorial", {}) as Dictionary).get("done", false)) and challenge_id == "" and not daily:
		controller.tutorial_run = true
	controller.new_run(character_id, risk_level, seed_value, challenge_id)
	controller.run.daily = daily
	replay_log.clear()
	Telemetry.begin(controller.run)
	SaveSystem.add_stat("runs", 1)
	SaveSystem.save_profile()
	autosave()
	EventBus.run_started.emit(controller.run)
	# Toute première partie : la cinématique d'intro avant d'entrer au casino.
	var seen: bool = int((SaveSystem.profile.get("stats", {}) as Dictionary).get("intro_seen", 0)) > 0
	if not seen and challenge_id == "" and not daily and not DevMode.active():
		goto(SCREEN_INTRO, {"next": String(SCREEN_RUN)})
	else:
		goto(SCREEN_RUN)


func continue_run() -> bool:
	var state: RunState = SaveSystem.load_run()
	if state == null:
		return false
	controller = RunController.new(DataRegistry.db)
	controller.load_run(state)
	Telemetry.resume(state)
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
	Telemetry.sync(controller.run)
	SaveSystem.save_run(controller.run)


func log_input(entry: Dictionary) -> void:
	replay_log.append(entry)


# --------------------------------------------------------------------------- succès


func _announce(ids: Array[String]) -> void:
	for aid: String in ids:
		var a: Dictionary = DataRegistry.db.get_entry("achievements", aid)
		EventBus.achievement_unlocked.emit(aid)
		EventBus.toast.emit(tr("TOAST_ACHIEVEMENT") % Localization.t(a, "name"), &"success")
		AudioBus.play("celebrate")
	if not ids.is_empty():
		SaveSystem.save_profile()


func record_spin(outcome: RunController.SpinOutcome) -> void:
	var r: RunState = controller.run
	_announce(MetaProgress.evaluate(SaveSystem.profile, DataRegistry.db, "spin", MetaProgress.spin_metrics(r, outcome.ctx)))
	if outcome.deadline_won:
		_announce(MetaProgress.evaluate(SaveSystem.profile, DataRegistry.db, "deadline_won", MetaProgress.deadline_metrics(r)))


func record_shop(action: String, data: Dictionary) -> void:
	var m: Dictionary = data.duplicate()
	m["action"] = action
	_announce(MetaProgress.evaluate(SaveSystem.profile, DataRegistry.db, "shop", m))


## Fin de run : statistiques de profil, déblocages, puis résumé.
func end_run(victory: bool) -> void:
	if not has_active_run():
		return
	var r: RunState = controller.run
	last_run_victory = victory
	SaveSystem.add_stat("spins", r.total_spins)
	(SaveSystem.profile["tutorial"] as Dictionary)["done"] = true
	SaveSystem.add_stat("zeros", r.zeros_hit)
	SaveSystem.max_stat("best_spin", r.best_spin)
	if victory:
		SaveSystem.add_stat("wins", 1)
		var mr: Dictionary = SaveSystem.profile["max_risk"]
		var prev: int = int(mr.get(r.character_id, -1))
		mr[r.character_id] = maxi(prev, r.risk_level + 1)
	var camp: Dictionary = SaveSystem.profile["campaign"]
	camp["act_reached"] = maxi(int(camp.get("act_reached", 1)), r.act())
	if victory and r.flags.has("ending"):
		var endings: Array = camp.get("endings", [])
		if not endings.has(String(r.flags["ending"])):
			endings.append(String(r.flags["ending"]))
		camp["endings"] = endings
	if MetaProgress.challenge_completed(DataRegistry.db, r, victory):
		var done: Array = SaveSystem.profile["challenges_done"]
		if not done.has(r.challenge_id):
			done.append(r.challenge_id)
	if r.daily:
		var daily: Dictionary = SaveSystem.profile["daily"]
		daily["best"] = maxi(int(daily.get("best", 0)), r.deadlines_cleared)
		daily["last_date"] = Time.get_date_string_from_system()
	var seed_code: String = RngService.seed_to_code(r.rng.seed_value)
	var hist: Dictionary = RunHistory.entry(r, victory, Telemetry.run_seconds(), seed_code, Time.get_datetime_string_from_system(false, true))
	RunHistory.record(SaveSystem.profile, hist, Balance.i("run.tiers"))
	_announce(MetaProgress.evaluate(SaveSystem.profile, DataRegistry.db, "run_end", MetaProgress.run_metrics(r, DataRegistry.db, victory)))
	_announce(MetaProgress.evaluate(SaveSystem.profile, DataRegistry.db, "profile", MetaProgress.profile_metrics(SaveSystem.profile)))
	SaveSystem.save_profile()
	SaveSystem.clear_run()
	Telemetry.end(r, victory)
	EventBus.run_ended.emit(r, victory)
	goto(SCREEN_SUMMARY, {"victory": victory})


func abandon_run() -> void:
	if has_active_run():
		SaveSystem.clear_run()
	controller = null
	goto(SCREEN_TITLE)
