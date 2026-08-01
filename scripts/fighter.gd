class_name Fighter
extends CharacterBody2D

## One script for everybody who stands in the arena: the hero, the allies who
## follow her, and every enemy she fights.
##
## This grew out of the old single-purpose player controller. The movement code
## at the bottom is still exactly the same idea — accumulate gravity, jump, set
## velocity.x, call move_and_slide() — but instead of reading the keyboard
## directly it reads four *intent* variables:
##
##     move_dir, wants_jump, wants_attack, wants_dash
##
## Every frame something fills those in. For the character the player is holding
## the controller for that "something" is Input; for everybody else it is
## _think(), a few lines of AI. Because both paths end in the same physics core,
## an enemy that walks off a ledge falls exactly like the hero does, and there is
## only one movement bug to fix instead of two.
##
## The node this is attached to is a CharacterBody2D: a body you move yourself
## (by writing to `velocity` and calling `move_and_slide()`) while the physics
## engine handles collision response for you.

## Emitted the moment this fighter's HP reaches zero, just before it removes
## itself from the scene. The battle scene listens so it can tell when one side
## has been wiped out. The dying fighter passes itself along so the listener
## does not have to guess who it was.
signal died(fighter: Fighter)


# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

# @export makes a variable editable in the Inspector, so you can tune the feel
# of the character without touching the code. Values set in the Inspector
# override the defaults written here. Everything below @export is set from code
# by setup(), because it comes from the save file or from a table of enemies.

## Horizontal run speed, in pixels per second.
@export var speed: float = 300.0

## Upward impulse applied when jumping. Negative because in Godot's 2D
## coordinate system the Y axis points DOWN, so "up" is a negative value.
@export var jump_velocity: float = -400.0

## How long the attack hitbox stays switched on, in seconds. Short: this is the
## window in which a swing can connect, not the length of the animation.
const ATTACK_ACTIVE_TIME := 0.15

## Minimum seconds between the start of one swing and the start of the next.
const ATTACK_COOLDOWN := 0.5

## How far in front of the body the hitbox sits, in pixels. Flipped along with
## the artwork so you always hit the way you are facing.
const ATTACK_OFFSET := 28.0

## Seconds of invulnerability granted by taking a hit. Without this a fighter
## standing inside an enemy would be damaged on every single physics frame.
const IFRAME_TIME := 0.6

## How hard a hit shoves you away from whoever landed it.
const KNOCKBACK_X := 220.0
const KNOCKBACK_Y := -160.0

## Seconds during which knockback is allowed to carry the body before normal
## movement takes the wheel again.
const KNOCKBACK_TIME := 0.18

## How quickly leftover knockback speed bleeds off, in pixels per second².
const KNOCKBACK_DECAY := 900.0

## Dash: a short burst at this multiple of `speed`, then a long wait.
const DASH_SPEED_MULT := 2.5
const DASH_TIME := 0.2
const DASH_COOLDOWN := 1.0

## How close an AI fighter wants to be before it swings.
const AI_ATTACK_RANGE := 50.0

## How far above or below an AI will accept a target as "in reach".
##
## This has to stay comfortably *smaller* than what the hitbox can really touch
## (roughly half the hitbox's height plus half the target's, so around 44px).
## Allow more than the hitbox can reach and an AI perched on a platform directly
## over its target will stand there swinging at thin air for the rest of the
## fight, convinced it is winning.
const AI_ATTACK_HEIGHT := 32.0

## Breather an AI takes between swings, so enemies do not feel like a drill.
const AI_ATTACK_PAUSE := 0.55

## How long a ground AI has to be making no headway before it decides it is
## stuck. Reacting the instant is_on_wall() goes true is far too eager: clipping
## the corner of a platform for a single frame counts as a wall, and the result
## is an enemy that pogos on the spot instead of fighting.
const AI_STUCK_TIME := 0.35

## How far an AI must travel within AI_STUCK_TIME to count as "getting
## somewhere". Even the slowest enemy covers several times this in that window,
## so anything less means something is in the way.
const AI_PROGRESS_EPSILON := 8.0

