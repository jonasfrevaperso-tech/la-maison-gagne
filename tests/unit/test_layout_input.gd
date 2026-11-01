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
	eq(deck.size(), 1, "Steam Deck : seule la plus petite fenêtre tient")
	var qhd: Array[Vector2i] = UiLayout.window_sizes_for(Vector2i(2560, 1440))
	check(qhd.has(Vector2i(1920, 1080)) and not qhd.has(Vector2i(2560, 1440)), "1440p : jusqu'à 1080p fenêtré")
	eq(Settings.parse_size("2560x1440"), Vector2i(2560, 1440), "lecture d'une taille")
	eq(Settings.parse_size("n'importe"), UiLayout.DEFAULT_WINDOW, "taille illisible : défaut")


func test_hint_line_follows_device_and_bindings() -> void:
	var was_pad: bool = InputHints.using_pad
	InputHints.using_pad = false
	var kb: String = InputHints.line("BETTING")
	check(kb.contains(InputHints.key_name(KEY_SPACE)), "clavier : touche de lancer affichée")
	var pad_event: InputEventJoypadButton = InputEventJoypadButton.new()
	check(InputHints.note_event(pad_event), "bouton de manette : bascule")
	var pad: String = InputHints.line("BETTING")
	check(pad.contains("Menu") and pad.contains("LB/RB"), "manette : Menu et LB/RB")
	check(not InputHints.note_event(pad_event), "pas de bascule répétée")
	check(InputHints.line("AIMING", "phrase").begins_with("phrase"), "phrase d'état en tête")
	InputHints.using_pad = was_pad


func test_dev_session_isolated() -> void:
	check(not DevMode.active(), "les tests ne sont pas une session de dev")
	eq(DevMode.save_dir(), "user://", "sauvegarde normale hors session de dev")
