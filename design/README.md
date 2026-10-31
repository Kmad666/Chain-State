# Design files

Everything made for Chain State that isn't the game itself (the Kenney assets live under `assets/`). The deploy copies this folder to the site, so it's browsable at **https://kmad666.github.io/Chain-State/design/**.

| File | What it is |
|---|---|
| `index.html` | The hub page linking everything below. |
| `casebook/index.html` | **The Casebook.** It holds: the mind map of the world, the atlas of the Gordian Empire, the four states, the cast, the endings and the open questions. |
| `casebook/gordian-empire-map.svg` | The atlas map on its own. `scripts/world/nation.gd` lays out the Nation level from it. |
| `casebook/cast-agent.json` | The cast cards saved in the live casebook (only the Agent so far). |
| `master-todo.md` / `todo.html` | **The Master To-Do**: mood boards, lore, cast, gameplay, enemies, levels, art, UI, release and the playtest checklist. `todo.html` renders it in a browser. |
| `spire-town-reference.png` | The reference painting Spire Town is built from. |
| `cloud-tree-reference.png` | The reference painting the Cloud Tree is built from. |
| (not stored) | The White Citadel's reference is by snowskadi: http://snowskadi.deviantart.com/. It's the artist's watermarked work, so it's credited here rather than copied into this public repo. |
| `level-grid/chain-state-level-grid.xlsx` | **The level-grid template**: 41 × 41 squares at 10 m each, with a legend, an example and a details sheet. |

These are snapshots. The live, editable originals are in Claude:
- [Casebook](https://claude.ai/artifact/FVh9A5W1N4upxQ6ZfCBKH2): its cast cards save there.
- [Master To-Do](https://claude.ai/artifact/LvGzsRvYQgt7Ltz5LvpvkF)

Ask Claude to refresh this folder when the originals change.

The `.gdignore` file keeps Godot from importing anything here into the game.
