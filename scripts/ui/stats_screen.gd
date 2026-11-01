class_name StatsScreen
extends MetaScreen
## Statistiques cumulées du profil.


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
