class_name DevUiCheck
extends Node
## Contrôle d'interface sans écran : chaque écran et chaque surcouche est ouvert à plusieurs
## tailles de fenêtre logique (16:9, 16:10 Steam Deck, texte agrandi) et doit :
##  - donner le focus à un contrôle (navigation manette possible dès l'ouverture) ;
##  - garder tous ses boutons dans la fenêtre (hors zones défilantes).
## Usage : godot --headless --path . -- --dev-ui-check
## Code de sortie 1 au moindre défaut.

## [taille logique, taille du texte] : 16:9, Steam Deck (16:10), petite fenêtre, Steam Deck texte max.
const CONFIGS: Array[Array] = [
	[Vector2i(1920, 1080), 1.0],
	[Vector2i(1280, 800), 1.0],
	[Vector2i(1920, 1200), 1.0],
	[Vector2i(1600, 900), 1.0],
	[Vector2i(2560, 1080), 1.0],
	[Vector2i(1920, 1200), 1.3],
]
## Téléphone (`--dev-mobile`) : zone sûre logique (hauteur 1080 sur les écrans allongés), texte
## agrandi : Pixel 7 (20:9 moins le poinçon), 19,5:9, pliable ouvert (≈ 6:5), tablette 16:10.
const CONFIGS_MOBILE: Array[Array] = [
	[Vector2i(2290, 1080), 1.35],
	[Vector2i(2240, 1080), 1.6],
	[Vector2i(2290, 1080), 1.6],
	[Vector2i(1920, 1600), 1.35],
	[Vector2i(1920, 1200), 1.35],
	[Vector2i(1920, 1080), 1.6],
]
## Téléphone : plus petite cible tactile (px logiques ≈ px physiques à 1080 de haut ; 88 ≈ 5,3 mm).
const TOUCH_MIN_PX: float = 88.0
## Téléphone : plus petit texte (px logiques ramenés à un écran de 1080 px de haut).
const PHONE_MIN_PX: float = 20.0
## Chevauchement toléré entre deux éléments (px) : bords qui se touchent, ombres.
const OVERLAP_TOLERANCE: float = 3.0
## Lisibilité Steam Deck : taille minimale d'un texte rendu en 1280×800 (critère Valve : 9 px).
const DECK_MIN_PX: float = 9.0
const DECK_HEIGHT: float = 800.0
const SETTLE_FRAMES: int = 6
const EDGE_TOLERANCE: float = 2.0
## Écrans pilotés à la manette sans focus d'interface (curseur du tapis, cf. RunScreen._gamepad_table) :
## donner le focus à un bouton y ferait déclencher « LANCER » par la touche A (miser).
const NO_FOCUS_OK: Array[StringName] = [&"run", &"intro"]

var problems: Array[String] = []
var checked: int = 0


var root: Window = null
var frame: Control = null


func _ready() -> void:
	root = get_tree().root
	frame = Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_run.call_deferred()


func _run() -> void:
	var db: ContentDB = ContentDB.shared()
	Settings.set_value("game", "input_mode", "gamepad")
	InputGlyphs.apply_mode()
	for cfg: Array in (CONFIGS_MOBILE if Platform.is_mobile() else CONFIGS):
		var sz: Vector2i = cfg[0]
		Settings.set_value("access", "text_scale", float(cfg[1]))
		UiKit.clear_cache()
		root.size = sz
		root.content_scale_size = sz
		UiLayout.fit_frame(frame, Vector2(sz))
		for screen_id: StringName in Main.SCREENS.keys():
			_prepare_run(db)
			var packed: PackedScene = load(Main.SCREENS[screen_id]) as PackedScene
			var node: Control = packed.instantiate() as Control
			if node.has_method("setup"):
				node.call("setup", {"victory": false})
			await _check(node, "%s @%dx%d×%.1f" % [screen_id, sz.x, sz.y, float(cfg[1])], not NO_FOCUS_OK.has(screen_id))
		# États de l'écran de run qui changent la rangée d'actions.
		for st: RunScreen.UiState in [RunScreen.UiState.RETHROW, RunScreen.UiState.TARGETING]:
			_prepare_run(db)
			var rs: RunScreen = (load(Main.SCREENS[&"run"]) as PackedScene).instantiate() as RunScreen
			await _check(rs, "run/%s @%dx%d×%.1f" % [RunScreen.UiState.keys()[st], sz.x, sz.y, float(cfg[1])], false, rs._set_state.bind(st))
		for o: Array in _overlays(db):
			var ov: Control = o[1] as Control
			var prep_o: Callable = (o[2] as Callable).bind(ov) if o.size() > 2 else Callable()
			await _check(ov, "%s @%dx%d×%.1f" % [o[0], sz.x, sz.y, float(cfg[1])], true, prep_o)
	Settings.set_value("access", "text_scale", 1.0)
	Settings.set_value("game", "input_mode", "auto")
	for p: String in problems:
		printerr("UI : " + p)
	print("Interface : %d vues contrôlées, %d problème(s)" % [checked, problems.size()])
	_cleanup()
	get_tree().quit(1 if not problems.is_empty() else 0)


