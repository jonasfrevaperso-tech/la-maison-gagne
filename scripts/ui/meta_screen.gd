class_name MetaScreen
extends Control
## Base des écrans méta : fond, titre, zone défilante, bouton retour.

var content: VBoxContainer = null


func setup(_params: Dictionary) -> void:
	pass


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(DecoBackground.new())
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 80
	v.offset_right = -80
	v.offset_top = 30
	v.offset_bottom = -30
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	v.add_child(UiKit.title(screen_title(), UiKit.SIZE_H1))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	var back: Button = UiKit.button(tr("MENU_BACK"), GameState.goto.bind(GameState.SCREEN_TITLE))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	build()
	back.call_deferred("grab_focus")
	AudioBus.play_music("menu")


func screen_title() -> String:
	return ""


func build() -> void:
	pass


func section(text: String) -> void:
	content.add_child(UiKit.label(text, UiKit.SIZE_H2, Palette.GOLD, "display"))


func grid(columns: int) -> GridContainer:
	var g: GridContainer = GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	content.add_child(g)
	return g
