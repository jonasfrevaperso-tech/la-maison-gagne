extends Node
## Point d'accès unique au hasard pour la présentation.
## La logique de jeu utilise exclusivement les flux du RunState (RngStreams) ;
## la présentation (particules, variations sonores) consomme le flux cosmétique.

var _menu_streams: RngStreams = RngStreams.new(0)


func _ready() -> void:
	_menu_streams.reseed(int(Time.get_unix_time_from_system()))


func streams() -> RngStreams:
	if GameState.controller != null and GameState.controller.run != null:
		return GameState.controller.run.rng
	return _menu_streams


func cosmetic() -> RandomNumberGenerator:
	return streams().stream(RngStreams.COSMETIC)


func cosmetic_f(from: float, to: float) -> float:
	return cosmetic().randf_range(from, to)


## Graine pour un nouveau run (aléatoire, quotidienne ou saisie).
func new_seed() -> int:
	return absi(hash(str(Time.get_unix_time_from_system()) + str(Time.get_ticks_usec())))


func daily_seed() -> int:
	var d: Dictionary = Time.get_date_dict_from_system()
	return absi(hash("daily-%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]))


static func seed_to_code(seed_value: int) -> String:
	const ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var v: int = absi(seed_value)
	var code: String = ""
	for _i: int in 8:
		code += ALPHABET[v % ALPHABET.length()]
		v /= ALPHABET.length()
	return code


static func code_to_seed(code: String) -> int:
	const ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var v: int = 0
	var up: String = code.strip_edges().to_upper()
	for i: int in range(up.length() - 1, -1, -1):
		var idx: int = ALPHABET.find(up[i])
		if idx < 0:
			return absi(hash(code))
		v = v * ALPHABET.length() + idx
	return v
