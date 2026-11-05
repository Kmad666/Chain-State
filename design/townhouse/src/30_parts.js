// ============================================================== building parts
// Facade-local space: x runs along the facade (left to right seen from the street),
// y is height above the pavement, z points out of the wall toward the street.

function addUV(bucket, key, geo, matrix, tile = 1) {
  boxUV(geo, tile);
  bucket.add(key, geo, matrix);
}

// ---------- mouldings: a profile swept along a path
// profile: [[z, y], ...] from the wall at the bottom, outward, back to the wall at the top.
// path: [[x, y], ...] in the facade plane; the profile's y is measured along the path's
// left normal (for a path running +x that is straight up).
function sweep(profile, path, closedEnds = true) {
  const pos = [];
  const P = path.length, Q = profile.length;
  const frames = [];
  for (let i = 0; i < P; i++) {
    const a = path[Math.max(0, i - 1)], b = path[Math.min(P - 1, i + 1)];
    let tx = b[0] - a[0], ty = b[1] - a[1];
    const l = Math.hypot(tx, ty) || 1; tx /= l; ty /= l;
    let nx = -ty, ny = tx;                // left normal
    // mitre: lengthen the normal at bends
    let k = 1;
    if (i > 0 && i < P - 1) {
      const a2 = path[i - 1], b2 = path[i + 1];
      const t1 = [path[i][0] - a2[0], path[i][1] - a2[1]], t2 = [b2[0] - path[i][0], b2[1] - path[i][1]];
      const l1 = Math.hypot(...t1), l2 = Math.hypot(...t2);
      const n1 = [-t1[1] / l1, t1[0] / l1], n2 = [-t2[1] / l2, t2[0] / l2];
      const nm = [n1[0] + n2[0], n1[1] + n2[1]], lm = Math.hypot(...nm);
      nx = nm[0] / lm; ny = nm[1] / lm;
      k = 1 / Math.max(0.3, nx * n1[0] + ny * n1[1]);
    }
    frames.push([path[i][0], path[i][1], nx * k, ny * k]);
  }
  const V = (f, q) => [f[0] + f[2] * profile[q][1], f[1] + f[3] * profile[q][1], profile[q][0]];
  for (let i = 0; i < P - 1; i++) {
    for (let q = 0; q < Q - 1; q++) {
      const a = V(frames[i], q), b = V(frames[i + 1], q), c = V(frames[i + 1], q + 1), d = V(frames[i], q + 1);
      pos.push(...a, ...b, ...c, ...a, ...c, ...d);
    }
  }
  // The side faces wind outward by construction (profile bottom -> out -> top, offset
  // along the path's left normal). End caps are oriented against / along the path.
  if (closedEnds) {
    const contour = profile.map(p => new THREE.Vector2(p[0], p[1]));
    const tris = THREE.ShapeUtils.triangulateShape(contour, []);
    for (const [fi, sgn] of [[0, -1], [P - 1, 1]]) {
      const a = path[fi === 0 ? 0 : P - 2], b = path[fi === 0 ? 1 : P - 1];
      const tx = (b[0] - a[0]) * sgn, ty = (b[1] - a[1]) * sgn;
      for (const t of tris) {
        let A = V(frames[fi], t[0]), Bv = V(frames[fi], t[1]), C = V(frames[fi], t[2]);
        const ux = Bv[0] - A[0], uy = Bv[1] - A[1], uz = Bv[2] - A[2], vx = C[0] - A[0], vy = C[1] - A[1], vz = C[2] - A[2];
        const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz;
        if (nx * tx + ny * ty < 0) [Bv, C] = [C, Bv];
        pos.push(...A, ...Bv, ...C);
      }
    }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
  g.computeVertexNormals();
  return g;
}

// Make every triangle face away from the wall/toward +z-ish "outside": we orient each
// triangle so its normal points away from the solid's centroid line (the wall, z=0).
function fixWinding(g) {
  const p = g.attributes.position.array;
  // centroid of the whole solid
  let cx = 0, cy = 0, cz = 0; const n = p.length / 3;
  for (let i = 0; i < p.length; i += 3) { cx += p[i]; cy += p[i + 1]; cz += p[i + 2]; }
  cx /= n; cy /= n; cz /= n;
  for (let i = 0; i < p.length; i += 9) {
    const ax = p[i], ay = p[i + 1], az = p[i + 2];
    const ux = p[i + 3] - ax, uy = p[i + 4] - ay, uz = p[i + 5] - az;
    const vx = p[i + 6] - ax, vy = p[i + 7] - ay, vz = p[i + 8] - az;
    const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
    const mx = (ax + p[i + 3] + p[i + 6]) / 3 - cx, my = (ay + p[i + 4] + p[i + 7]) / 3 - cy, mz = (az + p[i + 5] + p[i + 8]) / 3 - cz;
    if (nx * mx + ny * my + nz * mz < 0) {
      for (let k = 0; k < 3; k++) { const t = p[i + 3 + k]; p[i + 3 + k] = p[i + 6 + k]; p[i + 6 + k] = t; }
    }
  }
}

// Profiles (z out, y up), each starting and ending on the wall (z = 0).
const PROFILE = {
  // main cornice (Hauptgesims) ~1.0 m tall, 0.7 m projection: bed moulding, corona with drip, cyma
  main: (s = 1) => scaleP([[0, 0], [0.06, 0], [0.06, 0.06], [0.12, 0.1], [0.14, 0.16], [0.14, 0.3], [0.2, 0.3], [0.24, 0.36],
    [0.5, 0.42], [0.62, 0.44], [0.62, 0.66], [0.6, 0.68], [0.6, 0.72], [0.66, 0.74], [0.7, 0.8], [0.71, 0.88],
    [0.73, 0.94], [0.76, 0.98], [0.76, 1.0], [0, 1.0]], s),
  // belt course over the ground floor (Gurtgesims)
  belt: (s = 1) => scaleP([[0, 0], [0.05, 0], [0.09, 0.04], [0.1, 0.08], [0.1, 0.2], [0.14, 0.22], [0.18, 0.26], [0.18, 0.32], [0, 0.32]], s),
  // sill course (Sohlbankgesims)
  sill: (s = 1) => scaleP([[0, 0], [0.03, 0], [0.07, 0.05], [0.09, 0.08], [0.09, 0.15], [0, 0.15]], s),
  // window head cornice (gerade Verdachung) and pediment rakes
  cap: (s = 1) => scaleP([[0, 0], [0.04, 0], [0.06, 0.03], [0.06, 0.08], [0.13, 0.12], [0.15, 0.16], [0.16, 0.2], [0, 0.2]], s),
  // window frame band (Faschen) with an inner bead
  frame: () => [[0, 0], [0.025, 0], [0.04, 0.015], [0.04, 0.03], [0.045, 0.035], [0.045, 0.13], [0.03, 0.15], [0, 0.15]],
  // a simple plinth bead
  bead: () => [[0, 0], [0.04, 0.01], [0.05, 0.04], [0.04, 0.07], [0, 0.08]],
  // flat band (string course)
  band: (h = 0.2, d = 0.04) => [[0, 0], [d, 0], [d, h], [0, h]],
};
function scaleP(p, s) { return p.map(([z, y]) => [z * s, y * s]); }

function straight(x0, x1, y) { return [[x0, y], [x1, y]]; }

// ---------- a wall panel with openings (front face + reveals)
// openings: [{x, y, w, h, arch: 0|'seg'|'round', depth}]
function wallWithOpenings(x0, y0, x1, y1, openings, z = 0) {
  const shape = new THREE.Shape();
  shape.moveTo(x0, y0); shape.lineTo(x1, y0); shape.lineTo(x1, y1); shape.lineTo(x0, y1); shape.lineTo(x0, y0);
  const reveals = [];
  for (const o of openings) {
    const hole = new THREE.Path();
    const pts = openingOutline(o);
    // holes must wind the other way
    hole.moveTo(pts[0][0], pts[0][1]);
    for (let i = pts.length - 1; i > 0; i--) hole.lineTo(pts[i][0], pts[i][1]);
    shape.holes.push(hole);
    // reveal: extrude the outline inward
    const d = o.depth ?? 0.24;
    for (let i = 0; i < pts.length; i++) {
      const a = pts[i], b = pts[(i + 1) % pts.length];
      reveals.push(a[0], a[1], z, b[0], b[1], z, b[0], b[1], z - d, a[0], a[1], z, b[0], b[1], z - d, a[0], a[1], z - d);
    }
  }
  const front = new THREE.ShapeGeometry(shape, 6);
  front.translate(0, 0, z);
  const rg = new THREE.BufferGeometry();
  rg.setAttribute("position", new THREE.Float32BufferAttribute(reveals, 3));
  // reveal normals must face into the opening (toward its centre); flip triangles that don't
  orientReveals(rg, openings);
  rg.computeVertexNormals();
  return [front.toNonIndexed(), rg];
}

function orientReveals(g, openings) {
  const p = g.attributes.position.array;
  for (let i = 0; i < p.length; i += 9) {
    const cx = (p[i] + p[i + 3] + p[i + 6]) / 3, cy = (p[i + 1] + p[i + 4] + p[i + 7]) / 3;
    // find the opening this triangle belongs to (nearest centre)
    let best = null, bd = 1e9;
    for (const o of openings) {
      const ox = o.x + o.w / 2, oy = o.y + o.h / 2;
      const d = Math.abs(cx - ox) / (o.w / 2 + 0.01) + Math.abs(cy - oy) / (o.h / 2 + 0.01);
      if (d < bd) { bd = d; best = [ox, oy]; }
    }
    const ux = p[i + 3] - p[i], uy = p[i + 4] - p[i + 1], uz = p[i + 5] - p[i + 2];
    const vx = p[i + 6] - p[i], vy = p[i + 7] - p[i + 1], vz = p[i + 8] - p[i + 2];
    const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz;
    if (nx * (best[0] - cx) + ny * (best[1] - cy) < 0) {
      for (let k = 0; k < 3; k++) { const t = p[i + 3 + k]; p[i + 3 + k] = p[i + 6 + k]; p[i + 6 + k] = t; }
    }
  }
}

// counter-clockwise outline of an opening (rectangle, segmental or round arch top)
function openingOutline(o) {
  const pts = [[o.x, o.y], [o.x + o.w, o.y]];
  if (!o.arch) {
    pts.push([o.x + o.w, o.y + o.h], [o.x, o.y + o.h]);
  } else {
    const rise = o.arch === "round" ? o.w / 2 : o.w * 0.16;
    const spring = o.y + o.h - rise;
    pts.push([o.x + o.w, spring]);
    // arc through (x, spring), (mid, y+h), (x+w, spring)
    const half = o.w / 2, R = (half * half + rise * rise) / (2 * rise), cy = o.y + o.h - R, cx = o.x + half;
    const a0 = Math.atan2(spring - cy, half), a1 = Math.PI - a0;
    const N = o.arch === "round" ? 12 : 8;
    for (let i = 1; i < N; i++) {
      const a = a0 + (a1 - a0) * i / N;
      pts.push([cx + Math.cos(a) * R, cy + Math.sin(a) * R]);
    }
    pts.push([o.x, spring]);
  }
  return pts;
}

// ---------- a box-window (Kastendoppelfenster) with T-shaped cross
function windowUnit(B, o, rng, opts = {}) {
  const d = o.depth ?? 0.24;
  const z = -d + 0.06;
  const fw = 0.065, mull = 0.085, sash = 0.045;
  const key = opts.frameKey || "frame";
  const { x, y, w, h } = o;
  const add = (g) => B.add(key, g);
  // outer frame
  const topY = o.arch ? y + h - (o.arch === "round" ? w / 2 : w * 0.16) : y + h;
  add(boxGeo(x, y, z - 0.04, fw, topY - y, 0.08));
  add(boxGeo(x + w - fw, y, z - 0.04, fw, topY - y, 0.08));
  add(boxGeo(x, y, z - 0.04, w, fw + 0.02, 0.1));               // bottom rail + sill board
  add(boxGeo(x - 0.02, y - 0.02, z, w + 0.04, 0.035, 0.12));     // little outer sill
  if (!o.arch) add(boxGeo(x, y + h - fw, z - 0.04, w, fw, 0.08));
  else {
    // the frame follows the arch: short boxes along the curve
    const arc = openingOutline(o).slice(2);
    for (let i = 0; i < arc.length - 1; i++) {
      const [ax, ay] = arc[i], [bx, by] = arc[i + 1];
      const L = Math.hypot(bx - ax, by - ay) + 0.01, ang = Math.atan2(by - ay, bx - ax);
      const g = new THREE.BoxGeometry(L, fw, 0.08);
      const nx = -Math.sin(ang), ny = Math.cos(ang);       // left normal = inward for a CCW outline
      g.rotateZ(ang); g.translate((ax + bx) / 2 + nx * fw / 2, (ay + by) / 2 + ny * fw / 2, z);
      add(g);
    }
  }
  // transom (Kämpfer) at about 72% height, or at the springing of an arch
  const tY = o.arch ? topY - 0.05 : y + (h - fw) * (h > 1.9 ? 0.72 : 0.78);
  if (h > 1.4) add(boxGeo(x + fw, tY, z - 0.03, w - 2 * fw, 0.07, 0.07));
  const twoLeaf = w > 0.9;
  if (twoLeaf) add(boxGeo(x + w / 2 - mull / 2, y + fw, z - 0.025, mull, tY - y - fw, 0.065));
  // sash frames inside the lower part
  const leaves = twoLeaf ? [[x + fw, x + w / 2 - mull / 2], [x + w / 2 + mull / 2, x + w - fw]] : [[x + fw, x + w - fw]];
  for (const [a, b] of leaves) {
    add(boxGeo(a, y + fw, z - 0.02, sash, tY - y - fw, 0.05));
    add(boxGeo(b - sash, y + fw, z - 0.02, sash, tY - y - fw, 0.05));
    add(boxGeo(a, y + fw, z - 0.02, b - a, sash, 0.05));
    add(boxGeo(a, tY - sash, z - 0.02, b - a, sash, 0.05));
    if (opts.bars) add(boxGeo(a, y + fw + (tY - y - fw) / 2 - 0.015, z - 0.015, b - a, 0.03, 0.035));
  }
  // glass
  const gl = new THREE.PlaneGeometry(1, 1);
  // some flats have the lights on after dark
  const glassKey = opts.glassKey || (rng.chance(0.3) ? (rng.chance(0.6) ? "glassLit" : "glassLit2") : "glass");
  const glass = (gx, gy, gw, gh) => { const g = new THREE.PlaneGeometry(gw, gh); g.translate(gx + gw / 2, gy + gh / 2, z - 0.035); B.add(glassKey, g); };
  glass(x + fw, y + fw, w - 2 * fw, tY - y - fw);
  if (h > 1.4) {
    if (!o.arch) glass(x + fw, tY + 0.07, w - 2 * fw, y + h - fw - tY - 0.07);
    else {
      const s = new THREE.Shape();
      const pts = openingOutline({ ...o }).slice(1);
      s.moveTo(x + fw, tY); pts.forEach(p => s.lineTo(Math.min(Math.max(p[0], x + fw), x + w - fw), Math.max(p[1], tY)));
      const g = new THREE.ShapeGeometry(s, 4); g.translate(0, 0, z - 0.035); B.add(glassKey, g);
    }
  }
  // net curtains on some windows, sitting just in front of the glass
  if (opts.curtains !== false && rng.chance(opts.curtainChance ?? 0.55)) {
    const cw = rng.chance(0.5) ? w - 2 * fw : (w - 2 * fw) * rng.range(0.3, 0.5);
    const left = rng.chance(0.5);
    const cx = left ? x + fw : x + w - fw - cw;
    const ch = (tY - y - fw) * rng.range(0.55, 1);
    const g = new THREE.PlaneGeometry(cw, ch); g.translate(cx + cw / 2, tY - ch / 2, z - 0.028);
    const uv = g.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * cw * 2, uv.getY(i));
    B.add("curtain", g);
  }
}

