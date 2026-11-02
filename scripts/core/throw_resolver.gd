class_name ThrowResolver
extends RefCounted
## Résout un lancer AVANT toute animation.
## 1. Le joueur vise une case (moment du relâchement).
## 2. Avec la probabilité `control`, la bille tombe dans la zone visée
##    (largeur selon la Précision, tirage triangulaire centré) ; sinon rebond fou (uniforme).
## 3. Les cases attirantes (Aimant) et collantes peuvent dévier la bille.


class ThrowParams:
	extends RefCounted
	var target_index: int = 0
	var precision: int = 1
	var control_bonus: float = 0.0
	var zone_width_override: int = 0
	var attractors: Dictionary[int, float] = {}  # index -> probabilité d'attirer depuis un voisin
	var sticky_index: int = -1
	var sticky_chance: float = 0.0
	var last_landing_index: int = -1
	## Qualité du mini-jeu (0–1) ou −1 (lancer simplifié) : déjà incluse dans control_bonus.
	var skill: float = -1.0


class ThrowResult:
	extends RefCounted
	var target_index: int = 0
	var landing_index: int = 0
	var in_zone: bool = false
	var attracted_from: int = -1
	var stuck: bool = false
	var zone: Array[int] = []
	var control: float = 0.0
	var skill: float = -1.0

	func to_dict() -> Dictionary:
		return {
			"skill": snappedf(skill, 0.01),
			"target": target_index,
			"landing": landing_index,
			"in_zone": in_zone,
			"attracted_from": attracted_from,
			"stuck": stuck,
		}


static func precision_index(precision: int) -> int:
	return clampi(precision, 1, Balance.i("throw.max_precision")) - 1


static func control_for(precision: int, bonus: float) -> float:
	var table: Array = Balance.arr("throw.control_by_precision")
	var c: float = float(table[mini(precision_index(precision), table.size() - 1)]) + bonus
	return clampf(c, 0.0, 1.0)


static func zone_width_for(precision: int, override_width: int) -> int:
	if override_width > 0:
		return override_width
	var table: Array = Balance.arr("throw.zone_width_by_precision")
	return int(table[mini(precision_index(precision), table.size() - 1)])


## Distribution de probabilité exacte sur chaque index de roue (affichage Dr Khan, tests, bots).
static func distribution(wheel_size: int, params: ThrowParams) -> Array[float]:
	var probs: Array[float] = []
	probs.resize(wheel_size)
	probs.fill(0.0)
	var control: float = control_for(params.precision, params.control_bonus)
	var width: int = zone_width_for(params.precision, params.zone_width_override)
	var half: int = width / 2
	var weights: Array[float] = _zone_weights(half)
	var wsum: float = 0.0
	for w: float in weights:
		wsum += w
	for o: int in range(-half, half + 1):
		var idx: int = posmod(params.target_index + o, wheel_size)
		probs[idx] += control * weights[o + half] / wsum
	var wild: Array[float] = _wild_weights(wheel_size, params)
	var wild_sum: float = 0.0
	for w: float in wild:
		wild_sum += w
	for i: int in wheel_size:
		probs[i] += (1.0 - control) * wild[i] / wild_sum
	return probs


static func _zone_weights(half: int) -> Array[float]:
	var weights: Array[float] = []
	for o: int in range(-half, half + 1):
		weights.append(float(half + 1 - absi(o)))
	return weights


static func _wild_weights(wheel_size: int, params: ThrowParams) -> Array[float]:
	var wild: Array[float] = []
	wild.resize(wheel_size)
	wild.fill(1.0)
	if Balance.b("anti_streak.enabled") and params.last_landing_index >= 0 and params.last_landing_index < wheel_size:
		wild[params.last_landing_index] *= Balance.f("anti_streak.same_pocket_weight_penalty")
	return wild


static func resolve(wheel_size: int, params: ThrowParams, rng: RngStreams) -> ThrowResult:
	var r: ThrowResult = ThrowResult.new()
	r.target_index = posmod(params.target_index, wheel_size)
	r.control = control_for(params.precision, params.control_bonus)
	r.skill = params.skill
	var width: int = zone_width_for(params.precision, params.zone_width_override)
	var half: int = width / 2
	for o: int in range(-half, half + 1):
		r.zone.append(posmod(r.target_index + o, wheel_size))
	var landing: int
	if rng.chance(RngStreams.WHEEL, r.control):
		var off: int = rng.weighted_index(RngStreams.WHEEL, _zone_weights(half)) - half
		landing = posmod(r.target_index + off, wheel_size)
		r.in_zone = true
	else:
		landing = rng.weighted_index(RngStreams.WHEEL, _wild_weights(wheel_size, params))
		r.in_zone = r.zone.has(landing)
	# Case collante : la bille revient sur la dernière case collante touchée.
	if params.sticky_index >= 0 and params.sticky_index != landing:
		if rng.chance(RngStreams.WHEEL, params.sticky_chance):
			landing = params.sticky_index
			r.stuck = true
	# Aimants : un voisin direct aimanté peut attirer la bille.
	if not r.stuck:
		for side: int in [-1, 1]:
			var n_idx: int = posmod(landing + side, wheel_size)
			if params.attractors.has(n_idx) and rng.chance(RngStreams.WHEEL, params.attractors[n_idx]):
				r.attracted_from = landing
				landing = n_idx
				break
	r.landing_index = landing
	return r
