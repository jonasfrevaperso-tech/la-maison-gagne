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
