extends TestCase
## Curseur de tapis à la manette : bornes et zones extrêmes (grille par demi-cases, 1.3).


func _table() -> TableView:
	var t: TableView = TableView.new()
	t.size = Vector2(1040, 360)
	t._layout()
	t.move_cursor(0, 0)
	return t


func test_cursor_bounds_and_edges() -> void:
	var t: TableView = _table()
	eq(t.cursor_spot(), "straight:2", "départ sur la rangée du milieu, première colonne")
	for _i: int in 4:
		t.move_cursor(-1, 0)
	eq(t.cursor_spot(), "straight:0", "tout à gauche : zéro")
	t.move_cursor(1, 0)
	check(t.cursor_spot().begins_with("split:0-"), "juste à droite du zéro : cheval avec le zéro (%s)" % t.cursor_spot())
	for _i: int in 40:
		t.move_cursor(1, 0)
	for _i: int in 6:
		t.move_cursor(0, -1)
	eq(t.cursor_spot(), "column:2", "coin haut droit : colonne du haut")
	for _i: int in 12:
		t.move_cursor(0, 1)
	check(t.cursor_spot() in TableView.EVEN_ORDER, "tout en bas : chances simples (%s)" % t.cursor_spot())
	for _i: int in 30:
		t.move_cursor(-1, 0)
	eq(t.cursor_spot(), "low", "chances simples, à gauche : manque")
	t.free()
