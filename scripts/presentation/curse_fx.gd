class_name CurseFx
extends ColorRect
## Malus visuels des grigris (« Flasque de gin » → vision alcoolisée, etc.). Purement cosmétique :
## le champ `visual` d'un grigri ({"kind", "strength"}) est lu ici et s'applique pendant le
## mini-jeu de lancer et la course de la bille, en fondu. Le réglage « Malus visuels » (Juice)
## en règle l'intensité (0 = désactivés, accessibilité). Le nœud ne lit que l'écran sous lui.

const KINDS: Array[String] = VisualCurse.KINDS
const BALL_ONLY: Array[String] = VisualCurse.BALL_ONLY
const FADE_IN: float = 0.9
const FADE_OUT: float = 0.6

var _target: Dictionary[String, float] = {}
var _now: Dictionary[String, float] = {}
var _phase: StringName = &"none"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("res://shaders/curse_fx.gdshader") as Shader
	material = mat
	for k: String in KINDS:
		_now[k] = 0.0
		_target[k] = 0.0
	visible = false


## `phase` : &"throw" (mini-jeu), &"ball" (course de la bille) ou &"none".
func set_phase(phase: StringName, run: RunState, db: ContentDB) -> void:
	_phase = phase
	var amount: float = Settings.f("juice", "curse_fx")
	var s: Dictionary[String, float] = VisualCurse.strengths(run, db)
	for k: String in KINDS:
		var on: bool = phase == &"ball" or (phase == &"throw" and not BALL_ONLY.has(k))
		_target[k] = s.get(k, 0.0) * amount if on else 0.0


func active() -> bool:
	for k: String in KINDS:
		if _now[k] > 0.001 or _target[k] > 0.001:
			return true
	return false


func _process(delta: float) -> void:
	var any: bool = false
	for k: String in KINDS:
		var goal: float = _target[k]
		var rate: float = 1.0 / (FADE_IN if goal > _now[k] else FADE_OUT)
		_now[k] = move_toward(_now[k], goal, rate * delta)
		any = any or _now[k] > 0.001
		(material as ShaderMaterial).set_shader_parameter(k, _now[k])
	visible = any
