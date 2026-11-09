extends SceneTree
## Validation du contenu data/ + compilation de tous les scripts.
## Vérifie : ids uniques, champs requis, déclencheurs/conditions/actions connus,
## références croisées (types de cases, éditions, sceaux, grigris), comptes cibles.
## Usage : godot --headless --path . -s res://tools/validate_data.gd

const REQUIRED_COMMON: Array[String] = ["id", "name_fr", "name_en", "desc_fr", "desc_en"]
const REQUIRED_BY_CAT: Dictionary = {
	"grigris": ["rarity", "tags", "family", "flavor_fr", "flavor_en", "icon", "sfx"],
	"families": ["color", "icon", "tiers"],
	"pocket_types": ["flavor_fr", "flavor_en", "icon"],
	"fortunes": ["flavor_fr", "flavor_en", "icon", "cost"],
	"contracts": ["cost", "flavor_fr", "flavor_en"],
	"creditors": ["tier_min", "tier_max"],
	"characters": [],
	"risks": ["level"],
	"slot_symbols": ["weight", "icon"],
	"slot_prizes": ["match", "symbol", "do"],
}
const RARITIES: Array[String] = ["common", "rare", "legendary", "cursed"]
## 2.0 (D-086) : chaque famille compte exactement FAMILY_SIZE grigris, paliers à FAMILY_TIERS.
const FAMILY_SIZE: int = 7
const FAMILY_TIERS: Array[int] = [2, 4, 7]
## Boutons possibles du pavé tactile des épreuves (cf. TouchPad.STYLE, qui dépend des autoloads).
const TOUCH_PAD_ACTIONS: Array[String] = ["qte_left", "qte_up", "qte_right", "qte_down", "ui_up", "ui_down", "ui_spin"]
## Dispositions du pavé tactile (cf. TouchPad.LAYOUTS ; recopiées : outil lancé sans autoloads).
const TOUCH_LAYOUTS: Array[String] = ["diamond", "row", "split"]
## Mots et repères qui supposent une souris (conseils du tutoriel).
const MOUSE_WORDS: Array[String] = [
	"{@click", "{@right_click", "{@double_click", "{@mouse", "{@wheel", "Clique", "clique", "Click", "click",
	"Survole", "survole", "Hover", "hover",
]
const SKIP_DESC: Array[String] = ["dialogues", "achievements", "challenges", "events", "speakers", "tutorial", "cutscenes"]

var errors: Array[String] = []
var warnings: Array[String] = []


func _initialize() -> void:
	_compile_scripts("res://scripts")
	_compile_scripts("res://tests")
	var db: ContentDB = ContentDB.new()
	db.load_all()
	errors.append_array(db.errors)
	for cat: String in ContentDB.CATEGORIES.keys():
		for e: Dictionary in db.list(cat):
			_validate_entry(db, cat, e)
	_validate_museum(db)
	for e: String in warnings:
		print("avertissement : " + e)
	for e: String in errors:
		printerr("ERREUR DONNÉES : " + e)
	var counts: PackedStringArray = []
	for cat: String in ContentDB.CATEGORIES.keys():
		counts.append("%s=%d" % [cat, db.count(cat)])
	print("Contenu : " + ", ".join(counts))
	print("Validation : %d erreur(s), %d avertissement(s)" % [errors.size(), warnings.size()])
	quit(1 if not errors.is_empty() else 0)


