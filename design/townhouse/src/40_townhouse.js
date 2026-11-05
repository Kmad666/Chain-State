// ============================================================== the townhouse
// From the design sheet: a 5-storey limestone townhouse on a 14 m x 10 m corner plot,
// a café on the ground floor behind a green painted shopfront, residences above, an
// attic in a slate mansard with stone dormers, four brick chimney stacks.
// Storey heights from the sheet's section: 1F 4.0, 2F 3.4, 3F 3.2, 4F 3.0, 5F 3.0, attic 2.6.

const TH = {
  W: 14, Dp: 10,
  floors: [ { k: "1F", y0: 0, h: 4.0 }, { k: "2F", y0: 4.0, h: 3.4 }, { k: "3F", y0: 7.4, h: 3.2 },
            { k: "4F", y0: 10.6, h: 3.0 }, { k: "5F", y0: 13.6, h: 3.0 } ],
  wallTop: 16.6,            // top of the 5F wall, where the main cornice starts
  cornice: 0.95,
  get eave() { return this.wallTop + this.cornice; },
  mansardRise: 3.7, mansardRun: 1.0, hipRise: 1.3,
};

// facade frames: origin at the facade's left end (seen from outside), running along `a`
const FACADES = {
  front: { o: [0, 0, 0], a: [1, 0, 0], w: 14, axes: [2.15, 5.45, 8.55, 11.85] },
  right: { o: [14, 0, 0], a: [0, 0, -1], w: 10, axes: [3.0, 7.0] },
  rear:  { o: [14, 0, -10], a: [-1, 0, 0], w: 14, axes: [2.15, 5.45, 8.55, 11.85] },
  left:  { o: [0, 0, -10], a: [0, 0, 1], w: 10, axes: [3.0, 7.0] },
};

// window sizes and ornament by floor: [width, height, sill above floor, hood type, flower box]
const WIN = {
  "2F": [1.5, 2.35, 0.75, "seg", true],
  "3F": [1.45, 2.2, 0.72, "tri", true],
  "4F": [1.4, 2.05, 0.7, "flat", false],
  "5F": [1.35, 1.95, 0.68, "key", false],
};

function townhouseMaterials() {
  const ashlar = (c) => texMat("ashlar", c, { roughness: 0.9, normal: 0.9 });
  MAT.stone = texMat("stone", "#f6e6c4", { roughness: 0.85 });
  MAT.awningGreenPlain = new THREE.MeshStandardMaterial({ color: "#3e6b52", roughness: 0.85, side: THREE.DoubleSide });
  MAT.trimGreen = new THREE.MeshStandardMaterial({ color: "#2d5443", roughness: 0.45 });
  MAT.trimGreenDark = new THREE.MeshStandardMaterial({ color: "#21402f", roughness: 0.5 });
  MAT.pot = new THREE.MeshStandardMaterial({ color: "#a35a3a", roughness: 0.8 });
  MAT.shopWarm = new THREE.MeshStandardMaterial({ color: "#5a3e26", roughness: 0.8, emissive: new THREE.Color("#ffa94d"), emissiveIntensity: 1.6 });
  MAT.shopGlassWarm = new THREE.MeshStandardMaterial({ color: "#2c2a22", roughness: 0.05, transparent: true, opacity: 0.32, depthWrite: false, envMapIntensity: 0.8 });
  MAT.lampWarm = new THREE.MeshStandardMaterial({ color: "#fff1c9", emissive: new THREE.Color("#ffc36a"), emissiveIntensity: 2.2 });
  MAT.awningStripe = new THREE.MeshStandardMaterial({ map: stripeTexture(), roughness: 0.85, side: THREE.DoubleSide });
  MAT.flowersRed = new THREE.MeshStandardMaterial({ color: "#c2463c", roughness: 0.8, flatShading: true });
  MAT.flowersPink = new THREE.MeshStandardMaterial({ color: "#d77a8c", roughness: 0.8, flatShading: true });
  MAT.leavesBox = new THREE.MeshStandardMaterial({ color: "#4f6f32", roughness: 0.9, flatShading: true });
  MAT.signBoard = new THREE.MeshStandardMaterial({ map: teapotSign(), roughness: 0.6 });
  MAT.fascia = new THREE.MeshStandardMaterial({ map: fasciaTexture(), roughness: 0.5 });
  return { ashlar };
}

