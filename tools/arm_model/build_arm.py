"""
The first-person arm, modelled in code: a black suit sleeve, a white shirt cuff and a
black leather glove closed in a fist (after design/arm/reference-sheet.png).

The glove is one seamless surface. It is written as a signed distance field: the
wrist, palm, knuckles, four fingers of three phalanges, the thumb and the pads of
the palm are each a simple solid, and they are blended together with smooth unions,
so fingers grow out of the palm the way they do on a real hand, with no joins. The
field is meshed with marching cubes, decimated, and shaded with normals taken from
the field itself. The sleeve, shirt cuff and buttons are lofted around the arm.

Arm space, metres: -Z runs from the elbow to the knuckles, +Y is the back of the
hand, -X the thumb side (a right hand, palm down). The elbow pivot is the origin.

    python3 tools/arm_model/build_arm.py        ->  assets/models/arm/arm.glb
Needs numpy, scikit-image, trimesh, fast-simplification.
"""
import os
import sys
import numpy as np
from skimage.measure import marching_cubes
import trimesh
import fast_simplification

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "assets", "models", "arm", "arm.glb")

VOXEL = float(os.environ.get("ARM_VOXEL", 0.0007))      # marching cubes cell: 0.7 mm
GLOVE_TRIS = int(os.environ.get("ARM_TRIS", 26000))     # after decimation (0: keep all)

SLEEVE_END = -0.178     # the sleeve's hem
CUFF_END = -0.188       # the shirt cuff shows about a centimetre past it
HAND_SCALE = 1.07       # a gloved hand: leather and lining add to a real hand's size
WRIST = None            # set below: the point the hand is scaled about


# ------------------------------------------------------------------ vector helpers

def v3(x, y, z):
    return np.array([x, y, z], dtype=np.float64)


def unit(v):
    return v / np.linalg.norm(v)


def rot(v, axis, ang):
    """Rotate v about a unit axis by ang radians (right-handed)."""
    axis = unit(axis)
    c, s = np.cos(ang), np.sin(ang)
    return v * c + np.cross(axis, v) * s + axis * np.dot(axis, v) * (1 - c)


def dot(a, b):
    return np.sum(a * b, axis=-1)


# ------------------------------------------------------------------ distance functions
# p: (..., 3) float array of points; each returns (...) distances (negative inside)

def smin(a, b, k):
    """Polynomial smooth minimum: a union whose seam is a fillet about k wide.
    k may be an array, so the fillet can vary over the hand."""
    k = np.maximum(k, 1e-6)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)


def frame(a, b, up):
    t = unit(b - a)
    u = up - t * np.dot(up, t)
    u = unit(u)
    s = np.cross(t, u)
    return t, s, u


def round_cone(p, a, b, ra, rb, up=v3(0, 1, 0), sx=1.0, sy=1.0):
    """A capsule from a to b whose radius runs ra..rb; sx, sy squash its section
    across (side) and up, so fingers can be a touch flat on the back."""
    t, s, u = frame(a, b, up)
    q = p - a
    lx = dot(q, s) / sx
    ly = dot(q, u) / sy
    lz = dot(q, t)
    L = np.linalg.norm(b - a)
    # iq's round cone, in the frame where the axis is +z from 0 to L
    r1, r2 = ra, rb
    h = L
    bb = (r1 - r2) / h
    aa = np.sqrt(max(1 - bb * bb, 1e-9))
    qx = np.sqrt(lx * lx + ly * ly)
    k = -qx * bb + lz * aa       # dot(q, vec2(-b, a)) with q = (qx, lz)
    d = np.where(k < 0.0, np.sqrt(qx * qx + lz * lz) - r1,
                 np.where(k > aa * h, np.sqrt(qx * qx + (lz - h) ** 2) - r2,
                          qx * aa + lz * bb - r1))
    return d * min(sx, sy)


