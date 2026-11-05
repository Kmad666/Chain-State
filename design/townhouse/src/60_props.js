// ============================================================== street furniture
// Gas lanterns on cast-iron posts (Berlin still runs thousands of gas lamps), an
// advertising column (Litfaßsäule), a green hand pump (Straßenbrunnen), bollards,
// enamel street signs on the corner houses, and the tram's overhead wires.

function lathe(prof, seg = 12) { return new THREE.LatheGeometry(prof.map(p => new THREE.Vector2(p[0], p[1])), seg).toNonIndexed(); }

const LAMPS = [];       // world positions of lanterns (for night glow)

function gasLamp(B, x, z, rot) {
  const T = new THREE.Matrix4().makeRotationY(rot).setPosition(x, 0, z);
  const add = (k, g) => { g.applyMatrix4(T); B.add(k, g); };
  // fluted base, slim post with collars, ladder bar, lantern
  add("lampIron", lathe([[0, 0], [0.2, 0], [0.2, 0.08], [0.16, 0.14], [0.15, 0.5], [0.12, 0.62], [0.09, 0.7], [0.075, 0.75], [0, 0.75]], 10));
  add("lampIron", lathe([[0.07, 0.75], [0.055, 3.3], [0.045, 3.6], [0, 3.6]], 8));
  for (const y of [1.2, 2.4, 3.25]) add("lampIron", lathe([[0, y - 0.04], [0.08, y - 0.03], [0.085, y], [0.08, y + 0.03], [0, y + 0.04]], 8));
  add("lampIron", boxGeo(-0.35, 3.3, -0.02, 0.7, 0.035, 0.04));                    // ladder rest
  for (const s of [-1, 1]) add("lampIron", lathe([[0, -0.03], [0.04, 0], [0, 0.03]], 6).translate(s * 0.35, 3.32, 0));
  // lantern: four tapered glass sides in a black frame, a pyramid roof and a finial
  const y0 = 3.62, y1 = 4.35, b = 0.17, t = 0.26;
  add("lampIron", lathe([[0, 3.58], [0.12, 3.58], [0.18, 3.62], [0, 3.62]], 4).rotateY(Math.PI / 4));
  const glass = new THREE.CylinderGeometry(t * Math.SQRT2 * 0.98, b * Math.SQRT2 * 0.98, y1 - y0, 4, 1, true); glass.rotateY(Math.PI / 4); glass.translate(0, (y0 + y1) / 2, 0);
  add("lampGlass", glass.toNonIndexed());
  for (let k = 0; k < 4; k++) {
    const a = k * Math.PI / 2 + Math.PI / 4;
    const bar = new THREE.BoxGeometry(0.025, y1 - y0 + 0.02, 0.025);
    const lean = Math.atan2(t - b, y1 - y0);
    bar.rotateZ(-lean); bar.translate((b + t) / 2 * Math.SQRT2, (y0 + y1) / 2, 0); bar.rotateY(-a);
    add("lampIron", bar.toNonIndexed());
  }
  add("lampIron", lathe([[0, y1 - 0.01], [t * 1.55, y1], [t * 1.6, y1 + 0.04], [0.06, y1 + 0.32], [0.05, y1 + 0.4], [0.08, y1 + 0.46], [0, y1 + 0.55]], 4).rotateY(Math.PI / 4));
  add("lampIron", lathe([[0, y1 + 0.55], [0.03, y1 + 0.58], [0, y1 + 0.75]], 6));
  LAMPS.push(new THREE.Vector3(x, (y0 + y1) / 2, z));
  // the pool of light the lantern throws on the pavement (shown after dusk)
  // centred a little away from the carriageway so it doesn't hang over the road
  let ax = 0, az = 0;
  if (Math.abs(z) > D.aKerb && Math.abs(z) < D.aFront && Math.abs(x) > D.bFront) az = Math.sign(z);
  else if (Math.abs(x) > D.bKerb && Math.abs(x) < D.bFront && Math.abs(z) > D.aFront) ax = Math.sign(x);
  else { ax = Math.sign(x) * 0.7; az = Math.sign(z) * 0.7; }
  const pool = new THREE.PlaneGeometry(6, 6); pool.rotateX(-Math.PI / 2); pool.translate(x + ax * 1.6, 0.02, z + az * 1.6);
  B.add("lightPool", pool.toNonIndexed());
}

