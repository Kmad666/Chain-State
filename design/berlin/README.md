# Kettenkiez: a Berlin district study

A small Gründerzeit crossroads in the style of Prenzlauer Berg, built in three.js (r160) as a design study for Chain State's streets. Open `index.html` (or the Pages copy at https://kmad666.github.io/Chain-State/design/berlin/) to walk round it. The live original is the [Kettenkiez artifact](https://claude.ai/artifact/54TiUTeg4FCTDbUzAccfBp).

Everything is generated in code. There are no image files.

## What it models (and the references behind it)

- **Houses:** five-storey Mietshäuser under the 22 m eaves line of the 1887 building code.
  - The ground floor holds shops or a raised Hochparterre with cellar windows.
  - The Beletage (first floor) is tallest and richest, and ornament thins toward the top.
  - Details include window surrounds, pediments, consoles, quoins, risalits and bays (Erker), cast-iron and stone balconies, gables, mansard and tiled roofs with dormers, and chimneys.
  - Six styles: rich historicist, moderate, stripped of stucco, Jugendstil, brick, and a 1980s infill block.
- **Corner houses:** cut corners (Eckabschrägung) with a pub door. Two have octagonal oriel towers with copper domes.
- **Weathering:** each facade gets its own grime map, painted around its real windows and ledges: soot under the cornice, run-off streaks below sills, rising damp, blotches. On never-renovated houses, patches of fallen plaster show the brick.
- **Pavements:**
  - Bernburger mosaic strips run along the house and the kerb, with parallel edge rows and the middle laid at 45°.
  - Two rows of 1 m Silesian granite slabs run between them, with joints offset.
  - Granite kerbs stand 12 cm above the carriageway.
- **Carriageways:** Kettenstraße is granite setts with grooved tram rails and overhead wires on span wires from the facades. Gordianstraße is asphalt with sett gutters.
- **Street furniture:**
  - gas lanterns, an advertising column (Litfaßsäule) and a green hand pump
  - bollards, enamel street signs, orange litter bins and tram stops
  - lindens, parked cars, bicycles and a yellow tram
- **The rest:** a vacant lot with a tagged hoarding and a ghost sign on the bare firewall. Courtyards and side wings sit behind, with simpler blocks beyond.
- **Viewer:**
  - Time of day runs from morning to after dark, with lit windows and pools of lamplight.
  - Ambient occlusion (GTAO) can be switched on and off.
  - **Save as .glb** exports the district for Blender or Godot. The weathering is a live shader effect, so it doesn't travel in the .glb; a Godot port would bake it into the facade textures.

Sources used: Berliner Mieterverein on the Beletage and storey heights; hausjournal.net on the 22 m Traufhöhe; Berliner Zeitung ("Der Schweinebauch") and the-berliner.com on the pavement pattern; the Prenzlauer Berg article on Wikipedia for the block structure.

## Files

| File | What it is |
|---|---|
| `index.html` | The built page (loads three.js from jsDelivr). |
| `template.html` | Page shell and controls. |
| `src/00_util.js` … `src/80_scene.js` | The generator: utilities, textures, materials, building parts, buildings, streets, furniture, trees, cars, tram and bikes, district layout, scene and viewer. |
| `build.py` | Joins `src/` into the page: `python3 build.py site` writes `index.html`; `dev` writes `index-dev.html` against a local `npm install three@0.160.0`; `prod` writes the artifact copy. |

The `.gdignore` one level up keeps Godot from importing any of this.
