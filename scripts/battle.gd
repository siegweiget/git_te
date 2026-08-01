extends Node2D

## Runs one fight, start to finish.
##
## The arena itself — ground, platforms, walls, camera, HUD — is built in
## battle.tscn. Everything that changes from fight to fight is decided here:
## who turns up, which side they are on, who the player is steering, and what
## happens when one side runs out of fighters.
##
## The scene is deliberately runnable on its own. Press F5 with no overworld in
## sight and you get the hero against a single walker, which is exactly what you
## want while tuning the combat.

# preload() reads the file at compile time, so spawning is just instantiate().
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter.tscn")

## Who shows up for each kind of overworld enemy the player can bump into.
##
## The enemy the player touched decides the *shape* of the fight, not just its
## own stats: walking into a lone jumper gets you two of them, and the ranged
## one brings a friend to keep you busy while it shoots.
const ENEMY_LOADOUTS: Dictionary = {
	"walker": ["walker"],
	"jumper": ["jumper", "jumper"],
	"ranged": ["ranged", "walker"],
	"brute": ["brute"],
}

## Stats for each enemy kind. Kept as one table so the whole difficulty curve is
## readable at a glance instead of scattered across four scene files.
##
## `profile` is the AI fighter.gd will run; note that the brute is a "walker"
## with the numbers turned up, because a slow, heavy version of a familiar
## pattern reads as a boss without needing new code.
##
## One constraint on `jump`: the arena's platforms sit 60px above the ground and
## are too low to walk under, so they are barriers as much as scenery. Every
## enemy needs enough jump to clear one — 980px/s² gravity turns -400 into 82px
## of height — or it will spend the whole fight leaning on a ledge it cannot
## climb, with no way for the player to end the battle. "Slow" is the brute's
## character; unable to move is a softlock.
const ENEMY_STATS: Dictionary = {
	"walker": {
		"name": "Walker",
		"hp": 20,
		"attack": 4,
		"speed": 130.0,
		"jump": -400.0,
		"profile": "walker",
		"sprite": "res://assets/sprites/enemy_walker.svg",
	},
	"jumper": {
		"name": "Jumper",
		"hp": 12,
		"attack": 3,
		"speed": 190.0,
		"jump": -470.0,
		"profile": "jumper",
		"sprite": "res://assets/sprites/enemy_jumper.svg",
	},
	"ranged": {
		"name": "Slinger",
		"hp": 14,
		"attack": 4,
		"speed": 120.0,
		"jump": -400.0,
		"profile": "ranged",
		"sprite": "res://assets/sprites/enemy_ranged.svg",
	},
	"brute": {
		"name": "Brute",
		"hp": 60,
		"attack": 8,
		"speed": 80.0,
		"jump": -420.0,
		"profile": "walker",
		"sprite": "res://assets/sprites/enemy_brute.svg",
	},
}

## Which enemy kind to use when nobody told us (running battle.tscn directly).
const DEFAULT_ENEMY_TYPE := "walker"

## Every extra jumper in a loadout is this much frailer than the one before it.
## A pack should be threatening because it surrounds you, not because it has
## twice the health bar.
const JUMPER_PACK_HP_SCALE := 0.75

## Where the two sides line up. The party starts on the left and walks right;
## `SPAWN_Y` is a little above the ground so everyone drops in.
const PARTY_START_X := 200.0
const PARTY_SPACING := 70.0
const ENEMY_START_X := 920.0
const ENEMY_SPACING := 90.0
const SPAWN_Y := 540.0

## How long the VICTORY!/DEFEATED... banner is left on screen before the scene
## changes. Long enough to register, short enough not to be a wait.
const RESULT_DELAY := 0.8

# Everyone still standing, split by side. Fighters take themselves out of these
# lists when they die, so "is one side wiped out?" is just is_empty().
var _player_team: Array[Fighter] = []
var _enemy_team: Array[Fighter] = []

# Set once the outcome is decided, so a death that happens during the result
# delay cannot end the battle a second time.
var _resolved: bool = false

@onready var fighters_root: Node2D = $Fighters
@onready var result_label: Label = $ResultLayer/ResultLabel


func _ready() -> void:
	# SceneManager remembers which enemy the player walked into. Falling back to
	# a default rather than trusting it means this scene still works when it is
	# launched on its own, with nothing having set the field.
	var enemy_type: String = SceneManager.pending_enemy_type
	if enemy_type.is_empty() or not ENEMY_LOADOUTS.has(enemy_type):
		enemy_type = DEFAULT_ENEMY_TYPE

	_spawn_party()
	_spawn_enemies(enemy_type)


# ---------------------------------------------------------------------------
# Spawning
# ---------------------------------------------------------------------------

# Puts one fighter on the field for every member of the party.
#
# Index 0 is always the hero, so she is the one the player starts out steering;
# everybody else fights for themselves on the "walker" profile until the player
# switches to them.
func _spawn_party() -> void:
	# GameState.party is typed Array[CharacterStats]. Reading it into an equally
	# typed local (rather than an untyped one) keeps the element type intact all
	# the way through the loop below.
	var members: Array[CharacterStats] = GameState.party

	if members.is_empty():
		# Should never happen — GameState always creates a hero — but a battle
		# with nobody in it would deadlock, so give the player *someone*.
		push_warning("Battle: the party is empty, spawning a default hero")
		members = [CharacterStats.new()]

	for i in members.size():
		var stats: CharacterStats = members[i]
		var fighter: Fighter = FIGHTER_SCENE.instantiate()

		# Added to the tree first: setup() writes to child nodes, and those only
		# exist once the fighter is actually in the scene.
		fighters_root.add_child(fighter)
		fighter.global_position = Vector2(PARTY_START_X - float(i) * PARTY_SPACING, SPAWN_Y)
		fighter.setup(stats, "player", "player" if i == 0 else "walker", i == 0)

		fighter.died.connect(_on_fighter_died)
		_player_team.append(fighter)