function stripeTexture() {
  const c = canvas(256, 64), x = c.getContext("2d");
  for (let i = 0; i < 8; i++) { x.fillStyle = i % 2 ? "#2f5d48" : "#e6dcc2"; x.fillRect(i * 32, 0, 32, 64); }
  const t = toTex(c); return t;
}
function teapotSign() {
  const c = canvas(256, 256), x = c.getContext("2d");
  x.fillStyle = "#1f2b24"; x.fillRect(0, 0, 256, 256);
  x.strokeStyle = "#c9a24a"; x.lineWidth = 8; x.strokeRect(10, 10, 236, 236);
  x.fillStyle = "#e9dcc0";
  x.beginPath(); x.ellipse(128, 150, 62, 50, 0, 0, 7); x.fill();                    // pot
  x.fillRect(100, 88, 56, 16); x.beginPath(); x.arc(128, 82, 10, 0, 7); x.fill();      // lid
  x.beginPath(); x.moveTo(186, 135); x.quadraticCurveTo(225, 110, 222, 92); x.lineTo(212, 96); x.quadraticCurveTo(210, 118, 184, 128); x.fill(); // spout
  x.lineWidth = 12; x.strokeStyle = "#e9dcc0"; x.beginPath(); x.arc(62, 150, 26, Math.PI * 0.5, Math.PI * 1.5); x.stroke();      // handle
  return toTex(c, true, false);
}
function fasciaTexture() {
  const c = canvas(2048, 128), x = c.getContext("2d");
  x.fillStyle = "#2d5443"; x.fillRect(0, 0, 2048, 128);
  x.strokeStyle = "#c9a24a"; x.lineWidth = 4; x.strokeRect(10, 10, 2028, 108);
  x.fillStyle = "#d9b45a"; x.font = "italic 600 70px Georgia, 'Times New Roman', serif"; x.textAlign = "center"; x.textBaseline = "middle";
  x.fillText("The Copper Kettle  ·  Tea Room & Café", 1024, 68);
  return toTex(c, true, false);
}

// ------------------------------------------------------------------ one facade
function buildFacade(name, group, mats, rng) {
  const F = FACADES[name];
  const origin = new THREE.Vector3(...F.o), a = new THREE.Vector3(...F.a);
  const M = facadeMatrix(origin, a);
  const B = new Bucket();
  const W = F.w;
  const isFront = name === "front", isRight = name === "right";
  const openings = [];
  const windows = [];

  // ---- upper floors
  for (const f of TH.floors.slice(1)) {
    const [ww, wh, sill, hood, box] = WIN[f.k];
    for (const x of F.axes) {
      const o = { x: x - ww / 2, y: f.y0 + sill, w: ww, h: wh, depth: 0.28, kind: "window", floor: f, hood, box };
      openings.push(o); windows.push(o);
    }
  }
  // ---- ground floor
  const ground = [];
  let shopArea = null;
  if (isFront) {
    shopArea = { x0: 0.75, x1: W - 0.75 };   // the green shopfront between the corner piers
  } else if (isRight) {
    ground.push({ x: F.axes[0] - 1.0, y: 0.15, w: 2.0, h: 3.3, arch: "round", depth: 0.3, kind: "shoparch" });
    ground.push({ x: F.axes[1] - 0.75, y: 0.0, w: 1.5, h: 2.9, arch: "round", depth: 0.35, kind: "door" });
  } else if (name === "rear") {
    ground.push({ x: W / 2 - 0.6, y: 0.0, w: 1.2, h: 2.4, depth: 0.3, kind: "backdoor" });
    for (const x of [F.axes[0], F.axes[3]]) ground.push({ x: x - 0.6, y: 1.2, w: 1.2, h: 1.9, depth: 0.28, kind: "window" });
  } else {
    for (const x of F.axes) ground.push({ x: x - 0.6, y: 1.1, w: 1.2, h: 2.1, arch: "seg", depth: 0.28, kind: "window" });
  }
  const holes = [...openings, ...ground];
  if (shopArea) holes.push({ x: shopArea.x0, y: 0, w: shopArea.x1 - shopArea.x0, h: 4.05, depth: 0.0, kind: "shop" });
  const [wf, wr] = wallWithOpenings(0, 0, W, TH.wallTop, holes.filter(o => o.kind !== "shop"));
  // the shop hole: cut it out of the wall separately (no reveal, the shopfront fills it)
  if (shopArea) {
    const [wf2] = wallWithOpenings(0, 0, W, TH.wallTop, holes);
    addUV(B, "ashlar", wf2, null, [4, 2.7]);
  } else addUV(B, "ashlar", wf, null, [4, 2.7]);
  addUV(B, "ashlar", wr, null, [4, 2.7]);

  // ---- windows with surrounds and hoods
  for (const o of windows) {
    windowUnit(B, o, rng, { frameKey: "frameCream", bars: true, curtainChance: 0.18 });
    frameAround(B, "stone", o, 0.21, true);
    const headY = o.y + o.h + 0.18;
    // hoods a little wider than the surround so they read from across the street
    const ho = { ...o, x: o.x - 0.12, w: o.w + 0.24 };
    if (o.hood === "seg") pediment(B, "stone", ho, "seg", headY + 0.04);
    else if (o.hood === "tri") pediment(B, "stone", ho, "tri", headY + 0.04);
    else if (o.hood === "flat") pediment(B, "stone", ho, "flat", headY + 0.04);
    else { keystone(B, "stone", o); B.add("stone", sweep(PROFILE.cap(0.7), straight(o.x - 0.3, o.x + o.w + 0.3, headY + 0.1))); }
    if (o.box && (isFront || rng.chance(0.6))) flowerBox(B, o, rng);
  }

  // ---- string courses, corner quoins, main cornice
  const runs = [[0, W]];
  const band = (prof, y) => B.add("stone", sweep(prof, straight(-0.02, W + 0.02, y)));
  band(PROFILE.belt(1.15), 4.0);                         // over the shop
  for (const f of TH.floors.slice(2)) band(PROFILE.belt(0.7), f.y0 - 0.05);   // floor bands
  for (const f of TH.floors.slice(1)) band(PROFILE.sill(0.85), f.y0 + WIN[f.k][2] - 0.13);  // sill courses run under every window
  band(PROFILE.main(TH.cornice), TH.wallTop);
  for (let x = 0.3; x < W - 0.15; x += 0.55) B.add("stone", consoleGeo(x, TH.wallTop + 0.06, 0.14, 0.36, 0.55));
  dentils(B, "stone", 0, W, TH.wallTop - 0.22, 0.12, 0.08, 0.17, 0.09);
  // quoins: alternating long and short blocks up both corners, from the ground floor
  for (const xe of [0, 1]) {
    for (let y = 0.0, k = 0; y < TH.wallTop - 0.3; y += 0.45, k++) {
      const w = k % 2 ? 0.55 : 0.85;
      B.add("stone", boxGeo(xe ? W - w : 0, y + 0.02, 0, w, 0.41, 0.07));
    }
  }

  if (name === "rear") for (const bx of [W / 2 - 1.6, W / 2 + 1.4]) {
    const barrel = new THREE.LatheGeometry([[0, 0], [0.26, 0], [0.31, 0.2], [0.33, 0.4], [0.31, 0.6], [0.26, 0.8], [0, 0.8]].map(p => new THREE.Vector2(p[0], p[1])), 14);
    barrel.translate(bx, 0, 0.6); B.add("doorWood", barrel.toNonIndexed());
    for (const hy of [0.12, 0.68]) { const hoop = new THREE.TorusGeometry(0.3, 0.015, 4, 16); hoop.rotateX(Math.PI / 2); hoop.translate(bx, hy, 0.6); B.add("iron", hoop.toNonIndexed()); }
  }

  // ---- ground floor fillings
  if (isFront) shopfront(B, shopArea, rng);
  for (const o of ground) groundOpening(B, o, rng);

  // ---- materials (lightly weathered) and meshes
  const grime = { map: grimeTexture({ width: W, height: TH.eave + 4, windows: windows.map(o => ({ x: o.x, y: o.y, w: o.w })), ledges: [4.3, TH.wallTop], cond: 0.2 }, rng),
    origin: origin.clone(), along: a.clone(), width: W, height: TH.eave + 4 };
  const fm = {
    ashlar: patchGrime(mats.ashlar("#f3d9a8"), grime, false),
    stone: patchGrime(texMat("stone", "#fff3dc", { roughness: 0.85 }), grime, false),
  };
  for (const [k, geo] of B.merge()) {
    const m = new THREE.Mesh(geo, fm[k] || MAT[k] || signMat(k));
    m.matrixAutoUpdate = false; m.matrix.copy(M);
    m.castShadow = !["glass", "glassLit", "glassLit2", "shopGlassWarm", "curtain"].includes(k); m.receiveShadow = true;
    m.name = k;
    group.add(m);
  }
  return { M, F };
}

