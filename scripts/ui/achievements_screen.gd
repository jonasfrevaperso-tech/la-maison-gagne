class_name AchievementsScreen
extends MetaScreen
## Liste des 60 succès (débloqués en or, verrouillés en fumée).


func screen_title() -> String:
	return tr("MENU_ACHIEVEMENTS")


func build() -> void:
	var got: Array = SaveSystem.profile.get("achievements", [])
	var all: Array[Dictionary] = DataRegistry.db.list("achievements")
	section(tr("ACH_PROGRESS") % [got.size(), all.size()])
	var g: GridContainer = grid(3)
	for a: Dictionary in all:
		var ok: bool = got.has(String(a["id"]))
		var p: PanelContainer = UiKit.panel(Palette.VELVET_DEEP if ok else Palette.INK, Palette.GOLD if ok else Palette.SMOKE_DARK)
		p.custom_minimum_size = Vector2(560, 90)
		var v: VBoxContainer = VBoxContainer.new()
		p.add_child(v)
		v.add_child(
			UiKit.label(
				("★ " if ok else "☆ ") + Localization.t(a, "name"), UiKit.SIZE_BODY, Palette.GOLD_LIGHT if ok else Palette.SMOKE, "display"
			)
		)
		var d: Label = UiKit.label(Localization.t(a, "desc"), UiKit.SIZE_SMALL, Palette.IVORY if ok else Palette.SMOKE)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(d)
		g.add_child(p)
