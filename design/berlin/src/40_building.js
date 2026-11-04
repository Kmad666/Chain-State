// ============================================================== buildings
// A Berliner Mietshaus front building (Vorderhaus): five storeys under the 22 m eaves
// line of the 1887 building code, ground floor of shops or a raised Hochparterre,
// the Beletage on the first floor richest, ornament thinning out toward the top.

const SHARED = new Bucket();          // geometry in world space for materials shared by all houses
const SEG_KEYS = new Set(["wall", "orn", "rustic", "sockel", "brick"]);

// Colour schemes seen on renovated Prenzlauer Berg facades, and the grey of the unrenovated.
const SCHEMES = [
  { wall: "#e2d3b0", orn: "#efe6d0", base: "#c9b994" },     // sand
  { wall: "#d9c08a", orn: "#ece0c2", base: "#bfa676" },     // ochre
  { wall: "#e8e0cf", orn: "#f4efe4", base: "#cfc6b2" },     // cream white
  { wall: "#c7cbc4", orn: "#e6e6df", base: "#a9aea6" },     // pale grey-green
  { wall: "#dcb9a0", orn: "#efe1d3", base: "#c29f88" },     // salmon
  { wall: "#b9bfc6", orn: "#e3e5e6", base: "#9ea4ab" },     // blue grey
  { wall: "#e6d5a3", orn: "#f2ead2", base: "#ccb987" },     // pale yellow
  { wall: "#cfc2ad", orn: "#e3dccd", base: "#b1a48f" },     // stone
  { wall: "#a9b39b", orn: "#dfe2d2", base: "#8f9883" },     // sage
  { wall: "#d4a98a", orn: "#ecd8c4", base: "#b98d70" },     // terracotta wash
];
const GREY = { wall: "#9b958a", orn: "#a8a297", base: "#857f75" };

function floorPlan(rng, scale, shops) {
  // storey heights (m): ground, Beletage, 2nd, 3rd, 4th
  const hs = [shops ? 4.3 : 4.1, 4.05, 3.7, 3.45, 3.25].map(h => h * scale);
  const floors = []; let y = 0;
  const kinds = ["ground", "bel", "second", "third", "top"];
  for (let i = 0; i < 5; i++) { floors.push({ i, kind: kinds[i], y0: y, h: hs[i] }); y += hs[i]; }
  const frieze = 0.65 * scale, cornice = 1.0 * scale;
  return { floors, frieze, cornice, wallTop: y + frieze, eave: y + frieze + cornice };
}

// --------------------------------------------------------------------------------
class Building {
  constructor(lot) {
    this.lot = lot;
    this.rng = new Rng(lot.seed);
    this.group = new THREE.Group();
    this.group.name = lot.name || "house";
  }

  build() {
    const L = this.lot, r = this.rng;
    if (L.style === "gdr") return this.buildInfill();
    const shops = L.shops ?? r.chance(0.65);
    this.plan = floorPlan(r, L.scale || r.range(0.97, 1.05), shops);
    this.shops = shops;
    this.scheme = L.cond > 0.75 ? { ...GREY, wall: mixHex(GREY.wall, r.pick(SCHEMES).wall, 0.25) } : (L.scheme || r.pick(SCHEMES));
    if (L.style === "brick") this.scheme = { ...this.scheme, brick: r.chance(0.6) ? "brickYellow" : "brick", wall: "#ffffff" };
    this.frameKey = L.cond > 0.75 ? r.pick(["frameWood", "frameBrown", "frame"]) : r.pick(["frame", "frame", "frame", "frameCream", "frameWood", "frameGreen"]);
    this.segs = L.segments.map((s, i) => this.buildSegment(s, i));
    this.buildRoofAndBody();
    return this.group;
  }

