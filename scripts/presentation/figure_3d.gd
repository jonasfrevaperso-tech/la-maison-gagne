class_name Figure3D
extends Node3D
## Personnage articulé construit en code (2.0) : bassin, buste, tête, bras et jambes à deux
## segments, tenue paramétrable (groom, serveur, danseuse…). Animation procédurale : chaque image,
## l'épreuve demande une pose (`animate("run", phase)`), le corps y glisse en douceur (`SMOOTH`).
## Repère local : le personnage regarde vers +z, debout sur y = 0, haut de `HEIGHT` avant échelle.

const HEIGHT: float = 1.18
const SMOOTH: float = 16.0
## Proportions (unités locales, hauteur totale HEIGHT).
const HIP_Y: float = 0.5
const TORSO: Vector3 = Vector3(0.3, 0.36, 0.18)
const HEAD_R: float = 0.12
const UPPER_ARM: float = 0.18
const FOREARM: float = 0.17
const THIGH: float = 0.24
const SHIN: float = 0.24
const SHOULDER_X: float = 0.19
const HIP_X: float = 0.08
const JOINTS: Array[StringName] = [&"torso", &"head", &"sh_l", &"el_l", &"sh_r", &"el_r", &"hip_l", &"kn_l", &"hip_r", &"kn_r"]

## Tenue par défaut (le groom du Grand Zéro) ; `build()` fusionne les clés données.
const OUTFIT: Dictionary = {
	"skin": Color("e8b896"), "coat": Color("b0202e"), "trousers": Color("1c1418"), "shoes": Color("0e0a0c"),
	"trim": Color("d4af37"), "hat": "pillbox", "hat_col": Color("b0202e"), "hair": Color("3a2416"), "skirt": false,
}

var outfit: Dictionary = {}
var anim: StringName = &"idle"
var _pivots: Dictionary[StringName, Node3D] = {}
var _cur: Dictionary[StringName, Vector3] = {}
var _pelvis: Node3D = null
var _bob: float = 0.0
var _lean: float = 0.0


