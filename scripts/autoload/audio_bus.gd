extends Node
## Mixage par bus (Master, Music, SFX, UI, Ambience), SFX à variantes + pitch aléatoire,
## musique à couches dynamiques (les couches montent avec le Mult).
## Les fichiers sont cherchés dans res://audio/sfx/<id>_<n>.wav et res://audio/music/<id>_<couche>.ogg|wav.

const BUSES: Array[String] = ["Music", "SFX", "UI", "Ambience"]
const SFX_DIR: String = "res://audio/sfx/"
const MUSIC_DIR: String = "res://audio/music/"
const MIX_PATH: String = "res://audio/sfx_mix.json"
const POOL_SIZE: int = 24
const MAX_VARIANTS: int = 5
const PITCH_JITTER: float = 0.06
const MUSIC_LAYERS: int = 3
const FADE_TIME: float = 1.2
const SILENT_DB: float = -60.0
const DUCK_DB: float = -18.0
const COMPRESSOR_THRESHOLD_DB: float = -14.0
const COMPRESSOR_RATIO: float = 4.0
const SIDECHAIN_THRESHOLD_DB: float = -20.0
const SIDECHAIN_RATIO: float = 2.5

var _sfx_cache: Dictionary[String, Array] = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_next: int = 0
var _music_layers: Array[AudioStreamPlayer] = []
var _music_id: String = ""
var _intensity: float = 0.0
var _ambience: AudioStreamPlayer = null
## En headless (tests, simulation, CI), le pilote audio factice ne libère jamais les lectures.
var _silent: bool = false
var _hushed: bool = false
var _music_tweens: Array[Tween] = []
var _mix: Dictionary = {}
var _duck: float = 0.0
var _music_base_db: float = 0.0


func _ready() -> void:
	_silent = DisplayServer.get_name() == "headless"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MIX_PATH)) if FileAccess.file_exists(MIX_PATH) else null
	if parsed is Dictionary:
		_mix = parsed as Dictionary
	_ensure_buses()
	for i: int in POOL_SIZE:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for i: int in MUSIC_LAYERS:
		var m: AudioStreamPlayer = AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = SILENT_DB
		add_child(m)
		_music_layers.append(m)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Ambience"
	add_child(_ambience)
	apply_volumes()
	EventBus.settings_changed.connect(apply_volumes)


## Coupe les nouveaux sons (chauffe du rendu derrière le carton de chargement) ; jamais en headless.
func hush(on: bool) -> void:
	_hushed = on


## Arrête et détache tous les flux (évite des lectures orphelines à la fermeture).
func shutdown() -> void:
	_silent = true  # plus aucun son ne doit démarrer pendant la fermeture
	_music_id = ""
	for t: Tween in _music_tweens:
		if t != null and t.is_valid():
			t.kill()
	_music_tweens.clear()
	var players: Array[AudioStreamPlayer] = []
	players.append_array(_pool)
	players.append_array(_music_layers)
	players.append(_ambience)
	for p: AudioStreamPlayer in players:
		if p != null:
			p.stop()
			p.stream = null
	_sfx_cache.clear()


func _ensure_buses() -> void:
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	var master: int = AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var comp: AudioEffectCompressor = AudioEffectCompressor.new()
		comp.threshold = COMPRESSOR_THRESHOLD_DB
		comp.ratio = COMPRESSOR_RATIO
		AudioServer.add_bus_effect(master, comp)
	# Léger sidechain : la musique se tasse quand les SFX frappent.
	var music: int = AudioServer.get_bus_index("Music")
	if AudioServer.get_bus_effect_count(music) == 0:
		var sc: AudioEffectCompressor = AudioEffectCompressor.new()
		sc.threshold = SIDECHAIN_THRESHOLD_DB
		sc.ratio = SIDECHAIN_RATIO
		sc.sidechain = &"SFX"
		AudioServer.add_bus_effect(music, sc)


func apply_volumes() -> void:
	_set_bus_volume("Master", Settings.f("audio", "master"))
	_set_bus_volume("Music", Settings.f("audio", "music"))
	_set_bus_volume("SFX", Settings.f("audio", "sfx"))
	_set_bus_volume("UI", Settings.f("audio", "ui"))
	_set_bus_volume("Ambience", Settings.f("audio", "ambience"))


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		var db: float = linear_to_db(maxf(linear, 0.0001))
		if bus_name == "Music":
			_music_base_db = db
			db += _duck
		AudioServer.set_bus_volume_db(idx, db)


func _variants(sfx_id: String) -> Array:
	if _sfx_cache.has(sfx_id):
		return _sfx_cache[sfx_id]
	var list: Array = []
	for i: int in range(1, MAX_VARIANTS + 1):
		var path: String = "%s%s_%d.wav" % [SFX_DIR, sfx_id, i]
		if ResourceLoader.exists(path):
			list.append(load(path))
	if list.is_empty():
		var single: String = "%s%s.wav" % [SFX_DIR, sfx_id]
		if ResourceLoader.exists(single):
			list.append(load(single))
	_sfx_cache[sfx_id] = list
	return list


