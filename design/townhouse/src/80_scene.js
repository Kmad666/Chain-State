// ============================================================== scene and viewer
// The townhouse on its corner: setts in the street, granite pavements, a gas lamp.
// Elevation views use an orthographic camera so they line up with the design sheet.

const D = { aKerb: 6, aFront: 9, bKerb: 6, bFront: 9 };    // for the lamp's light pool
let renderer, scene, persp, ortho, camera, controls, composer, gtao, sky, sun, pmrem, envRT;
const STATE = { hour: 16.5, ao: true, dirty: true };

function setting() {
  const B = new Bucket();
  // pavement round the house (2.6 m), kerbs, and setts beyond
  const W = TH.W, Dp = TH.Dp, pw = 2.6;
  const ring = [[-pw, pw], [W + pw, pw], [W + pw, -Dp - pw], [-pw, -Dp - pw]];
  B.add("slabs", groundPoly(ring, 0, 2));
  B.add("setts", groundPoly([[-60, 60], [60, 60], [60, -60], [-60, -60]], -0.12, 3));
  const k = [[-pw, pw], [W + pw, pw], [W + pw, -Dp - pw], [-pw, -Dp - pw], [-pw, pw]];
  for (let i = 0; i < 4; i++) {
    const [ax, az] = k[i], [bx, bz] = k[i + 1];
    const len = Math.hypot(bx - ax, bz - az), ang = Math.atan2(bz - az, bx - ax);
    const g = new THREE.BoxGeometry(len + 0.3, 0.14, 0.3); g.rotateY(-ang); g.translate((ax + bx) / 2, -0.05, (az + bz) / 2);
    B.add("kerb", boxUV(g.toNonIndexed(), 0.6));
  }
  gasLamp(B, -1.6, 1.6, 0);
  for (const [k2, geo] of B.merge()) {
    const m = new THREE.Mesh(geo, MAT[k2]); m.receiveShadow = true; m.castShadow = !["slabs", "setts", "lightPool"].includes(k2); m.name = k2; scene.add(m);
  }
}

// big soft cumulus: clusters of sprites low over the horizon, as in the illustration
function cumulus() {
  const c = canvas(256, 256), x = c.getContext("2d");
  const g = x.createRadialGradient(128, 128, 8, 128, 128, 126);
  g.addColorStop(0, "rgba(255,255,255,1)"); g.addColorStop(0.55, "rgba(255,255,255,0.85)"); g.addColorStop(1, "rgba(255,255,255,0)");
  x.fillStyle = g; x.fillRect(0, 0, 256, 256);
  const tex = toTex(c, true, false), rng = new Rng(77);
  MAT.cloud = new THREE.SpriteMaterial({ map: tex, transparent: true, depthWrite: false, fog: false, color: "#ffffff" });
  MAT.cloudShade = new THREE.SpriteMaterial({ map: tex, transparent: true, depthWrite: false, fog: false, color: "#c9d3e6" });
  const group = new THREE.Group(); group.name = "clouds";
  for (let k = 0; k < 9; k++) {
    const a = rng.range(-1.2, 2.6), dist = rng.range(260, 420), cx = Math.cos(a) * dist, cz = -Math.sin(a) * dist - 40, cy = rng.range(70, 170);
    const size = rng.range(40, 80);
    for (let i = 0; i < 14; i++) {
      const sp = new THREE.Sprite(i < 5 ? MAT.cloudShade : MAT.cloud);
      sp.position.set(cx + rng.gauss() * size * 0.8, cy + Math.abs(rng.gauss()) * size * 0.35 + (i < 5 ? -size * 0.1 : 0), cz + rng.gauss() * size * 0.3);
      sp.scale.setScalar(size * rng.range(0.5, 0.9));
      group.add(sp);
    }
  }
  scene.add(group);
}

