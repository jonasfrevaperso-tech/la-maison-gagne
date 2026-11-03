class_name Warmup
extends RefCounted
## Chauffe du rendu, une fois par session, derrière le carton de chargement : chaque scène qui
## compile des pipelines graphiques à sa première apparition (épreuves 3D, machine à sous,
## carton d'acte, décors de bilan, éclats de jetons) est montée quelques images puis libérée.
## Sans elle, la première épreuve de chaque type gelait ≈ 140 ms (mesuré par HitchMonitor).

## Images rendues par scène (la première compile, la deuxième rend les effets différés).
const FRAMES_PER_ITEM: int = 3
## Le carton d'acte fait apparaître ses lignes en fondu : il reste (en secondes) jusqu'à ce
## qu'elles soient visibles (un texte transparent n'est pas dessiné, donc rien n'est compilé).
const ACT_TITLE_SECONDS: float = 1.0

## Les épreuves sont jouées par leur bot en accéléré pendant la chauffe : les effets qui
## n'apparaissent qu'en jouant (mousse, filet de liquide, éclats) compilent aussi leurs pipelines.
const TRIAL_FRAMES: int = 8
const TRIAL_STEP: float = 0.15
## Scènes chauffées ensemble.
const BATCH: int = 6

static var done: bool = false
static var _tick: Callable = Callable()


## `host` : contrôle plein écran sous les rideaux fermés. `progress` : Callable(float).
static func run(host: Control, progress: Callable) -> void:
	if done:
		progress.call(1.0)
		return
	done = true
	var t0: int = Time.get_ticks_msec()
	var before: int = HitchMonitor._pipeline_count()
	AudioBus.hush(true)
	var items: Array[Callable] = []
	for e: Dictionary in DataRegistry.db.list("throw_trials"):
		items.append(_trial.bind(e))
	items.append(_slot)
	items.append(_act_title)
	items.append(_backdrop)
	items.append(_chips)
	items.append(_cards)
	var tree: SceneTree = host.get_tree()
	# Par lots : les scènes d'un lot compilent ensemble (sur téléphone, une image coûte cher).
	var i: int = 0
	while i < items.size():
		var holders: Array[Control] = []
		var ticks: Array[Callable] = []
		var secs: float = 0.0
		for k: int in mini(BATCH, items.size() - i):
			var holder: Control = Control.new()
			holder.size = UiLayout.DESIGN_SIZE
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			host.add_child(holder)
			holders.append(holder)
			secs = maxf(secs, float((items[i + k] as Callable).call(holder)))
			if _tick.is_valid():
				ticks.append(_tick)
				_tick = Callable()
		i += holders.size()
		var t: int = Time.get_ticks_msec()
		for _f: int in FRAMES_PER_ITEM:
			await tree.process_frame
		if not ticks.is_empty():
			for _k: int in TRIAL_FRAMES:
				for tk: Callable in ticks:
					tk.call()
				await tree.process_frame
		while float(Time.get_ticks_msec() - t) < secs * 1000.0:
			await tree.process_frame
		for h: Control in holders:
			h.queue_free()
		progress.call(float(i) / float(items.size()))
	await tree.process_frame
	AudioBus.hush(false)
	print("Chauffe : %d scènes, %d pipelines, %d ms" % [
		items.size(), HitchMonitor._pipeline_count() - before, Time.get_ticks_msec() - t0
	])


static func _trial(holder: Control, e: Dictionary) -> float:
	var scr: GDScript = load(ThrowMinigame.TRIAL_SCRIPTS % String(e["id"])) as GDScript
	if scr == null:
		return 0.0
	var trial: ThrowTrial = (scr.new() as ThrowTrial).setup(e, 1, false, true)
	trial.size = ThrowMinigame.PANEL_RECT.size if not trial.full() else UiLayout.DESIGN_SIZE
	trial.position = Vector2.ZERO if trial.full() else ThrowMinigame.PANEL_RECT.position
	holder.add_child(trial)
	_tick = func() -> void:
		if is_instance_valid(trial) and not trial.finished:
			trial.act(trial.want())
			trial._process(TRIAL_STEP)
	return 0.0


static func _slot(holder: Control) -> float:
	var st: Stage3D = Stage3D.new()
	holder.add_child(st)
	var cab: SlotCabinet3D = SlotCabinet3D.new()
	st.root.add_child(cab)
	var ids: Array[String] = []
	for s: Dictionary in DataRegistry.db.list("slot_symbols"):
		ids.append(String(s["id"]))
	cab.build(ids, RngService.cosmetic())
	st.look(Vector3(0, 2.6, 7.5), Vector3(0, 1.6, 0), 40.0)
	return 0.0


static func _act_title(holder: Control) -> float:
	holder.add_child(ActTitle.new().configure(1))
	return ACT_TITLE_SECONDS


static func _backdrop(holder: Control) -> float:
	var bd: Control = VenueBackdrop3D.create("bazaar")
	holder.add_child(bd)
	bd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return 0.0


static func _chips(holder: Control) -> float:
	ChipBurst3D.spawn(holder, UiLayout.DESIGN_SIZE * 0.5, 6, false)
	ChipBurst3D.spawn(holder, UiLayout.DESIGN_SIZE * 0.5, 6, true)
	return 0.0


## Cartes du Bazar : une par édition (shader d'édition) plus un contrat.
static func _cards(holder: Control) -> float:
	var g: Array[Dictionary] = DataRegistry.db.list("grigris")
	if g.is_empty():
		return 0.0
	var x: float = 40.0
	for ed: String in [""] + GrigriCard.EDITION_MODES.keys():
		var card: GrigriCard = GrigriCard.new().configure("grigri", String(g[0]["id"]))
		card.edition = StringName(ed)
		card.price = 1
		card.position = Vector2(x, 40.0)
		x += GrigriCard.CARD_SIZE.x + 10.0
		holder.add_child(card)
	return 0.0