// the café front: green painted pilasters and fascia, four round-headed openings
// (three windows with fan glazing, one glazed door), lamps on the pilasters
function shopfront(B, area, rng) {
  const x0 = area.x0, x1 = area.x1, z = 0.14, top = 4.0;
  const n = 4, bay = (x1 - x0) / n;
  const ops = [];
  for (let i = 0; i < n; i++) {
    const cx = x0 + bay * (i + 0.5), w = bay - 0.75;
    ops.push({ x: cx - w / 2, y: i === 2 ? 0.0 : 0.55, w, h: i === 2 ? 3.15 : 2.6, arch: "round", depth: 0.25, kind: i === 2 ? "door" : "win" });
  }
  // panel with arched holes
  const [pf, pr] = wallWithOpenings(x0, 0, x1, top - 0.6, ops, z);
  B.add("trimGreen", pf); B.add("trimGreen", pr);
  // stall riser under the windows, and the fascia board with the café's name
  B.add("trimGreenDark", boxGeo(x0, 0, z, x1 - x0, 0.55, 0.06));
  const fascia = new THREE.PlaneGeometry(x1 - x0 - 0.2, 0.52); fascia.translate((x0 + x1) / 2, top - 0.32, z + 0.13); B.add("fascia", fascia);
  B.add("trimGreen", boxGeo(x0 - 0.05, top - 0.62, z, x1 - x0 + 0.1, 0.62, 0.12));
  B.add("trimGreenDark", sweep(PROFILE.cap(0.9), straight(x0 - 0.1, x1 + 0.1, top - 0.05)).translate(0, 0, z));
  // pilasters between the bays, with small capitals
  for (let i = 0; i <= n; i++) {
    const px = x0 + bay * i;
    B.add("trimGreen", boxGeo(px - 0.17, 0, z, 0.34, top - 0.62, 0.12));
    B.add("trimGreenDark", boxGeo(px - 0.22, top - 0.82, z, 0.44, 0.2, 0.18));
    B.add("trimGreenDark", boxGeo(px - 0.22, 0, z, 0.44, 0.3, 0.18));
    if (i > 0 && i < n) {   // brass lamps on the inner pilasters
      B.add("iron", boxGeo(px - 0.02, 2.85, z + 0.12, 0.04, 0.04, 0.3));
      const l = new THREE.CylinderGeometry(0.1, 0.07, 0.3, 8); l.translate(px, 2.75, z + 0.42); B.add("lampWarm", l.toNonIndexed());
      const cap = new THREE.ConeGeometry(0.14, 0.12, 8); cap.translate(px, 2.96, z + 0.42); B.add("iron", cap.toNonIndexed());
    }
  }
  // glazing: fan bars in the round heads, a grid below, a warm lit interior behind
  for (const o of ops) {
    const zg = z - 0.12, spring = o.y + o.h - o.w / 2, cx = o.x + o.w / 2;
    const gl = new THREE.Shape(openingOutline(o).map(p => new THREE.Vector2(p[0], p[1])));
    const g = new THREE.ShapeGeometry(gl, 8); g.translate(0, 0, zg); B.add("shopGlassWarm", g.toNonIndexed());
    for (let k = 1; k < 6; k++) { const ang = Math.PI * k / 6, R = o.w / 2; const bar = new THREE.BoxGeometry(0.035, R, 0.03); bar.translate(0, R / 2, 0); bar.rotateZ(Math.PI / 2 - ang); bar.translate(cx, spring, zg + 0.01); B.add("trimGreenDark", bar.toNonIndexed()); }
    B.add("trimGreenDark", boxGeo(o.x, spring - 0.04, zg, o.w, 0.07, 0.05));
    if (o.kind === "door") {
      B.add("trimGreen", boxGeo(o.x + 0.05, o.y, zg - 0.05, o.w - 0.1, 1.0, 0.06));
      B.add("trimGreenDark", boxGeo(cx - 0.03, o.y + 1.0, zg, 0.06, spring - o.y - 1.0, 0.05));
      B.add("gold", boxGeo(cx + 0.1, o.y + 1.05, zg + 0.04, 0.05, 0.3, 0.04));
    } else {
      for (let k = 1; k < 3; k++) B.add("trimGreenDark", boxGeo(o.x + o.w * k / 3 - 0.02, o.y, zg, 0.04, spring - o.y, 0.04));
      B.add("trimGreenDark", boxGeo(o.x, o.y + (spring - o.y) * 0.62, zg, o.w, 0.04, 0.04));
    }
    // interior: warm back wall and a counter suggested by blocks
    B.add("shopWarm", boxGeo(o.x - 0.2, 0, zg - 2.2, o.w + 0.4, o.h + 0.2, 0.05));
    B.add("frameBrown", boxGeo(o.x, 0, zg - 1.4, o.w, 0.9, 0.5));
    for (const sx of [o.x - 0.2, o.x + o.w + 0.2]) { const s = new THREE.PlaneGeometry(2.2, o.h + 0.2); s.rotateY(sx < cx ? Math.PI / 2 : -Math.PI / 2); s.translate(sx, (o.h + 0.2) / 2, zg - 1.1); B.add("shopWarm", s); }
  }
  // the striped awning over the first bay
  const o = ops[0], aw = o.w + 0.5, len = 1.5, drop = 0.7;
  const ag = new THREE.PlaneGeometry(aw, Math.hypot(len, drop)); ag.rotateX(-Math.PI / 2 + Math.atan2(drop, len));
  ag.translate(o.x + o.w / 2, top - 0.75 - drop / 2, z + len / 2 + 0.05);
  const uv = ag.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * aw / 1.6, uv.getY(i));
  B.add("awningGreenPlain", ag);
  const sc = new THREE.Shape(); const vy = top - 0.75 - drop; sc.moveTo(o.x - 0.25, vy);
  const nS = 7; for (let i = 0; i < nS; i++) { const xa = o.x - 0.25 + aw * i / nS, xb = xa + aw / nS; sc.lineTo(xa, vy - 0.18); sc.quadraticCurveTo((xa + xb) / 2, vy - 0.34, xb, vy - 0.18); }
  sc.lineTo(o.x - 0.25 + aw, vy); sc.lineTo(o.x - 0.25, vy);
  const vg = new THREE.ShapeGeometry(sc, 4); vg.translate(0, 0, z + len + 0.05); B.add("awningGreenPlain", vg.toNonIndexed());
}

