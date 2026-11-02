class_name VisualCurse
extends RefCounted
## Malus visuels des grigris (logique pure) : types connus et intensités cumulées des grigris
## portés. Le rendu est dans CurseFx (présentation) ; le champ `visual` est validé à partir d'ici.

const KINDS: Array[String] = ["drunk", "smoke", "crack", "flicker", "jitter", "mirror", "dark"]
## Effets réservés à la course de la bille (pas au mini-jeu de lancer).
const BALL_ONLY: Array[String] = ["mirror"]


## Intensités cumulées (plafonnées à 1) des grigris actifs.
static func strengths(run: RunState, db: ContentDB) -> Dictionary[String, float]:
	var out: Dictionary[String, float] = {}
	if run == null:
		return out
	for g: GrigriInstance in run.grigris:
		if g.disabled:
			continue
		var vis: Variant = db.get_entry("grigris", g.id).get("visual", null)
		if vis is Dictionary:
			var k: String = String((vis as Dictionary).get("kind", ""))
			out[k] = minf(out.get(k, 0.0) + float((vis as Dictionary).get("strength", 0.0)), 1.0)
	return out
