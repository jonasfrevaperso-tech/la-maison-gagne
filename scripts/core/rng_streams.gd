class_name RngStreams
extends RefCounted
## Source de hasard unique et déterministe, séparée en flux indépendants.
## Un même seed reproduit exactement le même run (roue, boutique, effets),
## tandis que le flux cosmétique peut être consommé librement par la présentation.

const WHEEL: StringName = &"wheel"
const SHOP: StringName = &"shop"
const EFFECTS: StringName = &"effects"
const COSMETIC: StringName = &"cosmetic"
const EVENTS: StringName = &"events"
const STREAM_NAMES: Array[StringName] = [WHEEL, SHOP, EFFECTS, COSMETIC, EVENTS]

var seed_value: int = 0
var _streams: Dictionary[StringName, RandomNumberGenerator] = {}


func _init(p_seed: int = 0) -> void:
	reseed(p_seed)


func reseed(p_seed: int) -> void:
	seed_value = p_seed
	_streams.clear()
	for stream_name: StringName in STREAM_NAMES:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = hash(str(p_seed) + ":" + String(stream_name))
		_streams[stream_name] = rng


func stream(stream_name: StringName) -> RandomNumberGenerator:
	assert(_streams.has(stream_name), "Flux RNG inconnu : %s" % stream_name)
	return _streams[stream_name]


func randf_in(stream_name: StringName) -> float:
	return stream(stream_name).randf()


func randi_range_in(stream_name: StringName, from: int, to: int) -> int:
	return stream(stream_name).randi_range(from, to)


func chance(stream_name: StringName, probability: float) -> bool:
	return stream(stream_name).randf() < probability


## Tirage pondéré : renvoie l'index choisi dans `weights` (poids >= 0).
func weighted_index(stream_name: StringName, weights: Array[float]) -> int:
	var total: float = 0.0
	for w: float in weights:
		total += maxf(w, 0.0)
	if total <= 0.0:
		return -1
	var roll: float = stream(stream_name).randf() * total
	for i: int in weights.size():
		roll -= maxf(weights[i], 0.0)
		if roll < 0.0:
			return i
	return weights.size() - 1


func shuffle_in(stream_name: StringName, items: Array) -> void:
	var rng: RandomNumberGenerator = stream(stream_name)
	for i: int in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp


## Sérialise l'état exact de chaque flux (reprise de run à l'identique).
func to_dict() -> Dictionary:
	var states: Dictionary = {}
	for stream_name: StringName in STREAM_NAMES:
		states[String(stream_name)] = str(_streams[stream_name].state)
	return {"seed": seed_value, "states": states}


func from_dict(data: Dictionary) -> void:
	reseed(int(data.get("seed", 0)))
	var states: Dictionary = data.get("states", {})
	for stream_name: StringName in STREAM_NAMES:
		var key: String = String(stream_name)
		if states.has(key):
			_streams[stream_name].state = int(String(states[key]))
