# Design & roadmap

## Concept

*The Wilds Grow Restless* borrows its overall shape from the Fire Emblem
GBA games: the world is split into two layers that never mix on screen at
the same time.

- An **overworld** layer (`scenes/overworld.tscn`) you explore top-down --
  walk around a village and the wilds beyond it, talk to NPCs, notice
  monsters roaming, and generally see the world as a map rather than as a
  fight.
- A **battle** layer (`scenes/battle.tscn`) that a collision with a
  roaming monster drops you into -- a side-view arena with gravity,
  platforms and jumping.

Where this project departs from its inspiration is *what happens* once
you're in that second layer. In Fire Emblem, initiating combat plays a
short, mostly-scripted animation and then resolves with a dice roll you
don't control. Here, combat is a real-time duel: you keep moving, jumping,
attacking and dashing for as long as the fight lasts, against enemies
that are actively thinking about what to do next (see `fighter.gd`'s
`_think()` and its `walker`/`jumper`/`ranged` profiles). The FE-style
world map is kept because it's a great way to pace an adventure and give
exploration its own texture; the scripted fight is thrown out because it
isn't as fun to actually play as fighting is.

The trick that makes both layers cheap to build and maintain is a single
`Fighter` script (`scripts/fighter.gd`) shared by the hero, her allies,
and every enemy. A human drives one fighter through `Input`; everyone
else is driven by the same four intent variables (`move_dir`,
`wants_jump`, `wants_attack`, `wants_dash`) filled in by a few lines of
AI instead. One movement/attack/knockback/death pipeline, no separate
"player controller" and "enemy controller" to keep in sync.

## What's in this slice

- A two-screen village and a larger wilds area to its east, joined by a
  gap in a fence (`scenes/overworld.tscn`).
- Elder Rowan, a talkable NPC who runs the main quest's dialogue and
  drives its state machine forward (`scripts/npc.gd` +
  `GameState.advance_quest()`).
- Four roaming regular enemies (walker/walker/jumper/ranged) and one boss
  (a scaled-up "brute") in the wilds, each wandering near its spawn until
  the hero gets close, then giving chase (`scripts/overworld_enemy.gd`).
- The quest: talk to the Elder, cull three beasts, find and slay the
  brute in the far clearing, report back -- rewarded with a second party
  member (Mira, an archer) and the Dash ability.
- A universal `Fighter` body used for every combatant, with four AI
  profiles (`player` for the human, `walker`, `jumper`, `ranged`) plus a
  scripted quest-boss loadout (a slow, heavy `walker`).
- A quest tracker HUD label, a save-point well in the village
  (`scripts/well.gd`), and full JSON persistence
  (`GameState.save_game()`/`load_game()`, `user://savegame.json`).
- Touch controls with keyboard/gamepad-style parity for both layers, and
  Android/iOS export presets.

## Phase 2 backlog

Roughly ordered by how directly the current code already points at it.

### Gear / equipment
`CharacterStats.gear` is a `Dictionary` (`{"weapon": "", "armor": ""}`)
that is faithfully saved and loaded (`to_dict()`/`from_dict()`) but never
read by anything. To make it real: an item registry (id → stat bonuses),
an equip UI (probably a new overworld menu, since there's no inventory
screen at all yet), and a read in `Fighter.setup()` that folds the
equipped items' bonuses into `max_hp`/`attack_power` before the fight
starts.

### Class evolution / switching
`CharacterStats.class_id` exists (default `"squire"`, Mira arrives as
`"archer"`) but nothing branches on it yet -- every fighter behaves
identically regardless of class. Next step is a class registry (stat
growth per class, maybe a distinct ability or two), an evolution trigger
at a level threshold, and perhaps a village NPC who lets the player
choose a path for the hero.

### More enemy types / arenas
`battle.gd`'s `ENEMY_STATS` and `ENEMY_LOADOUTS` dictionaries are exactly
the seam to extend: a new enemy kind is a new entry in both (stats table
+ which overworld encounter uses it), and `SceneManager.pending_enemy_type`
already carries an arbitrary string from the overworld encounter through
to the battle scene, so no plumbing changes are needed to add one. Arena
variety (a different `battle.tscn`-shaped scene per zone) would need
`SceneManager` to pick an arena scene as well as an enemy loadout, since
today there is exactly one arena for every fight.

