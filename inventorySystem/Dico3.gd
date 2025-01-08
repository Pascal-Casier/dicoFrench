extends Control

# Constantes
const SAVE_PATH = "user://dictionary.json"
const MIN_QUIZ_OPTIONS = 4
const BUTTON_MIN_SIZE = Vector2(200, 50)

# Références aux nœuds
@onready var french_input: LineEdit = %FrenchInput
@onready var portuguese_input: LineEdit = %PortuguesInput
@onready var add_button: Button = %AddButton
@onready var search_input: LineEdit = %SearchInput
@onready var result_label: Label = %ResultLabel
@onready var word_tree: Tree = %WordTree
@onready var tab_container: TabContainer = %TabContainer
@onready var quiz_word_label: Label = %WordLabel
@onready var quiz_score_label: Label = %ScoreLabel
@onready var quiz_buttons_container: GridContainer = %ButtonsContainer
@onready var delete_button: Button = %DeleteButton

# Variables pour le quiz
var quiz_state = {
	"current_word": "",
	"words": [],
	"score": 0,
	"total_questions": 0,
	"total_words": 0,
	"streak": 0
}

# Dictionnaire principal
var dictionary: Dictionary = {}

func _ready() -> void:
	_setup_signals()
	_setup_tree()
	load_dictionary()
	update_score_display()

func _setup_signals() -> void:
	add_button.pressed.connect(_on_add_button_pressed)
	search_input.text_changed.connect(_on_search_text_changed)
	tab_container.tab_selected.connect(_on_tab_selected)
	delete_button.pressed.connect(_on_delete_button_pressed)
	word_tree.cell_selected.connect(_on_word_tree_cell_selected)
	
func _on_word_tree_item_selected() -> void:
	var selected_item = word_tree.get_selected()
	if selected_item:
		var french_word = selected_item.get_text(0)
		french_input.text = french_word
		portuguese_input.text = dictionary[french_word]["portuguese"]
		delete_button.disabled = false
	else:
		delete_button.disabled = true

func _on_word_tree_cell_selected() -> void:
	print("Cellule sélectionnée")  # Pour le débogage
	var selected_item = word_tree.get_selected()
	if selected_item and not selected_item.get_text(0).is_empty():
		print("Mot sélectionné:", selected_item.get_text(0))  # Pour le débogage
		var french_word = selected_item.get_text(0)
		french_input.text = french_word
		portuguese_input.text = dictionary[french_word]["portuguese"]
		delete_button.disabled = false
	else:
		delete_button.disabled = true


# Nouvelle fonction pour supprimer un mot
func _on_delete_button_pressed() -> void:
	var selected_item = word_tree.get_selected()
	if selected_item:
		var french_word = selected_item.get_text(0)
		
		# Création d'une boîte de dialogue de confirmation
		var confirm_dialog = ConfirmationDialog.new()
		add_child(confirm_dialog)
		confirm_dialog.title = "Confirmer la suppression"
		confirm_dialog.dialog_text = "Voulez-vous vraiment supprimer le mot '%s' ?" % french_word
		
		# Utilisation de callable pour les connexions de signaux
		confirm_dialog.confirmed.connect(func():
			# Suppression du mot
			dictionary.erase(french_word)
			save_dictionary()
			update_word_tree()
			_clear_inputs()
			delete_button.disabled = true
			confirm_dialog.queue_free()  # Nettoyage de la boîte de dialogue
		)
		
		confirm_dialog.canceled.connect(func():
			confirm_dialog.queue_free()
		)
		
		# Définir une taille minimale pour la boîte de dialogue
		confirm_dialog.min_size = Vector2(300, 100)
		confirm_dialog.popup_centered()

func _setup_tree() -> void:
	word_tree.columns = 4
	word_tree.set_column_titles_visible(true)
	word_tree.set_column_title(0, "Français")
	word_tree.set_column_title(1, "Portugais")
	word_tree.set_column_title(2, "Maîtrise")
	word_tree.set_column_title(3, "Action")
	
	word_tree.allow_reselect = true
	word_tree.hide_root = true
	word_tree.select_mode = Tree.SELECT_ROW  # Ajout: permet la sélection de lignes entières
	word_tree.focus_mode = Control.FOCUS_ALL
	
	word_tree.set_column_custom_minimum_width(3, 80)
	
	# Connecter le signal pour le clic sur la colonne
	word_tree.button_clicked.connect(_on_tree_button_clicked)
	
	
func save_dictionary() -> void:
	var save_file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var json_string = JSON.stringify(dictionary)
	save_file.store_line(json_string)

func load_dictionary() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
		
	var save_file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_string = save_file.get_as_text()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result == OK:
		var data = json.get_data()
		dictionary.clear()
		for key in data:
			if typeof(data[key]) == TYPE_STRING:
				# Conversion de l'ancien format vers le nouveau
				dictionary[key] = {
					"portuguese": data[key],
					"mastery_level": 0,
					"last_reviewed": Time.get_unix_time_from_system()
				}
			else:
				dictionary[key] = data[key]
	update_word_tree()

func start_new_quiz() -> void:
	quiz_state.score = 0
	quiz_state.total_questions = 0
	quiz_state.streak = 0
	quiz_state.words = _get_prioritized_words()
	update_score_display()
	next_quiz_question()

func _get_prioritized_words() -> Array:
	var words = []
	for french_word in dictionary:
		var weight = 6 - dictionary[french_word]["mastery_level"]
		for i in range(weight):
			words.append(french_word)
	words.shuffle()
	return words

func next_quiz_question() -> void:
	if quiz_state.words.is_empty():
		_show_quiz_results()
		return
		
	quiz_state.current_word = quiz_state.words.pop_front()
	quiz_word_label.text = quiz_state.current_word
	_create_quiz_buttons(_get_quiz_options())

