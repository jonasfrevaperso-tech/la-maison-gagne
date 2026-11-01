class_name InputHints
extends RefCounted
## Aide aux commandes contextuelle : construite depuis les assignations réelles
## (remappage compris), pour le dernier périphérique utilisé (clavier/souris ou manette).

const SEP: String = "  ·  "
const PAIR_FALLBACK: String = "%s: %s"
## Noms des boutons de manette (disposition Xbox / Steam Deck).
const PAD_NAMES: Dictionary[int, String] = {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View",
	JOY_BUTTON_START: "Menu",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "↑",
	JOY_BUTTON_DPAD_DOWN: "↓",
	JOY_BUTTON_DPAD_LEFT: "←",
	JOY_BUTTON_DPAD_RIGHT: "→",
}
## Seuil d'inclinaison de stick considéré comme une intention (évite la dérive).
const STICK_DEADZONE: float = 0.5

## Commandes affichées par état de l'écran de run : [action ou repère souris, clé de libellé].
const BY_STATE: Dictionary[String, Array] = {
	"BETTING_KEYS":
	[
		["@click", "HINT_K_ADD"],
		["@shift_click", "HINT_K_ADD5"],
		["@right_click", "HINT_K_REMOVE"],
		["bet_undo", "BTN_UNDO"],
		["bet_repeat", "BTN_REPEAT"],
		["ui_spin", "BTN_SPIN"],
	],
	"BETTING_PAD":
	[
		["@dpad", "HINT_K_CURSOR"],
		["bet_place", "HINT_K_ADD"],
		["bet_cycle_prev", "HINT_K_INSIDE"],
		["bet_undo", "BTN_UNDO"],
		["bet_repeat", "BTN_REPEAT"],
		["ui_spin", "BTN_SPIN"],
	],
	"AIMING": [["ui_spin", "BTN_RELEASE"]],
	"BALL": [["skip_anim", "HINT_K_SKIP"], ["speed_toggle", "HINT_K_SPEED"]],
	"SCORING": [["skip_anim", "HINT_K_SKIP"], ["speed_toggle", "HINT_K_SPEED"]],
	"TARGETING": [["ui_cancel", "BTN_CANCEL_TARGET"]],
}

static var using_pad: bool = false


## Note le périphérique d'un événement ; renvoie vrai s'il a changé.
static func note_event(event: InputEvent) -> bool:
	var pad: bool = using_pad
	if event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > STICK_DEADZONE:
			pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 2.0:
		pad = false
	if pad == using_pad:
		return false
	using_pad = pad
	return true


## Nom de la touche (ou du bouton) assignée à une action pour le périphérique courant.
static func key_for(action: String) -> String:
	if action.begins_with("@"):
		return TranslationServer.translate("HINT_INPUT_" + action.substr(1).to_upper())
	if not InputMap.has_action(action):
		return "?"
	var second: String = ""
	if action == "bet_cycle_prev":
		second = key_for("bet_cycle_next")
	for e: InputEvent in InputMap.action_get_events(action):
		if using_pad and e is InputEventJoypadButton:
			var n: String = PAD_NAMES.get((e as InputEventJoypadButton).button_index, "?")
			return n + ("/" + second if second != "" else "")
		if not using_pad and e is InputEventKey:
			var k: InputEventKey = e as InputEventKey
			var code: Key = k.keycode
			if k.physical_keycode != KEY_NONE:
				code = k.physical_keycode
				if DisplayServer.get_name() != "headless":
					code = DisplayServer.keyboard_get_label_from_physical(k.physical_keycode)
			return key_name(code) + ("/" + second if second != "" else "")
	return "—"


## Nom lisible et traduit d'une touche.
static func key_name(code: Key) -> String:
	var raw: String = OS.get_keycode_string(code)
	var key: String = "KEYNAME_" + raw.to_upper().replace(" ", "_")
	var t: String = TranslationServer.translate(key)
	return raw if t == key else t


## Ligne d'aide d'un état (`BETTING`, `AIMING`…), préfixée d'une phrase éventuelle.
static func line(state_name: String, sentence: String = "") -> String:
	var key: String = state_name
	if state_name == "BETTING":
		key = "BETTING_PAD" if using_pad else "BETTING_KEYS"
	var fmt: String = TranslationServer.translate("HINT_PAIR")
	if fmt.count("%s") != 2:
		fmt = PAIR_FALLBACK
	var parts: Array[String] = []
	if sentence != "":
		parts.append(sentence)
	for pair: Array in BY_STATE.get(key, []):
		var what: String = TranslationServer.translate(String(pair[1])).to_lower()
		parts.append(fmt % [key_for(String(pair[0])), what])
	return SEP.join(parts)
