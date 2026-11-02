class_name ShopOverlay
extends Overlay
## Boutique : 3 grigris, 2 paquets, 1 contrat, reroll, vente, probabilités affichées.

const FLIP_TIME: float = 0.25
const FLIP_STAGGER: float = 0.08
const DISSOLVE_SHADER: String = "res://shaders/dissolve.gdshader"
const DISSOLVE_TIME: float = 0.7
const OWNED_PROMPTS_W: float = 1100.0
const PACK_BTN: Vector2 = Vector2(210, 150)
const PACK_DESC_W: float = 210.0
const OWNED_KEYS: Array[Array] = [["@double_click", "HINT_K_SELL"], ["@drag", "HINT_K_MOVE"], ["@right_click", "HINT_K_LOCK"]]
const OWNED_PAD: Array[Array] = [
	["@dpad", "HINT_K_SELECT"], ["ui_accept", "HINT_K_BUY_SELL"], ["bet_repeat", "HINT_K_LOCK"], ["bet_cycle_prev", "HINT_K_MOVE"]
]

var ctl: RunController = null
var _money: Label = null
var _offers_row: HBoxContainer = null
var _packs_row: HBoxContainer = null
var _odds: Label = null
var _reroll_btn: Button = null
var _owned: GrigriBar = null
var _pack_box: VBoxContainer = null
var _pack_layer: Control = null
var _pack_panel: PanelContainer = null
var _float: FloatLayer = null
var _rerolls_here: int = 0
var _owned_prompts: PromptBar = null
var _owned_title: Label = null
var _contract_row: HBoxContainer = null


func configure(p_ctl: RunController) -> ShopOverlay:
	ctl = p_ctl
	panel_width = 1560.0
	return self


func build() -> void:
	# En-tête : nom du Bazar, bourse.
	var head: HBoxContainer = row()
	head.add_theme_constant_override("separation", 40)
	head.add_child(UiKit.title(tr("SHOP_TITLE"), UiKit.SIZE_H1))
	var purse: PanelContainer = PanelContainer.new()
	purse.add_theme_stylebox_override("panel", UiKit.flat(Palette.INK, Palette.GOLD, 2, 20, 10))
	_money = UiKit.label("", UiKit.SIZE_H1, Palette.GOLD_LIGHT, "mono")
	purse.add_child(_money)
	head.add_child(purse)
	body.add_child(UiKit.divider(panel_width * 0.7))
	_odds = UiKit.label("", UiKit.SIZE_SMALL, Palette.IVORY.darkened(0.2))
	_odds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_odds)
	# Étal : trois cartes de section.
	var mid: HBoxContainer = row()
	mid.add_theme_constant_override("separation", 28)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	var gcard: PanelContainer = UiKit.section_card(tr("SHOP_GRIGRIS"), 0.0, Palette.GOLD)
	_offers_row = HBoxContainer.new()
	_offers_row.add_theme_constant_override("separation", 18)
	(gcard.get_meta("body") as VBoxContainer).add_child(_offers_row)
	mid.add_child(gcard)
	var pcard: PanelContainer = UiKit.section_card(tr("SHOP_PACKS"))
	_packs_row = HBoxContainer.new()
	_packs_row.add_theme_constant_override("separation", 14)
	(pcard.get_meta("body") as VBoxContainer).add_child(_packs_row)
	mid.add_child(pcard)
	var ccard: PanelContainer = UiKit.section_card(tr("SHOP_CONTRACT"), 0.0, Palette.MAGENTA.darkened(0.3))
	_contract_row = HBoxContainer.new()
	(ccard.get_meta("body") as VBoxContainer).add_child(_contract_row)
	mid.add_child(ccard)
	# Paquet ouvert : fenêtre dédiée au-dessus du Bazar (masqué pendant le choix, obligatoire).
	_pack_layer = Control.new()
	_pack_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pack_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_pack_layer.visible = false
	add_child(_pack_layer)
	var pack_center: CenterContainer = CenterContainer.new()
	pack_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pack_layer.add_child(pack_center)
	_pack_panel = UiKit.panel(Palette.VELVET_DEEP, Palette.CYAN)
	pack_center.add_child(_pack_panel)
	_pack_box = VBoxContainer.new()
	_pack_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_pack_box.add_theme_constant_override("separation", 12)
	_pack_panel.add_child(_pack_box)
	# Collection du joueur.
	var ocard: PanelContainer = UiKit.section_card("")
	ocard.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var obody: VBoxContainer = ocard.get_meta("body") as VBoxContainer
	_owned_title = UiKit.label("", UiKit.SIZE_SMALL, Palette.GOLD, "display")
	obody.add_child(_owned_title)
	_owned = GrigriBar.new()
	_owned.shop_mode = true
	_owned.sell_requested.connect(_on_sell)
	obody.add_child(_owned)
	_owned_prompts = PromptBar.new()
	_owned_prompts.custom_minimum_size = Vector2(OWNED_PROMPTS_W, InputGlyphs.PROMPT_H + 4)
	_owned_prompts.alignment = BoxContainer.ALIGNMENT_CENTER
	obody.add_child(_owned_prompts)
	_owned_prompts.set_device_items.call_deferred(OWNED_KEYS, OWNED_PAD)
	body.add_child(ocard)
	# Actions.
	var actions: HBoxContainer = row()
	actions.add_theme_constant_override("separation", 24)
	_reroll_btn = UiKit.button("", _on_reroll, Vector2(300, 60))
	actions.add_child(_reroll_btn)
	var leave: Button = UiKit.button(tr("SHOP_LEAVE"), close, Vector2(300, 60))
	actions.add_child(leave)
	PromptBadge.attach(leave, "pause_menu")
	_focus_first_offer.call_deferred()
	_float = FloatLayer.new()
	add_child(_float)
	_refresh(true)


