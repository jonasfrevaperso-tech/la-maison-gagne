class_name ScreenTransition
extends Control
## Transition « rideaux de casino » : deux pans de velours se ferment puis s'ouvrent.

const CLOSE_TIME: float = 0.28
const OPEN_TIME: float = 0.34
const FRINGE_HEIGHT: float = 14.0

## "curtains" (rideaux) ou "crt" (écran qui s'éteint en ligne).
var style: String = "curtains"
var _left: ColorRect = null
var _right: ColorRect = null
var _closed: bool = false
var _crt: ColorRect = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left = _make_panel()
	_right = _make_panel()
	_layout(0.0)


func _make_panel() -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = Palette.VELVET
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	var trim: ColorRect = ColorRect.new()
	trim.color = Palette.GOLD
	trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trim.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	trim.offset_top = -FRINGE_HEIGHT
	r.add_child(trim)
	return r


func _layout(t: float) -> void:
	var s: Vector2 = get_viewport_rect().size
	var half: float = s.x * 0.5
	_left.size = Vector2(half + 2.0, s.y)
	_right.size = Vector2(half + 2.0, s.y)
	_left.position = Vector2(-half + half * t, 0.0)
	_right.position = Vector2(s.x - half * t, 0.0)
	_left.visible = t > 0.0
	_right.visible = t > 0.0


func _speed() -> float:
	return maxf(Settings.speed(), 1.0) * (1.0 if JuiceProfile.intensity() > 0.0 else 100.0)


func _crt_layout(t: float) -> void:
	if _crt == null:
		_crt = ColorRect.new()
		_crt.color = Palette.INK
		_crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_crt)
	var s: Vector2 = get_viewport_rect().size
	var h: float = s.y * 0.5 * clampf(t * 1.3, 0.0, 1.0)
	_crt.position = Vector2.ZERO
	_crt.size = s
	_crt.color = Palette.INK
	_crt.visible = t > 0.0
	_crt.material = null
	# deux volets haut/bas qui se rejoignent en une ligne blanche
	_crt.size = Vector2(s.x, h)
	if _crt.get_child_count() == 0:
		var bottom: ColorRect = ColorRect.new()
		bottom.color = Palette.INK
		bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_crt.add_child(bottom)
		var line: ColorRect = ColorRect.new()
		line.color = Palette.IVORY
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_crt.add_child(line)
	var b: ColorRect = _crt.get_child(0) as ColorRect
	b.position = Vector2(0, s.y - h)
	b.size = Vector2(s.x, h)
	var ln: ColorRect = _crt.get_child(1) as ColorRect
	ln.position = Vector2(0, s.y * 0.5 - 1.5)
	ln.size = Vector2(s.x * (1.0 - clampf((t - 0.7) / 0.3, 0.0, 1.0)), 3.0)
	ln.visible = t > 0.6


func close() -> void:
	if _closed:
		return
	_closed = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if style == "crt":
		var tc: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tc.tween_method(_crt_layout, 0.0, 1.0, CLOSE_TIME * 1.4 / _speed())
		AudioBus.ui("panel_close")
		await tc.finished
		return
	var tw: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_method(_layout, 0.0, 1.0, CLOSE_TIME / _speed())
	AudioBus.ui("curtain")
	await tw.finished


func open() -> void:
	_closed = false
	if _crt != null and _crt.visible:
		var tc: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tc.tween_method(_crt_layout, 1.0, 0.0, OPEN_TIME / _speed())
		await tc.finished
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	var tw: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_layout, 1.0, 0.0, OPEN_TIME / _speed())
	await tw.finished
	mouse_filter = Control.MOUSE_FILTER_IGNORE
