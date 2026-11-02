class_name PocketCard
extends RefCounted
## Fiche illustrée d'une case de la roue (infobulle souris, sélection à la manette, Codex) :
## pastille du numéro à sa couleur, type et icône, pastilles de statistiques colorées
## (jetons en bleu, Mult en rouge, ×Mult, argent en or, niveau), édition, sceau et chance.

const STAT_DIR: String = "res://assets/stat_icons/"
const WIDTH: float = 420.0
const BADGE: float = 46.0
const ICON: float = 40.0
const STAT_ICON: float = 24.0
const PROB_BAR: Vector2 = Vector2(200, 12)
## Une case seule dépasse rarement 10 % : la barre est pleine à 10 %.
const PROB_FULL: float = 0.1
## Opérations d'effet montrées en pastilles : [icône, couleur, format].
const STAT_OPS: Dictionary[String, Array] = {
	"add_chips": ["chips", Color("3d8bff"), "+%s"],
	"add_mult": ["mult", Color("ff3b5c"), "+%s"],
	"mul_mult": ["xmult", Color("ff3b5c"), "×%s"],
	"add_money": ["money", Color("d4af37"), "+%s $"],
	"steal_chips": ["chips", Color("3d8bff"), "+%s"],
	"retrigger_pocket": ["level", Color("f2d27a"), "↻ %s"],
	"destroy_pocket": ["curse", Color("b03aff"), "✸"],
	"chance_destroy_pocket": ["curse", Color("b03aff"), "✸ %s %%"],
}


static func stat_icon(id: String) -> Texture2D:
	var path: String = STAT_DIR + id + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Panneau complet ; `probability` < 0 : chance non affichée.
