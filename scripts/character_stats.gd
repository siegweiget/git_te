class_name CharacterStats
extends Resource

## Plain data container for one party member (the hero, a companion, ...).
##
## This extends Resource rather than Node because it holds *data*, not
## behaviour: nothing here draws, moves or ticks. Resources can be created in
## code with `CharacterStats.new()`, passed around freely, and — thanks to
## to_dict()/from_dict() below — turned into something the save file can store.
##
## `class_name` at the top registers the type engine-wide, so any other script
## can write `CharacterStats.new()` without preloading this file first.

# @export marks a value as editable in the Inspector and, more importantly for
# a Resource, as something the engine knows about. Defaults written here are
# what a brand-new character starts with.

## Stable internal id, used by code (not shown to the player).
@export var id: String = "hero"

## Name shown in menus and battle UI.
@export var display_name: String = "Hero"

## Which class/archetype this character is. Not used yet: it is a hook for a
## later phase where classes change abilities and growth.
@export var class_id: String = "squire"

## Current level. Levels are gained in GameState.add_xp().
@export var level: int = 1

## Experience banked toward the *next* level (it is reset each level-up, not a
## running lifetime total).
@export var xp: int = 0

## Maximum hit points. Current HP lives in the battle scene, not here, because
## it only matters while a fight is happening.
@export var max_hp: int = 30

## How hard this character hits.
@export var attack_power: int = 5

## Ids of special moves this character knows. Typed as Array[String] so Godot
## rejects anything that is not text.
@export var abilities: Array[String] = []

## Equipped items, keyed by slot. Another later-phase hook: it is saved and
## loaded faithfully, but nothing reads it yet.
@export var gear: Dictionary = {"weapon": "", "armor": ""}

## Where this character's artwork lives.
@export var sprite_path: String = "res://assets/sprites/player_placeholder.svg"


## Copies every field into a plain Dictionary.
##
## Save files store simple types only (numbers, strings, arrays, dictionaries),
## so an object has to be flattened like this before JSON can handle it.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"class_id": class_id,
		"level": level,
		"xp": xp,
		"max_hp": max_hp,
		"attack_power": attack_power,
		"abilities": abilities,
		"gear": gear,
		"sprite_path": sprite_path,
	}


## Rebuilds a CharacterStats from a Dictionary produced by to_dict().
##
## `static` means you call it on the type itself — CharacterStats.from_dict(d) —
## instead of on an existing instance.
##
## Every read uses Dictionary.get(key, fallback), which returns the fallback
## when the key is missing. That way an old or hand-edited save that is missing
## fields still loads, filling the gaps with sensible defaults instead of
## crashing.
static func from_dict(d: Dictionary) -> CharacterStats:
	var stats := CharacterStats.new()
	stats.id = str(d.get("id", "hero"))
	stats.display_name = str(d.get("display_name", "Hero"))
	stats.class_id = str(d.get("class_id", "squire"))
	stats.level = int(d.get("level", 1))
	stats.xp = int(d.get("xp", 0))
	stats.max_hp = int(d.get("max_hp", 30))
	stats.attack_power = int(d.get("attack_power", 5))
	stats.sprite_path = str(d.get("sprite_path", "res://assets/sprites/player_placeholder.svg"))

	# `abilities` is typed Array[String], and JSON hands back an untyped Array,
	# so the values are copied across one at a time (and forced to String).
	stats.abilities = []
	for ability in d.get("abilities", []):
		stats.abilities.append(str(ability))

	# Same idea for gear: start from the default slots so a save written before
	# a slot existed still ends up with that slot present.
	var loaded_gear: Dictionary = d.get("gear", {})
	stats.gear = {"weapon": "", "armor": ""}
	for slot in loaded_gear:
		stats.gear[str(slot)] = loaded_gear[slot]

	return stats
