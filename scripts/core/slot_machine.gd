class_name SlotMachine
extends RefCounted
## Machine à sous du jackpot (logique pure). Un plein gagnant déclenche 1 à 3 tirages (selon le
## verdict du mini-jeu de lancer). Chaque tirage : trois rouleaux pondérés (data/slots), puis le
## gain d'un brelan ou d'une paire (data/slots/slot_prizes) appliqué aussitôt par le moteur
## d'effets. Tout est tiré sur le flux `effects` AVANT l'animation, que la présentation rejoue.

const REELS: int = 3


## Le tour est-il un jackpot ? Un plein (pari sur un seul numéro) gagnant.
static func is_jackpot(ctx: ScoreContext) -> bool:
	for spot_id: String in ctx.bets_won:
		var spot: BetSpot = BetCatalog.get_spot(spot_id)
		if spot != null and spot.kind == BetCatalog.KIND_STRAIGHT:
			return true
	return false


## Tire `spins` combinaisons et applique leurs gains. Retourne [{"reels": [ids], "prize": id}].
static func play(run: RunState, db: ContentDB, spins: int) -> Array[Dictionary]:
	var symbols: Array[Dictionary] = db.list("slot_symbols")
	var weights: Array[float] = []
	for s: Dictionary in symbols:
		weights.append(float(s.get("weight", 1.0)))
	var out: Array[Dictionary] = []
	for _i: int in spins:
		var reels: Array[String] = []
		for _r: int in REELS:
			reels.append(String(symbols[run.rng.weighted_index(&"effects", weights)]["id"]))
		var prize: Dictionary = prize_for(db, reels)
		if not prize.is_empty():
			apply(run, db, prize)
		out.append({"reels": reels, "prize": String(prize.get("id", ""))})
	return out


## Brelan d'abord, sinon paire (le symbole répété), sinon rien.
static func prize_for(db: ContentDB, reels: Array[String]) -> Dictionary:
	var counts: Dictionary[String, int] = {}
	for r: String in reels:
		counts[r] = counts.get(r, 0) + 1
	var best: String = ""
	var best_n: int = 1
	for k: String in counts.keys():
		if counts[k] > best_n:
			best = k
			best_n = counts[k]
	if best_n < 2:
		return {}
	var want: String = "triple" if best_n >= 3 else "pair"
	for p: Dictionary in db.list("slot_prizes"):
		if String(p.get("match", "")) == want and String(p.get("symbol", "")) == best:
			return p
	return {}


static func apply(run: RunState, db: ContentDB, prize: Dictionary) -> void:
	var env: EffectEnv = EffectEnv.new()
	env.run = run
	env.db = db
	env.source_kind = ScoreEvent.SRC_SYSTEM
	env.source_id = String(prize.get("id", ""))
	EffectRunner.run_effect({"trigger": "on_jackpot", "do": prize.get("do", [])}, env)


## Probabilités exactes d'un brelan et d'une paire par tirage (documentation, tests).
static func odds(db: ContentDB) -> Dictionary:
	var total: float = 0.0
	for s: Dictionary in db.list("slot_symbols"):
		total += float(s.get("weight", 0.0))
	var triple: float = 0.0
	var pair: float = 0.0
	for s2: Dictionary in db.list("slot_symbols"):
		var p: float = float(s2.get("weight", 0.0)) / maxf(total, 0.0001)
		triple += p * p * p
		pair += 3.0 * p * p * (1.0 - p)
	return {"triple": triple, "pair": pair}