# Reads the loadout for `enemy_type` and lines those enemies up on the right.
func _spawn_enemies(enemy_type: String) -> void:
	var loadout: Array = ENEMY_LOADOUTS[enemy_type]

	for i in loadout.size():
		var kind: String = str(loadout[i])
		var data: Dictionary = ENEMY_STATS[kind]

		var enemy_hp: int = int(data["hp"])
		if kind == "jumper" and i > 0:
			# pow() compounds the reduction, so a third jumper would be frailer
			# again without anybody having to write a third number down.
			enemy_hp = maxi(1, int(round(float(enemy_hp) * pow(JUMPER_PACK_HP_SCALE, float(i)))))

		var fighter: Fighter = FIGHTER_SCENE.instantiate()
		fighters_root.add_child(fighter)
		fighter.global_position = Vector2(ENEMY_START_X + float(i) * ENEMY_SPACING, SPAWN_Y)
		fighter.setup_raw(
			str(data["name"]),
			enemy_hp,
			int(data["attack"]),
			str(data["sprite"]),
			"enemy",
			str(data["profile"])
		)

		# Speed and jump height are @export vars on the fighter, so they are set
		# directly rather than squeezed through setup_raw()'s argument list.
		fighter.speed = float(data["speed"])
		fighter.jump_velocity = float(data["jump"])

		fighter.died.connect(_on_fighter_died)
		_enemy_team.append(fighter)


# ---------------------------------------------------------------------------
# Swapping who the player is steering
# ---------------------------------------------------------------------------

# _unhandled_input() sees events nothing else has claimed. The switch button on
# the HUD pushes the very same action, so touch and keyboard land here together.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_character"):
		_switch_character()


# Hands control to the next living party member, wrapping round at the end.
func _switch_character() -> void:
	var alive: Array[Fighter] = _living(_player_team)

	# Nobody to switch to: with a one-person party the button would just flash
	# the hero at you, which reads as a bug rather than as "not available".
	if alive.size() <= 1:
		return

	# Where in the queue the current character sits. -1 (nobody is controlled,
	# e.g. the previous one just died) turns into index 0 below, which is what
	# you want anyway.
	var current: int = -1
	for i in alive.size():
		if alive[i].is_player_controlled:
			current = i
			break

	var next: int = (current + 1) % alive.size()
	_give_control_to(alive[next])


# Makes `chosen` the one and only player-controlled fighter.
func _give_control_to(chosen: Fighter) -> void:
	for fighter in _living(_player_team):
		if fighter == chosen:
			continue
		fighter.is_player_controlled = false
		# Whoever is put down starts fighting on their own. The "player" profile
		# means "a human is driving", so an abandoned hero would otherwise stand
		# there and be hit.
		if fighter.ai_profile == "player":
			fighter.ai_profile = "walker"
		# Drop any direction they were still being told to walk in.
		fighter.move_dir = 0.0

	chosen.is_player_controlled = true

	# A quick flash of white so it is obvious who you just picked up. modulate on
	# the body tints the whole fighter; the damage flash tints only the sprite,
	# so the two effects multiply together instead of fighting over one property.
	chosen.modulate = Color(1.8, 1.8, 1.8, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(chosen, "modulate", Color.WHITE, 0.35)


# Filters a side down to the fighters who are still standing.
func _living(side: Array[Fighter]) -> Array[Fighter]:
	var result: Array[Fighter] = []
	for fighter in side:
		if is_instance_valid(fighter) and fighter.is_alive():
			result.append(fighter)
	return result


# ---------------------------------------------------------------------------
# Winning and losing
# ---------------------------------------------------------------------------

# Every fighter's died signal lands here, whichever side it was on.
func _on_fighter_died(fighter: Fighter) -> void:
	var was_controlled: bool = fighter.is_player_controlled

	# erase() only removes it if it is there, so both calls are safe to make.
	_player_team.erase(fighter)
	_enemy_team.erase(fighter)

	if _resolved:
		return

	if _enemy_team.is_empty():
		_finish(true)
		return

	if _player_team.is_empty():
		_finish(false)
		return

	# The character the player was holding just fell: pass the controller to a
	# survivor rather than leaving the player watching.
	if was_controlled:
		var survivors: Array[Fighter] = _living(_player_team)
		if not survivors.is_empty():
			_give_control_to(survivors[0])


# Shows the result, waits a beat, then hands back to SceneManager.
#
# The delay is not just decoration: ending on the exact frame of the last blow
# feels like a crash. Eight tenths of a second is enough to see what happened.
func _finish(won: bool) -> void:
	_resolved = true

	result_label.text = "VICTORY!" if won else "DEFEATED..."
	result_label.visible = true

	# create_timer() makes a one-shot timer that cleans itself up; awaiting its
	# timeout signal pauses this function without blocking the rest of the game.
	await get_tree().create_timer(RESULT_DELAY).timeout

	# SceneManager owns the fade, the experience payout and the trip back to the
	# overworld. All this scene has to report is who won.
	SceneManager.end_battle(won)
