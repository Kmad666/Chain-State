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
| Hold **Left Click** | Fire the silver chain at **anything inside the reticle circle** (green = in reach). A small diamond shows exactly where it will bite. You swing once it lands |
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
| **E** while hooked to a caster | Auto-wrap round them; after 3 laps, **E** again to **arrest** |
| **F2** | Dialogue editor |
| **F3** | Performance readout: FPS, the slowest recent frame, and the last hitch with what had just happened |
| **R** | Back to the start |
| **Esc** | Pause: controls, physics presets and live feel sliders |

You get 3 grapples in the air by default; touching the ground refills them.

## Tuning the feel
Pause with **Esc**. On the right there's a slider for every movement number: gravity, walk speed, jump, gravity while hooked, rope pull, swing push, reel speed, top speed, reach, air grapples, hook speed, release boost, dash, mouse sensitivity and reticle size (aim assist). Changes apply instantly and are saved. Three presets give starting points:

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
- **Enemy Test (Ground)** and **Enemy Test (Air):** a wizard, and the witch's tree (see below).

The islands have flat, grassy tops to walk on and jagged rock cones underneath. Every surface can be grappled, including the cliffs and the undersides. There are no obstacles or details yet: this is a blank countryside for practising level design. Falling off sends you back to the start.

## Grapple economy
Grapples on **ordinary** things (islands, rock, the test cube) are limited: 3 per jump, refilled when you land. Grapples on **magic** are free and unlimited: blue orbs, a witch's ward and the casters themselves. The crosshair says "magic, free grapple" when you're aiming at something free.

**Aim assist.** You don't need pinpoint aim at swing speed. Anything inside the big reticle circle counts:
1. If a blue orb or a caster is in the circle and in sight, the chain goes to the **nearest** one.
2. Otherwise it bites whatever surface is dead centre.
3. If the centre is open sky, it scans the circle outward and takes the surface **closest to the centre**, such as an island edge you just missed.

The diamond marker shows the pick before you fire. You can resize the circle (or turn it off at 0) with the "Reticle size" slider.

**Auto-aim lock-on.** Things built to be grappled carry a **grapple-target** label (the `grapple_target` group plus a `grapple_name`). For now that's the blue orbs: the tree's orbs and the hookable orbs in a wizard's volley.
- **Locking on:** auto-aim locks onto the one nearest your crosshair within a 30° cone, even well outside the reticle.
- **Highlight:** the locked orb turns **gold and pulses**, with gold brackets and a "blue orb 23 m" tag beside it.
- **Out of sight:** the lock **holds once the orb leaves your view**, while it stays in reach and in line of sight. A gold arrow at the screen edge points to it, and firing still sends the chain there.
- **Switching:** aim clearly closer to another orb, or put one inside the reticle, and the lock switches to it. Once you're hanging from an orb, the lock moves on to the next.
- **What wins:** anything inside the reticle (a surface or a caster) beats a lock that's off to the side, so you can still pick a wall on purpose. The highlight always shows what the chain will actually hit.
- **Tuning:** the "Auto-aim lock cone" slider sets the cone; 0 turns lock-on off.

To make anything else lock-on-able, add it to `grapple_target`, put it on the HOOK layer (4), and optionally give it `grapple_name` and `set_highlight(on)`.

## Stun
Touching **magic that isn't safe**, meaning any red orb, any projectile or the outside of a ward, **stuns you for 3 seconds**: the chain drops, you can't move or grapple, your sideways motion dies and you fall straight down, passing through wards. A purple flash and a **STUNNED** countdown (top left) make it clear. Control returns when it wears off, followed by a short grace period. Stuns replace the old hearts: falling is the punishment.

## Enemies: witches and wizards
Spellcasters on brooms (placeholder low-poly models: a robe, a pointy hat, a broom, a glowing casting hand).

- **Wizard (Enemy Test (Ground)):** blue robe and white beard; flies low over the island. Within **38 m** his casting hand glows red, he slows and faces you, and after a warning swell he fires a **spread-out line of five large dark red orbs** straight across, parallel to the ground (NieR-style). Alternate volleys shift by half a gap. Hook him from within **20 m** and swing around.
- **Witch (Enemy Test (Air)):** she doesn't shoot. Her **tree** is a tall, wide cone of **40 large dark red orbs** (1.8 m radius, never clumped) and **10 blue orbs**, spaced far apart and slowly turning, high above the island: a platforming climb in its own right. The blue orbs spiral up the cone as the route (free grapples, and they keep riding the tree while you hang from them). At the top she hovers inside her **ward**, a large faceted forcefield (17 m radius) with one opening, its rim **traced in gold** so you can find it from across the sky. You can grapple the ward, but touching it stuns you. You can hook her through the opening from just outside (her hook range grows with the ward: 25 m), but **laps only count once you're inside**.

**Arresting (both):** hook the caster from within range, then wrap the chain round them three times. Each lap adds a silver coil.
- **Auto-wrap:** press **E** while hooked and you'll circle them automatically, with the camera holding them dead centre. It takes about 2 s a lap at roughly 85 km/h. For the witch, you have to be inside her ward first.
- **By hand:** swinging round yourself works too.
- **Arrest:** after the third lap the caster is **bound**. Press **E** again to **ARREST**: an "ARRESTED" banner and a brief tint, and the chain comes free with **your momentum untouched**. There's no slow motion or freeze, so it doesn't break the flow with several casters about.
- A witch's ward breaks with her. Let go mid-wrap and the coils slip loose after a moment.

Code: `scripts/combat/sentry.gd` (casters, the wrap), `orb_tree.gd` (the witch's tree), `ward.gd` (the forcefield), `bullet_field.gd` (projectiles), `hook_orb.gd` (blue orbs).

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

## Sound and decoration

Sound effects come from Kenney's 3D Platformer and FPS starter kits (CC0) and play through the `Sfx` autoload (`scripts/autoload/sfx.gd`). Sounds out in the world, such as a wizard casting, are positional: they fade with distance and pan left and right.

| Event | Sound |
|---|---|
| Jumping | one of four jump variations |
| Landing (louder and deeper the harder you land) | land |
| Walking (a long loop that speeds up with you) | footsteps |
| Throwing the chain | a mechanical clack |
| The hook biting | a short, high clack |
| Being stunned | a hurt hit plus a low thud |
| A wizard's volley | a casting sound, at his position |
| Arresting a caster | an arrest sound, at their position, plus the chain coming free |
| A new logbook entry | coin |

Still to do: a proper chain rattle, the ward's hum, orb whooshes and ambience. Island levels also get Kenney's grass tufts (recoloured to the island green) and slowly drifting clouds. See CREDITS.md.
