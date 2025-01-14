extends Node

signal dictionary_updated

const SAVE_PATH = "user://dictionary.json"
const DEFAULT_CATEGORY = "Non classé"

var dictionary = {
	"words": {},
	"categories": {}
}

func initialize_dictionary() -> void:
	dictionary = {
		"words": {},
		"categories": {DEFAULT_CATEGORY: []}
	}

func save_dictionary() -> void:
	var save_file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var json_string = JSON.stringify(dictionary)
	save_file.store_line(json_string)

func load_dictionary() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		initialize_dictionary()
		return
		
	var save_file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_string = save_file.get_as_text()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result == OK:
		var data = json.get_data()
		if data.has("words") and data.has("categories"):
			dictionary = data
		else:
			initialize_dictionary()
			for french_word in data:
				if typeof(data[french_word]) == TYPE_STRING:
					add_word(french_word, data[french_word], DEFAULT_CATEGORY)

func add_word(french: String, portuguese: String, category: String) -> void:
	dictionary.words[french] = {
		"portuguese": portuguese,
		"mastery_level": 0,
		"last_reviewed": Time.get_unix_time_from_system(),
		"category": category
	}
	
	if not dictionary.categories.has(category):
		dictionary.categories[category] = []
	if not french in dictionary.categories[category]:
		dictionary.categories[category].append(french)
	
	dictionary_updated.emit()

func add_category(category_name: String) -> void:
	if not category_name.is_empty() and not dictionary.categories.has(category_name):
		dictionary.categories[category_name] = []
		dictionary_updated.emit()