  // ---------------------------------------------------------------- one facade
  buildSegment(seg, si) {
    const L = this.lot, r = this.rng, P = this.plan, S = L.style;
    const W = seg.width;
    const M = facadeMatrix(seg.origin, seg.along);
    const B = new Bucket();
    const rich = S === "rich" || S === "corner", stripped = S === "stripped", nouveau = S === "nouveau";
    const isChamfer = !!seg.chamfer;

    // ---- window axes
    let xs = [];
    if (isChamfer) xs = [W / 2];
    else {
      const pitch = r.range(3.0, 3.4);
      const n = Math.max(1, Math.floor((W - 1.4) / pitch + 0.35));
      const step = (W - 1.6) / Math.max(1, n - 1) ;
      const realStep = Math.min(pitch, step);
      const span = realStep * (n - 1), start = (W - span) / 2;
      for (let i = 0; i < n; i++) xs.push(start + i * realStep);
    }
    const n = xs.length;
    const pitch = n > 1 ? xs[1] - xs[0] : W;
    const ww = Math.min(1.35, pitch * 0.42);          // window width
    seg.xs = xs;

    // ---- facade features: risalit, Erker (bay), balconies
    const mid = Math.floor(n / 2);
    let erker = null, risalits = [];
    if (!isChamfer && n >= 5 && !stripped && (rich || nouveau ? r.chance(0.7) : r.chance(0.3)) && L.style !== "brick") {
      const span = n % 2 ? 1 : 2;
      const i0 = n % 2 ? mid : mid - 1;
      erker = { i0, i1: i0 + span - 1, proj: 0.85, x0: xs[i0] - ww / 2 - 0.55, x1: xs[i0 + span - 1] + ww / 2 + 0.55 };
    }
    if (!isChamfer && !erker && rich && n >= 5) {
      // a central risalit three (or two) axes wide, projecting a little
      const span = n % 2 ? 3 : 2, i0 = n % 2 ? mid - 1 : mid - 1;
      risalits.push({ x0: xs[i0] - pitch / 2 + 0.05, x1: xs[i0 + span - 1] + pitch / 2 - 0.05, z: 0.14 });
    }
    if (!isChamfer && n >= 6 && (S === "moderate" || S === "brick") && r.chance(0.5)) {
      risalits.push({ x0: 0, x1: xs[1] + pitch / 2 - 0.05, z: 0.1 });
      risalits.push({ x0: xs[n - 2] - pitch / 2 + 0.05, x1: W, z: 0.1 });
    }
    const balconyAxes = new Set();
    if (!isChamfer && !stripped) {
      if (erker) { if (erker.i0 - 2 >= 0 && r.chance(0.6)) { balconyAxes.add(erker.i0 - 2); balconyAxes.add(erker.i1 + 2); } }
      else if (n >= 4 && r.chance(0.75)) {
        if (r.chance(0.5)) { balconyAxes.add(mid); if (n % 2 === 0) balconyAxes.add(mid - 1); }
        else { balconyAxes.add(1); balconyAxes.add(n - 2); }
      }
    }
    const zAt = (x) => { for (const rs of risalits) if (x >= rs.x0 && x <= rs.x1) return rs.z; return 0; };

    // ---- the ground floor
    const g = P.floors[0];
    const gTop = g.y0 + g.h;
    const groundOpenings = [];
    const gate = isChamfer ? -1 : (L.gateAxis ?? (n >= 3 ? (r.chance(0.5) ? mid : (r.chance(0.5) ? 0 : n - 1)) : 0));
    const shopAxes = [];
    for (let i = 0; i < n; i++) {
      const x = xs[i];
      if (i === gate) {
        // Durchfahrt / house door: a round-arched opening with a double wooden door
        const w = L.gateWide ? 3.0 : 1.9, h = L.gateWide ? 3.7 : 3.3;
        groundOpenings.push({ x: x - w / 2, y: 0.02, w, h, arch: "round", depth: 0.4, kind: "door" });
      } else if (this.shops && !(i === gate - 1 && n < 4)) {
        const w = Math.min(pitch - 0.7, 2.7), h = 3.0;
        groundOpenings.push({ x: x - w / 2, y: 0.12, w, h, arch: S === "nouveau" ? "seg" : 0, depth: 0.32, kind: "shop" });
        shopAxes.push(i);
      } else {
        groundOpenings.push({ x: x - ww / 2, y: 1.1, w: ww, h: 2.3, arch: rich ? "seg" : 0, depth: 0.26, kind: "window" });
      }
    }
    if (isChamfer) groundOpenings[0] = { x: W / 2 - 0.85, y: 0.02, w: 1.7, h: 2.85, arch: "seg", depth: 0.35, kind: "pubdoor" };
    const [gf, gr] = wallWithOpenings(0, 0, W, gTop, groundOpenings);
    addUV(B, "rustic", gf, null, 2); addUV(B, "rustic", gr, null, 2);
    // granite plinth band and a belt course over the ground floor
    if (!this.shops) B.add("sockel", sweep(PROFILE.band(0.55, 0.05), straight(0, W, 0)));
    for (const o of groundOpenings) this.groundFill(B, o, r, S, seg, si);
    // tags sprayed on the ground floor between the openings (fewer on freshly done houses)
    const spans = groundOpenings.map(o => [o.x, o.x + o.w]).sort((a, b) => a[0] - b[0]);
    let gx = 0.2;
    for (const [a, b] of [...spans, [W - 0.2, W]]) {
      if (a - gx > 1.3 && r.chance(0.2 + 0.5 * L.cond)) {
        const tw = Math.min(a - gx - 0.2, r.range(1.1, 2.0));
        const tg = new THREE.PlaneGeometry(tw, tw * 0.5); tg.translate(gx + 0.1 + tw / 2, r.range(0.9, 1.9), 0.012);
        B.add("tag" + r.int(0, 7), tg);
      }
      gx = b;
    }

    // ---- upper floors
    const upper = P.floors.slice(1);
    const wallKey = this.scheme.brick ? "brick" : "wall";
    // panels: the main wall at z=0 and risalits / the Erker's backing
    const panels = [{ x0: 0, x1: W, z: 0 }];
    for (const rs of risalits) panels.push(rs);
    const openingsByPanel = panels.map(() => []);
    const windows = [];                      // for weathering: sills
    for (const f of upper) {
      for (let i = 0; i < n; i++) {
        const x = xs[i];
        if (erker && i >= erker.i0 && i <= erker.i1 && f.kind !== "top") continue;  // behind the bay
        const bal = balconyAxes.has(i) && f.kind !== "top" || (erker && i >= erker.i0 && i <= erker.i1 && f.kind === "top");
        const hgt = { bel: 2.6, second: 2.4, third: 2.25, top: 2.0 }[f.kind] * (this.plan.floors[1].h / 4.05);
        const sill = bal ? f.y0 + 0.08 : f.y0 + 0.88;
        const top = f.y0 + 0.88 + hgt;
        const arch = (nouveau && f.kind === "top") ? "seg" : (rich && f.kind === "bel" && i % 2 === 1 && r.chance(0) ? "round" : 0);
        const o = { x: x - ww / 2, y: sill, w: ww, h: top - sill, arch, depth: 0.26, kind: bal ? "balcony" : "window", floor: f, axis: i };
        const pi = panels.findIndex((p, k) => k > 0 && x >= p.x0 && x <= p.x1);
        openingsByPanel[pi < 0 ? 0 : pi].push(o);
        windows.push(o);
      }
    }
    if (isChamfer && L.tower) openingsByPanel[0].length = 0;       // the tower covers the chamfer
    // main wall (with risalit areas cut as openings without reveals), then each risalit
    const mainHoles = openingsByPanel[0].slice();
    const [mf, mr] = wallWithOpenings(0, gTop, W, P.wallTop, mainHoles);
    addUV(B, wallKey, mf, null, wallKey === "brick" ? [2, 1] : 2); addUV(B, wallKey, mr, null, 2);
    for (let k = 1; k < panels.length; k++) {
      const p = panels[k];
      const [pf, pr] = wallWithOpenings(p.x0, gTop, p.x1, P.wallTop, openingsByPanel[k], p.z);
      addUV(B, wallKey, pf, null, wallKey === "brick" ? [2, 1] : 2); addUV(B, wallKey, pr, null, 2);
      // side returns
      for (const xe of [p.x0, p.x1]) { const sg = new THREE.PlaneGeometry(p.z, P.wallTop - gTop); sg.rotateY(xe === p.x0 ? -Math.PI / 2 : Math.PI / 2); sg.translate(xe, (gTop + P.wallTop) / 2, p.z / 2); addUV(B, wallKey, sg, null, 2); }
    }
    // windows and their ornament
    for (let k = 0; k < panels.length; k++) {
      const pz = panels[k].z;
      const T = new THREE.Matrix4().makeTranslation(0, 0, pz);
      for (const o of openingsByPanel[k]) this.upperWindow(B, o, T, r, S);
    }

    // ---- horizontal mouldings
    const beltY = gTop - (stripped ? 0.2 : 0.32);
    for (const p of panels) {
      const T = new THREE.Matrix4().makeTranslation(0, 0, p.z);
      const pk = panels.indexOf(p);
      const run = (prof, y) => {
        const top = prof.reduce((m, q) => Math.max(m, q[1]), 0);
        const gaps = openingsByPanel[pk].filter(o => o.y < y + top && o.y + o.h > y).map(o => [o.x - 0.02, o.x + o.w + 0.02]).sort((a, b) => a[0] - b[0]);
        let x = p.x0;
        for (const [g0, g1] of [...gaps, [p.x1, p.x1]]) {
          if (g0 - x > 0.05) { const g2 = sweep(prof, straight(x, Math.min(g0, p.x1), y)); g2.applyMatrix4(T); B.add("orn", g2); }
          x = Math.max(x, g1);
        }
      };
      run(stripped ? PROFILE.band(0.2, 0.05) : PROFILE.belt(), beltY);
      if (!stripped) {
        run(PROFILE.sill(), P.floors[1].y0 + 0.66);           // under the Beletage windows
        if (rich || nouveau) run(PROFILE.sill(0.8), P.floors[2].y0 + 0.7);
        run(PROFILE.band(0.12, 0.03), P.floors[4].y0 + 0.74);
      }
      // frieze and main cornice
      run(stripped ? PROFILE.band(0.35, 0.18) : PROFILE.main(P.cornice), P.wallTop);
      if (!stripped) {
        // modillions (rich) or dentils
        if (rich || nouveau) {
          for (let x = p.x0 + 0.35; x < p.x1 - 0.2; x += 0.62) { const c = consoleGeo(x, P.wallTop + 0.06 * P.cornice, 0.16, 0.38 * P.cornice, 0.6 * P.cornice); c.applyMatrix4(T); B.add("orn", c); }
        } else {
          const gg = new Bucket(); dentils(gg, "orn", p.x0, p.x1, P.wallTop + 0.06, 0.12, 0.13, 0.16, 0.09);
          for (const geo of gg.parts.get("orn") || []) { geo.applyMatrix4(T); B.add("orn", geo); }
        }
        // frieze: a flat band with panels under the cornice
        const fr = boxGeo(p.x0, P.wallTop - P.frieze, p.z, p.x1 - p.x0, P.frieze - 0.05, 0.02); B.add("orn", fr);
      }
    }
    // quoins up the ends of the facade (not on the chamfer: the tower takes it)
    if (!stripped && !isChamfer && (rich || S === "moderate" || S === "brick")) {
      for (const xe of [0, W - 0.62]) {
        for (let y = gTop, k = 0; y < P.wallTop - P.frieze - 0.3; y += 0.62, k++) {
          const w = k % 2 ? 0.45 : 0.62;
          B.add("orn", boxGeo(xe === 0 ? 0 : W - w, y + 0.03, 0, w, 0.56, 0.05));
        }
      }
    }

    // ---- a gable over the middle axes, breaking the eaves line (Zwerchgiebel)
    if (!isChamfer && !stripped && n >= 5 && (rich || nouveau || S === "brick") && r.chance(rich ? 0.55 : 0.7)) {
      const span = n % 2 ? 1 : 2, i0 = n % 2 ? mid : mid - 1;
      const gx0 = xs[i0] - pitch * (span === 1 ? 0.75 : 0.62), gx1 = xs[i0 + span - 1] + pitch * (span === 1 ? 0.75 : 0.62);
      this.gable(B, gx0, gx1, zAt((gx0 + gx1) / 2), xs.slice(i0, i0 + span), ww, nouveau ? "curved" : "stepped", r, wallKey);
    }

    // ---- balconies
    for (const i of balconyAxes) for (const f of upper) if (f.kind !== "top" || false) {
      if (f.kind === "top") continue;
      const x = xs[i], z0 = zAt(x);
      this.balcony(B, x - Math.max(ww / 2 + 0.55, 1.2), x + Math.max(ww / 2 + 0.55, 1.2), f.y0, z0, rich && f.kind === "bel" ? "stone" : (nouveau ? "railNouveau" : "railScroll"), r);
    }

    // ---- the Erker
    if (erker) this.erker(B, erker, xs, ww, r, S);

    // ---- shared-material geometry goes to world space, the rest stays with this facade
    const grimeSpec = { width: W, height: P.eave + 5, windows: windows.map(o => ({ x: o.x, y: o.y, w: o.w })), ledges: [beltY, P.wallTop], cond: L.cond };
    const grime = { map: grimeTexture(grimeSpec, r), origin: seg.origin.clone(), along: new THREE.Vector3(seg.along.x, 0, seg.along.z).normalize(), width: W, height: P.eave + 5 };
    const mats = facadeMaterials(this.scheme, grime);
    const merged = B.merge();
    for (const [k, geo] of merged) {
      if (SEG_KEYS.has(k)) {
        const m = new THREE.Mesh(geo, mats[k] || mats.wall);
        m.matrixAutoUpdate = false; m.matrix.copy(M);
        m.castShadow = true; m.receiveShadow = true;
        this.group.add(m);
      } else {
        geo.applyMatrix4(M);
        SHARED.add(k, geo);
      }
    }
    return { seg, M, xs, ww, erker, windows };
  }