function groundOpening(B, o, rng) {
  if (o.kind === "window") {
    windowUnit(B, o, rng, { frameKey: "frame", bars: true });
    frameAround(B, "stone", o, 0.16);
    if (o.arch) keystone(B, "stone", o);
    return;
  }
  if (o.kind === "shoparch") {
    // the café wraps the corner: one more green round-headed window in a stone arch
    frameAround(B, "stone", o, 0.22); keystone(B, "stone", { ...o, h: o.h + 0.05 });
    const z = -o.depth + 0.06, spring = o.y + o.h - o.w / 2, cx = o.x + o.w / 2;
    const g = new THREE.ShapeGeometry(new THREE.Shape(openingOutline(o).map(p => new THREE.Vector2(p[0], p[1]))), 8); g.translate(0, 0, z); B.add("shopGlassWarm", g.toNonIndexed());
    B.add("trimGreen", boxGeo(o.x, o.y, z - 0.03, o.w, 0.5, 0.08));
    for (let k = 1; k < 6; k++) { const ang = Math.PI * k / 6, R = o.w / 2; const bar = new THREE.BoxGeometry(0.035, R, 0.03); bar.translate(0, R / 2, 0); bar.rotateZ(Math.PI / 2 - ang); bar.translate(cx, spring, z + 0.01); B.add("trimGreenDark", bar.toNonIndexed()); }
    B.add("trimGreenDark", boxGeo(o.x, spring - 0.04, z, o.w, 0.07, 0.05));
    for (let k = 1; k < 3; k++) B.add("trimGreenDark", boxGeo(o.x + o.w * k / 3 - 0.02, o.y + 0.5, z, 0.04, spring - o.y - 0.5, 0.04));
    B.add("shopWarm", boxGeo(o.x - 0.2, 0, z - 2.0, o.w + 0.4, o.h, 0.05));
    return;
  }
  if (o.kind === "door" || o.kind === "backdoor") {
    // panelled green door; the front one under a pedimented stone surround (sheet detail)
    const z = -o.depth + 0.06;
    const spring = o.arch ? o.y + o.h - o.w / 2 : o.y + o.h;
    const key = o.kind === "door" ? "trimGreen" : "doorWood";
    B.add(key, boxGeo(o.x + 0.02, o.y, z, o.w - 0.04, spring - o.y - 0.02, 0.06));
    for (const [py, ph] of [[0.25, 0.7], [1.15, spring - o.y - 1.45]]) for (const k of [0, 1]) {
      const pw = (o.w - 0.4) / 2;
      B.add("trimGreenDark", boxGeo(o.x + 0.15 + k * (pw + 0.1), o.y + py, z + 0.06, pw, ph, 0.03));
    }
    B.add("gold", boxGeo(o.x + o.w - 0.25, o.y + 1.05, z + 0.08, 0.05, 0.22, 0.05));
    if (o.arch) {
      const fan = new THREE.ShapeGeometry(new THREE.Shape([new THREE.Vector2(o.x, spring), ...openingOutline(o).slice(2).map(p => new THREE.Vector2(p[0], Math.max(p[1], spring)))]), 6);
      fan.translate(0, 0, z + 0.01); B.add("glass", fan.toNonIndexed());
      for (let k = 1; k < 6; k++) { const ang = Math.PI * k / 6, R = o.w / 2; const bar = new THREE.BoxGeometry(0.03, R, 0.03); bar.translate(0, R / 2, 0); bar.rotateZ(Math.PI / 2 - ang); bar.translate(o.x + o.w / 2, spring, z + 0.03); B.add("iron", bar.toNonIndexed()); }
    }
    frameAround(B, "stone", o, 0.24);
    if (o.kind === "door") {
      // pilasters and a triangular pediment on consoles, as in the sheet's door detail
      for (const px of [o.x - 0.55, o.x + o.w + 0.24]) B.add("stone", boxGeo(px, 0, 0, 0.31, o.h + 0.2, 0.12));
      pediment(B, "stone", { ...o, x: o.x - 0.35, w: o.w + 0.7 }, "tri", o.y + o.h + 0.25);
      B.add("stone", boxGeo(o.x - 0.3, -0.15, 0, o.w + 0.6, 0.16, 0.5));       // step
    }
  }
}

