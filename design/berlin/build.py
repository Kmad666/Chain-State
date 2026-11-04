import glob, json, os, sys
here = os.path.dirname(os.path.abspath(__file__))
mode = sys.argv[1] if len(sys.argv) > 1 else "dev"
V = "0.160.0"
if mode == "dev":
    imap = {"three": "./node_modules/three/build/three.module.js", "three/addons/": "./node_modules/three/examples/jsm/"}
else:
    imap = {"three": f"https://cdn.jsdelivr.net/npm/three@{V}/build/three.module.js",
            "three/addons/": f"https://cdn.jsdelivr.net/npm/three@{V}/examples/jsm/"}
header = """import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { Sky } from "three/addons/objects/Sky.js";
import { mergeGeometries, mergeVertices } from "three/addons/utils/BufferGeometryUtils.js";
import { EffectComposer } from "three/addons/postprocessing/EffectComposer.js";
import { RenderPass } from "three/addons/postprocessing/RenderPass.js";
import { GTAOPass } from "three/addons/postprocessing/GTAOPass.js";
import { OutputPass } from "three/addons/postprocessing/OutputPass.js";
import { GLTFExporter } from "three/addons/exporters/GLTFExporter.js";
"""
code = header + "\n".join(open(f).read() for f in sorted(glob.glob(os.path.join(here, "src", "*.js"))))
tpl = open(os.path.join(here, "template.html")).read()
if mode in ("dev", "site"):
    tpl = '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"></head><body>\n' + tpl + "\n</body></html>"
out = tpl.replace("{{IMPORTMAP}}", '<script type="importmap">' + json.dumps({"imports": imap}) + "</script>").replace("{{CODE}}", code)
# dev: index-dev.html against a local node_modules (npm install three@0.160.0)
# site: index.html for the GitHub Pages copy; prod: the body-only page published as a Claude artifact
name = {"dev": "index-dev.html", "site": "index.html"}.get(mode, "kettenkiez.html")
open(os.path.join(here, name), "w").write(out)
print(name, len(out))
