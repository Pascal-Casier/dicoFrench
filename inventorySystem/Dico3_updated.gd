
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

func _setup_tree() -> void:
	word_tree.columns = 4  # Ajout d'une colonne pour les actions
	word_tree.set_column_titles_visible(true)
	word_tree.set_column_title(0, "Français")
	word_tree.set_column_title(1, "Portugais")
	word_tree.set_column_title(2, "Maîtrise")
	word_tree.set_column_title(3, "Action")  # Colonne des actions
	word_tree.set_column_expand(3, false)  # Empêcher l'expansion automatique
	word_tree.allow_reselect = true
	word_tree.hide_root = true

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

		# Créez un bouton "Supprimer"
		var delete_button = Button.new()
		delete_button.text = "Supprimer"
		delete_button.custom_minimum_size = BUTTON_MIN_SIZE / 4  # Ajustez la taille
		delete_button.pressed.connect(callable(self, "_on_delete_button_pressed").bind(french_word))  # Nouvelle syntaxe
		word_tree.set_cell_mode(item, 3, Tree.CELL_MODE_CUSTOM)  # Mode personnalisé
		word_tree.set_custom_control(item, 3, delete_button)  # Associez le bouton à la cellule

func _on_delete_button_pressed(french_word: String) -> void:
	if dictionary.has(french_word):
		dictionary.erase(french_word)  # Supprimez le mot du dictionnaire
		save_dictionary()  # Sauvegardez les changements
		update_word_tree()  # Mettez à jour l'arbre

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

func _on_tab_selected(tab_index: int) -> void:
	match tab_index:
		0:  # Onglet "Ajouter"
			await get_tree().create_timer(0.1).timeout
			french_input.grab_focus()
		1:  # Onglet "Rechercher"
			search_input.grab_focus()
		3:  # Onglet "Quiz"
			start_new_quiz()