function flowerBox(B, o, rng) {
  const y = o.y - 0.12, x0 = o.x - 0.05, w = o.w + 0.1;
  B.add("doorWood", boxGeo(x0, y, 0.02, w, 0.24, 0.3));
  for (let k = 0; k < 9; k++) {
    const g = new THREE.IcosahedronGeometry(rng.range(0.09, 0.15), 0);
    g.translate(x0 + 0.08 + (w - 0.16) * k / 8, y + 0.28 + rng.range(-0.03, 0.06), 0.17 + rng.range(-0.06, 0.06));
    B.add(rng.chance(0.55) ? (rng.chance(0.6) ? "flowersRed" : "flowersPink") : "leavesBox", g.toNonIndexed());
  }
  // trailing greenery over the front edge
  for (let k = 0; k < 4; k++) { const g = new THREE.IcosahedronGeometry(0.1, 0); g.scale(1, 1.8, 0.6); g.translate(x0 + 0.15 + k * (w - 0.3) / 3, y - 0.05, 0.33); B.add("leavesBox", g.toNonIndexed()); }
}

// ------------------------------------------------------------------ roof
function buildRoof(group, rng) {
  const B = new Bucket();
  const E = TH.eave, W = TH.W, Dp = TH.Dp, R = TH.mansardRise, run = TH.mansardRun;
  const poly = [new THREE.Vector3(0, 0, 0), new THREE.Vector3(W, 0, 0), new THREE.Vector3(W, 0, -Dp), new THREE.Vector3(0, 0, -Dp)];
  // the cornice projects ~0.75 m: start the slate a little outside the wall line, with a slight bell
  const out = insetPolygon(poly, -0.3);
  const mid = insetPolygon(poly, run * 0.35);
  const top = insetPolygon(poly, run);
  const pos = [];
  const ring = (A, yA, Bp, yB) => {
    for (let i = 0; i < 4; i++) {
      const a = A[i], b = A[(i + 1) % 4], c = Bp[(i + 1) % 4], d = Bp[i];
      pos.push(a.x, yA, a.z, b.x, yA, b.z, c.x, yB, c.z, a.x, yA, a.z, c.x, yB, c.z, d.x, yB, d.z);
    }
  };
  ring(out, E, mid, E + R * 0.25);
  ring(mid, E + R * 0.25, top, E + R);
  // upper hipped roof: a short ridge along the long side
  const t = top, ridgeY = E + R + TH.hipRise, inset = (Dp - 2 * run) / 2;
  const k0 = new THREE.Vector3(t[0].x + inset, 0, (t[0].z + t[3].z) / 2), k1 = new THREE.Vector3(t[1].x - inset, 0, (t[1].z + t[2].z) / 2);
  const v = (p, y) => [p.x, y, p.z];
  const y0 = E + R;
  pos.push(...v(t[0], y0), ...v(t[1], y0), ...v(k1, ridgeY), ...v(t[0], y0), ...v(k1, ridgeY), ...v(k0, ridgeY));   // front
  pos.push(...v(t[2], y0), ...v(t[3], y0), ...v(k0, ridgeY), ...v(t[2], y0), ...v(k0, ridgeY), ...v(k1, ridgeY));   // rear
  pos.push(...v(t[1], y0), ...v(t[2], y0), ...v(k1, ridgeY));                                                        // right hip
  pos.push(...v(t[3], y0), ...v(t[0], y0), ...v(k0, ridgeY));                                                        // left hip
  const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
  orientUp(g); g.computeVertexNormals(); boxUV(g, 2);
  B.add("slate", g);
  // lead rolls along the hips and the curb between the slopes
  const roll = (p0, p1) => { const l = p0.distanceTo(p1); const c = new THREE.CylinderGeometry(0.05, 0.05, l, 6); c.translate(0, l / 2, 0); c.applyQuaternion(new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), p1.clone().sub(p0).normalize())); c.translate(p0.x, p0.y, p0.z); B.add("zinc", c.toNonIndexed()); };
  for (let i = 0; i < 4; i++) roll(new THREE.Vector3(t[i].x, y0, t[i].z), new THREE.Vector3(t[(i + 1) % 4].x, y0, t[(i + 1) % 4].z));
  for (const [c, k] of [[t[0], k0], [t[3], k0], [t[1], k1], [t[2], k1]]) roll(new THREE.Vector3(c.x, y0, c.z), new THREE.Vector3(k.x, ridgeY, k.z));
  roll(new THREE.Vector3(k0.x, ridgeY, k0.z), new THREE.Vector3(k1.x, ridgeY, k1.z));
  // hip rolls on the lower slope follow its bell: out -> mid -> top
  for (let i = 0; i < 4; i++) {
    roll(new THREE.Vector3(out[i].x, E, out[i].z), new THREE.Vector3(mid[i].x, E + R * 0.25, mid[i].z));
    roll(new THREE.Vector3(mid[i].x, E + R * 0.25, mid[i].z), new THREE.Vector3(top[i].x, E + R, top[i].z));
  }

  // chimneys: four stacks near the corners (roof plan), brick with stone bands and pots
  // behind the outer dormers, clear of their cheeks
  const stacks = [[1.55, -2.7], [W - 1.55, -2.7], [1.55, -Dp + 2.7], [W - 1.55, -Dp + 2.7]];
  for (const [cx, cz] of stacks) {
    const w = 1.75, d = 0.95, h0 = E - 1, h1 = ridgeY + 1.0;
    const st = boxGeo(cx - w / 2, h0, cz - d / 2, w, h1 - h0, d); boxUV(st, 1); B.add("chimney", st);
    B.add("stone", boxUV(boxGeo(cx - w / 2 - 0.08, h1 - 0.35, cz - d / 2 - 0.08, w + 0.16, 0.14, d + 0.16), 1));
    B.add("stone", boxUV(boxGeo(cx - w / 2 - 0.12, h1, cz - d / 2 - 0.12, w + 0.24, 0.16, d + 0.24), 1));
    const nPots = 3;
    for (let k = 0; k < nPots; k++) {
      const px = cx - w / 2 + 0.28 + k * (w - 0.56) / (nPots - 1);
      const pot = new THREE.LatheGeometry([[0, 0], [0.16, 0], [0.13, 0.35], [0.12, 0.55], [0.15, 0.6], [0.15, 0.66], [0.11, 0.66]].map(p => new THREE.Vector2(p[0], p[1])), 12);
      pot.translate(px, h1 + 0.16, cz); B.add("pot", pot.toNonIndexed());
    }
  }

  // dormers: stone fronts with alternating pediments, set into the lower slope
  const dormersOn = { front: [0, 1, 2, 3], rear: [0, 1, 2, 3], right: [0, 1], left: [0, 1] };
  for (const [name, idx] of Object.entries(dormersOn)) {
    const F = FACADES[name], M = facadeMatrix(new THREE.Vector3(...F.o), new THREE.Vector3(...F.a));
    const D2 = new Bucket();
    idx.forEach((i, n) => stoneDormer(D2, F.axes[i], n % 2 ? "seg" : "tri", rng));
    for (const [k, geo] of D2.merge()) { geo.applyMatrix4(M); B.add(k, geo); }
  }
  for (const [k, geo] of B.merge()) {
    const m = new THREE.Mesh(geo, MAT[k]); m.castShadow = true; m.receiveShadow = true; m.name = k; group.add(m);
  }
}

