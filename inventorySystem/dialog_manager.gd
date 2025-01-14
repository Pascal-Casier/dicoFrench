extends Node

var current_dialog: Window = null

signal dialog_confirmed(data: Dictionary)

func show_edit_dialog(word: String, dictionary: Dictionary) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Éditer le mot"
	
	# ... (reste du code pour le dialogue d'édition)
	
	dialog.confirmed.connect(func():
		var data = {
			"old_word": word,
			"new_french": french_edit.text.strip_edges(),
			"new_portuguese": portuguese_edit.text.strip_edges(),
			"new_category": edit_category_option.get_item_text(edit_category_option.selected)
		}
		dialog_confirmed.emit(data)
	)
	
	_show_dialog(dialog)
