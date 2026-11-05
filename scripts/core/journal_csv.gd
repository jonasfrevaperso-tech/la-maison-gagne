class_name JournalCsv
extends RefCounted
## Journal de jeu → tableaux CSV (logique pure, testable headless). Le journal est une suite
## d'objets JSON par ligne (`RunTelemetry`, `PlayJournal`) ; chaque fichier de run donne une
## colonne `run` (nom du fichier) pour relier les lignes entre elles.

const RUN_COLS: Array[String] = [
	"run", "date", "version", "character", "risk", "challenge", "daily", "seed",
	"victory", "tier", "act", "deadlines_cleared", "spins", "best_spin", "defeat", "pacts", "grigris", "seconds",
]
const SPIN_COLS: Array[String] = [
	"run", "n", "tier", "deadline", "act", "debt", "progress", "number", "zero", "in_zone", "control",
	"spots", "chips", "won_bets", "score", "base_chips", "mult", "xmult", "money_delta", "slot", "grigris", "think_s",
]
const DEADLINE_COLS: Array[String] = [
	"run", "tier", "deadline", "kind", "creditor", "won", "score", "debt", "spins_used", "money", "wheel_size", "seconds",
]
const TRIAL_COLS: Array[String] = [
	"run", "date", "context", "id", "difficulty", "score", "seconds", "gestures", "gestures_per_s", "input", "detail",
]
const PURCHASE_COLS: Array[String] = ["run", "tier", "deadline", "item", "money_before", "money_after", "rerolls", "seconds"]


## Lit un texte JSONL ; les lignes illisibles sont ignorées. `run` étiquette chaque objet.
static func parse_jsonl(text: String, run: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line: String in text.split("\n", false):
		var json: JSON = JSON.new()
		if json.parse(line) != OK or not (json.data is Dictionary):
			continue
		var d: Dictionary = json.data as Dictionary
		d["run"] = run
		out.append(d)
	return out


## Un run par ligne : début (personnage, graine…) et fin (victoire, palier…) réunis.
static func runs(records: Array[Dictionary]) -> String:
	var by_run: Dictionary = {}
	var order: Array[String] = []
	for r: Dictionary in records:
		var t: String = String(r.get("t", ""))
		if t != "run_start" and t != "run_end":
			continue
		var id: String = String(r["run"])
		if not by_run.has(id):
			by_run[id] = {}
			order.append(id)
		(by_run[id] as Dictionary).merge(r, true)
	var rows: Array[Dictionary] = []
	for id: String in order:
		rows.append(by_run[id] as Dictionary)
	return table(rows, RUN_COLS)


static func of_kind(records: Array[Dictionary], kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in records:
		if String(r.get("t", "")) == kind:
			out.append(r)
	return out


## Une ligne par grigri acheté.
static func purchases(records: Array[Dictionary]) -> String:
	var rows: Array[Dictionary] = []
	for r: Dictionary in of_kind(records, "shop"):
		for item: Variant in r.get("bought", []):
			var row: Dictionary = r.duplicate()
			row["item"] = String(item)
			rows.append(row)
	return table(rows, PURCHASE_COLS)


static func table(rows: Array[Dictionary], cols: Array[String]) -> String:
	var lines: PackedStringArray = PackedStringArray([",".join(PackedStringArray(cols))])
	for r: Dictionary in rows:
		var cells: PackedStringArray = PackedStringArray()
		for c: String in cols:
			cells.append(cell(r.get(c, "")))
		lines.append(",".join(cells))
	return "\n".join(lines) + "\n"


static func _nested(a: Array) -> bool:
	for x: Variant in a:
		if x is Dictionary or x is Array:
			return true
	return false


## Cellule CSV : listes jointes par « | », objets en JSON, guillemets si besoin.
static func cell(v: Variant) -> String:
	var s: String = ""
	if v is Array and _nested(v as Array):
		s = JSON.stringify(v)
	elif v is Array:
		var parts: PackedStringArray = PackedStringArray()
		for x: Variant in v:
			parts.append(str(x))
		s = "|".join(parts)
	elif v is Dictionary:
		s = JSON.stringify(v)
	elif v is bool:
		s = "1" if v else "0"
	elif v is float:
		var f: float = v
		s = str(int(f)) if f == floorf(f) and absf(f) < 1e15 else str(snappedf(f, 0.0001))
	else:
		s = str(v)
	if s.contains(",") or s.contains("\"") or s.contains("\n"):
		s = "\"" + s.replace("\"", "\"\"") + "\""
	return s