function stoneDormer(B, x, ped, rng) {
  const E = TH.eave, R = TH.mansardRise, run = TH.mansardRun;
  const zf = -0.1, y0 = E + 0.45, w = 1.15, h = 2.0;
  const o = { x: x - w / 2, y: y0 + 0.12, w, h: h - 0.2, arch: ped === "seg" ? "seg" : 0, depth: 0.15, kind: "window" };
  const fw = 0.22;
  const [f, rv] = wallWithOpenings(x - w / 2 - fw, y0, x + w / 2 + fw, y0 + h, [o], zf);
  addUV(B, "stone", f, null, 1); addUV(B, "stone", rv, null, 1);
  windowUnit(B, { ...o, depth: 0.15 }, rng, { frameKey: "frame", curtains: false });
  const T = new THREE.Matrix4().makeTranslation(0, 0, zf);
  const lb = new Bucket();
  pediment(lb, "stone", { ...o, x: o.x - 0.12, w: o.w + 0.24 }, ped, y0 + h);
  for (const [k, list] of lb.parts) for (const g of list) { g.applyMatrix4(T); B.add(k, g); }
  // small side scrolls and slate cheeks running back into the mansard
  for (const s of [-1, 1]) B.add("stone", consoleGeo(x + s * (w / 2 + fw) - (s < 0 ? 0 : 0.14), y0, 0.14, 0.6, 0.25).translate(0, 0, zf));
  const dep = 2.0;
  for (const xe of [x - w / 2 - fw, x + w / 2 + fw - 0.06]) B.add("slate", boxUV(boxGeo(xe, y0, zf - dep, 0.06, h, dep), 1));
  B.add("slate", boxUV(boxGeo(x - w / 2 - fw, y0 + h + 0.15, zf - dep, w + 2 * fw, 0.08, dep), 1));
}