func _focus_pack() -> void:
	var f: Control = PadNavigator.first_focusable(_pack_box)
	if f != null:
		f.grab_focus()


func _focus_first_offer() -> void:
	if not InputGlyphs.using_pad:
		return
	var f: Control = PadNavigator.first_focusable(_offers_row)
	if f == null:
		f = PadNavigator.first_focusable(body)
	if f != null:
		f.grab_focus()


## Menu (Start) / Échap : retour à la table.
func _unhandled_input(event: InputEvent) -> void:
	if GameInput.pressed(event, "pause_menu") and (_pack_box.get_child_count() == 0):
		close()
		get_viewport().set_input_as_handled()


func _refresh(animate: bool = false) -> void:
	var r: RunState = ctl.run
	var focused: Control = get_viewport().gui_get_focus_owner()
	var refocus: Array = _focus_path(focused)
	_money.text = "%d $" % r.money
	var probs: Dictionary = ShopModel.rarity_probabilities(r)
	var parts: PackedStringArray = []
	for k: String in ShopModel.RARITIES:
		if float(probs[k]) > 0.0:
			parts.append("%s %.0f %%" % [tr("RARITY_" + k.to_upper()), float(probs[k]) * 100.0])
	_odds.text = tr("SHOP_ODDS") % " · ".join(parts)
	for c: Node in _offers_row.get_children():
		c.queue_free()
	var offers: Array = r.shop_state.get("grigris", [])
	for i: int in offers.size():
		var o: Dictionary = offers[i]
		var card: GrigriCard = GrigriCard.new().configure("grigri", String(o["id"]), i)
		card.edition = StringName(String(o.get("edition", "")))
		card.price = int(o["price"])
		card.draggable = false
		card.disabled_look = bool(o["sold"])
		card.activated.connect(_on_buy_grigri)
		_offers_row.add_child(card)
		SaveSystem.mark_seen("grigris", String(o["id"]))
		if animate:
			_flip_in(card, i)
	for c2: Node in _packs_row.get_children():
		c2.queue_free()
	var packs: Array = r.shop_state.get("packs", [])
	for j: int in packs.size():
		var pk: Dictionary = packs[j]
		var kind_key: String = "PACK_" + String(pk["kind"]).to_upper()
		var col: VBoxContainer = VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		var b: Button = UiKit.button(tr(kind_key) + "\n%d $" % int(pk["price"]), _on_buy_pack.bind(j), PACK_BTN)
		b.disabled = bool(pk["sold"]) or not (r.shop_state.get("open_pack", {}) as Dictionary).is_empty()
		col.add_child(b)
		var desc: Label = UiKit.label(tr(kind_key + "_DESC"), UiKit.SIZE_SMALL, Palette.IVORY.darkened(0.15))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(PACK_DESC_W, 0)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(desc)
		_packs_row.add_child(col)
	for c3: Node in _contract_row.get_children():
		c3.queue_free()
	var contracts: Array = r.shop_state.get("contracts", [])
	for k2: int in contracts.size():
		var co: Dictionary = contracts[k2]
		var cc: GrigriCard = GrigriCard.new().configure("contract", String(co["id"]), k2)
		cc.price = int(co["price"])
		cc.disabled_look = bool(co["sold"])
		cc.draggable = false
		cc.activated.connect(_on_buy_contract)
		_contract_row.add_child(cc)
	_reroll_btn.text = tr("SHOP_REROLL") % int(r.shop_state.get("reroll_cost", 0))
	_reroll_btn.disabled = r.money < int(r.shop_state.get("reroll_cost", 0))
	_owned.bind(r)
	_owned_title.text = tr("SHOP_OWNED").to_upper() + "  %d / %d" % [r.grigris.size(), r.grigri_slots]
	_refresh_pack()
	if not refocus.is_empty():
		_restore_focus.call_deferred(refocus)


