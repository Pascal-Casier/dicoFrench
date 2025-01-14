extends Control

signal all_words_mastered


# Constantes
const SAVE_PATH = "user://dictionary.json"
const MIN_QUIZ_OPTIONS = 4
const BUTTON_MIN_SIZE = Vector2(200, 50)
const BUTTON_EDIT = 0
const BUTTON_DELETE = 1
const DEFAULT_CATEGORY = "Non classé"
const CORRECT_SOUND_EFFECT = preload("res://inventorySystem/Correct sound effect.mp3")
const WRONG_SOUND_EFFECT = preload("res://inventorySystem/wrong sound effect (mp3cut.net).mp3")

# Nouvelles constantes pour la priorité
const MAX_MASTERY_LEVEL = 5
const MASTERY_WEIGHT = 2.0
const TIME_WEIGHT = 1.0
const DAY_IN_SECONDS = 86400

var has_emitted_mastery_signal = false

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
@onready var category_option: OptionButton = %CategoryOption
@onready var new_category_button: Button = %NewCategoryButton
@onready var audio_stream_player: AudioStreamPlayer = %AudioStreamPlayer
@onready var confirmation_dialog: ConfirmationDialog = %ConfirmationDialog

# Variables pour le quiz
var quiz_state = {
	"current_word": "",
	"words": [],
	"score": 0,
	"total_questions": 0,
	"total_words": 0,
	"streak": 0
}

# Dictionnaire principal avec structure correcte
var dictionary = {
	"words": {},
	"categories": {}
}

var current_dialog: Window = null

class WordPriority:
	var word: String
	var priority: float
	
	func _init(w: String, p: float):
		word = w
		priority = p
	
	static func sort_by_priority(a: WordPriority, b: WordPriority) -> bool:
		return a.priority > b.priority

func _ready() -> void:
	initialize_dictionary()
	_setup_signals()
	_setup_tree()
	load_dictionary()
	update_score_display()

func initialize_dictionary() -> void:
	dictionary = {
		"words": {},
		"categories": {DEFAULT_CATEGORY: []}
	}
	_update_category_option()

func _update_category_option() -> void:
	if category_option:
		category_option.clear()
		for category in dictionary.categories.keys():
			category_option.add_item(category)

func _setup_signals() -> void:
	add_button.pressed.connect(_on_add_button_pressed)
	search_input.text_changed.connect(_on_search_text_changed)
	portuguese_input.text_submitted.connect(_on_add_button_pressed)  # Connecter le signal text_submitted
	tab_container.tab_selected.connect(_on_tab_selected)
	word_tree.button_clicked.connect(_on_tree_button_clicked)
	word_tree.cell_selected.connect(_on_word_tree_cell_selected)
	new_category_button.pressed.connect(_on_new_category_button_pressed)

func _on_word_tree_cell_selected() -> void:
	var selected_item = word_tree.get_selected()
	if selected_item and not selected_item.get_text(0).is_empty():
		var french_word = selected_item.get_text(0)
		if dictionary.words.has(french_word):
			french_input.text = french_word
			portuguese_input.text = dictionary.words[french_word].portuguese

func _show_dialog(dialog: Window) -> void:
	_cleanup_current_dialog()
	current_dialog = dialog
	add_child(dialog)
	dialog.popup_centered()

func _cleanup_current_dialog() -> void:
	if current_dialog and is_instance_valid(current_dialog):
		current_dialog.queue_free()
		current_dialog = null

func update_word_tree() -> void:
	word_tree.clear()
	var root = word_tree.create_item()
	
	for category_name in dictionary.categories.keys():
		var category_item = word_tree.create_item(root)
		category_item.set_text(0, category_name)
		category_item.set_custom_bg_color(0, Color(0.7, 0.7, 0.7, 0.3))
		
		for french_word in dictionary.categories[category_name]:
			if dictionary.words.has(french_word):
				var entry = dictionary.words[french_word]
				var word_item = word_tree.create_item(category_item)
				word_item.set_text(0, french_word)
				word_item.set_text(1, entry.portuguese)
				word_item.set_text(2, entry.category)
				word_item.set_text(3, str(entry.mastery_level) + "/5")
				word_item.add_button(4, preload("res://inventorySystem/icon_edit.png"), BUTTON_EDIT)
				word_item.add_button(4, preload("res://inventorySystem/icon_delete.png"), BUTTON_DELETE)

func _on_new_category_button_pressed() -> void:
	var dialog = AcceptDialog.new()
	var vbox = VBoxContainer.new()
	var input = LineEdit.new()
	
	vbox.custom_minimum_size = Vector2(350, 80)
	vbox.position = Vector2(16, 8)
	vbox.add_theme_constant_override("separation", 10)
	dialog.add_child(vbox)
	vbox.add_child(input)
	input.custom_minimum_size = Vector2(300, 40)
	input.placeholder_text = "Nom de la catégorie"
	
	dialog.title = "Nouvelle catégorie"
	dialog.min_size = Vector2(400, 150)
	dialog.confirmed.connect(func():
		var category_name = input.text.strip_edges()
		if not category_name.is_empty() and not dictionary.categories.has(category_name):
			dictionary.categories[category_name] = []
			_update_category_option()
			save_dictionary()
	)
	
	_show_dialog(dialog)

