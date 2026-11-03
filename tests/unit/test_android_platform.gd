extends TestCase
## Android : profil de plateforme et qualité du rendu. Le profil PC ne doit jamais changer.


func _with(mobile: int, body: Callable) -> void:
	var before: int = Platform.force
	Platform.force = mobile
	body.call()
	Platform.force = before
	RenderQuality.governed = ""


func test_pc_profile_unchanged() -> void:
	_with(0, func() -> void:
		check(not Platform.is_mobile(), "PC : pas mobile")
		var hh: bool = Settings.b("video", "handheld")
		eq(RenderQuality.level(), "handheld" if hh else "pc", "PC : niveau historique")
		eq(RenderQuality.scale_3d(), clampf(Settings.f("video", "render_scale"), 0.5, 1.0), "PC : échelle du réglage")
		check(RenderQuality.scaling_mode(true) == Viewport.SCALING_3D_MODE_BILINEAR, "vue transparente : toujours bilinéaire")
	)


## PC : un préréglage écrit tous les réglages fins ; en toucher un passe en Personnalisé ;
## « Élevé » reproduit le rendu des versions précédentes (100 %, MSAA 4x, ombres).
func test_graphics_presets() -> void:
	_with(0, func() -> void:
		var saved: Dictionary = {}
		for k: String in RenderQuality.PRESET_KEYS + ["preset", "handheld"]:
			saved[k] = Settings.get_value("video", k)
		Settings.set_value("video", "preset", "high")
		eq(Settings.s("video", "preset"), "high", "préréglage retenu")
		eq(RenderQuality.scale_3d(), 1.0, "Élevé : rendu plein")
		eq(RenderQuality.msaa(Viewport.MSAA_4X), Viewport.MSAA_4X, "Élevé : MSAA 4x")
		check(RenderQuality.shadows(), "Élevé : ombres")
		Settings.set_value("video", "preset", "low")
		check(not RenderQuality.shadows(), "Bas : sans ombres")
		eq(RenderQuality.scaling_mode(false), Viewport.SCALING_3D_MODE_FSR, "Bas : FSR 1")
		check(RenderQuality.particles(100) < 100, "Bas : moins de particules")
		Settings.set_value("video", "msaa", 2)
		eq(Settings.s("video", "preset"), "custom", "un réglage fin passe en Personnalisé")
		eq(int(Settings.get_value("video", "msaa")), 2, "le réglage fin est gardé")
		for k2: String in saved.keys():
			Settings.override("video", k2, saved[k2])
		Settings.save_settings()
	)


## Migration : l'ancienne VSync booléenne devient un mode ; un mode portable hérité devient le
## préréglage Steam Deck.
func test_vsync_and_handheld_migration() -> void:
	var cfg: ConfigFile = Settings._cfg
	var before: ConfigFile = ConfigFile.new()
	before.parse(cfg.encode_to_text())
	cfg.set_value("video", "vsync", false)
	cfg.set_value("video", "handheld", true)
	if cfg.has_section_key("video", "preset"):
		cfg.erase_section_key("video", "preset")
	Settings._migrate()
	eq(Settings.s("video", "vsync"), "off", "VSync booléenne → « off »")
	eq(Settings.s("video", "preset"), "deck", "portable → préréglage Steam Deck")
	Settings._cfg = before
	Settings.save_settings()


func test_mobile_quality_levels() -> void:
	_with(1, func() -> void:
		var saved: String = Settings.s("video", "quality")
		Settings.set_value("video", "quality", "balanced")
		if not RenderQuality.is_compat():
			eq(RenderQuality.level(), "balanced", "mobile : niveau du réglage")
			eq(RenderQuality.scale_3d(0.7), 0.7, "Équilibré : 3D à 70 %")
			check(not RenderQuality.shadows(), "Équilibré : sans ombres")
			Settings.set_value("video", "quality", "high")
			check(RenderQuality.shadows(), "Beau : ombres")
			RenderQuality.governed = "eco"
			eq(RenderQuality.level(), "eco", "le gouverneur abaisse la qualité")
			eq(RenderQuality.msaa(Viewport.MSAA_4X, Viewport.MSAA_2X), Viewport.MSAA_DISABLED, "Économie : sans MSAA")
		Settings.set_value("video", "quality", saved)
	)


func test_cover_counter() -> void:
	check(not RenderQuality.covered(), "rien ne couvre au départ")
	RenderQuality.cover(true)
	RenderQuality.cover(true)
	RenderQuality.cover(false)
	check(RenderQuality.covered(), "encore une couverture")
	RenderQuality.cover(false)
	RenderQuality.cover(false)
	check(not RenderQuality.covered(), "compteur jamais négatif")


func test_safe_rect_on_pc_is_full_screen() -> void:
	_with(0, func() -> void:
		var vp: Viewport = Engine.get_main_loop().root if Engine.get_main_loop() is SceneTree else null
		if vp != null:
			eq(Platform.safe_rect(vp), vp.get_visible_rect(), "PC : tout l'écran est utile")
	)


