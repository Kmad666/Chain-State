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
| **Q** / **E** while hooked | **Q** reels in, **E** gives slack (right mouse and Ctrl still work) |
| **Space** in the air | If the bottom of the screen shows **▼ LAND**, aim straight down, latch on and reel in fast. Doesn't count as a swing |
| **E** while hooked to a caster | Lock your view on them while you swing round (A / D circle you round fast); **E** again frees it. Once they're bound, **E** **arrests** |
| **F2** | Dialogue editor |
| **F4** / **V** | Dev fly: noclip flight (WASD, Space up, Ctrl down, Shift fast) |
| **F3** | Performance readout: FPS, the slowest recent frame, and the last hitch with what had just happened |
| **R** | Back to the start |
| **Esc** | Pause: controls, physics presets and live feel sliders |

You get 3 grapples in the air by default; touching the ground refills them.

## Tuning the feel
Pause with **Esc**. On the right there's a slider for every movement number: gravity, walk speed, jump, gravity while hooked, rope pull, swing push, reel speed, top speed above walk, reach, air grapples, hook speed, release boost, dash, mouse sensitivity and reticle size (aim assist). Changes apply instantly and are saved. Three presets give starting points:

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

**Awareness** is kept simple. Within its **spot range** a caster notices you, and a yellow **!** appears over its head. It then **follows** you until you get past its **leash range**, when it gives up and goes back to patrolling.

- **Wizard** (Enemy Test (Ground)): blue robe, white beard, flies low over the island.
  - **Hunting:** spots you within 38 m and follows slowly (3.5 m/s) to about 12 m away, giving up past 55 m. While he has you spotted, his casting hand glows red, swells as a warning, and fires a **spread-out line of five large dark red orbs** straight across, parallel to the ground. Alternate volleys shift by half a gap.
  - **Arresting him takes 3 wraps**, but after each of the first two **he burns the chain and throws you back** about 14 m/s. The coils stay on him, so hook him again for the next lap. The third lap binds him.
- **Apprentice** (The Ascent): a smaller broom-rider in green.
  - **Hunting:** patrols a **wide circle** (25 m) round its post. It spots you within 35 m and **chases** at 9 m/s (slower than your 16, so you can get away), giving up past 60 m. It fires **single large, fast orbs straight at you**.
  - **Resisting:** hooked, it **zigzags** side to side, about ±3 m every 0.6 s, to shake you.
  - **Arresting:** **one lap** binds it.
- **Cherub** and **Sage** (Cherub Test): see below.
- **Witch:** retired for now, pending a redesign. Her level (the orb tree and ward) is off the level select, but the code stays, and the aim tests still use her blue orbs.

**Arresting:** hook the caster from within range (20 m) and **swing round them yourself**.
- **The lock:** press **E** to lock your view on them. Holding **A** or **D** then pushes you round them, building up to top speed: about **3.5 s a lap**. E again frees your view.
- **Coils:** each full lap adds a silver coil. Let go mid-lap and that lap is lost; an apprentice's coil also slips off a moment after you let go.
- **The arrest:** once they're **bound**, **E** **arrests**. They drop to the ground with the coils on, your chain comes free with your momentum untouched, and a small "Arrested." line appears. There are no effects.

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
| A new logbook entry | coin |

Still to do: a proper chain rattle, the ward's hum, orb whooshes and ambience. Island levels also get Kenney's grass tufts (recoloured to the island green) and slowly drifting clouds. See CREDITS.md.

## Platform Test

A course of Kenney Platformer Kit pieces over the void, built for the core puzzle: **cross every gap in as few swings as you can.**

- **Grass-block pads** (Kenney Platformer Kit): you land on these. They're solid but **can't be grappled** (they sit on their own physics layer, `Player.LAYER_LAND`). Aim at one and the crosshair greys out with "can't grapple this".
- **Crate anchors:** metal-framed crates hung high above each gap. They're the **only** things the chain can bite, and auto-aim locks onto them in gold.
- **The gaps:** this first section takes one swing per gap. There are five gaps of 30–37 m, getting less level and stepping to the side. None can be crossed with a running jump and dash. The gold finish pad is at the end.
- **The tally:** "SWINGS n · PAR 5 · PAD n/5 · FALLS n" at the top. Each pad is a checkpoint; fall into the void and you're back on the last one.
- **Rope control:** Q reels in and E gives slack while you hang. Slack pays out freely, without the bungee tug.
- **Land below:** the line at the bottom of the screen says whether there's land straight under you. Over a pad, press **Space** to latch down onto it, which is handy when a swing overshoots.
- **Tested:** a bot plays the whole course in the test suite, at exactly par, so every gap is proven crossable in one swing. Each gap gives roughly 8–12 m of leeway on when you let go.

