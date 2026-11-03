class_name RunScreenLayoutMobile
extends RefCounted
## Écran de run sur téléphone (paysage 20:9). Mêmes nœuds que sur PC (RunScreenLayout), placés
## autrement sur une scène plus large (2200×1080) :
##   roue à gauche, tapis agrandi à droite (cases ≈ 100 px : visables au doigt),
##   rangée de gros boutons sous le tapis, grigris et Fortune en bas à gauche.
## « Disposition gaucher » : tout est mis en miroir (tapis et Lancer à gauche).

const STAGE: Vector2 = Vector2(2200, 1080)
const M: float = 16.0
const HEADER_H: float = 126.0
const WHEEL_RECT: Rect2 = Rect2(6, 150, 690, 590)
const SCORE_POS: Vector2 = Vector2(1120, 128)
const TABLE_RECT: Rect2 = Rect2(736, 330, 1448, 516)
const ACTIONS_Y: float = 894.0
const BTN: Vector2 = Vector2(176, 104)
const SPIN_BTN: Vector2 = Vector2(300, 118)
const SPEED_BTN: Vector2 = Vector2(110, 104)
const FORTUNE_X: float = 906.0
const HINT_W: float = 1000.0


static func apply(s: RunScreen) -> void:
	_header(s)
	s.wheel_view.position = WHEEL_RECT.position
	s.wheel_view.size = WHEEL_RECT.size
	s.throw_game.position = WHEEL_RECT.position
	s.throw_game.size = WHEEL_RECT.size
	s._history_box.position = Vector2(WHEEL_RECT.position.x + 14.0, WHEEL_RECT.end.y + 6.0)
	s.score_panel.position = SCORE_POS
	s.table_view.position = TABLE_RECT.position
	s.table_view.size = TABLE_RECT.size
	_actions(s)
	var bar_y: float = STAGE.y - GrigriCard.CARD_SIZE.y - M
	s.grigri_bar.position = Vector2(M + 8.0, bar_y)
	s._grigri_caption.position = s.grigri_bar.position - Vector2(0, RunScreen.BAR_CAPTION_Y)
	s.fortune_bar.position = Vector2(FORTUNE_X, bar_y)
	s._fortune_caption.position = s.fortune_bar.position - Vector2(0, RunScreen.BAR_CAPTION_Y)
	RunScreenLayout.seat_caption(s._grigri_caption, s.grigri_bar)
	RunScreenLayout.seat_caption(s._fortune_caption, s.fortune_bar)
	if Settings.b("game", "left_handed"):
		_mirror(s)


static func _header(s: RunScreen) -> void:
	s._header_strip.size = Vector2(STAGE.x - M * 2.0 - 130.0, HEADER_H)
	s._header_strip.position = Vector2(M, 6)
	s._menu_btn.custom_minimum_size = Vector2(110, 104)
	s._menu_btn.size = s._menu_btn.custom_minimum_size
	s._menu_btn.position = Vector2(STAGE.x - M - 110.0, 10)
	s._creditor_label.custom_minimum_size = Vector2(STAGE.x - 900.0, 0)


static func _actions(s: RunScreen) -> void:
	var row: HBoxContainer = s._actions
	row.add_theme_constant_override("separation", 14)
	for b: Button in [s._undo_btn, s._repeat_btn, s._clear_btn]:
		b.custom_minimum_size = BTN
	s._speed_btn.custom_minimum_size = SPEED_BTN
	for b2: Button in [s._spin_btn, s._rethrow_btn, s._keep_btn]:
		b2.custom_minimum_size = Vector2(b2.custom_minimum_size.x, SPIN_BTN.y)
	s._spin_btn.custom_minimum_size = SPIN_BTN
	row.reset_size()
	# Rangée calée à droite sous le tapis (le pouce droit tombe sur « Lancer »).
	row.position = Vector2(TABLE_RECT.end.x - row.get_combined_minimum_size().x, ACTIONS_Y)
	row.resized.connect(func() -> void: _seat_actions(s))
	s._prompt_bar.visible = false
	s._hint_label.size = Vector2(HINT_W, 0)
	s._hint_label.max_lines_visible = 1
	_seat_actions(s)


## La rangée reste calée sur le bord du tapis (côté pouce) quand des boutons apparaissent.
static func _seat_actions(s: RunScreen) -> void:
	var row: HBoxContainer = s._actions
	var w: float = row.get_combined_minimum_size().x
	if Settings.b("game", "left_handed"):
		row.position.x = STAGE.x - TABLE_RECT.end.x
	else:
		row.position.x = TABLE_RECT.end.x - w
	row.position.y = ACTIONS_Y
	var hx: float = row.position.x if not Settings.b("game", "left_handed") else row.position.x + w - HINT_W
	s._hint_label.position = Vector2(clampf(hx, M, STAGE.x - HINT_W - M), ACTIONS_Y + SPIN_BTN.y + 8.0)


## Disposition gaucher : miroir horizontal des grands blocs (la barre du haut ne bouge pas).
static func _mirror(s: RunScreen) -> void:
	for c: Control in [s.wheel_view, s.throw_game, s.table_view]:
		c.position.x = STAGE.x - c.position.x - c.size.x
	s._history_box.position.x = STAGE.x - WHEEL_RECT.end.x + 14.0
	var sp: Vector2 = s.score_panel.get_combined_minimum_size()
	s.score_panel.position.x = STAGE.x - SCORE_POS.x - sp.x
	_seat_actions(s)
