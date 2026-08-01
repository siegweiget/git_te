class_name DialogueBox
extends CanvasLayer

## The panel at the bottom of the screen that shows what somebody just said.
##
## It is a CanvasLayer so it draws in screen space: the camera follows the hero
## all over a 2304x1296 map, and a normal Node2D panel would be left behind in
## the grass. A high layer number puts it in front of the HUD.
##
## Conversations are handed over as a finished list of lines. Whoever starts one
## does not have to know how the panel is laid out, and this script does not have
## to know anything about quests — it shows lines, advances on a button press,
## and says when it is done.

## Emitted once the last line has been dismissed and the panel is closed again.
## WP4's quest wiring listens for this so the story only moves on *after* the
## player has actually read what was said.
signal dialogue_finished

## True while a conversation is on screen. Read by the overworld enemies, which
## hold still rather than ambush somebody who is stuck in a menu.
var is_open: bool = false

# The conversation being shown and how far through it we are.
var _lines: PackedStringArray = PackedStringArray()
var _index: int = 0

# The frame on which the panel last changed line (or opened).
#
# This exists because of one very specific bug: the same press of "interact"
# that opens the box would, a moment later in the very same frame, be seen again
# here and skip straight past the first line. Remembering the frame number and
# refusing to act twice within it fixes that, and also stops a tap that lands on
# the HUD's interact button from counting as two advances (once as a button
# press, once as the action it fires).
var _last_change_frame: int = -1

@onready var panel: PanelContainer = $Panel
@onready var text_label: Label = $Panel/Margin/VBox/TextLabel
@onready var hint_label: Label = $Panel/Margin/VBox/HintLabel
@onready var tap_catcher: Button = $TapCatcher


func _ready() -> void:
	# Same idea as the player's group: NPCs find this node by group rather than
	# by path, so the box can be instanced anywhere in the overworld scene.
	add_to_group("dialogue_box")

	# A full-screen, fully transparent Button is the simplest way to make
	# "tap anywhere to continue" work on a phone. It only exists while a
	# conversation is up, so it can never swallow a tap meant for the D-pad.
	tap_catcher.pressed.connect(_advance)

	_close(false)


## Puts a conversation on screen and freezes the player until it is finished.
##
## Calling this while another conversation is open simply replaces it, which is
## the least surprising thing that can happen.
func show_dialogue(lines: PackedStringArray) -> void:
	if lines.is_empty():
		# An empty conversation would open a panel with nothing in it and no
		# obvious way out, so refuse it rather than trap the player.
		push_warning("DialogueBox: show_dialogue() called with no lines")
		return

	_lines = lines
	_index = 0
	is_open = true
	_last_change_frame = Engine.get_process_frames()

	panel.visible = true
	tap_catcher.visible = true
	text_label.text = _lines[0]
	hint_label.visible = true

	_set_player_frozen(true)


# _unhandled_input() only sees events that nothing else has already claimed,
# which is exactly right for a "press to continue" prompt.
func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return

	if event.is_action_pressed("interact"):
		_advance()
		# Tell the viewport this event is dealt with, so the press cannot also be
		# read by anything further down the chain.
		get_viewport().set_input_as_handled()


# Moves on to the next line, or closes the box if that was the last one.
func _advance() -> void:
	if not is_open:
		return

	# The one-frame guard described above.
	var frame: int = Engine.get_process_frames()
	if frame == _last_change_frame:
		return
	_last_change_frame = frame

	_index += 1

	if _index >= _lines.size():
		_close(true)
		return

	text_label.text = _lines[_index]


# Hides everything and gives the player back the controls.
#
# `announce` is false when this is called from _ready() to set the starting
# state: nothing has finished, so nothing should be announced.
func _close(announce: bool) -> void:
	is_open = false
	_lines = PackedStringArray()
	_index = 0

	panel.visible = false
	tap_catcher.visible = false

	_set_player_frozen(false)

	if announce:
		dialogue_finished.emit()


# Freezes or unfreezes whoever is walking around the overworld.
#
# The player is looked up every time rather than cached, because this box
# outlives no scene changes and the lookup is cheap. A null result is fine and
# ignored: the dialogue box works just as well in a test scene with no player.
func _set_player_frozen(value: bool) -> void:
	var player: OverworldPlayer = get_tree().get_first_node_in_group("overworld_player") as OverworldPlayer
	if player != null:
		player.frozen = value