func test_touch_glyphs() -> void:
	var before_touch: bool = InputGlyphs.using_touch
	var before_pad: bool = InputGlyphs.using_pad
	InputGlyphs.using_pad = false
	InputGlyphs.using_touch = true
	eq(InputGlyphs.parts_for("@click"), ["touch_tap"] as Array[String], "toucher = clic")
	eq(InputGlyphs.parts_for("@right_click"), ["touch_hold"] as Array[String], "appui long = clic droit")
	eq(InputGlyphs.parts_for("qte_right"), ["pad_b"] as Array[String], "pavé tactile : B")
	check(InputGlyphs.parts_for("pause_menu").is_empty(), "pas de touche clavier au doigt")
	InputGlyphs.using_touch = before_touch
	InputGlyphs.using_pad = before_pad


func test_input_mode_choices_per_platform() -> void:
	_with(0, func() -> void:
		check((InputGlyphs.mode_choices()[0] as Array).has("keyboard"), "PC : clavier proposé")
		eq(Platform.audio_offset(), 0.0, "PC : aucun décalage audio")
	)
	_with(1, func() -> void:
		var vals: Array = InputGlyphs.mode_choices()[0]
		check(vals.has("touch") and not vals.has("keyboard"), "mobile : doigt au lieu du clavier")
		eq(vals.size(), (InputGlyphs.mode_choices()[1] as Array).size(), "autant de libellés que de valeurs")
	)


## Doigt posé, glissé puis relevé : la mise visée sous le doigt est posée (taille de mise choisie).
func test_touch_bet_place_and_remove() -> void:
	var before_touch: bool = InputGlyphs.using_touch
	var saved_3d: bool = Settings.b("video", "wheel_3d")
	var saved_confirm: bool = Settings.b("game", "tap_confirm")
	Settings.set_value("video", "wheel_3d", false)
	Settings.set_value("game", "tap_confirm", false)
	InputGlyphs.using_touch = true
	var tv: TableView = TableView.new()
	tv.size = Vector2(1400, 520)
	(Engine.get_main_loop() as SceneTree).root.add_child(tv)
	tv._layout()
	tv.slip = BetSlip.new()
	tv.bet_amount = 2
	var got: Array[Array] = []
	tv.spot_changed.connect(func(s: String, d: int) -> void: got.append([s, d]))
	var target: Vector2 = tv.number_center(17)
	tv._touch_input(_mb(target + Vector2(30, 30), true))
	var mm: InputEventMouseMotion = InputEventMouseMotion.new()
	mm.position = target
	tv._touch_input(mm)
	check(tv.touch_aiming, "visée en cours")
	tv._touch_input(_mb(target, false))
	eq(got, [["straight:17", 2]] as Array[Array], "relâcher pose la mise visée")
	# Appui long immobile sur une pile : −1 jeton, pas de pose au relâcher.
	tv.slip.chips["straight:17"] = 2
	got.clear()
	tv._touch_input(_mb(target, true))
	tv._touch_hold(TableView.TOUCH_HOLD_REMOVE + 0.05)
	tv._touch_input(_mb(target, false))
	eq(got, [["straight:17", -1]] as Array[Array], "appui long = retirer un jeton")
	tv.queue_free()
	InputGlyphs.using_touch = before_touch
	Settings.set_value("video", "wheel_3d", saved_3d)
	Settings.set_value("game", "tap_confirm", saved_confirm)


func _mb(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var mb: InputEventMouseButton = InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.position = at
	return mb


## Mise en arrière-plan (appel, accueil) : la partie est sauvegardée, le son coupé puis rendu ;
## l'application tuée ensuite se reprend depuis cette sauvegarde.
func test_background_saves_and_mutes() -> void:
	var saved_path: String = SaveSystem.run_path
	var saved_profile: String = SaveSystem.profile_path
	SaveSystem.run_path = "user://test_android_run.json"
	SaveSystem.profile_path = "user://test_android_profile.json"
	var saved_ctl: RunController = GameState.controller
	var ctl: RunController = RunController.new(DataRegistry.db)
	ctl.new_run("lea", 0, 4321)
	GameState.controller = ctl
	var life: AppLifecycle = AppLifecycle.new()
	life._to_background()
	check(SaveSystem.has_run(), "partie sauvegardée en arrière-plan")
	var back: RunState = SaveSystem.load_run()
	check(back != null and back.rng.seed_value == ctl.run.rng.seed_value, "même partie au redémarrage")
	check(AudioServer.is_bus_mute(AppLifecycle.MASTER_BUS), "son coupé")
	life._to_foreground()
	check(not AudioServer.is_bus_mute(AppLifecycle.MASTER_BUS), "son rendu au retour")
	life.free()
	SaveSystem.clear_run()
	DirAccess.remove_absolute(SaveSystem.profile_path)
	SaveSystem.run_path = saved_path
	SaveSystem.profile_path = saved_profile
	GameState.controller = saved_ctl
