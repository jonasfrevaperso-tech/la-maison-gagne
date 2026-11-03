class_name BetLoupe
extends Control
## Tactile : loupe au-dessus du doigt pendant la visée d'une mise. Elle montre le tapis
## agrandi sous le doigt (shader sur la texture d'écran), un réticule au point visé et le nom
## de la mise. Positionnée en coordonnées de fenêtre (top_level), à l'opposé du doigt.

const SIZE_PX: float = 260.0
const ZOOM: float = 2.0
const FINGER_GAP: float = 70.0
const RING_W: float = 4.0
const CROSS: float = 16.0
const LABEL_GAP: float = 8.0
const SHADER_PATH: String = "res://shaders/loupe.gdshader"

var _lens: ColorRect = null
var _label: Label = null
var _mat: ShaderMaterial = null
var _ring: Control = null


func _ready() -> void:
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40
	size = Vector2.ONE * SIZE_PX
	_lens = ColorRect.new()
	_lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lens.size = size
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH) as Shader
	_mat.set_shader_parameter("zoom", ZOOM)
	_lens.material = _mat
	add_child(_lens)
	# Anneau et réticule par-dessus la lentille (un enfant se dessine après son parent).
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.size = size
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_label = UiKit.label("", UiKit.SIZE_BODY, Palette.GOLD_LIGHT, "display")
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_outline_color", Palette.INK)
	_label.add_theme_constant_override("outline_size", 8)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	visible = false


## Affiche la loupe pour un doigt en `finger` (coordonnées de fenêtre) et la mise `spot_id`.
func show_at(finger: Vector2, spot_id: String) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var safe: Rect2 = Platform.safe_rect(get_viewport())
	var pos: Vector2 = Vector2(finger.x - SIZE_PX * 0.5, finger.y - FINGER_GAP - SIZE_PX)
	if pos.y < safe.position.y:
		# Trop haut : sur le côté du doigt (vers le centre de l'écran).
		pos.y = clampf(finger.y - SIZE_PX * 0.5, safe.position.y, safe.end.y - SIZE_PX)
		pos.x = finger.x + FINGER_GAP if finger.x < vp.x * 0.5 else finger.x - FINGER_GAP - SIZE_PX
	pos.x = clampf(pos.x, safe.position.x, safe.end.x - SIZE_PX)
	position = pos
	_mat.set_shader_parameter("focus_uv", finger / vp)
	_mat.set_shader_parameter("span_uv", Vector2.ONE * SIZE_PX / vp)
	_label.text = Localization.bet_label(spot_id) if spot_id != "" else ""
	_label.reset_size()
	# Nom de la mise au-dessus de la lentille (dessous, il serait sous le doigt).
	_label.position = Vector2((SIZE_PX - _label.size.x) * 0.5, -_label.size.y - LABEL_GAP)
	if pos.y + _label.position.y < safe.position.y:
		_label.position.y = SIZE_PX + LABEL_GAP
	visible = true
	_ring.queue_redraw()


func hide_loupe() -> void:
	visible = false


func _draw_ring() -> void:
	var c: Vector2 = Vector2.ONE * SIZE_PX * 0.5
	var r: float = SIZE_PX * 0.5
	_ring.draw_arc(c, r - RING_W * 0.5, 0.0, TAU, 64, Palette.GOLD, RING_W, true)
	_ring.draw_line(c - Vector2(CROSS, 0), c + Vector2(CROSS, 0), Palette.IVORY, 2.0)
	_ring.draw_line(c - Vector2(0, CROSS), c + Vector2(0, CROSS), Palette.IVORY, 2.0)
