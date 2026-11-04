// ============================================================== streets
// Two Hobrecht-plan streets crossing: Street A (along x) is 26 m between the house
// fronts with granite setts and tram tracks; Street B (along z) is 22 m, asphalt.
// Pavements follow the Berlin pattern from the house to the kerb: a strip of
// Bernburger mosaic, a band of two rows of 1 m Silesian granite slabs, another mosaic
// strip, then a granite kerb 12 cm above the carriageway.

const D = {
  L: 96,                 // the district runs from -L to L along both streets
  aFront: 13,            // |z| of the house fronts on Street A
  bFront: 11,            // |x| of the house fronts on Street B
  aKerb: 8,              // |z| of the kerb on Street A
  bKerb: 6,              // |x| of the kerb on Street B
  kerbR: 4.5,            // kerb radius at the corners
  chamfer: 4.6,          // the corner houses' cut corner (Eckabschrägung)
  road: -0.12,           // carriageway level (pavement = 0)
};

// a strip in the xz-plane from p0 to p1 (centre line), `w` wide, at height y, with UVs
// u = metres along / tileU, v = 0..1 across (or metres across / tileV)
function groundStrip(x0, z0, x1, z1, w, y, tileU, tileV) {
  const len = Math.hypot(x1 - x0, z1 - z0);
  const g = new THREE.PlaneGeometry(len, w, Math.max(1, Math.round(len / 8)), 1);
  g.rotateX(-Math.PI / 2);
  const ang = Math.atan2(z1 - z0, x1 - x0);
  g.rotateY(-ang);
  g.translate((x0 + x1) / 2, y, (z0 + z1) / 2);
  const uv = g.attributes.uv;
  for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * len / tileU, tileV ? uv.getY(i) * w / tileV : uv.getY(i));
  return g.toNonIndexed();
}

// a polygon in xz at height y with world-metre UVs
function groundPoly(pts, y, tile) {
  const s = new THREE.Shape(pts.map(p => new THREE.Vector2(p[0], -p[1])));
  const g = new THREE.ShapeGeometry(s, 8);
  g.rotateX(-Math.PI / 2); g.translate(0, y, 0);
  const t = g.toNonIndexed(); orientUp(t); t.computeVertexNormals();
  const pos = t.attributes.position, uv = new Float32Array(pos.count * 2);
  for (let i = 0; i < pos.count; i++) { uv[i * 2] = pos.getX(i) / tile; uv[i * 2 + 1] = pos.getZ(i) / tile; }
  t.setAttribute("uv", new THREE.BufferAttribute(uv, 2));
  return t;
}

// kerb stones along a path in xz: top 30 cm wide with a rounded street edge
function kerb(path, B) {
  const prof = [[0, 0], [0.3, 0], [0.33, -0.02], [0.34, D.road - 0.02]];   // [across (toward street), y]
  const pos = [];
  for (let i = 0; i < path.length - 1; i++) {
    const [ax, az] = path[i], [bx, bz] = path[i + 1];
    const tl = Math.hypot(bx - ax, bz - az), tx = (bx - ax) / tl, tz = (bz - az) / tl;
    // the street is on the path's right
    const nx = -tz, nz = tx;
    const rx = -nx, rz = -nz;
    for (let q = 0; q < prof.length - 1; q++) {
      const P = (x, z, k) => [x + rx * prof[k][0], prof[k][1], z + rz * prof[k][0]];
      const a = P(ax, az, q), b = P(bx, bz, q), c = P(bx, bz, q + 1), d = P(ax, az, q + 1);
      pos.push(...a, ...c, ...b, ...a, ...d, ...c);
    }
  }
  const g = new THREE.BufferGeometry(); g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
  g.computeVertexNormals(); boxUV(g, 0.6);
  B.add("kerb", g);
  // joints every metre or so
  let acc = 0;
  for (let i = 0; i < path.length - 1; i++) {
    const [ax, az] = path[i], [bx, bz] = path[i + 1];
    const tl = Math.hypot(bx - ax, bz - az);
    for (let s = (1 - acc % 1); s < tl; s += 1.0) {
      const t = s / tl, x = ax + (bx - ax) * t, z = az + (bz - az) * t;
      const nx = -(bz - az) / tl, nz = (bx - ax) / tl;
      const jg = new THREE.BoxGeometry(0.012, 0.004, 0.3);
      jg.rotateY(-Math.atan2(bz - az, bx - ax)); jg.translate(x - nx * 0.15, 0.001, z - nz * 0.15);
      B.add("joint", jg.toNonIndexed());
    }
    acc += tl;
  }
}

