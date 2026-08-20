## Developer-only launcher for playing the production Brief Puzzle directly.
extends Control

const BRIEF_PUZZLE_SCENE: PackedScene = preload(
	"res://scenes/card_screen/brief_puzzle.tscn"
)


func _ready() -> void:
	var puzzle: BriefPuzzle = BRIEF_PUZZLE_SCENE.instantiate()
	add_child(puzzle)
	puzzle.finished.connect(_on_puzzle_finished)
	if not puzzle.start(SpotlightMinigameConfig.load_config(&"brief_puzzle")):
		push_error("Brief Puzzle preview could not load its production config.")
		get_tree().quit(1)


func _on_puzzle_finished(_score: float, _abandoned: bool) -> void:
	get_tree().quit()
