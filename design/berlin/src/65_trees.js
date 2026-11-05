// ============================================================== street trees
// Lindens along Gordianstraße: tapered limbs and crowns of alpha-tested leaf cards.
// The cards get normals pointing out from the crown's centre, so a crown shades as one
// soft mass (lit side, shadow side) instead of a scatter of flickering planes.

function texLeaves() {
  const N = 256, rng = new Rng(311);
  const c = canvas(N, N), x = c.getContext("2d");
  x.clearRect(0, 0, N, N);
  const greens = ["#4f6b2e", "#5d7a34", "#6b8a3c", "#46602a", "#7a9445", "#3f5826"];
  for (let i = 0; i < 160; i++) {
    const px = rng.range(14, N - 14), py = rng.range(14, N - 14);
    // keep the cluster roughly round so card edges don't show
    if (Math.hypot(px - N / 2, py - N / 2) > N * 0.46) continue;
    const s = rng.range(7, 13), a = rng.range(0, Math.PI * 2);
    x.save(); x.translate(px, py); x.rotate(a);
    x.fillStyle = rng.pick(greens);
    // heart-shaped linden leaf
    x.beginPath(); x.moveTo(0, s);
    x.bezierCurveTo(s * 1.1, s * 0.3, s * 0.9, -s * 0.9, 0, -s * 0.45);
    x.bezierCurveTo(-s * 0.9, -s * 0.9, -s * 1.1, s * 0.3, 0, s);
    x.fill();
    x.strokeStyle = "rgba(30,40,15,0.35)"; x.lineWidth = 0.8; x.beginPath(); x.moveTo(0, s); x.lineTo(0, -s * 0.4); x.stroke();
    x.restore();
  }
  const t = toTex(c, true, false);
  TEX.leaves = { map: t };
  // linden bark: long shallow fissures running up the trunk
  const fb = makeFbm(321, 4, 5, 0.55);
  const b = paint(canvas(128, 256), (u, v) => {
    const fiss = Math.abs(Math.sin((u + 0.08 * fb(u, v * 0.25)) * Math.PI * 9));
    const k = 0.55 + 0.35 * Math.pow(fiss, 0.4) + 0.15 * (fb(u, v) - 0.5);
    return [88 * k, 82 * k, 74 * k];
  });
  TEX.bark = { map: toTex(b) };
}

function treeGeometry(x, z, rng, B, cards, scale = 1) {
  const h0 = rng.range(3.0, 3.6) * scale, crownH = rng.range(10, 13.5) * scale, crownR = rng.range(3.8, 5.0) * scale;
  const limb = (p0, p1, r0, r1) => {
    const len = p0.distanceTo(p1);
    const g = new THREE.CylinderGeometry(r1, r0, len, 7, 1, true); g.translate(0, len / 2, 0);
    const q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), p1.clone().sub(p0).normalize());
    g.applyQuaternion(q); g.translate(p0.x, p0.y, p0.z);
    const uv = g.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * 2, uv.getY(i) * len / 2);
    B.add("bark", g.toNonIndexed());
  };
  const base = new THREE.Vector3(x, 0, z), top = new THREE.Vector3(x + rng.range(-0.2, 0.2), h0, z + rng.range(-0.2, 0.2));
  limb(base, top, 0.24, 0.2);
  const centre = new THREE.Vector3(x, h0 + crownH * 0.52, z);
  const tips = [];
  const nL = rng.int(4, 5);
  for (let i = 0; i < nL; i++) {
    const a = (i / nL) * Math.PI * 2 + rng.range(-0.3, 0.3);
    const tilt = rng.range(0.35, 0.6);
    const L1 = rng.range(4.5, 6.5) * scale;
    const p1 = top.clone().add(new THREE.Vector3(Math.cos(a) * Math.sin(tilt) * L1, Math.cos(tilt) * L1, Math.sin(a) * Math.sin(tilt) * L1));
    limb(top, p1, 0.16, 0.09);
    for (let k = 0; k < 3; k++) {
      const a2 = a + rng.range(-0.9, 0.9), t2 = rng.range(0.25, 0.8), L2 = rng.range(2.5, 4) * scale;
      const p2 = p1.clone().add(new THREE.Vector3(Math.cos(a2) * Math.sin(t2) * L2, Math.cos(t2) * L2, Math.sin(a2) * Math.sin(t2) * L2));
      limb(p1, p2, 0.08, 0.035);
      tips.push(p2);
    }
  }
  // leaf cards: clustered round the branch tips and filling the crown's shell
  const nCards = 300;
  for (let i = 0; i < nCards; i++) {
    let p;
    if (i < nCards * 0.55) {
      const t = rng.pick(tips);
      p = t.clone().add(new THREE.Vector3(rng.gauss() * 1.6, rng.gauss() * 1.4, rng.gauss() * 1.6));
    } else {
      const u = rng.range(0, Math.PI * 2), v = Math.acos(rng.range(-0.6, 1)), r = rng.range(0.55, 1.0);
      p = centre.clone().add(new THREE.Vector3(Math.cos(u) * Math.sin(v) * crownR * r, Math.cos(v) * crownH * 0.45 * r, Math.sin(u) * Math.sin(v) * crownR * r));
    }
    if (p.y < h0 + 1.2) p.y = h0 + 1.2 + rng.range(0, 1);
    cards.push({ p, s: rng.range(1.3, 2.0), rot: [rng.range(0, Math.PI), rng.range(0, Math.PI), rng.range(0, Math.PI)], c: centre });
  }
  if (scale < 1) return;
  // tree pit: an iron grate in the pavement
  const pit = new THREE.PlaneGeometry(1.5, 1.5); pit.rotateX(-Math.PI / 2); pit.translate(x, 0.004, z);
  B.add("treeGrate", pit.toNonIndexed());
}

