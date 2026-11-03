class_name Platform
extends RefCounted
## Où tourne le jeu : seul point d'entrée pour les adaptations mobiles (Android).
## Une version PC ne prend jamais ces chemins : `is_mobile()` n'est vrai que dans un export
## portant l'étiquette « mobile » (préréglage Android), ou en émulation de développement
## (`-- --dev-mobile[=LxH]`, sources uniquement). Les tests peuvent forcer le profil (`force`).

## Poinçon de caméra simulé en émulation (pixels physiques, bord gauche en paysage).
const DEV_CUTOUT_PX: int = 110
## Taille d'écran émulée par défaut : Pixel 7 en paysage.
const DEV_DEFAULT_SIZE: Vector2i = Vector2i(2400, 1080)
const DP_BASE_DPI: float = 160.0
## Densité supposée en émulation (Pixel 7 : 420 dpi).
const DEV_DPI: int = 420
## Décalage audio maximal (ms) : au-delà, la mesure du système est jugée aberrante.
const AUDIO_OFFSET_MAX_MS: float = 250.0

## -1 : détection normale ; 0 / 1 : profil PC / mobile imposé (tests).
static var force: int = -1


static func is_mobile() -> bool:
	if force >= 0:
		return force == 1
	return OS.has_feature("mobile") or is_emulated()


static func is_android() -> bool:
	return OS.has_feature("android")


## Émulation mobile sur PC (session de développement).
static func is_emulated() -> bool:
	return DevMode.available() and DevMode.args().has("dev-mobile")


## Taille d'écran émulée (`--dev-mobile=2340x1080`), Pixel 7 par défaut.
static func emulated_size() -> Vector2i:
	var raw: String = String(DevMode.args().get("dev-mobile", "true"))
	if raw == "true":
		return DEV_DEFAULT_SIZE
	var s: Vector2i = Settings.parse_size(raw)
	return s if s.x > 0 and s.y > 0 else DEV_DEFAULT_SIZE


static func has_touch() -> bool:
	return is_mobile() or DisplayServer.is_touchscreen_available()


## Zone utile en coordonnées du canevas racine (hors poinçon, encoches et barre de gestes).
## Sur PC : tout l'écran.
static func safe_rect(viewport: Viewport) -> Rect2:
	var full: Rect2 = viewport.get_visible_rect()
	if not is_mobile():
		return full
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or win.y <= 0.0:
		return full
	var k: Vector2 = full.size / win
	if is_emulated() or force == 1:
		# Poinçon simulé, proportionnel à l'écran émulé.
		var es: Vector2 = Vector2(emulated_size()) if is_emulated() else win
		var cut: float = float(DEV_CUTOUT_PX) / es.x * full.size.x
		return Rect2(full.position + Vector2(cut, 0.0), full.size - Vector2(cut, 0.0))
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var origin: Vector2 = Vector2(DisplayServer.window_get_position())
	var r: Rect2 = Rect2((Vector2(safe.position) - origin) * k, Vector2(safe.size) * k)
	r = r.intersection(full)
	return r if r.size.x > full.size.x * 0.5 and r.size.y > full.size.y * 0.5 else full


## Marges de la zone sûre (gauche, haut, droite, bas) en coordonnées du canevas.
static func safe_margins(viewport: Viewport) -> Rect2:
	var full: Rect2 = viewport.get_visible_rect()
	var s: Rect2 = safe_rect(viewport)
	return Rect2(s.position.x - full.position.x, s.position.y - full.position.y, full.end.x - s.end.x, full.end.y - s.end.y)


## `n` dp en pixels du canevas racine.
static func dp(viewport: Viewport, n: float) -> float:
	var dpi: float = float(DEV_DPI if is_emulated() else DisplayServer.screen_get_dpi())
	if dpi <= 0.0:
		dpi = DP_BASE_DPI
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	var phys_per_logical: float = 1.0
	if win.y > 0.0:
		var logical: Vector2 = viewport.get_visible_rect().size
		phys_per_logical = win.y / logical.y
		if is_emulated():
			phys_per_logical = float(emulated_size().y) / logical.y
	return n * dpi / DP_BASE_DPI / phys_per_logical


## Petite vibration (si le réglage l'autorise ; sans effet sur PC).
static func haptic(ms: int) -> void:
	if not is_android() or not Settings.b("game", "haptics"):
		return
	Input.vibrate_handheld(ms)


## Décalage audio (s) appliqué au jugement du rythme : le son sort du haut-parleur en retard.
## PC : 0 (inchangé). Téléphone : réglage `game/audio_offset_ms`, ou latence mesurée par le
## système (`AudioServer.get_output_latency`) tant qu'il vaut -1.
static func audio_offset() -> float:
	if not is_mobile():
		return 0.0
	var ms: float = float(Settings.get_value("game", "audio_offset_ms"))
	if ms < 0.0:
		return clampf(AudioServer.get_output_latency(), 0.0, AUDIO_OFFSET_MAX_MS / 1000.0)
	return ms / 1000.0
