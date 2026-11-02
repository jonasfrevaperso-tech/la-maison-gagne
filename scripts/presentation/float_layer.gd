class_name FloatLayer
extends Control
## Nombres flottants et particules légères (pièces, étincelles, confettis).
## Pool de particules simples dessinées en _draw (aucun nœud par particule).

const MAX_PARTICLES: int = 400
const GRAVITY: float = 900.0

var _particles: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Gerbe de jetons (ou de pièces) en 3D ; `at` en coordonnées de canevas.
func burst_3d(at: Vector2, amount: int, coins: bool = false) -> void:
	ChipBurst3D.spawn(self, get_global_transform().affine_inverse() * at, amount, coins)


## `at` est en coordonnées de canevas (cf. UiLayout.canvas_point) : converti en local, le
## calque pouvant être mis à l'échelle par le cadre des écrans.
func pop_text(text: String, at: Vector2, color: Color, size_px: int = UiKit.SIZE_H2) -> void:
	at = get_global_transform().affine_inverse() * at
	var l: Label = UiKit.label(text, size_px, color, "mono")
	l.add_theme_color_override("font_outline_color", Palette.INK)
	l.add_theme_constant_override("outline_size", 8)
	l.position = at - Vector2(40, 20)
	l.pivot_offset = Vector2(40, 20)
	l.scale = Vector2(0.6, 0.6)
	add_child(l)
	var rise: float = JuiceProfile.FLOAT_TEXT_RISE * maxf(JuiceProfile.intensity(), 0.3)
	var t: float = JuiceProfile.FLOAT_TEXT_TIME / maxf(Settings.speed(), 1.0)
	var tw: Tween = l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE * (1.0 + 0.3 * JuiceProfile.intensity()), t * 0.2).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tw.tween_property(l, "position:y", l.position.y - rise, t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, t * 0.4).set_delay(t * 0.6)
	tw.chain().tween_callback(l.queue_free)


## kind : "coins", "sparks", "confetti", "smoke"
func burst(kind: String, at: Vector2, amount: int) -> void:
	at = get_global_transform().affine_inverse() * at
	var n: int = int(float(mini(amount, JuiceProfile.PARTICLE_COUNT_MAX)) * JuiceProfile.intensity())
	var rng: RandomNumberGenerator = RngService.cosmetic()
	for _i: int in n:
		if _particles.size() >= MAX_PARTICLES:
			_particles.pop_front()
		var ang: float = rng.randf_range(-PI, 0.0) if kind != "smoke" else rng.randf_range(-PI * 0.7, -PI * 0.3)
		var spd: float = rng.randf_range(180.0, 620.0) if kind != "smoke" else rng.randf_range(30.0, 90.0)
		var col: Color = Palette.GOLD_LIGHT
		match kind:
			"sparks":
				col = [Palette.CYAN, Palette.IVORY, Palette.GOLD_LIGHT][rng.randi_range(0, 2)]
			"confetti":
				col = [Palette.MAGENTA, Palette.CYAN, Palette.EMERALD, Palette.GOLD_LIGHT][rng.randi_range(0, 3)]
			"smoke":
				col = Palette.SMOKE
				col.a = 0.4
		(
			_particles
			. append(
				{
					"p": at,
					"v": Vector2.from_angle(ang) * spd,
					"life": rng.randf_range(0.6, 1.3),
					"age": 0.0,
					"c": col,
					"s": rng.randf_range(3.0, 8.0) if kind != "smoke" else rng.randf_range(14.0, 30.0),
					"k": kind,
					"rot": rng.randf() * TAU,
				}
			)
		)


func _process(delta: float) -> void:
	if _particles.is_empty():
		return
	var alive: Array[Dictionary] = []
	for p: Dictionary in _particles:
		p["age"] = float(p["age"]) + delta
		if float(p["age"]) >= float(p["life"]):
			continue
		var g: float = GRAVITY if String(p["k"]) != "smoke" else -40.0
		p["v"] = (p["v"] as Vector2) + Vector2(0, g * delta)
		p["p"] = (p["p"] as Vector2) + (p["v"] as Vector2) * delta
		p["rot"] = float(p["rot"]) + delta * 8.0
		alive.append(p)
	_particles = alive
	queue_redraw()


func _draw() -> void:
	for p: Dictionary in _particles:
		var c: Color = p["c"]
		c.a *= 1.0 - float(p["age"]) / float(p["life"])
		var pos: Vector2 = p["p"]
		var s: float = p["s"]
		match String(p["k"]):
			"coins":
				draw_circle(pos, s, c)
				draw_arc(pos, s * 0.65, 0.0, TAU, 12, Palette.GOLD_DARK, 1.5)
			"confetti":
				var d: Vector2 = Vector2.from_angle(float(p["rot"])) * s
				draw_line(pos - d, pos + d, c, 3.0)
			_:
				draw_circle(pos, s, c)
