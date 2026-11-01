class_name UiLayout
extends RefCounted
## Mise en page multi-résolution. Les écrans à positions fixes sont conçus sur une scène
## de référence 1920×1080 (16:9) ; `fit_stage` la centre et la met à l'échelle dans la
## fenêtre logique (étirement `canvas_items` + `expand`) : 16:9 à toute définition
## (720p, 1080p, 1440p, 4K), 16:10 (Steam Deck 1280×800) et ultra-larges sans débordement.

const DESIGN_SIZE: Vector2 = Vector2(1920, 1080)
## Résolutions proposées en fenêtré (filtrées selon l'écran).
const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1280, 800),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]
const DEFAULT_WINDOW: Vector2i = Vector2i(1600, 900)
## Marge laissée autour d'une fenêtre pour les barres du bureau.
const DESKTOP_MARGIN: Vector2i = Vector2i(0, 80)


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


## Résolutions fenêtrées utilisables sur un écran donné (toujours au moins la plus petite).
static func window_sizes_for(screen: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r: Vector2i in WINDOW_SIZES:
		if r.x <= screen.x - DESKTOP_MARGIN.x and r.y <= screen.y - DESKTOP_MARGIN.y:
			out.append(r)
	if out.is_empty():
		out.append(WINDOW_SIZES[0])
	return out
