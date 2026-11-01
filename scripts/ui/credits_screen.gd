class_name CreditsScreen
extends Control
## Crédits défilants (contenu tiré de docs/CREDITS.md résumé) + mention jeu de hasard simulé.

const SCROLL_SPEED: float = 40.0

var _box: VBoxContainer = null


func setup(_params: Dictionary) -> void:
	pass


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(DecoBackground.new())
	_box = VBoxContainer.new()
	_box.position = Vector2(460, 1080)
	_box.custom_minimum_size = Vector2(1000, 0)
	_box.add_theme_constant_override("separation", 18)
	add_child(_box)
	_box.add_child(UiKit.title(tr("GAME_TITLE"), UiKit.SIZE_TITLE))
	for key: String in ["CREDITS_1", "CREDITS_2", "CREDITS_3", "CREDITS_4", "CREDITS_5", "CREDITS_6", "DISCLAIMER_SIMULATED"]:
		var l: Label = UiKit.label(tr(key), UiKit.SIZE_H2 if key != "DISCLAIMER_SIMULATED" else UiKit.SIZE_BODY)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(1000, 0)
		_box.add_child(l)
	var back: Button = UiKit.button(tr("MENU_BACK"), GameState.goto.bind(GameState.SCREEN_TITLE))
	back.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	back.position = Vector2(-320, -100)
	add_child(back)
	back.call_deferred("grab_focus")
	AudioBus.play_music("menu")


func _process(delta: float) -> void:
	_box.position.y -= SCROLL_SPEED * delta
	if _box.position.y < -_box.size.y:
		_box.position.y = 1080.0


func go_back() -> void:
	GameState.goto(GameState.SCREEN_TITLE)
