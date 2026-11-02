class_name DevTrialBench
extends Node
## Banc d'essai des épreuves du lancer (--dev-trial-bench[=N]) : chaque épreuve est jouée N fois
## par un bot parfait (note attendue haute) et N fois sans aucune commande (elle doit se terminer
## seule, avec une note basse), en temps simulé. Échoue si une épreuve bloque ou note mal.

const DT: float = 1.0 / 60.0
const MAX_SECONDS: float = 120.0
const BOT_MIN: float = 0.8
const IDLE_MAX: float = 0.4

var runs: int = 3
var problems: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var host: Control = Control.new()
	host.size = UiLayout.DESIGN_SIZE
	add_child(host)
	for e: Dictionary in DataRegistry.db.list("throw_trials"):
		var id: String = String(e["id"])
		var bot: Array[float] = []
		var idle: Array[float] = []
		var secs: Array[float] = []
		for k: int in runs:
			for mode: String in ["bot", "idle"]:
				var res: Vector2 = await _play(host, e, mode == "bot", k % 2 == 1)
				if res.x < 0.0:
					problems.append("%s (%s) : ne se termine pas en %d s" % [id, mode, int(MAX_SECONDS)])
					continue
				(bot if mode == "bot" else idle).append(res.x)
				if mode == "bot":
					secs.append(res.y)
		var b: float = ThrowTrial.mean(bot)
		var i: float = ThrowTrial.mean(idle)
		print("Épreuve %-8s bot %.2f  inactif %.2f  durée %.1f s" % [id, b, i, ThrowTrial.mean(secs)])
		if b < BOT_MIN:
			problems.append("%s : le bot parfait n'obtient que %.2f" % [id, b])
		if i > IDLE_MAX:
			problems.append("%s : sans rien faire on obtient %.2f" % [id, i])
	for p: String in problems:
		printerr("Épreuves : " + p)
	print("Épreuves : %d problème(s)" % problems.size())
	get_tree().quit(1 if not problems.is_empty() else 0)


## Joue une épreuve en temps simulé ; (note, durée) ou (-1, …) si elle ne finit pas.
func _play(host: Control, e: Dictionary, bot: bool, mouse: bool) -> Vector2:
	var scr: GDScript = load(ThrowMinigame.TRIAL_SCRIPTS % String(e["id"])) as GDScript
	var trial: ThrowTrial = (scr.new() as ThrowTrial).setup(e, 1, false, mouse)
	trial.size = ThrowMinigame.PANEL_RECT.size if not trial.full() else UiLayout.DESIGN_SIZE
	host.add_child(trial)
	await get_tree().process_frame
	trial.set_process(false)
	var elapsed: float = 0.0
	while not trial.finished and elapsed < MAX_SECONDS:
		if bot:
			trial.act(trial.want())
		trial._process(DT * Engine.time_scale)
		elapsed += DT
	var result: float = trial.score if trial.finished else -1.0
	trial.queue_free()
	await get_tree().process_frame
	return Vector2(result, elapsed)
