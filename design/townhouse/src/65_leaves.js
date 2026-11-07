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

