extends Node
## Bus d'événements global à signaux typés (présentation ↔ état).

@warning_ignore_start("unused_signal")
signal screen_requested(screen_id: StringName, params: Dictionary)
signal run_started(run: RunState)
signal run_loaded(run: RunState)
signal run_ended(run: RunState, victory: bool)
signal bet_changed(slip: BetSlip)
signal bet_rejected(spot_id: String, reason: int)
signal throw_started(target_index: int)
signal throw_resolved(result: ThrowResolver.ThrowResult)
signal spin_resolved(outcome: RunController.SpinOutcome)
signal score_event_played(event: ScoreEvent)
signal score_presentation_finished(total: int)
signal deadline_started(tier: int, deadline_idx: int)
signal deadline_won(reward: Dictionary)
signal deadline_failed
signal shop_changed
signal grigris_changed
signal wheel_changed
signal money_changed(money: int)
signal fortune_used(fortune_id: String)
signal settings_changed
signal achievement_unlocked(achievement_id: String)
signal toast(text: String, kind: StringName)
signal juice_shake(intensity: float)
signal juice_flash(color: Color, intensity: float)
signal juice_hitstop(duration: float)
signal subtitle(text: String)
signal input_device_changed(using_pad: bool)
signal note_requested
@warning_ignore_restore("unused_signal")
