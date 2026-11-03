extends TestCase
## 1.8 « Le Musée » : correctifs (dialogues déjà vus, marquage des mises, blackjack).


## Un dialogue d'ouverture déjà vu ne rejoue que sa réplique à choix (son bonus compte en partie).
func test_seen_dialogue_keeps_only_choice() -> void:
	var db: ContentDB = ContentDB.shared()
	var intro: Dictionary = db.get_entry("dialogues", "act1_intro")
	check(DialogueOverlay.has_choices(intro), "act1_intro a un choix")
	check(not DialogueOverlay.has_choices(db.get_entry("dialogues", "act1_mid")), "act1_mid n'en a pas")
	var lines: Array = intro["lines"]
	var first: int = DialogueOverlay.next_choice(lines, 0)
	check(first < lines.size() and (lines[first] as Dictionary).has("choices"), "saute droit au choix")
	eq(DialogueOverlay.next_choice(lines, first + 1), lines.size(), "puis se termine")


## Blackjack : lire ses cartes pendant le délai de grâce ne coûte rien à la note.
func test_blackjack_grace_period() -> void:
	AudioBus.hush(true)
	var e: Dictionary = ContentDB.shared().get_entry("throw_trials", "blackjack")
	var scr: GDScript = load(ThrowMinigame.TRIAL_SCRIPTS % "blackjack") as GDScript
	var bj: TrialBlackjack = (scr.new() as TrialBlackjack).setup(e, 1, false, false) as TrialBlackjack
	bj.size = UiLayout.DESIGN_SIZE
	bj._player = [10, 10]
	bj._dealer = [6]
	bj._first = true
	bj._phase = "decide"
	bj._decide_t = bj.p("speed_grace") * 0.9
	bj.choose("stand")
	near(bj._marks[0], 1.0, 0.0001, "bonne décision dans le délai de grâce : note pleine")
	bj.free()
