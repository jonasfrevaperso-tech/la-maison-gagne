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
	_near(ThrowSkill.power_needle(0.0, 1.0), 0.0, "l'aiguille part du bord")
	_near(ThrowSkill.power_needle(0.5, 1.0), 1.0, "à mi-période, autre bord")


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
