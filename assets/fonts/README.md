# assets/fonts/

Custom fonts for UI text (menus, HUD, dialogue, etc.). Empty for now -- the
project currently uses Godot's built-in default font.

## Adding a font

1. Drop a `.ttf` or `.otf` file into this folder. Godot imports it
   automatically as a `FontFile` resource.
2. Select a `Label` (or other text-drawing control) node.
3. In the Inspector, open **Theme Overrides > Fonts > Font**, and set it to
   the imported font file.

That's enough to use the font on a single control; for a whole UI, put the
font on a shared `Theme` resource instead so every control picks it up
consistently.
