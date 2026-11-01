class_name DecoBackground
extends Control
## Fond art déco animé : rayons dorés en éventail, velours, poussière en suspension,
## néon qui clignote. Purement cosmétique.

const RAY_COUNT: int = 28
const RAY_SPEED: float = 0.02
const DUST_COUNT: int = 60
const DUST_SPEED: float = 14.0
const NEON_FLICKER_CHANCE: float = 0.012
const SHADOW_COUNT: int = 3
const SHADOW_SPEED: float = 22.0
const SHADOW_ALPHA: float = 0.18

var origin_ratio: Vector2 = Vector2(0.5, 1.1)
var _t: float = 0.0
var _dust: Array[Vector3] = []
var _neon: float = 1.0
var _tint: Color = Color(1, 1, 1, 0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng: RandomNumberGenerator = RngService.cosmetic()
	for i: int in DUST_COUNT:
		_dust.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.5, 2.5)))


func set_tint(c: Color) -> void:
	var tw: Tween = create_tween()
	tw.tween_method(func(v: Color) -> void: _tint = v, _tint, c, 1.2)


func _process(delta: float) -> void:
	_t += delta * JuiceProfile.intensity()
	var rng: RandomNumberGenerator = RngService.cosmetic()
	if rng.randf() < NEON_FLICKER_CHANCE * JuiceProfile.intensity():
		_neon = rng.randf_range(0.3, 0.7)
	else:
		_neon = lerpf(_neon, 1.0, delta * 8.0)
	queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	draw_rect(Rect2(Vector2.ZERO, s), Palette.INK)
	var o: Vector2 = Vector2(s.x * origin_ratio.x, s.y * origin_ratio.y)
	var radius: float = s.length() * 1.2
	for i: int in RAY_COUNT:
		var a0: float = PI + (float(i) / float(RAY_COUNT)) * PI + sin(_t * RAY_SPEED * TAU) * 0.05
		var a1: float = a0 + PI / float(RAY_COUNT) * 0.5
		var col: Color = Palette.VELVET_DEEP if i % 2 == 0 else Palette.VELVET.darkened(0.55)
		draw_colored_polygon(PackedVector2Array([o, o + Vector2.from_angle(a0) * radius, o + Vector2.from_angle(a1) * radius]), col)
	for k: int in 3:
		var r: float = s.y * (0.35 + 0.18 * float(k))
		draw_arc(o, r, PI, TAU, 96, Palette.GOLD_DARK.darkened(0.3 + 0.15 * float(k)), 3.0, true)
	var neon_col: Color = Palette.MAGENTA
	neon_col.a = 0.6 * _neon
	draw_arc(o, s.y * 0.3, PI, TAU, 96, neon_col, 6.0, true)
	# Ombres mouvantes (silhouettes de joueurs qui passent devant les lampes)
	for k: int in SHADOW_COUNT:
		var sx: float = fposmod(_t * SHADOW_SPEED * (1.0 + 0.3 * float(k)) + float(k) * s.x / float(SHADOW_COUNT), s.x * 1.4) - s.x * 0.2
		var sc: Color = Palette.INK
		sc.a = SHADOW_ALPHA
		draw_circle(Vector2(sx, s.y * (0.35 + 0.2 * float(k % 2))), s.y * 0.35, sc)
	if _tint.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), _tint)
	for d: Vector3 in _dust:
		var p: Vector2 = Vector2(fposmod(d.x * s.x + _t * DUST_SPEED * d.z, s.x), fposmod(d.y * s.y - _t * DUST_SPEED * 0.5 * d.z, s.y))
		var c: Color = Palette.GOLD_LIGHT
		c.a = 0.08 + 0.05 * d.z
		draw_circle(p, d.z, c)
