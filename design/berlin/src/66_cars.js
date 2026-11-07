// ============================================================== parked cars
// Kerbside parking down both streets. Each car is a side profile extruded across its
// width with rounded edges, a glass cabin, wheels in the arches, lamps and a plate.

const CAR_COLOURS = ["#b9bcbf", "#8c9095", "#1d1f22", "#e9e9e6", "#24324a", "#7c1f1f", "#3a4a3a", "#c7c2b5", "#4a5560"];

function carProfiles() {
  // side outlines (front at +x), rounded at the nose and tail; the cabin sits on the beltline
  const round = (pts) => pts;
  return {
    hatch: { L: 4.25, W: 1.79, body: [[0.02, 0.3], [0.0, 0.42], [0.03, 0.58], [0.12, 0.7], [0.32, 0.8], [0.7, 0.86], [1.2, 0.9], [3.7, 0.93], [4.05, 0.92], [4.2, 0.86], [4.25, 0.72], [4.24, 0.45], [4.2, 0.3]],
      cabin: [[1.2, 0.9], [1.75, 1.25], [2.1, 1.41], [3.5, 1.44], [3.85, 1.3], [4.02, 0.93]], wheels: [0.85, 3.45] },
    sedan: { L: 4.7, W: 1.82, body: [[0.02, 0.3], [0.0, 0.44], [0.04, 0.6], [0.16, 0.72], [0.4, 0.8], [0.9, 0.86], [1.4, 0.9], [3.8, 0.93], [4.4, 0.92], [4.62, 0.86], [4.7, 0.7], [4.69, 0.45], [4.64, 0.3]],
      cabin: [[1.4, 0.9], [1.95, 1.25], [2.3, 1.42], [3.35, 1.43], [3.75, 1.2], [4.05, 0.93]], wheels: [0.95, 3.75] },
    estate: { L: 4.65, W: 1.8, body: [[0.02, 0.3], [0.0, 0.44], [0.04, 0.6], [0.16, 0.72], [0.4, 0.8], [0.9, 0.86], [1.35, 0.9], [4.4, 0.94], [4.6, 0.9], [4.65, 0.7], [4.64, 0.45], [4.6, 0.3]],
      cabin: [[1.35, 0.9], [1.9, 1.26], [2.25, 1.44], [4.35, 1.45], [4.55, 1.3], [4.6, 0.94]], wheels: [0.95, 3.75] },
    van: { L: 4.9, W: 1.9, body: [[0.02, 0.32], [0.0, 0.5], [0.05, 0.72], [0.18, 0.92], [0.45, 1.08], [0.8, 1.15], [4.85, 1.15], [4.9, 1.0], [4.9, 0.32]],
      cabin: [[0.8, 1.15], [1.15, 1.6], [1.45, 1.92], [4.8, 1.97], [4.9, 1.8], [4.9, 1.15]], wheels: [0.85, 4.0], tall: true },
  };
}

function extrudeSide(points, width, bevel) {
  const s = new THREE.Shape(points.map(p => new THREE.Vector2(p[0], p[1])));
  const g = new THREE.ExtrudeGeometry(s, { depth: width - bevel * 2, bevelEnabled: true, bevelSize: bevel * 0.6, bevelThickness: bevel, bevelSegments: 3, curveSegments: 4 });
  g.translate(0, 0, -(width - bevel * 2) / 2);
  return g.toNonIndexed();
}

