class_name RunTelemetry
extends RefCounted
## Enregistrements de télémétrie locale (logique pure) : un run = une suite d'objets JSON
## (« run_start », « spin », « deadline », « shop », « note », « run_end »).
## Même format pour un joueur humain (`source = "human"`) et pour les bots du simulateur
## (`source = "bot:<type>"`), ce qui permet de comparer les deux dans `tools/telemetry_report.py`.

const FORMAT_VERSION: int = 1
## Plafond du temps de réflexion compté par tour (au-delà : joueur absent).
const MAX_THINK_SECONDS: float = 120.0


static func run_start(run: RunState, source: String, game_version: String) -> Dictionary:
	return {
		"t": "run_start",
		"format": FORMAT_VERSION,
		"version": game_version,
		"source": source,
		"character": run.character_id,
		"risk": run.risk_level,
		"challenge": run.challenge_id,
		"daily": run.daily,
		"seed": run.rng.seed_value,
		"date": Time.get_datetime_string_from_system(true),
	}


## Répartition des jetons misés par type de pari (`straight`, `red`…).
static func bets_by_kind(slip: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for spot_id: Variant in slip.keys():
		var spot: BetSpot = BetCatalog.get_spot(String(spot_id))
		var kind: String = String(spot.kind) if spot != null else "unknown"
		out[kind] = int(out.get(kind, 0)) + int(slip[spot_id])
	return out


## Instantané pris juste avant un tour : la logique peut ensuite changer d'échéance.
static func snapshot(run: RunState) -> Dictionary:
	return {
		"tier": run.tier,
		"deadline": run.deadline_idx,
		"act": run.act(),
		"kind": run.deadline_kind(),
		"creditor": run.creditor_id,
		"debt": run.debt,
		"score": run.deadline_score,
		"spins_used": run.spins_total - run.spins_left,
	}


static func spin(pre: Dictionary, run: RunState, ctx: ScoreContext, think_seconds: float) -> Dictionary:
	var t: ThrowResolver.ThrowResult = ctx.throw_result
	var chips: int = 0
	for v: Variant in ctx.slip.values():
		chips += int(v)
	return {
		"t": "spin",
		"tier": pre["tier"],
		"deadline": pre["deadline"],
		"act": pre["act"],
		"n": run.total_spins,
		"debt": pre["debt"],
		"progress": int(pre["score"]) + ctx.total,
		"bets": bets_by_kind(ctx.slip),
		"spots": ctx.slip.size(),
		"chips": chips,
		"number": ctx.landing.number if ctx.landing != null else -1,
		"zero": ctx.is_zero,
		"in_zone": t.in_zone if t != null else false,
		"control": snappedf(t.control, 0.001) if t != null else 0.0,
		"won_bets": ctx.bets_won.size(),
		"score": ctx.total,
		"base_chips": snappedf(ctx.chips, 0.01),
		"mult": snappedf(ctx.base_mult + ctx.mult_add, 0.01),
		"xmult": snappedf(ctx.mult_mul, 0.001),
		"money_delta": ctx.money_delta,
		"grigris": grigri_ids(run),
		"think_s": snappedf(minf(think_seconds, MAX_THINK_SECONDS), 0.1),
	}


## Fin d'échéance : `score` et `debt` permettent de mesurer la marge (score / dette).
static func deadline(pre: Dictionary, run: RunState, ctx: ScoreContext, won: bool, seconds: float) -> Dictionary:
	return {
		"t": "deadline",
		"tier": pre["tier"],
		"deadline": pre["deadline"],
		"kind": pre["kind"],
		"creditor": pre["creditor"],
		"won": won,
		"score": int(pre["score"]) + ctx.total,
		"debt": pre["debt"],
		"spins_used": int(pre["spins_used"]) + 1,
		"money": run.money,
		"grigris": grigri_ids(run),
		"wheel_size": run.wheel.size(),
		"seconds": snappedf(seconds, 0.1),
	}


## Visite de boutique : offres vues (rerolls compris), achats, ventes, argent.
static func shop(
	run: RunState, offered: Array[String], bought: Array[String], before: Array[String], money_before: int, rerolls: int, seconds: float
) -> Dictionary:
	var after: Array[String] = grigri_ids(run)
	var sold: Array[String] = []
	for gid: String in before:
		if not after.has(gid):
			sold.append(gid)
	var gained: Array[String] = []
	for gid: String in after:
		if not before.has(gid) and not bought.has(gid):
			gained.append(gid)
	return {
		"t": "shop",
		"tier": run.tier,
		"deadline": run.deadline_idx,
		"offered": offered,
		"bought": bought,
		"gained_other": gained,
		"sold": sold,
		"rerolls": rerolls,
		"money_before": money_before,
		"money_after": run.money,
		"seconds": snappedf(seconds, 0.1),
	}


static func run_end(run: RunState, victory: bool, seconds: float) -> Dictionary:
	return {
		"t": "run_end",
		"victory": victory,
		"tier": run.tier,
		"act": run.act(),
		"deadlines_cleared": run.deadlines_cleared,
		"spins": run.total_spins,
		"best_spin": run.best_spin,
		"defeat": run.defeat_reason,
		"grigris": grigri_ids(run),
		"pacts": run.pacts_used.size(),
		"seconds": snappedf(seconds, 0.1),
	}


## Une épreuve jouée : contexte (run, museum, tuto), note, durée, gestes, commande, détail.
static func trial(id: String, context: String, difficulty: String, score: float, seconds: float, gestures: int,
		input: String, detail: Dictionary) -> Dictionary:
	return {
		"t": "trial",
		"date": Time.get_datetime_string_from_system(true),
		"context": context,
		"id": id,
		"difficulty": difficulty,
		"score": snappedf(score, 0.001),
		"seconds": snappedf(seconds, 0.01),
		"gestures": gestures,
		"gestures_per_s": snappedf(float(gestures) / maxf(seconds, 0.01), 0.01),
		"input": input,
		"detail": detail,
	}


static func note(run: RunState, mood: String, text: String, screen: String, shot: String) -> Dictionary:
	var d: Dictionary = {"t": "note", "mood": mood, "text": text, "screen": screen, "shot": shot}
	if run != null:
		d["tier"] = run.tier
		d["deadline"] = run.deadline_idx
		d["n"] = run.total_spins
	return d


## Offres de grigris actuellement en boutique (avec leur état « vendu »).
static func shop_offers(run: RunState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o: Variant in run.shop_state.get("grigris", []):
		if o is Dictionary and (o as Dictionary).has("id"):
			out.append(o as Dictionary)
	return out


static func grigri_ids(run: RunState) -> Array[String]:
	var out: Array[String] = []
	for g: GrigriInstance in run.grigris:
		out.append(g.id)
	return out
