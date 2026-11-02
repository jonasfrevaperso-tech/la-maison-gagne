extends TestCase
## Multi-résolution (scène de référence), aide aux commandes, isolement des sessions de dev.


func test_stage_fits_common_resolutions() -> void:
	# Fenêtres logiques obtenues par l'étirement canvas_items + expand.
	eq(UiLayout.stage_scale(Vector2(1920, 1080)), 1.0, "16:9 : échelle 1")
	eq(UiLayout.stage_scale(Vector2(1920, 1200)), 1.0, "16:10 (Steam Deck) : échelle 1")
	eq(UiLayout.stage_scale(Vector2(2520, 1080)), 1.0, "21:9 : échelle 1")
	check(absf(UiLayout.stage_scale(Vector2(1600, 900)) - 1600.0 / 1920.0) < 0.001, "texte agrandi : réduite")
	var c: Control = Control.new()
	UiLayout.fit_stage(c, Vector2(1920, 1200))
	eq(c.position, Vector2(0, 60), "16:10 : centrée verticalement")
	UiLayout.fit_stage(c, Vector2(2520, 1080))
	eq(c.position, Vector2(300, 0), "21:9 : centrée horizontalement")
	c.free()


func test_window_sizes_filtered_by_screen() -> void:
	var deck: Array[Vector2i] = UiLayout.window_sizes_for(Vector2i(1280, 800))
	eq(deck, [Vector2i(1280, 720), Vector2i(1280, 800)] as Array[Vector2i], "Steam Deck : 720p et 800p")
	var qhd: Array[Vector2i] = UiLayout.window_sizes_for(Vector2i(2560, 1440))
	check(qhd.has(Vector2i(2560, 1440)) and qhd.has(Vector2i(1920, 1080)), "1440p proposé sur un écran 1440p")
	check(not qhd.has(Vector2i(3840, 2160)), "pas de 4K sur un écran 1440p")
	var render: Array[Vector2i] = UiLayout.render_sizes_for(Vector2i(3840, 2160))
	check(render.has(Vector2i(2560, 1440)) and not render.has(Vector2i(3840, 2160)), "rendu plein écran : définitions inférieures à la native")
	eq(UiLayout.aspect_label(Vector2i(3440, 1440)), "21:9", "format ultra-large")
	eq(UiLayout.aspect_label(Vector2i(1280, 800)), "16:10", "format Steam Deck")
	eq(Settings.parse_size("2560x1440"), Vector2i(2560, 1440), "lecture d'une taille")
	eq(Settings.parse_size("n'importe"), UiLayout.DEFAULT_WINDOW, "taille illisible : défaut")


func test_prompts_follow_device_and_mode() -> void:
	var was_pad: bool = InputGlyphs.using_pad
	var was_mode: String = InputGlyphs.mode()
	Settings.set_value("game", "input_mode", "auto")
	InputGlyphs.using_pad = false
	var kb: Array[String] = InputGlyphs.parts_for("ui_spin")
	eq(kb, ["#" + InputGlyphs.key_name(KEY_SPACE)] as Array[String], "clavier : touche Espace en relief")
	eq(InputGlyphs.parts_for("@click"), ["mouse_left"] as Array[String], "clavier : clic souris")
	var pad_event: InputEventJoypadButton = InputEventJoypadButton.new()
	check(InputGlyphs.note_event(pad_event), "mode auto : un bouton de manette bascule")
	eq(InputGlyphs.parts_for("ui_spin"), ["pad_rt"] as Array[String], "manette : RT pour lancer")
	eq(InputGlyphs.parts_for("ui_accept"), ["pad_a"] as Array[String], "manette : A valide les menus")
	eq(InputGlyphs.parts_for("ui_cancel"), ["pad_b"] as Array[String], "manette : B pour revenir")
	eq(InputGlyphs.parts_for("@click"), [] as Array[String], "manette : aucune invite souris")
	check(InputGlyphs.texture("pad_a") != null, "glyphe A présent")
	check(not InputGlyphs.note_event(pad_event), "pas de bascule répétée")
	Settings.set_value("game", "input_mode", "keyboard")
	InputGlyphs.apply_mode()
	check(not InputGlyphs.using_pad, "mode clavier forcé")
	check(not InputGlyphs.note_event(pad_event), "mode clavier : la manette ne bascule pas l'affichage")
	Settings.set_value("game", "input_mode", "gamepad")
	InputGlyphs.apply_mode()
	check(InputGlyphs.using_pad, "mode manette forcé")
	check(InputGlyphs.expand("{bet_place}").contains("pad_a.png"), "jeton {action} → glyphe inline")
	Settings.set_value("game", "input_mode", was_mode)
	InputGlyphs.using_pad = was_pad


func test_dev_session_isolated() -> void:
	check(DevMode.active(), "les tests sont une session de dev")
	eq(DevMode.save_dir(), DevMode.DEV_DIR, "les tests n'écrivent jamais dans la sauvegarde du joueur")