function arc(cx, cz, r, a0, a1, n) {
  const pts = [];
  for (let i = 0; i <= n; i++) { const a = a0 + (a1 - a0) * i / n; pts.push([cx + Math.cos(a) * r, cz + Math.sin(a) * r]); }
  return pts;
}

function buildStreets() {
  const B = new Bucket();
  const { L, aFront, bFront, aKerb, bKerb, kerbR: R, chamfer: c, road } = D;
  const sw = [["mosaicHouse", 1.5], ["slabs", 2.0], ["mosaicCurb", 1.2]];   // house -> kerb, then the kerb (0.3)

  // ---- pavements along the four street arms (each side), outside the corner squares
  const runs = [];
  for (const sz of [-1, 1]) {
    for (const sx of [-1, 1]) {
      // Street A pavement in quadrant (sx, sz): x from sx*(bFront + c) to sx*L, z from sz*aFront to sz*aKerb
      runs.push({ along: "x", s: sx, side: sz, from: bFront + c, to: L, house: aFront, kerbAt: aKerb });
      runs.push({ along: "z", s: sz, side: sx, from: aFront + c, to: L, house: bFront, kerbAt: bKerb });
    }
  }
  for (const r of runs) {
    let off = r.house;
    for (const [mat, w] of sw) {
      const mid = r.side * (off - w / 2);
      const tex = TEX[mat];
      if (r.along === "x") B.add(mat, groundStrip(r.s * r.from, mid, r.s * r.to, mid, w, 0, tex.size[0], mat === "slabs" ? tex.size[1] : 0));
      else B.add(mat, groundStrip(mid, r.s * r.from, mid, r.s * r.to, w, 0, tex.size[0], mat === "slabs" ? tex.size[1] : 0));
      off -= w;
    }
    // kerb: street on the right of the path
    const k = r.side * (r.kerbAt + 0.3);
    let p0, p1;
    if (r.along === "x") { p0 = [r.s * r.from, k]; p1 = [r.s * r.to, k]; }
    else { p0 = [k, r.s * r.from]; p1 = [k, r.s * r.to]; }
    // orient so the street is on the right
    const street = r.along === "x" ? [0, -r.side] : [-r.side, 0];
    const t = [p1[0] - p0[0], p1[1] - p0[1]];
    const rn = [t[1], -t[0]];
    if (rn[0] * street[0] + rn[1] * street[1] < 0) [p0, p1] = [p1, p0];
    kerb([p0, p1], B);
  }

  // ---- corner squares: mosaic up to the cut corner, a kerb around the corner radius
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    // quadrant arc from the B kerb line round to the A kerb line
    const cx = sx * (bKerb + 0.3 + R), cz = sz * (aKerb + 0.3 + R);
    const a0 = Math.atan2(0, -sx), a1 = Math.atan2(-sz, 0);
    let ap = [];
    for (let i = 0; i <= 10; i++) {
      const a = a0 + angDiff(a0, a1) * i / 10;
      ap.push([cx + Math.cos(a) * R, cz + Math.sin(a) * R]);
    }
    const poly = [
      ...ap,
      [sx * (bFront + c), sz * (aKerb + 0.3)],
      [sx * (bFront + c), sz * aFront],
      [sx * bFront, sz * (aFront + c)],
      [sx * (bKerb + 0.3), sz * (aFront + c)],
    ];
    B.add("mosaicField", groundPoly(poly, 0, 2));
    // kerb round the corner (street on the right)
    let kp = [[sx * (bKerb + 0.3), sz * (aFront + c)], ...ap, [sx * (bFront + c), sz * (aKerb + 0.3)]];
    const t = [kp[1][0] - kp[0][0], kp[1][1] - kp[0][1]];
    const rn = [t[1], -t[0]];
    if (rn[0] * -sx + rn[1] * 0 < 0) kp = kp.reverse();
    kerb(kp, B);
    // the carriageway filling the corner outside the kerb arc
    B.add("setts", groundPoly([[sx * bKerb, sz * aKerb], [sx * (bKerb + 0.3 + R), sz * aKerb], ...[...ap].reverse(), [sx * bKerb, sz * (aKerb + 0.3 + R)]], road, 3));
    // the kerb face drops 12 cm: the corner fill sits at road level
  }

  // ---- carriageways
  // Street A: setts the whole length, including the crossing
  B.add("setts", groundPoly([[-L, -aKerb], [L, -aKerb], [L, aKerb], [-L, aKerb]], road, 3));
  // setts under the kerb line strips (between kerb and the corner squares on A)
  for (const sz of [-1, 1]) B.add("setts", groundPoly([[-(bKerb + 0.3 + R), sz * aKerb], [bKerb + 0.3 + R, sz * aKerb], [bKerb + 0.3 + R, sz * (aKerb + 0.3)], [-(bKerb + 0.3 + R), sz * (aKerb + 0.3)]], road, 3));
  // Street B: asphalt, with a gutter of three rows of setts along each kerb
  for (const sz of [-1, 1]) {
    B.add("asphalt", groundPoly([[-bKerb + 0.35, sz * aKerb], [bKerb - 0.35, sz * aKerb], [bKerb - 0.35, sz * L], [-bKerb + 0.35, sz * L]], road, 6));
    for (const sx of [-1, 1]) {
      B.add("setts", groundPoly([[sx * (bKerb - 0.35), sz * aKerb], [sx * (bKerb + 0.3), sz * aKerb], [sx * (bKerb + 0.3), sz * L], [sx * (bKerb - 0.35), sz * L]], road + 0.002, 3));
    }
    // dashed centre line and a stop line before the crossing
    for (let z = aKerb + 6; z < L; z += 9) B.add("paint", groundStrip(0, sz * z, 0, sz * (z + 4.5), 0.12, road + 0.004, 1));
    // right-hand traffic: cars coming from +z keep to +x
    B.add("paint", groundStrip(sz > 0 ? 0.2 : -bKerb + 0.6, sz * (aKerb + 1.6), sz > 0 ? bKerb - 0.6 : -0.2, sz * (aKerb + 1.6), 0.4, road + 0.004, 1));
  }
  // Street A: stop lines too
  for (const sx of [-1, 1]) B.add("paint", groundStrip(sx * (bKerb + 1.6), sx > 0 ? -aKerb + 0.6 : 0.2, sx * (bKerb + 1.6), sx > 0 ? -0.2 : aKerb - 0.6, 0.4, road + 0.004, 1));

  // ---- tram tracks down the middle of Street A (grooved rails flush with the setts)
  for (const tc of [-1.55, 1.55]) {
    for (const rs of [-0.7175, 0.7175]) {
      const z = tc + rs;
      B.add("rail", groundStrip(-L, z, L, z, 0.07, road + 0.004, 1, 0));
      B.add("groove", groundStrip(-L, z + 0.055 * Math.sign(rs), L, z + 0.055 * Math.sign(rs), 0.035, road + 0.003, 1, 0));
      B.add("rail", groundStrip(-L, z + 0.09 * Math.sign(rs), L, z + 0.09 * Math.sign(rs), 0.02, road + 0.004, 1, 0));
    }
  }

  // ---- manholes and gullies
  const rng = new Rng(901);
  for (let x = -L + 10; x < L; x += rng.range(18, 30)) for (const sz of [-1, 1]) {
    if (Math.abs(x) < 12) continue;
    // gully grate in the gutter next to the kerb
    const gz = sz * (aKerb - 0.25);
    B.add("gully", groundStrip(x - 0.25, gz, x + 0.25, gz, 0.4, road + 0.006, 0.5, 0.4));
  }
  for (let z = -L + 14; z < L; z += rng.range(18, 30)) for (const sx of [-1, 1]) {
    if (Math.abs(z) < 14) continue;
    const gx = sx * (bKerb - 0.2);
    B.add("gully", groundStrip(gx, z - 0.25, gx, z + 0.25, 0.4, road + 0.006, 0.5, 0.4));
  }
  for (const [x, z] of [[-40, -4.6], [28, 4.8], [70, -4.4], [-75, 4.6], [0.3, 30], [-0.6, -58], [1, 76]]) {
    const g = new THREE.CircleGeometry(0.4, 24); g.rotateX(-Math.PI / 2); g.translate(x, road + 0.006, z);
    const uv = g.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i), uv.getY(i));
    B.add("manhole", g.toNonIndexed());
  }

  // ---- courtyards and the ground beyond
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    B.add("courtyard", groundPoly([[sx * bFront, sz * aFront], [sx * L, sz * aFront], [sx * L, sz * L], [sx * bFront, sz * L]], -0.01, 6));
  }
  const ground = new THREE.PlaneGeometry(1400, 1400); ground.rotateX(-Math.PI / 2); ground.translate(0, -0.2, 0);
  B.add("distantGround", ground.toNonIndexed());

  return B;
}
function angDiff(a, b) { let d = b - a; while (d > Math.PI) d -= 2 * Math.PI; while (d < -Math.PI) d += 2 * Math.PI; return d; }

