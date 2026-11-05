extends Node
## Télémétrie locale et optionnelle (consentement demandé au premier lancement, réglable
## dans les options). Rien ne quitte l'ordinateur : un fichier JSONL par run dans
## `user://telemetry/`, lu par `tools/telemetry_report.py` pour l'équilibrage.
## Le temps compté est le temps actif (fenêtre au premier plan, pause exclue).
## 2.0 : en plus, un JOURNAL de jeu toujours tenu, lui aussi local (`user://journal/`) : mêmes
## enregistrements + chaque épreuve jouée ; c'est lui que « Exporter mes données » emporte
## (`DataExport`). Les vieux runs tournent au-delà de JOURNAL_KEEP fichiers.

const DIR_NAME: String = "telemetry/"
const SHOTS_DIR: String = "shots/"
const FLAG_FILE: String = "telemetry_file"
const FLAG_SECONDS: String = "telemetry_seconds"
const FLAG_JOURNAL: String = "journal_file"
const JOURNAL_DIR: String = "journal/"
const MUSEUM_FILE: String = "museum.jsonl"
const JOURNAL_KEEP: int = 200

var _file: String = ""
var _journal: String = ""
var _run_seconds: float = 0.0
var _deadline_seconds: float = 0.0
var _think_seconds: float = 0.0
var _shop_seconds: float = 0.0
var _focused: bool = true
var _pre: Dictionary = {}
var _shop_before: Array[String] = []
var _shop_money: int = 0
var _shop_offered: Array[String] = []
var _shop_bought: Array[String] = []
var _shop_rerolls: int = 0


func _process(delta: float) -> void:
	if not _focused or get_tree().paused:
		return
	_run_seconds += delta
	_deadline_seconds += delta
	_think_seconds += delta
	_shop_seconds += delta


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focused = false
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focused = true


## Temps actif du run en cours (compté même sans consentement : sert à l'historique local).
func run_seconds() -> float:
	return _run_seconds


func enabled() -> bool:
	return Settings.b("game", "telemetry")


func directory() -> String:
	return DevMode.save_dir() + DIR_NAME


func journal_dir() -> String:
	return DevMode.save_dir() + JOURNAL_DIR


# --------------------------------------------------------------------------- cycle de run


func begin(run: RunState) -> void:
	_file = ""
	_run_seconds = 0.0
	_deadline_seconds = 0.0
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var name: String = "run_%s_%s.jsonl" % [stamp, run.character_id]
	DirAccess.make_dir_recursive_absolute(journal_dir())
	_rotate()
	_journal = journal_dir() + name
	run.flags[FLAG_JOURNAL] = _journal
	if enabled():
		DirAccess.make_dir_recursive_absolute(directory())
		_file = directory() + name
		run.flags[FLAG_FILE] = _file
	_write(RunTelemetry.run_start(run, "human", String(ProjectSettings.get_setting("application/config/version"))))


## Reprise d'un run sauvegardé : on continue le même fichier et le même chronomètre.
func resume(run: RunState) -> void:
	_file = String(run.flags.get(FLAG_FILE, "")) if enabled() else ""
	_journal = String(run.flags.get(FLAG_JOURNAL, ""))
	_run_seconds = float(run.flags.get(FLAG_SECONDS, 0.0))
	_deadline_seconds = 0.0
	_write({"t": "resume", "n": run.total_spins})


## Avant une sauvegarde : le chronomètre du run voyage avec la sauvegarde.
func sync(run: RunState) -> void:
	run.flags[FLAG_SECONDS] = snappedf(_run_seconds, 0.1)


func betting_started() -> void:
	_think_seconds = 0.0


func before_spin(run: RunState) -> void:
	_pre = RunTelemetry.snapshot(run)


func after_spin(run: RunState, outcome: RunController.SpinOutcome) -> void:
	if _pre.is_empty():
		_pre = RunTelemetry.snapshot(run)
	var rec: Dictionary = RunTelemetry.spin(_pre, run, outcome.ctx, _think_seconds)
	rec["slot"] = outcome.slot
	_write(rec)
	if outcome.deadline_won or outcome.deadline_failed:
		_write(RunTelemetry.deadline(_pre, run, outcome.ctx, outcome.deadline_won, _deadline_seconds))
		_deadline_seconds = 0.0
	_pre = {}


func shop_opened(run: RunState) -> void:
	_shop_before = RunTelemetry.grigri_ids(run)
	_shop_money = run.money
	_shop_offered.clear()
	_shop_bought.clear()
	_shop_rerolls = 0
	_shop_seconds = 0.0
	_collect_offers(run)


## À appeler avant un reroll (les offres affichées vont disparaître) et à la fermeture.
func _collect_offers(run: RunState) -> void:
	for o: Dictionary in RunTelemetry.shop_offers(run):
		var gid: String = String(o["id"])
		if bool(o.get("sold", false)):
			if not _shop_bought.has(gid):
				_shop_bought.append(gid)
		if not _shop_offered.has(gid):
			_shop_offered.append(gid)


func shop_rerolling(run: RunState) -> void:
	_collect_offers(run)
	_shop_rerolls += 1


func shop_rerolled(run: RunState) -> void:
	_collect_offers(run)


func shop_closed(run: RunState) -> void:
	_collect_offers(run)
	_write(RunTelemetry.shop(run, _shop_offered, _shop_bought, _shop_before, _shop_money, _shop_rerolls, _shop_seconds))


func end(run: RunState, victory: bool) -> void:
	_write(RunTelemetry.run_end(run, victory, _run_seconds))
	_file = ""
	_journal = ""


## Une épreuve jouée (`PlayJournal.trial`) : dans le journal du run, sinon dans celui du Musée.
func trial(rec: Dictionary) -> void:
	if _journal != "" and String(rec.get("context", "")) == "run":
		_write(rec)
		return
	DirAccess.make_dir_recursive_absolute(journal_dir())
	_append(journal_dir() + MUSEUM_FILE, rec)


## Garde les JOURNAL_KEEP runs les plus récents (noms horodatés : l'ordre alphabétique suffit).
func _rotate() -> void:
	var runs: Array[String] = []
	for f: String in DirAccess.get_files_at(journal_dir()):
		if f.begins_with("run_") and f.ends_with(".jsonl"):
			runs.append(f)
	runs.sort()
	while runs.size() >= JOURNAL_KEEP:
		DirAccess.remove_absolute(journal_dir() + runs.pop_front())


## Note de test (humeur + texte + capture éventuelle). Hors run : fichier de notes générales.
func note(run: RunState, mood: String, text: String, screen: String, shot: Image) -> String:
	DirAccess.make_dir_recursive_absolute(directory() + SHOTS_DIR)
	var shot_path: String = ""
	if shot != null:
		shot_path = directory() + SHOTS_DIR + "note_%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
		shot.save_png(shot_path)
	var rec: Dictionary = RunTelemetry.note(run, mood, text, screen, shot_path.get_file())
	if _file != "":
		_write(rec)
	else:
		_append(directory() + "notes.jsonl", rec)
	return shot_path


# --------------------------------------------------------------------------- écriture


func _write(rec: Dictionary) -> void:
	rec["at"] = snappedf(_run_seconds, 0.1)
	if _journal != "":
		_append(_journal, rec)
	if _file != "" and enabled():
		_append(_file, rec)


static func _append(path: String, rec: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(rec))
	f.close()
