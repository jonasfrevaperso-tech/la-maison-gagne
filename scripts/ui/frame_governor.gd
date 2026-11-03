class_name FrameGovernor
extends Node
## Mobile uniquement : surveille le temps d'image et abaisse la qualité 3D d'un cran
## (Beau → Équilibré → Économie) si le téléphone n'arrive plus à suivre (chauffe, mode
## économie de batterie). Ne remonte jamais seul pendant la session ; un toast l'annonce.

## Fenêtre de mesure (secondes).
const WINDOW: float = 5.0
## Nombre de fenêtres lentes consécutives avant de baisser d'un cran.
const STRIKES: int = 2
## Fraction de la cadence visée en dessous de laquelle une fenêtre est « lente ».
const SLOW_FRACTION: float = 0.8
## Délai de grâce après un changement (chargement d'écran, compilation de shaders).
const GRACE: float = 8.0

var _acc: float = 0.0
var _frames: int = 0
var _strikes: int = 0
var _grace: float = GRACE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.screen_requested.connect(func(_id: StringName, _p: Dictionary) -> void: _reset())


func _reset() -> void:
	_acc = 0.0
	_frames = 0
	_strikes = 0
	_grace = GRACE


## Cadence visée : limite d'images du réglage, sinon 60.
static func target_fps() -> float:
	var cap: int = Engine.max_fps
	return float(cap) if cap > 0 else 60.0


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _grace > 0.0:
		_grace -= delta
		return
	_acc += delta
	_frames += 1
	if _acc < WINDOW:
		return
	var fps: float = float(_frames) / _acc
	_acc = 0.0
	_frames = 0
	if fps >= target_fps() * SLOW_FRACTION:
		_strikes = 0
		return
	_strikes += 1
	if _strikes >= STRIKES:
		_strikes = 0
		_step_down()


func _step_down() -> void:
	var lv: String = RenderQuality.level()
	var idx: int = Settings.QUALITY_LEVELS.find(lv)
	if idx <= 0:
		return
	RenderQuality.governed = Settings.QUALITY_LEVELS[idx - 1]
	_grace = GRACE
	EventBus.toast.emit(tr("QUALITY_LOWERED") % tr("OPT_QUALITY_" + RenderQuality.governed.to_upper()), &"")
	EventBus.settings_changed.emit()
