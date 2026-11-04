// ============================================================== the district
// Four perimeter blocks meet at the crossing of Kettenstraße (Street A, with the tram)
// and Gordianstraße (Street B). Each block has a corner house with a cut corner, then
// lots of 15-22 m along both streets. Behind: courtyards, side wings and firewalls.

const STREET_A = "Kettenstraße", STREET_B = "Gordianstraße";
const UP = new THREE.Vector3(0, 1, 0);

// Each quadrant's plan, listed from the corner outward: style, condition (0 fresh .. 1
// never renovated), and a few specials.
const QUADRANTS = {
  "1,1":   { corner: { style: "corner", tower: true, pubName: "Zur Kette", cond: 0.25, scheme: 1 },
             A: [{ style: "rich", cond: 0.3 }, { style: "stripped", cond: 0.9 }, { style: "moderate", cond: 0.4 }, { style: "nouveau", cond: 0.2 }],
             B: [{ style: "moderate", cond: 0.35 }, { style: "brick", cond: 0.4 }, { style: "rich", cond: 0.15 }, { style: "moderate", cond: 0.5 }] },
  "-1,1":  { corner: { style: "rich", tower: false, cond: 0.45, scheme: 2, shopsOnly: true },
             A: [{ style: "nouveau", cond: 0.3 }, { style: "gap" }, { style: "rich", cond: 0.2 }, { style: "moderate", cond: 0.6 }],
             B: [{ style: "rich", cond: 0.85 }, { style: "moderate", cond: 0.3 }, { style: "nouveau", cond: 0.35 }, { style: "stripped", cond: 0.6 }] },
  "1,-1":  { corner: { style: "corner", tower: true, cond: 0.3, scheme: 6, pubName: "Eckkneipe Gordian" },
             A: [{ style: "moderate", cond: 0.25 }, { style: "gdr" }, { style: "rich", cond: 0.4 }, { style: "brick", cond: 0.3 }],
             B: [{ style: "nouveau", cond: 0.2 }, { style: "moderate", cond: 0.45 }, { style: "stripped", cond: 0.35 }, { style: "rich", cond: 0.3 }] },
  "-1,-1": { corner: { style: "moderate", tower: false, cond: 0.82, scheme: 0 },
             A: [{ style: "moderate", cond: 0.3 }, { style: "rich", cond: 0.25 }, { style: "nouveau", cond: 0.5 }, { style: "moderate", cond: 0.2 }],
             B: [{ style: "stripped", cond: 0.3 }, { style: "rich", cond: 0.35 }, { style: "moderate", cond: 0.9 }, { style: "brick", cond: 0.2 }] },
};

const GAP_GREEN = { trees: [], bushes: [] };

function facadeSeg(p0, p1, extra = {}) {
  const along = p1.clone().sub(p0); const width = along.length(); along.normalize();
  return { origin: p0.clone(), along, width, ...extra };
}

function buildDistrict(scene, progress) {
  const { L, aFront, bFront, chamfer: c } = D;
  const groups = [];
  const rngD = new Rng(2026);
  const extras = new Bucket();
  let seed = 100;
  const jobs = [];
  for (const key of Object.keys(QUADRANTS)) {
    const [sx, sz] = key.split(",").map(Number);
    const Q = QUADRANTS[key];
    const V = (x, z) => new THREE.Vector3(x, 0, z);
    // the corner house
    const wA = rngD.range(14, 17), wB = rngD.range(14, 17);
    const farA = V(sx * (bFront + c + wA), sz * aFront), PA = V(sx * (bFront + c), sz * aFront);
    const PB = V(sx * bFront, sz * (aFront + c)), farB = V(sx * bFront, sz * (aFront + c + wB));
    const segs = sx * sz > 0
      ? [facadeSeg(farA, PA, { street: "A" }), facadeSeg(PA, PB, { chamfer: true }), facadeSeg(PB, farB, { street: "B" })]
      : [facadeSeg(farB, PB, { street: "B" }), facadeSeg(PB, PA, { chamfer: true }), facadeSeg(PA, farA, { street: "A" })];
    const cq = Q.corner;
    jobs.push({ seed: seed++, name: `corner ${key}`, style: cq.style === "corner" ? "corner" : cq.style, tower: cq.tower, cond: cq.cond,
      scheme: SCHEMES[cq.scheme], segments: segs, depth: 13, shops: true, pubName: cq.pubName, gateAxis: undefined, roof: "mansard", corner: [sx, sz] });
    // the lots along each street
    for (const street of ["A", "B"]) {
      let u = street === "A" ? bFront + c + wA : aFront + c + wB;
      const plans = Q[street];
      for (let i = 0; i < plans.length; i++) {
        const remaining = L - u;
        const w = i === plans.length - 1 ? remaining : Math.min(remaining - 14, rngD.range(15, 21));
        const p0 = street === "A" ? V(sx * u, sz * aFront) : V(sx * bFront, sz * u);
        const p1 = street === "A" ? V(sx * (u + w), sz * aFront) : V(sx * bFront, sz * (u + w));
        // order the ends so that the facade faces the street
        const out = street === "A" ? new THREE.Vector3(0, 0, -sz) : new THREE.Vector3(-sx, 0, 0);
        const a = new THREE.Vector3().crossVectors(UP, out);
        const seg = p1.clone().sub(p0).dot(a) > 0 ? facadeSeg(p0, p1, { street }) : facadeSeg(p1, p0, { street });
        const pl = plans[i];
        if (pl.style === "gap") jobs.push({ gap: true, seg, street, quadrant: [sx, sz] });
        else jobs.push({ seed: seed++, name: `${street} ${key} ${i}`, style: pl.style, cond: pl.cond ?? 0.4, segments: [seg], depth: 13,
          gateWide: rngD.chance(0.4), street });
        u += w;
      }
    }
  }
  return { jobs, extras };
}