## How far away a "jumper" has to be before it bothers hopping.
##
## This has to be larger than the distance one hop actually covers (speed times
## time in the air — roughly 180px for the stock jumper). Trigger it any sooner
## and the thing sails clean over its target every time, lands behind it, turns
## round, and jumps back: a fight that never lands a blow.
const AI_JUMP_DISTANCE := 160.0

## How long an AI commits to backing out of a corner once it decides to. Long
## enough to actually clear the obstacle: re-deciding every frame would just
## walk it straight back into the thing it was trying to escape.
const AI_UNSTICK_TIME := 0.5

## Distance a "ranged" fighter tries to hold, and how much slop it tolerates
## before it bothers walking again. Without the slop it would jitter forever
## trying to stand on an exact pixel.
const AI_RANGED_DISTANCE := 250.0
const AI_RANGED_SLACK := 40.0

## Seconds between shots for a "ranged" fighter, and the furthest it will try.
const AI_SHOT_INTERVAL := 1.5
const AI_SHOT_MAX_RANGE := 520.0

## Width of the little HP bar drawn above every fighter's head, in pixels.
const HP_BAR_WIDTH := 34.0

# preload() reads the file at compile time and hands back a ready-made
# PackedScene, so firing a projectile later costs nothing but instantiate().
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectile.tscn")


# ---------------------------------------------------------------------------
# Identity and stats — filled in by setup()
# ---------------------------------------------------------------------------

## Name shown in debug output and, later, in battle UI.
var display_name: String = "Fighter"

## Maximum and current hit points. `hp` is battle-only state: it is deliberately
## NOT written back into CharacterStats, so a bruising fight does not follow the
## party out of the arena.
var max_hp: int = 30
var hp: int = 30

## How much damage one connecting swing deals.
var attack_power: int = 5

## Which side this fighter is on: "player" or "enemy". Two fighters can only
## damage each other when these differ, which is the whole of friendly fire
## prevention.
var team: String = "player"

## How this fighter decides what to do: "player" (no AI at all — a human is
## driving), "walker", "jumper" or "ranged".
var ai_profile: String = "player"

## True for the single fighter the human is currently steering. The battle scene
## makes sure exactly one player-team fighter has this set.
var is_player_controlled: bool = false


# ---------------------------------------------------------------------------
# Intent — rewritten from scratch every physics frame
# ---------------------------------------------------------------------------

## -1.0 for left, +1.0 for right, 0.0 for "stand still".
var move_dir: float = 0.0

## True on the single frame a jump/attack/dash is being asked for. These are
## edge-triggered on purpose: holding the attack button should not turn into a
## machine gun.
var wants_jump: bool = false
var wants_attack: bool = false
var wants_dash: bool = false

## Which way the artwork is turned: +1 right, -1 left.
var facing: int = 1

# Where an AI wants to look regardless of which way it is walking. A ranged
# fighter backing away still needs to face its target to shoot it.
var _look_dir: float = 0.0

# Countdown timers, all in seconds. Anything above zero means "still happening".
var _attack_active: float = 0.0
var _attack_cooldown: float = 0.0
var _iframe_timer: float = 0.0
var _knockback_timer: float = 0.0
var _dash_timer: float = 0.0
var _dash_cooldown: float = 0.0
var _ai_pause: float = 0.0
var _shot_timer: float = 0.0
var _stuck_timer: float = 0.0
var _stuck_check_x: float = 0.0
var _unstick_timer: float = 0.0
var _unstick_dir: float = 0.0

# Bodies already damaged by the swing that is currently out, so one swing can
# never hit the same target twice.
var _already_hit: Array[Node] = []

# Flipped to false the instant HP hits zero. queue_free() does not take the node
# out of the tree until the end of the frame, so without this flag other
# fighters could keep targeting (and hitting) a corpse for a few milliseconds.
var _alive: bool = true

# Remembered until the node is in the tree, because setup() may be called before
# the sprite node exists.
var _sprite_path: String = ""

