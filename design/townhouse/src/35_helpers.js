// helpers shared with the Berlin district study
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

function orientUp(g) {
  const p = g.attributes.position.array;
  for (let i = 0; i < p.length; i += 9) {
    const ux = p[i + 3] - p[i], uz = p[i + 5] - p[i + 2], vx = p[i + 6] - p[i], vz = p[i + 8] - p[i + 2];
    if (uz * vx - ux * vz < 0) for (let k = 0; k < 3; k++) { const t = p[i + 3 + k]; p[i + 3 + k] = p[i + 6 + k]; p[i + 6 + k] = t; }
  }
}

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
