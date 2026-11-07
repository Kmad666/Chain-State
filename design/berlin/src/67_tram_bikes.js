// ============================================================== the tram and bicycles
// A yellow Berlin tram standing at the stop on Kettenstraße, its pantograph up on the
// contact wire; bicycles locked to lantern posts along the pavements.

function tram(B, xFront, zTrack, dir) {
  // dir = -1: heading toward -x. Three articulated sections, 30 m in all.
  const H = 3.45, Wd = 2.4, floorY = D.road + 0.35;
  const T = new THREE.Matrix4().makeRotationY(dir < 0 ? Math.PI : 0).setPosition(xFront, 0, zTrack);
  const add = (k, g) => { g.applyMatrix4(T); B.add(k, g); };
  // local: front at x = 0, running back toward -x
  const sections = [[0, 9.6], [9.9, 19.8], [20.1, 30]];
  sections.forEach(([a, b], i) => {
    const len = b - a;
    // body with rounded vertical edges: an extruded plan shape
    const s = new THREE.Shape();
    const r = i === 0 ? 1.0 : 0.25, hw = Wd / 2;
    s.moveTo(-a, -hw + r); s.quadraticCurveTo(-a, -hw, -a - r, -hw); s.lineTo(-b + 0.25, -hw); s.quadraticCurveTo(-b, -hw, -b, -hw + 0.25);
    s.lineTo(-b, hw - 0.25); s.quadraticCurveTo(-b, hw, -b + 0.25, hw); s.lineTo(-a - r, hw); s.quadraticCurveTo(-a, hw, -a, hw - r); s.lineTo(-a, -hw + r);
    const lower = new THREE.ExtrudeGeometry(s, { depth: 1.15, bevelEnabled: false, curveSegments: 6 });
    lower.rotateX(-Math.PI / 2); lower.translate(0, floorY - 0.05, 0);
    add("tramYellow", lower.toNonIndexed());
    const band = new THREE.ExtrudeGeometry(s, { depth: 1.35, bevelEnabled: false, curveSegments: 6 });
    band.scale(0.999, 0.99, 1); band.rotateX(-Math.PI / 2); band.translate(0, floorY + 1.1, 0);
    add("tramGlass", band.toNonIndexed());
    const upper = new THREE.ExtrudeGeometry(s, { depth: 0.95, bevelEnabled: false, curveSegments: 6 });
    upper.rotateX(-Math.PI / 2); upper.translate(0, floorY + 2.45, 0);
    add("tramYellow", upper.toNonIndexed());
    // window pillars
    for (let x = a + 1.2; x < b - 0.5; x += 1.45) add("tramYellow", boxGeo(-x - 0.06, floorY + 1.1, -hw - 0.005, 0.12, 1.35, Wd + 0.01));
    // doors (two-leaf, glazed) on the platform side
    const side = -dir;   // the stop is on the tram's right
    for (const dx of [a + 2.2, a + len - 3.6]) {
      add("tramDoor", boxGeo(-dx - 1.3, floorY - 0.02, side > 0 ? hw - 0.02 : -hw - 0.03, 1.3, 2.05, 0.05));
    }
    // bogie skirts
    add("carTrim", boxGeo(-b + 0.6, D.road + 0.05, -hw + 0.08, len - 1.2, 0.32, Wd - 0.16));
    // roof equipment
    add("tramGrey", boxGeo(-b + 1.5, floorY + 3.4, -0.8, len - 3, 0.35, 1.6));
  });
  // bellows between sections
  for (const x of [9.6, 19.8]) add("carTrim", boxGeo(-x - 0.3, floorY + 0.1, -1.1, 0.3, 3.2, 2.2));
  // destination display and headlights
  add("tramDisplay", boxGeo(0.005, floorY + 2.55, -0.75, 0.02, 0.32, 1.5));
  for (const s of [-0.8, 0.8]) add("headlamp", boxGeo(0.0, floorY + 0.55, s - 0.12, 0.03, 0.12, 0.24));
  // pantograph up to the contact wire at 5.8 m
  const pz = 0, px = -14.8;
  const arm1 = new THREE.CylinderGeometry(0.03, 0.03, 1.6, 6); arm1.rotateZ(0.9); arm1.translate(px - 0.6, floorY + 4.25, pz); add("tramGrey", arm1.toNonIndexed());
  const arm2 = new THREE.CylinderGeometry(0.025, 0.025, 1.5, 6); arm2.rotateZ(-0.9); arm2.translate(px - 0.55, 5.25, pz); add("tramGrey", arm2.toNonIndexed());
  add("tramGrey", boxGeo(px - 1.3, 5.72, -0.9, 0.12, 0.06, 1.8));
}