func _prepare_run(db: ContentDB) -> void:
	var gs: Node = GameState
	var ctl: RunController = RunController.new(db)
	ctl.new_run("lea", 0, 1234)
	ctl.run.flags["act_intro_seen_1"] = true
	gs.set("controller", ctl)


func _overlays(db: ContentDB) -> Array[Array]:
	var ctl: RunController = RunController.new(db)
	ctl.new_run("lea", 0, 99)
	ctl.run.money = 30
	ShopModel.enter(ctl.run, db)
	GameState.controller = ctl
	var out: Array[Array] = [
		["shop", ShopOverlay.new().configure(ctl)],
		["pause", PauseMenu.new()],
		["quick_settings", QuickSettings.new()],
		["confirm", ConfirmBox.new().configure("?")],
		["note", NoteOverlay.new().configure(Image.create(8, 8, false, Image.FORMAT_RGB8), "run")],
		["soundboard", SoundboardOverlay.new()],
		["reward", RewardOverlay.new().configure(ctl.compute_reward(), false)],
	]
	var pact_ctl: RunController = RunController.new(db)
	pact_ctl.new_run("lea", 0, 7)
	out.append(["pact", PactOverlay.new().configure(pact_ctl)])
	var ev_ctl: RunController = RunController.new(db)
	ev_ctl.new_run("lea", 0, 8)
	ev_ctl.run.pending_event_id = db.ids("events")[0]
	out.append(["event", EventOverlay.new().configure(ev_ctl)])
	for kind: String in ["pocket", "fortune", "occult"]:
		var pk: RunController = RunController.new(db)
		pk.new_run("lea", 0, 21)
		pk.run.money = 50
		ShopModel.enter(pk.run, db)
		pk.run.shop_state["open_pack"] = {"kind": kind, "choices": ShopModel.roll_pack_choices(pk.run, db, kind)}
		out.append(["shop/pack_" + kind, ShopOverlay.new().configure(pk)])
	# Paquets vendus / indisponibles : le contrat et le reste doivent rester atteignables.
	for sold: Array in [[1], [0], [0, 1]]:
		var sc: RunController = RunController.new(db)
		sc.new_run("lea", 0, 22)
		sc.run.money = 3
		ShopModel.enter(sc.run, db)
		var packs: Array = sc.run.shop_state.get("packs", [])
		for k: Variant in sold:
			if int(k) < packs.size():
				(packs[int(k)] as Dictionary)["sold"] = true
		out.append(["shop/sold_" + "_".join(sold.map(func(v: Variant) -> String: return str(v))), ShopOverlay.new().configure(sc)])
	var dl_ctl: RunController = RunController.new(db)
	dl_ctl.new_run("lea", 0, 5)
	for did: String in ["act1_intro", "act2_intro", "finale"]:
		out.append(["dialogue/" + did, DialogueOverlay.new().configure(did, dl_ctl.run, db), _to_choice])
	var slot_spins: Array[Dictionary] = [{"reels": ["seven", "seven", "seven"], "prize": "p_seven3"}]
	out.append(["slot", SlotOverlay.new().configure(slot_spins, db), _slot_summary])
	out.append(["creditor_intro", CreditorIntro.new().configure(db.list("creditors")[0])])
	return out


## Fait défiler un dialogue jusqu'à son premier choix (ou sa fin).
func _to_choice(o: Control) -> void:
	for _i: int in 80:
		if bool(o.get("_waiting_choice")):
			return
		o.call("_advance")


func _slot_summary(o: Control) -> void:
	o.call("_show_summary")


