class_name DevAutoplay
extends Node
## Pilote automatique de l'interface (QA) : pose des mises, lance, relâche, enchaîne
## boutique / pacte, prend des captures. Activé par `-- --dev-autoplay=N [--shot-dir=...]`.

const RELEASE_DELAY: float = 0.9
const POLL: float = 0.1

var spins_wanted: int = 3
var shot_dir: String = ""
var perf: bool = false
var _shots: int = 0
var _frames: Array[float] = []
var _gpu: Array[float] = []
var _cpu: Array[float] = []
var _draw_calls: int = 0


func _ready() -> void:
	if perf:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_drive()


func _process(delta: float) -> void:
	if perf:
		_frames.append(delta * 1000.0)
		var rid: RID = get_viewport().get_viewport_rid()
		var gpu: float = RenderingServer.viewport_get_measured_render_time_gpu(rid)
		var cpu: float = RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu()
		if gpu > 0.0:
			_gpu.append(gpu)
			_cpu.append(cpu)
		_draw_calls = maxi(_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))


func _perf_report() -> void:
	if _frames.size() < 10:
		return
	if not _gpu.is_empty():
		_gpu.sort()
		_cpu.sort()
		print(
			"Rendu : GPU médian %.2f ms (99e centile %.2f ms) · CPU de rendu médian %.2f ms"
			% [_gpu[_gpu.size() / 2], _gpu[int(float(_gpu.size()) * 0.99)], _cpu[_cpu.size() / 2]]
		)
	var sorted: Array[float] = _frames.duplicate()
	sorted.sort()
	var avg: float = 0.0
	for f: float in sorted:
		avg += f
	avg /= float(sorted.size())
	var p99: float = sorted[int(float(sorted.size()) * 0.99)]
	print(
		(
			"Perf : %d frames · moyenne %.2f ms (%.0f FPS) · 1 %% lent %.2f ms · pire %.2f ms · draw calls max %d · mémoire %.0f Mo"
			% [
				sorted.size(),
				avg,
				1000.0 / avg,
				p99,
				sorted[sorted.size() - 1],
				_draw_calls,
				Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
			]
		)
	)


## Joue le mini-jeu proprement : vise le centre de la zone dorée, puis le contact de l'anneau.
func _throw_minigame(rs: RunScreen) -> void:
	var g: ThrowMinigame = rs.throw_game
	if rs.tutorial.blocking():
		rs.tutorial.call("_close_current")
	var guard: int = 0
	while g.beat == ThrowMinigame.Beat.POWER and guard < 400:
		guard += 1
		if absf(g.get("_needle") - 0.5) < 0.03:
			await _shot("throw_power")
			g.press()
			break
		await get_tree().process_frame
	guard = 0
	while g.beat == ThrowMinigame.Beat.RELEASE and guard < 400:
		guard += 1
		if float(g.get("_t")) >= float(g.get("_release_time")) - 0.01:
			await _shot("throw_release")
			g.press()
			break
		await get_tree().process_frame


func _screen() -> RunScreen:
	for n: Node in get_tree().root.find_children("*", "RunScreen", true, false):
		return n as RunScreen
	return null


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(tag: String) -> void:
	if shot_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	_shots += 1
	DirAccess.make_dir_recursive_absolute(shot_dir)
	img.save_png(shot_dir.path_join("%02d_%s.png" % [_shots, tag]))


func _drive() -> void:
	await _wait(1.5)
	Settings.speed_override = 4.0
	var done: int = 0
	var guard: int = 0
	while done < spins_wanted and guard < 20000:
		guard += 1
		if GameState.current_screen == GameState.SCREEN_SUMMARY:
			await _wait(1.5)
			await _shot("summary")
			print("Autoplay : écran de résumé atteint (victoire=%s)" % str(GameState.last_run_victory))
			break
		var rs: RunScreen = _screen()
		if rs == null:
			await _wait(POLL)
			continue
		match rs.state:
			RunScreen.UiState.BETTING:
				if rs.ctl.run.slip.is_empty():
					rs._on_spot_changed("red", 4)
					rs._on_spot_changed("straight:17", 2)
					rs._on_spot_changed("split:17-20", 1)
					rs._on_spot_changed("corner:1", 2)
					rs.ctl.ensure_some_bet()
					rs._refresh_table()
					await _shot("bets")
				rs._on_spin_pressed()
				await _wait(RELEASE_DELAY)
				await _shot("aim")
				rs._on_spin_pressed()
				# Mini-jeu : élan arrêté au centre de la jauge, lâcher au contact de l'anneau.
				await _throw_minigame(rs)
				await _wait(1.2)
				await _shot("ball")
			RunScreen.UiState.THROWING:
				await _throw_minigame(rs)
			RunScreen.UiState.SCORING:
				await _wait(0.6)
				await _shot("scoring")
				while rs.state == RunScreen.UiState.SCORING:
					await _wait(POLL)
				done += 1
				if GameState.has_active_run():
					var rr: RunState = rs.ctl.run
					print(
						(
							"Autoplay : tour %d · palier %d · échéance %d · %d / %d"
							% [done, rr.tier, rr.deadline_idx, rr.deadline_score, rr.debt]
						)
					)
			RunScreen.UiState.RETHROW:
				rs._on_keep()
			RunScreen.UiState.OVERLAY:
				await _shot("overlay")
				var o: Node = (
					rs.overlay_root.get_child(rs.overlay_root.get_child_count() - 1) if rs.overlay_root.get_child_count() > 0 else null
				)
				if o != null and o.has_method("_finish"):
					o.call("_finish")
				elif o is Overlay:
					if o is PactOverlay:
						(o as PactOverlay)._decline()
					elif o is EventOverlay:
						(o as EventOverlay)._pick(0)
					else:
						(o as Overlay).close()
				await _wait(0.5)
			_:
				await _wait(POLL)
	print("Autoplay terminé : %d tours" % done)
	_perf_report()
	GameState.quit_game()