// ------------------------------------------------------------------ ivy
// Ivy (Efeu) climbing from the ground up the right side and the corner, as in the sheet.
function buildIvy(group, rng) {
  const cards = [];
  const grow = (fname, u0, maxH, spread, n) => {
    const F = FACADES[fname], o = new THREE.Vector3(...F.o), a = new THREE.Vector3(...F.a);
    const out = new THREE.Vector3().crossVectors(a, new THREE.Vector3(0, 1, 0));
    for (let s = 0; s < n; s++) {
      let u = u0 + rng.range(-0.4, 0.4), y = 0.2;
      while (y < maxH * rng.range(0.6, 1)) {
        u += rng.range(-0.3, 0.3) * spread; y += rng.range(0.1, 0.25);
        if (u < 0.1 || u > F.w - 0.1) break;
        for (let k = 0; k < 4; k++) {
          const p = o.clone().addScaledVector(a, u + rng.range(-0.3, 0.3)).add(new THREE.Vector3(0, y + rng.range(-0.15, 0.15), 0)).addScaledVector(out, rng.range(0.03, 0.1));
          cards.push({ p, s: rng.range(0.22, 0.38), out });
        }
        // runners along the string courses
        if (rng.chance(0.12)) for (let k = 0, du = rng.range(-1, 1) > 0 ? 1 : -1; k < 10; k++) {
          const uu = u + du * k * 0.14; if (uu < 0.1 || uu > F.w - 0.1) break;
          cards.push({ p: o.clone().addScaledVector(a, uu).add(new THREE.Vector3(0, y + rng.range(-0.1, 0.1), 0)).addScaledVector(out, 0.06), s: rng.range(0.2, 0.32), out });
        }
      }
    }
  };
  grow("right", 0.5, 11.5, 1.6, 9);      // up from the corner by the café
  grow("right", 5.2, 5.5, 1.2, 5);
  grow("left", 7.5, 4.5, 1.2, 5);
  grow("front", 13.4, 7.0, 0.8, 4);      // round the corner onto the front
  grow("rear", 1.5, 6.0, 1.0, 4);
  // cards lie close to the wall: oriented along the wall with a little tilt
  const pos = [], nor = [], uv = [];
  const corners = [[-0.5, -0.5], [0.5, -0.5], [0.5, 0.5], [-0.5, -0.5], [0.5, 0.5], [-0.5, 0.5]];
  for (const c of cards) {
    const q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 0, 1), c.out);
    const tilt = new THREE.Quaternion().setFromEuler(new THREE.Euler(rng.range(-0.35, 0.35), rng.range(-0.35, 0.35), rng.range(0, Math.PI * 2)));
    q.multiply(tilt);
    for (const [u, v] of corners) {
      const p = new THREE.Vector3(u * c.s, v * c.s, 0).applyQuaternion(q).add(c.p);
      pos.push(p.x, p.y, p.z); nor.push(c.out.x, c.out.y + 0.2, c.out.z); uv.push(u + 0.5, v + 0.5);
    }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute("normal", new THREE.Float32BufferAttribute(nor, 3));
  g.setAttribute("uv", new THREE.Float32BufferAttribute(uv, 2));
  const m = new THREE.Mesh(g, MAT.ivy); m.castShadow = true; m.receiveShadow = true; m.name = "ivy"; group.add(m);
}

