extends StaticBody2D

## A villager the player can walk up to and talk to.
##
## The NPC is a StaticBody2D — a body that never moves — for two jobs at once:
## it stops the hero walking through the person she is chatting to, and it is
## something the player's InteractArea can find. There is no Area2D on this
## scene, because the *player* is the one doing the looking.
##
## Talking is deliberately one-way here: this script decides what the lines are
## and hands them to the dialogue box. It does not wait for an answer and it
## does not know how the box is drawn.

## Identifier used by the quest code. Not shown to the player.
@export var npc_id: String = "elder"

## The name shown on the first line of the conversation.
@export var display_name: String = "Elder Rowan"


## Starts a conversation. Called by OverworldPlayer when the interact button is
## pressed and this NPC is the nearest talkable thing.
func talk() -> void:
	var lines: PackedStringArray = _build_lines()

	# The dialogue box is found through its group rather than a node path,
	# because it is instanced beside this NPC in overworld.tscn rather than above
	# it — a path would have to guess at the shape of the whole scene.
	var box: DialogueBox = get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	if box == null:
		push_warning("NPC: no dialogue box in the scene, cannot talk")
		return

	box.show_dialogue(lines)


# Picks what this NPC has to say right now.
#
# The quest state is already switched on here so that the real writing has an
# obvious place to go; every branch just says the same placeholder for the
# moment. PackedStringArray rather than a plain Array because every element is a
# String and Godot stores it more compactly that way.
func _build_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append(display_name)

	# WP4: quest wiring goes here — replace the placeholder line in each branch
	# with the real dialogue, and call GameState.advance_quest("talked_to_elder")
	# from the branches that are supposed to move the story on (listen for the
	# box's dialogue_finished signal so the quest advances after the last line,
	# not before the first).
	match GameState.quest_state:
		"not_started":
			lines.append("Placeholder dialogue.")
		"hunt":
			lines.append("Placeholder dialogue.")
		"boss":
			lines.append("Placeholder dialogue.")
		"turn_in":
			lines.append("Placeholder dialogue.")
		"complete":
			lines.append("Placeholder dialogue.")
		_:
			# An unknown state should never happen, but saying *something* beats
			# opening an empty box that cannot be closed.
			lines.append("Placeholder dialogue.")

	return lines
