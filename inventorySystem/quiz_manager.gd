extends Node

signal quiz_completed(score: int, total: int)
signal score_updated(score: int, total: int, streak: int)

const MIN_QUIZ_OPTIONS = 4
const MAX_MASTERY_LEVEL = 5
const MASTERY_WEIGHT = 2.0
const TIME_WEIGHT = 1.0
const DAY_IN_SECONDS = 86400

var quiz_state = {
	"current_word": "",
	"words": [],
	"score": 0,
	"total_questions": 0,
	"total_words": 0,
	"streak": 0
}

class WordPriority:
	var word: String
	var priority: float
	
	func _init(w: String, p: float):
		word = w
		priority = p
	
	static func sort_by_priority(a: WordPriority, b: WordPriority) -> bool:
		return a.priority > b.priority

func start_new_quiz(dictionary: Dictionary) -> void:
	quiz_state.score = 0
	quiz_state.total_questions = 0
	quiz_state.streak = 0
	quiz_state.words = _get_prioritized_words(dictionary)
	if quiz_state.words.size() > 10:
		quiz_state.words = quiz_state.words.slice(0, 10)
	score_updated.emit(quiz_state.score, quiz_state.total_questions, quiz_state.streak)