## Construit le personnage à la hauteur `height` (unités du décor).
func build(height: float, p_outfit: Dictionary = {}) -> Figure3D:
	outfit = OUTFIT.duplicate()
	outfit.merge(p_outfit, true)
	scale = Vector3.ONE * (height / HEIGHT)
	var skin: StandardMaterial3D = Stage3D.mat(outfit["skin"], 0.0, 0.7)
	var coat: StandardMaterial3D = Stage3D.mat(outfit["coat"], 0.0, 0.55)
	var trousers: StandardMaterial3D = Stage3D.mat(outfit["trousers"], 0.0, 0.7)
	var shoes: StandardMaterial3D = Stage3D.mat(outfit["shoes"], 0.2, 0.3)
	var trim: StandardMaterial3D = Stage3D.mat(outfit["trim"], 0.75, 0.3)
	_pelvis = _pivot(self, &"pelvis", Vector3(0, HIP_Y, 0))
	Stage3D.box(_pelvis, Vector3(TORSO.x * 0.92, 0.1, TORSO.z * 0.95), Vector3(0, 0.0, 0), trousers)
	var torso: Node3D = _pivot(_pelvis, &"torso", Vector3(0, 0.04, 0))
	Stage3D.box(torso, TORSO, Vector3(0, TORSO.y * 0.5, 0), coat)
	if bool(outfit["skirt"]):
		Stage3D.cylinder(_pelvis, TORSO.x * 0.62, 0.22, Vector3(0, -0.08, 0), coat, TORSO.x * 0.4)
	for k: int in 3:  # boutons dorés
		Stage3D.sphere(torso, 0.018, Vector3(0, 0.08 + 0.09 * float(k), TORSO.z * 0.5 + 0.005), trim)
	Stage3D.box(torso, Vector3(TORSO.x * 1.02, 0.03, TORSO.z * 1.02), Vector3(0, 0.015, 0), trim)  # ceinture
	var head: Node3D = _pivot(torso, &"head", Vector3(0, TORSO.y + 0.02, 0))
	Stage3D.cylinder(head, 0.045, 0.05, Vector3(0, 0.02, 0), skin)
	Stage3D.sphere(head, HEAD_R, Vector3(0, HEAD_R + 0.03, 0), skin)
	Stage3D.sphere(head, HEAD_R * 1.02, Vector3(0, HEAD_R + 0.07, -0.03), Stage3D.mat(outfit["hair"], 0.0, 0.8))
	var eye: StandardMaterial3D = Stage3D.mat(Color("140c10"), 0.0, 0.4)
	for sx: float in [-1.0, 1.0]:
		Stage3D.sphere(head, 0.016, Vector3(sx * 0.045, HEAD_R + 0.05, HEAD_R * 0.9), eye)
	_hat(head, trim)
	for side: int in 2:
		var sx: float = -1.0 if side == 0 else 1.0
		var suffix: String = "_l" if side == 0 else "_r"
		var sh: Node3D = _pivot(torso, StringName("sh" + suffix), Vector3(sx * SHOULDER_X, TORSO.y - 0.04, 0))
		Stage3D.box(sh, Vector3(0.08, UPPER_ARM, 0.08), Vector3(0, -UPPER_ARM * 0.5, 0), coat)
		var el: Node3D = _pivot(sh, StringName("el" + suffix), Vector3(0, -UPPER_ARM, 0))
		Stage3D.box(el, Vector3(0.07, FOREARM, 0.07), Vector3(0, -FOREARM * 0.5, 0), coat)
		Stage3D.box(el, Vector3(0.075, 0.025, 0.075), Vector3(0, -FOREARM + 0.01, 0), trim)  # manchette
		Stage3D.sphere(el, 0.045, Vector3(0, -FOREARM - 0.04, 0), skin)
		var hip: Node3D = _pivot(_pelvis, StringName("hip" + suffix), Vector3(sx * HIP_X, -0.02, 0))
		Stage3D.box(hip, Vector3(0.11, THIGH, 0.11), Vector3(0, -THIGH * 0.5, 0), trousers)
		var kn: Node3D = _pivot(hip, StringName("kn" + suffix), Vector3(0, -THIGH, 0))
		Stage3D.box(kn, Vector3(0.1, SHIN, 0.1), Vector3(0, -SHIN * 0.5, 0), trousers)
		Stage3D.box(kn, Vector3(0.1, 0.06, 0.18), Vector3(0, -SHIN - 0.01, 0.035), shoes)
	for j: StringName in JOINTS:
		_cur[j] = Vector3.ZERO
	return self


func _pivot(parent: Node3D, id: StringName, at: Vector3) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = String(id)
	n.position = at
	parent.add_child(n)
	_pivots[id] = n
	return n


func _hat(head: Node3D, trim: StandardMaterial3D) -> void:
	var col: StandardMaterial3D = Stage3D.mat(outfit["hat_col"], 0.0, 0.5)
	var top: float = HEAD_R * 2.0 + 0.02
	match String(outfit["hat"]):
		"pillbox":
			Stage3D.cylinder(head, 0.085, 0.07, Vector3(0, top + 0.01, -0.01), col)
			Stage3D.cylinder(head, 0.088, 0.018, Vector3(0, top - 0.015, -0.01), trim)
		"top":
			Stage3D.cylinder(head, 0.15, 0.015, Vector3(0, top - 0.02, 0), col)
			Stage3D.cylinder(head, 0.09, 0.2, Vector3(0, top + 0.08, 0), col)
			Stage3D.cylinder(head, 0.092, 0.03, Vector3(0, top + 0.0, 0), trim)
		"chef":
			Stage3D.cylinder(head, 0.11, 0.16, Vector3(0, top + 0.06, 0), col, 0.13)
		"bow":
			Stage3D.sphere(head, 0.04, Vector3(0.08, top - 0.02, -0.02), col)