func _setup_tree() -> void:
	word_tree.columns = 5
	word_tree.set_column_titles_visible(true)
	word_tree.set_column_title(0, "Français")
	word_tree.set_column_title(1, "Portugais")
	word_tree.set_column_title(2, "Catégorie")
	word_tree.set_column_title(3, "Maîtrise")
	word_tree.set_column_title(4, "Actions")
	word_tree.set_column_title_alignment(3, HORIZONTAL_ALIGNMENT_CENTER)
	word_tree.set_column_title_alignment(4, HORIZONTAL_ALIGNMENT_CENTER)
	word_tree.set_column_custom_minimum_width(4, 120)
	word_tree.allow_reselect = true
	word_tree.hide_root = true
	word_tree.select_mode = Tree.SELECT_ROW
	word_tree.focus_mode = Control.FOCUS_ALL

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
			# Migration des anciennes données
			initialize_dictionary()
			for french_word in data:
				if typeof(data[french_word]) == TYPE_STRING:
					dictionary.words[french_word] = {
						"portuguese": data[french_word],
						"mastery_level": 0,
						"last_reviewed": Time.get_unix_time_from_system(),
						"category": DEFAULT_CATEGORY
					}
					dictionary.categories[DEFAULT_CATEGORY].append(french_word)
	
	_update_category_option()
	update_word_tree()

func _on_tree_button_clicked(item: TreeItem, _column: int, id: int, _mouse_button_index: int) -> void:
	var french_word = item.get_text(0)
	if id == BUTTON_EDIT:
		_show_edit_dialog(french_word)
	elif id == BUTTON_DELETE:
		_show_delete_dialog(french_word)

func _on_add_button_pressed(_submitted_text: String = "") -> void:
	var french_word = french_input.text.strip_edges()
	var portuguese_word = portuguese_input.text.strip_edges()
	var selected_category = category_option.get_item_text(category_option.selected)
	
	if french_word.is_empty() or portuguese_word.is_empty():
		_clear_inputs()
		return
	
	dictionary.words[french_word] = {
		"portuguese": portuguese_word,
		"mastery_level": 0,
		"last_reviewed": Time.get_unix_time_from_system(),
		"category": selected_category
	}
	
	if not dictionary.categories.has(selected_category):
		dictionary.categories[selected_category] = []
	if not french_word in dictionary.categories[selected_category]:
		dictionary.categories[selected_category].append(french_word)
	
	save_dictionary()
	update_word_tree()
	_clear_inputs()

func _clear_inputs() -> void:
	french_input.clear()
	portuguese_input.clear()
	french_input.grab_focus()
	if word_tree.get_selected():
		word_tree.deselect_all()

func _on_search_text_changed(new_text: String) -> void:
	new_text = new_text.strip_edges().to_lower()
	
	if new_text.is_empty():
		result_label.text = ""
		return
		
	var found_entries = []
	for french_word in dictionary.words:
		var entry = dictionary.words[french_word]
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

func _show_delete_dialog(french_word: String) -> void:
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Confirmer la suppression"
	confirm_dialog.dialog_text = "Voulez-vous vraiment supprimer le mot '%s' ?" % french_word
	confirm_dialog.min_size = Vector2(300, 100)
	
	confirm_dialog.confirmed.connect(func():
		var category = dictionary.words[french_word].category
		dictionary.categories[category].erase(french_word)
		dictionary.words.erase(french_word)
		save_dictionary()
		update_word_tree()
		_clear_inputs()
	)
	
	_show_dialog(confirm_dialog)

