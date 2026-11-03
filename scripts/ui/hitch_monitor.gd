class_name HitchMonitor
extends CanvasLayer
## Compteur d'images (Options › Vidéo › Afficher les im/s) et relevé des à-coups.
## Quand le compteur est affiché, ou avec `--dev-hitch`, chaque image plus longue que
## HITCH_MS est écrite dans le journal (console sur PC, logcat sur Android) avec l'écran courant,
## la dernière étape signalée (`mark`) et le temps écoulé depuis le changement d'écran.

const HITCH_MS: float = 50.0
const REFRESH_S: float = 0.5
const LAYER: int = 99
const MARGIN: Vector2 = Vector2(12, 8)

static var _last_mark: String = ""
static var _mark_ms: int = 0

var _label: Label = null
var _screen: String = "boot"
var _screen_ms: int = 0
var _acc: float = 0.0
var _frames: int = 0
var _worst: float = 0.0
var _log: bool = false
var _pipelines: int = 0


## Étape notable (ouverture d'une épreuve, d'une surcouche…) : citée par le prochain à-coup.
static func mark(what: String) -> void:
	_last_mark = what
	_mark_ms = Time.get_ticks_msec()


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = UiKit.label("", UiKit.SIZE_SMALL, Palette.EMERALD, "mono")
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	EventBus.screen_requested.connect(_on_screen)
	EventBus.settings_changed.connect(_apply)
	_apply()


func _apply() -> void:
	_label.visible = Settings.b("video", "show_fps")
	_log = _label.visible or DevMode.args().has("dev-hitch")
	var safe: Rect2 = Platform.safe_rect(get_viewport())
	_label.position = safe.position + MARGIN


## Pipelines graphiques compilés depuis le lancement (une compilation = un à-coup possible).
static func _pipeline_count() -> int:
	var n: int = 0
	for k: RenderingServer.RenderingInfo in [
		RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS, RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH,
		RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE, RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW,
		RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION,
	]:
		n += RenderingServer.get_rendering_info(k)
	return n


func _on_screen(screen_id: StringName, _params: Dictionary) -> void:
	_screen = String(screen_id)
	_screen_ms = Time.get_ticks_msec()


func _process(delta: float) -> void:
	var ms: float = delta * 1000.0
	var pipes: int = _pipeline_count()
	var new_pipes: int = pipes - _pipelines
	_pipelines = pipes
	if _log and ms > HITCH_MS:
		var now: int = Time.get_ticks_msec()
		print("HITCH %.0f ms · script %.0f ms · %d pipeline(s) · écran %s (+%.1f s) · étape « %s » (+%.1f s)" % [
			ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, new_pipes, _screen,
			float(now - _screen_ms) / 1000.0, _last_mark, float(now - _mark_ms) / 1000.0,
		])
	if not _label.visible:
		return
	_acc += delta
	_frames += 1
	_worst = maxf(_worst, ms)
	if _acc >= REFRESH_S:
		_label.text = tr("HUD_FPS") % [roundi(float(_frames) / _acc), _worst]
		_acc = 0.0
		_frames = 0
		_worst = 0.0
