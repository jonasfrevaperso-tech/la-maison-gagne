class_name ThrowSkill
extends RefCounted
## Mini-jeu de lancer v2 : règles pures (notation des trois gestes et effet sur le contrôle).
## 1. Visée : la roue tourne sous le pointeur, on fige la case visée.
## 2. Élan : on MAINTIENT pour charger une jauge qui accélère (puis redescend si on tarde) et on
##    relâche dans la zone dorée, dont la position change à chaque lancer (largeur selon la Précision).
## 3. Effet : des invites QTE défilent vers une ligne ; on frappe la bonne commande à leur passage.
## 4. Lâcher : un anneau se referme sur la bille en accélérant ; on frappe au contact.
## Qualité q = moyenne pondérée des trois notes. Le contrôle (probabilité de tomber dans la zone
## visée) est ajusté autour de la référence : un lancer de référence rend exactement la
## probabilité de la 1.2 ; les bots et le mode Simple jouent à la référence.

enum Grade { PERFECT, GREAT, GOOD, MISS }

const NEUTRAL: float = -1.0
## Note d'un élan relâché pile au bord de la zone dorée.
const EDGE_SCORE: float = 0.7
## Nombre de symboles d'invite (4 directions ; 2 à la souris : clics gauche et droit).
const SYMBOLS: int = 4
const MOUSE_SYMBOLS: int = 2


static func reference_quality() -> float:
	return Balance.f("throw_game.reference_quality")


## Bonus de contrôle pour une qualité q (q < 0 : lancer simplifié, aucun effet).
## Linéaire par morceaux : 0 à la référence, +control_up à 1, −control_down à 0.
static func control_bonus(q: float) -> float:
	if q < 0.0:
		return 0.0
	var ref: float = reference_quality()
	var x: float = clampf(q, 0.0, 1.0)
	if x >= ref:
		return (x - ref) / maxf(1.0 - ref, 0.0001) * Balance.f("throw_game.control_up")
	return -(ref - x) / maxf(ref, 0.0001) * Balance.f("throw_game.control_down")


static func _widen(assist: bool) -> float:
	return Balance.f("throw_game.assist_widen") if assist else 1.0


## Demi-largeur de la zone dorée de la jauge d'élan (fraction de la jauge).
static func sweet_half(precision: int, assist: bool) -> float:
	var table: Array = Balance.arr("throw_game.power_sweet_width_by_precision")
	var w: float = float(table[clampi(precision - 1, 0, table.size() - 1)]) * _widen(assist)
	return minf(w * 0.5, 0.3)


## Centre de la zone dorée pour un tirage u ∈ [0, 1] (le tirage est cosmétique : il ne change
## que la difficulté du geste, pas le résultat).
static func sweet_center(u: float) -> float:
	var r: Array = Balance.arr("throw_game.power_center_range")
	return lerpf(float(r[0]), float(r[1]), clampf(u, 0.0, 1.0))


## Niveau de la jauge après t secondes de charge : montée accélérée en `charge_seconds`, puis
## redescente symétrique (on peut encore se rattraper), et ainsi de suite.
static func charge_level(t: float, slow: float = 1.0) -> float:
	var period: float = maxf(Balance.f("throw_game.charge_seconds") * slow, 0.05)
	var u: float = fposmod(t / period, 2.0)
	var x: float = u if u <= 1.0 else 2.0 - u
	return pow(x, Balance.f("throw_game.charge_exponent"))


## Note de l'élan : niveau relâché `pos`, zone dorée de demi-largeur `half` centrée sur `center`.
## Parfait au cœur, EDGE_SCORE au bord de la zone, puis décroissance jusqu'à 0.
static func power_score(pos: float, half: float, center: float = 0.5) -> float:
	var d: float = absf(pos - center)
	var core: float = half * Balance.f("throw_game.power_perfect_ratio")
	if d <= core:
		return 1.0
	if d <= half:
		return lerpf(1.0, EDGE_SCORE, (d - core) / maxf(half - core, 0.0001))
	var fall: float = maxf(half * Balance.f("throw_game.power_falloff"), 0.0001)
	return clampf(EDGE_SCORE * (1.0 - (d - half) / fall), 0.0, EDGE_SCORE)


## Note d'un geste chronométré : `error_s` = écart à l'instant idéal (secondes).
static func timing_score(error_s: float, perfect_s: float, window_s: float) -> float:
	var e: float = absf(error_s)
	if e <= perfect_s:
		return 1.0
	return clampf(1.0 - (e - perfect_s) / maxf(window_s, 0.0001), 0.0, 1.0)


## Note d'une invite d'effet (bonne commande) ; mauvaise commande ou invite manquée : 0.
static func tap_score(error_s: float, assist: bool) -> float:
	var window: float = Balance.f("throw_game.spin_window_seconds") * _widen(assist)
	return timing_score(error_s, Balance.f("throw_game.spin_perfect_seconds"), window)


## Une invite peut encore être frappée tant que l'écart reste dans la fenêtre.
static func tap_window(assist: bool) -> float:
	return (Balance.f("throw_game.spin_window_seconds") + Balance.f("throw_game.spin_perfect_seconds")) * _widen(assist)


static func release_score(error_s: float, assist: bool) -> float:
	var window: float = Balance.f("throw_game.release_window_seconds") * _widen(assist)
	return timing_score(error_s, Balance.f("throw_game.release_perfect_seconds"), window)


## Rayon relatif de l'anneau du lâcher (1 → 0 au contact), qui accélère vers la fin.
static func ring_progress(t: float, duration: float) -> float:
	var u: float = clampf(t / maxf(duration, 0.01), 0.0, 1.0)
	return 1.0 - pow(u, Balance.f("throw_game.release_ease"))


static func spin_score(taps: Array[float]) -> float:
	if taps.is_empty():
		return 0.0
	var s: float = 0.0
	for v: float in taps:
		s += v
	return s / float(taps.size())


static func quality(power: float, spin: float, release: float) -> float:
	var wp: float = Balance.f("throw_game.weight_power")
	var ws: float = Balance.f("throw_game.weight_spin")
	return clampf(power * wp + spin * ws + release * (1.0 - wp - ws), 0.0, 1.0)


static func grade(q: float) -> Grade:
	var t: Array = Balance.arr("throw_game.grade_thresholds")
	if q >= float(t[0]):
		return Grade.PERFECT
	if q >= float(t[1]):
		return Grade.GREAT
	if q >= float(t[2]):
		return Grade.GOOD
	return Grade.MISS


static func grade_key(g: Grade) -> String:
	return ["THROW_Q_PERFECT", "THROW_Q_GREAT", "THROW_Q_GOOD", "THROW_Q_MISS"][int(g)]


## Note d'un temps isolé → verdict (mêmes seuils que la qualité globale).
static func beat_grade(score: float) -> Grade:
	return grade(score)


## Nombre de tirages de la machine à sous selon le verdict du lancer (Parfait 3, Très bien 2,
## sinon 1 ; lancer simplifié : 1).
static func slot_spins(q: float) -> int:
	if q < 0.0:
		return 1
	match grade(q):
		Grade.PERFECT:
			return 3
		Grade.GREAT:
			return 2
	return 1
