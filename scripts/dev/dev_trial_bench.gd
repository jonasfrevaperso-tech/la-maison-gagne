class_name DevTrialBench
extends Node
## Banc d'essai des épreuves du lancer (--dev-trial-bench[=N]) : chaque épreuve est jouée N fois
## par un bot parfait (note attendue haute) et N fois sans aucune commande (elle doit se terminer
## seule, avec une note basse), en temps simulé. Échoue si une épreuve bloque ou note mal.
## Un troisième passage, le bot « humain » (D-072), rejoue le bot parfait avec les limites d'une
## main humaine : chaque geste part en retard (temps de réaction), le stick suit avec du retard
## et du bruit, et pas plus de quelques gestes par seconde. Il doit garder une note correcte :
## c'est la mesure de « trop rapide pour un humain ».

const DT: float = 1.0 / 60.0
const MAX_SECONDS: float = 120.0
const BOT_MIN: float = 0.8
const IDLE_MAX: float = 0.4
const HUMAN_MIN: float = 0.55
const DURATION_MAX: float = 22.0
## Bot humain. Les gestes francs visent un moment prévisible (jauge, note, rebond) : un humain
## l'anticipe, avec une erreur de timing (retard de 0 à 100 ms). Le stick, lui, réagit à ce qui
## bouge : il suit l'intention avec un vrai temps de réaction (180 ms), du bruit, et pas plus de
## 6 gestes francs par seconde.
const HUMAN_LAG: float = 0.05
const HUMAN_LAG_JITTER: float = 0.05
const HUMAN_AXIS_LAG: float = 0.18
const HUMAN_AXIS_NOISE: float = 0.06
const HUMAN_RATE: float = 6.0

var runs: int = 3
var problems: Array[String] = []
## --dev-trials-only=a,b : ne joue que ces épreuves (mise au point).
var only: PackedStringArray = PackedStringArray()
## --dev-trial-trace : journal des gestes du bot humain (voulu → joué) à chaque changement.
var trace: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _trace_last: String = ""


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var host: Control = Control.new()
	host.size = UiLayout.DESIGN_SIZE
	add_child(host)
	for e: Dictionary in DataRegistry.db.list("throw_trials"):
		var id: String = String(e["id"])
		if not only.is_empty() and not only.has(id):
			continue
		var scores: Dictionary[String, Array] = {"bot": [], "idle": [], "human": []}
		var secs: Array[float] = []
		for k: int in runs:
			_rng.seed = hash(id) + k
			for mode: String in ["bot", "idle", "human"]:
				var res: Vector2 = await _play(host, e, mode, k % 2 == 1)
				if res.x < 0.0:
					problems.append("%s (%s) : ne se termine pas en %d s" % [id, mode, int(MAX_SECONDS)])
					continue
				scores[mode].append(res.x)
				if mode == "bot":
					secs.append(res.y)
		var b: float = _mean(scores["bot"])
		var i: float = _mean(scores["idle"])
		var h: float = _mean(scores["human"])
		var d: float = ThrowTrial.mean(secs)
		print("Épreuve %-9s bot %.2f  humain %.2f  inactif %.2f  durée %.1f s" % [id, b, h, i, d])
		if b < BOT_MIN:
			problems.append("%s : le bot parfait n'obtient que %.2f" % [id, b])
		if h < HUMAN_MIN:
			problems.append("%s : trop rapide, le bot humain n'obtient que %.2f" % [id, h])
		if i > IDLE_MAX:
			problems.append("%s : sans rien faire on obtient %.2f" % [id, i])
		if d > DURATION_MAX:
			problems.append("%s : dure %.1f s" % [id, d])
	for p: String in problems:
		printerr("Épreuves : " + p)
	print("Épreuves : %d problème(s)" % problems.size())
	get_tree().quit(1 if not problems.is_empty() else 0)


