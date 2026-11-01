class_name PostFx
extends CanvasLayer
## Post-traitement global : bloom (glow 2D via WorldEnvironment) + CRT réglable.

const LAYER: int = 100
const CRT_SHADER: String = "res://shaders/crt.gdshader"
const GLOW_INTENSITY_MAX: float = 1.1
const GLOW_BLOOM: float = 0.12
const GLOW_HDR_THRESHOLD: float = 0.85

var _rect: ColorRect = null
var _env: WorldEnvironment = null


func _ready() -> void:
	layer = LAYER
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load(CRT_SHADER) as Shader
	_rect.material = mat
	add_child(_rect)
	_env = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.glow_enabled = true
	e.glow_bloom = GLOW_BLOOM
	e.glow_hdr_threshold = GLOW_HDR_THRESHOLD
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	_env.environment = e
	add_child(_env)
	EventBus.settings_changed.connect(_apply)
	_apply()


func _apply() -> void:
	var crt: float = Settings.f("video", "crt")
	_rect.visible = crt > 0.0
	(_rect.material as ShaderMaterial).set_shader_parameter("intensity", crt)
	var bloom: float = Settings.f("video", "bloom")
	_env.environment.glow_enabled = bloom > 0.0
	_env.environment.glow_intensity = bloom * GLOW_INTENSITY_MAX
