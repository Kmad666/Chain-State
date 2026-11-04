// ============================================================== scene, light, viewer
const NO_SHADOW_CAST = new Set(["glass", "shopGlass", "curtain", "paint", "rail", "groove", "gully", "manhole", "joint",
  "mosaicHouse", "mosaicCurb", "mosaicField", "slabs", "setts", "asphalt", "courtyard", "distantGround", "interior",
  "shopInterior", "ghost", "gravel", "lampGlass", "wire", "glassLit", "glassLit2", "lightPool",
  "tag0", "tag1", "tag2", "tag3", "tag4", "tag5", "tag6", "tag7", "plate", "tramDisplay"]);

let renderer, scene, camera, controls, composer, gtao, sky, sun, pmrem, envRT, lampLight;
const STATE = { hour: 18.25, ao: true, grime: true, mode: "orbit", yaw: 0, pitch: 0, keys: {}, dirty: true };

function extraMaterials() {
  const std = (o) => new THREE.MeshStandardMaterial(o);
  const posters = posterTexture(7); posters.wrapS = THREE.RepeatWrapping;
  MAT.posters = std({ map: posters, roughness: 0.75 });
  const hoard = posterTexture(19); hoard.wrapS = THREE.RepeatWrapping;
  MAT.hoarding = std({ map: hoard, roughness: 0.8 });
  MAT.wire = std({ color: "#232323", roughness: 0.6, metalness: 0.5 });
  MAT.binOrange = std({ color: "#e0641b", roughness: 0.55 });
  const pc = canvas(128, 128), px = pc.getContext("2d");
  const pg = px.createRadialGradient(64, 64, 0, 64, 64, 64);
  pg.addColorStop(0, "rgba(255,190,110,0.55)"); pg.addColorStop(0.35, "rgba(255,170,90,0.22)"); pg.addColorStop(1, "rgba(255,160,80,0)");
  px.fillStyle = pg; px.fillRect(0, 0, 128, 128);
  MAT.lightPool = new THREE.MeshBasicMaterial({ map: toTex(pc, true, false), transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, opacity: 0, polygonOffset: true, polygonOffsetFactor: -2 });
  const sc = canvas(256, 256), sx = sc.getContext("2d");
  sx.fillStyle = "#f2c500"; sx.beginPath(); sx.arc(128, 128, 126, 0, 7); sx.fill();
  sx.strokeStyle = "#1d7a3a"; sx.lineWidth = 10; sx.beginPath(); sx.arc(128, 128, 112, 0, 7); sx.stroke();
  sx.fillStyle = "#1d7a3a"; sx.font = "bold 150px Arial, sans-serif"; sx.textAlign = "center"; sx.textBaseline = "middle"; sx.fillText("H", 128, 136);
  MAT.stopSign = std({ map: toTex(sc, true, false), roughness: 0.5 });
  MAT.gravel = texMat("asphalt", "#8f8578", { roughness: 1 });
  MAT.birch = std({ color: "#ddd8cc", roughness: 0.8 });
  MAT.leaves = std({ color: "#5e7a3a", roughness: 0.9, flatShading: true });
  const ghost = signTexture("KETTENWERK SEIFEN", { ...SIGN_STYLES.ghost });
  MAT.ghost = std({ map: ghost, transparent: true, depthWrite: false, roughness: 1, polygonOffset: true, polygonOffsetFactor: -4 });
  const dist = (c) => std({ map: TEX.distantFacade.map, color: c, roughness: 0.95 });
  MAT.distA = dist("#f2ece0"); MAT.distB = dist("#e9d6b4"); MAT.distC = dist("#d5d9d6");
  MAT.distD = dist("#e6cdb8"); MAT.distE = dist("#d9cfa8"); MAT.distF = dist("#c9cdc0");
  MAT.distantRoof = std({ color: "#5c4f47", roughness: 0.9 });
}

