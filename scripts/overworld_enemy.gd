class_name OverworldEnemy
extends CharacterBody2D

## A monster wandering the wilds. Touching one starts a battle.
##
## This is the overworld half of an enemy; the fighting half lives in battle.gd
## and fighter.gd. The two are joined by two strings: `enemy_uid`, which says
## *which* monster this is so a beaten one stays beaten, and `enemy_type`, which
## says what kind of fight it turns into.
##
## The brain is two states and nothing more. Left alone it strolls between random
## points near where it started; once the hero is close enough to notice it walks
## straight at her. That is enough to make the map feel alive without any
## pathfinding.

## Which artwork goes with which kind of monster. The same files the battle
## fighters use, so an enemy looks the same on the map as it does in the arena.
const SPRITES: Dictionary = {
	"walker": "res://assets/sprites/enemy_walker.svg",
	"jumper": "res://assets/sprites/enemy_jumper.svg",
	"ranged": "res://assets/sprites/enemy_ranged.svg",
	"brute": "res://assets/sprites/enemy_brute.svg",
}

## Strolling speed and chasing speed, in pixels per second. The chase has to be
## the faster of the two, but it is deliberately slower than the hero's 220 so
## running away is always an option.
const WANDER_SPEED := 60.0
const CHASE_SPEED := 110.0

## How long the monster waits before picking a new spot to stroll to. A random
## time between the two, so four monsters on screen do not move in lockstep.
const WANDER_PAUSE_MIN := 2.0
const WANDER_PAUSE_MAX := 4.0

## How close to its chosen spot counts as "arrived". Without a tolerance like
## this the monster would jitter forever trying to land on an exact pixel.
const ARRIVE_DISTANCE := 8.0

## Unique name for this particular monster, e.g. "wilds_1".
##
## GameState keeps a list of the uids that have been beaten, and overworld.gd
## removes those from the map on the way in — which is why every instance in
## overworld.tscn must have a uid of its own.
@export var enemy_uid: String = ""

## What kind of fight this becomes: "walker", "jumper", "ranged" or "brute".
@export var enemy_type: String = "walker"

## How far from its starting point the monster is willing to stroll.
@export var wander_radius: float = 120.0

## True for the boss. SceneManager works the boss out from the enemy type, but
## the flag makes the intent readable in the Inspector and gives overworld.gd
## something to find the brute by.
@export var is_boss: bool = false

# Where this monster was standing when the map loaded. Wandering is always
# measured from here, so nothing can slowly drift across the whole map.
var _home: Vector2 = Vector2.ZERO

# The spot currently being strolled towards, and the countdown until a new one
# is picked.
var _wander_target: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0

# The hero, while she is inside DetectionArea; null the rest of the time.
var _chase_target: Node2D = null

# Set the instant a battle is asked for. The scene change happens behind a fade,
# which takes a few tenths of a second, and without this flag the monster would
# spend that time still touching the player and asking for the same battle again
# on every single physics frame.
var _battle_started: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var detection_area: Area2D = $DetectionArea


func _ready() -> void:
	add_to_group("overworld_enemies")

	_home = global_position
	_apply_sprite()

	# Signals rather than a per-frame overlap test: the area tells us when the
	# hero arrives and when she leaves, and we just remember which it was.
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)

	# Start out standing still for a moment, at a different moment per monster.
	_wander_target = _home
	_wander_timer = randf_range(WANDER_PAUSE_MIN, WANDER_PAUSE_MAX)


# Swaps in the artwork that goes with enemy_type. load() (rather than preload())
# because the type is only known once the scene is running.
func _apply_sprite() -> void:
	var path: String = str(SPRITES.get(enemy_type, SPRITES["walker"]))
	if not ResourceLoader.exists(path):
		return

	var texture: Resource = load(path)
	if texture is Texture2D:
		sprite.texture = texture


func _physics_process(delta: float) -> void:
	# A battle is already on its way: stop dead and stay that way until the scene
	# changes out from under us.
	if _battle_started:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Nobody moves while somebody is talking. Being ambushed mid-sentence, with
	# no way to react because the controls are frozen, would be plain unfair.
	if _dialogue_is_open():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _chase_target != null and is_instance_valid(_chase_target):
		_chase(delta)
	else:
		_wander(delta)

	# Face the way we are heading. As with the player, moving straight up or down
	# leaves the artwork alone rather than snapping it to a side.
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0

	move_and_slide()

	_check_for_player_contact()


# Strolls between random points around home, with a pause at each one.
func _wander(delta: float) -> void:
	_wander_timer -= delta

	var to_target: Vector2 = _wander_target - global_position

	if to_target.length() <= ARRIVE_DISTANCE:
		# Arrived. Stand about until the timer runs out, then choose again.
		velocity = Vector2.ZERO
		if _wander_timer <= 0.0:
			_pick_wander_target()
		return

	velocity = to_target.normalized() * WANDER_SPEED

	# Also re-choose if the timer expires on the way, which quietly rescues a
	# monster that has walked into a rock and cannot reach where it was going.
	if _wander_timer <= 0.0:
		_pick_wander_target()


# Picks a fresh spot inside the wander circle and resets the pause timer.
func _pick_wander_target() -> void:
	# A random angle plus a random distance gives a point anywhere in the circle.
	var angle: float = randf_range(0.0, TAU)
	var distance: float = randf_range(0.0, wander_radius)
	_wander_target = _home + Vector2(cos(angle), sin(angle)) * distance
	_wander_timer = randf_range(WANDER_PAUSE_MIN, WANDER_PAUSE_MAX)


# Walks straight at the hero. No cleverness needed: the wilds are open ground
# and the monster is slower than she is, so a straight line is fair game.
func _chase(_delta: float) -> void:
	var to_player: Vector2 = _chase_target.global_position - global_position
	velocity = to_player.normalized() * CHASE_SPEED


# ---------------------------------------------------------------------------
# Noticing the player
# ---------------------------------------------------------------------------

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("overworld_player"):
		_chase_target = body


func _on_detection_body_exited(body: Node2D) -> void:
	if body == _chase_target:
		# Out of sight, out of mind: the monster goes back to strolling from
		# wherever it has ended up, not from where it first saw her.
		_chase_target = null
		_home = global_position
		_pick_wander_target()


# ---------------------------------------------------------------------------
# Starting a battle
# ---------------------------------------------------------------------------

# move_and_slide() records everything it bumped into on the way. Walking into the
# hero is what starts a fight, so the list is read straight afterwards.
func _check_for_player_contact() -> void:
	for i in get_slide_collision_count():
		var collision: KinematicCollision2D = get_slide_collision(i)
		var collider: Object = collision.get_collider()

		var body: Node = collider as Node
		if body == null or not body.is_in_group("overworld_player"):
			continue

		_start_battle(body as Node2D)
		return


func _start_battle(player: Node2D) -> void:
	# Guarded because the scene change is behind a fade: this function can
	# otherwise be reached again several times before the overworld goes away.
	if _battle_started:
		return
	_battle_started = true

	velocity = Vector2.ZERO

	# The player's position is handed over so SceneManager can put her back
	# exactly where she was standing once the fight is over.
	SceneManager.start_battle(enemy_uid, enemy_type, player.global_position)


# True while a conversation is on screen. The box is found by group, and a
# missing box simply means "nobody is talking".
func _dialogue_is_open() -> bool:
	var box: DialogueBox = get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	return box != null and box.is_open