## Joue un SFX (variante et pitch aléatoires). `pitch` multiplie le pitch de base.
func play(sfx_id: String, pitch: float = 1.0, volume_db: float = 0.0, bus: String = "SFX") -> void:
	play_get(sfx_id, pitch, volume_db, bus)


## Comme play(), mais rend le lecteur (null si rien ne joue) : pour suivre ou modifier un son
## long en cours (vitesse d'un morceau). Le lecteur appartient à la réserve : vérifier que son
## `stream` est toujours celui qu'on a lancé avant d'y toucher.
func play_get(sfx_id: String, pitch: float = 1.0, volume_db: float = 0.0, bus: String = "SFX") -> AudioStreamPlayer:
	if _silent or _hushed:
		return null
	var v: Array = _variants(sfx_id)
	if v.is_empty():
		return null
	var rng: RandomNumberGenerator = RngService.cosmetic()
	var p: AudioStreamPlayer = _pool[_pool_next]
	_pool_next = (_pool_next + 1) % _pool.size()
	p.stream = v[rng.randi_range(0, v.size() - 1)] as AudioStream
	p.pitch_scale = maxf(pitch * (1.0 + rng.randf_range(-PITCH_JITTER, PITCH_JITTER)), 0.05)
	p.volume_db = volume_db + float(_mix.get(sfx_id, 0.0))
	p.bus = bus
	p.play()
	return p


## Identifiants de tous les effets sonores mixés (table d'écoute des options).
func sfx_ids() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in _mix.keys():
		if not String(k).begins_with("_"):
			out.append(String(k))
	out.sort()
	return out


func ui(sfx_id: String) -> void:
	play(sfx_id, 1.0, 0.0, "UI")


func _music_stream(music_id: String, layer: int) -> AudioStream:
	for ext: String in ["ogg", "wav"]:
		var path: String = "%s%s_%d.%s" % [MUSIC_DIR, music_id, layer, ext]
		if ResourceLoader.exists(path):
			return _looping(load(path) as AudioStream)
	return null


## Force le bouclage (OGG et WAV) quel que soit le réglage d'import.
func _looping(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var w: AudioStreamWAV = stream as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * float(w.mix_rate))
	return stream


func play_music(music_id: String) -> void:
	if _silent or music_id == _music_id:
		return
	_music_id = music_id
	for i: int in _music_layers.size():
		var player: AudioStreamPlayer = _music_layers[i]
		var stream: AudioStream = _music_stream(music_id, i)
		var tw: Tween = create_tween()
		tw.tween_property(player, "volume_db", SILENT_DB, FADE_TIME * 0.5)
		tw.tween_callback(_swap_layer.bind(player, stream, i))
		_music_tweens.append(tw)


func _swap_layer(player: AudioStreamPlayer, stream: AudioStream, layer: int) -> void:
	player.stop()
	player.stream = stream
	if stream == null:
		return
	player.play()
	var tw: Tween = create_tween()
	tw.tween_property(player, "volume_db", _layer_db(layer), FADE_TIME)


func _layer_db(layer: int) -> float:
	if layer == 0:
		return 0.0
	var threshold: float = float(layer) / float(MUSIC_LAYERS)
	return 0.0 if _intensity >= threshold else SILENT_DB


## Intensité 0..1 (pilotée par le Mult courant) : ajoute les couches musicales.
func set_intensity(v: float) -> void:
	_intensity = clampf(v, 0.0, 1.0)
	for i: int in range(1, _music_layers.size()):
		var target: float = _layer_db(i)
		if not is_equal_approx(_music_layers[i].volume_db, target):
			var tw: Tween = create_tween()
			tw.tween_property(_music_layers[i], "volume_db", target, FADE_TIME)


## Baisse la musique pendant une épreuve qui joue son propre morceau (mini-jeu de rythme).
func duck_music(on: bool) -> void:
	var idx: int = AudioServer.get_bus_index("Music")
	if idx < 0:
		return
	var tw: Tween = create_tween()
	var target: float = DUCK_DB if on else 0.0
	tw.tween_method(func(v: float) -> void: AudioServer.set_bus_volume_db(idx, _music_base_db + v), _duck, target, 0.4)
	_duck = target


func stop_ambience() -> void:
	if _ambience != null:
		_ambience.stop()
		_ambience.stream = null


## `db` : atténuation propre à la scène (la pluie de la cinématique reste en fond).
func play_ambience(amb_id: String, db: float = 0.0) -> void:
	if _silent:
		return
	_ambience.volume_db = db
	var path: String = "%s%s.wav" % [SFX_DIR, amb_id]
	if ResourceLoader.exists(path) and (_ambience.stream == null or _ambience.stream.resource_path != path):
		_ambience.stream = _looping(load(path) as AudioStream)
		_ambience.play()