// A vacant lot (Baulücke): a hoarding of posters along the pavement, rubble and weeds,
// and the neighbour's bare firewall with a faded painted advertisement.
function buildGap(job, B) {
  const s = job.seg, a = s.along, n = new THREE.Vector3().crossVectors(a, UP);
  const W = s.width;
  // ground
  const p = (u, v) => s.origin.clone().addScaledVector(a, u).addScaledVector(n, -v);
  const q = [p(0, 0), p(W, 0), p(W, 13), p(0, 13)].map(v => [v.x, v.z]);
  B.add("gravel", groundPoly(q, 0.005, 4));
  // hoarding: boards with posters, set 0.2 m back from the building line
  const M = facadeMatrix(p(0, 0.2), a);
  const hoard = new THREE.PlaneGeometry(W, 2.6); hoard.translate(W / 2, 1.3, 0); hoard.applyMatrix4(M);
  const uv = hoard.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * W / 6, uv.getY(i));
  B.add("hoarding", hoard);
  for (let u = 1.5; u < W - 2; u += 3.4) { const t = new THREE.PlaneGeometry(1.8, 0.9); t.translate(u + 0.9, 1.4 + (u % 2) * 0.3, 0.015); t.applyMatrix4(M); B.add("tag" + (Math.floor(u) % 8), t); }
  const back = new THREE.PlaneGeometry(W, 2.6); back.rotateY(Math.PI); back.translate(W / 2, 1.3, -0.03); back.applyMatrix4(M); B.add("doorWood", back);
  for (let u = 0; u < W; u += 2.5) { const post = boxGeo(u, 0, -0.12, 0.1, 2.75, 0.1); post.applyMatrix4(M); B.add("doorWood", post); }
  // self-seeded trees and scrub (planted later with the street trees, same leaf cards)
  const rng = new Rng(77);
  for (let k = 0; k < 10; k++) { const pos = p(rng.range(1, W - 1), rng.range(2, 12)); GAP_GREEN.bushes.push(pos); }
  for (const [u, v] of [[W * 0.35, 7], [W * 0.72, 10]]) GAP_GREEN.trees.push(p(u, v));
  // ghost sign on the firewall of the house on the gap's left (its wall faces +a)
  const centre = p(0.05, 6.5).add(new THREE.Vector3(0, 11.5, 0));
  const along = new THREE.Vector3().crossVectors(UP, a);     // (up x a) x up = a: the plane faces +a
  const Mg = facadeMatrix(centre, along);
  const sign = new THREE.PlaneGeometry(10, 5); sign.applyMatrix4(Mg);
  B.add("ghost", sign);
}