function meshFor(key, geo) {
  let mat = MAT[key];
  if (!mat && key.startsWith("sign:")) {
    const [text, style] = key.slice(5).split("|");
    mat = signMat(text, SIGN_STYLES[style] || {});
  }
  if (!mat) { console.warn("no material", key); mat = MAT.frame; }
  const m = new THREE.Mesh(geo, mat);
  m.castShadow = !NO_SHADOW_CAST.has(key) && !key.startsWith("sign:");
  m.receiveShadow = true;
  m.name = key;
  return m;
}

function addBucket(bucket, parent) {
  for (const [k, g] of bucket.merge()) parent.add(meshFor(k, g));
}

// ---------------------------------------------------------------- sun and sky
function sunDir(hour) {
  // a late-summer day in Berlin: sunrise in the east-north-east, high in the south at noon
  const t = (hour - 5.5) / 15;
  const el = THREE.MathUtils.degToRad(Math.max(-4, 52 * Math.sin(Math.PI * t)));
  const az = THREE.MathUtils.degToRad(70 + 220 * t);   // from north, clockwise
  // north is -z, east is +x
  return new THREE.Vector3(Math.sin(az) * Math.cos(el), Math.sin(el), -Math.cos(az) * Math.cos(el));
}

function updateSun() {
  const d = sunDir(STATE.hour);
  const u = sky.material.uniforms;
  u.sunPosition.value.copy(d);
  const el = Math.asin(d.y) * 180 / Math.PI;
  sun.position.copy(d).multiplyScalar(220);
  sun.target.position.set(0, 0, 0);
  const warm = THREE.MathUtils.clamp(1 - el / 35, 0, 1);
  sun.color.set(new THREE.Color("#fff3e2").lerp(new THREE.Color("#ffb46a"), warm * 0.85));
  sun.intensity = 4.2 * THREE.MathUtils.smoothstep(el, -2, 8);
  // the environment (sky light and reflections) follows the sky
  if (envRT) envRT.dispose();
  const skyScene = new THREE.Scene(); const s2 = new Sky(); s2.scale.setScalar(1000);
  Object.assign(s2.material.uniforms.turbidity, { value: u.turbidity.value });
  for (const k of ["turbidity", "rayleigh", "mieCoefficient", "mieDirectionalG"]) s2.material.uniforms[k].value = u[k].value;
  s2.material.uniforms.sunPosition.value.copy(d);
  skyScene.add(s2);
  envRT = pmrem.fromScene(skyScene, 0, 0.1, 2000);
  scene.environment = envRT.texture;
  // haze colour and lamp glow
  const fogDay = new THREE.Color("#b7c6d6"), fogEve = new THREE.Color("#d9b48f"), fogNight = new THREE.Color("#2c3444");
  const night = THREE.MathUtils.clamp(1 - (el + 3) / 8, 0, 1);
  scene.fog.color.copy(fogDay).lerp(fogEve, warm * 0.7).lerp(fogNight, night);
  MAT.lampGlass.emissiveIntensity = 4 * night + 0.15 * warm;
  if (MAT.tramGlass) { MAT.tramGlass.emissive = new THREE.Color("#fff1d6"); MAT.tramGlass.emissiveIntensity = 0.8 * night; }
  MAT.shopInterior.emissiveIntensity = 0.4 + 2.2 * night;
  MAT.glassLit.emissiveIntensity = 1.3 * night; MAT.glassLit2.emissiveIntensity = 0.9 * night;
  MAT.lightPool.opacity = 0.85 * night; MAT.lightPool.visible = night > 0.02;
  if (MAT.clouds) MAT.clouds.color.set(new THREE.Color("#ffffff").lerp(new THREE.Color("#ffc890"), warm * 0.6).lerp(new THREE.Color("#3a3f4c"), night));
  renderer.toneMappingExposure = 0.78 + 0.25 * night;
  lampLight.intensity = 0.35 * night;
  STATE.dirty = true;
}

