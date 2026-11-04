#!/usr/bin/env bash
# Rebuild and lightmap the baked levels. Needs a Vulkan driver (a GPU, or Mesa's
# software lavapipe: apt install mesa-vulkan-drivers) and, on a server, xvfb.
#   tools/bake.sh                 every scene in levels/baked/
#   tools/bake.sh copper_kettle   just one
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . -s tools/make_bake_scenes.gd
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
RUN=()
command -v xvfb-run >/dev/null && [ -z "${DISPLAY:-}" ] && RUN=(xvfb-run -a -s "-screen 0 1600x900x24")
for f in levels/baked/*.tscn; do
  name=$(basename "$f" .tscn)
  [ $# -gt 0 ] && [[ " $* " != *" $name "* ]] && continue
  BAKE_SCENE="res://$f" "${RUN[@]}" "$GODOT" -e --path . --rendering-method forward_plus --rendering-driver vulkan 2>&1 | grep --line-buffered "autobake"
done
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
