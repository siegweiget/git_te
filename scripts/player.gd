extends CharacterBody2D

## Minimal side-scrolling player controller.
##
## The node this is attached to is a CharacterBody2D: a body you move yourself
## (by writing to `velocity` and calling `move_and_slide()`) while the physics
## engine handles collision response for you.

# @export makes a variable editable in the Inspector, so you can tune the feel
# of the character without touching the code. Values set in the Inspector
# override the defaults written here.

## Horizontal run speed, in pixels per second.
@export var speed: float = 300.0

## Upward impulse applied when jumping. Negative because in Godot's 2D
## coordinate system the Y axis points DOWN, so "up" is a negative value.
@export var jump_velocity: float = -400.0

# @onready waits until the node is inside the scene tree before running, which
# is when child nodes are guaranteed to exist. "$Sprite2D" is shorthand for
# get_node("Sprite2D").
@onready var sprite: Sprite2D = $Sprite2D


# _physics_process runs at a fixed rate (60 times a second by default). Always
# do movement/physics here rather than in _process, so it behaves the same on
# every machine. `delta` is the time in seconds since the last physics frame.
func _physics_process(delta: float) -> void:
	# Gravity. get_gravity() returns the gravity vector affecting this body
	# (from Project Settings > Physics > 2D > Default Gravity, 980 px/s² by
	# default). We only accumulate it while airborne so the body does not build
	# up downward speed while resting on the floor.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jumping. "jump" is a custom action defined in
	# Project Settings > Input Map (Space / W / Up arrow).
	# is_action_just_pressed() fires only on the frame the key goes down, so
	# holding the key does not re-trigger the jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Horizontal movement. get_axis() returns -1.0 when only the first action is
	# held, +1.0 when only the second is, and 0.0 when neither or both are.
	var direction: float = Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		velocity.x = direction * speed
		# Face the way we are moving. The artwork looks right, so it only needs
		# flipping when we travel left.
		sprite.flip_h = direction < 0.0
	else:
		# No input: ease back to a standstill instead of stopping dead.
		# Using `speed` as the step means we stop within roughly one frame,
		# which is snappy; lower it for a slidier, more slippery character.
		velocity.x = move_toward(velocity.x, 0.0, speed)

	# Applies `velocity`, slides along walls/slopes instead of sticking to them,
	# and updates is_on_floor() / is_on_wall() for the next frame.
	move_and_slide()
