# assets/sprites/

Textures used by the game's scenes.

Currently this folder holds `player_placeholder.svg`, a simple blue
placeholder sprite referenced by the `Sprite2D` node's `Texture` property in
`scenes/player.tscn`, plus three touch-button icons -- `arrow_left.svg`,
`arrow_right.svg`, and `button_jump.svg`. Those three are used as the
`texture_normal` of the `TouchScreenButton` nodes in `scenes/hud.tscn` (the
on-screen mobile move-left/move-right/jump controls). They're swappable the
same way as the player sprite -- drop in a replacement file and re-point the
`texture_normal` property in the Inspector.

## Swapping in real art

1. Drop the new image (PNG or SVG) into this folder. Godot will import it
   automatically the next time the editor gains focus (or the next time you
   run `godot --headless --import`).
2. Open `scenes/player.tscn` and select the `Sprite2D` node.
3. In the Inspector, drag the new file from the FileSystem dock onto the
   `Texture` property (under **Sprite2D > Texture**), replacing
   `player_placeholder.svg`.

A good, free source of ready-made sprites at roughly the right scale for this
project is Kenney's
[Pixel Platformer](https://kenney.nl/assets/pixel-platformer) pack.

## Note on texture filtering

`project.godot` sets the default canvas texture filter to **Nearest**
(`textures/canvas_textures/default_texture_filter = 0`), which keeps pixel
art crisp instead of blurring it with smoothing/mipmaps. If you bring in
pixel-art assets, this setting is already correct for them; if you later add
smooth/hi-res art you may want to change it (Project Settings > Rendering >
Textures > Canvas Textures > Default Texture Filter) or override the filter
per-texture in its import settings.
