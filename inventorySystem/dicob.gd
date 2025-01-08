extends Control

# Variables pour stocker les références aux nœuds
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
var current_word: String = ""
var quiz_words: Array = []
var score: int = 0
var total_questions: int = 0
var total_words: int = 0

# Dictionnaire pour stocker les mots
var dictionary = {}
# Chemin du fichier de sauvegarde
const SAVE_PATH = "user://dictionary.json"

func _ready():
	# Connexion des signaux
	add_button.pressed.connect(_on_add_button_pressed)
	search_input.text_changed.connect(_on_search_text_changed)
	tab_container.tab_selected.connect(_on_tab_selected)
	
	# Configuration de l'arbre
	word_tree.columns = 2  # Définit le nombre de colonnes
	word_tree.set_column_expand(0, true)  # Permet à la colonne de s'étendre
	word_tree.set_column_expand(1, true)
	word_tree.set_column_custom_minimum_width(0, 200)  # Largeur minimale
	word_tree.set_column_custom_minimum_width(1, 200)
	word_tree.set_column_titles_visible(true)
	word_tree.set_column_title(0, "Français")
	word_tree.set_column_title(1, "Portugais")
	word_tree.allow_reselect = true
	word_tree.hide_root = true  # Cache le nœud racine
	
	# Chargement des mots sauvegardés
	load_dictionary()
	
	# Initialisation du score
	update_score_display()


func save_dictionary():
	var save_file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var json_string = JSON.stringify(dictionary)
	save_file.store_line(json_string)

func load_dictionary():
	if FileAccess.file_exists(SAVE_PATH):
		var save_file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var json_string = save_file.get_as_text()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			dictionary = json.get_data()
			update_word_tree()

func start_new_quiz():
	score = 0
	total_questions = 0
	quiz_words = dictionary.keys()
	update_score_display()
	next_quiz_question()

func next_quiz_question():
	if quiz_words.is_empty():
		quiz_word_label.text = "Quiz terminé !"
		# Nettoyer les boutons
		for child in quiz_buttons_container.get_children():
			child.queue_free()
		return
		
	# Sélectionner un mot aléatoire
	var random_index = randi() % quiz_words.size()
	current_word = quiz_words[random_index]
	quiz_words.remove_at(random_index)
	
	quiz_word_label.text = current_word
	
	# Créer une liste de réponses possibles
	var answers = []
	answers.append(dictionary[current_word])  # Bonne réponse
	
	# Ajouter 3 mauvaises réponses aléatoires
	var other_translations = dictionary.values()
	other_translations = other_translations.filter(func(x): return x != dictionary[current_word])
	
	for i in range(min(3, other_translations.size())):
		var random_translation_index = randi() % other_translations.size()
		answers.append(other_translations[random_translation_index])
		other_translations.remove_at(random_translation_index)
	
	# Mélanger les réponses
	answers.shuffle()
	
	# Supprimer les anciens boutons
	for child in quiz_buttons_container.get_children():
		child.queue_free()
	
	# Créer les nouveaux boutons
	for answer in answers:
		var button = Button.new()
		button.text = answer
		button.custom_minimum_size = Vector2(200, 50)
		button.pressed.connect(_on_answer_button_pressed.bind(answer))
		quiz_buttons_container.add_child(button)

func _on_answer_button_pressed(answer: String):
	total_questions += 1
	if answer == dictionary[current_word]:
		score += 1
	update_score_display()
	next_quiz_question()

func update_score_display():
	total_words = dictionary.size()
	quiz_score_label.text = "Score: %d/%d - Total des mots: %d" % [score, total_questions, total_words]
	quiz_score_label.text = "Score: %d/%d" % [score, total_questions]

func _on_add_button_pressed(_text : String = ""):
	var french_word = french_input.text.strip_edges()
	var portuguese_word = portuguese_input.text.strip_edges()
	french_input.grab_focus()
	
	if french_word != "" and portuguese_word != "":
		dictionary[french_word] = portuguese_word
		save_dictionary()  # Sauvegarde après l'ajout
		update_word_tree()
		
		# Réinitialisation des champs
		french_input.text = ""
		portuguese_input.text = ""
	else:
		french_input.clear()
		portuguese_input.clear()
		french_input.grab_focus()

func _on_search_text_changed(new_text: String):
	new_text = new_text.strip_edges().to_lower()
	
	if new_text != "":
		var found = false
		for french_word in dictionary.keys():
			if french_word.to_lower().contains(new_text):
				result_label.text = "Français: " + french_word + "\nPortugais: " + dictionary[french_word]
				found = true
				break
		
		if !found:
			result_label.text = "Mot non trouvé"
	else:
		result_label.text = ""

func update_word_tree():
	word_tree.clear()
	var root = word_tree.create_item()
	
	# Création d'une liste triée des mots français
	var sorted_words = dictionary.keys()
	sorted_words.sort()
	
	# Vérification pour le débogage
	print("Nombre de mots à afficher : ", sorted_words.size())
	
	for french_word in sorted_words:
		var item = word_tree.create_item(root)
		item.set_text(0, french_word)
		item.set_text(1, dictionary[french_word])
		print("Ajout du mot : ", french_word)  # Débogage

func _on_tab_selected(tab_index: int):
	if tab_index == 0:  # Si c'est l'onglet "Ajouter"
		await get_tree().create_timer(0.1).timeout
		french_input.grab_focus()
	elif tab_index == 1:
		search_input.grab_focus()
	elif tab_index == 3:  # Onglet "Quiz"
		start_new_quiz()