// ------------------------------------------------------------------ sign
function hangingSign(group) {
  // wrought-iron bracket on the right side by the corner, with the teapot board
  const B = new Bucket();
  const F = FACADES.right, M = facadeMatrix(new THREE.Vector3(...F.o), new THREE.Vector3(...F.a));
  const x = 1.4, y = 4.7;
  B.add("iron", boxGeo(x - 0.03, y, 0, 0.06, 0.06, 1.25));
  const curve = []; for (let i = 0; i <= 10; i++) { const t = i / 10; curve.push([x, y - 0.55 + 0.55 * Math.sin(t * Math.PI / 2), 0.05 + t * 1.0]); }
  for (let i = 0; i < 10; i++) { const p0 = new THREE.Vector3(...curve[i]), p1 = new THREE.Vector3(...curve[i + 1]); const l = p0.distanceTo(p1); const c = new THREE.CylinderGeometry(0.02, 0.02, l, 5); c.translate(0, l / 2, 0); c.applyQuaternion(new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), p1.clone().sub(p0).normalize())); c.translate(p0.x, p0.y, p0.z); B.add("iron", c.toNonIndexed()); }
  for (let k = 0; k < 3; k++) { const r = new THREE.TorusGeometry(0.1, 0.012, 5, 14); r.rotateY(Math.PI / 2); r.translate(x, y - 0.18, 0.35 + k * 0.28); B.add("iron", r.toNonIndexed()); }
  for (const zz of [0.6, 1.05]) B.add("iron", boxGeo(x - 0.01, y - 0.25, zz, 0.02, 0.25, 0.02));
  const board = new THREE.BoxGeometry(0.05, 0.62, 0.62); board.translate(x, y - 0.6, 0.83);
  // map the teapot onto both faces
  B.add("signBoard", board.toNonIndexed());
  for (const [k, geo] of B.merge()) { geo.applyMatrix4(M); const m = new THREE.Mesh(geo, MAT[k]); m.castShadow = true; m.name = k; group.add(m); }
}

// soft smoke rising from two of the stacks, drifting downwind (as in the illustration)
function chimneySmoke(group, rng) {
  const c = canvas(128, 128), x = c.getContext("2d");
  const g = x.createRadialGradient(64, 64, 4, 64, 64, 62);
  g.addColorStop(0, "rgba(235,232,226,0.55)"); g.addColorStop(0.5, "rgba(220,216,210,0.28)"); g.addColorStop(1, "rgba(210,206,200,0)");
  x.fillStyle = g; x.fillRect(0, 0, 128, 128);
  const tex = toTex(c, true, false);
  const top = TH.eave + TH.mansardRise + TH.hipRise + 1.0 + 0.9;
  for (const [cx, cz] of [[1.55, -2.7], [TH.W - 1.55, -2.7]]) {
    for (let i = 0; i < 14; i++) {
      const t = i / 13;
      const m = new THREE.SpriteMaterial({ map: tex, transparent: true, depthWrite: false, opacity: 0.85 * (1 - t * 0.8), color: new THREE.Color("#d9d4cc").lerp(new THREE.Color("#a9a49c"), t * 0.6) });
      const sp = new THREE.Sprite(m);
      sp.position.set(cx - t * 3.5 + rng.range(-0.3, 0.3), top + t * 7 + rng.range(-0.2, 0.2), cz + t * 1.2);
      sp.scale.setScalar(0.9 + t * 3.2);
      sp.name = "smoke";
      group.add(sp);
    }
  }
}

function buildTownhouse(scene, rng) {
  const mats = townhouseMaterials();
  texLeaves();
  MAT.ivy = new THREE.MeshStandardMaterial({ map: TEX.leaves.map, alphaTest: 0.45, alphaToCoverage: true, side: THREE.DoubleSide, roughness: 0.85, color: "#c8e08f" });
  const g = new THREE.Group(); g.name = "townhouse";
  for (const name of Object.keys(FACADES)) buildFacade(name, g, mats, rng);
  buildRoof(g, rng);
  buildIvy(g, rng);
  hangingSign(g);
  chimneySmoke(g, rng);
  scene.add(g);
  return g;
}