func _show_quiz_results() -> void:
	quiz_word_label.text = "Quiz terminé !\nScore final: %d/%d\nMeilleure série: %d" % [
		quiz_state.score,
		quiz_state.total_questions,
		quiz_state.streak
	]
	_clear_quiz_buttons()

func _get_quiz_options() -> Array:
	var current_word_data = dictionary[quiz_state.current_word]
	var correct_answer = current_word_data["portuguese"]
	var answers = [correct_answer]
	
	var wrong_answers = []
	for word in dictionary:
		if word != quiz_state.current_word:
			wrong_answers.append(dictionary[word]["portuguese"])
	
	wrong_answers.shuffle()
	for i in range(min(MIN_QUIZ_OPTIONS - 1, wrong_answers.size())):
		answers.append(wrong_answers[i])
	
	answers.shuffle()
	return answers

func _create_quiz_buttons(answers: Array) -> void:
	_clear_quiz_buttons()
	
	for answer in answers:
		var button = Button.new()
		button.text = answer
		button.custom_minimum_size = BUTTON_MIN_SIZE
		button.pressed.connect(_on_answer_button_pressed.bind(answer))
		quiz_buttons_container.add_child(button)

func _clear_quiz_buttons() -> void:
	for child in quiz_buttons_container.get_children():
		child.queue_free()

func _on_answer_button_pressed(answer: String) -> void:
	var word_data = dictionary[quiz_state.current_word]
	quiz_state.total_questions += 1
	
	if answer == word_data["portuguese"]:
		quiz_state.score += 1
		quiz_state.streak += 1
		word_data["mastery_level"] = mini(word_data["mastery_level"] + 1, 5)
	else:
		quiz_state.streak = 0
		word_data["mastery_level"] = maxi(word_data["mastery_level"] - 1, 0)
	
	word_data["last_reviewed"] = Time.get_unix_time_from_system()
	update_score_display()
	save_dictionary()
	next_quiz_question()

func update_score_display() -> void:
	quiz_state.total_words = dictionary.size()
	quiz_score_label.text = "Score: %d/%d - Série: %d - Total des mots: %d" % [
		quiz_state.score,
		quiz_state.total_questions,
		quiz_state.streak,
		quiz_state.total_words
	]

func _on_add_button_pressed(_text: String = "") -> void:
	var french_word = french_input.text.strip_edges()
	var portuguese_word = portuguese_input.text.strip_edges()
	
	if french_word.is_empty() or portuguese_word.is_empty():
		_clear_inputs()
		return
		
	dictionary[french_word] = {
		"portuguese": portuguese_word,
		"mastery_level": 0,
		"last_reviewed": Time.get_unix_time_from_system()
	}
	
	save_dictionary()
	update_word_tree()
	_clear_inputs()

func _clear_inputs() -> void:
	french_input.clear()
	portuguese_input.clear()
	french_input.grab_focus()
	delete_button.disabled = true
	if word_tree.get_selected():
		word_tree.deselect_all()

func _on_search_text_changed(new_text: String) -> void:
	new_text = new_text.strip_edges().to_lower()
	
	if new_text.is_empty():
		result_label.text = ""
		return
		
	var found_entries = []
	for french_word in dictionary:
		if french_word.to_lower().contains(new_text):
			var entry = dictionary[french_word]
			found_entries.append("Français: %s\nPortugais: %s\nNiveau: %d/5" % [
				french_word,
				entry["portuguese"],
				entry["mastery_level"]
			])
	
	result_label.text = "Mot non trouvé" if found_entries.is_empty() else "\n\n".join(found_entries)

func update_word_tree() -> void:
	word_tree.clear()
	var root = word_tree.create_item()
	
	var sorted_words = dictionary.keys()
	sorted_words.sort()
	
	for french_word in sorted_words:
		var entry = dictionary[french_word]
		var item = word_tree.create_item(root)
		item.set_text(0, french_word)
		item.set_text(1, entry["portuguese"])
		item.set_text(2, str(entry["mastery_level"]) + "/5")
		
		# Ajouter un bouton dans la quatrième colonne
		item.add_button(3, preload("res://inventorySystem/icon_delete.png"))  # Assurez-vous d'avoir une icône de suppression
		# Ou utilisez cette ligne si vous préférez du texte plutôt qu'une icône
		# item.set_text(3, "Supprimer")
		item.set_selectable(0, true)
		item.set_selectable(1, true)
		item.set_selectable(2, true)
		item.set_selectable(3, true)

func _on_tree_button_clicked(item: TreeItem, _column: int, _button_idx: int, _mouse_button_idx: int) -> void:
	var french_word = item.get_text(0)
	
	var confirm_dialog = ConfirmationDialog.new()
	add_child(confirm_dialog)
	confirm_dialog.title = "Confirmer la suppression"
	confirm_dialog.dialog_text = "Voulez-vous vraiment supprimer le mot '%s' ?" % french_word
	
	confirm_dialog.confirmed.connect(func():
		dictionary.erase(french_word)
		save_dictionary()
		update_word_tree()
		_clear_inputs()
		confirm_dialog.queue_free()
	)
	
	confirm_dialog.canceled.connect(func():
		confirm_dialog.queue_free()
	)
	
	confirm_dialog.min_size = Vector2(300, 100)
	confirm_dialog.popup_centered()


func _on_tab_selected(tab_index: int) -> void:
	save_dictionary()
	update_word_tree()
	match tab_index:
		0:  # Onglet "Ajouter"
			await get_tree().create_timer(0.1).timeout
			french_input.grab_focus()
		1:  # Onglet "Rechercher"
			search_input.grab_focus()
			search_input.clear()
		3:  # Onglet "Quiz"
			start_new_quiz()
		