// ---------- frame band around an opening (Faschen), optionally with ears (Ohren)
function frameAround(B, key, o, width = 0.15, ears = false) {
  const pts = openingOutline(o);
  // path: left side bottom -> up -> across the top -> down the right side
  const path = [];
  const left = pts[pts.length - 1 - (o.arch ? 0 : 0)];
  path.push([o.x, o.y - 0.0]);
  if (!o.arch) path.push([o.x, o.y + o.h], [o.x + o.w, o.y + o.h]);
  else { for (let i = pts.length - 1; i >= 2; i--) path.push(pts[i]); }
  path.push([o.x + o.w, o.y]);
  // profile measured along the path's left normal (outward from the opening for this CW path)
  const prof = PROFILE.frame().map(([z, y]) => [z, y * width / 0.15]);
  B.add(key, sweep(prof, path.map(p => p), true));
  if (ears && !o.arch) {
    for (const ex of [o.x - width - 0.08, o.x + o.w + width]) B.add(key, boxGeo(ex, o.y + o.h - 0.22, 0, 0.08, 0.22 + width, 0.045));
  }
}

// ---------- S-scroll console (Konsole), extruded across `w`
function consoleGeo(x, y, w, h, d) {
  const s = new THREE.Shape();
  // side outline in (z, y): top flush with the underside of what it carries
  s.moveTo(0, 0); s.lineTo(d * 0.25, 0);
  s.bezierCurveTo(d * 0.3, h * 0.35, d * 0.95, h * 0.45, d, h * 0.85);
  s.lineTo(d, h); s.lineTo(0, h); s.lineTo(0, 0);
  const g = new THREE.ExtrudeGeometry(s, { depth: w, bevelEnabled: false, curveSegments: 6 });
  // shape x -> z (out), shape y -> y, extrude z -> x
  g.rotateY(-Math.PI / 2);   // extrusion now along -x; shape x now along +z
  g.translate(x + w, y, 0);
  return g.toNonIndexed();
}

