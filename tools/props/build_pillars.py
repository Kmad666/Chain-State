"""
Roman pillars for the level editor, modelled in code.

    python3 tools/props/build_pillars.py   ->  assets/models/props/pillars/<name>.glb
                                               assets/models/props/pillars/props.json

Six pieces, in the proportions of the orders as Vignola set them out (D is the
column's lower diameter, 1 m here unless noted):

  tuscan       7 D. Plain shaft with entasis, a torus base, echinus and abacus.
  doric        8 D. 20 shallow flutes meeting in sharp arrises, three annulets.
  ionic        9 D. Attic base, 24 flutes with fillets, a capital with volutes.
  corinthian   10 D (1.2 m). Attic base, 24 flutes, two rows of acanthus leaves,
               corner volutes under a concave abacus.
  broken       a fallen-short Doric shaft on its base, the break jagged.
  entablature  a 6 m beam for the columns' tops: three-fascia architrave, plain
               frieze, a cornice with dentils.

Kept light for a game: turned parts are 32-sided, flutes have five facets each,
curves are shaded smooth and corners sharp (split normals), and the shading in
every hollow (flutes, scotia, under the capital) is baked into the vertex colours
as ambient occlusion, so the stone reads as carved without extra geometry. Godot
builds distance LODs on import. Collision is a few boxes and cylinders per piece,
listed in props.json with each piece's bounding box.

Needs numpy, trimesh, rtree.
"""
import json
import math
import os
import sys
import numpy as np
import trimesh

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models", "props", "pillars"))
TURN = 32           # sides on turned (round) parts
rng = np.random.default_rng(7)


# ------------------------------------------------------------------ mesh helpers

def mesh(v, f):
    return trimesh.Trimesh(vertices=np.asarray(v, float), faces=np.asarray(f, int), process=False)


def grid_faces(rows, cols, wrap=True):
    """Quads joining `rows` rings of `cols` points (wrapping round)."""
    f = []
    cc = cols if wrap else cols - 1
    for i in range(rows - 1):
        for k in range(cc):
            a = i * cols + k
            b = i * cols + (k + 1) % cols
            c = (i + 1) * cols + k
            d = (i + 1) * cols + (k + 1) % cols
            f += [[a, b, c], [b, d, c]]
    return f


def lathe(profile, sides=TURN, cap_bottom=False, cap_top=False):
    """Turn a profile [(radius, y), ...] (bottom to top) about the Y axis."""
    rings = []
    for r, y in profile:
        a = np.linspace(0, 2 * np.pi, sides, endpoint=False)
        rings.append(np.stack([np.cos(a) * r, np.full(sides, y), np.sin(a) * r], 1))
    v = np.concatenate(rings)
    f = grid_faces(len(profile), sides)
    if cap_bottom:
        v = np.vstack([v, [0, profile[0][1], 0]])
        c = len(v) - 1
        f += [[c, (k + 1) % sides, k] for k in range(sides)]
    if cap_top:
        v = np.vstack([v, [0, profile[-1][1], 0]])
        c = len(v) - 1
        base = (len(profile) - 1) * sides
        f += [[c, base + k, base + (k + 1) % sides] for k in range(sides)]
    return outward(mesh(v, f))


def outward(m):
    """Wind faces so they point away from the Y axis (or out of a box-like solid)."""
    c = m.triangles_center
    n = m.face_normals
    radial = c - np.array([0, c[:, 1].mean(), 0]) * 0
    radial[:, 1] = 0
    score = np.sum(n * radial, axis=1)
    if np.sum(score > 0) < np.sum(score < 0):
        m.faces = m.faces[:, ::-1]
    return m


def box(size, centre):
    b = trimesh.creation.box(extents=size)
    b.apply_translation(centre)
    return b


def ring_profile(points, steps=4):
    """Expand profile primitives into a dense list of (r, y).
    Each item: ('line', (r, y)) or ('arc', (r_centre, y_centre, radius, a0, a1)) in
    degrees, measured from +r toward +y."""
    out = []
    for kind, data in points:
        if kind == "pt":
            out.append(data)
        else:
            rc, yc, rad, a0, a1 = data
            for i in range(steps + 1):
                a = math.radians(a0 + (a1 - a0) * i / steps)
                out.append((rc + rad * math.cos(a), yc + rad * math.sin(a)))
    # drop exact repeats
    clean = [out[0]]
    for p in out[1:]:
        if abs(p[0] - clean[-1][0]) > 1e-6 or abs(p[1] - clean[-1][1]) > 1e-6:
            clean.append(p)
    return clean


# ------------------------------------------------------------------ shafts

