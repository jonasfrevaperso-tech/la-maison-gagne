class_name ScoreEvent
extends RefCounted
## Une étape du calcul de score, rejouée une par une par la présentation.

const CHIPS: StringName = &"chips"
const MULT_ADD: StringName = &"mult_add"
const MULT_MUL: StringName = &"mult_mul"
const MONEY: StringName = &"money"
const BET_WIN: StringName = &"bet_win"
const BET_LOSE: StringName = &"bet_lose"
const ZERO: StringName = &"zero"
const INFO: StringName = &"info"
const DESTROY: StringName = &"destroy"
const TRANSFORM: StringName = &"transform"
const COUNTER: StringName = &"counter"
const SPINS: StringName = &"spins"
const TOTAL: StringName = &"total"

const SRC_BET: StringName = &"bet"
const SRC_POCKET: StringName = &"pocket"
const SRC_GRIGRI: StringName = &"grigri"
const SRC_EDITION: StringName = &"edition"
const SRC_SEAL: StringName = &"seal"
const SRC_CONTRACT: StringName = &"contract"
const SRC_CHARACTER: StringName = &"character"
const SRC_CREDITOR: StringName = &"creditor"
const SRC_SYSTEM: StringName = &"system"
const SRC_FORTUNE: StringName = &"fortune"

var kind: StringName = INFO
var source_kind: StringName = SRC_SYSTEM
var source_id: String = ""
var source_uid: int = 0
var amount: float = 0.0
var text: String = ""
var chips_after: float = 0.0
var mult_after: float = 0.0


func to_dict() -> Dictionary:
	return {
		"kind": String(kind), "src": String(source_kind), "id": source_id, "uid": source_uid,
		"amount": amount, "text": text, "chips": chips_after, "mult": mult_after,
	}
