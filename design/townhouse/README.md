# The Copper Kettle: a townhouse from a design sheet

A five-storey limestone townhouse with a tea room on the ground floor. It was built in three.js from the design sheet in `reference/design-sheet.png` over four compare-and-fix passes, then exported as a .glb and brought into the game as the **Copper Kettle** level.

Open `index.html` (Pages: https://kmad666.github.io/Chain-State/design/townhouse/) to view it. **Front**, **Right**, **Rear**, **Left** and **Roof plan** are orthographic, so they line up with the sheet's elevations. The live copy is the [Copper Kettle artifact](https://claude.ai/artifact/FJiYtMxc2JE9aoLC7fQmZJ).

**From the sheet:**
- 14 m × 10 m footprint, about 21 m to the ridge.
- Storey heights 4.0 / 3.4 / 3.2 / 3.0 / 3.0 m, with a 2.6 m attic.
- Four window axes on the front and rear, two on each side.
- Coursed limestone with quoins, hooded windows and flower boxes.
- A green painted shopfront with round-headed windows and an awning.
- A pedimented side door and the teapot sign on its iron bracket.
- A slate mansard with stone dormers, a hipped top and four brick stacks with three pots each.
- Ivy climbing the corner.

## Files

| File | What it is |
|---|---|
| `index.html` | The built page, self-contained (three.js bundled in). |
| `src/` | The generator. `40_townhouse.js` is the house; the rest is shared with the Berlin study. |
| `build.py` | `python3 build.py site` builds `index.html`. It needs `npm install three@0.160.0 esbuild@0.24.0` in this folder. |
| `reference/design-sheet.png` | The design sheet it was built from. |

**In the game:** `assets/models/townhouse/copper_kettle.glb`, loaded by `_build_copper_kettle()` in `scripts/world/world.gd`. Every mesh except the ivy, glass and curtains gets trimesh collision on the world layer.
