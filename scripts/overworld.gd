extends Node2D

## Sets the overworld map up each time it is loaded.
##
## The map itself — grass, houses, rocks, fences, walls — is built in
## overworld.tscn and never changes. What this script does is apply everything
## GameState remembers *about* that map: where the player should appear, which
## monsters are already dead, and whether the boss has turned up yet.
##
## That split matters because the overworld is loaded again after every single
## battle. The scene comes back exactly as it was authored, so all the "what has
## happened so far" has to be re-applied here, from the save file, every time.

## The size of the world in pixels: four screens, laid out two by two. The
## village fills the western half and the wilds the eastern half.
const MAP_SIZE := Vector2(2304.0, 1296.0)

## Where the hero appears when there is nothing to say otherwise — a new game,
## or waking up back home after losing a fight. This is the village plaza, a
## little south of the elder so she is standing in front of him rather than on
## top of him.
const VILLAGE_SPAWN := Vector2(560.0, 780.0)

## The uid of the boss monster, which is only on the map during one stage of the
## quest. Kept as a constant so the name is written down once.
const BRUTE_UID := "wilds_brute"

@onready var player: OverworldPlayer = $OverworldPlayer
@onready var enemies_root: Node2D = $Enemies


func _ready() -> void:
	_place_player()
	_setup_camera()
	_apply_enemy_state()


# ---------------------------------------------------------------------------
# The player
# ---------------------------------------------------------------------------

# Drops the hero wherever she is supposed to be standing.
#
# GameState.overworld_spawn uses Vector2.ZERO as a sentinel meaning "the map
# knows best" — it is never a real place we want to teleport somebody to, since
# that is the very top-left corner of the world, inside the border wall.
func _place_player() -> void:
	if GameState.overworld_spawn != Vector2.ZERO:
		player.global_position = GameState.overworld_spawn
	else:
		player.global_position = VILLAGE_SPAWN


# Stops the camera from showing the empty grey void outside the map.
#
# The limits are set from code rather than typed into the scene so that the map
# size is written down in exactly one place: change MAP_SIZE and the camera
# follows. Godot clamps the *edges* of the view to these, so the camera simply
# stops scrolling once the player gets near a border instead of jumping.
func _setup_camera() -> void:
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		push_warning("Overworld: the player has no Camera2D to set limits on")
		return

	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(MAP_SIZE.x)
	camera.limit_bottom = int(MAP_SIZE.y)


# ---------------------------------------------------------------------------
# The monsters
# ---------------------------------------------------------------------------

# Removes the monsters that should not be here.
#
# Two separate reasons a monster gets taken off the map:
#
#   1. It has already been beaten. GameState.defeated_enemies holds the uids, and
#      that list survives both the trip through a battle and quitting the game.
#   2. It is the boss and the quest has not reached the stage where he appears.
#
# Note both use queue_free() rather than hiding: a hidden body still blocks the
# hero and still starts a battle when she walks into it.
func _apply_enemy_state() -> void:
	for child in enemies_root.get_children():
		var enemy: OverworldEnemy = child as OverworldEnemy
		if enemy == null:
			continue

		if GameState.defeated_enemies.has(enemy.enemy_uid):
			enemy.queue_free()
			continue

		# The brute is only out in the wilds during the "boss" stage. Before
		# that the quest has not sent the player after him; afterwards he is in
		# defeated_enemies anyway and was already removed just above.
		if enemy.enemy_uid == BRUTE_UID and GameState.quest_state != "boss":
			enemy.queue_free()
