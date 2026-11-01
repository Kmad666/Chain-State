# The Brick Spire: Blender model

The Brick Spire level's tower, exported straight from the game's geometry, so it matches the level exactly.

| File | What it is |
|---|---|
| `brick_spire.blend` | Blender 5.1 file with the textures packed in. |
| `brick_spire.glb` | The same model as glTF. Import it in Blender (File → Import → glTF 2.0), Godot or most other 3D tools. |
| `brick_spire_preview.png` | A Cycles render of the `.blend`. |

## The model

- **Size:** 67 × 51 m footprint, 246 m tall, at real game scale (1 unit = 1 m).
- **Pivot:** the tower's foot. In the level that's 30 m under the sea; the `.blend` has a "Waterline" marker at Z = 30.
- **Mesh:** about 8,000 polygons in four meshes, one per material, all parented to the `BrickSpire` empty.
- **Materials:**
  - `Stone`, `Stone_Dark` and `Stone_Light`: pale beige stone, each with the game's speckled stone texture. The UVs are box-projected at 4 m per tile.
  - `Openings`: flat dark brown.
- **Welding:** the faces are welded and converted to quads where possible, so it edits cleanly. It's still a blockout built from boxes, cylinders and pyramids, so expect overlapping pieces rather than one sealed shell.

## Re-exporting

If the tower changes in `scripts/world/brick_tower.gd`, re-export it with the two scripts in `tools/`:

1. Export the `.glb` (this needs a display, because the game's batched meshes can't be read back headless):

   ```
   OUT=brick_spire.glb xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/export_brick_spire.gd
   ```

2. Build the `.blend` next to it, with Blender's Python (Blender 5.1 or the `bpy` module):

   ```
   python tools/make_brick_spire_blend.py --render
   ```

Run the second script from the folder that holds the `.glb`.