func _show_edit_dialog(french_word: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Éditer le mot"
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	vbox.position = Vector2(16, 8)
	vbox.custom_minimum_size = Vector2(200, 100)
	
	# Champs d'édition
	var french_container = HBoxContainer.new()
	var french_label = Label.new()
	french_label.text = "Français:"
	var french_edit = LineEdit.new()
	french_edit.text = french_word
	french_container.add_child(french_label)
	french_container.add_child(french_edit)
	
	var portuguese_container = HBoxContainer.new()
	var portuguese_label = Label.new()
	portuguese_label.text = "Portugais:"
	var portuguese_edit = LineEdit.new()
	portuguese_edit.text = dictionary.words[french_word].portuguese
	portuguese_container.add_child(portuguese_label)
	portuguese_container.add_child(portuguese_edit)
	
	var category_container = HBoxContainer.new()
	var category_label = Label.new()
	category_label.text = "Catégorie:"
	var edit_category_option = OptionButton.new()
	
	for category_name in dictionary.categories.keys():
		edit_category_option.add_item(category_name)
		if category_name == dictionary.words[french_word].category:
			edit_category_option.selected = edit_category_option.item_count - 1
	
	category_container.add_child(category_label)
	category_container.add_child(edit_category_option)
	
	vbox.add_child(french_container)
	vbox.add_child(portuguese_container)
	vbox.add_child(category_container)
	
	dialog.confirmed.connect(func():
		var new_french = french_edit.text.strip_edges()
		var new_portuguese = portuguese_edit.text.strip_edges()
		var new_category = edit_category_option.get_item_text(edit_category_option.selected)
		
		if not new_french.is_empty() and not new_portuguese.is_empty():
			var old_category = dictionary.words[french_word].category
			
			# Supprimer l'ancien mot de sa catégorie
			dictionary.categories[old_category].erase(french_word)
			
			# Si le mot français change
			if new_french != french_word:
				var entry = dictionary.words[french_word].duplicate()
				dictionary.words.erase(french_word)
				dictionary.words[new_french] = entry
				
				# Ajouter le nouveau mot à la catégorie appropriée
				if old_category == new_category:
					dictionary.categories[new_category].append(new_french)
			else:
				# Si seul le portugais change, remettre le mot français dans la catégorie
				dictionary.categories[old_category].append(french_word)
			
			# Si la catégorie change
			if old_category != new_category:
				# Supprimer de l'ancienne catégorie si nécessaire
				if dictionary.categories[old_category].has(new_french):
					dictionary.categories[old_category].erase(new_french)
				if dictionary.categories[old_category].has(french_word):
					dictionary.categories[old_category].erase(french_word)
					
				# Ajouter à la nouvelle catégorie
				if not dictionary.categories.has(new_category):
					dictionary.categories[new_category] = []
				dictionary.categories[new_category].append(new_french)
			
			# Mettre à jour les données du mot
			var target_word = new_french if new_french != french_word else french_word
			dictionary.words[target_word].portuguese = new_portuguese
			dictionary.words[target_word].category = new_category
			
			save_dictionary()
			update_word_tree()
	)
	
	_show_dialog(dialog)

func start_new_quiz() -> void:
	quiz_state.score = 0
	quiz_state.total_questions = 0
	quiz_state.streak = 0
	quiz_state.words = _get_prioritized_words()
	if quiz_state.words.size() > 10:
		quiz_state.words = quiz_state.words.slice(0, 10)
	update_score_display()
	next_quiz_question()

func _get_prioritized_words() -> Array:
	var current_time = Time.get_unix_time_from_system()
	var prioritized_words: Array[WordPriority] = []
	
	for french_word in dictionary.words:
		var entry = dictionary.words[french_word]
		var priority = _calculate_word_priority(entry, current_time)
		prioritized_words.append(WordPriority.new(french_word, priority))
	
	prioritized_words.sort_custom(WordPriority.sort_by_priority)
	
	var words = []
	for wp in prioritized_words:
		words.append(wp.word)
	
	return words

func _calculate_word_priority(entry: Dictionary, current_time: float) -> float:
	var mastery_factor = (MAX_MASTERY_LEVEL - entry.mastery_level) / float(MAX_MASTERY_LEVEL)
	var days_since_last_review = (current_time - entry.last_reviewed) / DAY_IN_SECONDS
	var time_factor = min(days_since_last_review / 7.0, 1.0)
	
	return (mastery_factor * MASTERY_WEIGHT) + (time_factor * TIME_WEIGHT)

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
	var correct_answer = dictionary.words[quiz_state.current_word].portuguese
	var answers = [correct_answer]
	
	var wrong_answers = []
	for word in dictionary.words:
		if word != quiz_state.current_word:
			wrong_answers.append(dictionary.words[word].portuguese)
	
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
	var word_data = dictionary.words[quiz_state.current_word]
	quiz_state.total_questions += 1
	
	if answer == word_data.portuguese:
		quiz_state.score += 1
		quiz_state.streak += 1
		word_data.mastery_level = mini(word_data.mastery_level + 1, MAX_MASTERY_LEVEL)
		audio_stream_player.stream = CORRECT_SOUND_EFFECT
		audio_stream_player.play()
	else:
		quiz_state.streak = 0
		word_data.mastery_level = maxi(word_data.mastery_level - 1, 0)
		audio_stream_player.stream = WRONG_SOUND_EFFECT
		audio_stream_player.play()
	
	word_data.last_reviewed = Time.get_unix_time_from_system()
	update_score_display()
	save_dictionary()
	check_all_words_mastery()
	next_quiz_question()

func reset_mastery_signal() -> void:
	has_emitted_mastery_signal = false

func update_score_display() -> void:
	quiz_state.total_words = dictionary.words.size()
	quiz_score_label.text = "Score: %d/%d - Série: %d - Total des mots: %d" % [
		quiz_state.score,
		quiz_state.total_questions,
		quiz_state.streak,
		quiz_state.total_words
	]

func check_all_words_mastery() -> void:
	if dictionary.words.is_empty() or has_emitted_mastery_signal:
		return
		
	var all_mastered = true
	for word in dictionary.words.values():
		if word.mastery_level < MAX_MASTERY_LEVEL:
			all_mastered = false
			break
	
	if all_mastered:
		has_emitted_mastery_signal = true
		emit_signal("all_words_mastered")
		confirmation_dialog.show()
		reset_mastery_signal()



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

func _exit_tree() -> void:
	_cleanup_current_dialog()