function litfass(B, x, z) {
  // ~1.3 m across, posters to about 2.8 m, a ring cornice and a dome cap
  const T = new THREE.Matrix4().makeTranslation(x, 0, z);
  const add = (k, g) => { g.applyMatrix4(T); B.add(k, g); };
  add("lampIron", lathe([[0, 0], [0.74, 0], [0.74, 0.12], [0.7, 0.2], [0.66, 0.3], [0, 0.3]], 24));
  const body = new THREE.CylinderGeometry(0.65, 0.65, 2.55, 32, 1, true); body.translate(0, 0.3 + 1.275, 0);
  add("posters", body.toNonIndexed());
  add("lampIron", lathe([[0, 2.82], [0.66, 2.82], [0.74, 2.9], [0.78, 3.0], [0.78, 3.06], [0.7, 3.1], [0.5, 3.35], [0.25, 3.5], [0.1, 3.55], [0.06, 3.7], [0.1, 3.78], [0, 3.85]], 24));
}

function pump(B, x, z, rot) {
  // a Berlin street pump: a fluted green column, a lever arm and a spout with a basin grate
  const T = new THREE.Matrix4().makeRotationY(rot).setPosition(x, 0, z);
  const add = (k, g) => { g.applyMatrix4(T); B.add(k, g); };
  add("pumpGreen", lathe([[0, 0], [0.32, 0], [0.32, 0.12], [0.24, 0.2], [0.2, 0.35], [0.17, 1.4], [0.2, 1.5], [0.2, 1.62], [0.15, 1.7], [0.16, 1.82], [0.08, 1.95], [0.1, 2.05], [0, 2.15]], 12));
  add("pumpGreen", boxGeo(-0.05, 0.85, 0, 0.1, 0.1, 0.42));                                // spout
  add("pumpGreen", lathe([[0, 0], [0.05, 0.02], [0.05, 0.1], [0, 0.12]], 6).rotateX(Math.PI / 2).translate(0, 0.8, 0.43));
  const arm = new THREE.BoxGeometry(0.06, 0.06, 1.1); arm.rotateX(0.5); arm.translate(0, 1.55, -0.45); add("pumpGreen", arm.toNonIndexed());
  add("pumpGreen", lathe([[0, 0], [0.06, 0.02], [0, 0.1]], 8).translate(0, 1.27, -0.93));
  add("gully", boxGeo(-0.3, 0.004, 0.25, 0.6, 0.01, 0.5));
}

function bollard(B, x, z) {
  const g = lathe([[0, 0], [0.1, 0], [0.09, 0.6], [0.11, 0.65], [0.11, 0.7], [0.08, 0.74], [0.07, 0.82], [0.04, 0.88], [0, 0.9]], 10);
  g.translate(x, 0, z); B.add("lampIron", g);
}

function streetSign(B, text, x, y, z, along) {
  // white enamel plate, black lettering, mounted flat on the facade
  const a = new THREE.Vector3(along.x, 0, along.z).normalize();
  const M = facadeMatrix(new THREE.Vector3(x, y, z), a);
  const plate = new THREE.PlaneGeometry(1.15, 0.34); plate.translate(0, 0, 0.07); plate.applyMatrix4(M);
  B.add("sign:" + text + "|street", plate);
  const back = boxGeo(-0.6, -0.19, 0.0, 1.2, 0.38, 0.065); back.applyMatrix4(M); B.add("paintWhite", back);
}

// the orange litter bin (BSR) clamped to a post
function bin(B, x, z, rot) {
  const T = new THREE.Matrix4().makeRotationY(rot).setPosition(x, 0, z);
  const g = lathe([[0, 0.55], [0.17, 0.55], [0.19, 0.6], [0.2, 1.15], [0.21, 1.18], [0.18, 1.2], [0, 1.2]], 14);
  g.translate(0, 0, 0.26); g.applyMatrix4(T); B.add("binOrange", g);
  const clamp = boxGeo(-0.06, 0.95, 0.04, 0.12, 0.08, 0.06); clamp.applyMatrix4(T); B.add("lampIron", clamp);
}

// a tram stop: the yellow disc with the green H on a pole, and a timetable box
function tramStop(B, x, z) {
  const pole = lathe([[0, 0], [0.05, 0], [0.04, 2.9], [0, 2.9]], 8); pole.translate(x, 0, z); B.add("steel", pole);
  const disc = new THREE.CylinderGeometry(0.32, 0.32, 0.03, 28); disc.rotateX(Math.PI / 2);
  disc.translate(x, 2.7, z); B.add("stopSign", disc.toNonIndexed());
  B.add("paintWhite", boxGeo(x - 0.25, 1.4, z - 0.06, 0.5, 0.7, 0.1));
  B.add("frameDark", boxGeo(x - 0.27, 2.12, z - 0.07, 0.54, 0.16, 0.12));
}

