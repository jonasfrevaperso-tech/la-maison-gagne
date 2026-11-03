class_name RenderQuality
extends RefCounted
## Qualité du rendu 3D, en un seul endroit.
## PC : réglages graphiques détaillés (Options › Vidéo › Graphismes), regroupés en préréglages
## (Bas, Moyen, Élevé, Ultra, Steam Deck) ; chaque vue 3D passe par `configure`.
## Mobile : trois niveaux (`video/quality` : eco / balanced / high), abaissés si besoin par le
## FrameGovernor (`governed`), et Économie imposée sous le moteur de compatibilité (OpenGL).

## Échelle du rendu 3D par niveau mobile.
const MOBILE_SCALE: Dictionary[String, float] = {"eco": 0.5, "balanced": 0.7, "high": 0.9}

## Mobile : la roue, pièce maîtresse, garde plus de définition que les autres vues.
const HERO_MOBILE_SCALE: Dictionary[String, float] = {"eco": 0.7, "balanced": 0.85, "high": 1.0}
## PC : réglages fins couverts par un préréglage (toucher l'un d'eux passe en « Personnalisé »).
const PRESET_KEYS: Array[String] = [
	"scaling", "render_scale", "fsr_sharpness", "msaa", "post_aa", "shadows", "aniso", "ssao", "particles"
]
const PRESET_NAMES: Array[String] = ["low", "medium", "high", "ultra", "deck", "custom"]
const PRESETS: Dictionary = {
	"low": {
		"scaling": "fsr1", "render_scale": 0.67, "fsr_sharpness": 0.8, "msaa": 0, "post_aa": "fxaa",
		"shadows": "off", "aniso": 2, "ssao": false, "particles": "low",
	},
	"medium": {
		"scaling": "fsr1", "render_scale": 0.77, "fsr_sharpness": 0.8, "msaa": 2, "post_aa": "none",
		"shadows": "low", "aniso": 4, "ssao": false, "particles": "medium",
	},
	"high": {
		"scaling": "bilinear", "render_scale": 1.0, "fsr_sharpness": 0.8, "msaa": 4, "post_aa": "none",
		"shadows": "medium", "aniso": 8, "ssao": false, "particles": "high",
	},
	"ultra": {
		"scaling": "bilinear", "render_scale": 1.0, "fsr_sharpness": 0.8, "msaa": 8, "post_aa": "none",
		"shadows": "high", "aniso": 16, "ssao": true, "particles": "high",
	},
	"deck": {
		"scaling": "fsr1", "render_scale": 0.7, "fsr_sharpness": 0.8, "msaa": 2, "post_aa": "none",
		"shadows": "off", "aniso": 4, "ssao": false, "particles": "medium",
	},
}
const SCALING_MODES: Dictionary = {
	"bilinear": Viewport.SCALING_3D_MODE_BILINEAR, "fsr1": Viewport.SCALING_3D_MODE_FSR, "fsr2": Viewport.SCALING_3D_MODE_FSR2,
}
const MSAA_MODES: Dictionary = {0: Viewport.MSAA_DISABLED, 2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X, 8: Viewport.MSAA_8X}
const ANISO_MODES: Dictionary = {
	0: Viewport.ANISOTROPY_DISABLED, 2: Viewport.ANISOTROPY_2X, 4: Viewport.ANISOTROPY_4X,
	8: Viewport.ANISOTROPY_8X, 16: Viewport.ANISOTROPY_16X,
}
## Ombres : taille des atlas (ponctuelles et directionnelle) et filtrage des ombres douces.
const SHADOW_ATLAS: Dictionary = {"low": 1024, "medium": 2048, "high": 4096}
const SHADOW_SOFT: Dictionary = {
	"low": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, "medium": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
	"high": RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
}
## Densité des particules (part de la quantité de référence).
const PARTICLE_SHARE: Dictionary = {"low": 0.35, "medium": 0.65, "high": 1.0}
const MOBILE_LIGHT_PARTICLES: float = 0.45
const SHARPNESS_RANGE: float = 2.0

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


## Ombres portées : selon le réglage sur PC, mobile « Beau » seulement.
static func shadows() -> bool:
	if not Platform.is_mobile():
		return Settings.s("video", "shadows") != "off"
	return level() == "high"


## Valeur « complète » ou « allégée » selon le niveau (mobile « Beau » = complète).
static func pick(full_value: Variant, light_value: Variant) -> Variant:
	var lv: String = level()
	return full_value if lv == "pc" or lv == "high" else light_value