  // A gable standing on the main cornice: a wall with windows, a moulded top edge
  // ("stepped": straight sides and a pediment, "curved": a Jugendstil swept outline),
  // and a short roof behind running back into the main roof.
  gable(B, x0, x1, z0, axes, ww, type, r, wallKey) {
    const P = this.plan, E = P.eave, w = x1 - x0, cx = (x0 + x1) / 2;
    const hSide = 2.7, hTop = 4.6;
    const outline = [];
    if (type === "curved") {
      outline.push([x0, E], [x1, E], [x1, E + hSide * 0.8]);
      for (let i = 1; i <= 10; i++) { const t = i / 10; outline.push([x1 - (w / 2) * t, E + hSide * 0.8 + (hTop - hSide * 0.8) * Math.sin(t * Math.PI / 2) + Math.sin(t * Math.PI) * 0.35]); }
      for (let i = 9; i >= 0; i--) { const t = i / 10; outline.push([x0 + (w / 2) * t, E + hSide * 0.8 + (hTop - hSide * 0.8) * Math.sin(t * Math.PI / 2) + Math.sin(t * Math.PI) * 0.35]); }
    } else {
      outline.push([x0, E], [x1, E], [x1, E + hSide], [cx, E + hTop], [x0, E + hSide]);
    }
    // wall with windows
    const shape = new THREE.Shape(outline.map(p => new THREE.Vector2(p[0], p[1])));
    const ops = axes.map(x => ({ x: x - ww * 0.42, y: E + 0.45, w: ww * 0.84, h: 1.9, arch: type === "curved" ? "seg" : 0, depth: 0.22, kind: "window", floor: { kind: "top" } }));
    if (axes.length === 1) ops.push({ x: cx - 0.3, y: E + 2.75, w: 0.6, h: 0.9, arch: "round", depth: 0.15, kind: "window", floor: { kind: "top" } });
    for (const o of ops) { const pts = openingOutline(o); const hole = new THREE.Path(); hole.moveTo(pts[0][0], pts[0][1]); for (let i = pts.length - 1; i > 0; i--) hole.lineTo(pts[i][0], pts[i][1]); shape.holes.push(hole); }
    const front = new THREE.ShapeGeometry(shape, 6); front.translate(0, 0, z0);
    addUV(B, wallKey, front.toNonIndexed(), null, 2);
    const [, rev] = wallWithOpenings(x0, E, x1, E + hTop, ops, z0);
    addUV(B, wallKey, rev, null, 2);
    const T = new THREE.Matrix4().makeTranslation(0, 0, z0);
    for (const o of ops) {
      const lb = new Bucket(); windowUnit(lb, o, r, { frameKey: this.frameKey, curtainChance: 0.3 }); frameAround(lb, "orn", o, 0.1);
      for (const [k, list] of lb.parts) for (const g of list) { g.applyMatrix4(T); B.add(k, g); }
    }
    // back wall where the gable's roof ends
    const backShape = new THREE.Shape(outline.map(p => new THREE.Vector2(p[0], p[1])));
    const back = new THREE.ShapeGeometry(backShape, 6); back.rotateY(Math.PI); back.translate(2 * cx, 0, z0 - 3.6);
    addUV(B, wallKey, back.toNonIndexed(), null, 2);
    // moulded top edge along the outline (not along the base)
    const edgePath = [[x1, E], ...outline.slice(2)];
    edgePath.push([x0, E]);
    B.add("orn", sweep(PROFILE.cap(0.9), edgePath.map(p => [p[0], p[1]]).reverse()).applyMatrix4(T));
    // finial
    const fin = new THREE.SphereGeometry(0.18, 10, 8); fin.translate(cx, E + hTop + 0.45, z0 + 0.1); B.add("orn", fin.toNonIndexed());
    B.add("orn", boxGeo(cx - 0.12, E + hTop + 0.05, z0 - 0.1, 0.24, 0.25, 0.24));
    // the gable's own roof running back 3.5 m, and its side walls
    const d = 3.6;
    const top = outline.slice(2);
    const roofPos = [];
    for (let i = 0; i < top.length - 1; i++) {
      const a = top[i], b = top[i + 1];
      roofPos.push(a[0], a[1], z0, b[0], b[1], z0, b[0], b[1], z0 - d, a[0], a[1], z0, b[0], b[1], z0 - d, a[0], a[1], z0 - d);
    }
    const rg = new THREE.BufferGeometry(); rg.setAttribute("position", new THREE.Float32BufferAttribute(roofPos, 3));
    orientUp(rg); rg.computeVertexNormals(); boxUV(rg, 2); B.add("gableRoof", rg);
    for (const xe of [x0, x1]) {
      const sh = top.find(p => Math.abs(p[0] - xe) < 1e-6) || [xe, E + hSide];
      const side = new THREE.PlaneGeometry(d, sh[1] - E); side.rotateY(xe === x0 ? -Math.PI / 2 : Math.PI / 2);
      side.translate(xe, (E + sh[1]) / 2, z0 - d / 2); addUV(B, wallKey, side.toNonIndexed(), null, 2);
    }
  }

