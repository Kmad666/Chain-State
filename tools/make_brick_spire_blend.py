import bpy, math, sys, os
here = os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
bpy.ops.import_scene.gltf(filepath=os.path.join(here, "brick_spire.glb"))
objs = [o for o in scene.objects if o.type == 'MESH']
col = bpy.data.collections.new("Brick Spire")
scene.collection.children.link(col)
for o in objs:
    for c in o.users_collection:
        c.objects.unlink(o)
    col.objects.link(o)
    # the game exports every face as its own triangles: weld them so it edits cleanly
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=0.001)
    bpy.ops.mesh.tris_convert_to_quads()
    bpy.ops.object.mode_set(mode='OBJECT')
    o.select_set(False)
    for p in o.data.polygons:
        p.use_smooth = False
# tidy the material names (the importer adds a number)
import re
for m in bpy.data.materials:
    m.name = re.sub(r"\d+$", "", m.name)
# parent everything to one empty at the tower's foot so it moves as one
root = bpy.data.objects.new("BrickSpire", None)
root.empty_display_type = 'PLAIN_AXES'
col.objects.link(root)
for o in objs:
    o.parent = root
# the waterline in the level: the tower's foot is 30 m below the sea
water = bpy.data.objects.new("Waterline (sea level in the game)", None)
water.empty_display_type = 'CUBE'
water.empty_display_size = 40
water.scale = (1.0, 1.0, 0.0001)
water.location = (0, 0, 30)
col.objects.link(water)
# report size
xs, ys, zs = [], [], []
for o in objs:
    for v in o.bound_box:
        w = o.matrix_world @ __import__('mathutils').Vector(v)
        xs.append(w.x); ys.append(w.y); zs.append(w.z)
print("SIZE x %.1f y %.1f z %.1f" % (max(xs)-min(xs), max(ys)-min(ys), max(zs)-min(zs)))
print("POLYS", sum(len(o.data.polygons) for o in objs), "VERTS", sum(len(o.data.vertices) for o in objs))
print("MATERIALS", sorted({m.name for o in objs for m in o.data.materials}))
# a camera and a sun for a quick preview
cam_data = bpy.data.cameras.new("Camera"); cam_data.lens = 35
cam = bpy.data.objects.new("Camera", cam_data); scene.collection.objects.link(cam)
cam.location = (170, -330, 120)
aim = bpy.data.objects.new("Camera target", None); scene.collection.objects.link(aim)
aim.location = (0, 0, 118)
track = cam.constraints.new('TRACK_TO'); track.target = aim
track.track_axis = 'TRACK_NEGATIVE_Z'; track.up_axis = 'UP_Y'
scene.camera = cam
sun_data = bpy.data.lights.new("Sun", 'SUN'); sun_data.energy = 4.0
sun = bpy.data.objects.new("Sun", sun_data); scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(40), math.radians(20), math.radians(30))
world = bpy.data.worlds.new("World"); scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.18, 0.32, 0.62, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
bpy.ops.file.pack_all()                      # keep the stone textures inside the .blend
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(here, "brick_spire.blend"), compress=True)
if "--render" in sys.argv:
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 24
    scene.cycles.device = 'CPU'
    scene.render.resolution_x = 640
    scene.render.resolution_y = 900
    scene.render.filepath = os.path.join(here, "brick_spire_preview.png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED")