def shaft(y0, y1, r0, r1, flutes=0, fillet=0.0, depth=0.0, per=5, sides=TURN):
    """A column shaft from y0 to y1 with entasis (straight for the lower third,
    then curving in to r1). With flutes: `flutes` channels, `fillet` the share of
    each left flat between them (0: sharp arrises, the Doric way), `depth` as a
    fraction of the radius. Flutes fade out in rounded ends near the top and foot."""
    def radius(y):
        t = (y - y0) / (y1 - y0)
        if t < 1 / 3:
            return r0
        u = (t - 1 / 3) / (2 / 3)
        return r0 + (r1 - r0) * (1 - math.cos(u * math.pi / 2))

    ys = [y0, y0 + 0.05, y0 + 0.13, y0 + (y1 - y0) / 3, y0 + (y1 - y0) * 0.55,
          y0 + (y1 - y0) * 0.78, y1 - 0.13, y1 - 0.05, y1]
    fade = [0, 0.15, 1, 1, 1, 1, 1, 0.15, 0]
    if flutes == 0:
        return lathe([(radius(y), y) for y in ys], sides)
    # one ring: per flute, the fillet's two corners then the channel's facets
    angs, shape = [], []
    span = 2 * np.pi / flutes
    for k in range(flutes):
        a0 = k * span
        if fillet > 0:
            angs += [a0, a0 + span * fillet]
            shape += [0.0, 0.0]
            g0, g1 = a0 + span * fillet, a0 + span
        else:
            angs.append(a0)
            shape.append(0.0)
            g0, g1 = a0, a0 + span
        for i in range(1, per):
            t = i / per
            angs.append(g0 + (g1 - g0) * t)
            shape.append(math.sin(math.pi * t))          # 0 at the edges, 1 mid-channel
    angs, shape = np.array(angs), np.array(shape)
    n = len(angs)
    rings = []
    for y, fd in zip(ys, fade):
        r = radius(y)
        rr = r * (1 - depth * fd * shape)
        rings.append(np.stack([np.cos(angs) * rr, np.full(n, y), np.sin(angs) * rr], 1))
    return outward(mesh(np.concatenate(rings), grid_faces(len(ys), n)))


# ------------------------------------------------------------------ bases and capitals

def attic_base(y0, r, plinth=True):
    """Plinth, lower torus, scotia between fillets, upper torus, fillet (Vitruvius'
    Attic base), half a diameter tall for a column of radius r."""
    D = 2 * r
    parts = []
    h = 0.5 * D
    if plinth:
        ph = h / 3
        parts.append(box((D * 1.36, ph, D * 1.36), (0, y0 + ph / 2, 0)))
        y = y0 + ph
    else:
        y = y0
    rest = h - (y - y0)
    t1 = rest * 0.36      # lower torus
    sc = rest * 0.32      # scotia with its fillets
    t2 = rest * 0.26      # upper torus
    prof = ring_profile([
        ("arc", (r * 1.18, y + t1 / 2, t1 / 2, -90, 90)),
        ("pt", (r * 1.08, y + t1)), ("pt", (r * 1.08, y + t1 + sc * 0.12)),
        ("arc", (r * 1.10, y + t1 + sc * 0.55, sc * 0.4, -90, -270)),
        ("pt", (r * 1.03, y + t1 + sc)),
        ("arc", (r * 1.10, y + t1 + sc + t2 / 2, t2 / 2, -90, 90)),
        ("pt", (r * 1.03, y + t1 + sc + t2)), ("pt", (r * 1.03, y + h)), ("pt", (r * 0.98, y0 + h)),
    ])
    parts.append(lathe(prof))
    return parts, y0 + h


def tuscan_base(y0, r):
    D = 2 * r
    h = 0.5 * D
    ph = h * 0.5
    parts = [box((D * 1.33, ph, D * 1.33), (0, y0 + ph / 2, 0))]
    y = y0 + ph
    t = h * 0.42
    prof = ring_profile([("arc", (r * 1.12, y + t / 2, t / 2, -90, 90)),
                         ("pt", (r * 1.06, y + t)), ("pt", (r * 1.06, y0 + h)), ("pt", (r * 0.98, y0 + h))])
    parts.append(lathe(prof))
    return parts, y0 + h


def tuscan_capital(y0, r):
    """Astragal, neck, echinus (a quarter round) and a square abacus."""
    D = 2 * r
    prof = ring_profile([
        ("pt", (r * 0.98, y0)), ("arc", (r * 1.05, y0 + 0.045 * D, 0.045 * D, -90, 90)),
        ("pt", (r * 1.0, y0 + 0.09 * D)), ("pt", (r * 0.98, y0 + 0.11 * D)), ("pt", (r * 0.98, y0 + 0.24 * D)),
        ("pt", (r * 1.04, y0 + 0.26 * D)),
        ("arc", (r * 1.04, y0 + 0.36 * D, 0.10 * D, -90, 0)),
        ("pt", (r * 1.20, y0 + 0.37 * D)), ("pt", (0.0, y0 + 0.37 * D)),
    ])
    ab = 0.13 * D
    return [lathe(prof), box((D * 1.25, ab, D * 1.25), (0, y0 + 0.37 * D + ab / 2, 0))], y0 + 0.5 * D


