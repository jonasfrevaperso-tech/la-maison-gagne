class_name StatsScreen
extends MetaScreen
## Statistiques cumulées du profil.


const RECENT_SHOWN: int = 15
const RECENT_COLUMNS: Array[String] = [
	"STATS_COL_DATE",
	"STATS_COL_CHAR",
	"STATS_COL_RISK",
	"STATS_COL_RESULT",
	"STATS_COL_SPINS",
	"STATS_COL_TIME",
	"STATS_COL_BEST",
	"STATS_COL_SEED",
]


func screen_title() -> String:
	return tr("MENU_STATS")


func build() -> void:
	var p: Dictionary = SaveSystem.profile
	var st: Dictionary = p.get("stats", {})
	var runs: int = int(st.get("runs", 0))
	var wins: int = int(st.get("wins", 0))
	var rows: Array[Array] = [
		["STATS_RUNS", str(runs)],
		["STATS_WINS", str(wins)],
		["STATS_WINRATE", "%.1f %%" % (100.0 * float(wins) / float(maxi(runs, 1)))],
		["STATS_SPINS", Localization.format_number(float(st.get("spins", 0)))],
		["STATS_BEST_SPIN", Localization.format_number(float(st.get("best_spin", 0)))],
		["STATS_ZEROS", str(int(st.get("zeros", 0)))],
		["STATS_PLAYTIME", "%.1f h" % (float(st.get("minutes", 0.0)) / 60.0)],
		["STATS_ACHIEVEMENTS", "%d / %d" % [(p.get("achievements", []) as Array).size(), DataRegistry.db.count("achievements")]],
		["STATS_CHALLENGES", "%d / %d" % [(p.get("challenges_done", []) as Array).size(), DataRegistry.db.count("challenges")]],
		[
			"STATS_SEEN",
			"%d / %d" % [((p.get("seen", {}) as Dictionary).get("grigris", []) as Array).size(), DataRegistry.db.count("grigris")]
		],
	]
	var g: GridContainer = grid(2)
	for r: Array in rows:
		var k: Label = UiKit.label(tr(String(r[0])), UiKit.SIZE_H2)
		k.custom_minimum_size = Vector2(700, 0)
		g.add_child(k)
		g.add_child(UiKit.label(String(r[1]), UiKit.SIZE_H2, Palette.GOLD_LIGHT, "mono"))
	_survival(p)
	_recent(p)


func _survival(p: Dictionary) -> void:
	section(tr("STATS_SURVIVAL"))
	content.add_child(UiKit.label(tr("STATS_SURVIVAL_DESC"), UiKit.SIZE_SMALL, Palette.SMOKE))
	content.add_child(SurvivalChart.new(RunHistory.survival_rates(p, Balance.i("run.tiers"))))


func _recent(p: Dictionary) -> void:
	section(tr("STATS_RECENT"))
	var hist: Array = p.get("history", [])
	if hist.is_empty():
		content.add_child(UiKit.label(tr("STATS_NO_HISTORY"), UiKit.SIZE_BODY, Palette.SMOKE))
		return
	var g: GridContainer = grid(RECENT_COLUMNS.size())
	for key: String in RECENT_COLUMNS:
		g.add_child(UiKit.label(tr(key), UiKit.SIZE_SMALL, Palette.GOLD))
	for i: int in mini(hist.size(), RECENT_SHOWN):
		var e: Dictionary = hist[hist.size() - 1 - i]
		var ch: Dictionary = DataRegistry.db.get_entry("characters", String(e.get("character", "")))
		var cells: Array[String] = [
			String(e.get("date", "")),
			Localization.t(ch, "name") if not ch.is_empty() else String(e.get("character", "")),
			str(int(e.get("risk", 0))),
			tr("STATS_RESULT_WIN") if bool(e.get("victory", false)) else tr("STATS_RESULT_TIER") % int(e.get("tier", 1)),
			str(int(e.get("spins", 0))),
			"%.0f min" % float(e.get("minutes", 0.0)),
			Localization.format_number(float(e.get("best_spin", 0))),
			String(e.get("seed", "")),
		]
		for c: int in cells.size():
			var col: Color = Palette.EMERALD if c == 3 and bool(e.get("victory", false)) else Palette.IVORY
			g.add_child(UiKit.label(cells[c], UiKit.SIZE_SMALL, col, "mono" if c >= 4 else "ui"))
