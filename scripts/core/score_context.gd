class_name ScoreContext
extends RefCounted
## Accumulateur d'un tour : Jetons × (base + Σ Mult additifs) × Π Mult multiplicatifs.

const MAX_TOTAL: float = 1.0e18

var chips: float = 0.0
var mult_add: float = 0.0
var mult_mul: float = 1.0
var base_mult: float = 1.0
var money_delta: int = 0
var events: Array[ScoreEvent] = []

var landing_index: int = -1
var landing: Pocket = null
var landing_colors: Array[StringName] = []
var landing_numbers: Array[int] = []
var is_zero: bool = false
var zero_protected: bool = false
var house_tax: int = 0

var slip: Dictionary = {}  # spot_id -> chips (figé)
var bets_won: Array[String] = []
var bets_lost: Array[String] = []
var win_chips_by_bet: Dictionary[String, float] = {}
var pocket_retriggers: int = 0
var pocket_pass: int = 0
var bet_retriggers: int = 0
var near_miss: bool = false
var throw_result: ThrowResolver.ThrowResult = null

# Contexte courant pendant un déclencheur par pari (on_bet_win / on_bet_lose)
var current_bet: String = ""
var current_bet_win: float = 0.0
var total: int = 0


func mult() -> float:
	return (base_mult + mult_add) * mult_mul


func compute_total() -> int:
	# Plafond : les builds extrêmes ne doivent jamais déborder l'entier 64 bits.
	return int(floor(minf(maxf(chips, 0.0) * maxf(mult(), 0.0), MAX_TOTAL)))


func push(kind: StringName, src_kind: StringName, src_id: String, amount: float, text: String = "", src_uid: int = 0) -> ScoreEvent:
	var e: ScoreEvent = ScoreEvent.new()
	e.kind = kind
	e.source_kind = src_kind
	e.source_id = src_id
	e.source_uid = src_uid
	e.amount = amount
	e.text = text
	e.chips_after = chips
	e.mult_after = mult()
	events.append(e)
	return e


func events_as_dicts() -> Array:
	var out: Array = []
	for e: ScoreEvent in events:
		out.append(e.to_dict())
	return out
