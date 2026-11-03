class_name GrigriBar
extends HBoxContainer
## Rangée des grigris possédés (ordre = ordre de déclenchement), emplacements vides visibles.
## En boutique, double-clic = vendre (avec confirmation si activée).

signal sell_requested(g_uid: int)
signal changed

const SLOT_EMPTY_ALPHA: float = 0.25

var run: RunState = null
var shop_mode: bool = false
var _cards: Dictionary[int, GrigriCard] = {}


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	alignment = BoxContainer.ALIGNMENT_CENTER


func bind(p_run: RunState) -> void:
	run = p_run
	refresh()


func refresh() -> void:
	for c: Node in get_children():
		c.queue_free()
	_cards.clear()
	if run == null:
		return
	for g: GrigriInstance in run.grigris:
		var card: GrigriCard = GrigriCard.new().configure("grigri", g.id, g.uid)
		card.edition = g.edition
		card.counter = g.counter
		card.show_counter = true
		card.locked = g.locked
		card.disabled_look = g.disabled
		if shop_mode:
			card.price = ShopModel.sell_value(run, DataRegistry.db, g)
			card.action_text = tr("CARD_SELL") % card.price
		card.lock_toggled.connect(_on_lock)
		card.reorder_requested.connect(_on_reorder)
		card.activated.connect(_on_activated)
		card.move_requested.connect(_on_move)
		add_child(card)
		_cards[g.uid] = card
	for _i: int in run.empty_grigri_slots():
		var empty: Panel = Panel.new()
		empty.custom_minimum_size = GrigriCard.CARD_SIZE
		empty.modulate.a = SLOT_EMPTY_ALPHA
		empty.tooltip_text = tr("SLOT_EMPTY")
		add_child(empty)


func card_for(g_uid: int) -> GrigriCard:
	return _cards.get(g_uid, null)


func card_center(g_uid: int) -> Vector2:
	var c: GrigriCard = card_for(g_uid)
	if c == null:
		return UiLayout.canvas_point(self, size * 0.5)
	return UiLayout.canvas_point(c, c.size * 0.5)


func bump(g_uid: int) -> void:
	var c: GrigriCard = card_for(g_uid)
	if c != null:
		c.bump()


func _on_lock(card: GrigriCard) -> void:
	var g: GrigriInstance = run.grigri_by_uid(card.uid)
	if g == null:
		return
	g.locked = not g.locked
	AudioBus.ui("lock")
	var had_focus: bool = card.has_focus()
	refresh()
	changed.emit()
	if had_focus:
		_focus_uid.call_deferred(card.uid)


func _on_reorder(from_uid: int, to_uid: int) -> void:
	var a: GrigriInstance = run.grigri_by_uid(from_uid)
	var b: GrigriInstance = run.grigri_by_uid(to_uid)
	if a == null or b == null:
		return
	var to_idx: int = run.grigris.find(b)
	run.grigris.erase(a)
	run.grigris.insert(to_idx, a)
	AudioBus.ui("card_place")
	refresh()
	changed.emit()


## Manette : échange avec le voisin, puis garde la sélection sur la carte déplacée.
func _on_move(card: GrigriCard, direction: int) -> void:
	var g: GrigriInstance = run.grigri_by_uid(card.uid)
	if g == null:
		return
	var i: int = run.grigris.find(g)
	var j: int = i + direction
	if j < 0 or j >= run.grigris.size():
		return
	_on_reorder(card.uid, run.grigris[j].uid)
	_focus_uid.call_deferred(card.uid)


func _focus_uid(g_uid: int) -> void:
	var c: GrigriCard = card_for(g_uid)
	if c != null:
		c.grab_focus()


func _on_activated(card: GrigriCard) -> void:
	if shop_mode:
		sell_requested.emit(card.uid)
