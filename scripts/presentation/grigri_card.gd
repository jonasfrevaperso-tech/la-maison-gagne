class_name GrigriCard
extends Control
## Carte de grigri / Fortune / contrat : cadre de rareté, icône (ou glyphe de repli),
## inclinaison 3D légère sous la souris, rebond au déclenchement, brillance d'édition.
## Glisser-déposer pour réordonner ; clic droit = verrouiller ; double-clic = action.

signal activated(card: GrigriCard)
signal lock_toggled(card: GrigriCard)
signal reorder_requested(from_uid: int, to_uid: int)

const CARD_SIZE: Vector2 = Vector2(112, 144)
const ICON_SIZE: float = 80.0
const TILT_MAX: float = 0.12
const HOVER_LIFT: float = 10.0

var kind: String = "grigri"  # grigri | fortune | contract | pocket_card
var entry_id: String = ""
var uid: int = 0
var edition: StringName = &""
var counter: float = 0.0
var locked: bool = false
var disabled_look: bool = false
var price: int = -1
var show_counter: bool = false
var draggable: bool = true

var _hover: bool = false
var _tilt: Vector2 = Vector2.ZERO
var _lift: float = 0.0


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	tooltip_text = " "


func _on_enter() -> void:
	_hover = true
	AudioBus.ui("card_hover")


func _on_exit() -> void:
	_hover = false


func configure(p_kind: String, p_id: String, p_uid: int = 0) -> GrigriCard:
	kind = p_kind
	entry_id = p_id
	uid = p_uid
	return self


func category() -> String:
	match kind:
		"fortune":
			return "fortunes"
		"contract":
			return "contracts"
		"pocket_card":
			return "pocket_types"
	return "grigris"


func entry() -> Dictionary:
	return DataRegistry.db.get_entry(category(), entry_id)


func rarity() -> String:
	return String(entry().get("rarity", "common" if kind == "grigri" else "rare"))


func bump() -> void:
	var s: float = 1.0 + 0.22 * JuiceProfile.intensity()
	var tw: Tween = create_tween()
	tw.tween_property(self, "scale", Vector2(s, s), 0.07)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "rotation", 0.0, 0.18).from(0.08 * JuiceProfile.intensity())


