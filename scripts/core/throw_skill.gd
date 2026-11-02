class_name ThrowSkill
extends RefCounted
## Mini-jeu de lancer : règles pures (notation des deux gestes et effet sur le contrôle).
## 1. Visée : la roue tourne sous le pointeur, on fige la case visée (inchangé).
## 2. Élan : une aiguille balaie une jauge ; on l'arrête dans la zone dorée (largeur selon la
##    Précision). Note = 1 au centre, décroît au-delà de la zone.
## 3. Lâcher : un anneau se resserre sur la bille ; on lâche quand il la touche.
## Qualité q = moyenne pondérée des deux notes. Le contrôle (probabilité de tomber dans la zone
## visée) est ajusté autour de la référence (± quelques points) : un lancer de référence rend exactement la
## probabilité de la 1.2 ; les bots et le mode simplifié jouent à la référence.

enum Grade { PERFECT, GREAT, GOOD, MISS }

const NEUTRAL: float = -1.0
## Note d'un élan arrêté pile au bord de la zone dorée.
const EDGE_SCORE: float = 0.7


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


## Demi-largeur de la zone dorée de la jauge d'élan (fraction de la jauge, 0–0,5).
static func sweet_half(precision: int, assist: bool) -> float:
	var table: Array = Balance.arr("throw_game.power_sweet_width_by_precision")
	var w: float = float(table[clampi(precision - 1, 0, table.size() - 1)])
	if assist:
		w *= Balance.f("throw_game.assist_widen")
	return minf(w * 0.5, 0.45)


## Note de l'élan : position de l'aiguille (0–1, centre de la zone à 0,5).
## Parfait au cœur de la zone, EDGE_SCORE à son bord, puis décroissance jusqu'à 0.
static func power_score(pos: float, half: float) -> float:
	var d: float = absf(pos - 0.5)
	var core: float = half * Balance.f("throw_game.power_perfect_ratio")
	if d <= core:
		return 1.0
	if d <= half:
		return lerpf(1.0, EDGE_SCORE, (d - core) / maxf(half - core, 0.0001))
	var fall: float = maxf(half * Balance.f("throw_game.power_falloff"), 0.0001)
	return clampf(EDGE_SCORE * (1.0 - (d - half) / fall), 0.0, EDGE_SCORE)


## Note du lâcher : écart (secondes) entre l'appui et le contact anneau-bille.
static func release_score(error_s: float, assist: bool) -> float:
	var window: float = Balance.f("throw_game.release_window_seconds") * (Balance.f("throw_game.assist_widen") if assist else 1.0)
	var e: float = absf(error_s)
	if e <= Balance.f("throw_game.release_perfect_seconds"):
		return 1.0
	return clampf(1.0 - (e - Balance.f("throw_game.release_perfect_seconds")) / maxf(window, 0.0001), 0.0, 1.0)


static func quality(power: float, release: float) -> float:
	var w: float = Balance.f("throw_game.power_weight")
	return clampf(power * w + release * (1.0 - w), 0.0, 1.0)


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


## Position de l'aiguille d'élan au temps t : aller-retour à vitesse constante (prévisible).
static func power_needle(t: float, period: float) -> float:
	var u: float = fposmod(t / maxf(period, 0.01), 1.0)
	return 1.0 - absf(u * 2.0 - 1.0)
