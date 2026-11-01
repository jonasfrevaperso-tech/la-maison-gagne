class_name PauseMenu
extends Overlay
## Menu en cours de run : reprendre, options rapides, graine, abandon.


func build() -> void:
	panel_width = 620.0
	cancel_closes = true
	heading(tr("PAUSE_TITLE"))
	var r: RunState = GameState.run()
	var seed_l: Label = UiKit.label(tr("PAUSE_SEED") % RngService.seed_to_code(r.rng.seed_value), UiKit.SIZE_BODY, Palette.CYAN, "mono")
	seed_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(seed_l)
	var resume: Button = UiKit.button(tr("PAUSE_RESUME"), close)
	resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(resume)
	var copy: Button = UiKit.button(tr("PAUSE_COPY_SEED"), _copy_seed)
	copy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(copy)
	var note_btn: Button = UiKit.button(tr("PAUSE_NOTE"), _note)
	PromptBadge.attach(note_btn, "playtest_note")
	note_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(note_btn)
	var quit_btn: Button = UiKit.button(tr("PAUSE_SAVE_QUIT"), _save_quit)
	quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(quit_btn)
	var abandon: Button = UiKit.button(tr("PAUSE_ABANDON"), _abandon)
	abandon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(abandon)
	resume.call_deferred("grab_focus")


func _note() -> void:
	close()
	EventBus.note_requested.emit()


func _copy_seed() -> void:
	DisplayServer.clipboard_set(RngService.seed_to_code(GameState.run().rng.seed_value))
	EventBus.toast.emit(tr("TOAST_SEED_COPIED"), &"success")


func _save_quit() -> void:
	GameState.autosave()
	GameState.controller = null
	GameState.goto(GameState.SCREEN_TITLE)


func _abandon() -> void:
	var dlg: ConfirmBox = ConfirmBox.new().configure(tr("CONFIRM_ABANDON"))
	dlg.confirmed.connect(_do_abandon)
	add_child(dlg)


func _do_abandon() -> void:
	GameState.end_run(false)
