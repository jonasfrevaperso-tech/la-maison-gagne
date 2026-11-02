class_name SeedRaceScreen
extends MetaScreen
## Course de graine : classement local de tous tes runs sur une même graine (celle du jour par
## défaut, ou n'importe quel code partagé), et départ immédiat sur cette graine.

const SHOWN: int = 12
const COLUMNS: Array[String] = [
	"RACE_COL_RANK", "STATS_COL_DATE", "STATS_COL_CHAR", "STATS_COL_RESULT", "RACE_COL_DEADLINES", "RACE_COL_SCORE", "STATS_COL_TIME"
]

var _seed_code: String = ""
var _seed_edit: LineEdit = null
var _board: VBoxContainer = null


func setup(params: Dictionary) -> void:
	_seed_code = String(params.get("seed", ""))


func screen_title() -> String:
	return tr("MENU_RACE")


func build() -> void:
	if _seed_code == "":
		_seed_code = RngService.seed_to_code(RngService.daily_seed())
	var intro: Label = UiKit.label(tr("RACE_INTRO"), UiKit.SIZE_BODY, Palette.IVORY.darkened(0.1))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	content.add_child(row)
	row.add_child(UiKit.label(tr("CHAR_SEED"), UiKit.SIZE_BODY))
	_seed_edit = LineEdit.new()
	_seed_edit.text = _seed_code
	_seed_edit.custom_minimum_size = Vector2(320, 52)
	_seed_edit.set_meta("osk_upper", true)
	_seed_edit.text_submitted.connect(func(_t: String) -> void: _load_seed())
	row.add_child(_seed_edit)
	row.add_child(UiKit.button(tr("RACE_LOAD"), _load_seed, Vector2(220, 52)))
	row.add_child(UiKit.button(tr("RACE_TODAY"), _today, Vector2(260, 52)))
	var play: Button = UiKit.button(tr("RACE_PLAY"), _play, Vector2(320, 52))
	row.add_child(play)
	_board = VBoxContainer.new()
	_board.add_theme_constant_override("separation", 8)
	content.add_child(_board)
	_refresh()


func _load_seed() -> void:
	var code: String = _seed_edit.text.strip_edges().to_upper()
	if code == "":
		return
	_seed_code = code
	_refresh()


func _today() -> void:
	_seed_code = RngService.seed_to_code(RngService.daily_seed())
	_seed_edit.text = _seed_code
	_refresh()


func _play() -> void:
	GameState.goto(GameState.SCREEN_CHARACTER, {"seed": _seed_code})


func _refresh() -> void:
	for c: Node in _board.get_children():
		c.queue_free()
	var is_today: bool = _seed_code == RngService.seed_to_code(RngService.daily_seed())
	var heading_txt: String = (tr("RACE_TODAY_SEED") if is_today else tr("RACE_SEED")) % _seed_code
	_board.add_child(UiKit.label(heading_txt, UiKit.SIZE_H2, Palette.GOLD, "display"))
	var rows: Array[Dictionary] = RunHistory.leaderboard(SaveSystem.profile, _seed_code)
	if rows.is_empty():
		_board.add_child(UiKit.label(tr("RACE_EMPTY"), UiKit.SIZE_BODY, Palette.SMOKE))
		return
	var g: GridContainer = GridContainer.new()
	g.columns = COLUMNS.size()
	g.add_theme_constant_override("h_separation", 28)
	g.add_theme_constant_override("v_separation", 8)
	_board.add_child(g)
	for key: String in COLUMNS:
		g.add_child(UiKit.label(tr(key), UiKit.SIZE_SMALL, Palette.GOLD))
	for i: int in mini(rows.size(), SHOWN):
		var e: Dictionary = rows[i]
		var win: bool = bool(e.get("victory", false))
		var ch: Dictionary = DataRegistry.db.get_entry("characters", String(e.get("character", "")))
		var medal: Color = [Palette.GOLD_LIGHT, Palette.IVORY, Palette.BRONZE][mini(i, 2)] if i < 3 else Palette.IVORY.darkened(0.2)
		var cells: Array[String] = [
			"#%d" % (i + 1),
			String(e.get("date", "")),
			Localization.t(ch, "name") if not ch.is_empty() else "?",
			tr("STATS_RESULT_WIN") if win else tr("STATS_RESULT_TIER") % int(e.get("tier", 1)),
			str(int(e.get("deadlines", 0))),
			Localization.format_number(float(e.get("score_total", 0))),
			"%.0f min" % float(e.get("minutes", 0.0)),
		]
		for c2: int in cells.size():
			var col: Color = medal if c2 == 0 else (Palette.EMERALD if c2 == 3 and win else Palette.IVORY)
			g.add_child(UiKit.label(cells[c2], UiKit.SIZE_BODY if c2 == 0 else UiKit.SIZE_SMALL, col, "mono" if c2 >= 4 or c2 == 0 else "ui"))
