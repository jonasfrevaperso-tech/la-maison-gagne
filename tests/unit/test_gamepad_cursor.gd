extends TestCase
## Curseur de tapis à la manette : déplacement, bornes, cycle des paris intérieurs.


func test_cursor_moves_and_cycles() -> void:
	var t: TableView = TableView.new()
	t.move_cursor(0, 0)
	eq(t.cursor_spot(), "straight:1", "départ sur le 1")
	t.move_cursor(-5, 0)
	eq(t.cursor_spot(), "straight:0", "bord gauche = zéro")
	t.move_cursor(20, -5)
	eq(t.cursor_spot(), "column:2", "coin haut droit = colonne 3")
	t.move_cursor(-20, 1)
	t.move_cursor(1, 0)
	eq(t.cursor_spot(), "straight:2", "rangée du milieu")
	t.cycle_cursor(1)
	var s: BetSpot = BetCatalog.get_spot(t.cursor_spot())
	check(s.kind == &"split" and s.covers(2), "premier cycle = cheval couvrant 2")
	t.move_cursor(0, 5)
	check(t.cursor_spot() in TableView.EVEN_ORDER, "dernière rangée = chances simples")
	t.free()