// The blocks beyond: simple boxes with a painted window grid, pitched roofs.
function buildSurroundings() {
  const B = new Bucket();
  const xs = [-340, -175, 0, 175, 340], zs = [-350, -185, 0, 185, 350];
  const rng = new Rng(5150);
  const hw = (i, list) => (list[i] === 0 ? (list === xs ? D.bFront : D.aFront) : 11);
  for (let i = 0; i < xs.length - 1; i++) for (let j = 0; j < zs.length - 1; j++) {
    const x0 = xs[i] + hw(i, xs), x1 = xs[i + 1] - hw(i + 1, xs);
    const z0 = zs[j] + hw(j, zs), z1 = zs[j + 1] - hw(j + 1, zs);
    // four sides of the block: [start, end, outward normal]
    const sides = [
      [[x0, z0], [x1, z0], [0, -1]], [[x1, z0], [x1, z1], [1, 0]], [[x1, z1], [x0, z1], [0, 1]], [[x0, z1], [x0, z0], [-1, 0]],
    ];
    for (const [s0, s1, nrm] of sides) {
      const len = Math.hypot(s1[0] - s0[0], s1[1] - s0[1]);
      const dir = [(s1[0] - s0[0]) / len, (s1[1] - s0[1]) / len];
      const onA = Math.abs(s0[1]) === D.aFront && s0[1] === s1[1];
      const onB = Math.abs(s0[0]) === D.bFront && s0[0] === s1[0];
      for (let u = 13; u < len - 13; ) {
        const w = Math.min(len - 13 - u, rng.range(15, 22));
        let m0 = [s0[0] + dir[0] * u, s0[1] + dir[1] * u], m1 = [s0[0] + dir[0] * (u + w), s0[1] + dir[1] * (u + w)];
        u += w;
        // the detailed district covers |x| < L along Street A and |z| < L along Street B: clip to it
        if (onA || onB) {
          const k = onA ? 0 : 1;
          const lo = Math.min(Math.abs(m0[k]), Math.abs(m1[k])), hi = Math.max(Math.abs(m0[k]), Math.abs(m1[k]));
          if (hi <= D.L) continue;
          if (lo < D.L) {
            const sign = Math.sign(m0[k] + m1[k]);
            if (Math.abs(m0[k]) < D.L) m0 = k === 0 ? [sign * D.L, m0[1]] : [m0[0], sign * D.L];
            else m1 = k === 0 ? [sign * D.L, m1[1]] : [m1[0], sign * D.L];
          }
          if (Math.hypot(m1[0] - m0[0], m1[1] - m0[1]) < 4) continue;
        }
        distantHouse(B, m0, m1, nrm, rng);
      }
    }
    // corners of the block (simple squares)
    for (const [cx, cz] of [[x0, z0], [x1, z0], [x1, z1], [x0, z1]]) {
      if (Math.abs(cx) < D.L + 2 && Math.abs(cz) < D.L + 2) continue;
      const g = boxGeo(Math.min(cx, cx + Math.sign(-cx || 1) * 13), 0, Math.min(cz, cz + Math.sign(-cz || 1) * 13), 13, rng.range(19, 22), 13);
      B.add(rng.pick(["distA", "distB", "distC"]), boxUV(g.toNonIndexed(), 6.4));
    }
  }
  return B;
}
function distantHouse(B, m0, m1, nrm, rng) {
  const H = rng.range(19, 22), Dd = 13;
  const a = new THREE.Vector3(m1[0] - m0[0], 0, m1[1] - m0[1]); const w = a.length(); a.normalize();
  const n = new THREE.Vector3(nrm[0], 0, nrm[1]);
  // a box from the street line inward
  const o = new THREE.Vector3(m0[0], 0, m0[1]);
  // make sure the facade faces outward (n); flip along if needed
  const out = new THREE.Vector3().crossVectors(a, UP);
  let origin = o, along = a;
  if (out.dot(n) < 0) { origin = new THREE.Vector3(m1[0], 0, m1[1]); along = a.clone().negate(); }
  const F = facadeMatrix(origin, along);
  const front = new THREE.PlaneGeometry(w, H); front.translate(w / 2, H / 2, 0);
  const uv = front.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * Math.max(1, Math.round(w / 6.6)), uv.getY(i));
  front.applyMatrix4(F);
  B.add(rng.pick(["distA", "distB", "distC", "distD", "distE", "distF"]), front.toNonIndexed());
  // roof prism
  const back = origin.clone().addScaledVector(out.dot(n) < 0 ? out.clone().negate() : out, -Dd);
  const v = (p, y) => [p.x, y, p.z];
  const nn = out.dot(n) < 0 ? out.clone().negate() : out.clone();
  const f0 = origin, f1 = origin.clone().addScaledVector(along, w);
  const k0 = f0.clone().addScaledVector(nn, -Dd / 2), k1 = f1.clone().addScaledVector(nn, -Dd / 2);
  const r0 = f0.clone().addScaledVector(nn, -Dd), r1 = f1.clone().addScaledVector(nn, -Dd);
  const g = new THREE.BufferGeometry();
  const R = H + 5;
  g.setAttribute("position", new THREE.Float32BufferAttribute([
    ...v(f0, H), ...v(f1, H), ...v(k1, R), ...v(f0, H), ...v(k1, R), ...v(k0, R),
    ...v(r1, H), ...v(r0, H), ...v(k0, R), ...v(r1, H), ...v(k0, R), ...v(k1, R)], 3));
  orientUp(g); g.computeVertexNormals(); boxUV(g, 2);
  B.add("distantRoof", g);
  // rear wall
  const rw = new THREE.PlaneGeometry(w, H); rw.rotateY(Math.PI); rw.translate(w / 2, H / 2, -Dd); rw.applyMatrix4(F); boxUV(rw, 6);
  B.add("distA", rw.toNonIndexed());
}