## Antialiasing 3D : réglage MSAA sur PC ; aucun / 2x sur mobile (`full_msaa` réservé au « Beau »).
static func msaa(full_msaa: Viewport.MSAA, _light_msaa: Viewport.MSAA = Viewport.MSAA_DISABLED) -> Viewport.MSAA:
	if not Platform.is_mobile():
		return MSAA_MODES.get(int(Settings.get_value("video", "msaa")), Viewport.MSAA_DISABLED) as Viewport.MSAA
	return Viewport.MSAA_2X if level() == "high" and full_msaa != Viewport.MSAA_DISABLED else Viewport.MSAA_DISABLED


## Échelle de rendu 3D : réglage sur PC, selon le niveau sur mobile.
static func scale_3d(_unused: float = 1.0) -> float:
	if not Platform.is_mobile():
		return clampf(Settings.f("video", "render_scale"), 0.5, 1.0)
	return MOBILE_SCALE[level()]


## Mode de mise à l'échelle 3D (PC). FSR 1 et 2 perdent la transparence du fond (constaté sous
## Godot 4.7 : fond noir) : les vues transparentes (roue, tapis, éclats) restent en bilinéaire.
static func scaling_mode(transparent: bool) -> Viewport.Scaling3DMode:
	if Platform.is_mobile() or transparent:
		return Viewport.SCALING_3D_MODE_BILINEAR
	return SCALING_MODES.get(Settings.s("video", "scaling"), Viewport.SCALING_3D_MODE_BILINEAR)


## Applique la qualité à une vue 3D (et à son environnement) : à rappeler sur `settings_changed`.
## `hero` : la roue (plus de définition et MSAA conservé sur mobile).
static func configure(vp: SubViewport, env: Environment = null, transparent: bool = false, hero: bool = false) -> void:
	if vp == null:
		return
	if Platform.is_mobile():
		var lv: String = level()
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = HERO_MOBILE_SCALE[lv] if hero else MOBILE_SCALE[lv]
		vp.msaa_3d = (Viewport.MSAA_DISABLED if lv == "eco" else Viewport.MSAA_2X) if hero else msaa(Viewport.MSAA_2X)
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		vp.use_taa = false
		if env != null:
			env.ssao_enabled = false
		return
	var mode: Viewport.Scaling3DMode = scaling_mode(transparent)
	var sc: float = scale_3d()
	vp.scaling_3d_mode = mode
	vp.scaling_3d_scale = sc
	vp.fsr_sharpness = SHARPNESS_RANGE * (1.0 - clampf(Settings.f("video", "fsr_sharpness"), 0.0, 1.0))
	# FSR calcule lui-même le biais de mipmap ; en bilinéaire on le compense à la main.
	vp.texture_mipmap_bias = log(sc) / log(2.0) if mode == Viewport.SCALING_3D_MODE_BILINEAR and sc < 1.0 else 0.0
	var fsr2: bool = mode == Viewport.SCALING_3D_MODE_FSR2
	var post: String = Settings.s("video", "post_aa")
	# FSR 2 fait son propre anticrénelage temporel : MSAA, FXAA et TAA s'effacent.
	vp.msaa_3d = Viewport.MSAA_DISABLED if fsr2 else msaa(Viewport.MSAA_4X)
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if post == "fxaa" and not fsr2 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = post == "taa" and not fsr2 and not transparent
	vp.anisotropic_filtering_level = ANISO_MODES.get(int(Settings.get_value("video", "aniso")), Viewport.ANISOTROPY_4X)
	vp.positional_shadow_atlas_size = int(SHADOW_ATLAS.get(Settings.s("video", "shadows"), 1024))
	if env != null:
		env.ssao_enabled = Settings.b("video", "ssao") and not transparent and not is_compat()


## Réglages globaux du moteur (ombres directionnelles, filtrage) : PC seulement.
static func apply_global() -> void:
	if Platform.is_mobile() or DisplayServer.get_name() == "headless":
		return
	var q: String = Settings.s("video", "shadows")
	if SHADOW_ATLAS.has(q):
		RenderingServer.directional_shadow_atlas_set_size(int(SHADOW_ATLAS[q]), true)
		RenderingServer.directional_soft_shadow_filter_set_quality(SHADOW_SOFT[q] as RenderingServer.ShadowQuality)
		RenderingServer.positional_soft_shadow_filter_set_quality(SHADOW_SOFT[q] as RenderingServer.ShadowQuality)


## Nombre de particules pour une quantité de référence `full_amount`.
static func particles(full_amount: int) -> int:
	if Platform.is_mobile():
		return full_amount if level() == "high" else maxi(1, roundi(full_amount * MOBILE_LIGHT_PARTICLES))
	return maxi(1, roundi(full_amount * float(PARTICLE_SHARE.get(Settings.s("video", "particles"), 1.0))))


## Valeurs d'un préréglage (vide pour « custom » ou un nom inconnu).
static func preset_values(preset: String) -> Dictionary:
	return PRESETS.get(preset, {}) as Dictionary


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
