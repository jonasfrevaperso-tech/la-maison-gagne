class_name DebtGauge
extends Control
## Jauge « score de l'échéance / dette ». Bat comme un cœur au dernier tour.

const HEIGHT: float = 46.0
const HEARTBEAT_HZ: float = 1.6
const FILL_TIME: float = 0.6

var score: float = 0.0
var debt: float = 1.0
var last_spin: bool = false
var _shown: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(520, HEIGHT)


func set_progress(p_score: int, p_debt: int, p_last_spin: bool) -> void:
	score = float(p_score)
	debt = float(maxi(p_debt, 1))
	last_spin = p_last_spin
	var tw: Tween = create_tween()
	tw.tween_property(self, "_shown", score, FILL_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	var beat: float = 0.0
	if last_spin and _shown < debt:
		beat = maxf(sin(Time.get_ticks_msec() * 0.001 * TAU * HEARTBEAT_HZ), 0.0) * JuiceProfile.intensity()
	var grow: Vector2 = Vector2(beat * 6.0, beat * 4.0)
	r = r.grow_individual(grow.x, grow.y, grow.x, grow.y)
	draw_rect(r, Palette.INK)
	var ratio: float = clampf(_shown / debt, 0.0, 1.0)
	var fill: Rect2 = Rect2(r.position, Vector2(r.size.x * ratio, r.size.y))
	var col: Color = Palette.EMERALD if ratio >= 1.0 else Palette.GOLD.lerp(Palette.DANGER, beat * 0.6)
	draw_rect(fill, col)
	draw_rect(r, Palette.GOLD, false, 2.0)
	var f: Font = UiKit.font("mono")
	var fs: int = int(size.y * 0.5)
	var t: String = "%s / %s" % [Localization.format_number(_shown), Localization.format_number(debt)]
	var sz: Vector2 = f.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string_outline(f, r.get_center() + Vector2(-sz.x * 0.5, sz.y * 0.3), t, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, 6, Palette.INK)
	draw_string(f, r.get_center() + Vector2(-sz.x * 0.5, sz.y * 0.3), t, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Palette.IVORY)