  // shop fronts, doors, ground-floor windows
  groundFill(B, o, r, S, seg, si) {
    const L = this.lot;
    if (o.kind === "window") {
      windowUnit(B, o, r, { bars: true, frameKey: this.frameKey });
      frameAround(B, "orn", o, 0.12);
      if (o.arch) keystone(B, "orn", o);
      // small cellar window below (Kellerfenster) behind a grille
      const kw = { x: o.x + 0.15, y: 0.15, w: o.w - 0.3, h: 0.45, depth: 0.15 };
      B.add("interior", boxGeo(kw.x, kw.y, -0.12, kw.w, kw.h, 0.02));
      for (let x = kw.x + 0.08; x < kw.x + kw.w; x += 0.12) B.add("iron", boxGeo(x, kw.y, -0.05, 0.02, kw.h, 0.02));
      B.add("sockel", boxGeo(o.x - 0.1, 0.0, 0, o.w + 0.2, 0.08, 0.06));
      return;
    }
    if (o.kind === "door" || o.kind === "pubdoor") {
      // reveal is done by the wall; the door leaves sit 0.3 m back
      const z = -o.depth + 0.08;
      const spring = o.y + o.h - (o.arch === "round" ? o.w / 2 : o.w * 0.16);
      const dh = spring - o.y - 0.25;
      const doorKey = o.kind === "pubdoor" ? "doorGreen" : r.pick(["doorWood", "doorWood", "doorGreen"]);
      const leaves = o.w > 1.2 ? 2 : 1;
      const lw = o.w / leaves;
      for (let k = 0; k < leaves; k++) {
        const lx = o.x + k * lw;
        B.add(doorKey, boxGeo(lx + 0.02, o.y, z, lw - 0.04, dh, 0.06));
        // raised panels: two tall over one short, with a glazed upper panel in pub doors
        const pw = lw - 0.3;
        B.add(doorKey, boxGeo(lx + 0.15, o.y + 0.25, z + 0.06, pw, 0.5, 0.03));
        if (o.kind === "pubdoor") B.add("glass", boxGeo(lx + 0.15, o.y + 1.0, z + 0.065, pw, dh - 1.25, 0.005));
        else {
          B.add(doorKey, boxGeo(lx + 0.15, o.y + 0.95, z + 0.06, pw, dh - 1.2, 0.03));
          B.add(doorKey, boxGeo(lx + 0.22, o.y + 1.05, z + 0.09, pw - 0.14, dh - 1.4, 0.02));
        }
        B.add("gold", boxGeo(lx + (k === 0 ? lw - 0.12 : 0.06), o.y + 1.0, z + 0.06, 0.05, 0.25, 0.05));
      }
      // transom and a fanlight with an iron sunburst
      B.add(doorKey, boxGeo(o.x, spring - 0.25, z, o.w, 0.25, 0.08));
      const fan = new THREE.Shape(); const pts = openingOutline(o).slice(2);
      fan.moveTo(o.x, spring); pts.forEach(p => fan.lineTo(p[0], Math.max(p[1], spring)));
      const fg = new THREE.ShapeGeometry(fan, 3); fg.translate(0, 0, z + 0.01); B.add("glass", fg.toNonIndexed());
      const cx = o.x + o.w / 2;
      for (let k = 1; k < 8; k++) {
        const a = Math.PI * k / 8, R = o.arch === "round" ? o.w / 2 : o.w * 0.5;
        const bar = new THREE.BoxGeometry(0.025, R, 0.02); bar.translate(0, R / 2, 0); bar.rotateZ(Math.PI / 2 - a); bar.translate(cx, spring, z + 0.03);
        B.add("iron", bar.toNonIndexed());
      }
      // stone surround with a keystone; a step in front
      frameAround(B, "orn", o, 0.22);
      if (o.arch) keystone(B, "orn", { ...o, h: o.h + 0.05 });
      B.add("sockel", boxGeo(o.x - 0.1, -0.12, 0, o.w + 0.2, 0.14, 0.32));
      if (o.kind === "pubdoor") {
        const name = L.pubName || "Zur Kette";
        const sg = new THREE.PlaneGeometry(2.4, 0.36); sg.translate(o.x + o.w / 2, o.y + o.h + 0.42, 0.08);
        B.add("sign:" + name + "|pub", sg);
        B.add("frameDark", boxGeo(o.x + o.w / 2 - 1.25, o.y + o.h + 0.2, 0, 2.5, 0.44, 0.07));
      }
      return;
    }
    if (o.kind === "shop") {
      const z = -o.depth + 0.05;
      const frameKey = r.pick(["frameDark", "frameDark", "frameBrown", "frame"]);
      // stall riser, frame, a door on one side, big display panes
      B.add(frameKey, boxGeo(o.x, o.y, z - 0.02, o.w, 0.55, 0.1));
      B.add(frameKey, boxGeo(o.x, o.y, z - 0.03, 0.09, o.h, 0.12));
      B.add(frameKey, boxGeo(o.x + o.w - 0.09, o.y, z - 0.03, 0.09, o.h, 0.12));
      B.add(frameKey, boxGeo(o.x, o.y + o.h - 0.5, z - 0.03, o.w, 0.08, 0.12));
      const doorLeft = r.chance(0.5), dw = 0.95;
      const dx = doorLeft ? o.x + 0.09 : o.x + o.w - 0.09 - dw;
      B.add(frameKey, boxGeo(dx + (doorLeft ? dw : -0.07), o.y, z - 0.03, 0.07, o.h - 0.5, 0.1));
      // door with glass
      B.add(frameKey, boxGeo(dx, o.y, z - 0.08, dw, 0.12, 0.05));
      B.add("shopGlass", boxGeo(dx + 0.08, o.y + 0.12, z - 0.07, dw - 0.16, o.h - 0.75, 0.01));
      const gx0 = doorLeft ? dx + dw + 0.07 : o.x + 0.09, gx1 = doorLeft ? o.x + o.w - 0.09 : dx - 0.07;
      B.add("shopGlass", boxGeo(gx0, o.y + 0.55, z - 0.0, gx1 - gx0, o.h - 1.05, 0.01));
      B.add("shopGlass", boxGeo(o.x + 0.09, o.y + o.h - 0.42, z, o.w - 0.18, 0.34, 0.01));
      // the shop inside: a lit back wall a metre and a half in
      B.add("shopInterior", boxGeo(o.x, o.y, z - 1.6, o.w, o.h, 0.02));
      for (const sx of [o.x, o.x + o.w]) { const pg = new THREE.PlaneGeometry(1.6, o.h); pg.rotateY(sx === o.x ? Math.PI / 2 : -Math.PI / 2); pg.translate(sx, o.y + o.h / 2, z - 0.8); B.add("shopInterior", pg); }
      { const pg = new THREE.PlaneGeometry(o.w, 1.6); pg.rotateX(-Math.PI / 2); pg.translate(o.x + o.w / 2, o.y, z - 0.8); B.add("shopInterior", pg); }
      // shelves suggested by a few dark boxes
      for (let k = 0; k < 3; k++) B.add("frameBrown", boxGeo(o.x + 0.2, o.y + 0.7 + k * 0.6, z - 1.55, o.w - 0.4, 0.04, 0.35));
      // signboard (fascia) over the shop with its name
      const name = this.shopName(r);
      if (name) {
        const sg = new THREE.PlaneGeometry(Math.min(o.w + 0.3, 3.2), 0.5);
        sg.translate(o.x + o.w / 2, o.y + o.h + 0.42, 0.07);
        B.add("sign:" + name.text + "|" + name.style, sg);
        B.add(frameKey, boxGeo(o.x + o.w / 2 - Math.min(o.w + 0.3, 3.2) / 2 - 0.04, o.y + o.h + 0.13, 0.0, Math.min(o.w + 0.3, 3.2) + 0.08, 0.58, 0.065));
      }
      // awning over some shops
      if (r.chance(0.35)) {
        const aw = r.pick(["awningRed", "awningGreen", "awningCream"]);
        const len = 1.3, drop = 0.55;
        const ag = new THREE.PlaneGeometry(o.w + 0.2, Math.hypot(len, drop));
        ag.rotateX(-Math.PI / 2 + Math.atan2(drop, len)); ag.translate(o.x + o.w / 2, o.y + o.h + 0.05 - drop / 2, len / 2 + 0.05);
        B.add(aw, ag);
        const val = new THREE.PlaneGeometry(o.w + 0.2, 0.22); val.translate(o.x + o.w / 2, o.y + o.h - drop - 0.06, len + 0.05); B.add(aw, val);
        B.add("iron", boxGeo(o.x - 0.1, o.y + o.h + 0.02, 0, o.w + 0.2, 0.08, 0.1));
      }
    }
  }

  shopName(r) {
    const pool = SHOPS;
    if (!pool.length) return null;
    return pool.splice(Math.floor(r.next() * pool.length), 1)[0];
  }

  // a window on an upper floor with its ornament by floor and style
  upperWindow(B, o, T, r, S) {
    const rich = S === "rich" || S === "corner", stripped = S === "stripped", nouveau = S === "nouveau";
    const kind = o.floor.kind;
    const local = new Bucket();
    windowUnit(local, o, r, { bars: false, frameKey: this.frameKey });
    if (stripped) {
      local.add("orn", boxGeo(o.x - 0.06, o.y - 0.07, 0, o.w + 0.12, 0.07, 0.08));
    } else {
      const ears = rich && (kind === "bel" || kind === "second");
      frameAround(local, "orn", o, kind === "top" ? 0.11 : 0.15, ears);
      if (o.kind !== "balcony") local.add("orn", sweep(PROFILE.sill(0.7), straight(o.x - 0.12, o.x + o.w + 0.12, o.y - 0.1)));
      const headY = o.y + o.h + 0.17;
      if (kind === "bel") {
        if (rich) pediment(local, "orn", o, o.axis % 2 ? "seg" : "tri", headY);
        else if (!nouveau) pediment(local, "orn", o, "flat", headY);
        if (o.kind !== "balcony" && (rich || nouveau)) apron(local, "orn", o, 0.5);
      } else if (kind === "second") {
        if (rich || S === "moderate" || S === "brick") pediment(local, "orn", o, "flat", headY);
        if (rich && o.kind !== "balcony") apron(local, "orn", o, 0.45);
      } else if (kind === "third") {
        if (!o.arch) keystone(local, "orn", o);
      }
      if (nouveau && kind !== "top" && o.kind !== "balcony") {
        // Jugendstil: a relief disc with radiating leaves over the window
        const cx = o.x + o.w / 2, cy = o.y + o.h + 0.45;
        const disc = new THREE.CylinderGeometry(0.2, 0.22, 0.05, 16); disc.rotateX(Math.PI / 2); disc.translate(cx, cy, 0.025); local.add("orn", disc.toNonIndexed());
        for (let k = -2; k <= 2; k++) { const leaf = new THREE.SphereGeometry(0.16, 8, 6); leaf.scale(1, 0.35, 0.25); leaf.rotateZ(k * 0.35); leaf.translate(cx + k * 0.25, cy - 0.05 - Math.abs(k) * 0.08, 0.02); local.add("orn", leaf.toNonIndexed()); }
      }
    }
    for (const [k, list] of local.parts) for (const g of list) { g.applyMatrix4(T); B.add(k, g); }
  }

