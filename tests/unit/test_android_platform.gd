extends TestCase
## Android : profil de plateforme et qualité du rendu. Le profil PC ne doit jamais changer.


func _with(mobile: int, body: Callable) -> void:
	var before: int = Platform.force
	Platform.force = mobile
	body.call()
	Platform.force = before
	RenderQuality.governed = ""


func test_pc_profile_unchanged() -> void:
	_with(0, func() -> void:
		check(not Platform.is_mobile(), "PC : pas mobile")
		var hh: bool = Settings.b("video", "handheld")
		eq(RenderQuality.level(), "handheld" if hh else "pc", "PC : niveau historique")
		if not hh:
			eq(RenderQuality.scale_3d(0.7), 1.0, "PC : rendu 3D plein")
			eq(RenderQuality.msaa(Viewport.MSAA_4X, Viewport.MSAA_2X), Viewport.MSAA_4X, "PC : MSAA complet")
			check(RenderQuality.shadows(), "PC : ombres")
	)


func test_mobile_quality_levels() -> void:
	_with(1, func() -> void:
		var saved: String = Settings.s("video", "quality")
		Settings.set_value("video", "quality", "balanced")
		if not RenderQuality.is_compat():
			eq(RenderQuality.level(), "balanced", "mobile : niveau du réglage")
			eq(RenderQuality.scale_3d(0.7), 0.7, "Équilibré : 3D à 70 %")
			check(not RenderQuality.shadows(), "Équilibré : sans ombres")
			Settings.set_value("video", "quality", "high")
			check(RenderQuality.shadows(), "Beau : ombres")
			RenderQuality.governed = "eco"
			eq(RenderQuality.level(), "eco", "le gouverneur abaisse la qualité")
			eq(RenderQuality.msaa(Viewport.MSAA_4X, Viewport.MSAA_2X), Viewport.MSAA_DISABLED, "Économie : sans MSAA")
		Settings.set_value("video", "quality", saved)
	)


func test_cover_counter() -> void:
	check(not RenderQuality.covered(), "rien ne couvre au départ")
	RenderQuality.cover(true)
	RenderQuality.cover(true)
	RenderQuality.cover(false)
	check(RenderQuality.covered(), "encore une couverture")
	RenderQuality.cover(false)
	RenderQuality.cover(false)
	check(not RenderQuality.covered(), "compteur jamais négatif")


func test_safe_rect_on_pc_is_full_screen() -> void:
	_with(0, func() -> void:
		var vp: Viewport = Engine.get_main_loop().root if Engine.get_main_loop() is SceneTree else null
		if vp != null:
			eq(Platform.safe_rect(vp), vp.get_visible_rect(), "PC : tout l'écran est utile")
	)