### More zones / quests
The quest state machine in `GameState.advance_quest()` is a hand-written
`match` over one quest's four stages (`not_started` → `hunt` → `boss` →
`turn_in` → `complete`). Supporting more than one quest at a time means
generalizing that into a `quests: Dictionary` keyed by quest id, each
with its own state. On the overworld side, `SceneManager` only knows how
to fade to the one hardcoded `OVERWORLD_SCENE` and `BATTLE_SCENE` today; a
`go_to_map(scene_path)` alongside `start_battle()`/`end_battle()` would
let a second zone exist as its own scene file.

### Companion abilities in the overworld
Right now Mira (and any future recruit) only matters in battle. An
overworld-side ability -- a companion who can push a boulder, swim,
or open a locked door -- would need a way for `OverworldPlayer` to ask
"is a companion with an ability X currently following me", which does not
exist yet (there is no overworld companion-following at all; the party
outside of battle is implicit in `GameState.party`, not represented as
extra nodes on the map).

### Second companion
Mechanically this is the smallest item on this list: one more entry
appended in a `_recruit_companion()`-shaped function, wired to whatever
new quest or event should trigger it. The `battle.gd` switch-character
loop already handles an arbitrary party size correctly (see
`_switch_character()`'s wraparound over `_living(_player_team)`), so nothing
about the switching logic needs to change to support a third fighter on
the field.

### Virtual joystick option
The touch D-pad and battle move buttons are discrete `TouchScreenButton`
presses (`passby_press = true` lets a thumb slide between them), not an
analog stick. A drag-based virtual joystick would be an alternative
`Control` added to `overworld_hud.tscn`/`battle_hud.tscn` that writes to
the same `move_left`/`move_right`/`move_up`/`move_down` actions, so it
could coexist with or replace the button D-pad without touching
`overworld_player.gd` or `fighter.gd` at all -- both already read movement
through the input action layer, not the buttons directly.

### Real pixel-art packs
All current art is placeholder SVGs (see
`assets/sprites/README.md` for the full inventory and swap
instructions). Kenney's Tiny Town / Tiny Dungeon packs suit the top-down
layer; Pixel Platformer suits the battle layer.

### Audio
`assets/audio/` exists and is empty, ready for music and sound effects.
Nothing in the codebase plays a sound yet -- there is no `AudioStreamPlayer`
anywhere in any scene -- so this is a clean slate rather than a
partially-wired feature.

### Title screen + save slots
The game currently auto-continues: `GameState._ready()` tries
`load_game()` and falls back to `start_new_game()` with no menu in
between, and there is exactly one save slot (`SAVE_PATH =
"user://savegame.json"`, a single fixed path). A title screen would sit in
front of that autoload's decision (probably as its own scene set as
`run/main_scene`, with the overworld becoming something it navigates to);
multiple save slots would mean parameterizing `SAVE_PATH` per slot and
adding a slot-picker UI.

## Known footgun (recorded from WP4)

`monitorable = false` on an `Area2D` looks like it only controls whether
*other* areas can detect this one -- but in Godot 4.3 it also silently
breaks that Area2D's pairing with `StaticBody2D` nodes. A moving body
(`CharacterBody2D`) still pairs fine, so the symptom is not "detection is
broken", it is "detection works on monsters and silently does nothing on
every NPC" (or vice versa, depending on which side of the interaction sits
still). Both `OverworldPlayer`'s `InteractArea`
(`scenes/overworld_player.tscn`) and `OverworldEnemy`'s `DetectionArea`
(`scenes/overworld_enemy.tscn`) have already been tripped by this once;
`InteractArea` keeps `monitorable` **on** specifically because NPCs and
the well are `StaticBody2D`. Any future `Area2D` that needs to notice a
`StaticBody2D` -- a new interactable, a trigger zone, a trap -- should
check this setting first rather than rediscover the bug.
