class_name RenderQuality
extends RefCounted
## Qualité du rendu 3D, en un seul endroit.
## PC : rendu complet, ou allégé en mode portable (Steam Deck, `video/handheld`) — comportement
## identique aux versions précédentes.
## Mobile : trois niveaux (`video/quality` : eco / balanced / high), abaissés si besoin par le
## FrameGovernor (`governed`), et Économie imposée sous le moteur de compatibilité (OpenGL).

## Échelle du rendu 3D par niveau mobile.
const MOBILE_SCALE: Dictionary[String, float] = {"eco": 0.5, "balanced": 0.7, "high": 0.9}

## Niveau imposé par le FrameGovernor pour la session ("" : aucun).
static var governed: String = ""
## Nombre de couvertures opaques plein écran (épreuve plein écran, boutique…) : les scènes 3D
## de la table, cachées dessous, cessent d'être rendues.
static var _covers: int = 0


## « pc », « handheld », ou un niveau mobile.
static func level() -> String:
	if not Platform.is_mobile():
		return "handheld" if Settings.b("video", "handheld") else "pc"
	if is_compat():
		return "eco"
	var q: String = Settings.s("video", "quality")
	if not MOBILE_SCALE.has(q):
		q = "balanced"
	if governed != "" and Settings.QUALITY_LEVELS.find(governed) < Settings.QUALITY_LEVELS.find(q):
		q = governed
	return q


static func is_compat() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


## Rendu complet (PC hors mode portable) ?
static func full() -> bool:
	return level() == "pc"


## Ombres portées : PC complet et mobile « Beau ».
static func shadows() -> bool:
	var lv: String = level()
	return lv == "pc" or lv == "high"


## Valeur « complète » ou « allégée » selon le niveau (mobile « Beau » = complète).
static func pick(full_value: Variant, light_value: Variant) -> Variant:
	var lv: String = level()
	return full_value if lv == "pc" or lv == "high" else light_value


## Antialiasing 3D : `full_msaa` sur PC, `light_msaa` en portable, aucun / 2x sur mobile.
static func msaa(full_msaa: Viewport.MSAA, light_msaa: Viewport.MSAA) -> Viewport.MSAA:
	match level():
		"pc":
			return full_msaa
		"handheld":
			return light_msaa
		"high":
			return Viewport.MSAA_2X
	return Viewport.MSAA_DISABLED


## Échelle de rendu 3D : 1 sur PC, `handheld_scale` en portable, selon le niveau sur mobile.
static func scale_3d(handheld_scale: float) -> float:
	var lv: String = level()
	if lv == "pc":
		return 1.0
	if lv == "handheld":
		return handheld_scale
	return MOBILE_SCALE[lv]


## Une surface opaque plein écran apparaît (vrai) ou disparaît (faux).
static func cover(on: bool) -> void:
	_covers = maxi(0, _covers + (1 if on else -1))


static func covered() -> bool:
	return _covers > 0


## À appeler à chaque image par une scène 3D de la table : rendu suspendu tant qu'elle est couverte.
static func sleep_if_covered(vp: SubViewport) -> void:
	var mode: SubViewport.UpdateMode = SubViewport.UPDATE_DISABLED if covered() else SubViewport.UPDATE_ALWAYS
	if vp != null and vp.render_target_update_mode != mode:
		vp.render_target_update_mode = mode
