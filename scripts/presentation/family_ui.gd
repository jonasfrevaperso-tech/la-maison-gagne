class_name FamilyUi
extends RefCounted
## Présentation des familles de grigris (builds) : couleur, emblème, bloc d'explication des
## paliers (infobulles, boutique, codex) et pastille dessinée sur les cartes.

static var _icons: Dictionary = {}


static func def(fid: String) -> Dictionary:
	return DataRegistry.db.get_entry("families", fid)


static func of_grigri(gid: String) -> String:
	return Families.family_of(DataRegistry.db, gid)


static func color(fid: String) -> Color:
	var d: Dictionary = def(fid)
	return Color(String(d.get("color", "d4af37")))


static func icon(fid: String) -> Texture2D:
	if not _icons.has(fid):
		var path: String = "res://assets/families/%s.png" % String(def(fid).get("icon", ""))
		_icons[fid] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _icons[fid] as Texture2D


## Nombre de grigris de la famille dans la partie en cours (0 hors partie).
static func owned(fid: String) -> int:
	if not GameState.has_active_run():
		return 0
	return int(Families.counts(GameState.run(), DataRegistry.db).get(fid, 0))


## Pastille ronde (fond encre, anneau couleur de famille, emblème) dessinée sur un CanvasItem.
static func draw_badge(ci: CanvasItem, center: Vector2, radius: float, fid: String, glow: float = 0.0) -> void:
	var col: Color = color(fid)
	if glow > 0.0:
		ci.draw_circle(center, radius + 6.0 * glow, Color(col, 0.35 * glow))
	ci.draw_circle(center, radius, Palette.INK)
	ci.draw_arc(center, radius, 0.0, TAU, 28, col, 2.5, true)
	var tex: Texture2D = icon(fid)
	if tex != null:
		var s: float = radius * 1.35
		ci.draw_texture_rect(tex, Rect2(center - Vector2(s, s) * 0.5, Vector2(s, s)), false)


## Bloc « famille » des infobulles : emblème, nom, compte, description et paliers (atteint,
## prochain, suivants). `adding` : l'objet n'est pas encore à toi (boutique, paquet) — on
## montre ce que l'achat changerait.
static func info_block(fid: String, width: float, adding: bool) -> Control:
	var d: Dictionary = def(fid)
	var col: Color = color(fid)
	var have: int = owned(fid)
	var with_it: int = have + (1 if adding else 0)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var ic: TextureRect = TextureRect.new()
	ic.texture = icon(fid)
	ic.custom_minimum_size = Vector2(28, 28)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.add_child(ic)
	var name_l: Label = UiKit.label(Localization.t(d, "name").to_upper(), UiKit.SIZE_SMALL, col, "display")
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	var cnt: String = "%d" % have
	if adding:
		cnt = "%d → %d" % [have, with_it]
	head.add_child(UiKit.label(cnt, UiKit.SIZE_SMALL, Palette.IVORY, "mono"))
	box.add_child(head)
	var desc: Label = UiKit.label(Localization.t(d, "desc"), UiKit.SIZE_SMALL, Palette.SMOKE)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(width, 0)
	box.add_child(desc)
	var reached: int = Families.tier_index(d, with_it)
	var tiers: Array = d.get("tiers", [])
	for k: int in tiers.size():
		var td: Dictionary = tiers[k]
		var n: int = int(td.get("n", 0))
		var line: RichTextLabel = RichTextLabel.new()
		line.bbcode_enabled = true
		line.fit_content = true
		line.scroll_active = false
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(width, 0)
		line.add_theme_font_override("normal_font", UiKit.font("ui"))
		line.add_theme_font_size_override("normal_font_size", UiKit.fs(UiKit.SIZE_SMALL))
		var mark: String = "●" if k <= reached else "○"
		var tcol: Color = col if k == reached else (Palette.IVORY if k > reached else Palette.SMOKE)
		var txt: String = "%s %d : %s" % [mark, n, CardTooltip._highlight(Localization.t(td, "desc"))]
		if k == reached:
			txt = "[b]%s[/b]" % txt
		line.text = "[color=#%s]%s[/color]" % [tcol.to_html(false), txt]
		box.add_child(line)
	return box


## Texte court d'un palier (« Le Plein 3 : … ») pour les annonces.
static func tier_text(fid: String, tier: int) -> String:
	var d: Dictionary = def(fid)
	var td: Dictionary = (d.get("tiers", []) as Array)[tier]
	return "%s %d : %s" % [Localization.t(d, "name"), int(td.get("n", 0)), Localization.t(td, "desc")]
