class_name OverworldPlayer
extends CharacterBody2D

## The hero as she is steered around the village and the wilds.
##
## This is a much smaller script than fighter.gd, and deliberately so. There is
## no gravity here, no jumping and no attacking: the overworld is a top-down map,
## so "up" is a real direction you can walk in rather than something you fall
## back down from. All this node has to do is move, face the way it is going, and
## notice when the player wants to talk to somebody.
##
## The node is a CharacterBody2D, the same kind of body the battle fighters use:
## you write a `velocity` and call move_and_slide(), and the physics engine takes
## care of sliding you along walls instead of letting you tunnel through them.

## How fast the hero walks, in pixels per second. @export puts it in the
## Inspector so it can be tuned without editing this file.
@export var speed: float = 220.0

## While this is true the hero ignores the controls completely.
##
## The dialogue box sets it so the player cannot wander off mid-conversation,
## and clears it again when the last line has been read. It is a plain variable
## rather than a function because "am I allowed to move?" is state, not an event.
var frozen: bool = false

# @onready waits until this node is inside the scene tree, which is the first
# moment its children are guaranteed to exist.
@onready var sprite: Sprite2D = $Sprite2D
@onready var interact_area: Area2D = $InteractArea


func _ready() -> void:
	# Other scripts (the dialogue box, the overworld enemies) need to find the
	# player without holding a reference to it. A group is Godot's way of doing
	# that: any node can ask the tree for "whoever is in this group".
	#
	# The group is also set on the node in overworld_player.tscn; adding it here
	# too is harmless (groups are a set, so it cannot end up in there twice) and
	# means the script still works if the scene is ever rebuilt by hand.
	add_to_group("overworld_player")


# Movement lives in _physics_process because it runs at a fixed rate — 60 times
# a second by default — so the hero covers the same ground on a fast machine as
# on a slow one.
func _physics_process(_delta: float) -> void:
	if frozen:
		# Standing still is not the same as "not moving": leftover velocity would
		# keep carrying the body along. Zero it and still call move_and_slide() so
		# the engine keeps this body's collision state up to date.
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# get_vector() reads all four actions at once and hands back a direction
	# vector that is already length-limited to 1, so walking diagonally is not
	# secretly 40% faster than walking straight.
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed

	# The artwork is drawn facing right, so it only needs mirroring when we are
	# heading left. Walking straight up or down leaves x at 0 and the sprite
	# keeps whatever way it was already facing, which looks better than snapping.
	if direction.x != 0.0:
		sprite.flip_h = direction.x < 0.0

	move_and_slide()

	# is_action_just_pressed() is true only on the frame the button goes down, so
	# leaning on the key does not re-open the same conversation over and over.
	if Input.is_action_just_pressed("interact"):
		_try_interact()


# Looks for the nearest thing standing inside InteractArea that knows how to be
# talked to, and talks to it.
#
# Both bodies and areas are checked. NPCs are StaticBody2D and so turn up in the
# body list, but collecting areas too means a later work package can add a
# talkable signpost or a save point as an Area2D without touching this script.
func _try_interact() -> void:
	# An untyped Array on purpose: it holds two different kinds of node and only
	# ever gets read back one element at a time.
	var candidates: Array = []
	candidates.append_array(interact_area.get_overlapping_bodies())
	candidates.append_array(interact_area.get_overlapping_areas())

	var best: Node = null
	var best_distance: float = INF

	for node in candidates:
		# has_method() is the duck-typing check: anything that can answer to
		# talk() counts, whatever class it happens to be.
		if not node.has_method("talk"):
			continue

		var other: Node2D = node as Node2D
		if other == null:
			continue

		# distance_squared_to() rather than distance_to(): comparing squares puts
		# the candidates in exactly the same order and skips a square root each.
		var d: float = global_position.distance_squared_to(other.global_position)
		if d < best_distance:
			best_distance = d
			best = other

	if best != null:
		best.call("talk")
