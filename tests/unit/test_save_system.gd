extends TestCase
## Sauvegardes : écriture atomique, copie de secours, corruption, migration de profil.

const SAVE_SCRIPT: String = "res://scripts/autoload/save_system.gd"
const PATH: String = "user://test_save.json"

var ss: GDScript = null


func before_each() -> void:
	ss = load(SAVE_SCRIPT) as GDScript
	for p: String in [PATH, PATH + ".bak", PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func test_atomic_write_and_read() -> void:
	check(bool(ss.call("write_atomic", PATH, {"a": 1})), "écriture")
	var d: Dictionary = ss.call("read_with_backup", PATH)
	eq(int(d.get("a", 0)), 1)
	check(not FileAccess.file_exists(PATH + ".tmp"), "pas de fichier temporaire résiduel")


func test_corruption_falls_back_to_backup() -> void:
	ss.call("write_atomic", PATH, {"v": 1})
	ss.call("write_atomic", PATH, {"v": 2})  # la v1 passe en .bak
	var f: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{ corrompu")
	f.close()
	var d: Dictionary = ss.call("read_with_backup", PATH)
	eq(int(d.get("v", 0)), 1, "relu depuis la copie de secours")


func test_profile_migration_fills_missing_keys() -> void:
	var inst: Node = ss.new() as Node
	var old: Dictionary = {"version": 0, "stats": {"runs": 7}}
	var migrated: Dictionary = inst.call("migrate_profile", old)
	eq(int((migrated["stats"] as Dictionary)["runs"]), 7, "données conservées")
	check((migrated["stats"] as Dictionary).has("wins"), "clé ajoutée")
	check(migrated.has("unlocked_characters"), "section ajoutée")
	inst.free()


func test_run_state_survives_disk_roundtrip() -> void:
	var c: RunController = RunController.new(ContentDB.shared())
	c.new_run("barnabe", 2, 31337)
	c.place_bet("red", 3)
	c.spin(4)
	ss.call("write_atomic", PATH, c.run.to_dict())
	var back: RunState = RunState.from_dict(ss.call("read_with_backup", PATH) as Dictionary)
	eq(JSON.stringify(back.to_dict()), JSON.stringify(c.run.to_dict()))