## Où était le focus (rangée, index) pour le retrouver après reconstruction des cartes.
func _focus_path(c: Control) -> Array:
	for row_node: Control in [_offers_row, _packs_row, _contract_row, _owned]:
		if c != null and row_node.is_ancestor_of(c):
			return [row_node, c.get_index()]
	return []


func _restore_focus(path: Array) -> void:
	var row_node: Control = path[0] as Control
	var kids: Array[Node] = row_node.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	var idx: int = mini(int(path[1]), kids.size() - 1)
	for k: int in range(idx, -1, -1):
		var node_c: Control = kids[k] as Control
		if node_c != null and node_c.focus_mode == Control.FOCUS_ALL and not (node_c is BaseButton and (node_c as BaseButton).disabled):
			node_c.grab_focus()
			return
	_focus_first_offer()


func _flip_in(card: Control, i: int) -> void:
	card.scale = Vector2(0.0, 1.0)
	var tw: Tween = card.create_tween()
	tw.tween_interval(FLIP_STAGGER * float(i) / maxf(Settings.speed(), 1.0))
	tw.tween_callback(AudioBus.play.bind("card_flip"))
	tw.tween_property(card, "scale", Vector2.ONE, FLIP_TIME / maxf(Settings.speed(), 1.0)).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)


func _feedback(res: ShopModel.BuyResult, at: Vector2) -> bool:
	match res:
		ShopModel.BuyResult.OK:
			AudioBus.play("buy")
			_float.burst("coins", at, 12)
			return true
		ShopModel.BuyResult.NO_MONEY:
			EventBus.toast.emit(tr("SHOP_NO_MONEY"), &"error")
		ShopModel.BuyResult.NO_SLOT:
			EventBus.toast.emit(tr("SHOP_NO_SLOT"), &"error")
	AudioBus.ui("error")
	return false


func _on_buy_grigri(card: GrigriCard) -> void:
	var pos: Vector2 = UiLayout.canvas_point(card, card.size * 0.5)
	if _feedback(ShopModel.buy_grigri(ctl.run, ctl.db, card.uid), pos):
		SaveSystem.mark_seen("grigris", card.entry_id)
		GameState.record_shop("buy", {"rarity": card.rarity(), "id": card.entry_id})
		_refresh()
		GameState.autosave()


func _on_buy_contract(card: GrigriCard) -> void:
	var pos: Vector2 = UiLayout.canvas_point(card, card.size * 0.5)
	if _feedback(ShopModel.buy_contract(ctl.run, ctl.db, card.uid), pos):
		SaveSystem.mark_seen("contracts", card.entry_id)
		_refresh()
		GameState.autosave()


func _on_buy_pack(i: int) -> void:
	if _feedback(ShopModel.buy_pack(ctl.run, ctl.db, i), UiLayout.canvas_point(_packs_row, _packs_row.size * 0.5)):
		AudioBus.play("pack_open")
		_refresh()


func _on_reroll() -> void:
	Telemetry.shop_rerolling(ctl.run)
	if ShopModel.reroll(ctl.run, ctl.db):
		Telemetry.shop_rerolled(ctl.run)
		AudioBus.play("reroll")
		_rerolls_here += 1
		GameState.record_shop("reroll", {"rerolls_here": _rerolls_here})
		_refresh(true)
		GameState.autosave()


func _on_sell(g_uid: int) -> void:
	var g: GrigriInstance = ctl.run.grigri_by_uid(g_uid)
	if g == null:
		return
	if g.locked:
		EventBus.toast.emit(tr("SHOP_LOCKED"), &"error")
		return
	var pos: Vector2 = _owned.card_center(g_uid)
	if Settings.b("game", "confirm_irreversible"):
		var dlg: ConfirmBox = ConfirmBox.new().configure(
			tr("CONFIRM_SELL") % [Localization.name_of("grigris", g.id), ShopModel.sell_value(ctl.run, ctl.db, g)]
		)
		dlg.confirmed.connect(_do_sell.bind(g_uid, pos))
		add_child(dlg)
	else:
		_do_sell(g_uid, pos)


