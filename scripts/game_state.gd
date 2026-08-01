extends Node

## Autoload singleton that owns every piece of state that has to survive a
## scene change or a restart of the game.
##
## Because it is registered as an autoload (Project Settings > Autoload), Godot
## creates exactly one of these when the game boots and keeps it alive for the
## whole session, outside of any scene. Any script can reach it by name:
##
##     GameState.add_xp(10)
##
## Rule of thumb for what belongs here: if losing it when the player walks
## through a door would be a bug, it goes in GameState.

## Where the save file is written. `user://` is a per-game writable folder that
## Godot maps to a real directory on each platform (on Linux that is under
## ~/.local/share/godot/app_userdata/<project name>/), so it works the same on
## desktop and mobile without hard-coding any path.
const SAVE_PATH := "user://savegame.json"

## Bumped whenever the payload layout changes. load_game() refuses saves that
## do not match, which is friendlier than loading garbage.
const SAVE_VERSION := 1

## How many regular enemies the hunt asks for before the boss appears.
const KILLS_FOR_BOSS := 3

## Emitted whenever the quest moves forward, so UI can react without polling.
## The listener gets the state the quest just entered.
signal quest_changed(new_state: String)

## Emitted when the party's makeup or numbers change (a level-up, a new member).
signal party_changed

## The player's characters. Index 0 is always the hero.
var party: Array[CharacterStats] = []

## Where the main quest currently sits. One of:
## "not_started", "hunt", "boss", "turn_in", "complete".
var quest_state: String = "not_started"

## Regular enemies felled during the "hunt" stage.
var quest_kills: int = 0

## Abilities the player has earned. Checked through has_ability().
var unlocks: Dictionary = {"dash": false}

## Unique ids of overworld enemies already beaten, so they stay gone when the
## map is reloaded after a battle.
var defeated_enemies: Array = []

## Where to drop the player when the overworld loads next.
## Vector2.ZERO is a sentinel meaning "use whatever spawn point the map itself
## defines" — it is never a real position we want to teleport to.
var overworld_spawn: Vector2 = Vector2.ZERO


# _ready() runs once, as soon as this node is in the scene tree. Continue the
# player's save if there is one; otherwise begin a fresh story.
func _ready() -> void:
	if not load_game():
		start_new_game()


## Wipes everything back to the start of the game and creates a fresh hero.
func start_new_game() -> void:
	party = [CharacterStats.new()]
	quest_state = "not_started"
	quest_kills = 0
	unlocks = {"dash": false}
	defeated_enemies = []
	overworld_spawn = Vector2.ZERO
	party_changed.emit()


## Experience required to get from `level` to the next one.
##
## Kept as a formula rather than a table so the curve is easy to tweak: each
## level costs 10 more than the one before it.
func xp_needed(level: int) -> int:
	return 20 + level * 10


## Grants experience to the whole party (nobody gets left behind for sitting
## out a fight) and applies any level-ups that follow.
##
## Only stats change here. Restoring HP after a level-up is the battle scene's
## job, because current HP is battle-side state.
func add_xp(amount: int) -> void:
	var leveled_up: bool = false

	for member: CharacterStats in party:
		member.xp += amount
		# A `while` rather than an `if`: a big reward can push a character
		# through several levels at once.
		while member.xp >= xp_needed(member.level):
			member.xp -= xp_needed(member.level)
			member.level += 1
			member.max_hp += 10
			member.attack_power += 2
			leveled_up = true

	if leveled_up:
		party_changed.emit()


## The main quest's state machine.
##
## Everything that can move the story forward funnels through here and reports
## *what happened* ("talked_to_elder"), not what should happen next. This file
## alone decides the ordering, so no other script can put the quest into an
## impossible state. Events that do not fit the current stage are ignored in
## silence — that is normal, e.g. chatting to the elder again mid-hunt.
func advance_quest(event: String) -> void:
	var previous_state: String = quest_state
	var previous_kills: int = quest_kills

	match quest_state:
		"not_started":
			if event == "talked_to_elder":
				quest_state = "hunt"

		"hunt":
			if event == "enemy_defeated":
				quest_kills += 1
				if quest_kills >= KILLS_FOR_BOSS:
					quest_state = "boss"

		"boss":
			if event == "boss_defeated":
				quest_state = "turn_in"

		"turn_in":
			if event == "talked_to_elder":
				quest_state = "complete"
				_recruit_companion()
				unlocks["dash"] = true
				party_changed.emit()

	# Nothing matched? Then there is nothing to announce or write to disk.
	if quest_state == previous_state and quest_kills == previous_kills:
		return

	quest_changed.emit(quest_state)
	save_game()


