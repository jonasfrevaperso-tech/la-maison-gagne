extends TestCase
## 2.0 « La Grande Saison » : correctifs, épreuves approfondies, export, difficulté, builds, salles.


func _boot() -> void:
	AudioBus.hush(true)
	if DataRegistry.db == null:
		DataRegistry.db = ContentDB.shared()
	if SaveSystem.profile.is_empty():
		SaveSystem.profile = SaveSystem.default_profile()
	if TranslationServer.translate(&"MUSEUM_COUNT") == "MUSEUM_COUNT":
		TranslationServer.add_translation(load("res://localization/strings.fr.translation") as Translation)
		TranslationServer.set_locale("fr")


func _trial(id: String) -> ThrowTrial:
	var tr: ThrowTrial = (load(ThrowMinigame.TRIAL_SCRIPTS % id) as GDScript).new() as ThrowTrial
	tr.setup(DataRegistry.db.get_entry("throw_trials", id), 1, false, false)
	tr.size = UiLayout.DESIGN_SIZE
	tr._begun = true
	tr.begin()
	return tr


## Pluie : une part de chaque prise est acquise ; une pile renversée garde sa moitié basse.
func test_catch_topple_keeps_half() -> void:
	_boot()
	var c: TrialCatch = _trial("catch") as TrialCatch
	c._catch({"kind": "chip", "bonus": ""}, Vector2(500, 600))
	check(c._banked > 0.0, "une part de la prise est acquise d'office")
	c._stack_n = 8
	c._stack_val = 8.0
	c._topple()
	eq(c._stack_n, 4, "la moitié basse de la pile reste")
	check(c._stack_val > 0.0, "la valeur de la moitié basse est gardée")
	c.free()


## Personnage articulé : toutes les poses se calculent, le corps glisse vers la pose demandée.
func test_figure_poses() -> void:
	_boot()
	var f: Figure3D = Figure3D.new().build(1.0, {"hat": "top"})
	for a: StringName in [&"idle", &"run", &"walk", &"jump", &"fall", &"hang", &"stun", &"cheer"]:
		for k: int in 20:
			f.animate(a, float(k) * 0.3, 1.0 / 60.0, 0.5)
	var sh: Node3D = f.find_child("sh_l", true, false) as Node3D
	check(sh != null and sh.rotation.x < -1.0, "bras levés en fin de « cheer »")
	f.free()


## Tuto : la démo est ralentie et dure au moins une étape de lecture par consigne.
func test_tuto_demo_pace() -> void:
	_boot()
	var g: ThrowMinigame = ThrowMinigame.new()
	g._rehearsal = "demo"
	g.trial = _trial("pour")
	g.trial.tuto_lines.assign(["a", "b", "c"])
	check(g._rehearsal_limit() >= Balance.f("throw_game.tuto_step_seconds") * 3.0 - 0.01
		or g._rehearsal_limit() >= Balance.f("throw_game.tuto_demo_max") - 0.01, "au moins une étape de lecture par consigne")
	check(Balance.f("throw_game.tuto_demo_speed") < 1.0, "démo ralentie")
	g.trial.free()
	g.free()


## Verre parfait : verre penché, beaucoup moins de mousse ; débordement = col perdu.
func test_pour_tilt_and_spill() -> void:
	_boot()
	var t: TrialPour = _trial("pour") as TrialPour
	t._tilt = 0.0
	var upright: float = t._foam_ratio()
	t._tilt = 1.0
	check(t._foam_ratio() < upright * 0.3, "penché : peu de mousse")
	t._tilt = 0.0
	t.press()
	for k: int in 600:
		t.tick(1.0 / 60.0)
		if t._spilled:
			break
	check(t._spilled, "verser sans s'arrêter finit par déborder")
	check(not t._pouring, "le débordement arrête le service")
	t.free()


## Bonneteau : une feinte ne change rien, une rotation à trois déplace trois gobelets.
func test_shells_feint_and_cycle() -> void:
	_boot()
	var t: TrialShells = _trial("shells") as TrialShells
	t._cups = 4
	t._slot.assign([0, 1, 2, 3])
	t._apply_move({"s": [0, 1], "kind": "feint"})
	eq(t._slot, [0, 1, 2, 3] as Array[int], "feinte : rien ne bouge")
	t._apply_move({"s": [0, 1, 2], "kind": "cycle"})
	eq(t._slot, [1, 2, 0, 3] as Array[int], "rotation : 0→1, 1→2, 2→0")
	t._apply_move({"s": [1, 3], "kind": "swap"})
	eq(t._slot, [3, 2, 0, 1] as Array[int], "échange simple")
	t.free()


