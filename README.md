# Chain State

*Working title.* Foundation for a first-person detective game: half **Verlet-style grapple platforming**, half **investigation and dialogue**. You play a detective solving crimes caused by magic across the floating, chained-together states of the Gordian Empire, a Victorian-style society. Built in **Godot 4.7** for **desktop** (keyboard and mouse).

**Play the latest build in your browser:** https://kmad666.github.io/Chain-State/
**Windows build:** open the latest run under the repo's **Actions** tab and download **ChainState-windows** from Artifacts.

## What's in the test range
- A 400 × 400 m flat plane with a 1 m grid, so you can read speed and distance
- One floating cube to swing from
- One NPC (an orange rectangle labelled "NPC") to talk to

## Controls
| Input | Action |
|---|---|
| Mouse | Look |
| Hold **Left Click** | Fire the silver chain at **any surface** under the crosshair (green = in reach). You swing once it lands |
| Release Left Click | Let go. Letting go at speed gives a small boost |
| **Space** | Jump; while hooked, reel in |
| Right Click / Wheel Up | Reel in |
| Q / Ctrl / Wheel Down | Reel out |
| **WASD** | Walk, steer in the air, push your swing toward where you look |
| **Shift** | Dash where you look (1.2 s cooldown) |
| **E** (or Left Click) on an NPC | Talk |
| **1–9** / click | Pick a dialogue choice. **Esc** leaves the conversation |
| **L** / Tab / J | Open the Agent's logbook |
| **E** on a clue | Examine it and log it as evidence |
| **F2** | Dialogue editor |
| **R** | Back to the start |
| **Esc** | Pause: controls, physics presets and live feel sliders |

You get 3 grapples in the air by default; touching the ground refills them.

## Tuning the feel
Pause with **Esc**. On the right there's a slider for every movement number: gravity, walk speed, jump, gravity while hooked, rope pull, swing push, reel speed, top speed, reach, air grapples, hook speed, release boost, dash and mouse sensitivity. Changes apply instantly and are saved. Three presets give starting points:

1. **Float**: no gravity on the rope, so you drift on momentum.
2. **Pendulum**: full gravity on a rigid rope, for classic Verlet swing arcs.
3. **Bungee** (default): the rope pulls you in like an elastic band, with 60% gravity.

### How the rope works
`scripts/player/player.gd` treats the rope as a Verlet distance constraint. Each physics tick (120 per second) it predicts where gravity and momentum would carry you. If that's past the rope length, it projects the point back onto the rope's sphere and derives your velocity from the correction. You get real pendulum swings, and reeling in pumps speed.

## Levels
The game opens on a **level select**. Click a level or press its number. In a level, Esc → **Level select** takes you back.

- **Test Range:** the flat plane with the floating cube, the NPC and four practice clues.
- **Level 1:** two floating islands level with each other, with a short gap. Start near the edge facing the far island.
- **Level 2:** two floating islands, the far one further away and 16 m higher, so you need height and momentum.

The islands have flat, grassy tops to walk on and jagged rock cones underneath. Every surface can be grappled, including the cliffs and the undersides. There are no obstacles or details yet: this is a blank countryside for practising level design. Falling off sends you back to the start.

## Skies
The range uses Kenney's free CC0 skybox pack: **Day** (default), **Morning**, **Night**, **Space** and **Alien**. Switch between them in the pause menu (Esc → Sky); your choice is remembered. Each sky moves the sun light to where the painted sun sits, and matches the light colour, ambient light and fog to that sky.

## Look
- **Sun glare:** looking toward the sun brings up a lens glare: a bright core, slowly turning rays and faint coloured ghosts toward the screen centre. It fades when you look away or when anything blocks the sun, and it's dimmer for the moon and the space sky. See `scripts/ui/sun_glare.gd`.
- **Polished chain:** the chain, arrowhead and cuff use `shaders/chrome.gdshader`, a mirror-silver material. Godot's lighter renderer can only reflect the sky, so the shader fakes a full environment (bright sky above, a sharp horizon, darker ground below) matched to the current sky. That's what makes each link's facets flash light and dark.

## Logbook and evidence
Press **L** to open the Agent's logbook. The game pauses while it's open.