## Joue une épreuve en temps simulé ; (note, durée) ou (-1, …) si elle ne finit pas.
func _play(host: Control, e: Dictionary, mode: String, mouse: bool) -> Vector2:
	var scr: GDScript = load(ThrowMinigame.TRIAL_SCRIPTS % String(e["id"])) as GDScript
	var trial: ThrowTrial = (scr.new() as ThrowTrial).setup(e, 1, false, mouse)
	trial.size = ThrowMinigame.PANEL_RECT.size if not trial.full() else UiLayout.DESIGN_SIZE
	host.add_child(trial)
	await get_tree().process_frame
	trial.set_process(false)
	var elapsed: float = 0.0
	var hb: HumanBot = HumanBot.new()
	while not trial.finished and elapsed < MAX_SECONDS:
		if mode == "bot":
			trial.act(trial.want())
		elif mode == "human":
			var w: Dictionary = trial.want()
			var g: Dictionary = hb.step(w, elapsed, _rng)
			if trace and String(w.get("do", "")) + String(g.get("do", "")) != _trace_last:
				_trace_last = String(w.get("do", "")) + String(g.get("do", ""))
				print("  %.2f s  voulu %s  joué %s" % [elapsed, w.get("do", ""), g.get("do", "")])
			trial.act(g)
		trial._process(DT * Engine.time_scale)
		elapsed += DT
	var result: float = trial.score if trial.finished else -1.0
	trial.queue_free()
	await get_tree().process_frame
	return Vector2(result, elapsed)


static func _mean(a: Array) -> float:
	var t: float = 0.0
	for v: Variant in a:
		t += float(v)
	return t / float(maxi(a.size(), 1))


## Main humaine posée sur le bot parfait : les gestes francs (confirmer, symbole, direction,
## maintenir, lâcher) partent après un temps de réaction et au plus HUMAN_RATE fois par seconde ;
## le stick suit l'intention avec retard et bruit. Un geste par image, comme le bot parfait.
class HumanBot:
	extends RefCounted
	var _stream: Array[Array] = []  # [échéance, geste] du stick (ou rien)
	var _pending: Array[Array] = []  # [échéance, geste] des gestes francs
	var _last_key: String = ""
	var _last_fire: float = -10.0
	var _current: Dictionary = {"do": ""}
	var _held: bool = false  # gâchette maintenue (« hold » jusqu'au « release »)

	func step(w: Dictionary, now: float, rng: RandomNumberGenerator) -> Dictionary:
		var kind: String = String(w.get("do", ""))
		var key: String = "%s|%s|%s" % [kind, str(w.get("symbol", "")), str(w.get("dir", ""))]
		if kind == "axis" or kind == "":
			_stream.append([now + DevTrialBench.HUMAN_AXIS_LAG, w])
		elif kind == "hold" and _held:
			pass  # déjà maintenue
		elif key != _last_key and _pending.is_empty():
			var lag: float = DevTrialBench.HUMAN_LAG + rng.randf_range(-1.0, 1.0) * DevTrialBench.HUMAN_LAG_JITTER
			_pending.append([now + lag, w])
		_last_key = key
		if not _pending.is_empty() and float(_pending[0][0]) <= now and now - _last_fire >= 1.0 / DevTrialBench.HUMAN_RATE:
			_last_fire = now
			var g: Dictionary = _pending.pop_front()[1] as Dictionary
			match String(g.get("do", "")):
				"hold":
					_held = true
				"release":
					_held = false
				_:
					_last_key = ""  # après avoir vu l'effet du geste, on peut le refaire
			return g
		while not _stream.is_empty() and float(_stream[0][0]) <= now:
			_current = _stream.pop_front()[1] as Dictionary
		# Gâchette maintenue : le stick reste à la main (« hold » porte alors son vecteur).
		if String(_current.get("do", "")) == "axis":
			var v: Vector2 = _current["v"] as Vector2
			var n: float = DevTrialBench.HUMAN_AXIS_NOISE
			v = (v * (1.0 + rng.randf_range(-n, n)) + Vector2(rng.randf_range(-n, n), rng.randf_range(-n, n))).limit_length(1.0)
			return {"do": "hold", "v": v} if _held else {"do": "axis", "v": v}
		return {"do": "hold"} if _held else {"do": ""}