## Tiercé : une haie manquée fait chuter (vitesse perdue) ; sautée au bon temps, elle passe.
func test_derby_hurdle() -> void:
	_boot()
	var d: TrialDerby = _trial("derby") as TrialDerby
	var jb: int = d._jumps[0]
	d._speed[TrialDerby.ME] = 0.1
	d.t = (float(jb) + d.p("jump_window") + 0.05) * d._beat()
	d.tick(1.0 / 60.0)
	check(d._stun > 0.0 and d._speed[TrialDerby.ME] < 0.05, "haie manquée : chute")
	var jb2: int = d._jumps[1]
	d._stun = 0.0
	d.t = float(jb2) * d._beat()
	d.jump()
	check(d._jumped.get(jb2, false), "saut au temps : haie franchie")
	d.free()


## Billard : la noire touchée par la blanche est une faute ; l'effet rétro fait revenir la blanche.
func test_billiards_black_and_spin() -> void:
	_boot()
	var b: TrialBilliards = _trial("billiards") as TrialBilliards
	b._shot = 1
	b._rack()
	check(b._black_on, "la noire est sur le tapis à partir du 2e coup")
	# Blanche droit sur la noire.
	b._cue = b.TABLE.get_center()
	b._obj = b.TABLE.position + Vector2(100, 100)
	b._xp[0] = b._cue + Vector2(200, 0)
	b._xin[0] = false
	b._spin = 0
	b._cue_v = Vector2(800, 0)
	b._rolling = true
	for k: int in 600:
		b._physics(1.0 / 60.0 / float(TrialBilliards.SUBSTEPS))
	check(b._foul, "la blanche a touché la noire : faute")
	# Rétro : la blanche repart en arrière après un choc plein.
	b._foul = false
	b._spun = false
	b._spin = -1
	b._xin[0] = true
	b._cue = b.TABLE.get_center()
	b._obj = b._cue + Vector2(100, 0)
	b._cue_v = Vector2(800, 0)
	b._obj_v = Vector2.ZERO
	for k2: int in 120:
		b._physics(1.0 / 60.0 / float(TrialBilliards.SUBSTEPS))
	check(b._cue_v.x < 0.0, "rétro : la blanche revient")
	b.free()


## Lasers : le rideau barre la porte tant que la dalle n'est pas foulée.
func test_lasers_switch_opens_curtain() -> void:
	_boot()
	var l: TrialLasers = _trial("lasers") as TrialLasers
	var at: Vector2 = Vector2(TrialLasers.BARRIER_X, TrialLasers.ROOM.get_center().y)
	check(l._hit_at(at, l.t), "rideau fermé : on ne passe pas")
	l._pos = l._switch
	l.tick(1.0 / 60.0)
	check(l._open_t > 0.0, "dalle foulée : rideau dévié")
	check(not l._hit_at(at, l.t), "rideau dévié : la voie est libre")
	l.free()


## Tri : un piège trié est une faute ; un double demande ses deux couleurs ; les bacs tournent.
func test_sort_types_and_turning_bins() -> void:
	_boot()
	var s: TrialSort = _trial("sort") as TrialSort
	var at: Vector2 = s._window().get_center()
	s._chips.append({"p": at, "kind": 0, "kind2": 2, "type": "trap", "half": -1, "shown": true, "done": false, "to": -1, "t": 0.0})
	s.sort(0)
	eq(s._wrong, 1, "piège trié : faute")
	s._chips.clear()
	s._chips.append({"p": at, "kind": 0, "kind2": 2, "type": "double", "half": -1, "shown": true, "done": false, "to": -1, "t": 0.0})
	s.sort(2)
	s.sort(0)
	eq(s._good, 1, "double : deux couleurs, un jeton bien trié")
	s._rotate_bins()
	check(s._perm != [0, 1, 2, 3], "les bacs ont tourné")
	eq(s._perm[s._key_for(1)], 1, "le bot retrouve le bon bouton")
	s.free()


## Bouteilles : le vent dévie le point d'arrivée, et le tir est jugé à l'arrivée.
func test_bottles_wind_drift() -> void:
	_boot()
	var b: TrialBottles = _trial("bottles") as TrialBottles
	b._wind = 120.0
	b._shelf_v = 0.0
	b._aim_lock = b._xs[b._target]
	b._pow_sc = 1.0
	b._land()
	check(not b._hit, "visée pile sur la bouteille mais vent ignoré : raté")
	b._throw = 1
	b._next_target()
	b._wind = 120.0
	b._aim_lock = b._xs[b._target] - 120.0
	b._land()
	check(b._hit, "visée corrigée du vent : touché")
	b.free()


