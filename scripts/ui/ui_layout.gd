class_name UiLayout
extends RefCounted
## Mise en page multi-résolution. Les écrans à positions fixes sont conçus sur une scène
## de référence 1920×1080 (16:9) ; `fit_stage` la centre et la met à l'échelle dans la
## fenêtre logique (étirement `canvas_items` + `expand`) : 16:9 à toute définition
## (720p, 1080p, 1440p, 4K), 16:10 (Steam Deck 1280×800) et ultra-larges sans débordement.

const DESIGN_SIZE: Vector2 = Vector2(1920, 1080)
## Définitions courantes en 2026 (Steam Hardware Survey, portables, ultra-larges) : proposées
## en fenêtré (si la fenêtre tient) et comme résolution de rendu en plein écran.
const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1280, 800),
	Vector2i(1366, 768),
	Vector2i(1440, 900),
	Vector2i(1600, 900),
	Vector2i(1680, 1050),
	Vector2i(1920, 1080),
	Vector2i(1920, 1200),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
	Vector2i(2560, 1600),
	Vector2i(2880, 1800),
	Vector2i(3440, 1440),
	Vector2i(3840, 1600),
	Vector2i(3840, 2160),
	Vector2i(5120, 1440),
	Vector2i(5120, 2880),
]
const DEFAULT_WINDOW: Vector2i = Vector2i(1600, 900)


## Échelle qui fait tenir la scène de référence dans `viewport` (jamais d'agrandissement :
## l'étirement du projet s'en charge déjà).
static func stage_scale(viewport: Vector2) -> float:
	return minf(1.0, minf(viewport.x / DESIGN_SIZE.x, viewport.y / DESIGN_SIZE.y))


## Place `stage` (taille DESIGN_SIZE) au centre de `viewport`, mise à l'échelle.
static func fit_stage(stage: Control, viewport: Vector2) -> void:
	var s: float = stage_scale(viewport)
	stage.size = DESIGN_SIZE
	stage.scale = Vector2(s, s)
	stage.position = ((viewport - DESIGN_SIZE * s) * 0.5).floor()


## Cadre plein écran des écrans : au moins DESIGN_SIZE dans chaque dimension (les écrans
## n'ont jamais moins de place que prévu), réduit uniformément si la fenêtre logique est plus
## petite (texte agrandi, petite fenêtre). Les fenêtres plus grandes gardent toute leur place.
static func fit_frame(frame: Control, viewport: Vector2) -> void:
	var s: float = stage_scale(viewport)
	frame.scale = Vector2(s, s)
	frame.position = Vector2.ZERO
	frame.size = viewport / s


## Rectangle d'un contrôle en coordonnées de canevas (tient compte des échelles parentes).
static func canvas_rect(c: Control) -> Rect2:
	return c.get_global_transform() * Rect2(Vector2.ZERO, c.size)


## Point local d'un contrôle en coordonnées de canevas.
static func canvas_point(c: Control, local: Vector2) -> Vector2:
	return c.get_global_transform() * local


## Résolutions fenêtrées utilisables sur un écran (taille de l'écran entier : une fenêtre de la
## taille de l'écran est permise, le bureau la recadre au besoin ; toujours au moins la plus petite).
static func window_sizes_for(screen: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r: Vector2i in WINDOW_SIZES:
		if r.x <= screen.x and r.y <= screen.y:
			out.append(r)
	if out.is_empty():
		out.append(WINDOW_SIZES[0])
	return out


## Résolutions de rendu en plein écran : celles qui ne dépassent pas l'écran (rendu puis mise à
## l'échelle), la native en tête.
static func render_sizes_for(screen: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r: Vector2i in WINDOW_SIZES:
		if r.x <= screen.x and r.y <= screen.y and r != screen:
			out.append(r)
	return out


## « 16:9 », « 16:10 », « 21:9 », « 32:9 » : format lisible d'une définition.
static func aspect_label(r: Vector2i) -> String:
	var a: float = float(r.x) / float(maxi(r.y, 1))
	var known: Dictionary[String, float] = {"16:9": 16.0 / 9.0, "16:10": 1.6, "21:9": 21.0 / 9.0, "32:9": 32.0 / 9.0, "4:3": 4.0 / 3.0}
	var best: String = ""
	var err: float = 1.0
	for k: String in known.keys():
		if absf(known[k] - a) < err:
			err = absf(known[k] - a)
			best = k
	return best if err < 0.08 else "%d:%d" % [r.x, r.y]