  // a balcony slab on consoles with a railing; style "stone" gives a balustrade
  balcony(B, x0, x1, y, z0, style, r) {
    const d = 1.05, t = 0.16;
    B.add("orn", sweep([[0, 0], [d, 0], [d, 0.04], [d + 0.03, 0.07], [d + 0.03, t], [0, t]], straight(x0, x1, y - t)).applyMatrix4(new THREE.Matrix4().makeTranslation(0, 0, z0)));
    // consoles
    const nC = Math.max(2, Math.round((x1 - x0) / 1.1));
    for (let k = 0; k < nC; k++) {
      const cx = x0 + 0.15 + k * ((x1 - x0 - 0.45) / (nC - 1));
      const c = consoleGeo(cx, y - t - 0.55, 0.16, 0.55, d * 0.8); c.translate(0, 0, z0); B.add("orn", c);
    }
    if (style === "stone") {
      balustrade(B, "orn", x0 + 0.05, x1 - 0.05, y, 0.95, z0 + d - 0.12);
      // side balustrades
      const side = new Bucket(); balustrade(side, "orn", 0.1, d - 0.15, y, 0.95, 0);
      for (const [k, list] of side.parts) for (const g of list) {
        for (const xe of [x0 + 0.12, x1 - 0.12]) {
          const c = g.clone(); c.rotateY(-Math.PI / 2); c.translate(xe, 0, z0); B.add(k, c);
        }
      }
    } else {
      const h = 1.0;
      const front = new THREE.PlaneGeometry(x1 - x0, h); front.translate((x0 + x1) / 2, y + h / 2, z0 + d - 0.05);
      const uv = front.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * (x1 - x0) / 2, uv.getY(i));
      B.add(style, front);
      for (const xe of [x0 + 0.04, x1 - 0.04]) {
        const sg = new THREE.PlaneGeometry(d - 0.05, h); sg.rotateY(Math.PI / 2); sg.translate(xe, y + h / 2, z0 + (d - 0.05) / 2);
        const u2 = sg.attributes.uv; for (let i = 0; i < u2.count; i++) u2.setXY(i, u2.getX(i) * d / 2, u2.getY(i));
        B.add(style, sg);
      }
      B.add("iron", boxGeo(x0, y + h - 0.02, z0 + d - 0.09, x1 - x0, 0.05, 0.08));
      B.add("iron", boxGeo(x0, y + h - 0.02, z0, 0.06, 0.05, d));
      B.add("iron", boxGeo(x1 - 0.06, y + h - 0.02, z0, 0.06, 0.05, d));
      // flower boxes on some balconies
      if (r.chance(0.4)) {
        B.add("frameBrown", boxGeo(x0 + 0.3, y + h - 0.25, z0 + d - 0.02, Math.min(1.2, x1 - x0 - 0.6), 0.2, 0.2));
        for (let k = 0; k < 6; k++) {
          const s = new THREE.IcosahedronGeometry(r.range(0.1, 0.17), 0); s.translate(x0 + 0.4 + k * 0.18, y + h - 0.02, z0 + d + 0.08);
          B.add(r.chance(0.3) ? "awningRed" : "grassDark", s.toNonIndexed());
        }
      }
    }
  }

  // a bay window (Erker) carried on a corbel, from the Beletage to the third floor
  erker(B, e, xs, ww, r, S) {
    const P = this.plan, f1 = P.floors[1], fT = P.floors[4];
    const y0 = f1.y0 - 0.1, y1 = fT.y0, d = e.proj, x0 = e.x0, x1 = e.x1;
    const wallKey = this.scheme.brick ? "brick" : "wall";
    // openings on the front, per floor
    const openings = [];
    for (const f of P.floors.slice(1, 4)) {
      for (let i = e.i0; i <= e.i1; i++) {
        const hgt = { bel: 2.6, second: 2.4, third: 2.25 }[f.kind] * (P.floors[1].h / 4.05);
        openings.push({ x: xs[i] - ww / 2, y: f.y0 + 0.88, w: ww, h: hgt, depth: 0.2, floor: f, axis: i, kind: "window" });
      }
    }
    const [ff, fr] = wallWithOpenings(x0, y0, x1, y1, openings, d);
    addUV(B, wallKey, ff, null, wallKey === "brick" ? [2, 1] : 2); addUV(B, wallKey, fr, null, 2);
    // sides with a narrow window each floor
    for (const side of [0, 1]) {
      const sideOpen = [];
      for (const f of P.floors.slice(1, 4)) sideOpen.push({ x: 0.22, y: f.y0 + 0.88, w: 0.42, h: 2.0 * (P.floors[1].h / 4.05), depth: 0.15, kind: "window" });
      const [sf, sr] = wallWithOpenings(0, y0, d, y1, sideOpen, 0);
      const sideB = new Bucket();
      addUV(sideB, wallKey, sf, null, 2); addUV(sideB, wallKey, sr, null, 2);
      for (const o of sideOpen) { windowUnit(sideB, o, r, { curtains: false }); frameAround(sideB, "orn", o, 0.08); }
      const Mside = new THREE.Matrix4();
      if (side === 0) Mside.makeRotationY(-Math.PI / 2).setPosition(x0, 0, 0);      // left side faces -x
      else Mside.makeRotationY(Math.PI / 2).setPosition(x1, 0, d);                    // right side faces +x
      for (const [k, list] of sideB.parts) for (const g of list) { g.applyMatrix4(Mside); B.add(k, g); }
    }
    const T = new THREE.Matrix4().makeTranslation(0, 0, d);
    for (const o of openings) this.upperWindow(B, { ...o }, T, r, S === "stripped" ? "moderate" : S);
    // floor bands around the bay
    const band = (y, prof) => {
      const path = [[x0 - 0.001, y], [x1 + 0.001, y]];
      const g = sweep(prof, path); g.translate(0, 0, d); B.add("orn", g);
      for (const [xe, rot] of [[x0, -Math.PI / 2], [x1, Math.PI / 2]]) {
        const s2 = sweep(prof, [[0, y], [d, y]]);
        if (rot < 0) { s2.applyMatrix4(new THREE.Matrix4().makeRotationY(-Math.PI / 2)); s2.translate(xe, 0, 0); }
        else { s2.applyMatrix4(new THREE.Matrix4().makeRotationY(Math.PI / 2)); s2.translate(xe, 0, d); }
        B.add("orn", s2);
      }
    };
    for (const f of P.floors.slice(2, 4)) band(f.y0 - 0.05, PROFILE.belt(0.6));
    // underside: corbel of stepped stone and two big consoles
    for (let k = 0; k < 4; k++) {
      const inset = k * 0.12;
      B.add("orn", boxGeo(x0 + inset, y0 - (k + 1) * 0.16, 0, x1 - x0 - 2 * inset, 0.16, d - inset * 1.2));
    }
    B.add("orn", consoleGeo(x0 + 0.1, y0 - 1.3, 0.25, 0.8, d * 0.9));
    B.add("orn", consoleGeo(x1 - 0.35, y0 - 1.3, 0.25, 0.8, d * 0.9));
    // top: a slab and a railing (the top-floor flat gets a balcony)
    B.add("orn", sweep(PROFILE.belt(0.8), straight(x0 - 0.05, x1 + 0.05, y1 - 0.25)).translate(0, 0, d));
    B.add("orn", boxGeo(x0 - 0.05, y1 - 0.05, 0, x1 - x0 + 0.1, 0.12, d + 0.08));
    const rail = S === "nouveau" ? "railNouveau" : "railScroll";
    const fr2 = new THREE.PlaneGeometry(x1 - x0, 1.0); fr2.translate((x0 + x1) / 2, y1 + 0.57, d + 0.02);
    const u = fr2.attributes.uv; for (let i = 0; i < u.count; i++) u.setXY(i, u.getX(i) * (x1 - x0) / 2, u.getY(i));
    B.add(rail, fr2);
    B.add("iron", boxGeo(x0, y1 + 1.05, d - 0.02, x1 - x0, 0.05, 0.07));
  }

  // ---------------------------------------------------------------- roof, rear, ends
  buildRoofAndBody() {
    const L = this.lot, P = this.plan, r = this.rng;
    const D = L.depth || 13;
    const E = P.eave;
    // outline of the building at the eaves: along each facade, then the rear
    const outer = [], inner = [];
    for (const s of L.segments) {
      const a = new THREE.Vector3(s.along.x, 0, s.along.z).normalize();
      outer.push(s.origin.clone(), s.origin.clone().addScaledVector(a, s.width));
    }
    // inner (rear) line: offset the non-chamfer facade lines by D
    const lines = L.segments.filter(s => !s.chamfer).map(s => {
      const a = new THREE.Vector3(s.along.x, 0, s.along.z).normalize();
      const n = new THREE.Vector3().crossVectors(a, new THREE.Vector3(0, 1, 0));   // out
      const o = s.origin.clone().addScaledVector(n, -D);
      return { o, a, w: s.width };
    });
    if (lines.length === 1) {
      const l = lines[0];
      inner.push(l.o.clone().addScaledVector(l.a, l.w), l.o.clone());
    } else {
      const l1 = lines[0], l2 = lines[lines.length - 1];
      // intersection of the two offset lines
      const d = l1.a.x * l2.a.z - l1.a.z * l2.a.x;
      const t = ((l2.o.x - l1.o.x) * l2.a.z - (l2.o.z - l1.o.z) * l2.a.x) / d;
      const X = l1.o.clone().addScaledVector(l1.a, t);
      inner.push(l2.o.clone().addScaledVector(l2.a, l2.w), X, l1.o.clone());
    }
    // dedupe consecutive outer points
    const poly = [];
    for (const p of [...outer, ...inner]) if (!poly.length || poly[poly.length - 1].distanceTo(p) > 0.01) poly.push(p);
    if (poly[0].distanceTo(poly[poly.length - 1]) < 0.01) poly.pop();
    this.footprint = poly;

    // rear wall(s) and end walls (party walls / exposed firewalls) up to the eaves
    const rearN = inner.length - 1;
    for (let i = 0; i < inner.length - 1; i++) this.plainWall(inner[i], inner[i + 1], E - 0.4, "rear");
    // ends: from the last outer point to the first inner point, and from the last inner to the first outer
    this.plainWall(outer[outer.length - 1], inner[0], E, "end");
    this.plainWall(inner[inner.length - 1], outer[0], E, "end");

    const roofType = L.roof || (L.segments.length > 1 ? "mansard" : r.pick(["pitched", "pitched", "mansard"]));
    if (roofType === "mansard" || L.segments.length > 1) this.mansardRoof(poly, E, r);
    else this.pitchedRoof(lines[0], D, E, r);

    // side wing into the courtyard on many lots
    if (L.segments.length === 1 && r.chance(0.7)) {
      const l = lines[0];
      const left = r.chance(0.5);
      const ww = 6.5, len = r.range(10, 18);
      const n = new THREE.Vector3().crossVectors(l.a, new THREE.Vector3(0, 1, 0));
      const o = left ? l.o.clone() : l.o.clone().addScaledVector(l.a, l.w - ww);
      const h = E - P.floors[4].h * (r.chance(0.5) ? 1 : 0);
      const c0 = o, c1 = o.clone().addScaledVector(l.a, ww), c2 = c1.clone().addScaledVector(n, -len), c3 = o.clone().addScaledVector(n, -len);
      this.plainWall(c1, c2, h, left ? "rear" : "end");
      this.plainWall(c2, c3, h, "rear");
      this.plainWall(c3, c0, h, left ? "end" : "rear");
      // single-pitch roof falling toward the courtyard
      const rise = 2.2;
      const hi = left ? [c0, c3] : [c1, c2];
      const lo = left ? [c1, c2] : [c0, c3];
      const g = new THREE.BufferGeometry();
      const v = (p, y) => [p.x, y, p.z];
      g.setAttribute("position", new THREE.Float32BufferAttribute([
        ...v(hi[0], h + rise), ...v(lo[0], h), ...v(lo[1], h), ...v(hi[0], h + rise), ...v(lo[1], h), ...v(hi[1], h + rise)], 3));
      orientUp(g); g.computeVertexNormals(); boxUV(g, 2);
      SHARED.add("tiles", g);
    }
  }

  plainWall(p0, p1, h, kind) {
    const len = p0.distanceTo(p1);
    if (len < 0.05) return;
    const a = p1.clone().sub(p0).normalize();
    const M = facadeMatrix(p0, a);
    const B = new Bucket();
    if (kind === "rear") {
      // a plain courtyard facade: a grid of simple windows, staircase windows offset
      const P = this.plan, r = this.rng;
      const openings = [];
      const n = Math.floor((len - 1) / 3.2);
      for (let i = 0; i < n; i++) {
        const x = (len - (n - 1) * 3.2) / 2 + i * 3.2;
        for (const f of P.floors) {
          if (f.y0 + 3 > h) continue;
          openings.push({ x: x - 0.6, y: f.y0 + 0.9, w: 1.2, h: 1.9, depth: 0.2, kind: "window" });
        }
      }
      const [wf, wr] = wallWithOpenings(0, 0, len, h, openings);
      addUV(B, "rearWall", wf, null, 2); addUV(B, "rearWall", wr, null, 2);
      for (const o of openings) windowUnit(B, o, r, { curtains: r.chance(0.5) });
    } else {
      const g = new THREE.PlaneGeometry(len, h); g.translate(len / 2, h / 2, 0);
      addUV(B, "firewall", g, null, 2);
    }
    for (const [k, geo] of B.merge()) { geo.applyMatrix4(M); SHARED.add(k, geo); }
  }

  // steep lower slopes all round, flat top: works for any outline (corner houses)
  mansardRoof(poly, E, r) {
    const rise = 3.4, run = 1.1;
    const inset = insetPolygon(poly, run);
    const pos = [];
    for (let i = 0; i < poly.length; i++) {
      const a = poly[i], b = poly[(i + 1) % poly.length], c = inset[(i + 1) % poly.length], d = inset[i];
      pos.push(a.x, E, a.z, b.x, E, b.z, c.x, E + rise, c.z, a.x, E, a.z, c.x, E + rise, c.z, d.x, E + rise, d.z);
    }
    const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
    orientOut(g, poly); g.computeVertexNormals(); boxUV(g, 2);
    SHARED.add(this.lot.cond > 0.75 ? "slate" : r.pick(["slate", "slate", "tiles"]), g);
    // flat top in zinc
    const shape = new THREE.Shape(inset.map(p => new THREE.Vector2(p.x, -p.z)));
    const top = new THREE.ShapeGeometry(shape); top.rotateX(-Math.PI / 2); top.translate(0, E + rise, 0);
    const tg = top.toNonIndexed(); orientUp(tg); tg.computeVertexNormals(); boxUV(tg, 2);
    SHARED.add("zinc", tg);
    // dormers on the street slopes, one per window axis on alternate axes
    for (const s of this.segs) {
      if (s.seg.chamfer) continue;
      s.xs.forEach((x, i) => { if (i % 2 === (s.xs.length % 2 ? 0 : 1) || s.xs.length <= 3) this.dormer(s, x, E, rise, run, "mansard"); });
    }
    this.chimneys(poly, E + rise, r);
    if (this.lot.tower) this.cornerTower(r);
  }

  pitchedRoof(l, D, E, r) {
    const pitch = r.range(36, 44) * Math.PI / 180;
    const half = D / 2, rise = half * Math.tan(pitch);
    const n = new THREE.Vector3().crossVectors(l.a, new THREE.Vector3(0, 1, 0));
    const F0 = l.o.clone().addScaledVector(n, D), F1 = F0.clone().addScaledVector(l.a, l.w);  // front eave line
    const R0 = l.o.clone(), R1 = l.o.clone().addScaledVector(l.a, l.w);                        // rear eave line
    const K0 = l.o.clone().addScaledVector(n, half), K1 = K0.clone().addScaledVector(l.a, l.w); // ridge
    const v = (p, y) => [p.x, y, p.z];
    const pos = [
      ...v(F0, E), ...v(F1, E), ...v(K1, E + rise), ...v(F0, E), ...v(K1, E + rise), ...v(K0, E + rise),
      ...v(R1, E), ...v(R0, E), ...v(K0, E + rise), ...v(R1, E), ...v(K0, E + rise), ...v(K1, E + rise),
    ];
    const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
    orientUp(g); g.computeVertexNormals(); boxUV(g, 2);
    SHARED.add(r.chance(0.7) ? "tiles" : "slate", g);
    // gable ends: firewalls standing a little proud of the roof
    for (const [a, b, k] of [[F0, R0, K0], [F1, R1, K1]]) {
      const gg = new THREE.BufferGeometry();
      gg.setAttribute("position", new THREE.Float32BufferAttribute([...v(a, E), ...v(b, E), ...v(k, E + rise + 0.3), ...v(b, E), ...v(a, E), ...v(k, E + rise + 0.3)], 3));
      gg.computeVertexNormals(); boxUV(gg, 2); SHARED.add("firewall", gg);
    }
    // dormers on the street side
    const s = this.segs[0];
    s.xs.forEach((x, i) => { if (i % 2 === 1 || s.xs.length <= 3) this.dormer(s, x, E, rise, half, "pitched"); });
    this.chimneys([F0, F1, R1, R0], E + rise * 0.7, r, K0, K1);
  }

  // a dormer whose window sits on the roof slope above axis x
  dormer(s, x, E, rise, run, type) {
    const B = new Bucket();
    const back = type === "mansard" ? 0.55 : 1.4;               // how far up the slope the front sits
    const y0 = E + back * (rise / run) - 0.2;
    const w = 1.1, h = 1.45, z0 = -back;
    const o = { x: x - w / 2, y: y0 + 0.15, w, h: h - 0.3, depth: 0.12, kind: "window" };
    const [f, rv] = wallWithOpenings(x - w / 2 - 0.15, y0, x + w / 2 + 0.15, y0 + h, [o], 0);
    addUV(B, "zinc", f, null, 2); addUV(B, "zinc", rv, null, 2);
    windowUnit(B, o, this.rng, { curtains: false });
    // cheeks and a little roof
    const dep = 1.6;
    for (const xe of [x - w / 2 - 0.15, x + w / 2 + 0.15]) { const c = boxGeo(xe - 0.03, y0, -dep, 0.06, h, dep); B.add("zinc", c); }
    if (type === "pitched") {
      // a small gabled roof in tiles, with a zinc-clad pediment
      const hw = w / 2 + 0.3, ridge = 0.7, yT = y0 + h;
      const v = (px, py, pz) => [px, py, pz];
      const pos = [];
      for (const s of [-1, 1]) {
        const e = x + s * hw;
        pos.push(...v(e, yT, 0.15), ...v(x, yT + ridge, 0.15), ...v(x, yT + ridge, -dep), ...v(e, yT, 0.15), ...v(x, yT + ridge, -dep), ...v(e, yT, -dep));
      }
      const rg = new THREE.BufferGeometry(); rg.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
      orientUp(rg); rg.computeVertexNormals(); boxUV(rg, 2); B.add("tiles", rg);
      const tri = new THREE.Shape([new THREE.Vector2(x - w / 2 - 0.15, yT), new THREE.Vector2(x + w / 2 + 0.15, yT), new THREE.Vector2(x, yT + ridge - 0.05)]);
      const tg = new THREE.ShapeGeometry(tri); tg.translate(0, 0, 0.01); B.add("zinc", tg.toNonIndexed());
    } else {
      const roof = new THREE.BoxGeometry(w + 0.5, 0.08, dep + 0.2); roof.translate(x, y0 + h + 0.05, -dep / 2 + 0.05);
      B.add("zinc", roof);
    }
    const M = facadeMatrix(s.seg.origin, s.seg.along);
    const T = new THREE.Matrix4().makeTranslation(0, 0, z0);
    for (const [k, geo] of B.merge()) { geo.applyMatrix4(T); geo.applyMatrix4(M); SHARED.add(k, geo); }
  }

  chimneys(poly, yTop, r, k0, k1) {
    // stoves in every room: Berlin roofs bristle with chimneys
    const c = new THREE.Vector3(); poly.forEach(p => c.add(p)); c.divideScalar(poly.length);
    const N = Math.max(2, Math.round(this.lot.segments.reduce((s, x) => s + x.width, 0) / 4));
    for (let i = 0; i < N; i++) {
      let p;
      if (k0) p = k0.clone().lerp(k1, (i + 0.5) / N).add(new THREE.Vector3(r.range(-0.6, 0.6), 0, r.range(-0.6, 0.6)));
      else { const a = poly[i % poly.length], b = poly[(i + 1) % poly.length]; p = a.clone().lerp(b, r.range(0.2, 0.8)).lerp(c, r.range(0.25, 0.45)); }
      const h = r.range(1.2, 2.0), w = r.range(0.5, 0.9), d = 0.5;
      const g = boxGeo(-w / 2, 0, -d / 2, w, h + 1.5, d); g.translate(p.x, yTop - 1.5, p.z); boxUV(g, 1);
      SHARED.add("chimney", g);
      const cap = boxGeo(-w / 2 - 0.06, h - 0.1, -d / 2 - 0.06, w + 0.12, 0.1, d + 0.12); cap.translate(p.x, yTop - 1.5 + 1.5, p.z);
      SHARED.add("granite", boxUV(cap, 1));
    }
  }

  // the corner tower: an octagonal oriel over the chamfer, rising above the eaves to a copper dome
  cornerTower(r) {
    const ch = this.segs.find(s => s.seg.chamfer);
    if (!ch) return;
    const P = this.plan, s = ch.seg;
    const a = new THREE.Vector3(s.along.x, 0, s.along.z).normalize();
    const n = new THREE.Vector3().crossVectors(a, new THREE.Vector3(0, 1, 0));
    const c = s.origin.clone().addScaledVector(a, s.width / 2).addScaledVector(n, 0.6);
    const R = s.width / 2 + 0.25;
    const y0 = P.floors[1].y0 - 0.2, y1 = P.eave + 6.4;
    const sides = 8, ang0 = Math.atan2(n.z, n.x);
    const B = new Bucket();
    // octagon walls with windows: built as eight little facades
    for (let k = 0; k < sides; k++) {
      const a0 = ang0 + (k - sides / 2 + 0.5) * Math.PI * 2 / sides - Math.PI / sides, a1 = a0 + Math.PI * 2 / sides;
      const p0 = new THREE.Vector3(c.x + Math.cos(a0) * R, 0, c.z + Math.sin(a0) * R);
      const p1 = new THREE.Vector3(c.x + Math.cos(a1) * R, 0, c.z + Math.sin(a1) * R);
      const mid = p0.clone().add(p1).multiplyScalar(0.5);
      // faces looking into the building only show above the roof
      const buried = mid.clone().sub(c).dot(n) < -0.3;
      const fa = p1.clone().sub(p0); const fw = fa.length(); fa.normalize();
      // facadeMatrix wants along = direction such that out = along x up points away from c
      const outTest = new THREE.Vector3().crossVectors(fa, new THREE.Vector3(0, 1, 0));
      let o = p0, al = fa;
      if (outTest.dot(mid.clone().sub(c)) < 0) { o = p1; al = fa.clone().negate(); }
      const M = facadeMatrix(o, al);
      const LB = new Bucket();
      const ops = [];
      if (!buried) for (const f of P.floors.slice(1)) ops.push({ x: fw / 2 - 0.42, y: f.y0 + 0.9, w: 0.84, h: 2.1 * (P.floors[1].h / 4.05), depth: 0.2, kind: "window", floor: f });
      ops.push({ x: fw / 2 - 0.33, y: P.eave + 3.75, w: 0.66, h: 1.75, arch: "round", depth: 0.2, kind: "window" });
      if (!buried) ops.push({ x: fw / 2 - 0.4, y: P.eave + 0.6, w: 0.8, h: 1.9, depth: 0.2, kind: "window" });
      const [tf, tr] = wallWithOpenings(0, buried ? P.eave + 3.2 : y0, fw, y1, ops);
      addUV(LB, "wall", tf, null, 2); addUV(LB, "wall", tr, null, 2);
      for (const op of ops) { windowUnit(LB, op, r, { curtains: false }); frameAround(LB, "orn", op, 0.08); }
      if (!buried) {
        for (const f of P.floors.slice(2)) LB.add("orn", sweep(PROFILE.belt(0.5), straight(-0.02, fw + 0.02, f.y0 - 0.1)));
        LB.add("orn", sweep(PROFILE.main(0.7), straight(-0.05, fw + 0.05, P.wallTop)));
      }
      LB.add("orn", sweep(PROFILE.belt(0.6), straight(-0.04, fw + 0.04, P.eave + 3.35)));
      LB.add("orn", sweep(PROFILE.cap(1.2), straight(-0.05, fw + 0.05, y1 - 0.25)));
      for (const [k, list] of LB.parts) for (const g of list) { g.applyMatrix4(M); B.add(k, g); }
    }
    // corbel under the oriel
    const corbel = new THREE.LatheGeometry([[0, -0.75], [R * 0.32, -0.75], [R * 0.36, -0.62], [R * 0.5, -0.55], [R * 0.62, -0.38], [R * 0.66, -0.3],
      [R * 0.82, -0.18], [R * 0.95, -0.1], [R * 1.02, -0.04], [R * 1.02, 0.02], [0, 0.02]].map(p => new THREE.Vector2(p[0], p[1])), sides);
    corbel.rotateY(Math.PI / sides); corbel.translate(c.x, y0, c.z);
    B.add("orn", corbel.toNonIndexed());
    // the dome: an ogee bell in copper with a lantern and a finial
    const prof = [];
    for (let i = 0; i <= 16; i++) {
      const t = i / 16;
      const rr = R * (1.06 - 0.95 * Math.pow(t, 1.4)) + Math.sin(t * Math.PI) * 0.35 * (1 - t);
      prof.push(new THREE.Vector2(Math.max(0.12, rr), t * 4.2));
    }
    const dome = new THREE.LatheGeometry(prof, sides * 2); dome.translate(c.x, y1, c.z); boxUV(dome, 2);
    SHARED.add("copper", dome.toNonIndexed());
    const lantern = new THREE.CylinderGeometry(0.35, 0.4, 1.2, 8); lantern.translate(c.x, y1 + 4.6, c.z); SHARED.add("copper", boxUV(lantern.toNonIndexed(), 1));
    const knob = new THREE.SphereGeometry(0.22, 10, 8); knob.translate(c.x, y1 + 5.45, c.z); SHARED.add("gold", knob.toNonIndexed());
    const spike = new THREE.ConeGeometry(0.06, 1.4, 6); spike.translate(c.x, y1 + 6.2, c.z); SHARED.add("gold", spike.toNonIndexed());
    // this tower's wall pieces use the chamfer facade's own weathered materials
    const chMat = facadeMaterials(this.scheme, { map: grimeTexture({ width: 6, height: y1 + 1, windows: [], ledges: [P.wallTop], cond: this.lot.cond }, r), origin: c.clone().addScaledVector(a, -3), along: a, width: 6, height: y1 + 1 });
    for (const [k, geo] of B.merge()) {
      if (SEG_KEYS.has(k)) { const m = new THREE.Mesh(geo, chMat[k] || chMat.wall); m.castShadow = m.receiveShadow = true; this.group.add(m); }
      else SHARED.add(k, geo);
    }
  }

  // ---------------------------------------------------------------- a 1980s infill block
  // (Lückenbau): concrete panels, window bands, flat roof, six storeys under the old eaves
  buildInfill() {
    const L = this.lot, r = this.rng, s = L.segments[0], W = s.width;
    const M = facadeMatrix(s.origin, s.along);
    const B = new Bucket();
    const fh = 2.9, nF = 7, H = fh * nF + 0.6;
    this.plan = { floors: Array.from({ length: nF }, (_, i) => ({ y0: i * fh, h: fh })), eave: H, wallTop: H };
    const ops = [];
    const nx = Math.floor(W / 2.4);
    for (let f = 1; f < nF; f++) for (let i = 0; i < nx; i++) ops.push({ x: 0.6 + i * (W - 1.2) / nx + 0.25, y: f * fh + 0.85, w: (W - 1.2) / nx - 0.5, h: 1.45, depth: 0.12, kind: "window" });
    const shop = { x: 1, y: 0.1, w: W - 2, h: 2.6, depth: 0.2, kind: "shop" };
    const [wf, wr] = wallWithOpenings(0, 0, W, H, [...ops, shop]);
    addUV(B, "wall", wf, null, 2); addUV(B, "wall", wr, null, 2);
    for (const o of ops) {
      windowUnit(B, o, r, { frameKey: "paintWhite", curtains: true });
    }
    B.add("shopGlass", boxGeo(shop.x, shop.y, -0.18, shop.w, shop.h, 0.02));
    B.add("frameDark", boxGeo(shop.x - 0.05, shop.y + shop.h, 0, shop.w + 0.1, 0.5, 0.06));
    // panel joints
    for (let f = 1; f <= nF; f++) B.add("frameDark", boxGeo(0, f * fh - 0.01, 0.005, W, 0.02, 0.01));
    for (let x = 0.6; x < W; x += (W - 1.2) / nx) B.add("frameDark", boxGeo(x - 0.01, fh, 0.005, 0.02, H - fh, 0.01));
    const sign = new THREE.PlaneGeometry(Math.min(W - 2, 6), 0.4); sign.translate(W / 2, shop.h + 0.35, 0.07); B.add("sign:Kaufhalle|gdr", sign);
    const scheme = { wall: "#c4bba8", orn: "#c4bba8", base: "#a59d8c" };
    const grime = { map: grimeTexture({ width: W, height: H, windows: ops.map(o => ({ x: o.x, y: o.y, w: o.w })), ledges: [H - 0.3], cond: 0.45 }, r), origin: s.origin.clone(), along: new THREE.Vector3(s.along.x, 0, s.along.z).normalize(), width: W, height: H };
    const mats = facadeMaterials(scheme, grime);
    for (const [k, geo] of B.merge()) {
      if (SEG_KEYS.has(k)) { const m = new THREE.Mesh(geo, mats[k] || mats.wall); m.matrixAutoUpdate = false; m.matrix.copy(M); m.castShadow = m.receiveShadow = true; this.group.add(m); }
      else { geo.applyMatrix4(M); SHARED.add(k, geo); }
    }
    // body and flat roof
    const D = 12;
    const a = new THREE.Vector3(s.along.x, 0, s.along.z).normalize(), n = new THREE.Vector3().crossVectors(a, new THREE.Vector3(0, 1, 0));
    const o0 = s.origin, o1 = s.origin.clone().addScaledVector(a, W), i1 = o1.clone().addScaledVector(n, -D), i0 = o0.clone().addScaledVector(n, -D);
    this.plainWall(i1, i0, H, "rear");
    this.plainWall(o1, i1, H, "end"); this.plainWall(i0, o0, H, "end");
    const roof = new THREE.BufferGeometry();
    const v = (p) => [p.x, H, p.z];
    roof.setAttribute("position", new THREE.Float32BufferAttribute([...v(o0), ...v(o1), ...v(i1), ...v(o0), ...v(i1), ...v(i0)], 3));
    orientUp(roof); roof.computeVertexNormals(); boxUV(roof, 2); SHARED.add("asphaltRoof", roof);
    const par = sweep(PROFILE.band(0.5, 0.25), straight(0, W, H - 0.1)); par.applyMatrix4(M); SHARED.add("granite", boxUV(par, 1));
    return this.group;
  }
}

