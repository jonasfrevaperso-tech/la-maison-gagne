extends SceneTree
## Runner de tests headless : charge tous les scripts tests/**/test_*.gd et exécute
## leurs méthodes test_*. Code de sortie 1 en cas d'échec.
## Usage : godot --headless --path . -s res://tests/run_tests.gd [-- --filter=nom]

const ROOTS: Array[String] = ["res://tests/unit", "res://tests/integration"]


func _initialize() -> void:
	Engine.set_meta(&"no_trial_tutos", true)  # les tests qui en ont besoin le rallument (ThrowMinigame)
	var filter: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--filter="):
			filter = a.substr(9)
	var files: Array[String] = []
	for root: String in ROOTS:
		_collect(root, files)
	files.sort()
	var total: int = 0
	var failed: int = 0
	var all_failures: Array[String] = []
	var t0: int = Time.get_ticks_msec()
	for path: String in files:
		var script: GDScript = load(path) as GDScript
		if script == null:
			all_failures.append("Impossible de charger %s" % path)
			failed += 1
			continue
		for m: Dictionary in script.get_script_method_list():
			var mname: String = String(m["name"])
			if not mname.begins_with("test_"):
				continue
			if filter != "" and not (path + ":" + mname).contains(filter):
				continue
			var inst: TestCase = script.new() as TestCase
			inst.current_test = "%s::%s" % [path.get_file(), mname]
			inst.before_each()
			inst.call(mname)
			total += 1
			if not inst.failures.is_empty():
				failed += 1
				all_failures.append_array(inst.failures)
	for f: String in all_failures:
		printerr("ÉCHEC  " + f)
	print("Tests : %d exécutés, %d en échec (%d ms)" % [total, failed, Time.get_ticks_msec() - t0])
	quit(1 if failed > 0 else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for f: String in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for d: String in dir.get_directories():
		_collect(dir_path.path_join(d), out)
