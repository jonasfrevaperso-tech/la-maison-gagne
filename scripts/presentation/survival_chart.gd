class_name SurvivalChart
extends Control
## Barres « taux de passage par palier » de l'écran Statistiques.

const BAR_GAP: float = 14.0
const LABEL_H: float = 30.0
const CHART_SIZE: Vector2 = Vector2(980, 260)

var rates: Array[float] = []
var font_size: int = UiKit.SIZE_SMALL


func _init(p_rates: Array[float] = []) -> void:
	rates = p_rates
	custom_minimum_size = CHART_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if rates.is_empty():
		return
	var font: Font = UiKit.font("mono")
	var n: int = rates.size()
	var bar_w: float = (size.x - BAR_GAP * float(n - 1)) / float(n)
	var h: float = size.y - LABEL_H * 2.0
	for i: int in n:
		var x: float = float(i) * (bar_w + BAR_GAP)
		var base: Rect2 = Rect2(x, LABEL_H, bar_w, h)
		draw_rect(base, Palette.SMOKE_DARK)
		var label: String = "—"
		if rates[i] >= 0.0:
			var fill: float = h * rates[i]
			var col: Color = Palette.EMERALD.lerp(Palette.DANGER, 1.0 - rates[i])
			draw_rect(Rect2(x, LABEL_H + h - fill, bar_w, fill), col)
			label = "%d %%" % roundi(rates[i] * 100.0)
		draw_string(font, Vector2(x, LABEL_H - 8.0), label, HORIZONTAL_ALIGNMENT_CENTER, bar_w, font_size, Palette.IVORY)
		draw_string(font, Vector2(x, size.y - 6.0), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, bar_w, font_size, Palette.GOLD_LIGHT)