function cardsGeometry(cards) {
  const pos = [], nor = [], uv = [];
  const q = new THREE.Quaternion(), e = new THREE.Euler();
  const corners = [[-0.5, -0.5], [0.5, -0.5], [0.5, 0.5], [-0.5, -0.5], [0.5, 0.5], [-0.5, 0.5]];
  for (const c of cards) {
    e.set(...c.rot); q.setFromEuler(e);
    for (const [u, v] of corners) {
      const p = new THREE.Vector3(u * c.s, v * c.s, 0).applyQuaternion(q).add(c.p);
      pos.push(p.x, p.y, p.z);
      const n = p.clone().sub(c.c); n.y *= 1.6; n.normalize();
      nor.push(n.x, n.y, n.z);
      uv.push(u + 0.5, v + 0.5);
    }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute("normal", new THREE.Float32BufferAttribute(nor, 3));
  g.setAttribute("uv", new THREE.Float32BufferAttribute(uv, 2));
  return g;
}

function buildTrees() {
  texLeaves();
  MAT.bark = new THREE.MeshStandardMaterial({ map: TEX.bark.map, roughness: 0.95 });
  MAT.leafCards = new THREE.MeshStandardMaterial({ map: TEX.leaves.map, alphaTest: 0.45, alphaToCoverage: true, side: THREE.DoubleSide, roughness: 0.85 });
  const g = canvas(128, 128), gx = g.getContext("2d");
  gx.fillStyle = "#2d2a26"; gx.fillRect(0, 0, 128, 128);
  gx.strokeStyle = "#151412"; gx.lineWidth = 3;
  for (let r = 10; r < 64; r += 8) { gx.beginPath(); gx.arc(64, 64, r, 0, 7); gx.stroke(); }
  for (let k = 0; k < 16; k++) { const a = k * Math.PI / 8; gx.beginPath(); gx.moveTo(64 + Math.cos(a) * 12, 64 + Math.sin(a) * 12); gx.lineTo(64 + Math.cos(a) * 64, 64 + Math.sin(a) * 64); gx.stroke(); }
  gx.strokeStyle = "#5a5047"; gx.lineWidth = 4; gx.strokeRect(2, 2, 124, 124);
  MAT.treeGrate = new THREE.MeshStandardMaterial({ map: toTex(g, true, false), roughness: 0.7, metalness: 0.4 });

  const B = new Bucket(), cards = [], rng = new Rng(4242);
  const { L, bKerb } = D;
  // along Gordianstraße, on the kerb-side mosaic, keeping clear of the lanterns
  const lampZ = new Set();
  for (const p of LAMPS) if (Math.abs(Math.abs(p.x) - (bKerb + 0.95)) < 0.1) lampZ.add(Math.round(p.z));
  for (const sx of [-1, 1]) for (let z = 21; z < L - 4; z += rng.range(8.5, 10)) for (const sz of [-1, 1]) {
    const zz = sz * z;
    let near = false; for (const lz of lampZ) if (Math.abs(lz - zz) < 3 && Math.sign(lz) === sz) near = true;
    if (near) continue;
    treeGeometry(sx * (bKerb + 0.95), zz, rng, B, cards);
  }
  // a few in the courtyards
  for (const [x, z] of [[62, 58], [55, -62], [-55, 64], [-70, -50], [78, 56], [-72, 52]]) treeGeometry(x, z, rng, B, cards);
  for (const p of GAP_GREEN.trees) treeGeometry(p.x, p.z, rng, B, cards, 0.75);
  for (const p of GAP_GREEN.bushes) {
    const c = new THREE.Vector3(p.x, 0.7, p.z), R = rng.range(0.7, 1.3);
    for (let k = 0; k < 45; k++) cards.push({ p: c.clone().add(new THREE.Vector3(rng.gauss() * R, Math.abs(rng.gauss()) * R * 0.6, rng.gauss() * R)), s: rng.range(0.7, 1.1), rot: [rng.range(0, 3), rng.range(0, 3), rng.range(0, 3)], c });
  }
  B.add("leafCards", cardsGeometry(cards));
  return B;
}
