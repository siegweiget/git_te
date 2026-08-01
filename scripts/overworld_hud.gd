extends CanvasLayer

## The overworld's heads-up display: the touch D-pad, the interact button, and
## the one line of text telling the player what the quest wants from them next.
##
## Only the tracker needs code. The buttons are TouchScreenButtons wired straight
## to input actions in overworld_hud.tscn and never change.
##
## The tracker is refreshed from two directions, and it needs both:
##
##   * _ready(), every time the overworld scene is built. Battles happen in a
##     different scene tree entirely, so all the progress made in a fight lands
##     while this node does not exist. Reading GameState on the way in is what
##     makes the label right after every return trip.
##   * GameState.quest_changed, for progress made without leaving the map —
##     which today means finishing a conversation with the elder.

# @onready waits until this node is in the scene tree, which is the first moment
# its children are guaranteed to exist.
@onready var quest_label: Label = $QuestTracker


func _ready() -> void:
	# GameState is an autoload, so it outlives this scene. The connection does not
	# have to be undone by hand: Godot drops it automatically when this node is
	# freed on the next scene change.
	GameState.quest_changed.connect(_on_quest_changed)
	_refresh()


# quest_changed hands over the state that was just entered. It is ignored here
# because _objective_text() reads GameState directly — one source of truth beats
# two, and the kill counter is not in the signal's payload anyway.
func _on_quest_changed(_new_state: String) -> void:
	_refresh()


# Writes the current objective into the label, and hides the label completely
# when there is nothing left to ask for.
#
# Hiding rather than showing an empty string matters: an empty Label still draws
# its outline padding and still occupies the corner of the screen.
func _refresh() -> void:
	var objective: String = _objective_text()
	quest_label.text = objective
	quest_label.visible = not objective.is_empty()


# One short line per stage of the main quest.
#
# The hunt line is the only one that is not a constant, because it is the only
# stage with something to count. KILLS_FOR_BOSS is read from GameState rather
# than typed in, so raising the quota changes the label too.
func _objective_text() -> String:
	match GameState.quest_state:
		"not_started":
			return "Talk to Elder Rowan"
		"hunt":
			return "Cull the wilds: %d/%d" % [GameState.quest_kills, GameState.KILLS_FOR_BOSS]
		"boss":
			return "Slay the brute in the far clearing"
		"turn_in":
			return "Return to Elder Rowan"

	# "complete" and anything unexpected: nothing to track, so show nothing.
	return ""
