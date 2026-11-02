class_name ThrowTrials
extends RefCounted
## Tirage des épreuves d'un lancer (logique pure). Chaque lancer en joue `count` différentes,
## tirées au poids parmi data/throw/throw_trials.json, en évitant si possible celles du lancer
## précédent. Le tirage passe par le flux cosmétique : il ne change que le geste demandé.


static func pick(db: ContentDB, rng: RandomNumberGenerator, count: int, avoid: Array[String] = []) -> Array[String]:
	var pool: Array[Dictionary] = db.list("throw_trials")
	var fresh: Array[Dictionary] = pool.filter(func(e: Dictionary) -> bool: return not avoid.has(String(e["id"])))
	if fresh.size() >= count:
		pool = fresh
	var out: Array[String] = []
	while out.size() < count and not pool.is_empty():
		var total: float = 0.0
		for e: Dictionary in pool:
			total += float(e.get("weight", 1.0))
		var r: float = rng.randf() * total
		var idx: int = 0
		while idx < pool.size() - 1 and r > float(pool[idx].get("weight", 1.0)):
			r -= float(pool[idx].get("weight", 1.0))
			idx += 1
		out.append(String(pool[idx]["id"]))
		pool.remove_at(idx)
	return out


## Nombre d'épreuves par lancer selon le mode (complet : 2, rapide : 1).
static func count_for(mode: String) -> int:
	return Balance.i("throw_game.trials_quick") if mode == "quick" else Balance.i("throw_game.trials_per_throw")