func _compile_scripts(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for f: String in dir.get_files():
		if f.ends_with(".gd"):
			var path: String = dir_path.path_join(f)
			var s: GDScript = load(path) as GDScript
			if s == null:
				errors.append("Script non compilable : %s" % path)
	for d: String in dir.get_directories():
		_compile_scripts(dir_path.path_join(d))


func _validate_entry(db: ContentDB, cat: String, e: Dictionary) -> void:
	var eid: String = "%s/%s" % [cat, String(e.get("id", "?"))]
	var required: Array[String] = []
	if not SKIP_DESC.has(cat):
		required.assign(REQUIRED_COMMON)
	else:
		required.assign(["id"])
	for k: Variant in REQUIRED_BY_CAT.get(cat, []):
		required.append(String(k))
	for k: String in required:
		if not e.has(k):
			errors.append("%s : champ requis absent '%s'" % [eid, k])
	if cat == "grigris" and e.has("visual"):
		var vis: Dictionary = e["visual"] if e["visual"] is Dictionary else {}
		if not VisualCurse.KINDS.has(String(vis.get("kind", ""))):
			errors.append("%s : effet visuel inconnu « %s »" % [eid, String(vis.get("kind", ""))])
		var st: float = float(vis.get("strength", -1.0))
		if st <= 0.0 or st > 1.0:
			errors.append("%s : intensité visuelle hors de ]0, 1]" % eid)
	if cat == "grigris" and not RARITIES.has(String(e.get("rarity", ""))):
		errors.append("%s : rareté invalide" % eid)
	if cat == "grigris" and not db.has_entry("families", String(e.get("family", ""))):
		errors.append("%s : famille inconnue « %s »" % [eid, String(e.get("family", ""))])
	if cat == "families":
		var members: int = 0
		for g: Dictionary in db.list("grigris"):
			if String(g.get("family", "")) == String(e["id"]):
				members += 1
		if members != FAMILY_SIZE:
			errors.append("%s : %d grigris (il en faut %d)" % [eid, members, FAMILY_SIZE])
		var ns: Array[int] = []
		for td2: Variant in e.get("tiers", []):
			ns.append(int((td2 as Dictionary).get("n", 0)))
		if ns != FAMILY_TIERS:
			errors.append("%s : paliers %s (attendu %s)" % [eid, str(ns), str(FAMILY_TIERS)])
		var last_n: int = 0
		for td: Variant in e.get("tiers", []):
			var tier: Dictionary = td as Dictionary
			if int(tier.get("n", 0)) <= last_n:
				errors.append("%s : paliers non croissants" % eid)
			last_n = int(tier.get("n", 0))
			if not tier.has("desc_fr") or not tier.has("desc_en"):
				errors.append("%s : palier sans desc_fr/desc_en" % eid)
			_validate_effects(db, eid + "/tier", tier.get("effects", []) as Array)
		if not ResourceLoader.exists("res://assets/families/%s.png" % String(e.get("icon", ""))):
			errors.append("%s : icône absente" % eid)
	_validate_effects(db, eid, e.get("effects", []) as Array)
	for ph: Variant in e.get("phases", []):
		_validate_effects(db, eid + "/phase", (ph as Dictionary).get("effects", []) as Array)
	for ch: Variant in e.get("choices", []):
		_validate_effects(db, eid + "/choice", (ch as Dictionary).get("effects", []) as Array)
		for cc: Variant in (ch as Dictionary).get("if", []):
			_validate_cond(eid + "/choice", cc as Dictionary)
		if not (ch as Dictionary).has("text_fr") or not (ch as Dictionary).has("text_en"):
			errors.append("%s : choix sans text_fr/text_en" % eid)
	for ln: Variant in e.get("lines", []):
		var who: String = String((ln as Dictionary).get("who", ""))
		if who != "hero" and not db.has_entry("speakers", who) and not db.has_entry("creditors", who):
			errors.append("%s : locuteur inconnu '%s'" % [eid, who])
		if not (ln as Dictionary).has("text_fr") or not (ln as Dictionary).has("text_en"):
			errors.append("%s : réplique sans text_fr/text_en" % eid)
		for ch2: Variant in (ln as Dictionary).get("choices", []):
			_validate_effects(db, eid + "/line_choice", (ch2 as Dictionary).get("effects", []) as Array)
	var setup: Dictionary = e.get("setup", {})
	for gid: Variant in setup.get("grigris", []):
		if not db.has_entry("grigris", String(gid)):
			errors.append("%s : grigri de départ inconnu '%s'" % [eid, gid])
	for wop: Variant in setup.get("wheel", []):
		var t: String = String((wop as Dictionary).get("type", ""))
		if t != "" and not db.has_entry("pocket_types", t):
			errors.append("%s : type de case inconnu '%s'" % [eid, t])
	if cat == "slot_symbols" and float(e.get("weight", 0)) <= 0.0:
		errors.append("%s : poids nul" % eid)
	if cat == "slot_prizes":
		if not String(e.get("match", "")) in ["quad", "triple", "pair"]:
			errors.append("%s : combinaison inconnue" % eid)
		if not db.has_entry("slot_symbols", String(e.get("symbol", ""))):
			errors.append("%s : symbole inconnu" % eid)
		_validate_effects(db, eid, [{"trigger": "on_jackpot", "do": e.get("do", [])}])
	if cat == "cutscenes":
		for lay: Variant in e.get("layers", []):
			var img: String = "res://assets/cutscene/%s.png" % String((lay as Dictionary).get("img", ""))
			if not ResourceLoader.exists(img):
				errors.append("%s : calque absent %s" % [eid, img])
		for cap: Variant in e.get("captions", []):
			var c: Dictionary = cap as Dictionary
			if not c.has("text_fr") or not c.has("text_en"):
				errors.append("%s : légende sans text_fr/text_en" % eid)
			var who: String = String(c.get("who", ""))
			if who != "hero" and not db.has_entry("speakers", who):
				errors.append("%s : locuteur inconnu '%s'" % [eid, who])
	if cat == "tutorial":
		# Téléphone : un conseil qui parle de souris (clic, survol, molette) a sa variante tactile.
		for lang: String in ["fr", "en"]:
			var txt: String = String(e.get("text_" + lang, ""))
			var mouse_talk: bool = false
			for w: String in MOUSE_WORDS:
				mouse_talk = mouse_talk or txt.contains(w)
			if mouse_talk and String(e.get("text_touch_" + lang, "")) == "":
				errors.append("%s : texte souris sans variante tactile (text_touch_%s)" % [eid, lang])
	if cat == "throw_trials":
		if not String(e.get("stage", "")) in ["panel", "full"]:
			errors.append("%s : stage doit valoir panel ou full" % eid)
		if not ResourceLoader.exists("res://scripts/presentation/trials/trial_%s.gd" % String(e.get("id", ""))):
			errors.append("%s : script d'épreuve absent" % eid)
		# Tactile : boutons du pavé (TouchPad), sinon l'épreuve se joue au pointeur.
		for a: Variant in e.get("touch_pad", []):
			if not TOUCH_PAD_ACTIONS.has(String(a)) or not InputMap.has_action(StringName(String(a))):
				errors.append("%s : touch_pad « %s » inconnu" % [eid, a])
		# 1.9 : jeu direct au doigt — l'épreuve doit traduire le toucher, et n'a pas de pavé.
		if bool(e.get("touch_direct", false)):
			var src: String = FileAccess.get_file_as_string("res://scripts/presentation/trials/trial_%s.gd" % String(e.get("id", "")))
			if not src.contains("func tap_action") and not src.contains("func direct_input"):
				errors.append("%s : touch_direct sans tap_action ni direct_input" % eid)
			if e.has("touch_pad") or e.has("touch_stick"):
				errors.append("%s : touch_direct et pavé émulé à la fois" % eid)
		# 2.0 : positions des Échecs éclair — chacune a exactement un mat, celui des données.
		for pz: Variant in e.get("puzzles", []):
			var pd: Dictionary = pz as Dictionary
			var mates: Array[Vector2i] = ChessMini.from_fen(String(pd.get("fen", ""))).mating_moves()
			if mates.size() != 1 or mates[0] != ChessMini.parse_uci(String(pd.get("solution", ""))):
				errors.append("%s : position « %s » sans mat unique conforme" % [eid, String(pd.get("fen", ""))])
		# 1.9 : tuto de première rencontre, 2 à 4 étapes par langue.
		for lang: String in ["fr", "en"]:
			var steps: Array = e.get("tuto_" + lang, []) as Array
			if steps.size() < 2 or steps.size() > 4:
				errors.append("%s : tuto_%s doit compter 2 à 4 étapes" % [eid, lang])
			for st: Variant in steps:
				if String(st).strip_edges() == "":
					errors.append("%s : étape vide dans tuto_%s" % [eid, lang])
		if not Balance.data().get("throw_trials", {}).has(String(e.get("id", ""))):
			errors.append("%s : réglages absents de balance.json (throw_trials)" % eid)
		if e.has("touch_layout") and not TOUCH_LAYOUTS.has(String(e["touch_layout"])):
			errors.append("%s : touch_layout doit valoir %s" % [eid, ", ".join(TOUCH_LAYOUTS)])
		var split_n: int = (e.get("touch_pad", []) as Array).size()
		if String(e.get("touch_layout", "")) == "split" and (split_n < 2 or split_n > 3):
			errors.append("%s : la disposition split demande deux ou trois boutons" % eid)
		for la: Variant in (e.get("touch_labels", {}) as Dictionary).keys():
			if not (e.get("touch_pad", []) as Array).has(la):
				errors.append("%s : touch_labels « %s » hors du pavé" % [eid, la])
		if e.has("touch_stick") and typeof(e["touch_stick"]) != TYPE_BOOL:
			errors.append("%s : touch_stick doit être un booléen" % eid)
		if float(e.get("weight", 0)) <= 0.0:
			errors.append("%s : poids nul" % eid)
	if cat == "contracts" and String(e.get("requires", "")) != "" and not db.has_entry("contracts", String(e["requires"])):
		errors.append("%s : prérequis inconnu" % eid)


func _validate_effects(db: ContentDB, eid: String, effects: Array) -> void:
	for eff_v: Variant in effects:
		if not (eff_v is Dictionary):
			errors.append("%s : effet non objet" % eid)
			continue
		var eff: Dictionary = eff_v as Dictionary
		var trig: StringName = StringName(String(eff.get("trigger", "")))
		if not EffectRunner.TRIGGERS.has(trig):
			errors.append("%s : déclencheur inconnu '%s'" % [eid, trig])
		for c: Variant in eff.get("if", []):
			_validate_cond(eid, c as Dictionary)
		for a: Variant in eff.get("do", []):
			var ad: Dictionary = a as Dictionary
			var op: StringName = StringName(String(ad.get("op", "")))
			if not EffectRunner.OPS.has(op):
				errors.append("%s : action inconnue '%s'" % [eid, op])
			_validate_value(eid, ad.get("v", 0))
			if (
				ad.has("type")
				and op in [&"transform_pocket", &"burn_random_pocket"]
				and not db.has_entry("pocket_types", String(ad["type"]))
			):
				errors.append("%s : type de case inconnu '%s'" % [eid, ad["type"]])
			if ad.has("edition") and String(ad["edition"]) != "" and not db.has_entry("editions", String(ad["edition"])):
				errors.append("%s : édition inconnue '%s'" % [eid, ad["edition"]])
			if ad.has("seal") and not db.has_entry("seals", String(ad["seal"])):
				errors.append("%s : sceau inconnu '%s'" % [eid, ad["seal"]])
			if op == &"add_grigri" and String(ad.get("id", "")) != "" and not db.has_entry("grigris", String(ad["id"])):
				errors.append("%s : grigri inconnu '%s'" % [eid, ad["id"]])
			if op == &"add_fortune" and String(ad.get("id", "random")) != "random" and not db.has_entry("fortunes", String(ad["id"])):
				errors.append("%s : fortune inconnue '%s'" % [eid, ad["id"]])


func _validate_cond(eid: String, c: Dictionary) -> void:
	var n: StringName = StringName(String(c.get("c", "")))
	if n == &"not":
		_validate_cond(eid, c.get("x", {}) as Dictionary)
		return
	if n == &"any":
		for sub: Variant in c.get("x", []):
			_validate_cond(eid, sub as Dictionary)
		return
	if not EffectRunner.PREDICATES.has(n) and not EffectRunner.VARIABLES.has(n):
		errors.append("%s : condition inconnue '%s'" % [eid, n])
	_validate_value(eid, c.get("v", 0))


func _validate_value(eid: String, v: Variant) -> void:
	if v is Dictionary:
		var vn: StringName = StringName(String((v as Dictionary).get("var", "")))
		if not EffectRunner.VARIABLES.has(vn):
			errors.append("%s : variable inconnue '%s'" % [eid, vn])


## Musée : chaque épreuve exposée dans exactement une salle, couleurs lisibles.
func _validate_museum(db: ContentDB) -> void:
	var count: Dictionary[String, int] = {}
	for r: Dictionary in db.list("museum_rooms"):
		var rid: String = "museum_rooms/%s" % String(r.get("id", "?"))
		for k: String in ["wall", "floor", "accent"]:
			if not Color.html_is_valid(String(r.get(k, ""))):
				errors.append("%s : couleur %s invalide" % [rid, k])
		var ex: Array = r.get("exhibits", []) as Array
		if ex.is_empty():
			errors.append("%s : salle vide" % rid)
		for t: Variant in ex:
			if db.get_entry("throw_trials", String(t)).is_empty():
				errors.append("%s : épreuve inconnue « %s »" % [rid, t])
			count[String(t)] = int(count.get(String(t), 0)) + 1
	for e: Dictionary in db.list("throw_trials"):
		var n: int = int(count.get(String(e.get("id", "")), 0))
		if n != 1:
			errors.append("throw_trials/%s : exposée %d fois au Musée (1 attendue)" % [String(e.get("id", "")), n])