## Demande une pose. `phase` : cycle (course, marche) ou avancement 0..1 (saut) selon la pose ;
## `amount` : intensité (balancement d'un câble, vent…).
func animate(p_anim: StringName, phase: float, dt: float, amount: float = 0.0) -> void:
	anim = p_anim
	var target: Dictionary[StringName, Vector3] = _pose(p_anim, phase, amount)
	var k: float = 1.0 - exp(-SMOOTH * dt)
	for j: StringName in JOINTS:
		_cur[j] = (_cur[j] as Vector3).lerp(target.get(j, Vector3.ZERO), k)
		(_pivots[j] as Node3D).rotation = _cur[j]
	_bob = lerpf(_bob, float(target.get(&"_bob", Vector3.ZERO).y), k)
	_lean = lerpf(_lean, float(target.get(&"_lean", Vector3.ZERO).x), k)
	_pelvis.position.y = HIP_Y + _bob
	_pelvis.rotation.x = _lean


## Poses : angles d'Euler par articulation (x positif = vers l'arrière).
func _pose(p_anim: StringName, ph: float, amount: float) -> Dictionary[StringName, Vector3]:
	var s: float = sin(ph)
	var c: float = cos(ph)
	var o: Dictionary[StringName, Vector3] = {}
	match p_anim:
		&"run", &"walk":
			var a: float = 0.75 if p_anim == &"run" else 0.4
			o[&"hip_l"] = Vector3(-a * s, 0, 0)
			o[&"hip_r"] = Vector3(a * s, 0, 0)
			o[&"kn_l"] = Vector3(maxf(0.0, -c) * a * 1.6 + 0.1, 0, 0)
			o[&"kn_r"] = Vector3(maxf(0.0, c) * a * 1.6 + 0.1, 0, 0)
			o[&"sh_l"] = Vector3(a * 0.8 * s, 0, -0.08)
			o[&"sh_r"] = Vector3(-a * 0.8 * s, 0, 0.08)
			o[&"el_l"] = Vector3(-0.9 if p_anim == &"run" else -0.3, 0, 0)
			o[&"el_r"] = o[&"el_l"]
			o[&"_bob"] = Vector3(0, absf(s) * (0.04 if p_anim == &"run" else 0.015), 0)
			o[&"_lean"] = Vector3(-0.18 if p_anim == &"run" else -0.04, 0, 0)
			o[&"head"] = Vector3(0.1 if p_anim == &"run" else 0.0, 0, 0)
		&"jump":
			# phase 0 → 1 : impulsion, sommet groupé, descente jambes tendues.
			var tuck: float = sin(clampf(ph, 0.0, 1.0) * PI)
			o[&"hip_l"] = Vector3(-1.0 * tuck - 0.2, 0, 0)
			o[&"hip_r"] = Vector3(-0.5 * tuck + 0.3, 0, 0)
			o[&"kn_l"] = Vector3(1.4 * tuck + 0.2, 0, 0)
			o[&"kn_r"] = Vector3(1.0 * tuck + 0.3, 0, 0)
			o[&"sh_l"] = Vector3(-2.4, 0, -0.2)
			o[&"sh_r"] = Vector3(-1.6, 0, 0.2)
			o[&"el_l"] = Vector3(-0.3, 0, 0)
			o[&"el_r"] = Vector3(-0.5, 0, 0)
			o[&"_lean"] = Vector3(-0.15, 0, 0)
		&"fall":
			var fl: float = sin(ph * 2.0)
			o[&"sh_l"] = Vector3(-2.6 + 0.4 * fl, 0, -0.5)
			o[&"sh_r"] = Vector3(-2.6 - 0.4 * fl, 0, 0.5)
			o[&"hip_l"] = Vector3(-0.4 + 0.3 * fl, 0, -0.15)
			o[&"hip_r"] = Vector3(0.3 - 0.3 * fl, 0, 0.15)
			o[&"kn_l"] = Vector3(0.6, 0, 0)
			o[&"kn_r"] = Vector3(0.4, 0, 0)
			o[&"head"] = Vector3(-0.3, 0, 0)
		&"hang":
			# Suspendu à deux mains ; `amount` = angle du câble, les jambes traînent derrière.
			o[&"sh_l"] = Vector3(-3.0, 0, -0.12)
			o[&"sh_r"] = Vector3(-3.0, 0, 0.12)
			o[&"el_l"] = Vector3(-0.15, 0, 0)
			o[&"el_r"] = Vector3(-0.15, 0, 0)
			o[&"hip_l"] = Vector3(-0.35 + amount * 0.6, 0, 0)
			o[&"hip_r"] = Vector3(-0.1 + amount * 0.6, 0, 0)
			o[&"kn_l"] = Vector3(0.6, 0, 0)
			o[&"kn_r"] = Vector3(0.3, 0, 0)
			o[&"head"] = Vector3(-0.25, 0, 0)
		&"stun":
			o[&"head"] = Vector3(0.3 * sin(ph * 3.0), 0.4 * sin(ph * 2.0), 0.3 * c)
			o[&"torso"] = Vector3(0.1, 0, 0.15 * s)
			o[&"sh_l"] = Vector3(0.2, 0, -0.3 - 0.2 * s)
			o[&"sh_r"] = Vector3(0.2, 0, 0.3 + 0.2 * s)
			o[&"kn_l"] = Vector3(0.4, 0, 0)
			o[&"kn_r"] = Vector3(0.4, 0, 0)
			o[&"_bob"] = Vector3(0, -0.05, 0)
		&"cheer":
			o[&"sh_l"] = Vector3(-2.9 + 0.3 * s, 0, -0.4)
			o[&"sh_r"] = Vector3(-2.9 - 0.3 * s, 0, 0.4)
			o[&"el_l"] = Vector3(-0.2, 0, 0)
			o[&"el_r"] = Vector3(-0.2, 0, 0)
			o[&"_bob"] = Vector3(0, absf(s) * 0.06, 0)
		&"tap":
			# Claquette : `amount` = pas (0 pointe gauche, 1 talon, 2 pointe droite, 3 frappe à plat) ;
			# `ph` 0 → 1 : le pied monte puis frappe ; bras en jazz, buste qui accompagne.
			var step: int = clampi(int(amount), 0, 3)
			var lift: float = sin(clampf(ph, 0.0, 1.0) * PI)
			var left: bool = step == 0 or (step == 1 and fmod(ph, 2.0) < 1.0) or step == 3
			var hk: StringName = &"hip_l" if left else &"hip_r"
			var kk: StringName = &"kn_l" if left else &"kn_r"
			var heel: bool = step == 1
			o[hk] = Vector3(-0.5 * lift if not heel else -0.25 * lift, 0, 0)
			o[kk] = Vector3((0.9 if not heel else 0.2) * lift + 0.15, 0, 0)
			o[&"kn_l" if hk == &"hip_r" else &"kn_r"] = Vector3(0.25, 0, 0)
			o[&"sh_l"] = Vector3(-0.6 - 0.4 * lift, 0, -0.9)
			o[&"sh_r"] = Vector3(-0.6 - 0.4 * lift, 0, 0.9)
			o[&"el_l"] = Vector3(-0.6, 0, 0)
			o[&"el_r"] = Vector3(-0.6, 0, 0)
			o[&"torso"] = Vector3(0.05, 0.25 * (1.0 if left else -1.0) * lift, 0)
			o[&"_bob"] = Vector3(0, -0.03 + 0.025 * lift, 0)
		&"balance":
			# Funambule : `amount` = inclinaison (-1..1), bras écartés qui compensent.
			o[&"torso"] = Vector3(0, 0, amount * 0.45)
			o[&"sh_l"] = Vector3(-0.1, 0, -1.45 + amount * 0.5)
			o[&"sh_r"] = Vector3(-0.1, 0, 1.45 + amount * 0.5)
			o[&"el_l"] = Vector3(-0.1, 0, 0)
			o[&"el_r"] = Vector3(-0.1, 0, 0)
			o[&"hip_l"] = Vector3(-0.25 * s, 0, -0.05)
			o[&"hip_r"] = Vector3(0.25 * s, 0, 0.05)
			o[&"kn_l"] = Vector3(0.2 + maxf(0.0, -c) * 0.3, 0, 0)
			o[&"kn_r"] = Vector3(0.2 + maxf(0.0, c) * 0.3, 0, 0)
			o[&"head"] = Vector3(0.15, 0, -amount * 0.3)
		&"carry":
			# Serveur : plateau tenu à droite, bras plié ; `amount` = inclinaison du plateau ; `ph` = marche.
			var w: float = 0.3
			o[&"hip_l"] = Vector3(-w * s, 0, 0)
			o[&"hip_r"] = Vector3(w * s, 0, 0)
			o[&"kn_l"] = Vector3(maxf(0.0, -c) * w * 1.6 + 0.1, 0, 0)
			o[&"kn_r"] = Vector3(maxf(0.0, c) * w * 1.6 + 0.1, 0, 0)
			o[&"sh_r"] = Vector3(-1.4, 0, 0.35 + amount * 0.3)
			o[&"el_r"] = Vector3(-1.5, 0, 0)
			o[&"sh_l"] = Vector3(0.2 * s, 0, -0.25 - amount * 0.3)
			o[&"el_l"] = Vector3(-0.3, 0, 0)
			o[&"torso"] = Vector3(0, 0, -amount * 0.2)
			o[&"_bob"] = Vector3(0, absf(s) * 0.012, 0)
		&"throw":
			# Lancer à bras roulé : `ph` 0 (armé, bras en arrière) → 1 (bras projeté devant).
			var u: float = clampf(ph, 0.0, 1.0)
			o[&"sh_r"] = Vector3(lerpf(1.2, -2.2, u), 0, 0.25)
			o[&"el_r"] = Vector3(lerpf(-0.8, -0.1, u), 0, 0)
			o[&"sh_l"] = Vector3(lerpf(-0.9, 0.4, u), 0, -0.3)
			o[&"torso"] = Vector3(lerpf(0.15, -0.2, u), lerpf(0.5, -0.4, u), 0)
			o[&"hip_l"] = Vector3(-0.35, 0, 0)
			o[&"kn_l"] = Vector3(0.25, 0, 0)
			o[&"hip_r"] = Vector3(0.25, 0, 0)
			o[&"kn_r"] = Vector3(0.2, 0, 0)
		&"sit":
			# Assis (chaise, banquette) : `amount` = penché vers la table (0..1), `ph` = respiration.
			o[&"hip_l"] = Vector3(-1.5, 0, -0.08)
			o[&"hip_r"] = Vector3(-1.5, 0, 0.08)
			o[&"kn_l"] = Vector3(1.5, 0, 0)
			o[&"kn_r"] = Vector3(1.5, 0, 0)
			o[&"torso"] = Vector3(-0.15 * amount + 0.02 * s, 0, 0)
			o[&"sh_l"] = Vector3(-0.7 * amount - 0.1, 0, -0.15)
			o[&"sh_r"] = Vector3(-0.7 * amount - 0.1, 0, 0.15)
			o[&"el_l"] = Vector3(-0.9 * amount - 0.2, 0, 0)
			o[&"el_r"] = Vector3(-0.9 * amount - 0.2, 0, 0)
			o[&"_bob"] = Vector3(0, -0.2, 0)
		&"smoke":
			# Fumeur assis : `amount` 0..1 = inspiration (main à la bouche, buste qui se gonfle et
			# s'incline en arrière) ; négatif = il souffle (tête projetée, main écartée).
			var inh: float = clampf(amount, 0.0, 1.0)
			var blow: float = clampf(-amount, 0.0, 1.0)
			o[&"hip_l"] = Vector3(-1.5, 0, -0.08)
			o[&"hip_r"] = Vector3(-1.5, 0, 0.08)
			o[&"kn_l"] = Vector3(1.5, 0, 0)
			o[&"kn_r"] = Vector3(1.4, 0, 0)
			o[&"torso"] = Vector3(0.12 * inh - 0.12 * blow + 0.02 * s, 0, 0)
			o[&"head"] = Vector3(0.15 * inh - 0.25 * blow, 0, 0)
			o[&"sh_r"] = Vector3(-1.3 + 0.6 * blow, 0, 0.35 + 0.3 * blow)
			o[&"el_r"] = Vector3(-2.0 + 0.9 * blow, 0, 0)
			o[&"sh_l"] = Vector3(-0.3, 0, -0.2)
			o[&"el_l"] = Vector3(-0.8, 0, 0)
			o[&"_bob"] = Vector3(0, -0.2 + 0.015 * inh, 0)
		&"tic":
			# Joueur attablé et ses tics (Bluff) : `amount` = tic (0 se gratte le nez, 1 tire l'oreille,
			# 2 lisse la moustache, 3 tapote la table), `ph` 0..1 = déroulé du geste (0 = repos).
			var g: float = sin(clampf(ph, 0.0, 1.0) * PI)
			o[&"hip_l"] = Vector3(-1.5, 0, -0.08)
			o[&"hip_r"] = Vector3(-1.5, 0, 0.08)
			o[&"kn_l"] = Vector3(1.5, 0, 0)
			o[&"kn_r"] = Vector3(1.5, 0, 0)
			o[&"torso"] = Vector3(-0.12 + 0.015 * s, 0, 0)
			o[&"sh_l"] = Vector3(-0.8, 0, -0.15)
			o[&"el_l"] = Vector3(-1.0, 0, 0)
			o[&"sh_r"] = Vector3(-0.8, 0, 0.15)
			o[&"el_r"] = Vector3(-1.0, 0, 0)
			o[&"_bob"] = Vector3(0, -0.2, 0)
			match clampi(int(amount), 0, 3):
				0:
					o[&"sh_r"] = Vector3(-0.8 - 1.0 * g, 0, 0.15 - 0.25 * g)
					o[&"el_r"] = Vector3(-1.0 - 1.1 * g, 0, 0)
					o[&"head"] = Vector3(0.12 * g, 0, 0)
				1:
					o[&"sh_l"] = Vector3(-0.8 - 1.4 * g, 0, -0.15 - 0.5 * g)
					o[&"el_l"] = Vector3(-1.0 - 1.0 * g, 0, 0)
					o[&"head"] = Vector3(0, 0, 0.25 * g)
				2:
					o[&"sh_r"] = Vector3(-0.8 - 1.0 * g, 0.3 * sin(ph * TAU * 2.0) * g, 0.1)
					o[&"el_r"] = Vector3(-1.0 - 1.0 * g, 0, 0)
					o[&"head"] = Vector3(-0.1 * g, 0.2 * g, 0)
				_:
					o[&"sh_r"] = Vector3(-0.8 + 0.25 * absf(sin(ph * TAU * 3.0)) * g, 0, 0.15)
					o[&"head"] = Vector3(0.1 * g, -0.3 * g, 0)
		&"point":
			# Désigne devant soi ; `amount` = direction (-1 gauche … 1 droite).
			o[&"sh_r"] = Vector3(-1.5, -amount * 0.8, 0.1)
			o[&"el_r"] = Vector3(-0.05, 0, 0)
			o[&"sh_l"] = Vector3(0.05, 0, -0.12)
			o[&"el_l"] = Vector3(-0.2, 0, 0)
			o[&"torso"] = Vector3(0, -amount * 0.3, 0)
			o[&"head"] = Vector3(0.05, -amount * 0.4, 0)
		_:  # idle : respiration, bras le long du corps.
			o[&"torso"] = Vector3(0.02 * s, 0, 0)
			o[&"sh_l"] = Vector3(0.05, 0, -0.1 - 0.03 * s)
			o[&"sh_r"] = Vector3(0.05, 0, 0.1 + 0.03 * s)
			o[&"el_l"] = Vector3(-0.15, 0, 0)
			o[&"el_r"] = Vector3(-0.15, 0, 0)
			o[&"_bob"] = Vector3(0, 0.005 * s, 0)
	return o


## Position d'une articulation en coordonnées monde (mains sur un câble, plateau d'un serveur).
func joint_global(id: StringName) -> Vector3:
	return (_pivots[id] as Node3D).global_position if _pivots.has(id) else global_position