func _check(node: Control, label: String, need_focus: bool = true, prep: Callable = Callable()) -> void:
	frame.add_child(node)
	for _i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	if prep.is_valid():
		prep.call()
		for _i: int in SETTLE_FRAMES:
			await get_tree().process_frame
	checked += 1
	var focus: Control = root.gui_get_focus_owner()
	if need_focus and (focus == null or not node.is_ancestor_of(focus)):
		problems.append("%s : aucun contrôle n'a le focus (manette inutilisable à l'ouverture)" % label)
	var view: Rect2 = Rect2(Vector2.ZERO, Vector2(root.size)).grow(EDGE_TOLERANCE)
	for b: Node in node.find_children("*", "BaseButton", true, false):
		var btn: BaseButton = b as BaseButton
		if not btn.is_visible_in_tree() or _in_scroll(btn, node):
			continue
		var r: Rect2 = btn.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, btn.size)
		if not view.encloses(r):
			problems.append("%s : bouton « %s » hors de l'écran %s" % [label, _name(btn), r])
	_check_fonts(node, label)
	_check_overlaps(node, label)
	if Platform.is_mobile():
		_check_touch_targets(node, label)
	if need_focus:
		await _check_reach(node, label)
	frame.remove_child(node)
	node.queue_free()
	await get_tree().process_frame


func _in_scroll(c: Node, stop: Node) -> bool:
	var p: Node = c.get_parent()
	while p != null and p != stop:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


func _name(b: Control) -> String:
	if b is GrigriCard:
		return "carte %s" % (b as GrigriCard).entry_id
	return (b as Button).text if b is Button and (b as Button).text != "" else String(b.name)


func _cleanup() -> void:
	GameState.controller = null
	UiKit.clear_cache()
	IconLibrary.clear_cache()


## Plus petit texte visible, ramené à l'écran du Steam Deck (la fenêtre logique la plus haute
## correspond à 800 px physiques).
func _check_fonts(node: Control, label: String) -> void:
	var to_deck: float = 1.0 if Platform.is_mobile() else DECK_HEIGHT / maxf(float(root.size.y), 1.0)
	var worst: float = 1e9
	var worst_name: String = ""
	for c: Node in node.find_children("*", "Control", true, false):
		var ctl: Control = c as Control
		if not ctl.is_visible_in_tree():
			continue
		var size_px: int = 0
		var txt: String = ""
		if ctl is Label:
			size_px = ctl.get_theme_font_size("font_size")
			txt = (ctl as Label).text
		elif ctl is Button:
			size_px = ctl.get_theme_font_size("font_size")
			txt = (ctl as Button).text
		elif ctl is RichTextLabel:
			size_px = ctl.get_theme_font_size("normal_font_size")
			txt = (ctl as RichTextLabel).get_parsed_text()
		if txt.strip_edges() == "" or size_px <= 0:
			continue
		var px: float = float(size_px) * ctl.get_global_transform_with_canvas().get_scale().y * to_deck
		if px < worst:
			worst = px
			worst_name = txt.substr(0, 24)
	var min_px: float = PHONE_MIN_PX if Platform.is_mobile() else DECK_MIN_PX
	if worst < min_px:
		var where: String = "sur téléphone" if Platform.is_mobile() else "sur Steam Deck"
		problems.append("%s : texte de %.1f px %s (« %s »), minimum %.0f px" % [label, worst, where, worst_name, min_px])


## Téléphone : chaque bouton actif doit offrir une cible assez grande pour le doigt.
## Sur téléphone, 1 px logique ≈ 1 px physique (≈ 0,06 mm) ; les pliables et tablettes, plus hauts
## en pixels logiques, sont aussi physiquement plus grands : pas de mise à l'échelle.
func _check_touch_targets(node: Control, label: String) -> void:
	var to_phone: float = 1.0
	var reported: int = 0
	for b: Node in node.find_children("*", "BaseButton", true, false):
		var btn: BaseButton = b as BaseButton
		if not btn.is_visible_in_tree() or btn.disabled or btn.modulate.a < 0.05:
			continue
		var sc: Vector2 = btn.get_global_transform_with_canvas().get_scale()
		var h: float = btn.size.y * sc.y * to_phone
		var w: float = btn.size.x * sc.x * to_phone
		if minf(w, h) < TOUCH_MIN_PX:
			problems.append("%s : cible tactile « %s » de %.0f×%.0f px (minimum %.0f)" % [label, _name(btn), w, h, TOUCH_MIN_PX])
			reported += 1
			if reported >= 4:
				return


