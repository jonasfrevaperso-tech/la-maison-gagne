class_name ShopOverlay
extends Overlay
## Boutique : 3 grigris, 2 paquets, 1 contrat, reroll, vente, probabilités affichées.

const FLIP_TIME: float = 0.25
const FLIP_STAGGER: float = 0.08
const DISSOLVE_SHADER: String = "res://shaders/dissolve.gdshader"
const DISSOLVE_TIME: float = 0.7

var ctl: RunController = null
var _money: Label = null
var _offers_row: HBoxContainer = null
var _packs_row: HBoxContainer = null
var _odds: Label = null
var _reroll_btn: Button = null
var _owned: GrigriBar = null
var _pack_box: VBoxContainer = null
var _float: FloatLayer = null
var _rerolls_here: int = 0


func configure(p_ctl: RunController) -> ShopOverlay:
	ctl = p_ctl
	panel_width = 1500.0
	return self


func build() -> void:
	var head: HBoxContainer = row()
	head.add_child(UiKit.title(tr("SHOP_TITLE"), UiKit.SIZE_H1))
	_money = UiKit.label("", UiKit.SIZE_H1, Palette.GOLD_LIGHT, "mono")
	head.add_child(_money)
	_odds = UiKit.label("", UiKit.SIZE_SMALL, Palette.SMOKE)
	_odds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_odds)
	var mid: HBoxContainer = row()
	mid.add_theme_constant_override("separation", 60)
	var gcol: VBoxContainer = VBoxContainer.new()
	gcol.add_child(UiKit.label(tr("SHOP_GRIGRIS"), UiKit.SIZE_BODY, Palette.GOLD))
	_offers_row = HBoxContainer.new()
	_offers_row.add_theme_constant_override("separation", 16)
	gcol.add_child(_offers_row)
	mid.add_child(gcol)
	var pcol: VBoxContainer = VBoxContainer.new()
	pcol.add_child(UiKit.label(tr("SHOP_PACKS_CONTRACT"), UiKit.SIZE_BODY, Palette.GOLD))
	_packs_row = HBoxContainer.new()
	_packs_row.add_theme_constant_override("separation", 16)
	pcol.add_child(_packs_row)
	mid.add_child(pcol)
	_pack_box = VBoxContainer.new()
	_pack_box.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(_pack_box)
	body.add_child(UiKit.label(tr("SHOP_OWNED"), UiKit.SIZE_BODY, Palette.GOLD))
	_owned = GrigriBar.new()
	_owned.shop_mode = true
	_owned.sell_requested.connect(_on_sell)
	body.add_child(_owned)
	var actions: HBoxContainer = row()
	_reroll_btn = UiKit.button("", _on_reroll)
	actions.add_child(_reroll_btn)
	var leave: Button = UiKit.button(tr("SHOP_LEAVE"), close)
	actions.add_child(leave)
	leave.call_deferred("grab_focus")
	_float = FloatLayer.new()
	add_child(_float)
	_refresh(true)


func _refresh(animate: bool = false) -> void:
	var r: RunState = ctl.run
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
		var b: Button = UiKit.button(
			tr("PACK_" + String(pk["kind"]).to_upper()) + "\n%d $" % int(pk["price"]), _on_buy_pack.bind(j), Vector2(180, 144)
		)
		b.disabled = bool(pk["sold"]) or not (r.shop_state.get("open_pack", {}) as Dictionary).is_empty()
		b.tooltip_text = tr("PACK_" + String(pk["kind"]).to_upper() + "_DESC")
		_packs_row.add_child(b)
	var contracts: Array = r.shop_state.get("contracts", [])
	for k2: int in contracts.size():
		var co: Dictionary = contracts[k2]
		var cc: GrigriCard = GrigriCard.new().configure("contract", String(co["id"]), k2)
		cc.price = int(co["price"])
		cc.disabled_look = bool(co["sold"])
		cc.draggable = false
		cc.activated.connect(_on_buy_contract)
		_packs_row.add_child(cc)
	_reroll_btn.text = tr("SHOP_REROLL") % int(r.shop_state.get("reroll_cost", 0))
	_reroll_btn.disabled = r.money < int(r.shop_state.get("reroll_cost", 0))
	_owned.bind(r)
	_refresh_pack()


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
	var pos: Vector2 = card.global_position + card.size * 0.5
	if _feedback(ShopModel.buy_grigri(ctl.run, ctl.db, card.uid), pos):
		SaveSystem.mark_seen("grigris", card.entry_id)
		GameState.record_shop("buy", {"rarity": card.rarity(), "id": card.entry_id})
		_refresh()
		GameState.autosave()


func _on_buy_contract(card: GrigriCard) -> void:
	var pos: Vector2 = card.global_position + card.size * 0.5
	if _feedback(ShopModel.buy_contract(ctl.run, ctl.db, card.uid), pos):
		SaveSystem.mark_seen("contracts", card.entry_id)
		_refresh()
		GameState.autosave()


func _on_buy_pack(i: int) -> void:
	if _feedback(ShopModel.buy_pack(ctl.run, ctl.db, i), _packs_row.global_position + Vector2(90, 70)):
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
	card.global_position = center - GrigriCard.CARD_SIZE * 0.5
	var tw: Tween = card.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("progress", v), 0.0, 1.0, DISSOLVE_TIME / maxf(Settings.speed(), 1.0))
	tw.tween_callback(card.queue_free)


# --------------------------------------------------------------------------- paquet ouvert


func _refresh_pack() -> void:
	for c: Node in _pack_box.get_children():
		c.queue_free()
	var pack: Dictionary = ctl.run.shop_state.get("open_pack", {})
	if pack.is_empty():
		return
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
				col.add_child(fc)
				col.add_child(UiKit.button(tr("PACK_TAKE"), _choose.bind(i, "add"), Vector2(150, 44)))
			"occult":
				var oc: GrigriCard = GrigriCard.new().configure("grigri", String(c2["grigri"]), i)
				oc.draggable = false
				col.add_child(oc)
				col.add_child(UiKit.button(tr("PACK_TAKE"), _choose.bind(i, "add"), Vector2(150, 44)))
		_flip_in(col, i)
	_pack_box.add_child(UiKit.button(tr("PACK_SKIP"), _skip_pack, Vector2(200, 44)))


func _choose(i: int, mode: String) -> void:
	if ShopModel.choose_pack(ctl.run, ctl.db, i, mode):
		AudioBus.play("card_place")
		_refresh()
		GameState.autosave()
	else:
		EventBus.toast.emit(tr("SHOP_NO_SLOT"), &"error")


func _skip_pack() -> void:
	ShopModel.skip_pack(ctl.run)
	_refresh()
