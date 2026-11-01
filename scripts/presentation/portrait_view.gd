class_name PortraitView
extends Control
## Portrait animé (sprite sheet horizontale de N frames 128×128 si disponible,
## sinon silhouette art déco procédurale avec respiration et clignement).

const SIZE_PX: float = 256.0
const FRAME_SIZE: int = 128
const FPS: float = 6.0
const BLINK_EVERY: float = 3.2

var portrait_id: String = ""
var accent: Color = Palette.GOLD
var talking: bool = false
var _tex: Texture2D = null
var _frames: int = 1
var _t: float = 0.0


func configure(p_id: String, p_accent: Color) -> PortraitView:
	portrait_id = p_id
	accent = p_accent
	return self


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE_PX, SIZE_PX)
	_tex = IconLibrary.portrait(portrait_id)
	if _tex != null:
		_frames = maxi(_tex.get_width() / FRAME_SIZE, 1)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, Vector2(SIZE_PX, SIZE_PX))
	draw_rect(r, Palette.VELVET_DEEP)
	if _tex != null:
		var frame: int = int(_t * FPS) % _frames
		if not talking and _frames > 1:
			frame = 0 if fmod(_t, BLINK_EVERY) > 0.15 else mini(1, _frames - 1)
		draw_texture_rect_region(_tex, r, Rect2(float(frame * FRAME_SIZE), 0.0, float(FRAME_SIZE), float(FRAME_SIZE)))
	else:
		var breathe: float = sin(_t * 2.0) * 3.0
		var c: Vector2 = r.get_center() + Vector2(0, 20 + breathe)
		draw_circle(c + Vector2(0, 90), 95, accent.darkened(0.5))
		draw_circle(c + Vector2(0, -30), 56, accent.darkened(0.25))
		var blink: bool = fmod(_t, BLINK_EVERY) < 0.12
		for sx: float in [-20.0, 20.0]:
			if blink:
				draw_line(c + Vector2(sx - 8, -36), c + Vector2(sx + 8, -36), Palette.INK, 3.0)
			else:
				draw_circle(c + Vector2(sx, -36), 6, Palette.IVORY)
		var mouth_h: float = (absf(sin(_t * 14.0)) * 8.0) if talking else 2.0
		draw_rect(Rect2(c + Vector2(-14, -8), Vector2(28, mouth_h)), Palette.INK)
		draw_arc(c + Vector2(0, -30), 62, PI, TAU, 24, Palette.GOLD, 3.0)
	draw_rect(r, accent, false, 3.0)