func _process(delta: float) -> void:
	var target_tilt: Vector2 = Vector2.ZERO
	if _hover and JuiceProfile.intensity() > 0.0:
		var m: Vector2 = get_local_mouse_position() / CARD_SIZE - Vector2(0.5, 0.5)
		target_tilt = m * TILT_MAX * 2.0 * JuiceProfile.intensity()
	_tilt = _tilt.lerp(target_tilt, delta * 12.0)
	_lift = lerpf(_lift, HOVER_LIFT if _hover else 0.0, delta * 12.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT and kind == "grigri":
			lock_toggled.emit(self)
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and (mb.double_click or kind != "grigri"):
			activated.emit(self)
			accept_event()
	elif event.is_action_pressed("ui_accept"):
		activated.emit(self)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not draggable or kind != "grigri":
		return null
	var preview: GrigriCard = GrigriCard.new().configure(kind, entry_id, uid)
	preview.edition = edition
	preview.modulate.a = 0.8
	set_drag_preview(preview)
	return {"grigri_uid": uid}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (
		kind == "grigri"
		and data is Dictionary
		and (data as Dictionary).has("grigri_uid")
		and int((data as Dictionary)["grigri_uid"]) != uid
	)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	reorder_requested.emit(int((data as Dictionary)["grigri_uid"]), uid)


func _make_custom_tooltip(_for_text: String) -> Object:
	return CardTooltip.build(kind, entry_id, edition, counter, price)


func _draw() -> void:
	var e: Dictionary = entry()
	var rcol: Color = Palette.rarity_color(rarity())
	var off: Vector2 = Vector2(_tilt.x * 18.0, -_lift + _tilt.y * 10.0)
	var skew: float = _tilt.x * 14.0
	var r: Rect2 = Rect2(Vector2(4, 4) + off, CARD_SIZE - Vector2(8, 8))
	# Ombre
	draw_rect(Rect2(r.position + Vector2(5, 7 + _lift * 0.5), r.size), Color(0, 0, 0, 0.5))
	# Corps (légère déformation pseudo-3D par trapèze)
	var tl: Vector2 = r.position + Vector2(skew, 0)
	var top_right: Vector2 = Vector2(r.end.x + skew * 0.3, r.position.y)
	var br: Vector2 = r.end - Vector2(skew * 0.3, 0)
	var bl: Vector2 = Vector2(r.position.x - skew, r.end.y)
	var body: Color = Palette.VELVET_DEEP if not disabled_look else Palette.SMOKE_DARK
	draw_colored_polygon(PackedVector2Array([tl, top_right, br, bl]), body)
	draw_polyline(PackedVector2Array([tl, top_right, br, bl, tl]), rcol, 3.0, true)
	draw_polyline(
		PackedVector2Array([tl + Vector2(5, 5), top_right + Vector2(-5, 5), br + Vector2(-5, -5), bl + Vector2(5, -5), tl + Vector2(5, 5)]),
		Palette.GOLD_DARK,
		1.0,
		true
	)
	# Icône
	var icon_rect: Rect2 = Rect2(r.position + Vector2((r.size.x - ICON_SIZE) * 0.5, 10), Vector2(ICON_SIZE, ICON_SIZE))
	var tex: Texture2D = IconLibrary.icon(String(e.get("icon", entry_id)))
	if tex != null:
		draw_texture_rect(tex, icon_rect, false)
	else:
		_draw_glyph(icon_rect, e, rcol)
	# Édition
	if edition != &"":
		var ec: Color = PocketInfo.edition_color(edition)
		var t: float = Time.get_ticks_msec() * 0.002
		ec.a = 0.18 + 0.12 * sin(t * 3.0)
		if edition == &"polychrome":
			ec = Color.from_hsv(fposmod(t * 0.3, 1.0), 0.7, 1.0, 0.25)
		draw_rect(Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 8)), ec)
		var sweep: float = fposmod(t * 0.6, 1.6) - 0.3
		var sx: float = r.position.x + r.size.x * sweep
		var shine: Color = Color(1, 1, 1, 0.18)
		draw_line(Vector2(sx, r.position.y + 4), Vector2(sx - 30, r.end.y - 4), shine, 8.0)
	# Nom
	var f: Font = UiKit.font("ui")
	var fs: int = 14
	var name_txt: String = Localization.t(e, "name")
	var lines: PackedStringArray = _wrap(name_txt, f, fs, r.size.x - 10)
	var y: float = icon_rect.end.y + 14.0
	for ln: String in lines:
		var w: float = f.get_string_size(ln, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(f, Vector2(r.get_center().x - w * 0.5, y), ln, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Palette.IVORY)
		y += float(fs) + 2.0
	if show_counter and absf(counter) > 0.001:
		var ct: String = ("×%.2f" % counter) if counter < 10.0 and not is_equal_approx(counter, round(counter)) else str(int(counter))
		draw_string(UiKit.font("mono"), r.position + Vector2(6, 22), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.EMERALD)
	if locked:
		draw_string(
			UiKit.font("mono"), Vector2(r.end.x - 22, r.position.y + 22), "🔒", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.GOLD_LIGHT
		)
		draw_rect(r, Palette.GOLD_LIGHT, false, 2.0)
	if price >= 0:
		var pt: String = "%d $" % price
		var pw: float = UiKit.font("mono").get_string_size(pt, HORIZONTAL_ALIGNMENT_CENTER, -1, 20).x
		draw_rect(Rect2(Vector2(r.get_center().x - pw * 0.5 - 8, r.end.y - 8), Vector2(pw + 16, 26)), Palette.INK)
		draw_string(
			UiKit.font("mono"),
			Vector2(r.get_center().x - pw * 0.5, r.end.y + 12),
			pt,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			20,
			Palette.GOLD_LIGHT
		)
	if disabled_look:
		draw_line(r.position, r.end, Palette.DANGER, 3.0)


func _draw_glyph(rect: Rect2, e: Dictionary, rcol: Color) -> void:
	draw_rect(rect, Palette.INK)
	draw_rect(rect, rcol.darkened(0.3), false, 2.0)
	var tags: Array = e.get("tags", [])
	var tag: String = String(tags[0]) if not tags.is_empty() else kind
	var glyph: String = CardTooltip.TAG_GLYPHS.get(tag, "✦")
	var f: Font = UiKit.font("ui")
	var fs: int = 44
	var sz: Vector2 = f.get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string(f, rect.get_center() + Vector2(-sz.x * 0.5, sz.y * 0.3), glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, rcol)


static func _wrap(t: String, f: Font, fs: int, max_w: float) -> PackedStringArray:
	var out: PackedStringArray = []
	var cur: String = ""
	for word: String in t.split(" "):
		var test: String = word if cur == "" else cur + " " + word
		if f.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = test
	if cur != "":
		out.append(cur)
	return out