## Éléments lisibles ou cliquables (boutons, textes, cartes) qui se recouvrent : le texte d'un
## choix de dialogue sous un autre bloc, un bouton sous un panneau, etc.
func _check_overlaps(node: Control, label: String) -> void:
	var items: Array[Control] = []
	for c: Node in node.find_children("*", "Control", true, false):
		var ctl: Control = c as Control
		if not ctl.is_visible_in_tree() or ctl.modulate.a < 0.05 or _in_scroll(ctl, node) or _floating(ctl, node):
			continue
		var is_text: bool = ctl is Label and (ctl as Label).text.strip_edges() != ""
		is_text = is_text or (ctl is RichTextLabel and (ctl as RichTextLabel).text != "")
		if ctl is BaseButton or is_text or ctl is GrigriCard:
			items.append(ctl)
	var rects: Array[Rect2] = []
	for ctl2: Control in items:
		rects.append(ctl2.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, ctl2.size))
	var reported: int = 0
	for i: int in items.size():
		for j: int in range(i + 1, items.size()):
			var a: Control = items[i]
			var b: Control = items[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			var inter: Rect2 = rects[i].intersection(rects[j])
			if inter.size.x > OVERLAP_TOLERANCE and inter.size.y > OVERLAP_TOLERANCE:
				problems.append("%s : « %s » chevauche « %s »" % [label, _desc(a), _desc(b)])
				reported += 1
				if reported >= 3:
					return


func _desc(c: Control) -> String:
	if c is Button and (c as Button).text != "":
		return (c as Button).text.substr(0, 24)
	if c is Label:
		return (c as Label).text.substr(0, 24)
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text().substr(0, 24)
	var sc: Script = c.get_script() as Script
	var cls: String = sc.get_global_name() if sc != null else c.get_class()
	return "%s %s (%s)" % [cls, String(c.name), c.get_parent().get_class() if c.get_parent() != null else ""]


## Tous les boutons actifs doivent être atteignables à la croix depuis le focus (onglets : LB/RB).
func _check_reach(node: Control, label: String) -> void:
	var tabs: Array[Node] = node.find_children("*", "TabContainer", true, false)
	var reached: Dictionary[Control, bool] = {}
	var starts: Array[Control] = []
	var focus: Control = root.gui_get_focus_owner()
	if focus != null and node.is_ancestor_of(focus):
		starts.append(focus)
	for t: Node in tabs:
		var tc: TabContainer = t as TabContainer
		for k: int in tc.get_tab_count():
			tc.current_tab = k
			await get_tree().process_frame
			await get_tree().process_frame
			var first: Control = PadNavigator.first_focusable(tc.get_current_tab_control())
			if first != null:
				_flood(first, reached)
		if focus != null and node.is_ancestor_of(focus):
			_flood(focus, reached)
	for st: Control in starts:
		_flood(st, reached)
	var missing: int = 0
	var targets: Array[Node] = node.find_children("*", "BaseButton", true, false)
	targets.append_array(node.find_children("*", "GrigriCard", true, false))
	for b: Node in targets:
		var btn: Control = b as Control
		var off: bool = btn is BaseButton and (btn as BaseButton).disabled
		if not btn.is_visible_in_tree() or off or btn.focus_mode == Control.FOCUS_NONE or reached.has(btn):
			continue
		if _in_tab_hidden(btn, node):
			continue
		problems.append("%s : bouton « %s » inaccessible à la manette" % [label, _name(btn)])
		missing += 1
		if missing >= 4:
			return


func _flood(start: Control, reached: Dictionary[Control, bool]) -> void:
	var todo: Array[Control] = [start]
	while not todo.is_empty():
		var c: Control = todo.pop_back()
		if reached.has(c):
			continue
		reached[c] = true
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			# Comme PadNavigator : un bouton désactivé est enjambé dans la même direction.
			var n: Control = c.find_valid_focus_neighbor(side)
			var hops: int = 0
			while n != null and n is BaseButton and (n as BaseButton).disabled and hops < 8:
				n = n.find_valid_focus_neighbor(side)
				hops += 1
			if n != null and not reached.has(n) and not (n is BaseButton and (n as BaseButton).disabled):
				todo.append(n)


func _in_tab_hidden(c: Node, stop: Node) -> bool:
	var p: Node = c.get_parent()
	while p != null and p != stop:
		if p is Control and not (p as Control).visible:
			return true
		p = p.get_parent()
	return false


## Infobulles et éléments flottants (top_level) : ils couvrent volontairement le contenu.
func _floating(c: Node, stop: Node) -> bool:
	var p: Node = c
	while p != null and p != stop:
		if p is CanvasItem and (p as CanvasItem).top_level:
			return true
		p = p.get_parent()
	return false