// ---------------------------------------------------------------- views
const VIEWS = {
  corner: { label: "Corner", walk: true, pos: [-9.2, 1.7, -10.8], look: [14, 13.5, 16] },
  streetA: { label: STREET_A, walk: true, pos: [58, 1.7, -10.4], look: [-30, 7, 2] },
  streetB: { label: STREET_B, walk: true, pos: [-9.6, 1.7, 61], look: [1, 7, -30] },
  facade: { label: "A facade", walk: true, pos: [-30, 1.7, 9.4], look: [-34, 11, 13] },
  aerial: { label: "Aerial", walk: false, pos: [104, 52, 30], look: [-6, 2, -2] },
  roofs: { label: "Rooftops", walk: false, pos: [38, 34, -42], look: [8, 18, 6] },
  grey: { label: "Unrenovated", walk: true, pos: [9.2, 1.7, -14.2], look: [-12, 9.5, -27] },
  gap: { label: "Vacant lot", walk: true, pos: [-56, 1.7, -10.6], look: [-60, 9, 14] },
  courtyard: { label: "Courtyard", walk: true, pos: [70, 1.7, 70], look: [40, 10, 34] },
};

function setView(id) {
  const v = VIEWS[id];
  camera.position.set(...v.pos);
  const look = new THREE.Vector3(...v.look);
  if (v.walk) {
    STATE.mode = "walk"; controls.enabled = false;
    const d = look.clone().sub(camera.position);
    STATE.yaw = Math.atan2(-d.x, -d.z);
    STATE.pitch = Math.atan2(d.y, Math.hypot(d.x, d.z));
    applyLook();
  } else {
    STATE.mode = "orbit"; controls.enabled = true;
    controls.target.copy(look); controls.update();
  }
  document.querySelectorAll("[data-view]").forEach(b => b.setAttribute("aria-pressed", String(b.dataset.view === id)));
  document.getElementById("modeHint").textContent = v.walk
    ? "Walking: drag to look · W A S D to walk · Shift to hurry"
    : "Orbit: drag to turn · right-drag to pan · wheel to zoom";
  STATE.dirty = true;
}
function applyLook() {
  camera.rotation.set(0, 0, 0, "YXZ");
  camera.rotation.order = "YXZ";
  camera.rotation.y = STATE.yaw; camera.rotation.x = STATE.pitch;
}