// row of dentils / small blocks
function dentils(B, key, x0, x1, y, h, d, pitch, w) {
  for (let x = x0 + pitch / 2; x < x1 - w / 2; x += pitch) B.add(key, boxGeo(x - w / 2, y, 0, w, h, d));
}

// ---------- triangular / segmental pediment above an opening
function pediment(B, key, o, type, y0) {
  const ov = 0.22;
  const x0 = o.x - ov, x1 = o.x + o.w + ov;
  // horizontal cornice
  B.add(key, sweep(PROFILE.cap(), straight(x0, x1, y0)));
  const top = y0 + 0.2;
  if (type === "tri") {
    const peak = (x1 - x0) * 0.22;
    const mid = (x0 + x1) / 2;
    // the two raking cornices
    B.add(key, sweep(PROFILE.cap(0.9), [[x0, top - 0.02], [mid, top + peak]]));
    B.add(key, sweep(PROFILE.cap(0.9).map(([z, y]) => [z, y]), [[mid, top + peak], [x1, top - 0.02]]));
    // tympanum
    const s = new THREE.Shape(); s.moveTo(x0 + 0.1, top); s.lineTo(x1 - 0.1, top); s.lineTo(mid, top + peak - 0.05); s.lineTo(x0 + 0.1, top);
    const g = new THREE.ShapeGeometry(s); g.translate(0, 0, 0.03); B.add(key, g.toNonIndexed());
  } else if (type === "seg") {
    const half = (x1 - x0) / 2, rise = half * 0.32, R = (half * half + rise * rise) / (2 * rise);
    const cx = (x0 + x1) / 2, cy = top + rise - R;
    const a0 = Math.atan2(top - cy, -half), a1 = Math.atan2(top - cy, half);
    const path = [];
    for (let i = 0; i <= 12; i++) { const a = a0 + (a1 - a0) * i / 12; path.push([cx + Math.cos(a) * R, cy + Math.sin(a) * R]); }
    B.add(key, sweep(PROFILE.cap(0.9), path));
    const s = new THREE.Shape(); s.moveTo(x0 + 0.1, top); path.slice(1, -1).forEach(p => s.lineTo(p[0], p[1] - 0.06)); s.lineTo(x1 - 0.1, top); s.lineTo(x0 + 0.1, top);
    const g = new THREE.ShapeGeometry(s); g.translate(0, 0, 0.03); B.add(key, g.toNonIndexed());
  }
  // small consoles carrying the cornice
  B.add(key, consoleGeo(o.x - 0.2, y0 - 0.45, 0.14, 0.45, 0.13));
  B.add(key, consoleGeo(o.x + o.w + 0.06, y0 - 0.45, 0.14, 0.45, 0.13));
}

