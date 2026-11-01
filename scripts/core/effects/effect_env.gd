class_name EffectEnv
extends RefCounted
## Environnement d'évaluation d'un effet : qui déclenche, sur quel état.

var run: RunState = null
var ctx: ScoreContext = null
var db: ContentDB = null
var source_kind: StringName = ScoreEvent.SRC_SYSTEM
var source_id: String = ""
var source_uid: int = 0
var grigri: GrigriInstance = null
var pocket: Pocket = null
var pocket_index: int = -1
var depth: int = 0
var extra: Dictionary = {}


func duplicate_env() -> EffectEnv:
	var e: EffectEnv = EffectEnv.new()
	e.run = run
	e.ctx = ctx
	e.db = db
	e.source_kind = source_kind
	e.source_id = source_id
	e.source_uid = source_uid
	e.grigri = grigri
	e.pocket = pocket
	e.pocket_index = pocket_index
	e.depth = depth
	e.extra = extra
	return e
