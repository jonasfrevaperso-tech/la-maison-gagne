class_name LoadingScreen
extends Control
## Carton de chargement art déco, posé par Main au-dessus des rideaux fermés pour les écrans
## lourds (partie, bilan) : roulette qui tourne, astuce du tutoriel, barre de progression.
## Ce qui gèle (chargement, compilation des pipelines graphiques, cf. Warmup) se passe derrière.

const FADE: float = 0.18
const WHEEL_R: float = 70.0
const WHEEL_SPEED: float = 2.4
const POCKETS: int = 37
const BAR_SIZE: Vector2 = Vector2(640, 10)
const TIP_W: float = 1100.0

var _progress: float = 0.0
var _shown: float = 0.0
var _angle: float = 0.0
var _title: Label = null
var _tip: RichTextLabel = null
var _box: VBoxContainer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiKit.theme()
	visible = false
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 20)
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, WHEEL_R * 2.0 + 40.0)
	_box.add_child(spacer)
	_title = UiKit.title(tr("LOADING_TITLE"), UiKit.SIZE_H1)
	_box.add_child(_title)
	var bar_gap: Control = Control.new()
	bar_gap.custom_minimum_size = Vector2(0, BAR_SIZE.y + 30.0)
	_box.add_child(bar_gap)
	_tip = UiKit.rich("", UiKit.SIZE_BODY)
	_tip.fit_content = true
	_tip.custom_minimum_size = Vector2(TIP_W, 0)
	_tip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_tip)


## Affiche le carton (fondu court) avec une astuce tirée du tutoriel.
func show_card() -> void:
	_progress = 0.0
	_shown = 0.0
	_tip.text = "[center][color=#%s]%s[/color]  %s[/center]" % [
		Palette.GOLD.to_html(false), tr("LOADING_TIP"), _random_tip()
	]
	visible = true
	modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, FADE)
	await tw.finished


func hide_card() -> void:
	_progress = 1.0
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, FADE)
	await tw.finished
	visible = false


func set_progress(p: float) -> void:
	_progress = clampf(maxf(p, _progress), 0.0, 1.0)


func _random_tip() -> String:
	var tips: Array[Dictionary] = DataRegistry.db.list("tutorial")
	if tips.is_empty():
		return ""
	var e: Dictionary = tips[RngService.cosmetic().randi_range(0, tips.size() - 1)]
	return TutorialDirector.tip_text(e)


func _process(delta: float) -> void:
	if not visible:
		return
	_angle = fmod(_angle + delta * WHEEL_SPEED, TAU)
	_shown = lerpf(_shown, _progress, minf(1.0, delta * 8.0))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.INK)
	var c: Vector2 = Vector2(size.x * 0.5, _title.global_position.y - global_position.y - WHEEL_R - 30.0)
	# Rayons art déco derrière la roulette.
	for i: int in 16:
		var a: float = TAU * float(i) / 16.0 + _angle * 0.1
		draw_line(c, c + Vector2.from_angle(a) * WHEEL_R * 2.2, Color(Palette.GOLD_DARK, 0.35), 2.0)
	draw_circle(c, WHEEL_R + 8.0, Palette.GOLD_DARK)
	for k: int in POCKETS:
		var a0: float = _angle + TAU * float(k) / float(POCKETS)
		var a1: float = a0 + TAU / float(POCKETS)
		var col: Color = Palette.EMERALD if k == 0 else (Palette.MULT_RED if k % 2 == 1 else Palette.SMOKE.darkened(0.6))
		var pts: PackedVector2Array = [c, c + Vector2.from_angle(a0) * WHEEL_R, c + Vector2.from_angle(a1) * WHEEL_R]
		draw_colored_polygon(pts, col)
	draw_circle(c, WHEEL_R * 0.55, Palette.VELVET_DEEP)
	draw_circle(c, WHEEL_R * 0.2, Palette.GOLD)
	draw_circle(c + Vector2.from_angle(-_angle * 1.7) * WHEEL_R * 0.8, 6.0, Palette.IVORY)
	# Barre de progression sous le titre.
	var bar: Rect2 = Rect2(
		Vector2(size.x * 0.5 - BAR_SIZE.x * 0.5, _title.global_position.y - global_position.y + _title.size.y + 24.0), BAR_SIZE
	)
	draw_rect(bar.grow(3.0), Palette.GOLD_DARK, false, 2.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _shown, bar.size.y)), Palette.GOLD_LIGHT)