// keystone in a lintel
function keystone(B, key, o) {
  const s = new THREE.Shape();
  const cx = o.x + o.w / 2, y = o.y + o.h - 0.05;
  s.moveTo(cx - 0.1, y); s.lineTo(cx + 0.1, y); s.lineTo(cx + 0.15, y + 0.34); s.lineTo(cx - 0.15, y + 0.34); s.lineTo(cx - 0.1, y);
  const g = new THREE.ExtrudeGeometry(s, { depth: 0.09, bevelEnabled: true, bevelSize: 0.01, bevelThickness: 0.01, bevelSegments: 1 });
  B.add(key, g.toNonIndexed());
}

// recessed apron panel under a window (Brüstungsfeld)
function apron(B, key, o, h = 0.55) {
  const x0 = o.x + 0.02, x1 = o.x + o.w - 0.02, y1 = o.y - 0.12, y0 = y1 - h;
  B.add(key, sweep(PROFILE.bead().map(([z, y]) => [z * 0.8, y]), [[x0, y0], [x0, y1], [x1, y1], [x1, y0], [x0, y0]].reverse(), false));
  B.add(key, boxGeo(x0 + 0.12, y0 + 0.12, 0, x1 - x0 - 0.24, h - 0.24, 0.02));
}

// balustrade of turned balusters (for Beletage balconies on rich houses)
function balustrade(B, key, x0, x1, y, h, z) {
  B.add(key, boxGeo(x0, y, z - 0.12, x1 - x0, 0.12, 0.24));
  B.add(key, boxGeo(x0 - 0.02, y + h - 0.12, z - 0.14, x1 - x0 + 0.04, 0.12, 0.28));
  const prof = [[0.0, 0], [0.07, 0.0], [0.07, 0.05], [0.04, 0.1], [0.06, 0.24], [0.08, 0.32], [0.05, 0.45], [0.03, 0.5], [0.06, 0.55], [0.06, 0.6], [0, 0.6]];
  const lathe = new THREE.LatheGeometry(prof.map(p => new THREE.Vector2(p[0], p[1] * (h - 0.24) / 0.6)), 8);
  for (let x = x0 + 0.12; x < x1 - 0.08; x += 0.2) {
    const g = lathe.clone(); g.translate(x, y + 0.12, z); B.add(key, g.toNonIndexed());
  }
}