Field of view is now **90** (slider in the pause menu), widening a little with speed.

## Hamlet

A small hamlet on a floating island about 130 m across, built from Kenney's **Modular Buildings** pack, with trees, barrels and fences from the Platformer Kit.

- **Layout:** you arrive from the south and walk up the road into the square, which has a well and a signpost. A lane runs east to west, and a road runs north to the chapel bell tower. Around them are four houses, the inn and the smithy.
- **Grappling** follows the Platform Test rules. Buildings, the ground and the well are solid but **can't be grappled**. The grapple points are crates above each roof and on the bell tower, the signpost and a tall tree in the south-west. Each one is within chain reach of another, so there's a rooftop route as well as the streets.
- **The case:** the Harrow house in the north-east burnt from the inside. The **innkeeper** (by the inn) and a **neighbour** (in the square) have short dialogues, and there are three fire clues to examine and log: the door, the back-gate latch and a ring of ash in the fenced back yard.

## City

A dense city on a 130 m island, built from Kenney's **Retro Fantasy Kit**.

- **Buildings:** every block is wall-to-wall **five-storey stone terraces** (about 17.5 m, plus a gable). Street-facing walls get windows and doors; some buildings are plain stone and some painted.
- **Streets**, all cobblestone: two tree-lined **boulevards** cross at a **fountain plaza** ringed with trees. A grid of 6 m **streets**, 3 m **narrow streets** and 2.5 m **alleys** (two of them diagonal) cuts the blocks, and a tree-lined **ring promenade** runs round the edge. You enter by the south gate.
- **Grappling:** 12 crate anchors hang about 25 m up over the crossroads, above the rooftops. Buildings and cobbles are solid but can't be grappled, so you swing down the street canyons from crossing to crossing.
- **Performance:** the terraces are drawn in bulk, one draw call per kind of wall block (`MultiMesh`), with one collision box per run of terrace. Hidden inner cells draw only their top storey.

## Speed

- **Air steering** tops out at **walking pace**, 6 m/s by default.
- **Top speed** is **walk speed + 10**, so 16 m/s by default. It's a hard cap: swings, dashes and release boosts all stop there.
  - While swinging, your whole velocity is capped.
  - In free flight, only your horizontal speed is capped, so falling still works.
- **Exception:** the ground latch's fast reel-in is a landing aid, not travel, so it isn't capped.
- **Sliders:** both live in the pause menu, as "Air steer speed" and "Top speed above walk".
- **Saved settings:** older saved settings for these two are reset to the new defaults.

## The Ascent

A long ride.
- **The island:** a great forest island about 220 m across, about 500 trees, shrubs, rocks and mushrooms from the two Kenney kits, drawn in bulk. A giant tree stands at its heart.
- **The route:** **50 crate anchors** spiral up round the giant tree, about 8 m higher each time and 19–27 m apart, to a gold **finish platform about 405 m up**.
- **Free anchors:** they cost no air grapples, so you can chain the whole climb without touching ground. Hang on, aim at the next one, let go and fire. The bungee pull lifts you as you go.
- **Rest ledges** below anchors 10, 20, 30 and 40 are checkpoints. Drop more than 45 m below your last one and you're put back on it.
- **Clouds:** a second cloud layer between about 120 and 360 m to climb through.
- **The readout:** "ANCHOR n/50 · HEIGHT · TIME · FALLS" at the top. The clock starts at the first anchor and stops when you land on the gold platform.
- **Tested:** a bot chains all 50 anchors to the top in about 85 seconds without breaking top speed.

