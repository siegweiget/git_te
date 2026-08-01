extends CanvasLayer

## The on-screen touch controls for a battle.
##
## A CanvasLayer draws on top of the world and ignores the camera, so the
## buttons stay put no matter what is happening in the arena.
##
## The only logic here is hiding the two buttons that are not always available.
## Doing it in _ready() — once, when the battle opens — is enough, because
## neither the party's size nor the dash unlock can change mid-fight.

# @onready waits until the node is inside the scene tree before running, which
# is when these children are guaranteed to exist.
@onready var dash_button: TouchScreenButton = $DashButton
@onready var switch_button: TouchScreenButton = $SwitchButton


func _ready() -> void:
	# Dashing is a quest reward. Until it is earned there is nothing behind the
	# button, so showing it would just be a lie.
	dash_button.visible = GameState.has_ability("dash")

	# Copying the party into a typed local before reading it. GameState.party is
	# an Array[CharacterStats]; going through a correctly typed variable keeps
	# the engine from having to guess, which it does not always do well.
	var members: Array[CharacterStats] = GameState.party
	switch_button.visible = members.size() > 1
