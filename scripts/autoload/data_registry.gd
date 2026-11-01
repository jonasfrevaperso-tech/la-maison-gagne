extends Node
## Registre du contenu de jeu (wrapper autoload de ContentDB partagé).

var db: ContentDB = null


func _ready() -> void:
	db = ContentDB.shared()
	for e: String in db.errors:
		push_error("DataRegistry : " + e)


func entry(cat: String, entry_id: String) -> Dictionary:
	return db.get_entry(cat, entry_id)
