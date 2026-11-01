class_name UiKit
extends RefCounted
## Fabrique de widgets stylés (art déco noir & or) pour construire les écrans en code.

const FONT_DISPLAY_PATH: String = "res://assets/fonts/display.ttf"
const FONT_UI_PATH: String = "res://assets/fonts/ui.ttf"
const FONT_MONO_PATH: String = "res://assets/fonts/mono.ttf"
const SIZE_TITLE: int = 96
const SIZE_H1: int = 54
const SIZE_H2: int = 36
const SIZE_BODY: int = 24
const SIZE_SMALL: int = 18
const RADIUS: int = 6
const BORDER: int = 2
const PAD: int = 14
const BUTTON_MIN: Vector2 = Vector2(260, 56)
const WEIGHTS: Dictionary = {"ui": 600, "mono": 600}

static var _fonts: Dictionary[String, Font] = {}
static var _theme: Theme = null


static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var path: String = {"display": FONT_DISPLAY_PATH, "ui": FONT_UI_PATH, "mono": FONT_MONO_PATH}.get(kind, FONT_UI_PATH)
	var base: Font = null
	if ResourceLoader.exists(path):
		base = load(path) as Font
	var symbols: SystemFont = SystemFont.new()
	symbols.font_names = PackedStringArray(["Noto Sans Symbols 2", "Noto Sans Symbols", "DejaVu Sans", "Noto Sans"])
	var f: Font
	if base == null:
		var sf: SystemFont = SystemFont.new()
		var names: Dictionary = {"mono": ["DejaVu Sans Mono", "Liberation Mono"], "display": ["DejaVu Serif", "Noto Serif"]}
		sf.font_names = PackedStringArray(names.get(kind, ["DejaVu Sans", "Noto Sans"]))
		sf.fallbacks = [symbols]
		f = sf
	else:
		# Polices variables : on fixe une graisse lisible (les instances par défaut sont « Thin »).
		var fv: FontVariation = FontVariation.new()
		fv.base_font = base
		if kind != "display":
			fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): WEIGHTS.get(kind, 500)}
		fv.fallbacks = [symbols]
		f = fv
	_fonts[kind] = f
	return f


## Libère les caches statiques (sinon fuite signalée à la fermeture).
static func clear_cache() -> void:
	_fonts.clear()
	_theme = null


static func flat(bg: Color, border: Color, border_w: int = BORDER, radius: int = RADIUS, pad: int = PAD) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	sb.anti_aliasing = true
	return sb


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	t.default_font = font("ui")
	t.default_font_size = SIZE_BODY
	t.set_color("font_color", "Label", Palette.IVORY)
	t.set_color("font_color", "Button", Palette.IVORY)
	t.set_color("font_hover_color", "Button", Palette.GOLD_LIGHT)
	t.set_color("font_pressed_color", "Button", Palette.INK)
	t.set_color("font_disabled_color", "Button", Palette.SMOKE)
	t.set_color("font_focus_color", "Button", Palette.GOLD_LIGHT)
	t.set_stylebox("normal", "Button", flat(Palette.VELVET_DEEP, Palette.GOLD_DARK))
	t.set_stylebox("hover", "Button", flat(Palette.VELVET, Palette.GOLD))
	t.set_stylebox("pressed", "Button", flat(Palette.GOLD, Palette.GOLD_LIGHT))
	t.set_stylebox("disabled", "Button", flat(Palette.SMOKE_DARK, Palette.SMOKE))
	t.set_stylebox("focus", "Button", flat(Color(0, 0, 0, 0), Palette.CYAN, 3))
	t.set_stylebox("panel", "PanelContainer", flat(Palette.VELVET_DEEP, Palette.GOLD_DARK))
	t.set_stylebox("panel", "Panel", flat(Palette.VELVET_DEEP, Palette.GOLD_DARK))
	t.set_color("font_color", "LineEdit", Palette.IVORY)
	t.set_stylebox("normal", "LineEdit", flat(Palette.INK, Palette.GOLD_DARK))
	t.set_stylebox("focus", "LineEdit", flat(Palette.INK, Palette.CYAN))
	t.set_color("default_color", "RichTextLabel", Palette.IVORY)
	t.set_font("normal_font", "RichTextLabel", font("ui"))
	t.set_font("mono_font", "RichTextLabel", font("mono"))
	t.set_stylebox("panel", "TooltipPanel", flat(Palette.INK, Palette.GOLD, 2, 4, 10))
	t.set_color("font_color", "TooltipLabel", Palette.IVORY)
	t.set_stylebox("slider", "HSlider", flat(Palette.SMOKE_DARK, Palette.GOLD_DARK, 1, 3, 4))
	t.set_color("font_color", "CheckBox", Palette.IVORY)
	t.set_color("font_color", "OptionButton", Palette.IVORY)
	t.set_stylebox("normal", "OptionButton", flat(Palette.VELVET_DEEP, Palette.GOLD_DARK))
	t.set_stylebox("hover", "OptionButton", flat(Palette.VELVET, Palette.GOLD))
	t.set_stylebox("pressed", "OptionButton", flat(Palette.VELVET, Palette.GOLD))
	t.set_stylebox("panel", "PopupMenu", flat(Palette.INK, Palette.GOLD))
	t.set_stylebox("background", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("tab_selected", "TabContainer", flat(Palette.VELVET, Palette.GOLD))
	t.set_stylebox("tab_unselected", "TabContainer", flat(Palette.VELVET_DEEP, Palette.GOLD_DARK))
	t.set_stylebox("panel", "TabContainer", flat(Palette.VELVET_DEEP, Palette.GOLD_DARK))
	_theme = t
	return t


static func label(text: String, size: int = SIZE_BODY, color: Color = Palette.IVORY, kind: String = "ui") -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func title(text: String, size: int = SIZE_H1) -> Label:
	var l: Label = label(text, size, Palette.GOLD_LIGHT, "display")
	l.add_theme_color_override("font_outline_color", Palette.INK)
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func button(text: String, callback: Callable, min_size: Vector2 = BUTTON_MIN) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_override("font", font("display"))
	b.pressed.connect(callback)
	b.pressed.connect(AudioBus.ui.bind("click"))
	b.mouse_entered.connect(AudioBus.ui.bind("hover"))
	return b


static func panel(bg: Color = Palette.VELVET_DEEP, border: Color = Palette.GOLD_DARK) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(bg, border))
	return p


static func rich(bbcode: String, size: int = SIZE_BODY) -> RichTextLabel:
	var r: RichTextLabel = RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = bbcode
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("mono_font_size", size)
	return r


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


static func background(color: Color = Palette.INK) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = color
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func spacer(h: float) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