function tramWires(B) {
  // span wires from facade rosettes across Street A every ~32 m, two contact wires
  const { L, aFront } = D;
  const hWire = 5.8, hSpan = 6.6;
  const wire = (p0, p1, r = 0.012) => {
    const len = p0.distanceTo(p1);
    const g = new THREE.CylinderGeometry(r, r, len, 4, 1, true);
    g.translate(0, len / 2, 0);
    const q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), p1.clone().sub(p0).normalize());
    g.applyQuaternion(q); g.translate(p0.x, p0.y, p0.z);
    B.add("wire", g.toNonIndexed());
  };
  const spans = [];
  for (let x = -L + 8; x < L; x += 32) spans.push(x);
  for (const x of spans) {
    const a = new THREE.Vector3(x, hSpan + 0.9, -aFront + 0.05), b = new THREE.Vector3(x, hSpan + 0.9, aFront - 0.05);
    // sagging span wire in a few pieces
    const pts = [];
    for (let i = 0; i <= 8; i++) { const t = i / 8; pts.push(new THREE.Vector3(x, hSpan + 0.9 - Math.sin(t * Math.PI) * 0.9, lerp(a.z, b.z, t))); }
    for (let i = 0; i < 8; i++) wire(pts[i], pts[i + 1], 0.008);
    // wall rosettes
    for (const z of [a.z, b.z]) { const r = new THREE.CylinderGeometry(0.11, 0.11, 0.06, 12); r.rotateX(Math.PI / 2); r.translate(x, a.y, z + Math.sign(-z) * 0.03); B.add("lampIron", r.toNonIndexed()); }
    // droppers to the contact wires
    for (const zc of [-1.55, 1.55]) wire(new THREE.Vector3(x, hWire, zc), new THREE.Vector3(x, hSpan + 0.9 - Math.cos(zc / aFront * Math.PI / 2) * 0.9, zc), 0.006);
  }
  for (const zc of [-1.55, 1.55]) for (let i = 0; i < spans.length - 1; i++) {
    const x0 = spans[i], x1 = spans[i + 1];
    for (let k = 0; k < 4; k++) {
      const t0 = k / 4, t1 = (k + 1) / 4;
      const y = (t) => hWire - Math.sin(t * Math.PI) * 0.12;
      wire(new THREE.Vector3(lerp(x0, x1, t0), y(t0), zc), new THREE.Vector3(lerp(x0, x1, t1), y(t1), zc), 0.007);
    }
  }
}

function buildProps() {
  const B = new Bucket();
  const { L, aFront, bFront, aKerb, bKerb } = D;
  // gas lanterns along the kerb-side mosaic, staggered
  for (let x = 20; x < L; x += 28) for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    const xx = sx * (x + (sz > 0 ? 14 : 0));
    if (Math.abs(xx) > L - 2) continue;
    gasLamp(B, xx, sz * (aKerb + 0.95), 0);
  }
  for (let z = 22; z < L; z += 28) for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    const zz = sz * (z + (sx > 0 ? 14 : 0));
    if (Math.abs(zz) > L - 2) continue;
    gasLamp(B, sx * (bKerb + 0.95), zz, 0);
  }
  // corner lanterns
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) gasLamp(B, sx * (bKerb + 3.2), sz * (aKerb + 3.2), 0);
  litfass(B, 8.6, -10.4);
  tramStop(B, 34, -8.85); tramStop(B, -30, 8.85);
  // bins on some lantern posts
  LAMPS.forEach((p, i) => { if (i % 3 === 0) bin(B, p.x, p.z, Math.abs(p.z) > Math.abs(p.x) ? (p.z > 0 ? Math.PI : 0) : (p.x > 0 ? -Math.PI / 2 : Math.PI / 2)); });
  pump(B, -9.3, 11.0, Math.PI * 0.75);
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    for (let k = 0; k < 3; k++) {
      // bollards round the corner kerb
      const cx = sx * (bKerb + 0.3 + D.kerbR), cz = sz * (aKerb + 0.3 + D.kerbR);
      const ang = Math.atan2(-sz, -sx) + (k - 1) * 0.42;
      bollard(B, cx + Math.cos(ang) * (D.kerbR - 0.45), cz + Math.sin(ang) * (D.kerbR - 0.45));
    }
  }
  tramWires(B);
  return B;
}
