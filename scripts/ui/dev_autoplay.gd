class_name DevAutoplay
extends Node
## Pilote automatique de l'interface (QA) : pose des mises, lance, relâche, enchaîne
## boutique / pacte, prend des captures. Activé par `-- --dev-autoplay=N [--shot-dir=...]`.

const RELEASE_DELAY: float = 0.9
const POLL: float = 0.1

var spins_wanted: int = 3
var shot_dir: String = ""
var _shots: int = 0


func _ready() -> void:
	_drive()


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
	img.save_png(shot_dir.path_join("%02d_%s.png" % [_shots, tag]))


func _drive() -> void:
	await _wait(1.5)
	var done: int = 0
	var guard: int = 0
	while done < spins_wanted and guard < 2000:
		guard += 1
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
					await _shot("bets")
				rs._on_spin_pressed()
				await _wait(RELEASE_DELAY)
				await _shot("aim")
				rs._on_spin_pressed()
				await _wait(1.2)
				await _shot("ball")
			RunScreen.UiState.SCORING:
				await _wait(0.6)
				await _shot("scoring")
				while rs.state == RunScreen.UiState.SCORING:
					await _wait(POLL)
				done += 1
				print("Autoplay : tour %d terminé, score échéance %d / %d" % [done, rs.ctl.run.deadline_score, rs.ctl.run.debt])
			RunScreen.UiState.RETHROW:
				rs._on_keep()
			RunScreen.UiState.OVERLAY:
				await _shot("overlay")
				var o: Node = rs.overlay_root.get_child(rs.overlay_root.get_child_count() - 1) if rs.overlay_root.get_child_count() > 0 else null
				if o is Overlay:
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
	get_tree().quit()
