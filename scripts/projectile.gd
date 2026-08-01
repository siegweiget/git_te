class_name Projectile
extends Area2D

## A thing that has been thrown at somebody.
##
## Area2D rather than a physics body: a projectile does not need to be pushed
## around or to stand on the floor, it only needs to notice what it flies into.
## Areas report overlaps and otherwise stay out of the physics engine's way.
##
## Everything it needs to know — where it is going, how hard it hits and whose
## side it is on — is handed to it by setup() before it enters the tree.

## How fast it travels, in pixels per second.
const SPEED := 350.0

## Seconds before it gives up and removes itself. Without this, a shot fired at
## the sky would live for the rest of the session, and a long fight would end up
## dragging hundreds of forgotten nodes around.
const LIFETIME := 3.0

## Unit vector pointing where it is headed.
var direction: Vector2 = Vector2.RIGHT

## Damage dealt on contact — copied from whoever fired it.
var damage: int = 3

## The shooter's team. A projectile never damages its own side, which is the
## same rule fighters' melee hitboxes follow.
var team: String = "enemy"

# Seconds of life left. Counted down in _physics_process().
var _life: float = LIFETIME


## Aims and arms the projectile. Called immediately after instantiate(), i.e.
## before _ready(), so it only writes plain variables and touches no child node.
func setup(new_direction: Vector2, new_damage: int, shooter_team: String) -> void:
	direction = new_direction.normalized()
	damage = new_damage
	team = shooter_team


func _ready() -> void:
	# body_entered fires when a PhysicsBody2D — a fighter, the ground, a wall —
	# starts overlapping this area. Connecting in code keeps the wiring next to
	# the handler that uses it, instead of hidden in the scene file.
	body_entered.connect(_on_body_entered)

	# Point the artwork the way we fly. angle() turns a vector into radians.
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	# Moved by hand rather than by the physics engine: an Area2D has no velocity
	# of its own. `position +=` is enough because nothing is meant to stop it
	# except the overlap check below.
	position += direction * SPEED * delta

	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	# Duck typing on purpose: anything that can take_damage() and has a `team` is
	# a valid victim, and this script never has to know about the Fighter class.
	if body.has_method("take_damage") and body.get("team") != null:
		if str(body.get("team")) == team:
			# Flying through a friend (usually the shooter, on frame one) is not
			# a collision at all — carry on.
			return
		body.call("take_damage", damage, self)

	# Hit an enemy, or hit the ground/a platform/a wall: either way it is spent.
	queue_free()
