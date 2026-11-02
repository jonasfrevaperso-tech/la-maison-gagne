class_name CharacterSelect
extends Control
## Choix du personnage, du niveau de Risque et (optionnel) de la graine.

const CARD_W: float = 280.0

var daily: bool = false
var _selected: String = "lea"
var _risk: int = 0
var _cards: HBoxContainer = null
var _detail: RichTextLabel = null
var _risk_label: Label = null
var _risk_desc: Label = null
var _seed_edit: LineEdit = null
## Graine imposée (Course de graine) : pré-remplie, modifiable.
var _preset_seed: String = ""
var _start_btn: Button = null


func setup(params: Dictionary) -> void:
	daily = bool(params.get("daily", false))
	_preset_seed = String(params.get("seed", ""))


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(DecoBackground.new())
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 60
	v.offset_right = -60
	v.offset_top = 40
	v.offset_bottom = -40
	v.add_theme_constant_override("separation", 18)
	add_child(v)
	v.add_child(UiKit.title(tr("DAILY_TITLE") if daily else tr("CHAR_TITLE"), UiKit.SIZE_H1))
	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 18)
	v.add_child(_cards)
	_detail = UiKit.rich("", UiKit.SIZE_BODY)
	_detail.custom_minimum_size = Vector2(1200, 120)
	_detail.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_detail)
	var risk_row: HBoxContainer = HBoxContainer.new()
	risk_row.alignment = BoxContainer.ALIGNMENT_CENTER
	risk_row.add_theme_constant_override("separation", 16)
	v.add_child(risk_row)
	risk_row.add_child(UiKit.button("◀", _change_risk.bind(-1), Vector2(64, 54)))
	_risk_label = UiKit.label("", UiKit.SIZE_H2, Palette.GOLD_LIGHT, "display")
	_risk_label.custom_minimum_size = Vector2(320, 0)
	_risk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	risk_row.add_child(_risk_label)
	risk_row.add_child(UiKit.button("▶", _change_risk.bind(1), Vector2(64, 54)))
	_risk_desc = UiKit.label("", UiKit.SIZE_BODY, Palette.SMOKE)
	_risk_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_risk_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_risk_desc)
	var seed_row: HBoxContainer = HBoxContainer.new()
	seed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(seed_row)
	seed_row.add_child(UiKit.label(tr("CHAR_SEED"), UiKit.SIZE_BODY))
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = tr("CHAR_SEED_PLACEHOLDER")
	_seed_edit.custom_minimum_size = Vector2(300, 48)
	_seed_edit.editable = not daily
	_seed_edit.set_meta("osk_upper", true)
	if daily:
		_seed_edit.text = RngService.seed_to_code(RngService.daily_seed())
	elif _preset_seed != "":
		_seed_edit.text = _preset_seed
	seed_row.add_child(_seed_edit)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 20)
	v.add_child(actions)
	actions.add_child(UiKit.button(tr("MENU_BACK"), GameState.goto.bind(GameState.SCREEN_TITLE)))
	_start_btn = UiKit.button(tr("CHAR_START"), _start)
	actions.add_child(_start_btn)
	if daily:
		var ids: Array[String] = _playable()
		_selected = ids[RngService.daily_seed() % ids.size()]
	_build_cards()
	_refresh()
	_start_btn.call_deferred("grab_focus")


func _playable() -> Array[String]:
	var out: Array[String] = []
	for cid: String in DataRegistry.db.ids("characters"):
		if _unlocked(cid):
			out.append(cid)
	return out


func _unlocked(cid: String) -> bool:
	return (SaveSystem.profile.get("unlocked_characters", []) as Array).has(cid)


func _max_risk(cid: String) -> int:
	return mini(int((SaveSystem.profile.get("max_risk", {}) as Dictionary).get(cid, 0)), DataRegistry.db.count("risks"))


func _build_cards() -> void:
	for cid: String in DataRegistry.db.ids("characters"):
		var e: Dictionary = DataRegistry.db.get_entry("characters", cid)
		var unlocked: bool = _unlocked(cid)
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(CARD_W, 360)
		b.toggle_mode = true
		b.disabled = not unlocked or daily
		b.pressed.connect(_select.bind(cid))
		b.pressed.connect(AudioBus.ui.bind("click"))
		var col: VBoxContainer = VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(col)
		var pv: PortraitView = PortraitView.new().configure(String(e.get("portrait", cid)), Color(String(e.get("color", "d4af37"))))
		pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pv.scale = Vector2(0.9, 0.9)
		col.add_child(pv)
		var n: Label = UiKit.label(Localization.t(e, "name") if unlocked else "???", UiKit.SIZE_BODY, Palette.GOLD_LIGHT, "display")
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(n)
		b.set_meta("cid", cid)
		_cards.add_child(b)


func _select(cid: String) -> void:
	_selected = cid
	_risk = mini(_risk, _max_risk(cid))
	_refresh()


func _change_risk(d: int) -> void:
	_risk = clampi(_risk + d, 0, _max_risk(_selected))
	AudioBus.ui("click")
	_refresh()


func _refresh() -> void:
	for b: Node in _cards.get_children():
		(b as Button).button_pressed = String(b.get_meta("cid")) == _selected
	var e: Dictionary = DataRegistry.db.get_entry("characters", _selected)
	_detail.text = (
		"[center][b][color=#f2d27a]%s[/color][/b]\n%s\n[i][color=#6b6275]« %s »[/color][/i][/center]"
		% [Localization.t(e, "name"), Localization.t(e, "desc"), Localization.t(e, "flavor")]
	)
	_risk_label.text = tr("RISK_LEVEL") % _risk
	var descs: PackedStringArray = []
	for r: Dictionary in DataRegistry.db.list("risks"):
		if int(r["level"]) <= _risk:
			descs.append(Localization.t(r, "desc"))
	_risk_desc.text = tr("RISK_NONE") if descs.is_empty() else " · ".join(descs)


func _start() -> void:
	var seed_value: int
	if daily:
		seed_value = RngService.daily_seed()
	elif _seed_edit.text.strip_edges() != "":
		seed_value = RngService.code_to_seed(_seed_edit.text)
	else:
		seed_value = RngService.new_seed()
	GameState.start_new_run(_selected, _risk, seed_value, "", daily)


func go_back() -> void:
	GameState.goto(GameState.SCREEN_TITLE)
