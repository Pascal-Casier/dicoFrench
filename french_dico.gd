# Dictionary.gd
extends Control

var dictionary = {}
var file_path = "user://dictionary.json"

func _ready():
	load_dictionary()
	
	# Connecter les signaux des boutons
	%AddButton.pressed.connect(_on_add_pressed)
	%SearchButton.pressed.connect(_on_search_pressed)
	%DeleteButton.pressed.connect(_on_delete_pressed)
	%ShowAllButton.pressed.connect(_on_show_all_pressed)

func load_dictionary():
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_string = file.get_as_text()
		dictionary = JSON.parse_string(json_string)

func save_dictionary():
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	var json_string = JSON.stringify(dictionary)
	file.store_string(json_string)

func _on_add_pressed():
	var french_word = %FrenchInput.text.strip_edges()
	var portuguese_word = %"$PortugueseInput".text.strip_edges()
	
	if french_word != "" and portuguese_word != "":
		dictionary[french_word] = portuguese_word
		save_dictionary()
		%ResultLabel.text = "Mot ajouté avec succès!"
		clear_inputs()

func _on_search_pressed():
	var search_term = %SearchInput.text.strip_edges()
	if search_term == "":
		return
		
	var found = false
	var result = ""
	
	# Chercher dans les mots français
	if dictionary.has(search_term):
		result = "Français: " + search_term + "\nPortugais: " + dictionary[search_term]
		found = true
	
	# Chercher dans les mots portugais
	if not found:
		for french_word in dictionary.keys():
			if dictionary[french_word] == search_term:
				result = "Portugais: " + search_term + "\nFrançais: " + french_word
				found = true
				break
	
	if found:
		%ResultLabel.text = result
	else:
		%ResultLabel.text = "Mot non trouvé"

func _on_delete_pressed():
	var word = %DeleteInput.text.strip_edges()
	
	if dictionary.has(word):
		dictionary.erase(word)
		save_dictionary()
		%ResultLabel.text = "Mot supprimé avec succès!"
	else:
		%ResultLabel.text = "Mot non trouvé"
	
	clear_inputs()

func _on_show_all_pressed():
	var text = "Liste complète des mots:\n\n"
	for french_word in dictionary.keys():
		text += french_word + " -> " + dictionary[french_word] + "\n"
	%ResultLabel.text = text

func clear_inputs():
	%FrenchInput.text = ""
	%"$PortugueseInput".text = ""
	%SearchInput.text = ""
	%DeleteInput.text = ""