**Apprentices:** five of them hover just off the route, near anchors 8, 17, 26, 35 and 44. An apprentice is a weaker flying caster: a smaller broom-rider in a green robe.
- **Its shots:** within 45 m it fires a **single large, fast orb** (24 m/s, about twice the wizard's orb size) **straight at you**, leading your movement a little, every 2.2 s. A hit stuns you like any red orb, so you drop, and below a rest ledge you're put back on it.
- **Arresting it:** hook it, lock on with **E**, and circle it once with **A** or **D**: **one lap** binds it, even while it zigzags. Then **E** again to arrest, and it drops out of the sky.
- **Hunting:** each one patrols a wide circle round its spot and chases you (with a **!**) once you're within 35 m, until you're 60 m clear.

**Aim rule:** for half a second after you let go of an anchor, the aim ignores it, and auto-aim never locks onto the anchor you're hanging from. Swapping to the next anchor never re-hooks the one you just left.

## Tower

A reusable building piece, `scripts/world/grapple_tower.gd`, shown off on its own grassy island in the **Tower** level.

- **The tower:** 16 round stone sections of 8 m each, from Retro Fantasy Kit pieces with a painted band every third section. About **130 m** to a walkable, battlemented **crown**.
- **Hooks:** from every section a **wooden beam juts 5 m out**, each a quarter-turn round from the last, with a free grapple crate at its tip. The quarter-turn keeps every crate in clear sight of the next instead of hidden behind the tower.
- **Rest ledges:** a wide stone ring every 4 sections. The **last hook** stands on a post above the crown, so you swing up and latch down onto the top.
- **Grappling:** stone and beams are solid but can't be grappled; only the crates can.
- **Tested:** a bot climbs hook to hook to the top post in about 22 s, then lands on the crown.
- **Reuse:** to drop one into any level, `var t = preload("res://scripts/world/grapple_tower.gd").new()`, set its position, `add_child(t)`. Exports cover sections, unit size, ledge spacing, hook reach, free hooks and the first hook's direction. `t.hooks` and `t.top_point()` give you its crates and summit.

## The Nation (draft) and dev fly

**The Nation (draft)** lays the whole Gordian Empire out at **1:50** from the casebook map (`scripts/world/nation.gd`). The map's scale bar makes one map unit about 536 m of real Germany, so 10.73 m in game; every state keeps its real bearing from Delos.

- **Delos** (the Bundesinsel) sits in the middle: a 1 km hero island with a blockout city, a domed parliament and a 110 m landmark tower.
- **The five state capitals** sit 3.7 to 6.7 km out:
  - Gordia (Berlin), north-east
  - Rhenish Gordia (Köln), west
  - Delosen (Dresden), east
  - Arcaden (München), south-east
  - Daedalen (Stuttgart), south-west
- Each capital is a 520 to 640 m island with a block city in its state colour, a 75 m tower and three satellite isles within 2 km.
- **Twelve ordinary islands**, 100 to 400 m across, sit along the spokes and round the ring between the states.
- A thin haze turns the far states into silhouettes. Floating labels name every island and give its size.

**Dev fly** works in every level:
- **F4** or **V** toggles noclip flight.
- **WASD** flies where you look, **Space** rises and **Ctrl** or **C** sinks.
- **Shift** goes 5× faster: 60 m/s normally, 300 m/s boosted.
- The HUD shows your speed, your altitude and the nearest island, either "over DELOS" or "ARCADEN 2.4 km".

## Cherub (boss) and Sages

**Cherub Test** is one plain grassy island with a **Cherub** hovering high off its north edge: a giant floating eye (8 m) with feathered angel wings.

- **Waking:** come within about 135 m and it turns its eye on you. After a **2 s stare** it casts a **vast transparent cone** from its eye toward where you stood: 175 m long and about 270 m across at its mouth, big enough to swallow the island.
- **The trap:** inside the cone you're **trapped**; its wall stops you dead.
- **The barrage:** the eye fills the cone with **bullet-hell patterns**, cycling every 7 s with a short breather between. About 200 orbs are in flight at the peak.
  - **Spiral:** two turning arms.
  - **Rings:** double rings that open as they fly.
  - **Aimed fan:** seven shots at you.
- **Sages:** small winged eyes, caster-sized, released from the Cherub's eye, at most 3 at a time. Each flies out to a spot inside the cone, hovers there and **fires aimed orbs**.
  - They're the **only things you can grapple** in the fight: free, and auto-aim locks onto them.
  - **One lap** binds a Sage, then E arrests it.
- **Winning:** arrest **5 Sages** and the Cherub is **spent**. The barrage stops, the cone fades and its eye closes.
- **Performance:** all orbs share one bullet MultiMesh; the cone is one transparent mesh, pre-drawn at load so it never stalls; no lights.

Code: `scripts/combat/cherub.gd`, `eye_model.gd` (the winged eye, shared), and kind `"sage"` in `sentry.gd`.
