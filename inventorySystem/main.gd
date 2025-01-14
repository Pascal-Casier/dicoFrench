extends Control

@onready var dictionary_manager = $DictionaryManager
@onready var word_tree_view = $WordTreeView
@onready var quiz_manager = $QuizManager
@onready var dialog_manager = $DialogManager

# Références UI existantes
@onready var french_input: LineEdit = %FrenchInput
@onready var portuguese_input: LineEdit = %PortuguesInput
@onready var add_button: Button = %AddButton
@onready var search_input: LineEdit = %SearchInput
@onready var result_label: Label = %ResultLabel
@onready var tab_container: TabContainer = %TabContainer
@onready var quiz_word_label: Label = %WordLabel
@onready var quiz_score_label: Label = %ScoreLabel
@onready var category_option: OptionButton = %CategoryOption
@onready var new_category_button: Button = %NewCategoryButton

func _ready() -> void:
	# Connexion des signaux des managers
	dictionary_manager.dictionary_updated.connect(_on_dictionary_updated)
	word_tree_view.word_selected.connect(_on_word_selected)
	word_tree_view.word_edit_requested.connect(_on_word_edit_requested)
	word_tree_view.word_delete_requested.connect(_on_word_delete_requested)
	quiz_manager.score_updated.connect(_on_score_updated)
	dialog_manager.dialog_confirmed.connect(_on_dialog_confirmed)
	
	# Connexion des signaux UI
	add_button.pressed.connect(_on_add_button_pressed)
	search_input.text_changed.connect(_on_search_text_changed)
	portuguese_input.text_submitted.connect(_on_add_button_pressed)
	tab_container.tab_selected.connect(_on_tab_selected)
	new_category_button.pressed.connect(_on_new_category_button_pressed)
	
	# Initialisation
	dictionary_manager.load_dictionary()
	_update_category_option()

# Gestionnaire de dictionnaire
func _on_dictionary_updated() -> void:
	word_tree_view.update_tree(dictionary_manager.dictionary)
	_update_category_option()

func _update_category_option() -> void:
	if category_option:
		category_option.clear()
		for category in dictionary_manager.dictionary.categories.keys():
			category_option.add_item(category)

# Gestion des mots
func _on_add_button_pressed(_submitted_text: String = "") -> void:
	var french_word = french_input.text.strip_edges()
	var portuguese_word = portuguese_input.text.strip_edges()
	var selected_category = category_option.get_item_text(category_option.selected)
	
	if french_word.is_empty() or portuguese_word.is_empty():
		_clear_inputs()
		return
	
	dictionary_manager.add_word(french_word, portuguese_word, selected_category)
	_clear_inputs()

func _clear_inputs() -> void:
	french_input.clear()
	portuguese_input.clear()
	french_input.grab_focus()

func _on_word_selected(french: String, portuguese: String) -> void:
	french_input.text = french
	portuguese_input.text = portuguese

# Gestion de la recherche
func _on_search_text_changed(new_text: String) -> void:
	new_text = new_text.strip_edges().to_lower()
	
	if new_text.is_empty():
		result_label.text = ""
		return
		
	var found_entries = []
	for french_word in dictionary_manager.dictionary.words:
		var entry = dictionary_manager.dictionary.words[french_word]
		if french_word.to_lower().contains(new_text) or \
		   entry.portuguese.to_lower().contains(new_text) or \
		   entry.category.to_lower().contains(new_text):
			found_entries.append("Français: %s\nPortugais: %s\nCatégorie: %s\nNiveau: %d/5" % [
				french_word,
				entry.portuguese,
				entry.category,
				entry.mastery_level
			])
	
	result_label.text = "Mot non trouvé" if found_entries.is_empty() else "\n\n".join(found_entries)

# Gestion des catégories
func _on_new_category_button_pressed() -> void:
	dialog_manager.show_new_category_dialog()

# Gestion du quiz
func _on_score_updated(score: int, total: int, streak: int) -> void:
	var total_words = dictionary_manager.dictionary.words.size()
	quiz_score_label.text = "Score: %d/%d - Série: %d - Total des mots: %d" % [
		score, total, streak, total_words
	]

# Gestion des dialogues
func _on_word_edit_requested(word: String) -> void:
	dialog_manager.show_edit_dialog(word, dictionary_manager.dictionary)

func _on_word_delete_requested(word: String) -> void:
	dialog_manager.show_delete_dialog(word)

func _on_dialog_confirmed(data: Dictionary) -> void:
	match data.dialog_type:
		"edit":
			dictionary_manager.update_word(
				data.old_word,
				data.new_french,
				data.new_portuguese,
				data.new_category
			)
		"delete":
			dictionary_manager.delete_word(data.word)
		"new_category":
			dictionary_manager.add_category(data.category_name)

# Gestion des onglets
func _on_tab_selected(tab_index: int) -> void:
	dictionary_manager.save_dictionary()
	word_tree_view.update_tree(dictionary_manager.dictionary)
	match tab_index:
		0:  # Onglet "Ajouter"
			await get_tree().create_timer(0.1).timeout
			french_input.grab_focus()
		1:  # Onglet "Rechercher"
			search_input.grab_focus()
			search_input.clear()
		3:  # Onglet "Quiz"
			quiz_manager.start_new_quiz(dictionary_manager.dictionary)

func _exit_tree() -> void:
	dictionary_manager.save_dictionary()