- **Field guide:** what each school of magic leaves behind at a crime scene, what that implicates, and the ordinary causes it is easily mistaken for. It covers **fire, nature, ice and water** magic. The text lives in `data/magic_schools.json`, so it can be edited without touching code.
- **Case evidence:** every clue you've examined, with the school it points to and a note.

The test range has four practice clues in a row near the start, one per school: a ring burnt into stone, a crate that has sprouted, frost on a summer post, and a tide line on a dry crate. Look at one and press **E** to examine it.

To place a clue in a scene, add `scripts/world/evidence.gd` with an `evidence_id`, `school`, `title` and `note`, and build its shape with `part()` (see `_build_evidence()` in `world.gd`).

## Dialogue
Walk up to an NPC, look at it and press **E**. A tall Disco Elysium-style column opens on the right. The conversation builds up as a log (**SPEAKER** — line), with numbered choices underneath. Choices you've already picked in this conversation turn grey.

The test NPC's tree is placeholder text. "test test test" offers options A, B and C, and each one leads to a line that offers the others, so the conversation loops until you pick **[Leave]**.

### Dialogue editor (F2)
Each NPC has its own tree, saved as `dialogue/<npc_id>.json`.

- Pick the NPC from the drop-down.
- Each **box** is one line the NPC says: an optional speaker name (empty means the NPC's name), the text, then the choices.
- Each choice has an **orange socket** on the right. Drag it to a box's **blue socket** to say where that choice leads. Drag it into empty space to create a new box that's already linked. A choice with no link ends the conversation.
- **+ Line** adds a box, **Set start** marks the opening line (gold), and **Delete** (or the Del key) removes the selected boxes.
- **+ Choice**, **✕** and **↑** add, remove and reorder choices.
- **Play test** runs the conversation as it stands, saved or not, and returns you to the editor.
- **Save** (Ctrl+S) writes the file. **Revert** goes back to the last saved version.

**Where Save writes:**
- **Running inside the Godot editor:** straight into the project's `dialogue/` folder. Commit it and it ships with the game.
- **An exported build (Windows or browser):** to your user data folder, overriding the shipped file on that computer. Use **Copy JSON**, **Download** (browser) or **Open folder** (Windows) to get the file, then put it in `dialogue/` in the repo.

To add a new NPC, place `scripts/world/npc.gd` in a scene (or add one in `world.gd`) with a unique `npc_id` and `display_name`. It shows up in the editor's drop-down automatically.

## Project layout
- `scenes/level_select.tscn` + `scripts/ui/level_select.gd`: the level select, the first screen
- `scenes/world.tscn` + `scripts/world/world.gd`: the playable world. Builds the chosen level and wires the UI together
- `scripts/world/levels.gd`: the list of levels
- `scripts/world/floating_island.gd`: a procedurally shaped floating island (grass top, rock cone below)
- `scripts/player/player.gd`: first-person controller, grapple, rope physics, feel tuning, talk targeting
- `scripts/player/viewmodel.gd`: your right arm (sleeve, glove, silver cuff); punches out on fire, reaches up while hooked
- `scripts/player/chain.gd`: the silver chain, coiled around the forearm and paying out to the arrowhead
- `scripts/world/npc.gd`: talkable NPC (collision layer 2: solid and talkable, but can't be grappled)
- `scripts/autoload/game.gd`: input map and UI mode (play, pause, dialogue, editor)
- `scripts/autoload/dialogue_db.gd`: loads and saves dialogue trees (the file format is documented at the top)
- `scripts/ui/dialogue_panel.gd`: the right-hand conversation column
- `scripts/ui/dialogue_editor.gd`: the graph editor
- `scripts/ui/hud.gd`, `scripts/ui/pause_menu.gd`: crosshair, speed, prompts, pause menu and sliders
- `tests/test_runner.tscn`: smoke tests (dialogue loops, a real grapple swing, editor save/load). Run `godot --headless res://tests/test_runner.tscn`. CI runs them on every push
- `.github/workflows/deploy.yml`: web build to GitHub Pages and Windows build to Artifacts on every push to `main`

## Rendering
For now the project uses Godot's **Compatibility** renderer, so the browser build works for quick testing. When the game moves to desktop-only releases, switch to **Forward+** in Project Settings to get better lighting and effects.