// ---------------------------------------------------------------- main
async function main() {
  const status = document.getElementById("loadStatus"), bar = document.getElementById("loadBar");
  const tick = (text, f) => new Promise(res => { status.textContent = text; bar.style.width = (f * 100).toFixed(0) + "%"; setTimeout(res, 0); });

  renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: "high-performance" });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
  renderer.setSize(innerWidth, innerHeight);
  renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 0.65;
  document.getElementById("view").appendChild(renderer.domElement);

  scene = new THREE.Scene();
  scene.fog = new THREE.FogExp2(0xb7c6d6, 0.0024);
  camera = new THREE.PerspectiveCamera(55, innerWidth / innerHeight, 0.1, 4000);
  pmrem = new THREE.PMREMGenerator(renderer);

  // textures
  const steps = buildTextures();
  for (let i = 0; i < steps.length; i++) { await tick(`Painting ${steps[i][0]}…`, 0.05 + 0.3 * i / steps.length); steps[i][1](); }
  streetDetailTextures();
  buildSharedMaterials(); streetMaterials(); extraMaterials(); tagMaterials();

  // streets
  await tick("Laying the setts and the pavements…", 0.38);
  const streets = new THREE.Group(); streets.name = "streets";
  addBucket(buildStreets(), streets); scene.add(streets);

  // houses
  resetShops();
  const { jobs } = buildDistrict(scene);
  const houses = new THREE.Group(); houses.name = "houses";
  const gapB = new Bucket();
  for (let i = 0; i < jobs.length; i++) {
    const j = jobs[i];
    await tick(`Building ${j.gap ? "the vacant lot" : (j.segments.length > 1 ? "a corner house" : "house " + (i + 1))} of ${jobs.length}…`, 0.4 + 0.45 * i / jobs.length);
    if (j.gap) { buildGap(j, gapB); continue; }
    const b = new Building(j);
    houses.add(b.build());
  }
  addBucket(gapB, houses);
  await tick("Street signs, lanterns and wires…", 0.87);
  const props = buildProps();
  for (const j of jobs) {
    if (!j.corner) continue;
    const [sx, sz] = j.corner;
    streetSign(props, STREET_A, sx * (D.bFront + D.chamfer + 1.4), 3.25, sz * D.aFront, new THREE.Vector3(-sz, 0, 0));
    streetSign(props, STREET_B, sx * D.bFront, 3.25, sz * (D.aFront + D.chamfer + 1.4), new THREE.Vector3(0, 0, sx));
  }
  const propsG = new THREE.Group(); propsG.name = "furniture"; addBucket(props, propsG); scene.add(propsG);
  await tick("Parking the cars…", 0.89);
  const cars = new THREE.Group(); cars.name = "cars"; addBucket(buildCars(), cars); scene.add(cars);
  const tb = new THREE.Group(); tb.name = "tram"; addBucket(buildTramAndBikes(), tb); scene.add(tb);
  await tick("Planting the lindens…", 0.9);
  const trees = new THREE.Group(); trees.name = "trees"; addBucket(buildTrees(), trees); scene.add(trees);
  const shared = new THREE.Group(); shared.name = "shared"; addBucket(SHARED, shared); houses.add(shared);
  scene.add(houses);
  await tick("The rest of the city…", 0.93);
  const sur = new THREE.Group(); sur.name = "surroundings"; addBucket(buildSurroundings(), sur);
  sur.traverse(o => { if (o.isMesh) o.castShadow = false; });
  scene.add(sur);

  // sky, sun
  sky = new Sky(); sky.scale.setScalar(10000);
  Object.assign(sky.material.uniforms.turbidity, { value: 3.2 });
  sky.material.uniforms.rayleigh.value = 1.4;
  sky.material.uniforms.mieCoefficient.value = 0.005;
  sky.material.uniforms.mieDirectionalG.value = 0.82;
  scene.add(sky);
  // a thin layer of fair-weather cumulus far overhead
  {
    const N = 1024, f = makeFbm(909, 4, 6, 0.55), g = makeFbm(919, 16, 3, 0.5);
    const cc = paint(canvas(N, N), (u, v) => {
      const k = f(u, v) * 0.75 + g(u, v) * 0.25;
      const a = clamp01((k - 0.52) * 3.2);
      const shade = 235 - 50 * clamp01((k - 0.6) * 2);
      return [shade, shade, shade + 6, a * 220];
    });
    const ct = toTex(cc, true, true); ct.repeat.set(3, 3);
    const clouds = new THREE.Mesh(new THREE.PlaneGeometry(9000, 9000), new THREE.MeshBasicMaterial({ map: ct, transparent: true, depthWrite: false, fog: false, opacity: 0.85 }));
    clouds.rotation.x = Math.PI / 2; clouds.position.y = 900; clouds.name = "clouds";
    scene.add(clouds);
    MAT.clouds = clouds.material;
  }
  sun = new THREE.DirectionalLight(0xffffff, 3);
  sun.castShadow = true;
  sun.shadow.mapSize.set(4096, 4096);
  const sc = sun.shadow.camera; sc.left = -125; sc.right = 125; sc.top = 125; sc.bottom = -125; sc.near = 10; sc.far = 600;
  sun.shadow.bias = -0.0003; sun.shadow.normalBias = 0.04;
  scene.add(sun, sun.target);
  lampLight = new THREE.HemisphereLight(0xffc98a, 0x1a1a22, 0);    // a warm wash at night from the lanterns
  scene.add(lampLight);

  // post: ambient occlusion
  composer = new EffectComposer(renderer);
  composer.addPass(new RenderPass(scene, camera));
  gtao = new GTAOPass(scene, camera, innerWidth, innerHeight);
  gtao.output = GTAOPass.OUTPUT.Default;
  gtao.blendIntensity = 0.85;
  gtao.updateGtaoMaterial({ radius: 0.6, distanceExponent: 1.5, thickness: 1, scale: 1, samples: 12 });
  // GTAO draws its own depth/normal pass without alpha cut-outs: leave out anything
  // cut out of a texture (leaves, railings, tags) and the sky, or they'd darken as solid cards
  const NO_AO = new Set(["leafCards", "railScroll", "railNouveau", "ghost", "lightPool", "curtain",
    "tag0", "tag1", "tag2", "tag3", "tag4", "tag5", "tag6", "tag7"]);
  scene.traverse(o => { if (o.isMesh && NO_AO.has(o.name)) o.userData.noAO = true; });
  sky.userData.noAO = true;
  scene.getObjectByName("clouds").userData.noAO = true;
  gtao.overrideVisibility = function () {
    const cache = this._visibilityCache;
    this.scene.traverse(o => { cache.set(o, o.visible); if (o.isPoints || o.isLine || o.userData.noAO) o.visible = false; });
  };
  composer.addPass(gtao);
  composer.addPass(new OutputPass());

  controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true; controls.maxPolarAngle = Math.PI * 0.495; controls.maxDistance = 700; controls.minDistance = 2;
  controls.addEventListener("change", () => STATE.dirty = true);

  scene.traverse(o => {
    if (!o.isMesh) return;
    const m = o.material;
    if (m.envMapIntensity !== undefined && m !== MAT.glass && m !== MAT.glassLit && m !== MAT.glassLit2 && m !== MAT.shopGlass && m !== MAT.rail && m !== MAT.steel && m !== MAT.gold) m.envMapIntensity = 0.22;
  });
  updateSun();
  wireUI();
  setView(new URLSearchParams(location.search).get("view") || "corner");
  await tick("Ready", 1);
  document.getElementById("loading").hidden = true;
  stats();
  let last = performance.now();
  const loop = (now) => {
    const dt = Math.min(0.1, (now - last) / 1000); last = now;
    if (STATE.mode === "walk") walk(dt); else controls.update();
    if (STATE.dirty || STATE.mode === "walk" && anyKey()) {
      if (STATE.ao) composer.render(); else renderer.render(scene, camera);
      STATE.dirty = false;
    }
    requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);
  window.__scene = scene;
  window.__ready = true;
}