// make every triangle of g face up (+y)
function orientUp(g) {
  const p = g.attributes.position.array;
  for (let i = 0; i < p.length; i += 9) {
    const ux = p[i + 3] - p[i], uz = p[i + 5] - p[i + 2], vx = p[i + 6] - p[i], vz = p[i + 8] - p[i + 2];
    if (uz * vx - ux * vz < 0) for (let k = 0; k < 3; k++) { const t = p[i + 3 + k]; p[i + 3 + k] = p[i + 6 + k]; p[i + 6 + k] = t; }
  }
}
// make roof slopes face away from the polygon's inside (upward and outward)
function orientOut(g, poly) {
  const c = new THREE.Vector3(); poly.forEach(p => c.add(p)); c.divideScalar(poly.length);
  const p = g.attributes.position.array;
  for (let i = 0; i < p.length; i += 9) {
    const ux = p[i + 3] - p[i], uy = p[i + 4] - p[i + 1], uz = p[i + 5] - p[i + 2];
    const vx = p[i + 6] - p[i], vy = p[i + 7] - p[i + 1], vz = p[i + 8] - p[i + 2];
    const ny = uz * vx - ux * vz;
    if (ny < 0) for (let k = 0; k < 3; k++) { const t = p[i + 3 + k]; p[i + 3 + k] = p[i + 6 + k]; p[i + 6 + k] = t; }
  }
}
// inset a simple polygon (in xz) by distance d, mitring the corners
function insetPolygon(poly, d) {
  // signed area to know the winding
  let A = 0;
  for (let i = 0; i < poly.length; i++) { const a = poly[i], b = poly[(i + 1) % poly.length]; A += a.x * b.z - b.x * a.z; }
  const s = A > 0 ? 1 : -1;
  const out = [];
  for (let i = 0; i < poly.length; i++) {
    const p0 = poly[(i - 1 + poly.length) % poly.length], p1 = poly[i], p2 = poly[(i + 1) % poly.length];
    const e1 = p1.clone().sub(p0).normalize(), e2 = p2.clone().sub(p1).normalize();
    // inward normals
    const n1 = new THREE.Vector3(-e1.z * s, 0, e1.x * s), n2 = new THREE.Vector3(-e2.z * s, 0, e2.x * s);
    const m = n1.clone().add(n2); const ml = m.length();
    if (ml < 1e-4) { out.push(p1.clone().addScaledVector(n1, d)); continue; }
    m.divideScalar(ml);
    const k = d / Math.max(0.25, m.dot(n1));
    out.push(p1.clone().addScaledVector(m, k));
  }
  return out;
}

