extends Node

const BUTTON_EDIT = 0
const BUTTON_DELETE = 1

signal word_selected(french: String, portuguese: String)
signal word_edit_requested(word: String)
signal word_delete_requested(word: String)

@onready var word_tree: Tree = %WordTree

func _ready() -> void:
	_setup_tree()
	word_tree.button_clicked.connect(_on_tree_button_clicked)
	word_tree.cell_selected.connect(_on_cell_selected)

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

func update_tree(dictionary: Dictionary) -> void:
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
