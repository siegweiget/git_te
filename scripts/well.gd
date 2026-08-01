extends StaticBody2D

## The village well: a save point you can walk up to.
##
## This is the smallest possible "interactable". It is not an NPC and it has no
## quest state; all it shares with the elder is a `talk()` method. That is
## enough, because OverworldPlayer._try_interact() finds things by asking
## has_method("talk") rather than by checking their class — so anything that can
## answer to talk() is talkable, and adding one costs a five-line script.
##
## Resting here does not heal anybody, and that is not an oversight: current HP
## is battle-only state that fighter.gd rebuilds from CharacterStats at the start
## of every fight, so the party already arrives at full health. What the well
## actually gives the player is a *checkpoint they asked for*, written on demand
## instead of only when the quest happens to move.

## What the well says. Three lines: the name tag, the flavour, and the one piece
## of information that matters.
const LINES: Array[String] = [
	"Well",
	"You draw cool water and rest a moment.",
	"Game saved.",
]


## Called by OverworldPlayer when the interact button is pressed and this well is
## the nearest talkable thing.
func talk() -> void:
	var box: DialogueBox = get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if box == null:
		push_warning("Well: no dialogue box in the scene, cannot rest here")
		return

	# Saved *before* the panel opens, so "Game saved." is already true by the time
	# anybody reads it. Nothing here waits on dialogue_finished: unlike the
	# elder's speech there is no reward to withhold until the last line, and a
	# save that only lands if the player finishes reading would be a trap.
	GameState.save_game()

	# PackedStringArray is what show_dialogue() takes; the constant above is a
	# plain Array[String] because a PackedStringArray cannot be a `const`.
	box.show_dialogue(PackedStringArray(LINES))