function anyKey() { return Object.values(STATE.keys).some(Boolean); }
function walk(dt) {
  const k = STATE.keys, sp = (k.shift ? 9 : 3.2) * dt;
  const f = new THREE.Vector3(-Math.sin(STATE.yaw), 0, -Math.cos(STATE.yaw)), r = new THREE.Vector3(-f.z, 0, f.x);
  const m = new THREE.Vector3();
  if (k.w || k.arrowup) m.add(f); if (k.s || k.arrowdown) m.sub(f);
  if (k.d || k.arrowright) m.add(r); if (k.a || k.arrowleft) m.sub(r);
  if (k.q) camera.position.y -= sp; if (k.e) camera.position.y += sp;
  if (m.lengthSq() > 0) { camera.position.addScaledVector(m.normalize(), sp); STATE.dirty = true; }
}

function stats() {
  let tris = 0, meshes = 0;
  scene.traverse(o => { if (o.isMesh) { meshes++; tris += (o.geometry.index ? o.geometry.index.count : o.geometry.attributes.position.count) / 3; } });
  document.getElementById("stats").textContent = `${(tris / 1e6).toFixed(2)} M triangles · ${meshes} meshes`;
}

// ---------------------------------------------------------------- UI
function wireUI() {
  const el = renderer.domElement;
  let drag = null;
  el.addEventListener("pointerdown", e => { if (STATE.mode === "walk") { drag = { x: e.clientX, y: e.clientY }; el.setPointerCapture(e.pointerId); } });
  el.addEventListener("pointermove", e => {
    if (!drag) return;
    STATE.yaw += (e.clientX - drag.x) * 0.004; STATE.pitch += (e.clientY - drag.y) * 0.004;
    STATE.pitch = THREE.MathUtils.clamp(STATE.pitch, -1.45, 1.45);
    drag = { x: e.clientX, y: e.clientY }; applyLook(); STATE.dirty = true;
  });
  el.addEventListener("pointerup", () => drag = null);
  addEventListener("keydown", e => { if (e.target.tagName === "INPUT") return; STATE.keys[e.key.toLowerCase()] = true; if (e.key === "Shift") STATE.keys.shift = true; });
  addEventListener("keyup", e => { STATE.keys[e.key.toLowerCase()] = false; if (e.key === "Shift") STATE.keys.shift = false; });
  addEventListener("resize", () => {
    camera.aspect = innerWidth / innerHeight; camera.updateProjectionMatrix();
    renderer.setSize(innerWidth, innerHeight); composer.setSize(innerWidth, innerHeight); STATE.dirty = true;
  });
  const vb = document.getElementById("views");
  for (const [id, v] of Object.entries(VIEWS)) {
    const b = document.createElement("button"); b.className = "chip"; b.dataset.view = id; b.textContent = v.label;
    b.onclick = () => setView(id); vb.appendChild(b);
  }
  const hour = document.getElementById("hour"), hourOut = document.getElementById("hourOut");
  const fmt = h => `${String(Math.floor(h)).padStart(2, "0")}:${String(Math.round((h % 1) * 60)).padStart(2, "0")}`;
  hour.value = STATE.hour; hourOut.textContent = fmt(STATE.hour);
  let pend = null;
  hour.addEventListener("input", () => {
    STATE.hour = parseFloat(hour.value); hourOut.textContent = fmt(STATE.hour);
    clearTimeout(pend); pend = setTimeout(updateSun, 60);
  });
  document.getElementById("aoToggle").onchange = e => { STATE.ao = e.target.checked; STATE.dirty = true; };
  document.getElementById("grimeToggle").onchange = e => { setGrime(e.target.checked); STATE.dirty = true; };
  document.getElementById("exportBtn").onclick = exportGLB;
  document.getElementById("panelToggle").onclick = () => {
    const p = document.getElementById("panel"); p.classList.toggle("folded");
    document.getElementById("panelToggle").setAttribute("aria-expanded", String(!p.classList.contains("folded")));
  };
}