const SHOPS = [];
function resetShops() {
  SHOPS.length = 0;
  SHOPS.push(
    { text: "Bäckerei Hoffmann", style: "bakery" }, { text: "Apotheke am Platz", style: "pharmacy" },
    { text: "Spätkauf", style: "spaeti" }, { text: "Antiquariat", style: "books" },
    { text: "Friseur Krause", style: "barber" }, { text: "Café Ketten", style: "cafe" },
    { text: "Weinhandlung", style: "wine" }, { text: "Blumen Lindner", style: "flowers" },
    { text: "Fahrräder", style: "bikes" }, { text: "Buchhandlung", style: "books2" },
    { text: "Eisenwaren", style: "hardware" }, { text: "Feinkost", style: "deli" },
    { text: "Schneiderei", style: "tailor" }, { text: "Uhren · Schmuck", style: "jeweller" },
    { text: "Galerie", style: "gallery" }, { text: "Waschsalon", style: "laundry" },
    { text: "Kiosk", style: "kiosk" }, { text: "Konditorei", style: "cake" },
  );
}
const SIGN_STYLES = {
  bakery: { bg: "#7a2f1e", fg: "#f3d9a4" }, pharmacy: { bg: "#f3efe6", fg: "#b3202a", weight: 700 },
  spaeti: { bg: "#1d1d1d", fg: "#f2d23c", font: "Arial Black, Arial, sans-serif", weight: 800 },
  books: { bg: "#23301f", fg: "#d7c48e" }, barber: { bg: "#e9e4d8", fg: "#1b2a4a" },
  cafe: { bg: "#3a2b22", fg: "#f1e2c6" }, wine: { bg: "#4a1c24", fg: "#e7cf96" },
  flowers: { bg: "#e8eee3", fg: "#2f5a35" }, bikes: { bg: "#1c3e57", fg: "#f2f2ee", font: "Arial, sans-serif" },
  books2: { bg: "#efe7d5", fg: "#2d2a26" }, hardware: { bg: "#2a2f33", fg: "#e8b44a", font: "Arial, sans-serif" },
  deli: { bg: "#1f3b33", fg: "#e9dcb6" }, tailor: { bg: "#e5ddd0", fg: "#4b2e2b" },
  jeweller: { bg: "#151515", fg: "#d8b766" }, gallery: { bg: "#f5f5f2", fg: "#111111", font: "Helvetica, Arial, sans-serif", weight: 400, spacing: 12 },
  laundry: { bg: "#2f6f9a", fg: "#ffffff", font: "Arial, sans-serif" }, kiosk: { bg: "#b2382c", fg: "#ffffff", font: "Arial, sans-serif" },
  cake: { bg: "#f0dfe0", fg: "#6b2c3a" }, pub: { bg: "#1f2a1e", fg: "#e6c97a", border: "#b8913d" },
  gdr: { bg: "#c94b2c", fg: "#ffffff", font: "Arial, sans-serif", weight: 700, spacing: 6 },
  street: { bg: "#f4f2ec", fg: "#111111", font: "Arial Narrow, Arial, sans-serif", weight: 600, border: "#111111", h: 340, w: 1150, size: 150 },
  ghost: { bg: "rgba(0,0,0,0)", fg: "rgba(238,228,204,0.78)", font: "Georgia, serif", weight: 700, h: 512, w: 1024, size: 120 },
};