def doric_capital(y0, r):
    """Neck, three annulets, an echinus, and an abacus crowned by a small ogee."""
    D = 2 * r
    pts = [("pt", (r * 0.99, y0)), ("arc", (r * 1.05, y0 + 0.04 * D, 0.04 * D, -90, 90)),
           ("pt", (r * 0.99, y0 + 0.08 * D)), ("pt", (r * 0.99, y0 + 0.20 * D))]
    y = y0 + 0.20 * D
    for k in range(3):      # the annulets: little steps out
        pts += [("pt", (r * (1.03 + 0.02 * k), y)), ("pt", (r * (1.03 + 0.02 * k), y + 0.018 * D))]
        y += 0.018 * D
    pts += [("arc", (r * 1.08, y + 0.10 * D, 0.10 * D, -90, -10)),
            ("pt", (r * 1.26, y + 0.12 * D)), ("pt", (0.0, y + 0.12 * D))]
    y += 0.12 * D
    ab = 0.11 * D
    parts = [lathe(ring_profile(pts)), box((D * 1.30, ab, D * 1.30), (0, y + ab / 2, 0))]
    # the abacus' crowning moulding, a thin step
    parts.append(box((D * 1.36, 0.03 * D, D * 1.36), (0, y + ab + 0.015 * D, 0)))
    return parts, y + ab + 0.03 * D


def ionic_capital(y0, r):
    """Astragal, an echinus (ovolo), the volutes on either side joined by their
    bolsters and the canalis, and a thin abacus."""
    D = 2 * r
    parts = []
    prof = ring_profile([("pt", (r * 0.99, y0)), ("arc", (r * 1.05, y0 + 0.035 * D, 0.035 * D, -90, 90)),
                         ("pt", (r * 0.99, y0 + 0.07 * D)), ("pt", (r * 1.0, y0 + 0.10 * D)),
                         ("arc", (r * 1.0, y0 + 0.22 * D, 0.12 * D, -90, 0)),
                         ("pt", (r * 1.24, y0 + 0.22 * D)), ("pt", (0.0, y0 + 0.22 * D))])
    parts.append(lathe(prof))
    yb = y0 + 0.22 * D                      # top of the echinus: the volutes' band sits here
    R = 0.25 * D                            # a volute's outer radius
    xc = 0.60 * D                           # its eye, out from the axis
    yc = yb - 0.06 * D
    zf = 0.40 * D                           # the front and back faces
    # the bolsters (pulvini): a roll along z behind each pair of volutes, waisted
    # in the middle by a band (balteus)
    for sx in (-1, 1):
        prof = []
        for i in range(9):
            z = -zf + 2 * zf * i / 8
            w = 1.0 - 0.18 * (1 - (z / zf) ** 2) + (0.04 if abs(z) < 0.03 * D else 0.0)
            prof.append((R * 0.93 * w, z))
        b = lathe(prof, sides=24, cap_bottom=True, cap_top=True)
        b.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2, [1, 0, 0]))
        b.apply_translation([sx * xc, yc, 0])
        parts.append(b)
    # the canalis: the band across each face from volute to volute, over the echinus
    for sz in (-1, 1):
        parts.append(box((2 * xc, 0.10 * D, 0.03 * D), (0, yb - 0.01 * D, sz * zf)))
    # the volute spirals on each face, raised bands winding in to the eye
    for sx in (-1, 1):
        for sz in (-1, 1):
            parts.append(volute(np.array([sx * xc, yc, sz * zf]), R, sx, sz, turns=2.6, band=0.09 * D,
                                lift=0.022 * D))
    ab = 0.07 * D
    parts.append(box((2 * xc, 0.05 * D, 2 * zf * 0.95), (0, yb + 0.015 * D, 0)))   # the bed under the abacus
    parts.append(box((D * 1.30, ab, D * 1.10), (0, yb + 0.04 * D + ab / 2, 0)))
    return parts, yb + 0.04 * D + ab


