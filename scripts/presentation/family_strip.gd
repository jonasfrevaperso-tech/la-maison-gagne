class_name FamilyStrip
extends HBoxContainer
## Rangée des familles (builds) de la partie, à côté de « Tes grigris » : une pastille par
## famille possédée avec sa progression vers le palier suivant. Survol : détail des paliers.

var run: RunState = null
var _chips: Dictionary[String, FamilyChip] = {}
## Paliers vus au dernier rafraîchissement (pour annoncer un palier franchi).
var _last_tiers: Dictionary = {}
var _seen_run: RunState = null


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_PASS


func bind(p_run: RunState) -> void:
	run = p_run
	refresh()


func refresh() -> void:
	for c: Node in get_children():
		c.queue_free()
	_chips.clear()
	if run == null:
		return
	var counts: Dictionary = Families.counts(run, DataRegistry.db)
	_announce(counts)
	var ids: Array = counts.keys()
	# Les builds les plus avancés d'abord.
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return int(counts[a]) > int(counts[b]))
	for fid: Variant in ids:
		var chip: FamilyChip = FamilyChip.new()
		chip.setup(String(fid), int(counts[fid]))
		add_child(chip)
		_chips[String(fid)] = chip


## Centre d'une pastille, en coordonnées du canevas de jeu (pour les nombres flottants).
func chip_center(fid: String) -> Vector2:
	var c: FamilyChip = _chips.get(fid, null)
	if c == null:
		return UiLayout.canvas_point(self, size * 0.5)
	return UiLayout.canvas_point(c, c.size * 0.5)


func bump(fid: String) -> void:
	var c: FamilyChip = _chips.get(fid, null)
	if c != null:
		c.bump()


## Annonce les paliers franchis depuis le dernier rafraîchissement (pas au chargement).
func _announce(counts: Dictionary) -> void:
	var tiers: Dictionary = {}
	for fid: Variant in counts.keys():
		tiers[fid] = Families.tier_index(FamilyUi.def(String(fid)), int(counts[fid]))
	if run == _seen_run:
		for fid: Variant in tiers.keys():
			if int(tiers[fid]) > int(_last_tiers.get(fid, -1)):
				EventBus.toast.emit(tr("FAMILY_TIER_UP") % FamilyUi.tier_text(String(fid), int(tiers[fid])), &"success")
				AudioBus.play("chime", 1.2, -2.0)
	_seen_run = run
	_last_tiers = tiers