# @onready waits until the node is inside the scene tree before running, which
# is when child nodes are guaranteed to exist. "$Sprite2D" is shorthand for
# get_node("Sprite2D").
@onready var sprite: Sprite2D = $Sprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var hp_bar: Node2D = $HPBar
@onready var hp_bar_fill: ColorRect = $HPBar/Fill


func _ready() -> void:
	# Groups are Godot's answer to "give me every X in the scene" without any
	# node having to keep a list. _find_target() uses this to look for enemies.
	add_to_group("fighters")
	_apply_sprite()
	_update_hp_bar()


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

## Builds a party member out of the CharacterStats that GameState keeps.
##
## Call this AFTER the node has been added to the tree, so the @onready
## references above are live.
func setup(stats: CharacterStats, in_team: String = "player", profile: String = "player", controlled: bool = false) -> void:
	setup_raw(stats.display_name, stats.max_hp, stats.attack_power, stats.sprite_path, in_team, profile)
	is_player_controlled = controlled


## Builds a fighter from plain values instead of a CharacterStats resource.
##
## Enemies live in a table in battle.gd rather than in the save file, so they
## have no CharacterStats of their own and come in through this door.
func setup_raw(new_name: String, new_max_hp: int, new_attack: int, sprite_path: String, in_team: String = "enemy", profile: String = "walker") -> void:
	display_name = new_name
	max_hp = maxi(1, new_max_hp)
	hp = max_hp
	attack_power = new_attack
	team = in_team
	ai_profile = profile
	is_player_controlled = false
	_sprite_path = sprite_path

	# setup() is normally called just after add_child(), so the node IS ready and
	# these run right now. The guard only matters if somebody sets a fighter up
	# before parenting it.
	if is_node_ready():
		_apply_sprite()
		_update_hp_bar()


# Swaps in the artwork named by _sprite_path and resizes the body to match it,
# so a 48x64 brute really is bigger than a 32x40 walker.
func _apply_sprite() -> void:
	if _sprite_path.is_empty() or not ResourceLoader.exists(_sprite_path):
		return

	# load() (as opposed to preload()) reads the file at runtime, which is what we
	# need here: the path only becomes known when the save file is read.
	var texture: Resource = load(_sprite_path)
	if not (texture is Texture2D):
		return

	sprite.texture = texture
	var art_size: Vector2 = (texture as Texture2D).get_size()

	# Sub-resources written inside a .tscn are SHARED by every instance of that
	# scene, so editing one in place would resize every fighter at once.
	# duplicate() gives this fighter a private copy to resize.
	if body_shape.shape is RectangleShape2D:
		var own_shape: RectangleShape2D = (body_shape.shape as RectangleShape2D).duplicate()
		own_shape.size = art_size
		body_shape.shape = own_shape

	# Keep the HP bar floating just above the head whatever the head's height is.
	hp_bar.position.y = -(art_size.y * 0.5 + 10.0)


# ---------------------------------------------------------------------------
# Frame loop
# ---------------------------------------------------------------------------

# _physics_process runs at a fixed rate (60 times a second by default). Always
# do movement/physics here rather than in _process, so it behaves the same on
# every machine. `delta` is the time in seconds since the last physics frame.
func _physics_process(delta: float) -> void:
	if not _alive:
		return

	# Wipe last frame's intent. Everything below either re-asks for something or
	# leaves it switched off; nothing is allowed to linger by accident.
	move_dir = 0.0
	wants_jump = false
	wants_attack = false
	wants_dash = false
	_look_dir = 0.0

	_tick_timers(delta)

	if is_player_controlled:
		_read_input()
	else:
		_think(delta)

	_update_facing()
	_process_attack(delta)
	_process_dash(delta)
	_apply_movement(delta)