async function exportGLB() {
  const btn = document.getElementById("exportBtn"), note = document.getElementById("exportNote");
  btn.disabled = true; note.textContent = "Packing the district…";
  try {
    const root = new THREE.Group();
    for (const name of ["streets", "houses", "furniture", "cars", "trees", "tram"]) {
      const g = scene.getObjectByName(name); if (g) root.add(g.clone(true));
    }
    // index the geometry (shared corners) so the file is a fraction of the size
    root.traverse(o => { if (o.isMesh) { o.geometry = mergeVertices(o.geometry, 1e-4); } });
    root.updateMatrixWorld(true);
    const buf = await new GLTFExporter().parseAsync(root, { binary: true, maxTextureSize: 2048 });
    const dl = window.claude ? await window.claude.use("downloads") : null;
    if (!dl) { note.textContent = "Saving files works when this page is open in Claude."; return; }
    await dl.save({ filename: "kettenkiez-berlin.glb", data: new Blob([buf], { type: "model/gltf-binary" }) });
    note.textContent = "Saved kettenkiez-berlin.glb";
  } catch (e) {
    note.textContent = "Couldn't save: " + (e?.message || e);
  } finally { btn.disabled = false; }
}

main().catch(e => { document.getElementById("loadStatus").textContent = "Something went wrong: " + e.message; console.error(e); });
