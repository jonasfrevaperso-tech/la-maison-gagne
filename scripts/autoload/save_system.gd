extends Node
## Sauvegardes versionnées dans user:// : écriture atomique (fichier temporaire + renommage),
## copie de secours (.bak) et migrations. Deux fichiers : profil (méta) et run en cours.

const PROFILE_PATH: String = "user://profile.json"
const RUN_PATH: String = "user://run.json"
const PROFILE_VERSION: int = 1
const TMP_SUFFIX: String = ".tmp"
const BAK_SUFFIX: String = ".bak"

## Fichiers corrompus rencontrés (la copie de secours a pris le relais) : signalés à l'écran titre.
static var corrupted_files: Array[String] = []

var profile: Dictionary = {}


func _ready() -> void:
	profile = load_profile()


# --------------------------------------------------------------------------- bas niveau


static func write_atomic(path: String, data: Dictionary) -> bool:
	var text: String = JSON.stringify(data, "\t")
	var tmp: String = path + TMP_SUFFIX
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem : écriture impossible %s" % tmp)
		return false
	f.store_string(text)
	f.close()
	# Vérifie la relecture avant de remplacer.
	var check: Variant = parse_quiet(FileAccess.get_file_as_string(tmp))
	if not (check is Dictionary):
		push_error("SaveSystem : vérification échouée %s" % tmp)
		return false
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + BAK_SUFFIX)
	var err: Error = DirAccess.rename_absolute(tmp, path)
	return err == OK


static func read_with_backup(path: String) -> Dictionary:
	for candidate: String in [path, path + BAK_SUFFIX]:
		if not FileAccess.file_exists(candidate):
			continue
		var parsed: Variant = parse_quiet(FileAccess.get_file_as_string(candidate))
		if parsed is Dictionary:
			return parsed as Dictionary
		corrupted_files.append(candidate)
	return {}


## Analyse JSON sans journaliser d'erreur moteur (un fichier corrompu est un cas prévu).
static func parse_quiet(text: String) -> Variant:
	var j: JSON = JSON.new()
	if j.parse(text) != OK:
		return null
	return j.data


# --------------------------------------------------------------------------- profil


func default_profile() -> Dictionary:
	return {
		"version": PROFILE_VERSION,
		"unlocked_characters": ["lea", "vic", "odile", "barnabe", "marthe"],
		"max_risk": {},
		"achievements": [],
		"challenges_done": [],
		"seen": {"grigris": [], "pockets": [], "fortunes": [], "contracts": [], "creditors": []},
		"stats": {"runs": 0, "wins": 0, "spins": 0, "best_spin": 0, "zeros": 0, "money_earned": 0},
		"campaign": {"act_reached": 1, "endings": [], "dialogues_seen": []},
		"tutorial": {"done": false, "tips_seen": []},
		"daily": {"last_date": "", "best": 0},
		"favorites": [],
	}


func load_profile() -> Dictionary:
	var d: Dictionary = read_with_backup(PROFILE_PATH)
	if d.is_empty():
		return default_profile()
	return migrate_profile(d)


## Migrations successives : complète les clés absentes, met à jour la version.
func migrate_profile(d: Dictionary) -> Dictionary:
	var base: Dictionary = default_profile()
	for k: Variant in base.keys():
		if not d.has(k):
			d[k] = base[k]
		elif base[k] is Dictionary and d[k] is Dictionary:
			for sk: Variant in (base[k] as Dictionary).keys():
				if not (d[k] as Dictionary).has(sk):
					(d[k] as Dictionary)[sk] = (base[k] as Dictionary)[sk]
	d["version"] = PROFILE_VERSION
	return d


func save_profile() -> void:
	write_atomic(PROFILE_PATH, profile)


func mark_seen(cat: String, entry_id: String) -> void:
	var seen: Dictionary = profile["seen"]
	if not seen.has(cat):
		seen[cat] = []
	var arr: Array = seen[cat]
	if not arr.has(entry_id):
		arr.append(entry_id)


func add_stat(key: String, amount: int) -> void:
	var st: Dictionary = profile["stats"]
	st[key] = int(st.get(key, 0)) + amount


func max_stat(key: String, value: int) -> void:
	var st: Dictionary = profile["stats"]
	st[key] = maxi(int(st.get(key, 0)), value)


# --------------------------------------------------------------------------- run


func has_run() -> bool:
	return not read_with_backup(RUN_PATH).is_empty()


func save_run(run: RunState) -> void:
	write_atomic(RUN_PATH, run.to_dict())


func load_run() -> RunState:
	var d: Dictionary = read_with_backup(RUN_PATH)
	if d.is_empty():
		return null
	if int(d.get("version", 0)) > RunState.SAVE_VERSION:
		push_warning("SaveSystem : run d'une version future ignoré")
		return null
	return RunState.from_dict(d)


func clear_run() -> void:
	for p: String in [RUN_PATH, RUN_PATH + BAK_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
