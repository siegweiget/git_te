extends StaticBody2D

## A villager the player can walk up to and talk to.
##
## The NPC is a StaticBody2D — a body that never moves — for two jobs at once:
## it stops the hero walking through the person she is chatting to, and it is
## something the player's InteractArea can find. There is no Area2D on this
## scene, because the *player* is the one doing the looking.
##
## Talking is deliberately one-way here: this script decides what the lines are
## and hands them to the dialogue box. It does not know how the box is drawn.
##
## The one thing it *does* wait for is the end of its own conversation. Two of
## the elder's five speeches move the main quest on, and they have to do it after
## the player has read the last line rather than the moment the panel opens —
## otherwise the reward is announced by a line the player has not seen yet.

## The quest states in which talking to this NPC pushes the story forward.
##
## Written down as data rather than as an `if` buried in talk(), so the list of
## "conversations that matter" is readable in one place. Every other state is a
## conversation with no consequences, and deliberately does not connect anything.
const ADVANCING_STATES: Array[String] = ["not_started", "turn_in"]

## The event handed to GameState when one of those conversations ends. GameState
## alone decides what it means — see advance_quest() over there.
const QUEST_EVENT := "talked_to_elder"

## Identifier used by the quest code. Not shown to the player.
@export var npc_id: String = "elder"

## The name shown on the first line of the conversation.
@export var display_name: String = "Elder Rowan"

# True between "this NPC opened a conversation that will advance the quest" and
# "that conversation finished". It is the reentry guard: without it, a second
# talk() would connect a second one-shot listener and the quest would be pushed
# forward twice by one speech.
var _awaiting_finish: bool = false


## Starts a conversation. Called by OverworldPlayer when the interact button is
## pressed and this NPC is the nearest talkable thing.
func talk() -> void:
	# The dialogue box is found through its group rather than a node path,
	# because it is instanced beside this NPC in overworld.tscn rather than above
	# it — a path would have to guess at the shape of the whole scene.
	var box: DialogueBox = get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if box == null:
		push_warning("NPC: no dialogue box in the scene, cannot talk")
		return

	# Already mid-speech with a quest payload waiting on it: do nothing at all.
	# Restarting the conversation would re-arm the payload.
	if _awaiting_finish:
		return

	# Built here, at the moment of talking, rather than cached: the hunt line
	# quotes a running kill count that changes between visits.
	var lines: PackedStringArray = _build_lines()
	if lines.is_empty():
		return

	# Only listen when this particular speech is one that moves the story. A
	# CONNECT_ONE_SHOT connection removes itself the first time it fires, so the
	# listener lives exactly as long as this one conversation and cannot be woken
	# by somebody else's dialogue later on.
	if ADVANCING_STATES.has(GameState.quest_state):
		_awaiting_finish = true
		box.dialogue_finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)

	box.show_dialogue(lines)


# The player has read the last line. Now the quest may move.
func _on_dialogue_finished() -> void:
	_awaiting_finish = false
	# GameState owns the ordering: it works out which stage this event belongs to,
	# recruits Mira, unlocks the dash and writes the save file on the way past.
	GameState.advance_quest(QUEST_EVENT)


# Picks what this NPC has to say right now.
#
# PackedStringArray rather than a plain Array because every element is a String
# and Godot stores it more compactly that way. The first entry is always the
# speaker's name, which the dialogue box shows as its own line — a cheap name tag
# that needs no extra label.
func _build_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append(display_name)

	match GameState.quest_state:
		"not_started":
			lines.append("You have your mother's stubborn chin, child. Good — you will need it.")
			lines.append("The wilds grow restless. Cull three of the beasts east of the fence, and the village sleeps easier.")

		"hunt":
			lines.append("Three beasts, no fewer. You have felled %d of %d." % [GameState.quest_kills, GameState.KILLS_FOR_BOSS])
			lines.append("The gap in the fence is your road east. Mind the rocks out there.")

		"boss":
			lines.append("The beasts are culled, but something worse has come down out of the deep wood.")
			lines.append("A monstrous brute has appeared in the far clearing. Slay it, and this is finished.")

		"turn_in":
			lines.append("The brute is dead. You have given this village back its evenings, child.")
			lines.append("Mira the archer will walk with you now — she has waited a long time for someone worth following.")
			lines.append("And you have learned Dash: press K or Shift, or tap the new button in a fight.")

		"complete":
			lines.append("Sit a while. The bread is warm and nothing is howling out in the dark.")
			lines.append("Mira fights beside you now — press Q, or tap Switch, to take her reins.")

		_:
			# An unknown state should never happen, but saying *something* beats
			# opening an empty box that cannot be closed.
			lines.append("The wilds are quiet enough today. Long may it last.")

	return lines