def ellipsoid(p, c, r, axes=None):
    """Ellipsoid centred at c with radii r along axes (rows), default x, y, z."""
    q = p - c
    if axes is not None:
        q = np.stack([dot(q, axes[0]), dot(q, axes[1]), dot(q, axes[2])], axis=-1)
    k0 = np.linalg.norm(q / r, axis=-1)
    k1 = np.linalg.norm(q / (r * r), axis=-1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def round_box(p, c, half, rad, axes=None):
    q = p - c
    if axes is not None:
        q = np.stack([dot(q, axes[0]), dot(q, axes[1]), dot(q, axes[2])], axis=-1)
    q = np.abs(q) - (half - rad)
    return np.linalg.norm(np.maximum(q, 0.0), axis=-1) + np.minimum(np.max(q, axis=-1), 0.0) - rad


# ------------------------------------------------------------------ the hand
# Real proportions for a man's hand inside a fitted glove: about 19 cm from the
# wrist crease to the middle fingertip, 8.8 cm across the knuckles.

FINGERS = [
    # knuckle (MCP) head, phalanx lengths joint to joint, radii at MCP/PIP/DIP/tip
    dict(mcp=v3(-0.0295, 0.0035, -0.3045), len=[0.0410, 0.0250, 0.0175], r=[0.0115, 0.0108, 0.0101, 0.0094]),
    dict(mcp=v3(-0.0095, 0.0055, -0.3085), len=[0.0450, 0.0280, 0.0185], r=[0.0119, 0.0111, 0.0103, 0.0096]),
    dict(mcp=v3(0.0105, 0.0035, -0.3050), len=[0.0425, 0.0270, 0.0180], r=[0.0113, 0.0105, 0.0098, 0.0092]),
    dict(mcp=v3(0.0285, -0.0005, -0.2945), len=[0.0330, 0.0200, 0.0160], r=[0.0101, 0.0094, 0.0088, 0.0083]),
]
# The fist round the chain (MCP, PIP, DIP flexion, degrees): the fingers wrap a
# link about 18 mm thick, the little finger curled tightest.
FIST = [[74.0, 96.0, 52.0], [76.0, 97.0, 55.0], [81.0, 102.0, 60.0], [88.0, 106.0, 64.0]]
SPLAY = [0.035, 0.0, -0.02, -0.05]       # fingers lean together in a grip (radians, about Y)


def finger_joints(f):
    """Joint positions (MCP, PIP, DIP, tip) and the back-of-finger direction at each."""
    d = FINGERS[f]
    fwd = rot(v3(0, 0, -1), v3(0, 1, 0), SPLAY[f])
    side = rot(v3(1, 0, 0), v3(0, 1, 0), SPLAY[f])
    pts = [d["mcp"]]
    ups = [v3(0, 1, 0)]
    ang = 0.0
    p = d["mcp"].copy()
    for j in range(3):
        ang += np.radians(FIST[f][j])
        direction = rot(fwd, side, -ang)
        p = p + direction * d["len"][j]
        pts.append(p.copy())
        ups.append(rot(v3(0, 1, 0), side, -ang))
    return pts, ups


THUMB = [v3(-0.0225, -0.0115, -0.2255), v3(-0.0485, -0.0305, -0.2600),
         v3(-0.0405, -0.0490, -0.2860), v3(-0.0130, -0.0535, -0.2925)]
THUMB_R = [0.0165, 0.0128, 0.0114, 0.0099]


def hand_sdf(p):
    # the glove's gauntlet: a flattened round cone from inside the sleeve to the wrist
    cuff = round_cone(p, v3(0, -0.003, -0.110), v3(0, -0.002, -0.214), 0.0335, 0.0302, sx=1.12, sy=0.85)
    # the hand itself, a touch larger than bare, scaled about the wrist
    w = v3(0.0, -0.002, -0.214)
    q = w + (p - w) / HAND_SCALE
    return smin(cuff, _hand(q) * HAND_SCALE, 0.012)


def _hand(p):
    y = p[..., 1]
    z = p[..., 2]
    # --- the body of the hand
    # the wrist, narrowest across the bones, then the palm: a rounded slab, a
    # little wider at the knuckles
    d = round_cone(p, v3(0, -0.002, -0.200), v3(0, -0.002, -0.226), 0.0292, 0.0290, sx=1.12, sy=0.84)
    palm = round_box(p, v3(-0.0005, -0.0015, -0.2665), v3(0.0405, 0.0140, 0.0400), 0.0115)
    d = smin(d, palm, 0.016)
    # metacarpals under the back of the glove, fanning out to the knuckle heads
    for f in range(4):
        m = FINGERS[f]["mcp"]
        base = v3(m[0] * 0.55, 0.0035, -0.2335)
        mc = round_cone(p, base, m, 0.0072, FINGERS[f]["r"][0] * 1.02)
        d = smin(d, mc, 0.009)
    # pads on the palm side: the heel of the hand, the ball below the fingers, and
    # the thick base of the thumb (thenar) and the outer edge (hypothenar)
    d = smin(d, ellipsoid(p, v3(0.0175, -0.0135, -0.2440), v3(0.0170, 0.0110, 0.0300)), 0.008)
    d = smin(d, ellipsoid(p, v3(-0.0010, -0.0140, -0.2930), v3(0.0350, 0.0085, 0.0120)), 0.008)
    d = smin(d, ellipsoid(p, v3(-0.0285, -0.0150, -0.2420), v3(0.0165, 0.0150, 0.0270),
                          axes=[unit(v3(1, 0, -0.45)), v3(0, 1, 0), unit(v3(0.45, 0, 1))]), 0.010)

    # --- the fingers, each three tapering phalanges, held tight together
    fingers = None
    for f in range(4):
        pts, ups = finger_joints(f)
        r = FINGERS[f]["r"]
        fd = None
        for j in range(3):
            seg = round_cone(p, pts[j], pts[j + 1], r[j], r[j + 1], up=ups[j + 1], sx=0.97, sy=0.95)
            fd = seg if fd is None else smin(fd, seg, 0.0025)
        # the knuckle head stands a little proud on the back of the fist
        fd = smin(fd, ellipsoid(p, pts[0] + v3(0, 0.0040, -0.0022), v3(r[0] * 0.95, r[0] * 0.92, r[0] * 1.0)), 0.0022)
        fingers = fd if fingers is None else smin(fingers, fd, 0.0012)
    # grown out of the palm: a broad fillet at the roots, where the hand is one
    # surface, narrowing to almost nothing where the fingertips press the palm
    root = np.clip((y + 0.022) / 0.012, 0.0, 1.0)
    d = smin(d, fingers, 0.0015 + 0.0075 * root)

    # --- the thumb: a thick metacarpal off the thenar pad, then two phalanges laid
    # across the front of the index and middle fingers; blended broadly at its base,
    # only touching where it lies on the fingers
    td = None
    for j in range(3):
        seg = round_cone(p, THUMB[j], THUMB[j + 1], THUMB_R[j], THUMB_R[j + 1], up=v3(-0.6, 0.4, 0.2), sx=1.05, sy=0.92)
        td = seg if td is None else smin(td, seg, 0.003)
    base = np.clip((z + 0.285) / 0.020, 0.0, 1.0)
    d = smin(d, td, 0.0015 + 0.0100 * base)
    return d


def wrist_wrinkles(p):
    """Soft creases where the glove's gauntlet gathers above the hand."""
    z = p[..., 2]
    ang = np.arctan2(p[..., 1] + 0.002, p[..., 0])
    band = np.clip(-(z + 0.186) / 0.006, 0, 1) * np.clip((z + 0.234) / 0.010, 0, 1)
    # a few broad, slanted folds that wander round the wrist, each fading in and out
    w = np.zeros_like(z)
    for k, (z0, tilt, ph, amp) in enumerate([(-0.195, 0.004, 0.3, 1.0), (-0.203, -0.005, 2.1, 0.8),
                                              (-0.211, 0.006, 4.0, 1.0), (-0.219, -0.003, 1.2, 0.7),
                                              (-0.226, 0.004, 5.1, 0.5)]):
        zc = z0 + tilt * np.sin(ang + ph) + 0.0015 * np.sin(2.0 * ang + ph * 1.7)
        reach = np.clip(0.55 + 0.6 * np.sin(ang * 1.0 + ph * 2.3), 0, 1)
        w += amp * reach * np.exp(-((z - zc) / 0.0018) ** 2)
    return 0.0014 * band * (w - 0.25)


def points_sdf(p, base):
    """The three stitched points on the back of the glove: raised welts, each with
    a fine groove either side, running from the wrist toward the knuckles."""
    d = base
    for k in range(3):
        x0 = -0.0145 + k * 0.0145
        a = v3(x0 * 0.80, 0, -0.2290)
        b = v3(x0 * 1.05, 0, -0.2830)
        for end in (a, b):
            end[1] = surface_y(end[0], end[2]) - 0.0002
        # three points along the welt so it follows the curve of the hand's back
        mid = (a + b) * 0.5
        mid[1] = surface_y(mid[0], mid[2]) - 0.0002
        welt = np.minimum(round_cone(p, a, mid, 0.0016, 0.0017), round_cone(p, mid, b, 0.0017, 0.0015))
        d = smin(d, welt, 0.0010)
    return d


def surface_y(x, z):
    """Height of the back of the hand at (x, z), found along a vertical ray."""
    lo, hi = -0.01, 0.05
    for _ in range(40):
        mid = 0.5 * (lo + hi)
        if hand_sdf(np.array([[x, mid, z]]))[0] < 0:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def glove_sdf(p):
    d = hand_sdf(p)
    d = d - wrist_wrinkles(p)
    return points_sdf(p, d)


def build_glove():
    lo = v3(-0.082, -0.090, -0.360)
    hi = v3(0.058, 0.036, -0.112)
    n = np.ceil((hi - lo) / VOXEL).astype(int) + 1
    print("glove grid", n, n.prod() / 1e6, "M samples")
    xs = lo[0] + np.arange(n[0]) * VOXEL
    ys = lo[1] + np.arange(n[1]) * VOXEL
    zs = lo[2] + np.arange(n[2]) * VOXEL
    vol = np.empty((n[0], n[1], n[2]), dtype=np.float32)
    X, Y = np.meshgrid(xs, ys, indexing="ij")
    step = 24
    for k0 in range(0, n[2], step):
        zz = zs[k0:k0 + step]
        P = np.stack(np.broadcast_arrays(X[..., None], Y[..., None], zz[None, None, :]), axis=-1)
        vol[:, :, k0:k0 + step] = glove_sdf(P)
    # the open end inside the sleeve: cut flat (it's never seen)
    verts, faces, _, _ = marching_cubes(vol, 0.0, spacing=(VOXEL, VOXEL, VOXEL))
    verts += lo
    print("glove raw", len(faces), "tris")
    if GLOVE_TRIS > 0:
        verts, faces = fast_simplification.simplify(verts.astype(np.float32), faces.astype(np.int32),
                                                    target_reduction=1.0 - GLOVE_TRIS / len(faces), agg=6)
    # shade with the field's own gradient: smooth everywhere, crisp where the field is
    e = 0.00025
    g = np.zeros_like(verts, dtype=np.float64)
    for i in range(3):
        o = np.zeros(3)
        o[i] = e
        g[:, i] = glove_sdf(verts + o) - glove_sdf(verts - o)
    normals = g / np.linalg.norm(g, axis=1, keepdims=True)
    m = trimesh.Trimesh(vertices=verts, faces=faces, vertex_normals=normals, process=False)
    # make sure the faces wind outward (agreeing with the field's normals)
    fn = m.face_normals
    vn = normals[m.faces].mean(axis=1)
    if np.mean(np.sum(fn * vn, axis=1) > 0) < 0.5:
        m.faces = m.faces[:, ::-1]
    print("glove", len(m.faces), "tris")
    return m


# ------------------------------------------------------------------ the sleeve

SLEEVE_START = 0.30


def sleeve_radius(z):
    """Full through the forearm's muscle, narrowing to the cuff."""
    t = (SLEEVE_START - z) / (SLEEVE_START - SLEEVE_END)
    belly = np.sin(np.clip(t, 0, 1) * np.pi) * 0.0035
    rx = 0.0675 + (0.0462 - 0.0675) * t ** 1.15 + belly
    ry = 0.0625 + (0.0432 - 0.0625) * t ** 1.15 + belly
    return rx, ry, t


def sleeve_fold(ang, z, t):
    """Wool drape: long soft folds down the sleeve, and a run of shallow diagonal
    creases where the sleeve settles above the cuff."""
    long_folds = (0.55 * np.sin(3 * ang + z * 11.0 + 0.4) + 0.35 * np.sin(5 * ang - z * 17.0 + 1.9)
                  + 0.18 * np.sin(7 * ang + z * 23.0 + 0.7))
    f = 0.0042 * (1.0 - 0.45 * t) * long_folds
    settle = np.clip((t - 0.45) / 0.25, 0, 1) * np.clip((0.985 - t) / 0.06, 0, 1)
    f += 0.0024 * settle * np.sin(z * 150.0 + ang * 2.0 + np.sin(ang * 3.0 + z * 40.0) * 1.4)
    # broad diagonal drag folds running round the forearm
    f += 0.0022 * np.clip(t * 2.0, 0, 1) * np.sin(z * 55.0 - ang * 1.0 + 0.6) * np.clip(np.sin(ang * 2.0 + z * 20.0), 0, 1)
    return f


def sleeve_point(ang, z, inset=0.0):
    rx, ry, t = sleeve_radius(z)
    sag = 1.0 + 0.06 * t * max(0.0, -np.sin(ang))           # the cloth hangs a little low
    f = sleeve_fold(ang, z, t)
    x = np.cos(ang) * (rx + f - inset)
    y = np.sin(ang) * (ry * sag + f - inset) - 0.004 * t
    return v3(x, y, z)


def loft(rings, close_start=False, close_end=False, flip=False):
    """Triangles joining equal-sized rings of points (lists of (N,3))."""
    R = len(rings)
    N = len(rings[0])
    verts = np.concatenate(rings)
    faces = []
    for i in range(R - 1):
        for k in range(N):
            a = i * N + k
            b = i * N + (k + 1) % N
            c = (i + 1) * N + k
            d = (i + 1) * N + (k + 1) % N
            faces += [[a, c, b], [b, c, d]]
    faces = np.array(faces)
    if close_start:
        verts = np.vstack([verts, rings[0].mean(axis=0)])
        ci = len(verts) - 1
        faces = np.vstack([faces, [[ci, k, (k + 1) % N] for k in range(N)]])
    if close_end:
        verts = np.vstack([verts, rings[-1].mean(axis=0)])
        ci = len(verts) - 1
        base = (R - 1) * N
        faces = np.vstack([faces, [[ci, base + (k + 1) % N, base + k] for k in range(N)]])
    if flip:
        faces = faces[:, ::-1]
    m = trimesh.Trimesh(vertices=verts, faces=faces, process=False)
    return m


def outward(m, centre_axis=True):
    """Turn a lofted tube's faces outward (checked against its axis)."""
    c = m.triangles_center
    n = m.face_normals
    radial = c.copy()
    radial[:, 2] = 0
    radial[:, 1] += 0.004
    if np.mean(np.sum(n * radial, axis=1) > 0) < 0.5:
        m.faces = m.faces[:, ::-1]
    return m


def build_sleeve():
    N = 72
    angs = np.linspace(0, 2 * np.pi, N, endpoint=False)
    zs = np.linspace(SLEEVE_START, SLEEVE_END, 120)
    rings = [np.array([sleeve_point(a, z) for a in angs]) for z in zs]
    outer = outward(loft(rings, close_start=True))
    # the hem turns in: a rounded edge, then the lining back up inside
    hem = []
    for k, (dz, inset) in enumerate([(0.0, 0.0), (0.0006, 0.0009), (0.0015, 0.0016), (0.0030, 0.0020)]):
        hem.append(np.array([sleeve_point(a, SLEEVE_END) + v3(0, 0, dz) - v3(np.cos(a), np.sin(a), 0) * inset for a in angs]))
    hem_m = loft(hem)
    if np.mean(hem_m.face_normals[:, 2] < 0) < 0.5:     # the hem faces down the arm
        hem_m.faces = hem_m.faces[:, ::-1]
    lining = [np.array([sleeve_point(a, SLEEVE_END) + v3(0, 0, dz) - v3(np.cos(a), np.sin(a), 0) * 0.0020 for a in angs])
              for dz in (0.0030, 0.06)]
    lining_m = outward(loft(lining))
    lining_m.faces = lining_m.faces[:, ::-1]            # seen from inside
    wool = trimesh.util.concatenate([outer, hem_m])
    wool.merge_vertices()
    return wool, lining_m


def build_shirt():
    N = 96
    angs = np.linspace(0, 2 * np.pi, N, endpoint=False)
    rows = []
    # the cuff band, its rounded edge, and a short return inside toward the glove
    for z, rx, ry in [(-0.140, 0.0395, 0.0360), (SLEEVE_END + 0.004, 0.0398, 0.0362),
                      (CUFF_END + 0.0008, 0.0398, 0.0362), (CUFF_END, 0.0388, 0.0352),
                      (CUFF_END + 0.0006, 0.0372, 0.0336), (CUFF_END + 0.004, 0.0362, 0.0326)]:
        rows.append(np.array([v3(np.cos(a) * rx, np.sin(a) * ry - 0.0045, z) for a in angs]))
    m = loft(rows)
    # face out on the band (the return is tucked away inside)
    n = m.face_normals[: N * 2]
    c = m.triangles_center[: N * 2]
    if np.mean(np.sum(n[:, :2] * c[:, :2], axis=1) > 0) < 0.5:
        m.faces = m.faces[:, ::-1]
    return m


def build_buttons():
    """Three horn buttons on the outer side of the cuff, above the hem."""
    parts = []
    a = np.radians(52.0)                 # between the back of the arm and its outer edge
    for k in range(3):
        z = SLEEVE_END + 0.0125 + k * 0.0150
        p = sleeve_point(a, z)
        q = sleeve_point(a + 0.01, z)
        tz = v3(0, 0, 1)
        tang = unit(q - p)
        nrm = unit(np.cross(tz, tang))
        if np.dot(nrm, v3(np.cos(a), np.sin(a), 0)) < 0:
            nrm = -nrm
        b = trimesh.creation.cylinder(radius=0.0068, height=0.0030, sections=32)
        # a domed face: lift the outer cap's middle a touch
        v = b.vertices
        top = v[:, 2] > 0
        r = np.linalg.norm(v[:, :2], axis=1)
        v[top, 2] += 0.0009 * (1 - (r[top] / 0.0068) ** 2)
        b.vertices = v
        Rm = np.eye(4)
        x_axis = unit(np.cross(nrm, tz))
        y_axis = np.cross(nrm, x_axis)
        Rm[:3, 0] = x_axis
        Rm[:3, 1] = y_axis
        Rm[:3, 2] = nrm
        Rm[:3, 3] = p + nrm * 0.0009
        b.apply_transform(Rm)
        parts.append(b)
    return trimesh.util.concatenate(parts)


# ------------------------------------------------------------------ export

def main():
    glove = build_glove()
    wool, lining = build_sleeve()
    shirt = build_shirt()
    buttons = build_buttons()
    scene = trimesh.Scene()
    for name, m in [("glove", glove), ("sleeve", wool), ("lining", lining), ("shirt", shirt), ("buttons", buttons)]:
        if name != "glove":
            m.vertex_normals                    # smooth normals from the faces
        scene.add_geometry(m, node_name=name, geom_name=name)
        print(name, len(m.faces), "tris")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    scene.export(OUT)
    print("wrote", os.path.normpath(OUT), os.path.getsize(OUT) // 1024, "KB")
    # where the chain leaves the fist (the thumb side of the grip), for the game
    w = v3(0.0, -0.002, -0.214)
    tunnel = v3(-0.045, -0.030, -0.296)                 # the thumb end of the grip's tunnel
    print("chain exit", np.round(w + (tunnel - w) * HAND_SCALE, 4))


if __name__ == "__main__":
    main()