// ---- small textures for street details
function streetDetailTextures() {
  // manhole cover: concentric rings and a grid of raised bosses
  const c = canvas(256, 256), x = c.getContext("2d");
  x.fillStyle = "#2a2a2a"; x.fillRect(0, 0, 256, 256);
  x.fillStyle = "#3d3b38"; x.beginPath(); x.arc(128, 128, 126, 0, 7); x.fill();
  x.strokeStyle = "#1c1c1c"; x.lineWidth = 6; x.beginPath(); x.arc(128, 128, 118, 0, 7); x.stroke();
  x.fillStyle = "#55524c";
  for (let i = -6; i <= 6; i++) for (let j = -6; j <= 6; j++) if (i * i + j * j < 30) { x.beginPath(); x.arc(128 + i * 16, 128 + j * 16, 4, 0, 7); x.fill(); }
  x.fillStyle = "#1c1c1c"; x.font = "bold 22px Arial"; x.textAlign = "center"; x.fillText("BERLIN", 128, 136);
  TEX.manhole = { map: toTex(c, true, false) };
  // gully grate: bars
  const g = canvas(128, 128), gx = g.getContext("2d");
  gx.fillStyle = "#3a3936"; gx.fillRect(0, 0, 128, 128);
  gx.fillStyle = "#0e0e0e"; for (let i = 0; i < 9; i++) gx.fillRect(10 + i * 12.5, 12, 6, 104);
  TEX.gully = { map: toTex(g, true, false) };
  // a whole-height facade strip for the surrounding blocks: two window axes (6.6 m) wide,
  // 21 m tall: shopfronts, a belt course, four rows of framed windows, the main cornice
  const DW = 256, DH = 816, pxm = DW / 6.6, d = canvas(DW, DH), dx = d.getContext("2d");
  const Y = m => DH - m * pxm;
  dx.fillStyle = "#e9e3d6"; dx.fillRect(0, 0, DW, DH);
  dx.fillStyle = "#d6cfbf"; dx.fillRect(0, Y(4.3), DW, 4.3 * pxm);
  dx.fillStyle = "#c7c0b0"; for (let y = 0.4; y < 4.3; y += 0.4) dx.fillRect(0, Y(y), DW, 1.2);
  dx.fillStyle = "#2b2e30";
  for (const ax of [1.65, 4.95]) dx.fillRect((ax - 1.2) * pxm, Y(3.2), 2.4 * pxm, 3.0 * pxm);
  dx.fillStyle = "#bdb5a3"; dx.fillRect(0, Y(4.6), DW, 0.3 * pxm);
  for (const [y0, h] of [[4.3, 2.6], [8.35, 2.4], [12.05, 2.25], [15.5, 2.05]]) for (const ax of [1.65, 4.95]) {
    const x0 = (ax - 0.65) * pxm, w = 1.3 * pxm, top = Y(y0 + 0.9 + h);
    dx.fillStyle = "#f6f2ea"; dx.fillRect(x0 - 4, top - 4, w + 8, h * pxm + 8);
    dx.fillStyle = "#30353a"; dx.fillRect(x0, top, w, h * pxm);
    dx.fillStyle = "#e8e4dc"; dx.fillRect(x0 + w / 2 - 1.5, top, 3, h * pxm); dx.fillRect(x0, top + h * pxm * 0.25, w, 3);
    dx.fillStyle = "#b6ae9c"; dx.fillRect(x0 - 8, Y(y0 + 0.9), w + 16, 5);
  }
  dx.fillStyle = "#cdc5b4"; dx.fillRect(0, Y(20.9), DW, 1.0 * pxm);
  dx.fillStyle = "#a59d8b"; dx.fillRect(0, Y(19.95), DW, 5);
  const gr = dx.createLinearGradient(0, 0, 0, DH); gr.addColorStop(0, "rgba(60,55,50,0.25)"); gr.addColorStop(0.4, "rgba(60,55,50,0)"); gr.addColorStop(0.97, "rgba(60,55,50,0)"); gr.addColorStop(1, "rgba(60,55,50,0.3)");
  dx.fillStyle = gr; dx.fillRect(0, 0, DW, DH);
  const dt = toTex(d); dt.wrapT = THREE.ClampToEdgeWrapping;
  TEX.distantFacade = { map: dt };
}