func _do_sell(g_uid: int, pos: Vector2) -> void:
	var ghost_id: String = ctl.run.grigri_by_uid(g_uid).id if ctl.run.grigri_by_uid(g_uid) != null else ""
	var got: int = ShopModel.sell_grigri(ctl.run, ctl.db, g_uid)
	if got > 0:
		_dissolve_card(ghost_id, pos)
		AudioBus.play("sell")
		_float.burst("coins", pos, 26)
		_float.pop_text("+%d $" % got, pos, Palette.GOLD_LIGHT)
		_refresh()
		GameState.autosave()


## Carte fantôme qui se consume en braises à l'endroit de la vente.
func _dissolve_card(gid: String, center: Vector2) -> void:
	if gid == "" or JuiceProfile.intensity() <= 0.0:
		return
	var card: GrigriCard = GrigriCard.new().configure("grigri", gid)
	card.draggable = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(DISSOLVE_SHADER) as Shader
	card.material = m
	add_child(card)
	card.top_level = true
	card.position = center - GrigriCard.CARD_SIZE * 0.5
	var tw: Tween = card.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("progress", v), 0.0, 1.0, DISSOLVE_TIME / maxf(Settings.speed(), 1.0))
	tw.tween_callback(card.queue_free)


# --------------------------------------------------------------------------- paquet ouvert


func _refresh_pack() -> void:
	for c: Node in _pack_box.get_children():
		c.queue_free()
	var pack: Dictionary = ctl.run.shop_state.get("open_pack", {})
	_pack_layer.visible = not pack.is_empty()
	panel.visible = pack.is_empty()
	if pack.is_empty():
		return
	_focus_pack.call_deferred()
	var kind: String = String(pack["kind"])
	_pack_box.add_child(UiKit.label(tr("PACK_CHOOSE") % tr("PACK_" + kind.to_upper()), UiKit.SIZE_H2, Palette.CYAN, "display"))
	var h: HBoxContainer = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 24)
	_pack_box.add_child(h)
	var choices: Array = pack.get("choices", [])
	for i: int in choices.size():
		var c2: Dictionary = choices[i]
		var col: VBoxContainer = VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(col)
		match kind:
			"pocket":
				var card: GrigriCard = GrigriCard.new().configure("pocket_card", String(c2["type"]), i)
				card.edition = StringName(String(c2.get("edition", "")))
				card.draggable = false
				card.activated.connect(func(_c: GrigriCard) -> void: _choose(i, "add"))
				col.add_child(card)
				var extra: String = "n° %d" % int(c2["number"])
				if String(c2.get("seal", "")) != "":
					extra += " · " + Localization.name_of("seals", String(c2["seal"]))
				col.add_child(UiKit.label(extra, UiKit.SIZE_SMALL, Palette.IVORY))
				col.add_child(UiKit.button(tr("PACK_ADD"), _choose.bind(i, "add"), Vector2(150, 44)))
				col.add_child(UiKit.button(tr("PACK_REPLACE"), _choose.bind(i, "replace"), Vector2(150, 44)))
			"fortune":
				var fc: GrigriCard = GrigriCard.new().configure("fortune", String(c2["fortune"]), i)
				fc.draggable = false
				fc.activated.connect(func(_c: GrigriCard) -> void: _choose(i, "add"))
				col.add_child(fc)
				col.add_child(UiKit.button(tr("PACK_TAKE"), _choose.bind(i, "add"), Vector2(150, 44)))
			"occult":
				var oc: GrigriCard = GrigriCard.new().configure("grigri", String(c2["grigri"]), i)
				oc.draggable = false
				oc.activated.connect(func(_c: GrigriCard) -> void: _choose(i, "add"))
				col.add_child(oc)
				col.add_child(UiKit.button(tr("PACK_TAKE"), _choose.bind(i, "add"), Vector2(150, 44)))
		_flip_in(col, i)
	_pack_box.add_child(UiKit.label(tr("PACK_MANDATORY"), UiKit.SIZE_SMALL, Palette.IVORY.darkened(0.2)))
	_fit_pack.call_deferred()


func _choose(i: int, mode: String) -> void:
	if ShopModel.choose_pack(ctl.run, ctl.db, i, mode):
		AudioBus.play("card_place")
		_refresh()
		GameState.autosave()
	else:
		EventBus.toast.emit(tr("SHOP_NO_SLOT"), &"error")


## La fenêtre du paquet tient dans l'écran quelle que soit la résolution.
func _fit_pack() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var need: Vector2 = _pack_panel.size
	var room: Vector2 = size * FIT_MARGIN
	var k: float = minf(1.0, minf(room.x / maxf(need.x, 1.0), room.y / maxf(need.y, 1.0)))
	_pack_panel.pivot_offset = need * 0.5
	_pack_panel.scale = Vector2(k, k)
