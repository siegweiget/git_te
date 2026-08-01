# assets/sprites/

Textures used by the game's scenes. Everything here is a placeholder SVG,
swappable for real art without touching any script (every sprite is either
an `@export`ed Inspector field or, for enemies, looked up by path from a
small table in code).

## Current inventory

**Characters and monsters** -- used by `scenes/fighter.tscn` (every
combatant in a duel: hero, allies, and enemies alike, via
`Fighter.setup()`/`setup_raw()`), by `scenes/overworld_player.tscn` and
`scenes/npc.tscn` on the map, and by `scenes/overworld_enemy.tscn` (which
looks up the matching sprite for its `enemy_type` from the `SPRITES`
dictionary in `scripts/overworld_enemy.gd`, so the monster looks the same
wandering the wilds as it does once battle starts):

| File                     | Used for |
|--------------------------|----------|
| `player_placeholder.svg` | The hero -- default `sprite_path` on a fresh `CharacterStats`, and the texture on `overworld_player.tscn`'s `Sprite2D` |
| `companion.svg`          | Mira, the archer companion recruited at the end of the quest (`GameState._recruit_companion()`) |
| `npc.svg`                | Villagers you can talk to, e.g. Elder Rowan (`scenes/npc.tscn`) |
| `enemy_walker.svg`       | The "walker" enemy kind (melee, chases straight in) |
| `enemy_jumper.svg`       | The "jumper" enemy kind (hops over obstacles and onto platforms) |
| `enemy_ranged.svg`       | The "ranged" enemy kind (keeps its distance, throws projectiles) |
| `enemy_brute.svg`        | The boss -- a bigger, slower, harder-hitting "walker" |

**Touch-button icons** -- `texture_normal` on `TouchScreenButton` nodes.
The overworld and battle layers each have their own HUD scene and use a
different subset:

| File                   | Used by (`TouchScreenButton` node) |
|------------------------|-------------------------------------|
| `arrow_up.svg`         | `overworld_hud.tscn` → `UpButton` |
| `arrow_left.svg`       | `overworld_hud.tscn` → `LeftButton`; `battle_hud.tscn` → `LeftButton` |
| `arrow_right.svg`      | `overworld_hud.tscn` → `RightButton`; `battle_hud.tscn` → `RightButton` |
| `arrow_down.svg`       | `overworld_hud.tscn` → `DownButton` |
| `button_interact.svg`  | `overworld_hud.tscn` → `InteractButton` |
| `button_jump.svg`      | `battle_hud.tscn` → `JumpButton` |
| `button_attack.svg`    | `battle_hud.tscn` → `AttackButton` |
| `button_switch.svg`    | `battle_hud.tscn` → `SwitchButton` (hidden until the party has more than one member -- see `scripts/battle_hud.gd`) |
| `button_dash.svg`      | `battle_hud.tscn` → `DashButton` (hidden until Dash is unlocked -- see `scripts/battle_hud.gd`) |

## Swapping in real art

1. Drop the new image (PNG or SVG) into this folder. Godot will import it
   automatically the next time the editor gains focus (or the next time you
   run `godot --headless --import`).
2. Open the scene that uses the sprite (see the tables above) and select
   the relevant node -- a `Sprite2D` for a character/monster, or the
   `TouchScreenButton` itself for a HUD icon.
3. In the Inspector, drag the new file from the FileSystem dock onto the
   `Texture` (for a `Sprite2D`) or `Texture Normal` (for a
   `TouchScreenButton`) property, replacing the placeholder.

For enemies specifically, the path is also written into
`scripts/battle.gd`'s `ENEMY_STATS` table (one `"sprite"` entry per enemy
kind) and `scripts/overworld_enemy.gd`'s `SPRITES` table -- update both if
you rename a file rather than just replacing its contents in place.

Two free, appropriately-licensed sources of ready-made sprites, matched to
this project's two different layers:

- Kenney's [Tiny Town](https://kenney.nl/assets/tiny-town) or
  [Tiny Dungeon](https://kenney.nl/assets/tiny-dungeon) packs suit the
  top-down overworld layer (the village, the wilds, NPCs, roaming
  monsters).
- Kenney's [Pixel Platformer](https://kenney.nl/assets/pixel-platformer)
  pack suits the side-view battle layer (the hero, allies, and enemies as
  they appear once a duel starts).

All of Kenney's packs linked above are public domain (CC0).

## Note on texture filtering

`project.godot` sets the default canvas texture filter to **Nearest**
(`textures/canvas_textures/default_texture_filter = 0`), which keeps pixel
art crisp instead of blurring it with smoothing/mipmaps. If you bring in
pixel-art assets, this setting is already correct for them; if you later add
smooth/hi-res art you may want to change it (Project Settings > Rendering >
Textures > Canvas Textures > Default Texture Filter) or override the filter
per-texture in its import settings.
