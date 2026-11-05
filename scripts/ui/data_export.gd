class_name DataExport
extends RefCounted
## « Exporter mes données » : une archive .zip lisible par n'importe quel tableur ou script —
## sauvegardes (profil, run en cours, réglages), journal brut (JSONL) et tableaux CSV (runs,
## tours, échéances, épreuves, achats), plus un README qui décrit les champs.
## PC : dans Documents, puis le dossier s'ouvre. Android : sélecteur de fichiers du système
## (SAF), à défaut dans Téléchargements, à défaut dans les données de l'application.

const PREFIX: String = "LaMaisonGagne-donnees-"
const README_SOURCE: String = "res://data/export/README.txt"
const STAGING: String = "export/"
## Chemin rendu quand le joueur ferme le sélecteur sans choisir.
const CANCELLED: String = "<cancelled>"


static func file_name() -> String:
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	return PREFIX + stamp + ".zip"


## Construit l'archive en `path`. Retourne OK ou le code d'erreur.
static func build(path: String) -> Error:
	var zip: ZIPPacker = ZIPPacker.new()
	var err: Error = zip.open(path)
	if err != OK:
		return err
	var dir: String = DevMode.save_dir()
	for f: String in [SaveSystem.PROFILE_FILE, SaveSystem.RUN_FILE, Settings.FILE]:
		if FileAccess.file_exists(dir + f):
			_put(zip, "saves/" + f, FileAccess.get_file_as_bytes(dir + f))
	var records: Array[Dictionary] = []
	var jdir: String = Telemetry.journal_dir()
	for f: String in _jsonl_files(jdir):
		var text: String = FileAccess.get_file_as_string(jdir + f)
		_put(zip, "journal/" + f, text.to_utf8_buffer())
		records.append_array(JournalCsv.parse_jsonl(text, f.get_basename()))
	_put(zip, "csv/runs.csv", JournalCsv.runs(records).to_utf8_buffer())
	_put(zip, "csv/spins.csv", JournalCsv.table(JournalCsv.of_kind(records, "spin"), JournalCsv.SPIN_COLS).to_utf8_buffer())
	var deadlines: Array[Dictionary] = JournalCsv.of_kind(records, "deadline")
	_put(zip, "csv/deadlines.csv", JournalCsv.table(deadlines, JournalCsv.DEADLINE_COLS).to_utf8_buffer())
	_put(zip, "csv/trials.csv", JournalCsv.table(JournalCsv.of_kind(records, "trial"), JournalCsv.TRIAL_COLS).to_utf8_buffer())
	_put(zip, "csv/purchases.csv", JournalCsv.purchases(records).to_utf8_buffer())
	_put(zip, "README.txt", FileAccess.get_file_as_bytes(README_SOURCE))
	return zip.close()


static func _jsonl_files(dir: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".jsonl"):
			out.append(f)
	out.sort()
	return out


static func _put(zip: ZIPPacker, name: String, bytes: PackedByteArray) -> void:
	zip.start_file(name)
	zip.write_file(bytes)
	zip.close_file()


## Lance l'export selon la plateforme ; `done(path)` reçoit le chemin final (vide : échec ;
## CANCELLED : sélecteur fermé).
static func run(done: Callable) -> void:
	var staging: String = DevMode.save_dir() + STAGING
	DirAccess.make_dir_recursive_absolute(staging)
	var name: String = file_name()
	var temp: String = staging + name
	if build(temp) != OK:
		done.call("")
		return
	if not Platform.is_mobile():
		var docs: String = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		var dest: String = docs.path_join(name) if docs != "" else ProjectSettings.globalize_path(temp)
		if dest != ProjectSettings.globalize_path(temp) and DirAccess.copy_absolute(temp, dest) != OK:
			dest = ProjectSettings.globalize_path(temp)
		OS.shell_open(dest.get_base_dir())
		done.call(dest)
		return
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		var cb: Callable = func(ok: bool, paths: PackedStringArray, _filter: int) -> void:
			done.call(_copy_to(temp, paths[0]) if ok and not paths.is_empty() else CANCELLED)
		var shown: Error = DisplayServer.file_dialog_show("", "", name, false, DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,
			PackedStringArray(["*.zip"]), cb)
		if shown == OK:
			return
	done.call(_fallback(temp))


## Copie octet par octet (marche aussi vers un document choisi dans le sélecteur Android).
static func _copy_to(src: String, dest: String) -> String:
	var f: FileAccess = FileAccess.open(dest, FileAccess.WRITE)
	if f == null:
		return _fallback(src)
	f.store_buffer(FileAccess.get_file_as_bytes(src))
	f.close()
	return dest


static func _fallback(temp: String) -> String:
	var dl: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if dl != "":
		var dest: String = dl.path_join(temp.get_file())
		if DirAccess.copy_absolute(temp, dest) == OK:
			return dest
	return ProjectSettings.globalize_path(temp)
