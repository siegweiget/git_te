# Platformer

A minimal Godot 4 2D platformer skeleton: one scene with a ground, three
floating platforms, and a controllable character. It's meant as a small,
readable starting point for learning Godot, not a finished game.

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
assets; this only happens once.

## Controls

| Action     | Keys           | Touch (mobile) |
|------------|----------------|-----------------|
| Move left  | `A` / `←`      | ◀ button, bottom-left |
| Move right | `D` / `→`      | ▶ button, bottom-left |
| Jump       | `Space` / `W` / `↑` | Jump button, bottom-right |

## Project structure

```
.
├── project.godot              # Engine/project settings: input map, main scene, window size
├── icon.svg                   # Project icon
├── export_presets.cfg          # Android/iOS export configuration (no secrets); see MOBILE.md
├── scenes/
│   ├── main.tscn               # The game world: ground, 3 platforms, an instanced Player + Camera2D + HUD
│   ├── hud.tscn                 # Touch-control overlay: on-screen left/right/jump buttons
│   └── player.tscn             # The player: CharacterBody2D + Sprite2D + CollisionShape2D
├── scripts/
│   └── player.gd                # Player movement/physics, attached to scenes/player.tscn
└── assets/
    ├── sprites/                 # Textures (placeholder player sprite + touch-button icons)
    ├── audio/                   # Sound effects / music (empty for now)
    └── fonts/                   # Fonts (empty for now)
```

## Mobile (Android/iOS)

The project also runs on phones: it has on-screen touch controls, scales to
different screen sizes, and is configured with Android and iOS export
presets (no credentials included). See [MOBILE.md](MOBILE.md) for a full
walkthrough of testing touch controls on desktop and exporting/building for
Android or iOS.

## Tuning

The player's feel is controlled by two `@export` variables on the `Player`
node's script (`scripts/player.gd`):

- `speed` -- horizontal run speed, in pixels per second (default `300`).
- `jump_velocity` -- upward impulse applied on jump, in pixels per second
  (default `-400`; negative because Y points down).

Because they're `@export`ed, you don't need to edit the script to tune them --
select the `Player` node in `scenes/player.tscn` (or the `Player` instance in
`scenes/main.tscn`) and change the values directly in the Inspector.

## Where to go next

Some small next steps if you want to keep building on this skeleton:

- Add collectible coins (an `Area2D` the player overlaps, plus a score
  counter).
- Add a simple enemy (patrol between two points, or chase the player).
- Add a kill-plane/respawn: walking off the left edge of the ground
  currently falls forever, since there's nothing below the screen to catch
  the player. A large `Area2D` below the level that resets the player's
  position (or restarts the scene) fixes this.
- Add more platforms, or rearrange the existing ones into a bigger level.
- Swap the placeholder SVGs for real art -- Kenney's free
  [Pixel Platformer](https://kenney.nl/assets/pixel-platformer) asset pack is
  a good match for this project's scale and license terms (public domain).

## About `helloworld.txt`

`helloworld.txt` is an empty leftover file from when this repository was
first created. It isn't used by the project -- it's left in place rather
than deleted here, so remove it yourself if you'd like it gone.