def volute(eye, R, sx, sz, turns, band, lift, samples=64, sides=5, disc_sides=24, boss=1):
    """A spiral band on a volute's face: starting at the top on the inner side and
    winding outward round and in to the eye, its width shrinking as it goes."""
    k = math.log(1 / 0.16) / (turns * 2 * math.pi)       # outer radius to the eye's
    pts, widths = [], []
    for i in range(samples):
        t = i / (samples - 1)
        phi = t * turns * 2 * math.pi
        rr = R * math.exp(-k * phi)
        # start at the top, heading outward (away from the column) then down
        ang = math.pi / 2 - phi if sx > 0 else math.pi / 2 + phi
        pts.append(eye + np.array([math.cos(ang) * rr, math.sin(ang) * rr, 0]))
        widths.append(band * (0.35 + 0.65 * rr / R))
    pts = np.array(pts)
    v, f = [], []
    out = np.array([0, 0, sz], float)                    # off the face
    for i, p in enumerate(pts):
        tdir = pts[min(i + 1, samples - 1)] - pts[max(i - 1, 0)]
        tdir /= np.linalg.norm(tdir)
        side = np.cross(out, tdir)
        side /= np.linalg.norm(side)
        w = widths[i] * 0.5
        # a flattened, rounded section: the band stands `lift` proud of the face
        for j in range(sides):
            a = math.pi * j / (sides - 1)
            v.append(p + side * math.cos(a) * w + out * math.sin(a) * lift)
    for i in range(samples - 1):
        for j in range(sides - 1):
            a = i * sides + j
            b = a + 1
            c = a + sides
            d = c + 1
            f += [[a, c, b], [b, c, d]]
    m = mesh(v, f)
    if np.mean(np.sum(m.face_normals * out, axis=1)) < 0:
        m.faces = m.faces[:, ::-1]
    # the volute's face, a disc under the band
    disc = trimesh.creation.cylinder(radius=R * 0.98, height=0.012, sections=disc_sides)   # axis along z already
    disc.apply_translation(eye - out * 0.006)
    # the eye: a small boss
    boss = trimesh.creation.icosphere(subdivisions=boss, radius=R * 0.15)
    boss.apply_scale([1, 1, 0.5])
    boss.apply_translation(eye + out * lift * 0.4)
    return trimesh.util.concatenate([m, disc, boss])


