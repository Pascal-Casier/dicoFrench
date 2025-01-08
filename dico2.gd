# Dictionary.gd
extends Control

var dictionary = {}
var file_path = "user://dictionary.json"

func _ready():
	load_dictionary()
	setup_signals()
	update_word_list()

func setup_signals():
	# Onglet Ajouter
	%AddButton.pressed.connect(_on_add_pressed)
	
	# Onglet Rechercher
	%SearchButton.pressed.connect(_on_search_pressed)
	%SearchInput.text_submitted.connect(_on_search_pressed)
	
	# Onglet Gérer
	%DeleteButton.pressed.connect(_on_delete_pressed)
	$"MainContainer/TabContainer/Gérer/ButtonExport".pressed.connect(_on_export_pressed)
	$"MainContainer/TabContainer/Gérer/ButtonImport".pressed.connect(_on_import_pressed)

func load_dictionary():
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_string = file.get_as_text()
		var parsed = JSON.parse_string(json_string)
		if parsed:
			dictionary = parsed

func save_dictionary():
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	var json_string = JSON.stringify(dictionary)
	file.store_string(json_string)

func _on_add_pressed():
	var french_input = %FrenchInput
	var portuguese_input = %"$PortugueseInput"
	var status_label = %LabelAddStatus
	
	var french_word = french_input.text.strip_edges()
	var portuguese_word = portuguese_input.text.strip_edges()
	
	if french_word != "" and portuguese_word != "":
		dictionary[french_word] = portuguese_word
		save_dictionary()
		status_label.text = "✓ Mot ajouté avec succès!"
		status_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		french_input.text = ""
		portuguese_input.text = ""
		update_word_list()
	else:
		status_label.text = "⚠ Veuillez remplir tous les champs"
		status_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))

func _on_search_pressed():
	var search_input = %SearchInput
	var results_label = %SearchResults
	
	var search_term = search_input.text.strip_edges()
	if search_term == "":
		results_label.text = "Veuillez entrer un terme à rechercher"
		return
		
	var found = false
	var result = ""
	
	# Recherche dans les deux langues
	if dictionary.has(search_term):
		result = "[b]Français:[/b] " + search_term + "\n[b]Portugais:[/b] " + dictionary[search_term]
		found = true
	else:
		for french_word in dictionary.keys():
			if dictionary[french_word].to_lower() == search_term.to_lower():
				result = "[b]Portugais:[/b] " + search_term + "\n[b]Français:[/b] " + french_word
				found = true
				break
	
	if found:
		results_label.text = result
	else:
		results_label.text = "❌ Mot non trouvé"

func _on_delete_pressed():
	var delete_input = %DeleteInput
	var status_label = %LabelDeleteStatus
	
	var word = delete_input.text.strip_edges()
	
	if dictionary.has(word):
		dictionary.erase(word)
		save_dictionary()
		status_label.text = "✓ Mot supprimé avec succès!"
		status_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		delete_input.text = ""
		update_word_list()
	else:
		status_label.text = "❌ Mot non trouvé"
		status_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))

func update_word_list():
	var tree = %TreeWordList
	tree.clear()
	
	var root = tree.create_item()
	tree.set_column_titles_visible(true)
	tree.set_column_title(0, "Français")
	tree.set_column_title(1, "Portugais")
	
	for french_word in dictionary.keys():
		var item = tree.create_item(root)
		item.set_text(0, french_word)
		item.set_text(1, dictionary[french_word])

func _on_export_pressed():
	var csv = "Français,Portugais\n"
	for french_word in dictionary.keys():
		csv += french_word + "," + dictionary[french_word] + "\n"
	
	var file = FileAccess.open("user://dictionary_export.csv", FileAccess.WRITE)
	file.store_string(csv)
	
	var status_label = %LabelDeleteStatus
	status_label.text = "✓ Dictionnaire exporté avec succès!"
	status_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))

func _on_import_pressed():
	if not FileAccess.file_exists("user://dictionary_import.csv"):
		var status_label = %LabelDeleteStatus
		status_label.text = "❌ Fichier d'import non trouvé"
		status_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
		return
		
	var file = FileAccess.open("user://dictionary_import.csv", FileAccess.READ)
	var content = file.get_as_text()
	var lines = content.split("\n")
	
	# Ignorer la première ligne (en-têtes)
	for i in range(1, lines.size()):
		var line = lines[i].strip_edges()
		if line != "":
			var parts = line.split(",")
			if parts.size() == 2:
				dictionary[parts[0]] = parts[1]
	
	save_dictionary()
	update_word_list()
	
	var status_label = %LabelDeleteStatus
	status_label.text = "✓ Dictionnaire importé avec succès!"
	status_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
