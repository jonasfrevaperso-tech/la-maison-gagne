class_name DevMode
extends RefCounted
## Options de développement (captures, pilote automatique, accès direct aux écrans).
## Disponibles uniquement depuis les sources (binaire éditeur) : un export n'a ni la
## fonctionnalité « editor » ni les scripts de `scripts/dev/` (exclus des presets d'export).
## Une session de développement écrit dans `user://dev/`, jamais dans la sauvegarde du joueur.

const DEV_DIR: String = "user://dev/"
const HOOKS_SCRIPT: String = "res://scripts/dev/dev_hooks.gd"
## Arguments qui font d'un lancement une session de développement.
const DEV_ARGS: Array[String] = ["dev-run", "dev-screen", "dev-autoplay", "dev-hover", "dev-ui-check", "shot", "quit-frames", "perf"]

static var _args_cache: Dictionary = {}
static var _parsed: bool = false


## Arguments utilisateur (`-- --cle=valeur`) sous forme de dictionnaire.
static func args() -> Dictionary:
	if not _parsed:
		_parsed = true
		for a: String in OS.get_cmdline_user_args():
			if a.begins_with("--"):
				var kv: PackedStringArray = a.substr(2).split("=", true, 1)
				_args_cache[kv[0]] = kv[1] if kv.size() > 1 else "true"
	return _args_cache


## Vrai si les outils de développement existent dans ce binaire.
static func available() -> bool:
	return OS.has_feature("editor") and ResourceLoader.exists(HOOKS_SCRIPT)


## Vrai si ce lancement est une session de développement.
static func active() -> bool:
	if not available():
		return false
	for k: String in DEV_ARGS:
		if args().has(k):
			return true
	return false


## Dossier de sauvegarde : séparé pour les sessions de développement.
static func save_dir() -> String:
	if active():
		DirAccess.make_dir_recursive_absolute(DEV_DIR)
		return DEV_DIR
	return "user://"