## Adds Mira to the party as the reward for finishing the quest.
## She arrives at the hero's level so she is never dead weight.
func _recruit_companion() -> void:
	var mira := CharacterStats.new()
	mira.id = "mira"
	mira.display_name = "Mira"
	mira.class_id = "archer"
	mira.level = party[0].level if party.size() > 0 else 1
	mira.max_hp = 24
	mira.attack_power = 4
	mira.sprite_path = "res://assets/sprites/companion.svg"
	party.append(mira)


## Remembers that an overworld enemy was beaten and tells the quest about it.
##
## The uid is whatever unique name the overworld gave that enemy node; storing
## it means the enemy can be skipped when the map respawns.
func record_enemy_defeated(uid: String, is_boss: bool) -> void:
	if not defeated_enemies.has(uid):
		defeated_enemies.append(uid)

	# Note that regular kills only count during the "hunt" stage. There is no
	# extra check needed here — advance_quest() already ignores the event in
	# every other state.
	advance_quest("boss_defeated" if is_boss else "enemy_defeated")

	save_game()


## True if the player has earned the named ability (e.g. "dash").
## Using get() with a `false` fallback means asking about an unknown ability is
## safe and simply answers "no".
func has_ability(ability: String) -> bool:
	return unlocks.get(ability, false)


## Writes the whole game state to disk as JSON.
##
## Vector2 is not something JSON understands, so overworld_spawn is stored as a
## plain [x, y] pair and rebuilt on load.
func save_game() -> void:
	var party_data: Array = []
	for member: CharacterStats in party:
		party_data.append(member.to_dict())

	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"party": party_data,
		"quest_state": quest_state,
		"quest_kills": quest_kills,
		"unlocks": unlocks,
		"defeated_enemies": defeated_enemies,
		"overworld_spawn": [overworld_spawn.x, overworld_spawn.y],
	}

	# FileAccess.open() returns null if the file cannot be created (a full or
	# read-only disk), so it is checked rather than assumed.
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("GameState: could not write save file at %s" % SAVE_PATH)
		return

	# "\t" indents the JSON so a human can read (and debug) the save file.
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


## Reads the save file back in.
##
## Returns true only when a complete, matching save was restored. Returns false
## for "no save yet", damaged text, or a save from an incompatible version — in
## every one of those cases the caller should just start a new game.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("GameState: save file exists but could not be opened")
		return false

	var text: String = file.get_as_text()
	file.close()

	# JSON.parse_string() returns null when the text is not valid JSON, so a
	# corrupted file is caught here instead of exploding later.
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameState: save file is corrupt, ignoring it")
		return false

	var data: Dictionary = parsed
	if int(data.get("version", -1)) != SAVE_VERSION:
		push_warning("GameState: save file version mismatch, ignoring it")
		return false

	# Rebuild the party as real CharacterStats objects; JSON only gave us
	# dictionaries.
	party = []
	for entry in data.get("party", []):
		if typeof(entry) == TYPE_DICTIONARY:
			party.append(CharacterStats.from_dict(entry))

	quest_state = str(data.get("quest_state", "not_started"))
	quest_kills = int(data.get("quest_kills", 0))

	unlocks = {"dash": false}
	var loaded_unlocks: Dictionary = data.get("unlocks", {})
	for key in loaded_unlocks:
		unlocks[str(key)] = loaded_unlocks[key]

	defeated_enemies = data.get("defeated_enemies", [])

	var spawn: Array = data.get("overworld_spawn", [0, 0])
	if spawn.size() >= 2:
		overworld_spawn = Vector2(float(spawn[0]), float(spawn[1]))
	else:
		overworld_spawn = Vector2.ZERO

	# A save with no party at all would leave the game unplayable, so treat it
	# the same as having no save.
	if party.is_empty():
		push_warning("GameState: save file had an empty party, ignoring it")
		return false

	party_changed.emit()
	quest_changed.emit(quest_state)
	return true