def acanthus_leaf(theta, y0, height, width, bell, hook, rows=10, cols=7, thick=0.006):
    """One acanthus leaf on the bell of a Corinthian capital: a blade rising close
    against the bell from y0, rounded in section with a raised rib, its edges cut
    into pointed lobes, its top rolling forward and down into a hook of radius
    `hook`. `bell(y)` is the bell's radius. The back is modelled only where it
    shows: under the bent tip."""
    straight = height - hook * 1.2
    vs, back = [], []
    for i in range(rows):
        v = i / (rows - 1)
        # outline: narrow at the foot, broadest below the middle, to a point
                # broad and overlapping its neighbours low down, narrowing above so each
        # leaf's roll stands on its own, rounding off at the tip
        if v < 0.3:
            f = 0.9 + 0.1 * v / 0.3
        elif v < 0.55:
            f = 1.0
        else:
            f = 0.12 + 0.88 * math.cos(math.pi / 2 * (v - 0.55) / 0.45) ** 1.3
        if 0.12 < v < 0.75:
            f *= 1.0 - 0.24 * max(0.0, math.cos(2 * math.pi * v * 3.5)) ** 6     # notches between the lobes
        hw = width * 0.5 * max(f, 0.03)
        # up the bell for the straight part, then round the hook
        if v < 0.68:
            s_ = v / 0.68
            y = y0 + straight * s_
            out = 0.012 * height + 0.05 * height * s_ * s_
            down = 0.0
        else:
            ang = (v - 0.68) / 0.32 * math.radians(80)
            y = y0 + straight + hook * math.sin(ang)
            out = 0.062 * height + hook * (1 - math.cos(ang))
        for j in range(cols):
            u = -1 + 2 * j / (cols - 1)
            a = theta + u * hw / bell(y0 + height * 0.3)
            rr = bell(min(y, y0 + straight)) + out + 0.075 * height * (1 - u * u) + 0.022 * height * (1 - abs(u)) ** 3
            p = np.array([math.cos(a) * rr, y, math.sin(a) * rr])
            vs.append(p)
            back.append(p - np.array([math.cos(a), 0, math.sin(a)]) * thick)
    f = grid_faces(rows, cols, wrap=False)
    outer = mesh(vs, f)
    lo = outer.triangles_center[: (rows // 2) * (cols - 1) * 2]
    ln = outer.face_normals[: (rows // 2) * (cols - 1) * 2]
    if np.mean(np.sum(ln * (lo * [1, 0, 1]), axis=1)) < 0:
        outer.faces = outer.faces[:, ::-1]
    first = int(rows * 0.6)                      # the back from the start of the roll
    fb = np.array(grid_faces(rows - first, cols, wrap=False)) + first * cols
    inner = mesh(back, fb[:, ::-1] if np.all(outer.faces[0] == f[0]) else fb)
    inner.remove_unreferenced_vertices()
    return trimesh.util.concatenate([outer, inner])


def tube(points, radii, sides=6):
    """A round tube along a polyline, its radius varying."""
    v, f = [], []
    n = len(points)
    for i, p in enumerate(points):
        t = points[min(i + 1, n - 1)] - points[max(i - 1, 0)]
        t /= np.linalg.norm(t)
        a = np.array([0, 1, 0]) if abs(t[1]) < 0.9 else np.array([1, 0, 0])
        x = np.cross(t, a)
        x /= np.linalg.norm(x)
        y = np.cross(t, x)
        for j in range(sides):
            ang = 2 * math.pi * j / sides
            v.append(p + (x * math.cos(ang) + y * math.sin(ang)) * radii[i])
    f = grid_faces(n, sides)
    m = mesh(v, f)
    m.fix_normals()
    return m


def corinthian_capital(y0, r):
    """A bell wrapped in two rows of eight acanthus leaves, volutes curling out to
    the abacus' corners, and an abacus with concave sides."""
    D = 2 * r
    H = 1.17 * D
    parts = []
    parts.append(lathe(ring_profile([("pt", (r * 0.99, y0)), ("arc", (r * 1.05, y0 + 0.035 * D, 0.035 * D, -90, 90)),
                                     ("pt", (r * 0.99, y0 + 0.07 * D))])))
    yb0 = y0 + 0.07 * D
    ytop = y0 + H - 0.17 * D

    def bell(y):
        t = np.clip((y - yb0) / (ytop - yb0), 0, 1)
        return r * (0.99 + 0.16 * t * t)
    prof = [(float(bell(yb0 + (ytop - yb0) * i / 8)), yb0 + (ytop - yb0) * i / 8) for i in range(9)]
    prof.append((r * 1.2, ytop))
    parts.append(lathe(prof, sides=32))
    hb = ytop - yb0
    # the lower row of eight under the upper row of eight, set between them
    for k in range(8):
        parts.append(acanthus_leaf(2 * math.pi * (k + 0.5) / 8, yb0, hb * 0.44, 0.47 * D, bell, hook=0.055 * D))
    for k in range(8):
        parts.append(acanthus_leaf(2 * math.pi * k / 8, yb0 + hb * 0.12, hb * 0.66, 0.44 * D, bell, hook=0.07 * D))
    # the caulicoli: a stalk rising from between each pair of upper leaves and
    # forking toward the volutes either side
    for k in range(8):
        a = 2 * math.pi * (k + 0.5) / 8
        d = np.array([math.cos(a), 0, math.sin(a)])
        pts, rad = [], []
        for i in range(8):
            t = i / 7
            y = yb0 + hb * (0.50 + 0.38 * t)
            rr = float(bell(y)) + 0.035 * D + 0.06 * D * t * t
            # lean toward the nearer corner as it rises
            corner = 2 * math.pi * (math.floor(k / 2) * 2 + 1) / 8
            aa = a + (corner - a) * 0.0 + (0.2 if k % 2 == 0 else -0.2) * t * t
            pts.append(np.array([math.cos(aa) * rr, y, math.sin(aa) * rr]))
            rad.append(0.028 * D * (1 - 0.4 * t))
        parts.append(tube(np.array(pts), rad, sides=6))
    # the volutes: a big one curling out under each corner of the abacus, and a
    # small pair on each face meeting in the middle under the rosette
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        d = np.array([math.cos(a), 0, math.sin(a)])
        eye = d * r * 1.30 + np.array([0, ytop - 0.11 * D, 0])
        v = volute(np.zeros(3), 0.13 * D, 1, 1, turns=1.9, band=0.06 * D, lift=0.025 * D, samples=30,
                   disc_sides=16)
        v.apply_transform(trimesh.geometry.align_vectors([0, 0, 1], d))
        v.apply_translation(eye)
        parts.append(v)
        f = np.array([math.cos(a + math.pi / 4), 0, math.sin(a + math.pi / 4)])     # the face between corners
        for sgn in (-1, 1):
            side = np.cross([0, 1, 0], f)
            eye2 = f * r * 1.16 + side * sgn * 0.10 * D + np.array([0, ytop - 0.07 * D, 0])
            v2 = volute(np.zeros(3), 0.065 * D, sgn, 1, turns=1.5, band=0.035 * D, lift=0.015 * D, samples=18,
                        sides=4, disc_sides=12, boss=0)
            v2.apply_transform(trimesh.geometry.align_vectors([0, 0, 1], f))
            v2.apply_translation(eye2)
            parts.append(v2)
        # the rosette (fleuron) on the abacus face
        ros = trimesh.creation.icosphere(subdivisions=1, radius=0.06 * D)
        ros.apply_scale([1, 1, 0.55])
        ros.apply_transform(trimesh.geometry.align_vectors([0, 0, 1], f))
        ros.apply_translation(f * (0.71 * D - 0.12 * D) + np.array([0, ytop + 0.085 * D, 0]))
        parts.append(ros)
    # abacus: square with concave sides, the corners cut
    ab = 0.10 * D                    # the abacus' upper band; a narrower one under it
    side = 1.42 * D
    n = 10
    ring = []
    for s in range(4):
        rot = s * math.pi / 2
        for i in range(n):
            t = -1 + 2 * i / (n - 1)
            x = side / 2 - 0.13 * D * (1 - t * t)          # the concave curve inward
            z = t * side / 2 * 0.92
            ring.append((x * math.cos(rot) - z * math.sin(rot), x * math.sin(rot) + z * math.cos(rot)))
    ring = np.array(ring)
    bot = np.column_stack([ring[:, 0], np.full(len(ring), ytop), ring[:, 1]])
    top = np.column_stack([ring[:, 0], np.full(len(ring), ytop + ab), ring[:, 1]])
    v = np.vstack([bot, top, [[0, ytop, 0], [0, ytop + ab, 0]]])
    m = len(ring)
    f = grid_faces(2, m)
    cb, ct = 2 * m, 2 * m + 1
    f += [[cb, (k + 1) % m, k] for k in range(m)]
    f += [[ct, m + k, m + (k + 1) % m] for k in range(m)]
    upper = outward(mesh(v, f))
    lower = upper.copy()
    lower.apply_translation([0, -ytop, 0])
    lower.apply_scale([0.95, 0.7, 0.95])
    lower.apply_translation([0, ytop, 0])
    upper.apply_translation([0, ab * 0.7, 0])
    parts += [lower, upper]
    return parts, ytop + ab * 1.7


# ------------------------------------------------------------------ the break

def broken_top(y, r, flutes, depth, per=5, jag=0.18):
    """Cap a fluted shaft at height y with a jagged break: the rim rises and falls,
    and the face slopes and is pitted."""
    span = 2 * np.pi / flutes
    angs, shape = [], []
    for k in range(flutes):
        for i in range(per):
            t = i / per
            angs.append(k * span + span * t)
            shape.append(math.sin(math.pi * t))
    angs, shape = np.array(angs), np.array(shape)
    n = len(angs)
    noise = np.interp(angs, np.linspace(0, 2 * np.pi, 9), rng.uniform(-1, 1, 9)) + 0.4 * rng.uniform(-1, 1, n)
    rim_y = y + jag * r * (0.6 * np.sin(angs + 0.7) + 0.4 * noise)
    rr = r * (1 - depth * shape)
    rim = np.stack([np.cos(angs) * rr, rim_y, np.sin(angs) * rr], 1)
    below = rim.copy()
    below[:, 1] = y - jag * r * 1.2
    # the broken face: rings stepping in, rough
    face = [rim]
    for s, f in enumerate([0.7, 0.4]):
        ring = rim.copy()
        ring[:, 0] *= f
        ring[:, 2] *= f
        ring[:, 1] = y + jag * r * (0.4 * np.sin(angs + 0.7) * f + 0.3 * rng.uniform(-1, 1, n))
        face.append(ring)
    v = np.vstack([below, rim] + face[1:] + [[[0, y + jag * r * 0.1, 0]]])
    rows = 2 + len(face) - 1
    f = grid_faces(rows, n)
    c = len(v) - 1
    base = (rows - 1) * n
    f += [[c, base + k, base + (k + 1) % n] for k in range(n)]
    m = mesh(v, f)
    # sides face out, the face faces up
    side = m.face_normals[: 2 * n]
    cen = m.triangles_center[: 2 * n] * [1, 0, 1]
    if np.mean(np.sum(side * cen, axis=1)) < 0:
        m.faces = m.faces[:, ::-1]
    return m


# ------------------------------------------------------------------ entablature

def entablature(length=6.0, D=1.0):
    """Architrave (three fasciae), frieze, cornice with a row of dentils; extruded
    along x, the face toward +z."""
    depth = 0.95 * D
    # profile in (z out from the back plane, y up), from the bottom
    archi = 0.55 * D
    pts = [(0, 0), (depth * 0.80, 0), (depth * 0.80, archi * 0.30), (depth * 0.83, archi * 0.30),
           (depth * 0.83, archi * 0.62), (depth * 0.86, archi * 0.62), (depth * 0.86, archi * 0.88),
           (depth * 0.92, archi * 0.94), (depth * 0.92, archi)]
    y = archi
    frieze = 0.50 * D
    pts += [(depth * 0.84, y), (depth * 0.84, y + frieze)]
    y += frieze
    # bed moulding, the dentil course (behind the dentils), corona, cyma
    pts += [(depth * 0.90, y + 0.04 * D), (depth * 0.90, y + 0.06 * D), (depth * 0.92, y + 0.06 * D),
            (depth * 0.92, y + 0.20 * D)]
    y += 0.20 * D
    pts += [(depth * 1.20, y + 0.03 * D), (depth * 1.28, y + 0.05 * D), (depth * 1.28, y + 0.20 * D),
            (depth * 1.31, y + 0.22 * D)]
    y += 0.22 * D
    for i in range(1, 5):
        a = i / 4 * math.pi / 2
        pts.append((depth * 1.31 - 0.10 * D * math.sin(a), y + 0.12 * D * (1 - math.cos(a)) * 0 + 0.12 * D * i / 4))
    y += 0.12 * D
    pts += [(depth * 1.18, y), (0, y)]
    pts = np.array(pts)
    m = len(pts)
    xs = [-length / 2, length / 2]
    v = []
    for x in xs:
        for z, yy in pts:
            v.append([x, yy, z - depth * 0.5])
    f = []
    for k in range(m):
        a, b = k, (k + 1) % m
        c, d = m + k, m + (k + 1) % m
        f += [[a, c, b], [b, c, d]]
    # end caps (the profile is a simple polygon: fan from the back bottom corner is
    # wrong for concave runs, so triangulate it properly)
    poly = trimesh.path.polygons.Polygon(pts)
    tri_v, tri_f = trimesh.creation.triangulate_polygon(poly)
    for s, x in enumerate(xs):
        base = len(v)
        for tz, ty in tri_v:
            v.append([x, ty, tz - depth * 0.5])
        ff = tri_f + base
        f += (ff if s == 1 else ff[:, ::-1]).tolist()
    body = mesh(v, f)
    body.fix_normals()
    parts = [body]
    # the dentils: small blocks along the dentil course, front and ends
    dw, dh, dd = 0.11 * D, 0.13 * D, 0.10 * D
    yd = archi + frieze + 0.065 * D
    n = int(length / (dw * 1.6))
    for i in range(n):
        x = -length / 2 + (i + 0.5) * length / n
        parts.append(box((dw, dh, dd), (x, yd + dh / 2, depth * 0.92 + dd / 2 - depth * 0.5)))
    return parts, y


# ------------------------------------------------------------------ the pieces

def column(order):
    parts = []
    if order == "tuscan":
        r = 0.45
        D = 2 * r
        p, y = tuscan_base(0, r)
        parts += p
        top = y + 6.0 * D
        parts.append(shaft(y - 0.01, top, r, r * 0.80))
        p, y = tuscan_capital(top, r * 0.80)
        parts += p
        coll = [("box", [D * 1.33, 0.25 * D, D * 1.33], [0, 0.125 * D, 0]),
                ("cyl", r, [0, (0.25 * D + top) / 2, 0], top - 0.25 * D),
                ("box", [D * 1.0, y - top, D * 1.0], [0, (top + y) / 2, 0])]
    elif order in ("doric", "broken"):
        r = 0.5
        D = 2 * r
        p, y = attic_base(0, r)
        parts += p
        if order == "broken":
            top = y + 3.1 * D
            parts.append(shaft(y - 0.01, top + 0.4, r, r * 0.83, flutes=20, depth=0.10))
            # cut the shaft at the break: keep only the part below it
            sh = parts.pop()
            sh = sh.slice_plane([0, top - 0.2 * r, 0], [0, -1, 0])
            parts.append(sh)
            parts.append(broken_top(top - 0.02, float(np.interp(top, [y, y + 8], [r, r * 0.83])),
                                    20, 0.10))
            coll = [("box", [D * 1.36, D / 6, D * 1.36], [0, D / 12, 0]),
                    ("cyl", r, [0, (D / 6 + top) / 2, 0], top - D / 6)]
        else:
            top = y + 7.0 * D
            parts.append(shaft(y - 0.01, top, r, r * 0.83, flutes=20, depth=0.10))
            p, y = doric_capital(top, r * 0.83)
            parts += p
            coll = [("box", [D * 1.36, D / 6, D * 1.36], [0, D / 12, 0]),
                    ("cyl", r, [0, (D / 6 + top) / 2, 0], top - D / 6),
                    ("box", [D * 1.1, y - top, D * 1.1], [0, (top + y) / 2, 0])]
    elif order == "ionic":
        r = 0.5
        D = 2 * r
        p, y = attic_base(0, r)
        parts += p
        top = y + 7.9 * D
        parts.append(shaft(y - 0.01, top, r, r * 0.83, flutes=24, fillet=0.22, depth=0.075))
        p, y = ionic_capital(top, r * 0.83)
        parts += p
        coll = [("box", [D * 1.36, D / 6, D * 1.36], [0, D / 12, 0]),
                ("cyl", r, [0, (D / 6 + top) / 2, 0], top - D / 6),
                ("box", [D * 1.3, y - top, D * 1.0], [0, (top + y) / 2, 0])]
    elif order == "corinthian":
        r = 0.6
        D = 2 * r
        p, y = attic_base(0, r)
        parts += p
        top = y + 8.33 * D
        parts.append(shaft(y - 0.01, top, r, r * 0.83, flutes=24, fillet=0.22, depth=0.075))
        p, y = corinthian_capital(top, r * 0.83)
        parts += p
        coll = [("box", [D * 1.36, D / 6, D * 1.36], [0, D / 12, 0]),
                ("cyl", r, [0, (D / 6 + top) / 2, 0], top - D / 6),
                ("box", [D * 1.2, y - top, D * 1.2], [0, (top + y) / 2, 0])]
    return parts, coll


def finish(parts):
    """Merge, shade (smooth curves, sharp corners), bake ambient occlusion into
    vertex colours, centre on the bounding box."""
    m = trimesh.util.concatenate(parts)
    m.merge_vertices(digits_vertex=5)
    m.update_faces(m.nondegenerate_faces(height=1e-7))
    m.remove_unreferenced_vertices()
    m = trimesh.graph.smooth_shade(m, angle=math.radians(34), facet_minarea=None)
    ao = bake_ao(m)
    g = np.clip(0.42 + 0.58 * ao, 0, 1)
    cols = np.column_stack([g, g, g, np.ones_like(g)]) * 255
    m.visual = trimesh.visual.ColorVisuals(m, vertex_colors=cols.astype(np.uint8))
    lo, hi = m.bounds
    centre = (lo + hi) / 2
    m.apply_translation(-centre)
    return m, centre, hi - lo


def bake_ao(m, rays=24, reach=0.45):
    """How open each vertex is to the sky: the share of rays over its hemisphere
    that escape within `reach` metres."""
    n = np.array(m.vertex_normals)
    bad = ~np.isfinite(n).all(axis=1) | (np.linalg.norm(n, axis=1) < 0.5)
    n[bad] = [0, 1, 0]
    p = m.vertices + n * 0.004
    # a fixed set of directions over the hemisphere, cosine weighted
    i = np.arange(rays) + 0.5
    phi = np.arccos(np.sqrt(1 - i / rays))
    th = math.pi * (1 + 5 ** 0.5) * i
    local = np.stack([np.cos(th) * np.sin(phi), np.sin(th) * np.sin(phi), np.cos(phi)], 1)
    open_ = np.zeros(len(p))
    # a frame per vertex round its normal
    a = np.where(np.abs(n[:, 0:1]) < 0.9, [[1, 0, 0]], [[0, 1, 0]])
    t1 = np.cross(n, a)
    t1 /= np.linalg.norm(t1, axis=1, keepdims=True)
    t2 = np.cross(n, t1)
    for d in local:
        dirs = t1 * d[0] + t2 * d[1] + n * d[2]
        hit, ray_i = m.ray.intersects_location(p, dirs, multiple_hits=False)[:2]
        blocked = np.zeros(len(p), bool)
        if len(ray_i):
            dist = np.linalg.norm(hit - p[ray_i], axis=1)
            blocked[ray_i[dist < reach]] = True
        open_ += ~blocked
    return open_ / rays


PIECES = {
    "tuscan": "Tuscan column",
    "doric": "Doric column",
    "ionic": "Ionic column",
    "corinthian": "Corinthian column",
    "broken": "Broken column",
    "entablature": "Entablature",
}


def main():
    os.makedirs(OUT, exist_ok=True)
    meta = {}
    manifest = os.path.join(OUT, "props.json")
    if os.path.exists(manifest):
        meta = json.load(open(manifest))
    only = sys.argv[1:]                     # build just these, keeping the others
    for key, label in PIECES.items():
        if only and key not in only:
            continue
        if key == "entablature":
            parts, y = entablature()
            coll = [("box", [6.0, y, 0.95 * 1.31], [0, y / 2, 0.95 * 0.65 - 0.95 * 0.5])]
        else:
            parts, coll = column(key)
        m, centre, size = finish(parts)
        path = os.path.join(OUT, key + ".glb")
        m.export(path)
        shapes = []
        for c in coll:
            if c[0] == "box":
                shapes.append({"box": [round(float(x), 4) for x in c[1]],
                               "at": [round(float(x - o), 4) for x, o in zip(c[2], centre)]})
            else:
                shapes.append({"cyl": round(float(c[1]), 4), "height": round(float(c[3]), 4),
                               "at": [round(float(x - o), 4) for x, o in zip(c[2], centre)]})
        meta[key] = {"label": label, "file": "res://assets/models/props/pillars/%s.glb" % key,
                     "size": [round(float(s), 3) for s in size], "collide": shapes}
        print("%-12s %6d tris  %s m  -> %s" % (key, len(m.faces), np.round(size, 2), os.path.basename(path)))
    meta = {k: meta[k] for k in PIECES if k in meta}          # keep the palette's order
    with open(manifest, "w") as f:
        json.dump(meta, f, indent=1)


if __name__ == "__main__":
    main()
