extends TestCase
## 1.3 : mini-jeu de lancer (notation, effet borné sur le contrôle, neutralité de référence).


func _near(a: float, b: float, msg: String) -> void:
	check(absf(a - b) < 0.0001, "%s (%.4f ≠ %.4f)" % [msg, a, b])


func test_control_bonus_is_bounded_and_neutral_at_reference() -> void:
	var ref: float = ThrowSkill.reference_quality()
	_near(ThrowSkill.control_bonus(ThrowSkill.NEUTRAL), 0.0, "lancer simplifié : aucun effet")
	_near(ThrowSkill.control_bonus(ref), 0.0, "lancer de référence : aucun effet")
	_near(ThrowSkill.control_bonus(1.0), Balance.f("throw_game.control_up"), "lancer parfait : bonus maximal")
	_near(ThrowSkill.control_bonus(0.0), -Balance.f("throw_game.control_down"), "lancer raté : malus maximal")
	check(ThrowSkill.control_bonus(0.8) > ThrowSkill.control_bonus(0.7), "monotone")


func test_power_and_release_scores() -> void:
	var half: float = ThrowSkill.sweet_half(1, false)
	_near(ThrowSkill.power_score(0.5, half), 1.0, "centre de la jauge : parfait")
	_near(ThrowSkill.power_score(0.5 + half, half), ThrowSkill.EDGE_SCORE, "bord de la zone dorée")
	_near(ThrowSkill.power_score(0.0, half), 0.0, "bout de la jauge : nul")
	check(ThrowSkill.sweet_half(7, false) > half, "la Précision élargit la zone")
	check(ThrowSkill.sweet_half(1, true) > half, "l'assistance élargit la zone")
	_near(ThrowSkill.release_score(0.0, false), 1.0, "lâcher pile : parfait")
	_near(ThrowSkill.release_score(1.0, false), 0.0, "lâcher très en retard : nul")
	eq(ThrowSkill.grade(1.0), ThrowSkill.Grade.PERFECT, "note parfaite")
	eq(ThrowSkill.grade(0.0), ThrowSkill.Grade.MISS, "note ratée")
	_near(ThrowSkill.charge_level(0.0), 0.0, "la jauge part de zéro")
	_near(ThrowSkill.charge_level(Balance.f("throw_game.charge_seconds")), 1.0, "pleine au bout de la charge")
	check(ThrowSkill.charge_level(Balance.f("throw_game.charge_seconds") * 0.5) < 0.5, "la charge accélère")
	_near(ThrowSkill.charge_level(Balance.f("throw_game.charge_seconds") * 2.0), 0.0, "puis redescend")


func test_v14_three_beats() -> void:
	var c: float = ThrowSkill.sweet_center(0.5)
	var half: float = ThrowSkill.sweet_half(1, false)
	_near(ThrowSkill.power_score(c, half, c), 1.0, "zone dorée déplacée : parfait en son centre")
	check(ThrowSkill.power_score(0.5, half, ThrowSkill.sweet_center(1.0)) < ThrowSkill.EDGE_SCORE, "hors zone")
	_near(ThrowSkill.tap_score(0.0, false), 1.0, "invite frappée pile")
	_near(ThrowSkill.tap_score(ThrowSkill.tap_window(false), false), 0.0, "invite au bord de la fenêtre : nulle")
	_near(ThrowSkill.spin_score([1.0, 0.0, 1.0, 0.0] as Array[float]), 0.5, "effet = moyenne des invites")
	_near(ThrowSkill.quality([1.0, 1.0] as Array[float], 1.0), 1.0, "trois gestes parfaits")
	_near(ThrowSkill.quality([0.0, 0.0] as Array[float], 0.0), 0.0, "trois gestes ratés")
	_near(ThrowSkill.quality([1.0, 0.0] as Array[float], 0.5), 0.5, "moyenne des épreuves et lâcher")
	_near(ThrowSkill.ring_progress(0.0, 1.0), 1.0, "anneau au départ")
	_near(ThrowSkill.ring_progress(1.0, 1.0), 0.0, "anneau au contact")
	check(ThrowSkill.ring_progress(0.5, 1.0) > 0.5, "l'anneau accélère vers la fin")
	eq(ThrowSkill.slot_spins(1.0), 3, "Parfait : trois tirages")
	eq(ThrowSkill.slot_spins(0.75), 2, "Très bien : deux tirages")
	eq(ThrowSkill.slot_spins(0.2), 1, "sinon un tirage")
	eq(ThrowSkill.slot_spins(ThrowSkill.NEUTRAL), 1, "mode Simple : un tirage")


func test_reference_throw_matches_previous_distribution() -> void:
	var c: RunController = RunController.new(ContentDB.shared())
	c.new_run("lea", 0, 11)
	var base: Array[float] = ThrowResolver.distribution(c.run.wheel.size(), c.throw_params(4))
	var ref: Array[float] = ThrowResolver.distribution(c.run.wheel.size(), c.throw_params(4, ThrowSkill.reference_quality()))
	eq(ref, base, "la référence reproduit exactement le lancer de la 1.2")
	var good: Array[float] = ThrowResolver.distribution(c.run.wheel.size(), c.throw_params(4, 1.0))
	check(good[4] > base[4], "un lancer parfait concentre la bille sur la cible")
	c.place_bet("red", 1)
	var res: ThrowResolver.ThrowResult = c.throw_ball(4, 0.9)
	_near(res.skill, 0.9, "la qualité est conservée dans le résultat")
