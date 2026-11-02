class_name TitleWheel
extends WheelView
## Roue 3D de l'écran titre : tourne lentement et lance une bille de démonstration de temps
## en temps (pur décor : tirage cosmétique, aucune incidence sur une partie).

const DEMO_EVERY: float = 7.0

var _demo_t: float = 2.5


func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	muted = true
	setup(WheelModel.standard(), DataRegistry.db)


func _process(delta: float) -> void:
	super._process(delta)
	if is_ball_active() or JuiceProfile.intensity() <= 0.0:
		return
	_demo_t -= delta
	if _demo_t <= 0.0:
		_demo_t = DEMO_EVERY
		play_throw(RngService.cosmetic().randi_range(0, wheel.size() - 1), false)


func _gui_input(_event: InputEvent) -> void:
	pass
