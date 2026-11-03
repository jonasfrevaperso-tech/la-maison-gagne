class_name ArcadeKit
extends RefCounted
## Dessin commun des épreuves « borne d'arcade » du Grand Zéro (Envahisseurs, Cave) : caisson
## en bois laqué, fronton lumineux, écran cathodique bombé avec lignes de balayage.

const BEZEL: float = 34.0
const SCANLINE_STEP: float = 4.0
const WOOD: Color = Color("3a1c12")
const WOOD_LIGHT: Color = Color("5c2e1c")
const SCREEN_BG: Color = Color("06040c")


## Salle d'arcade du sous-sol : moquette à motifs, bornes voisines éteintes, néons au mur.
static func room(ci: CanvasItem, size: Vector2, t: float) -> void:
	ci.draw_rect(Rect2(-size.x, 0, size.x * 3.0, size.y), Color("120a1c"))
	ci.draw_rect(Rect2(-size.x, size.y * 0.82, size.x * 3.0, size.y * 0.18), Color("1c0f2a"))
	var step: float = 64.0
	var x: float = -size.x
	while x < size.x * 2.0:
		var c: Color = Palette.MAGENTA if int(x / step) % 3 == 0 else Palette.CYAN
		ci.draw_rect(Rect2(x, size.y * 0.86, 10, 10), Color(c, 0.25))
		x += step
	for k: int in 6:
		var bx: float = -size.x * 0.5 + float(k) * 560.0
		if absf(bx + 130.0 - size.x * 0.5) < 700.0:
			continue
		ci.draw_rect(Rect2(bx, size.y * 0.3, 260, size.y * 0.56), Color("0a0612"))
		ci.draw_rect(Rect2(bx + 30, size.y * 0.36, 200, 150), Color(Palette.CYAN, 0.05 + 0.03 * sin(t * 2.0 + k)))
	ci.draw_rect(Rect2(-size.x, size.y * 0.12, size.x * 3.0, 4), Color(Palette.MAGENTA, 0.35 + 0.15 * sin(t * 3.0)))


## Caisson et fronton autour de `screen` ; `title` sur le fronton, `glow` en 0..1 (clignotement).
static func cabinet(ci: CanvasItem, screen: Rect2, title: String, glow: float) -> void:
	var outer: Rect2 = screen.grow(BEZEL)
	ci.draw_rect(outer.grow(26.0), WOOD)
	ci.draw_rect(Rect2(outer.position - Vector2(26, 26), Vector2(outer.size.x + 52, 12)), WOOD_LIGHT)
	ci.draw_rect(outer, Color(0.02, 0.02, 0.03))
	ci.draw_rect(outer, Palette.GOLD_DARK, false, 3.0)
	# Fronton : bandeau néon au-dessus de l'écran.
	var marquee: Rect2 = Rect2(outer.position.x, outer.position.y - 96.0, outer.size.x, 70.0)
	ci.draw_rect(marquee, Color(0.08, 0.02, 0.08))
	ci.draw_rect(marquee, Color(Palette.MAGENTA, 0.5 + 0.5 * glow), false, 3.0)
	var f: Font = UiKit.font("display")
	var fs: int = UiKit.fs(UiKit.SIZE_H2)
	var w: float = f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at: Vector2 = Vector2(marquee.get_center().x - w * 0.5, marquee.get_center().y + fs * 0.35)
	ci.draw_string_outline(f, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(Palette.MAGENTA, 0.35 * glow))
	ci.draw_string(f, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.GOLD_LIGHT.lerp(Palette.IVORY, glow * 0.4))
	ci.draw_rect(screen, SCREEN_BG)


## Lignes de balayage et reflet du verre bombé, par-dessus le jeu.
static func glass(ci: CanvasItem, screen: Rect2) -> void:
	var y: float = screen.position.y
	while y < screen.end.y:
		ci.draw_line(Vector2(screen.position.x, y), Vector2(screen.end.x, y), Color(0, 0, 0, 0.18), 1.0)
		y += SCANLINE_STEP
	ci.draw_rect(Rect2(screen.position, Vector2(screen.size.x, screen.size.y * 0.16)), Color(1, 1, 1, 0.035))
	ci.draw_rect(screen, Color(Palette.CYAN, 0.25), false, 2.0)


## Bloc de pixels d'un motif (lignes de caractères, « # » = plein) en `cell` px.
static func sprite(ci: CanvasItem, at: Vector2, rows: Array[String], cell: float, col: Color) -> void:
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			if row[x] == "#":
				ci.draw_rect(Rect2(at + Vector2(x, y) * cell, Vector2(cell, cell)), col)