## Tour : la pose se juge dans le repère de la pile qui oscille ; les légers l'agitent.
func test_tower_sway_and_kinds() -> void:
	_boot()
	var tw: TrialTower = _trial("tower") as TrialTower
	var calm: float = tw._sway_amp()
	tw._stack.append(Vector2(tw._stack[-1].x, tw._stack[-1].y))
	tw._kinds.append(TrialTower.Kind.LIGHT)
	check(tw._sway_amp() > calm, "pile plus haute et légère : plus d'oscillation")
	tw._sway = 40.0
	tw._x = tw._stack[-1].x + tw._off(tw._stack.size())
	tw.drop()
	eq(tw._perfects, 1, "sommet décalé par l'oscillation, visé où il est : pile !")
	tw.free()


## Journal → CSV : guillemets, listes, fusion début / fin de run, une ligne par achat.
func test_journal_csv_tables() -> void:
	var text: String = "\n".join(PackedStringArray([
		JSON.stringify({"t": "run_start", "character": "joueur", "seed": 7}),
		JSON.stringify({"t": "spin", "n": 1, "score": 120, "grigris": ["a", "b"], "slot": [{"reels": ["x"], "prize": ""}]}),
		JSON.stringify({"t": "shop", "bought": ["g1", "g2"], "money_before": 30, "money_after": 5}),
		JSON.stringify({"t": "run_end", "victory": true, "tier": 4}),
		"pas du json",
	]))
	var recs: Array[Dictionary] = JournalCsv.parse_jsonl(text, "run_a")
	eq(recs.size(), 4, "la ligne illisible est ignorée (sans bruit)")
	var runs: PackedStringArray = JournalCsv.runs(recs).strip_edges().split("\n")
	eq(runs.size(), 2, "un run = une ligne (plus l'en-tête)")
	check(runs[1].begins_with("run_a,") and runs[1].contains(",joueur,") and runs[1].contains(",1,4,"), "début et fin réunis")
	var spins: String = JournalCsv.table(JournalCsv.of_kind(recs, "spin"), JournalCsv.SPIN_COLS)
	check(spins.contains(",a|b,"), "les grigris sont joints par |")
	check(spins.contains("\"[{\"\"prize\"\""), "la machine à sous est un JSON entre guillemets")
	eq(JournalCsv.purchases(recs).strip_edges().split("\n").size(), 3, "une ligne par grigri acheté")
	eq(JournalCsv.cell("a,b"), "\"a,b\"", "virgule échappée")


## Export : l'archive contient sauvegardes, journal, CSV et README ; une épreuve est journalisée.
func test_data_export_zip() -> void:
	_boot()
	var rec: Dictionary = RunTelemetry.trial("darts", "museum", "normal", 0.8, 12.5, 25, "pad", {"beats": []})
	eq(rec["gestures_per_s"], 2.0, "gestes par seconde")
	Telemetry.trial(rec)
	var museum: String = FileAccess.get_file_as_string(Telemetry.journal_dir() + Telemetry.MUSEUM_FILE)
	check(museum.contains("\"id\":\"darts\""), "l'épreuve du Musée est dans museum.jsonl")
	var path: String = DevMode.save_dir() + "test_export.zip"
	eq(DataExport.build(path), OK, "archive construite")
	var zip: ZIPReader = ZIPReader.new()
	eq(zip.open(path), OK, "archive lisible")
	var files: PackedStringArray = zip.get_files()
	for f: String in ["README.txt", "csv/runs.csv", "csv/spins.csv", "csv/deadlines.csv", "csv/trials.csv", "csv/purchases.csv",
			"journal/" + Telemetry.MUSEUM_FILE]:
		check(files.has(f), "contient " + f)
	var trials: String = zip.read_file("csv/trials.csv").get_string_from_utf8()
	check(trials.contains(",museum,darts,normal,0.8,"), "la ligne de l'épreuve est dans trials.csv")
	zip.close()
	DirAccess.remove_absolute(path)


## Builds 2.0 : 28 familles de 7 ; le build complet (7) active le palier le plus fort.
func test_families_of_seven() -> void:
	var db: ContentDB = ContentDB.shared()
	eq(db.list("families").size(), 28, "28 familles")
	var c: RunController = RunController.new(db)
	c.new_run("lea", 0, 5)
	var members: Array[String] = []
	for g: Dictionary in db.list("grigris"):
		if String(g.get("family", "")) == "pleins":
			members.append(String(g["id"]))
	eq(members.size(), 7, "7 grigris dans Le Plein")
	c.run.grigri_slots = 8
	for gid: String in members:
		c.run.add_grigri(gid)
	var act: Array[Dictionary] = Families.active(c.run, db)
	var tier: int = -1
	for fa: Dictionary in act:
		if String(fa["id"]) == "pleins":
			tier = int(fa["tier"])
	eq(tier, 2, "build complet : palier 7 actif")