static func build(p: Pocket, db: ContentDB, probability: float = -1.0) -> PanelContainer:
	var loc: String = Localization.locale()
	var tdef: Dictionary = db.get_entry("pocket_types", String(p.type_id))
	var tcol: Color = Color(String(tdef.get("color", ""))) if tdef.has("color") else PocketInfo.type_color(p.type_id)
	if p.type_id == Pocket.TYPE_STANDARD:
		tcol = Palette.GOLD_LIGHT
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.flat(Palette.INK, tcol, 2, 6, 12))
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	# En-tête : pastille du numéro, icône et nom du type.
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	head.add_child(_number_badge(p))
	var tex: Texture2D = IconLibrary.icon(String(tdef.get("icon", "")))
	if tex != null and p.type_id != Pocket.TYPE_STANDARD:
		head.add_child(tex_rect(tex, ICON))
	var names: VBoxContainer = VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(UiKit.label(ContentDB.text(tdef, "name", loc), UiKit.SIZE_BODY, tcol, "display"))
	names.add_child(UiKit.label(TranslationServer.translate("COLOR_" + String(p.color()).to_upper()), UiKit.SIZE_SMALL, Palette.SMOKE))
	# Pastilles : jetons du numéro et du niveau, puis effets chiffrés du type.
	var stats: HFlowContainer = HFlowContainer.new()
	stats.add_theme_constant_override("h_separation", 8)
	stats.add_theme_constant_override("v_separation", 6)
	box.add_child(stats)
	var base_chips: int = p.number * Balance.i("score.pocket_number_chips")
	if base_chips > 0:
		stats.add_child(pill("chips", Color("3d8bff"), "+%d" % base_chips, "STAT_BASE_CHIPS"))
	if p.level > 0:
		stats.add_child(pill("level", Palette.GOLD_LIGHT, "+%d" % (p.level * Balance.i("score.pocket_level_chips")), "STAT_LEVEL", p.level))
	for eff: Variant in tdef.get("effects", []):
		for act: Variant in (eff as Dictionary).get("do", []):
			var a: Dictionary = act as Dictionary
			var op: String = String(a.get("op", ""))
			if not STAT_OPS.has(op):
				continue
			var spec: Array = STAT_OPS[op]
			var v: Variant = a.get("v", "")
			var txt: String = String(spec[2])
			if txt.contains("%s"):
				var shown: Variant = float(v) * 100.0 if op == "chance_destroy_pocket" and (v is float or v is int) else v
				txt = txt % (num(shown) if (shown is float or shown is int) else "?")
			stats.add_child(pill(String(spec[0]), spec[1] as Color, txt, ""))
	var desc: Label = UiKit.label(ContentDB.text(tdef, "desc", loc), UiKit.SIZE_SMALL, Palette.IVORY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(WIDTH - 30, 0)
	box.add_child(desc)
	if p.edition != &"":
		var e: Dictionary = db.get_entry("editions", String(p.edition))
		var ecol: Color = PocketInfo.edition_color(p.edition).lightened(0.2)
		box.add_child(_extra("edition", ecol, ContentDB.text(e, "name", loc), ContentDB.text(e, "desc", loc)))
	if p.seal != &"":
		var sd: Dictionary = db.get_entry("seals", String(p.seal))
		var scol: Color = PocketInfo.seal_color(p.seal).lightened(0.15)
		box.add_child(_extra("seal", scol, ContentDB.text(sd, "name", loc), ContentDB.text(sd, "desc", loc)))
	if probability >= 0.0:
		box.add_child(chance_row(probability, PROB_FULL))
	return panel


static func num(v: Variant) -> String:
	var f: float = float(v)
	return str(int(f)) if is_equal_approx(f, roundf(f)) else ("%.1f" % f).replace(".", "," if Localization.locale() == "fr" else ".")


static func tex_rect(t: Texture2D, sz: float) -> TextureRect:
	var r: TextureRect = TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.custom_minimum_size = Vector2(sz, sz)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func _number_badge(p: Pocket) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(BADGE, BADGE)
	var col: Color = Palette.pocket_color(p.color())
	c.draw.connect(
		func() -> void:
			c.draw_circle(Vector2(BADGE, BADGE) * 0.5, BADGE * 0.5, Palette.GOLD)
			c.draw_circle(Vector2(BADGE, BADGE) * 0.5, BADGE * 0.5 - 3.0, col)
			var f: Font = UiKit.font("mono")
			var fs: int = UiKit.fs(UiKit.SIZE_BODY)
			var t: String = str(p.number)
			var w: Vector2 = f.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
			c.draw_string(f, Vector2((BADGE - w.x) * 0.5, BADGE * 0.5 + w.y * 0.3), t, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Palette.IVORY)
	)
	return c


## Pastille : icône + valeur colorée (+ libellé discret).
static func pill(icon_id: String, col: Color, value: String, label_key: String, arg: int = -1) -> Control:
	var pc: PanelContainer = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.flat(Color(col, 0.16), Color(col, 0.7), 1, 4, 4))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	pc.add_child(h)
	var t: Texture2D = stat_icon(icon_id)
	if t != null:
		h.add_child(tex_rect(t, STAT_ICON))
	h.add_child(UiKit.label(value, UiKit.SIZE_BODY - 2, col.lightened(0.25), "mono"))
	if label_key != "":
		var txt: String = TranslationServer.translate(label_key)
		if arg >= 0:
			txt = txt % arg
		h.add_child(UiKit.label(txt, UiKit.SIZE_SMALL, Palette.SMOKE))
	return pc


static func _extra(icon_id: String, col: Color, title: String, desc: String) -> Control:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var t: Texture2D = stat_icon(icon_id)
	if t != null:
		h.add_child(tex_rect(t, STAT_ICON))
	var l: RichTextLabel = UiKit.rich("[color=#%s]%s[/color] — %s" % [col.to_html(false), title, desc], UiKit.SIZE_SMALL)
	l.custom_minimum_size = Vector2(WIDTH - 70, 0)
	h.add_child(l)
	return h


## Ligne de chance : icône, barre (pleine à `full`), pourcentage.
static func chance_row(p: float, full: float, label_key: String = "POCKET_PROBABILITY") -> Control:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var t: Texture2D = stat_icon("chance")
	if t != null:
		h.add_child(tex_rect(t, STAT_ICON))
	var bar: Control = Control.new()
	bar.custom_minimum_size = PROB_BAR
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.draw.connect(
		func() -> void:
			bar.draw_rect(Rect2(Vector2.ZERO, PROB_BAR), Palette.SMOKE_DARK)
			bar.draw_rect(Rect2(Vector2.ZERO, Vector2(PROB_BAR.x * clampf(p / full, 0.0, 1.0), PROB_BAR.y)), Palette.EMERALD)
			bar.draw_rect(Rect2(Vector2.ZERO, PROB_BAR), Palette.GOLD_DARK, false, 1.0)
	)
	h.add_child(bar)
	h.add_child(UiKit.label(TranslationServer.translate(label_key) % (p * 100.0), UiKit.SIZE_SMALL, Palette.EMERALD))
	return h