function sunDir(hour) {
  const t = (hour - 5.5) / 15;
  const el = THREE.MathUtils.degToRad(Math.max(-4, 50 * Math.sin(Math.PI * t)));
  const az = THREE.MathUtils.degToRad(70 + 220 * t);
  return new THREE.Vector3(Math.sin(az) * Math.cos(el), Math.sin(el), -Math.cos(az) * Math.cos(el));
}
function updateSun() {
  const d = sunDir(STATE.hour), u = sky.material.uniforms;
  u.sunPosition.value.copy(d);
  const el = Math.asin(d.y) * 180 / Math.PI, warm = THREE.MathUtils.clamp(1 - el / 35, 0, 1);
  sun.position.copy(d).multiplyScalar(80).add(new THREE.Vector3(7, 0, -5));
  sun.target.position.set(7, 8, -5);
  sun.color.set(new THREE.Color("#fff3e2").lerp(new THREE.Color("#ffb46a"), warm * 0.8));
  sun.intensity = 4.0 * THREE.MathUtils.smoothstep(el, -2, 8);
  if (envRT) envRT.dispose();
  const skyScene = new THREE.Scene(), s2 = new Sky(); s2.scale.setScalar(1000);
  for (const k of ["turbidity", "rayleigh", "mieCoefficient", "mieDirectionalG"]) s2.material.uniforms[k].value = u[k].value;
  s2.material.uniforms.sunPosition.value.copy(d); skyScene.add(s2);
  envRT = pmrem.fromScene(skyScene, 0, 0.1, 2000); scene.environment = envRT.texture;
  const night = THREE.MathUtils.clamp(1 - (el + 3) / 8, 0, 1);
  if (MAT.cloud) { MAT.cloud.color.set(new THREE.Color("#ffffff").lerp(new THREE.Color("#ffd9b0"), warm * 0.7).lerp(new THREE.Color("#4a5160"), night)); MAT.cloudShade.color.set(new THREE.Color("#c3cde3").lerp(new THREE.Color("#c9a9a0"), warm * 0.5).lerp(new THREE.Color("#2c3240"), night)); }
  scene.fog.color.copy(new THREE.Color("#c3d3e2")).lerp(new THREE.Color("#e2bf98"), warm * 0.6).lerp(new THREE.Color("#2c3444"), night);
  MAT.lampGlass.emissiveIntensity = 4 * night + 0.2 * warm;
  MAT.glassLit.emissiveIntensity = 1.3 * night; MAT.glassLit2.emissiveIntensity = 0.9 * night;
  MAT.lightPool.opacity = 0.85 * night; MAT.lightPool.visible = night > 0.02;
  renderer.toneMappingExposure = 0.62 + 0.4 * night;
  STATE.dirty = true;
}

// views: "persp" frames the corner like the sheet's illustration; the elevations are orthographic
const VIEWS = {
  persp: { label: "Corner", pos: [24.5, 1.6, 13.5], look: [6.5, 10.8, -3.5], fov: 52 },
  front: { label: "Front", ortho: true, pos: [7, 12.8, 60], look: [7, 12.8, 0] },
  right: { label: "Right", ortho: true, pos: [70, 12.8, -5], look: [0, 12.8, -5] },
  rear:  { label: "Rear", ortho: true, pos: [7, 12.8, -70], look: [7, 12.8, 0] },
  left:  { label: "Left", ortho: true, pos: [-60, 12.8, -5], look: [0, 12.8, -5] },
  roof:  { label: "Roof plan", ortho: true, pos: [7, 90, -5], look: [7, 0, -5], up: [0, 0, -1] },
  orbit: { label: "Orbit", pos: [30, 18, 28], look: [7, 9, -5], fov: 45 },
};
function setView(id) {
  const v = VIEWS[id];
  camera = v.ortho ? ortho : persp;
  camera.position.set(...v.pos);
  camera.up.set(...(v.up || [0, 1, 0]));
  camera.lookAt(...v.look);
  if (!v.ortho) { persp.fov = v.fov; persp.updateProjectionMatrix(); }
  controls.object = camera; controls.target.set(...v.look); controls.enabled = !v.ortho || id === "roof" ? true : true;
  controls.enableRotate = !v.ortho; controls.update();
  composer.passes.forEach(p => { if (p.camera) p.camera = camera; });
  gtao.camera = camera;
  document.querySelectorAll("[data-view]").forEach(b => b.setAttribute("aria-pressed", String(b.dataset.view === id)));
  STATE.view = id; STATE.dirty = true;
  resize();
}
function resize() {
  const w = innerWidth, h = innerHeight, aspect = w / h, H = 30;
  persp.aspect = aspect; persp.updateProjectionMatrix();
  ortho.left = -H * aspect / 2; ortho.right = H * aspect / 2; ortho.top = H / 2; ortho.bottom = -H / 2; ortho.updateProjectionMatrix();
  renderer.setSize(w, h); composer.setSize(w, h); STATE.dirty = true;
}

