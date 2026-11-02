class_name SlotReel
extends Control
## Un rouleau de la machine à sous : bande de symboles qui défile (flou de mouvement), puis
## s'arrête avec un rebond PILE sur le symbole tiré par le cœur (SlotMachine) — l'animation
## raconte un résultat déjà connu.

signal stopped

const STEP: float = 118.0
const SYMBOL: float = 96.0
const STRIP: int = 24
const SPEED: float = 2600.0
const DECEL_TIME: float = 0.55
const TEASE_DECEL: float = 1.6
const OVERSHOOT: float = 1.25

var symbols: Array[String] = []
var _pos: float = 0.0
var _spinning: bool = false
var _stopping: bool = false
var _from: float = 0.0
var _to: float = 0.0
var _t: float = 0.0
var _dur: float = DECEL_TIME
var _stop_at: float = 0.0
var _clock: float = 0.0
var _final_index: int = 0
var _glow: float = 0.0
var _textures: Dictionary[String, Texture2D] = {}


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Bande de départ (symboles de remplissage tirés au hasard cosmétique).
func setup(ids: Array[String]) -> void:
	var rng: RandomNumberGenerator = RngService.cosmetic()
	symbols.clear()
	for _i: int in STRIP:
		symbols.append(ids[rng.randi_range(0, ids.size() - 1)])
	for id: String in ids:
		var path: String = "res://assets/slot/slot_%s.png" % id
		if ResourceLoader.exists(path):
			_textures[id] = load(path) as Texture2D
	_pos = float(rng.randi_range(0, STRIP - 1)) * STEP
	queue_redraw()


## Lance le rouleau ; il s'arrêtera sur `final_id` après `after` secondes (`tease` : lentement).
func spin(final_id: String, after: float, tease: bool) -> void:
	_final_index = (int(_pos / STEP) + STRIP / 2) % STRIP
	symbols[_final_index] = final_id
	_spinning = true
	_stopping = false
	_clock = 0.0
	_stop_at = after
	_dur = TEASE_DECEL if tease else DECEL_TIME
	_glow = 0.0


## Arrêt immédiat (passer l'animation).
func hurry() -> void:
	if _spinning and not _stopping:
		_stop_at = minf(_stop_at, _clock)
		_dur = 0.18


func is_spinning() -> bool:
	return _spinning


func flash() -> void:
	_glow = 1.0


func _strip_len() -> float:
	return STEP * float(STRIP)


func _process(delta: float) -> void:
	_glow = maxf(_glow - delta * 1.5, 0.0)
	if not _spinning:
		if _glow > 0.0:
			queue_redraw()
		return
	_clock += delta
	if not _stopping:
		_pos = fposmod(_pos + SPEED * delta, _strip_len())
		if _clock >= _stop_at:
			_stopping = true
			_t = 0.0
			_from = _pos
			# Destination : le symbole final centré, au moins un tour de bande plus loin (en avant).
			var target: float = float(_final_index) * STEP
			var ahead: float = fposmod(target - _from, _strip_len())
			_to = _from + ahead + _strip_len() * (1.0 if _dur > DECEL_TIME else 0.0)
			if ahead < STEP * 3.0:
				_to += _strip_len()
	else:
		_t += delta
		var u: float = clampf(_t / _dur, 0.0, 1.0)
		# Décélération avec léger dépassement (ressort) : « clac » mécanique.
		var e: float = 1.0 + (OVERSHOOT + 1.0) * pow(u - 1.0, 3.0) + OVERSHOOT * pow(u - 1.0, 2.0)
		_pos = fposmod(lerpf(_from, _to, e), _strip_len())
		if u >= 1.0:
			_pos = fposmod(_to, _strip_len())
			_spinning = false
			_stopping = false
			stopped.emit()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.IVORY.darkened(0.08))
	var mid: float = size.y * 0.5
	var blur: bool = _spinning and not _stopping
	var speed_blur: float = 1.0 if blur else (0.4 if _stopping and _t < _dur * 0.5 else 0.0)
	var n: int = int(ceil(size.y / STEP)) + 2
	var base: int = int(floor(_pos / STEP))
	for k: int in range(-n, n + 1):
		var idx: int = posmod(base + k, STRIP)
		var y: float = mid + (float(base + k) * STEP - _pos)
		if y < -STEP or y > size.y + STEP:
			continue
		var tex: Texture2D = _textures.get(symbols[idx], null)
		if tex == null:
			continue
		var h: float = SYMBOL * (1.0 + 0.5 * speed_blur)
		var r: Rect2 = Rect2(Vector2(size.x * 0.5 - SYMBOL * 0.5, y - h * 0.5), Vector2(SYMBOL, h))
		draw_texture_rect(tex, r, false, Color(1, 1, 1, 1.0 - 0.35 * speed_blur))
	# Ombre de cylindre en haut et en bas.
	for i: int in 8:
		var a: float = 0.55 * (1.0 - float(i) / 8.0)
		draw_rect(Rect2(0, float(i) * 10.0, size.x, 10.0), Color(Palette.INK, a))
		draw_rect(Rect2(0, size.y - float(i + 1) * 10.0, size.x, 10.0), Color(Palette.INK, a))
	if _glow > 0.0:
		draw_rect(Rect2(Vector2(0, mid - STEP * 0.5), Vector2(size.x, STEP)), Color(Palette.GOLD_LIGHT, 0.35 * _glow))
