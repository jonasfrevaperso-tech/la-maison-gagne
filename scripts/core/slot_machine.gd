class_name SlotMachine
extends RefCounted
## Machine à sous du jackpot (logique pure). Un plein gagnant déclenche 1 à 3 tirages (selon le
## verdict du mini-jeu de lancer). Chaque tirage : quatre rouleaux pondérés (data/slots), puis le
## gain d'un carré, d'un brelan ou d'une paire (data/slots/slot_prizes) appliqué aussitôt par le
## moteur d'effets. Tout est tiré sur le flux `effects` AVANT l'animation, que la présentation rejoue.

const REELS: int = 4
const MATCHES: Array[String] = ["", "", "pair", "triple", "quad"]


## Le tour est-il un jackpot ? Un plein (pari sur un seul numéro) gagnant.
static func is_jackpot(ctx: ScoreContext) -> bool:
	for spot_id: String in ctx.bets_won:
		var spot: BetSpot = BetCatalog.get_spot(spot_id)
		if spot != null and spot.kind == BetCatalog.KIND_STRAIGHT:
			return true
	return false


## Nombre de tirages offerts par ce tour : plein gagnant ou « gros coup » (le tour solde à lui
## seul l'échéance restante et pèse au moins `slot.big_win_debt_frac` de la dette) → selon la
## qualité du lancer ; plus les tirages gratuits gagnés pendant le score (Sceau Cloche, grigris).
## Consomme le compteur `slot_pulls`. Plafonné à `slot.max_pulls`.
static func pulls(run: RunState, ctx: ScoreContext, quality: float, remaining_before: int) -> int:
	var n: int = int(run.flags.get("slot_pulls", 0))
	run.flags.erase("slot_pulls")
	var big: bool = ctx.total >= remaining_before and float(ctx.total) >= float(run.debt) * Balance.f("slot.big_win_debt_frac")
	if is_jackpot(ctx) or big:
		n += ThrowSkill.slot_spins(quality)
	return mini(n, Balance.i("slot.max_pulls"))


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


## Carré d'abord, puis brelan, sinon paire (le symbole le plus répété), sinon rien. Un carré sans
## gain dédié retombe sur le gain du brelan.
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
	for n: int in range(mini(best_n, MATCHES.size() - 1), 1, -1):
		for p: Dictionary in db.list("slot_prizes"):
			if String(p.get("match", "")) == MATCHES[n] and String(p.get("symbol", "")) == best:
				return p
	return {}


static func apply(run: RunState, db: ContentDB, prize: Dictionary) -> void:
	var env: EffectEnv = EffectEnv.new()
	env.run = run
	env.db = db
	env.source_kind = ScoreEvent.SRC_SYSTEM
	env.source_id = String(prize.get("id", ""))
	EffectRunner.run_effect({"trigger": "on_jackpot", "do": prize.get("do", [])}, env)


## Probabilités exactes par tirage (énumération des combinaisons) : {"quad", "triple", "pair"}
## selon le symbole le plus répété. Sert à la documentation et aux tests.
static func odds(db: ContentDB) -> Dictionary:
	var ps: Array[float] = []
	var total: float = 0.0
	for s: Dictionary in db.list("slot_symbols"):
		total += float(s.get("weight", 0.0))
	for s2: Dictionary in db.list("slot_symbols"):
		ps.append(float(s2.get("weight", 0.0)) / maxf(total, 0.0001))
	var out: Dictionary = {"quad": 0.0, "triple": 0.0, "pair": 0.0}
	var n: int = ps.size()
	var combos: int = int(pow(float(n), float(REELS)))
	for c: int in combos:
		var counts: Array[int] = []
		counts.resize(n)
		var prob: float = 1.0
		var x: int = c
		for _r: int in REELS:
			counts[x % n] += 1
			prob *= ps[x % n]
			x = int(x / float(n))
		var best: int = counts.max()
		if best >= 2:
			var key: String = MATCHES[mini(best, MATCHES.size() - 1)]
			out[key] = float(out[key]) + prob
	return out