function car(B, x, z, heading, rng) {
  const P = carProfiles();
  const type = rng.pick(["hatch", "hatch", "sedan", "estate", "estate", "van"]);
  const c = P[type];
  const paint = "car" + rng.int(0, CAR_COLOURS.length - 1);
  const T = new THREE.Matrix4().makeRotationY(heading).setPosition(x, D.road, z);
  const add = (k, g) => { g.translate(-c.L / 2, 0, 0); g.applyMatrix4(T); B.add(k, g); };
  // body: the lower outline closed along the bottom
  const body = [...c.body];
  add(paint, extrudeSide(body, c.W, 0.13));
  // cabin: glass, a little narrower, with a roof panel and pillars in the body colour
  const cab = [...c.cabin];
  add("carGlass", extrudeSide(cab, c.W - 0.16, 0.05));
  const roofY = Math.max(...cab.map(p => p[1]));
  const roofX0 = cab[2][0], roofX1 = cab[3][0];
  add(paint, boxGeo(roofX0 + 0.02, roofY - 0.03, -(c.W - 0.12) / 2, roofX1 - roofX0 - 0.04, 0.06, c.W - 0.12));
  const pillarX = (roofX0 + roofX1) / 2 - 0.05;
  for (const s of [-1, 1]) add(paint, boxGeo(pillarX, 0.93, s * (c.W - 0.16) / 2 - 0.035, 0.1, roofY - 0.95, 0.07));
  // dark sill and bumpers
  add("carTrim", boxGeo(0.25, 0.28, -c.W / 2 - 0.005, c.L - 0.5, 0.1, c.W + 0.01));
  add("carTrim", boxGeo(-0.03, 0.3, -c.W / 2 + 0.08, 0.1, 0.22, c.W - 0.16));
  add("carTrim", boxGeo(c.L - 0.07, 0.3, -c.W / 2 + 0.08, 0.1, 0.22, c.W - 0.16));
  // wheels
  for (const wx of c.wheels) for (const s of [-1, 1]) {
    const tyre = new THREE.CylinderGeometry(0.31, 0.31, 0.2, 18); tyre.rotateX(Math.PI / 2); tyre.translate(wx, 0.31, s * (c.W / 2 - 0.12));
    add("tyre", tyre.toNonIndexed());
    const rim = new THREE.CylinderGeometry(0.19, 0.19, 0.02, 12); rim.rotateX(Math.PI / 2); rim.translate(wx, 0.31, s * (c.W / 2 - 0.015));
    add("rim", rim.toNonIndexed());
  }
  // lamps and number plates (front is +x)
  for (const s of [-1, 1]) {
    add("headlamp", boxGeo(c.L - 0.06, 0.62, s * 0.62 - 0.17, 0.08, 0.12, 0.34));
    add("taillamp", boxGeo(-0.02, 0.7, s * 0.66 - 0.11, 0.06, 0.16, 0.22));
  }
  add("plate", boxGeo(c.L - 0.02, 0.36, -0.26, 0.03, 0.11, 0.52));
  add("plate", boxGeo(-0.03, 0.45, -0.26, 0.03, 0.11, 0.52));
  // wing mirrors
  for (const s of [-1, 1]) add(paint, boxGeo(c.cabin[0][0] + 0.15, 0.95, s * (c.W / 2 + 0.06) - 0.06, 0.12, 0.1, 0.12));
  return c.L;
}

function buildCars() {
  CAR_COLOURS.forEach((col, i) => MAT["car" + i] = new THREE.MeshStandardMaterial({ color: col, roughness: 0.32, metalness: 0.35, envMapIntensity: 0.8 }));
  MAT.carGlass = new THREE.MeshStandardMaterial({ color: "#1c2328", roughness: 0.05, metalness: 0.2, envMapIntensity: 1.2 });
  MAT.carTrim = new THREE.MeshStandardMaterial({ color: "#1b1b1c", roughness: 0.7 });
  MAT.tyre = new THREE.MeshStandardMaterial({ color: "#151515", roughness: 0.9 });
  MAT.rim = new THREE.MeshStandardMaterial({ color: "#9a9ea2", roughness: 0.35, metalness: 0.8 });
  MAT.headlamp = new THREE.MeshStandardMaterial({ color: "#dfe4e8", roughness: 0.1, metalness: 0.3 });
  MAT.taillamp = new THREE.MeshStandardMaterial({ color: "#8f1a16", roughness: 0.2 });
  MAT.plate = new THREE.MeshStandardMaterial({ color: "#e9e9e2", roughness: 0.5 });
  const B = new Bucket(), rng = new Rng(8080);
  const { L, aKerb, bKerb } = D;
  // Gordianstraße: parallel parking along both kerbs, heading with the traffic
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    let z = aKerb + 9;
    while (z < L - 4) {
      if (rng.chance(0.82)) {
        // right-hand traffic: on the +x kerb cars face -z
        const len = car(B, sx * (bKerb - 1.12), sz * (z + 2.4), sx > 0 ? Math.PI / 2 : -Math.PI / 2, rng);
        z += len + rng.range(0.7, 1.6);
      } else z += rng.range(3, 6);
    }
  }
  // Kettenstraße: parking outside the tram tracks, clear of the crossing and the tram stops
  for (const sz of [-1, 1]) for (const sx of [-1, 1]) {
    let x = bKerb + 10;
    while (x < L - 4) {
      const xx = sx * (x + 2.4);
      const nearStop = (sz < 0 && Math.abs(xx - 34) < 12) || (sz > 0 && Math.abs(xx + 30) < 12);
      if (!nearStop && rng.chance(0.8)) {
        const len = car(B, xx, sz * (aKerb - 1.12), sz > 0 ? 0 : Math.PI, rng);
        x += len + rng.range(0.7, 1.6);
      } else x += rng.range(3, 6);
    }
  }
  return B;
}