function bicycle(B, x, z, ang, rng) {
  const T = new THREE.Matrix4().makeRotationY(ang).setPosition(x, 0, z);
  const add = (k, g) => { g.applyMatrix4(T); B.add(k, g); };
  const col = rng.pick(["bikeBlack", "bikeBlue", "bikeRed", "bikeGreen", "bikeBlack"]);
  const R = 0.34;
  for (const wx of [-0.52, 0.52]) {
    const w = new THREE.TorusGeometry(R, 0.022, 6, 24); w.translate(wx, R + 0.01, 0); add("tyre", w.toNonIndexed());
    for (let k = 0; k < 6; k++) { const sp = new THREE.CylinderGeometry(0.003, 0.003, R * 2, 3); sp.rotateZ(k * Math.PI / 6); sp.translate(wx, R + 0.01, 0); add("rim", sp.toNonIndexed()); }
  }
  const tube = (a, b, r = 0.016) => {
    const p0 = new THREE.Vector3(...a), p1 = new THREE.Vector3(...b), len = p0.distanceTo(p1);
    const g = new THREE.CylinderGeometry(r, r, len, 5); g.translate(0, len / 2, 0);
    g.applyQuaternion(new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), p1.clone().sub(p0).normalize()));
    g.translate(p0.x, p0.y, p0.z); add(col, g.toNonIndexed());
  };
  const bb = [0, 0.3, 0], seat = [-0.12, 0.85, 0], head = [0.4, 0.92, 0];
  tube([-0.52, R, 0], bb); tube(bb, seat); tube(seat, [-0.52, R, 0]); tube(seat, head); tube(bb, head); tube(head, [0.52, R, 0]);
  tube(head, [0.36, 1.05, 0]); tube([0.36, 1.05, -0.28], [0.36, 1.05, 0.28], 0.014);
  add("carTrim", boxGeo(-0.24, 0.86, -0.07, 0.24, 0.05, 0.14));
}

function buildTramAndBikes() {
  MAT.tramYellow = new THREE.MeshStandardMaterial({ color: "#f0c419", roughness: 0.4, metalness: 0.2 });
  MAT.tramGlass = new THREE.MeshStandardMaterial({ color: "#20262b", roughness: 0.05, envMapIntensity: 1.1 });
  MAT.tramDoor = new THREE.MeshStandardMaterial({ color: "#3a4046", roughness: 0.2, metalness: 0.3 });
  MAT.tramGrey = new THREE.MeshStandardMaterial({ color: "#7d8287", roughness: 0.5, metalness: 0.4 });
  const dc = canvas(512, 96), dx = dc.getContext("2d");
  dx.fillStyle = "#111"; dx.fillRect(0, 0, 512, 96); dx.fillStyle = "#ffb000"; dx.font = "bold 58px Arial, sans-serif"; dx.textBaseline = "middle";
  dx.fillText("M2  Kettenplatz", 16, 50);
  MAT.tramDisplay = new THREE.MeshStandardMaterial({ map: toTex(dc, true, false), emissive: new THREE.Color("#ffb000"), emissiveMap: toTex(dc, true, false), emissiveIntensity: 0.6 });
  for (const [k, c] of [["bikeBlack", "#1e1e1e"], ["bikeBlue", "#2b4a7a"], ["bikeRed", "#8c2a24"], ["bikeGreen", "#3c5a40"]]) MAT[k] = new THREE.MeshStandardMaterial({ color: c, roughness: 0.4, metalness: 0.5 });
  const B = new Bucket(), rng = new Rng(616);
  // the tram stands at the stop on the north side, heading west
  tram(B, 21, -1.55, -1);
  // bicycles locked to some lantern posts, parallel to the kerb
  LAMPS.forEach((p, i) => {
    if (i % 4 !== 1) return;
    const alongX = Math.abs(p.z) > D.aKerb && Math.abs(p.z) < D.aFront && Math.abs(p.x) > D.bFront;
    const off = alongX ? [0, Math.sign(p.z) * 0.3] : [Math.sign(p.x) * 0.3, 0];
    bicycle(B, p.x + off[0], p.z + off[1], alongX ? 0 : Math.PI / 2, rng);
  });
  return B;
}
