class_name FamilyChip
extends Control
## Pastille d'une famille : emblème, compte / prochain seuil, points des paliers atteints.

const SIZE: Vector2 = Vector2(74, 30)

var fid: String = ""
var count: int = 0
var _pulse: float = 0.0


func setup(p_fid: String, p_count: int) -> void:
	fid = p_fid
	count = p_count
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = " "


func bump() -> void:
	_pulse = 1.0
	set_process(true)


func _process(delta: float) -> void:
	_pulse = maxf(_pulse - delta * 2.5, 0.0)
	queue_redraw()
	if _pulse <= 0.0:
		set_process(false)


func _make_custom_tooltip(_for_text: String) -> Object:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.flat(Color(Palette.INK, 0.94), FamilyUi.color(fid), 2, 6, 12))
	panel.add_child(FamilyUi.info_block(fid, CardTooltip.WIDTH, false))
	return panel


func _draw() -> void:
	var d: Dictionary = FamilyUi.def(fid)
	var col: Color = FamilyUi.color(fid)
	var active: bool = Families.tier_index(d, count) >= 0
	var r: Rect2 = Rect2(Vector2.ZERO, SIZE)
	draw_rect(r, Color(Palette.INK, 0.85))
	draw_rect(r, Color(col, 1.0 if active else 0.45), false, 2.0 if active else 1.0)
	if active:
		draw_rect(r.grow(-2.0), Color(col, 0.12 + 0.25 * _pulse))
	FamilyUi.draw_badge(self, Vector2(15, 15), 12.0, fid, _pulse)
	var nxt: int = Families.next_threshold(d, count)
	var t: String = "%d/%d" % [count, nxt] if nxt > 0 else "%d ★" % count
	var tc: Color = Palette.IVORY if active else Palette.SMOKE
	draw_string(UiKit.font("mono"), Vector2(31, 21), t, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.fs(16), tc)
