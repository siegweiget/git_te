# The Wilds Grow Restless

A small Godot 4 RPG built around the two-layer structure the Fire Emblem
GBA games are known for: you **explore** a top-down village-and-wilds
map, and when you walk into trouble you drop into a **side-view arena**
for the fight itself. Unlike those games, the fight is not a scripted
animation — it is a real-time duel you control directly, switching
between party members on the fly, with dashing, jumping and AI-driven
enemies of several different temperaments.

Talk to Elder Rowan in the village to begin. She wants the wilds culled
of the beasts roaming them; finish that and the village gains a second
fighter and a new trick for your hero's own moveset.

## Requirements

- [Godot Engine 4.3+](https://godotengine.org/download) (free, no account or
  install required -- it's a single executable).

No other dependencies. Everything in this repository is plain text (scenes,
scripts, SVGs) and is imported by Godot itself the first time you open the
project.

## Getting started

1. Open Godot.
2. Click **Import**, browse to this repository, and select `project.godot`.
3. Once the project is open, press **F5** (or the Play button in the top
   right) to run it.

The first run will take a few extra seconds while Godot imports the SVG
assets; this only happens once. The game boots straight into the
overworld and auto-continues your last save, or starts a fresh game if
there isn't one yet.

## Controls

### Overworld (the top-down map)

| Action      | Keys              | Touch (mobile)                |
|-------------|-------------------|--------------------------------|
| Move        | `WASD` / arrow keys | D-pad, bottom-left (4 buttons) |
| Interact / talk | `E`           | Interact button, bottom-right |

Walking into an NPC or the village well and pressing Interact starts a
conversation; walking into a roaming monster starts a battle.

### Battle (the side-view duel)

| Action           | Keys                      | Touch (mobile)         |
|------------------|---------------------------|--------------------------|
| Move             | `A`/`D` or `←`/`→`        | Left/Right buttons |
| Jump             | `Space` / `W` / `↑`       | Jump button |
| Attack           | `J` / `F`                 | Attack button |
| Dash             | `K` / `Shift`              | Dash button |
| Switch character | `Q`                       | Switch button |

Dash and Switch only appear once they matter: the Dash button is hidden
until the quest reward unlocks it, and the Switch button is hidden while
your party is a solo act. Both checks live in `scripts/battle_hud.gd`, so
the touch UI and the input map never disagree about what is currently
available.

## Quest walkthrough (spoiler-light)

The quest tracker in the top-left corner of the overworld always tells
you the current objective, so this is only the shape of it:

1. Find **Elder Rowan** in the village and talk to her (`E` / Interact).
2. She sends you out into the wilds, east of the fence, to cull a few of
   the beasts roaming there. Walking into one starts a duel; win it and
   the tracker's count goes up.
3. Once enough are culled, something larger has moved into the far
   clearing. Find it and finish the job.
4. Return to the Elder to report in. She rewards you with a new
   companion at your side and a new move for your own fighter.

Along the way, the village **well** is a save point: walk up to it and
press Interact to write your progress to disk on demand (in addition to
the automatic save that happens whenever the quest itself moves
forward).

## Project structure

```
.
├── project.godot                  # Engine/project settings: input map, autoloads, main scene
├── icon.svg                       # Project icon
├── export_presets.cfg              # Android/iOS export configuration (no secrets); see MOBILE.md
├── scenes/
│   ├── overworld.tscn               # Main scene: village + wilds map, main scene per project.godot
│   ├── overworld_player.tscn        # The hero on the map: CharacterBody2D, no gravity, talks via InteractArea
│   ├── overworld_enemy.tscn         # A roaming monster: wanders, then chases and starts a battle on contact
│   ├── npc.tscn                     # A talkable villager (Elder Rowan uses this)
│   ├── dialogue_box.tscn            # The bottom-of-screen conversation panel, shared by NPCs and the well
│   ├── overworld_hud.tscn           # Touch D-pad + Interact button + quest tracker label
│   ├── battle.tscn                  # The duel arena: ground, platforms, walls, camera, result banner
│   ├── battle_hud.tscn              # Touch move/jump/attack/dash/switch buttons for battles
│   ├── fighter.tscn                 # One universal fighter body -- hero, allies and every enemy all use this
│   └── projectile.tscn              # A thrown shot fired by ranged enemies
├── scripts/
│   ├── game_state.gd                # Autoload: party, quest state, unlocks, save/load (user://savegame.json)
│   ├── scene_manager.gd             # Autoload: fade + scene swap between overworld and battle
│   ├── character_stats.gd           # Resource: one party member's persistent stats (level, xp, gear, ...)
│   ├── overworld_player.gd          # Hero movement + interact-with-nearest-talkable on the map
│   ├── overworld_enemy.gd           # Wander/chase AI for a roaming monster, starts a battle on contact
│   ├── overworld.gd                 # Places the player, sets camera limits, removes defeated/inactive enemies
│   ├── overworld_hud.gd              # Refreshes the quest tracker label from GameState
│   ├── npc.gd                       # Elder Rowan's dialogue + advances the quest state machine
│   ├── well.gd                      # The village save point
│   ├── dialogue_box.gd              # Generic conversation panel: shows lines, advances, freezes the player
│   ├── fighter.gd                   # Universal fighter: movement, attack, dash, AI profiles, HP, knockback
│   ├── battle.gd                    # Runs one fight: spawns both sides, handles switching, win/lose
│   ├── battle_hud.gd                # Hides the Dash/Switch buttons until they are actually available
│   └── projectile.gd                # A ranged enemy's shot: flies straight, damages on contact
└── assets/
    ├── sprites/                     # Placeholder art: see assets/sprites/README.md for the full inventory
    ├── audio/                       # Sound effects / music (empty for now)
    └── fonts/                       # Fonts (empty for now)
```

## Mobile (Android/iOS)

The project also runs on phones: it has on-screen touch controls for both
the overworld and battle layers, scales to different screen sizes, and is
configured with Android and iOS export presets (no credentials included).
See [MOBILE.md](MOBILE.md) for a full walkthrough of testing touch
controls on desktop and exporting/building for Android or iOS.

## Tuning

A handful of `@export` variables and constants control the game's feel,
all editable without touching the surrounding logic:

- **`scripts/fighter.gd`** -- the universal battle character:
  - `speed` -- horizontal run speed in a duel, pixels per second (default
    `300`).
  - `jump_velocity` -- upward impulse on jump, pixels per second (default
    `-400`; negative because Y points down). Enemy loadouts in
    `battle.gd` override both per enemy kind.
- **`scripts/overworld_player.gd`**:
  - `speed` -- the hero's walking speed on the map, pixels per second
    (default `220`; deliberately slower than any duel speed feels, and
    faster than every roaming enemy's chase speed, so outrunning trouble
    on the map is always possible).
- **`scripts/game_state.gd`**:
  - `xp_needed(level)` -- the level-up curve, currently `20 + level * 10`
    XP per level.
  - `KILLS_FOR_BOSS` -- how many regular beasts the hunt stage of the
    quest asks for before the brute appears (default `3`).
- **`scripts/battle.gd`**:
  - `ENEMY_STATS` -- one dictionary entry per enemy kind (`walker`,
    `jumper`, `ranged`, `brute`) with its HP, attack, speed, jump height,
    AI profile and sprite -- the whole difficulty curve in one readable
    table.
  - `ENEMY_LOADOUTS` -- which enemies actually show up for each kind of
    overworld encounter (e.g. bumping into a `ranged` enemy brings a
    `walker` along too).

Because these are `@export`ed or top-level constants, most of them can be
tuned straight from the Inspector or the script without touching any
other file.

## Design & roadmap

See [DESIGN.md](DESIGN.md) for the design concept behind the two-layer
structure and the phase 2 backlog -- gear, class evolution, more zones,
a title screen, and the rest of what this slice deliberately leaves out.

## About `helloworld.txt`

`helloworld.txt` is an empty leftover file from when this repository was
first created. It isn't used by the project -- it's left in place rather
than deleted here, so remove it yourself if you'd like it gone.
