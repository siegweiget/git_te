# assets/audio/

Sound effects and music for the game. Empty for now -- nothing in the
project plays audio yet.

## File formats

- **Music**: `.ogg` (Ogg Vorbis) -- good compression for longer tracks.
- **Short sound effects**: `.wav` -- uncompressed, so there's no
  decode/latency cost when it needs to play instantly (jumps, hits, coin
  pickups, etc.).

Godot imports both automatically as soon as they're placed in the project.

## Playing a sound

1. Add an `AudioStreamPlayer` node (or `AudioStreamPlayer2D`/`3D` if you want
   positional audio) to the relevant scene.
2. Set its **Stream** property to the imported audio file.
3. Call `$AudioStreamPlayer.play()` from a script, or check **Autoplay** in
   the Inspector if it should play immediately.

## Free audio

Kenney also publishes free [audio packs](https://kenney.nl/assets?q=audio)
(sound effects and music) that pair well with their sprite packs.