# Counts every timer down towards zero and runs the effects that are purely
# about time passing (the damage flash).
func _tick_timers(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_knockback_timer = maxf(0.0, _knockback_timer - delta)
	_ai_pause = maxf(0.0, _ai_pause - delta)

	if _iframe_timer > 0.0:
		_iframe_timer = maxf(0.0, _iframe_timer - delta)
		if _iframe_timer > 0.0:
			# fmod() gives the remainder of a division, so this counts 0->1->0->1
			# roughly twelve times a second: a blink, done without an animation.
			var lit: bool = fmod(_iframe_timer * 12.0, 1.0) < 0.5
			sprite.modulate = Color(1.0, 1.0, 1.0, 0.35) if lit else Color(1.0, 0.55, 0.55, 1.0)
		else:
			# Always finish on the normal look, never mid-blink.
			sprite.modulate = Color.WHITE


# ---------------------------------------------------------------------------
# Intent source 1: a human
# ---------------------------------------------------------------------------

func _read_input() -> void:
	# get_axis() returns -1.0 when only the first action is held, +1.0 when only
	# the second is, and 0.0 when neither or both are.
	move_dir = Input.get_axis("move_left", "move_right")

	# is_action_just_pressed() fires only on the frame the key goes down, so
	# holding the key does not re-trigger the action.
	wants_jump = Input.is_action_just_pressed("jump")
	wants_attack = Input.is_action_just_pressed("attack")

	# Dashing is a quest reward, not a starting move. Asking GameState every
	# frame keeps the check in one place — the button on the HUD hides itself
	# using the very same call.
	wants_dash = Input.is_action_just_pressed("dash") and GameState.has_ability("dash")


# ---------------------------------------------------------------------------
# Intent source 2: a very small brain
# ---------------------------------------------------------------------------

# Fills in the same four intent variables a human would, based on where the
# nearest opponent is. Each profile is only a handful of lines: the interesting
# behaviour comes from feeding them through the same physics as the player.
func _think(delta: float) -> void:
	var target: Fighter = _find_target()
	if target == null:
		return

	# Offsets to the target. dx > 0 means "to my right"; dy < 0 means "above me",
	# because Y grows downward.
	var dx: float = target.global_position.x - global_position.x
	var dy: float = target.global_position.y - global_position.y

	# Whatever the profile does with its feet, it looks at its target.
	_look_dir = signf(dx)

	match ai_profile:
		"walker":
			_think_walker(delta, dx, dy)
		"jumper":
			_think_jumper(delta, dx, dy)
		"ranged":
			_think_ranged(delta, target, dx, dy)
		_:
			# "player" with nobody driving, or an unknown profile: stand there.
			pass


# Marches straight at the target and swings when it is close enough, with a
# short breather between swings so it reads as a fighter rather than a blender.
func _think_walker(delta: float, dx: float, dy: float) -> void:
	# Close enough to swing? Both axes have to agree. The horizontal range is
	# generous on purpose: two fighters can never stand closer than half of one
	# body plus half of the other, and a 48px wide brute facing a 32px wide hero
	# already eats 40 of those pixels. Anything tighter and the big enemies jam
	# against their target forever, always one step short of a swing.
	if absf(dx) <= AI_ATTACK_RANGE and absf(dy) < AI_ATTACK_HEIGHT:
		if _ai_pause <= 0.0:
			wants_attack = true
			_ai_pause = AI_ATTACK_PAUSE
		# In reach means whatever we were escaping from no longer matters.
		_unstick_timer = 0.0
		_stuck_timer = 0.0
		return

	# Out of reach, so close the gap. Note this branch also runs when the target
	# is *horizontally* close but on another level — standing on the platform
	# over somebody's head is not the same as standing next to them.
	move_dir = signf(dx)
	if move_dir == 0.0:
		# Directly above or below: sign() of nothing is nothing, and standing
		# still would be a stalemate neither fighter could break. Keep walking
		# the way we already face.
		move_dir = float(facing)

	_unstick(delta, dy)


# Bounces towards the target: it jumps whenever it is on the ground and the
# target is either far away or standing above it, so it climbs the platforms.
func _think_jumper(delta: float, dx: float, dy: float) -> void:
	if absf(dx) <= AI_ATTACK_RANGE and absf(dy) < AI_ATTACK_HEIGHT:
		# Nose to nose: plant and swing.
		if _ai_pause <= 0.0:
			wants_attack = true
			_ai_pause = AI_ATTACK_PAUSE
		_unstick_timer = 0.0
		_stuck_timer = 0.0
		return

	move_dir = signf(dx)
	if move_dir == 0.0:
		# Same stalemate-breaker the walker uses when it ends up directly above
		# or below its target.
		move_dir = float(facing)

	# Hop whenever there is ground under us and the target is either a way off
	# or above us — the second half of that is what carries it up onto the
	# platforms after somebody who is trying to keep their distance.
	if is_on_floor() and (absf(dx) > AI_JUMP_DISTANCE or dy < -24.0):
		wants_jump = true

	_unstick(delta, dy)


# Keeps its distance and throws things. Backing away when crowded is what makes
# it feel different from a walker: it is the only profile that ever retreats.
func _think_ranged(delta: float, target: Fighter, dx: float, dy: float) -> void:
	var distance: float = absf(dx)

	if distance < AI_RANGED_DISTANCE - AI_RANGED_SLACK:
		move_dir = -signf(dx)
	elif distance > AI_RANGED_DISTANCE + AI_RANGED_SLACK:
		move_dir = signf(dx)

	_shot_timer = maxf(0.0, _shot_timer - delta)
	if _shot_timer <= 0.0 and distance <= AI_SHOT_MAX_RANGE:
		_fire_projectile(target)
		_shot_timer = AI_SHOT_INTERVAL

	# Standing still at its chosen distance is this profile's whole point, so
	# _unstick() leaves it alone: it only reacts when move_dir says we are trying
	# to walk somewhere and getting nowhere.
	_unstick(delta, dy)


# Shared escape hatch for the two ground profiles.
#
# Fighters walk into things: the side of a platform, the arena wall, the ledge
# they happen to be standing on. Left to themselves they will lean on the
# obstacle forever, and a fight in which nobody can reach anybody never ends —
# which, with no way to flee a battle, is a softlock. This spots that state and
# picks whichever way out actually helps.
func _unstick(delta: float, dy: float) -> void:
	# Already backing out of somewhere: see it through rather than re-deciding.
	if _unstick_timer > 0.0:
		_unstick_timer -= delta
		move_dir = _unstick_dir
		return

	# "Stuck" is simply: feet on something, trying to walk, and not actually
	# going anywhere. Measuring progress rather than checking is_on_wall()
	# catches every version of the problem at once — pressed into a wall, wedged
	# on a corner, dithering on the lip of a platform directly above the target,
	# or standing on another fighter's head.
	if is_on_floor() and move_dir != 0.0 and absf(global_position.x - _stuck_check_x) < AI_PROGRESS_EPSILON:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0
		_stuck_check_x = global_position.x

	if _stuck_timer < AI_STUCK_TIME:
		return

	_stuck_timer = 0.0

	if dy <= AI_ATTACK_HEIGHT:
		# The target is level with us or above us, so the thing in the way is
		# something to climb. Hop over it.
		wants_jump = true
	else:
		# The target is below us and we are jammed against the very ledge we are
		# stood on. Jumping would drop us right back here; walking away from the
		# obstacle takes us off the edge and down to their level instead.
		#
		# Which way is "away" comes from the wall itself. get_wall_normal()
		# points out of whatever we are leaning on, which is the one direction
		# guaranteed to be clear. Reversing our heading instead would be a coin
		# flip: when the target is directly overhead, dx is a hair either side of
		# zero, so the heading it produced is noise — and half the time reversing
		# it walks us straight back into the wall we are trying to leave.
		var escape: float = 0.0
		if is_on_wall():
			escape = signf(get_wall_normal().x)
		if escape == 0.0:
			escape = -move_dir
		if escape == 0.0:
			escape = -float(facing)

		_unstick_dir = escape
		_unstick_timer = AI_UNSTICK_TIME
		move_dir = _unstick_dir


# Finds the closest living fighter on the other side. distance_squared_to() is
# used rather than distance_to() because comparing squares gives the same answer
# and skips a square root per candidate.
func _find_target() -> Fighter:
	var best: Fighter = null
	var best_distance: float = INF

	for node in get_tree().get_nodes_in_group("fighters"):
		var other: Fighter = node as Fighter
		if other == null or other == self:
			continue
		if not other.is_alive() or other.team == team:
			continue

		var d: float = global_position.distance_squared_to(other.global_position)
		if d < best_distance:
			best_distance = d
			best = other

	return best


# Spawns a projectile aimed at `target`. It is added next to this fighter rather
# than under it, so it keeps flying straight instead of being dragged around by
# its shooter (and it survives the shooter's death).
func _fire_projectile(target: Fighter) -> void:
	var muzzle: Vector2 = global_position + Vector2(float(facing) * 20.0, -4.0)
	var direction: Vector2 = (target.global_position - muzzle).normalized()

	var shot: Projectile = PROJECTILE_SCENE.instantiate()
	shot.setup(direction, attack_power, team)
	get_parent().add_child(shot)
	shot.global_position = muzzle


# ---------------------------------------------------------------------------
# Facing
# ---------------------------------------------------------------------------

# The artwork is drawn facing right, so it only needs flipping when we face
# left. The attack hitbox is moved to the same side, which is why this has to
# run before the attack is resolved.
func _update_facing() -> void:
	if _look_dir != 0.0:
		facing = 1 if _look_dir > 0.0 else -1
	elif move_dir != 0.0:
		facing = 1 if move_dir > 0.0 else -1

	sprite.flip_h = facing < 0
	attack_area.position.x = float(facing) * ATTACK_OFFSET


# ---------------------------------------------------------------------------
# Attacking
# ---------------------------------------------------------------------------

func _process_attack(delta: float) -> void:
	# Start a swing? Only if nothing is on cooldown and no swing is already out.
	if wants_attack and _attack_cooldown <= 0.0 and _attack_active <= 0.0:
		_attack_active = ATTACK_ACTIVE_TIME
		_attack_cooldown = ATTACK_COOLDOWN
		_already_hit.clear()
		# set_deferred() waits until the physics step has finished before making
		# the change. Turning a collision shape on or off in the middle of one is
		# exactly the sort of thing that makes Godot complain about "flushing
		# queries", and this is the standard way to avoid it.
		attack_shape.set_deferred("disabled", false)

	if _attack_active > 0.0:
		_attack_active -= delta
		_damage_overlapping()
		if _attack_active <= 0.0:
			attack_shape.set_deferred("disabled", true)


# Damages everyone standing in the hitbox who is on the other team and has not
# already been hit by this particular swing.
func _damage_overlapping() -> void:
	for body in attack_area.get_overlapping_bodies():
		if _already_hit.has(body):
			continue

		# Anything that is not a Fighter — the ground, a platform, a wall —
		# casts to null here and is quietly skipped.
		var other: Fighter = body as Fighter
		if other == null or other == self:
			continue
		if not other.is_alive() or other.team == team:
			continue

		_already_hit.append(body)
		other.take_damage(attack_power, self)


# ---------------------------------------------------------------------------
# Dashing
# ---------------------------------------------------------------------------

func _process_dash(delta: float) -> void:
	if _dash_timer > 0.0:
		# Already dashing; the burst itself is applied in _apply_movement().
		_dash_timer = maxf(0.0, _dash_timer - delta)
		return

	if wants_dash and _dash_cooldown <= 0.0:
		_dash_timer = DASH_TIME
		_dash_cooldown = DASH_COOLDOWN
		# Dashing through an attack is the point of the move, so it grants
		# invulnerability for its duration — but maxf() means it can never cut an
		# existing, longer window short.
		_iframe_timer = maxf(_iframe_timer, DASH_TIME)


# ---------------------------------------------------------------------------
# Taking damage
# ---------------------------------------------------------------------------

## Applies `amount` damage from `attacker` (which may be null, e.g. a trap).
##
## Called by other fighters' hitboxes and by projectiles. Everything that can
## reduce HP goes through here, so invulnerability, the flash, the knockback and
## death only had to be written once.
func take_damage(amount: int, attacker: Node2D = null) -> void:
	if not is_alive():
		return

	# Still blinking from the last hit (or mid-dash): ignore this one.
	if _iframe_timer > 0.0:
		return

	hp -= amount
	_iframe_timer = IFRAME_TIME
	_knockback_timer = KNOCKBACK_TIME

	# Shoved directly away from whoever hit us, plus a small pop upwards so the
	# hit visibly interrupts what we were doing.
	var away: float = 1.0
	if attacker != null:
		away = signf(global_position.x - attacker.global_position.x)
		if away == 0.0:
			# Standing in exactly the same column: pick a side rather than
			# multiplying the knockback by zero and looking broken.
			away = -float(facing)
	velocity.x = away * KNOCKBACK_X
	velocity.y = KNOCKBACK_Y

	_update_hp_bar()

	if hp <= 0:
		hp = 0
		_die()


## True while this fighter is a valid opponent. is_queued_for_deletion() covers
## the gap between queue_free() being called and the node actually leaving the
## tree at the end of the frame.
func is_alive() -> bool:
	return _alive and not is_queued_for_deletion()


func _die() -> void:
	# Set the flag FIRST. Listeners of died() may look around the arena, and they
	# must not see this fighter as a live combatant any more.
	_alive = false
	set_physics_process(false)
	# Stop the corpse from soaking up hits or blocking the survivors.
	set_deferred("collision_layer", 0)
	attack_shape.set_deferred("disabled", true)

	died.emit(self)
	queue_free()


# ---------------------------------------------------------------------------
# HP bar
# ---------------------------------------------------------------------------

# Two ColorRects: a dark one that never changes, and a coloured one on top whose
# width is the fraction of HP left. Cheap, readable, and no UI theme required.
func _update_hp_bar() -> void:
	var fraction: float = 0.0
	if max_hp > 0:
		fraction = clampf(float(hp) / float(max_hp), 0.0, 1.0)

	# A Control's size is stored as offsets from its anchors; assigning `size`
	# moves the right/bottom edge only, so the bar drains towards the right.
	hp_bar_fill.size.x = HP_BAR_WIDTH * fraction

	# Green while healthy, amber when it starts to matter, red when it is dire.
	if fraction > 0.5:
		hp_bar_fill.color = Color(0.36, 0.79, 0.37)
	elif fraction > 0.25:
		hp_bar_fill.color = Color(0.91, 0.72, 0.24)
	else:
		hp_bar_fill.color = Color(0.85, 0.25, 0.22)


# ---------------------------------------------------------------------------
# The physics core — unchanged in spirit from the original player controller
# ---------------------------------------------------------------------------

func _apply_movement(delta: float) -> void:
	# Gravity. get_gravity() returns the gravity vector affecting this body
	# (from Project Settings > Physics > 2D > Default Gravity, 980 px/s² by
	# default). We only accumulate it while airborne so the body does not build
	# up downward speed while resting on the floor.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# "jump" is a custom action defined in Project Settings > Input Map
	# (Space / W / Up arrow). An AI asks for it through the same flag.
	if wants_jump and is_on_floor():
		velocity.y = jump_velocity

	if _dash_timer > 0.0:
		# Dashing overrides steering entirely: you commit to the direction you
		# were facing when you pressed the button.
		velocity.x = float(facing) * speed * DASH_SPEED_MULT
	elif _knockback_timer > 0.0:
		# Being hit takes the controls away for a moment. The push decays on its
		# own rather than being cancelled, so the shove has weight.
		velocity.x = move_toward(velocity.x, 0.0, KNOCKBACK_DECAY * delta)
	elif move_dir != 0.0:
		velocity.x = move_dir * speed
	else:
		# No input: ease back to a standstill instead of stopping dead.
		# Using `speed` as the step means we stop within roughly one frame,
		# which is snappy; lower it for a slidier, more slippery character.
		velocity.x = move_toward(velocity.x, 0.0, speed)

	# Applies `velocity`, slides along walls/slopes instead of sticking to them,
	# and updates is_on_floor() / is_on_wall() for the next frame.
	move_and_slide()
