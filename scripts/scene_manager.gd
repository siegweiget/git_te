extends Node

## Autoload singleton that handles moving between the overworld and battles,
## with a black fade in between so the switch does not feel like a glitch.
##
## Scene changes are centralised here for two reasons: the fade only has to be
## written once, and the little bit of information a battle needs ("which enemy
## did I touch?") has somewhere to live while the old scene is being torn down.

## Overworld scene the player returns to after a fight.
const OVERWORLD_SCENE := "res://scenes/overworld.tscn"

## Battle scene entered when the player bumps into an enemy.
const BATTLE_SCENE := "res://scenes/battle.tscn"

## Sentinel handed to GameState.overworld_spawn to mean "put the player at the
## map's own default spawn point" — used after a loss, when returning to where
## the player fell would be unkind.
const VILLAGE_SPAWN := Vector2.ZERO

## How long a fade to or from black takes, in seconds.
const FADE_TIME := 0.3

## Which enemy the battle about to start is against. Set by start_battle() and
## read by the battle scene once it is running.
var pending_enemy_uid: String = ""

## What kind of enemy it is: "walker", "jumper", "ranged" or "brute".
## "brute" is the boss, and is worth more experience.
var pending_enemy_type: String = ""

# The black rectangle used for fading. Built in code in _ready() so this
# singleton needs no scene file of its own.
var _fade_rect: ColorRect


func _ready() -> void:
	# A CanvasLayer draws independently of the game world: it ignores the
	# camera, so the rectangle covers the screen no matter where the player is.
	# A high layer number keeps it in front of everything else, HUD included.
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	# PRESET_FULL_RECT anchors all four sides to the screen edges, so the
	# rectangle resizes with the window instead of being a fixed size.
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# MOUSE_FILTER_IGNORE lets clicks and touches pass straight through, so an
	# invisible overlay can never swallow the player's input.
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Start fully transparent. Only the alpha channel is animated later.
	_fade_rect.modulate.a = 0.0
	layer.add_child(_fade_rect)


## Fades the black overlay toward `to_alpha` (0 = clear, 1 = black).
##
## Tweens animate a property over time on their own; `await` on the tween's
## finished signal lets the caller pause until the fade is actually done.
func _fade(to_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", to_alpha, FADE_TIME)
	await tween.finished


## Leaves the overworld and starts a fight.
##
## `return_pos` is where the player was standing, so they can be put back there
## when the battle is over.
func start_battle(enemy_uid: String, enemy_type: String, return_pos: Vector2) -> void:
	pending_enemy_uid = enemy_uid
	pending_enemy_type = enemy_type
	GameState.overworld_spawn = return_pos

	# The battle scene arrives in a later work package. Checking for it first
	# means calling this too early logs a warning instead of leaving the player
	# staring at a black screen.
	if not ResourceLoader.exists(BATTLE_SCENE):
		push_warning("SceneManager: %s does not exist yet" % BATTLE_SCENE)
		return

	await _fade(1.0)
	get_tree().change_scene_to_file(BATTLE_SCENE)
	await _fade(0.0)


## Ends a fight and returns to the overworld.
##
## On a win the enemy is struck off the map for good and the party is paid in
## experience. On a loss nothing is lost except the trip: the player simply
## wakes up back in the village.
func end_battle(won: bool) -> void:
	if won:
		var is_boss: bool = pending_enemy_type == "brute"
		GameState.record_enemy_defeated(pending_enemy_uid, is_boss)
		GameState.add_xp(25 if is_boss else 10)
		GameState.save_game()
	else:
		GameState.overworld_spawn = VILLAGE_SPAWN

	# The fight is settled either way, so forget who it was against.
	pending_enemy_uid = ""
	pending_enemy_type = ""

	# Same safety net as above: the overworld scene lands in a later package.
	if not ResourceLoader.exists(OVERWORLD_SCENE):
		push_warning("SceneManager: %s does not exist yet" % OVERWORLD_SCENE)
		return

	await _fade(1.0)
	get_tree().change_scene_to_file(OVERWORLD_SCENE)
	await _fade(0.0)