async function main() {
  const status = document.getElementById("loadStatus"), bar = document.getElementById("loadBar");
  const tick = (text, f) => new Promise(res => { status.textContent = text; bar.style.width = (f * 100).toFixed(0) + "%"; setTimeout(res, 0); });
  renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
  renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  document.getElementById("view").appendChild(renderer.domElement);
  scene = new THREE.Scene(); scene.fog = new THREE.FogExp2(0xc3d3e2, 0.0016);
  persp = new THREE.PerspectiveCamera(50, 1, 0.1, 3000);
  ortho = new THREE.OrthographicCamera(-10, 10, 10, -10, 0.1, 400);
  camera = persp;
  pmrem = new THREE.PMREMGenerator(renderer);

  const steps = buildTextures();
  for (let i = 0; i < steps.length; i++) { await tick(`Painting ${steps[i][0]}…`, 0.05 + 0.6 * i / steps.length); steps[i][1](); }
  buildSharedMaterials();
  MAT.kerb = new THREE.MeshStandardMaterial({ map: TEX.granite.map, normalMap: TEX.granite.normal, color: "#d4d0c8", roughness: 0.7 });
  const pc = canvas(128, 128), px = pc.getContext("2d"), pg = px.createRadialGradient(64, 64, 0, 64, 64, 64);
  pg.addColorStop(0, "rgba(255,190,110,0.55)"); pg.addColorStop(1, "rgba(255,160,80,0)"); px.fillStyle = pg; px.fillRect(0, 0, 128, 128);
  MAT.lightPool = new THREE.MeshBasicMaterial({ map: toTex(pc, true, false), transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, opacity: 0 });
  await tick("Laying the limestone…", 0.75);
  buildTownhouse(scene, new Rng(1887));
  setting();
  scene.traverse(o => { if (o.isMesh && o.material.envMapIntensity !== undefined && !/glass/i.test(o.name)) o.material.envMapIntensity = 0.3; });

  sky = new Sky(); sky.scale.setScalar(2000);
  sky.material.uniforms.turbidity.value = 2.0; sky.material.uniforms.rayleigh.value = 1.2;
  sky.material.uniforms.mieCoefficient.value = 0.003; sky.material.uniforms.mieDirectionalG.value = 0.82;
  scene.add(sky);
  cumulus();
  sun = new THREE.DirectionalLight(0xffffff, 4); sun.castShadow = true;
  sun.shadow.mapSize.set(4096, 4096);
  Object.assign(sun.shadow.camera, { left: -30, right: 30, top: 30, bottom: -30, near: 1, far: 200 });
  sun.shadow.bias = -0.0002; sun.shadow.normalBias = 0.02;
  scene.add(sun, sun.target);

  composer = new EffectComposer(renderer);
  composer.addPass(new RenderPass(scene, camera));
  gtao = new GTAOPass(scene, camera, innerWidth, innerHeight);
  gtao.blendIntensity = 0.8;
  gtao.updateGtaoMaterial({ radius: 0.5, distanceExponent: 1.5, thickness: 1, scale: 1, samples: 12 });
  gtao.overrideVisibility = function () {
    const cache = this._visibilityCache;
    this.scene.traverse(o => { cache.set(o, o.visible); if (o.isPoints || o.isLine || o.name === "ivy" || o.name === "curtain" || o === sky || o.isSprite) o.visible = false; });
  };
  composer.addPass(gtao);
  composer.addPass(new OutputPass());
  controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true; controls.maxPolarAngle = Math.PI * 0.495; controls.minDistance = 3; controls.maxDistance = 200;
  controls.addEventListener("change", () => STATE.dirty = true);

  updateSun();
  wireUI();
  addEventListener("resize", resize);
  setView(new URLSearchParams(location.search).get("view") || "persp");
  await tick("Ready", 1);
  document.getElementById("loading").hidden = true;
  const loop = () => {
    controls.update();
    if (STATE.dirty) { if (STATE.ao) composer.render(); else renderer.render(scene, camera); STATE.dirty = false; }
    requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);
  window.__ready = true; window.__scene = scene;
}

function wireUI() {
  const vb = document.getElementById("views");
  for (const [id, v] of Object.entries(VIEWS)) {
    const b = document.createElement("button"); b.className = "chip"; b.dataset.view = id; b.textContent = v.label; b.onclick = () => setView(id); vb.appendChild(b);
  }
  const hour = document.getElementById("hour"), out = document.getElementById("hourOut");
  const fmt = h => `${String(Math.floor(h)).padStart(2, "0")}:${String(Math.round((h % 1) * 60)).padStart(2, "0")}`;
  hour.value = STATE.hour; out.textContent = fmt(STATE.hour);
  let pend = null;
  hour.addEventListener("input", () => { STATE.hour = parseFloat(hour.value); out.textContent = fmt(STATE.hour); clearTimeout(pend); pend = setTimeout(updateSun, 60); });
  document.getElementById("aoToggle").onchange = e => { STATE.ao = e.target.checked; STATE.dirty = true; };
  document.getElementById("panelToggle").onclick = () => document.getElementById("panel").classList.toggle("folded");
}

main().catch(e => { document.getElementById("loadStatus").textContent = "Something went wrong: " + e.message; console.error(e); });