function streetMaterials() {
  MAT.kerb = new THREE.MeshStandardMaterial({ map: TEX.granite.map, normalMap: TEX.granite.normal, color: "#d4d0c8", roughness: 0.7, side: THREE.DoubleSide });
  MAT.joint = new THREE.MeshStandardMaterial({ color: "#2d2b28", roughness: 1 });
  MAT.mosaicField = new THREE.MeshStandardMaterial({ map: TEX.mosaicHouse.map, normalMap: TEX.mosaicHouse.normal, roughness: 0.85 });
  MAT.paint = new THREE.MeshStandardMaterial({ color: "#d8d6cf", roughness: 0.7 });
  MAT.rail = new THREE.MeshStandardMaterial({ color: "#b9bcbe", roughness: 0.22, metalness: 0.95 });
  MAT.groove = new THREE.MeshStandardMaterial({ color: "#151413", roughness: 1 });
  MAT.manhole = new THREE.MeshStandardMaterial({ map: TEX.manhole.map, roughness: 0.55, metalness: 0.5 });
  MAT.gully = new THREE.MeshStandardMaterial({ map: TEX.gully.map, roughness: 0.6, metalness: 0.5 });
  MAT.distantGround = new THREE.MeshStandardMaterial({ color: "#4b4a47", roughness: 1 });
  MAT.distantFacade = new THREE.MeshStandardMaterial({ map: TEX.distantFacade.map, roughness: 0.95 });
}
