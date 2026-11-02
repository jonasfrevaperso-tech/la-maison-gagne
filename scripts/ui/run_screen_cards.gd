class_name RunScreenCards
extends RefCounted
## Fiches illustrées de l'écran de run pilotées à la manette : case de la roue (ciblage d'une
## carte Fortune) et emplacement de pari sous le curseur du tapis.

const POCKET_CARD_GAP: float = 120.0
const BET_CARD_GAP: float = 46.0

var s: RunScreen = null
var _pocket_card: PanelContainer = null
var _bet_card: PanelContainer = null


func _init(screen: RunScreen) -> void:
	s = screen


## Fiche illustrée d'une case (ciblage à la manette), placée à côté de la case, hors de la roue.
func show_pocket(index: int) -> void:
	if _pocket_card != null and is_instance_valid(_pocket_card):
		_pocket_card.queue_free()
	_pocket_card = null
	if index < 0:
		return
	var probs: Array[float] = s.wheel_view.probabilities
	_pocket_card = PocketCard.build(s.ctl.run.wheel.at(index), s.ctl.db, probs[index] if index < probs.size() else -1.0)
	_pocket_card.z_index = 5
	s._stage.add_child(_pocket_card)
	var at: Vector2 = s.wheel_view.position + s.wheel_view.pocket_screen_pos(index)
	var out: Vector2 = (at - (s.wheel_view.position + s.wheel_view.size * 0.5)).normalized()
	var sz: Vector2 = _pocket_card.get_combined_minimum_size()
	var pos: Vector2 = at + out * POCKET_CARD_GAP - sz * 0.5 + Vector2(sz.x * 0.5 * signf(out.x), 0.0)
	_pocket_card.position = pos.clamp(Vector2(8, 8), UiLayout.DESIGN_SIZE - sz - Vector2(8, 8))


## Fiche du pari sous le curseur manette : au-dessus du curseur, sinon en dessous ; jamais sur
## les barres de grigris et de Fortune.
func show_bet(spot_id: String) -> void:
	hide_bet()
	if spot_id == "" or not InputGlyphs.using_pad or s.state != RunScreen.UiState.BETTING or s._items_mode:
		return
	var r: RunState = s.ctl.run
	_bet_card = BetCard.build(spot_id, s.table_view.hide_odds, r.wheel, r.chip_value, int(r.slip.chips.get(spot_id, 0)))
	if _bet_card == null:
		return
	_bet_card.z_index = 5
	s._stage.add_child(_bet_card)
	# Manette : la fiche se range à gauche du tapis (sur la roue, inutile pendant les mises), à
	# hauteur du curseur ; elle ne couvre jamais le tapis ni l'emplacement sélectionné.
	var at: Vector2 = s.table_view.position + s.table_view.cursor_point()
	var sz: Vector2 = _bet_card.get_combined_minimum_size()
	var x: float = s.table_view.position.x - sz.x - BET_CARD_GAP
	var y: float = at.y - sz.y * 0.5
	var max_y: float = s.grigri_bar.position.y - RunScreen.BAR_CAPTION_Y - sz.y - 8.0
	_bet_card.position = Vector2(maxf(x, 8.0), clampf(y, RunScreen.HUD_STRIP_H + 16.0, max_y))


func hide_bet() -> void:
	if _bet_card != null and is_instance_valid(_bet_card):
		_bet_card.queue_free()
	_bet_card = null
