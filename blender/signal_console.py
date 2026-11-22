"""
VotV — Signal Reception / Processing Console  (SIG_)
Build: run inside Blender (MCP execute_blender_code), or `blender -b -P signal_console.py`.
Generates geometry, procedural emissive screens, the SignalFlow_12s action, VSE sounds,
three keyframe renders and signal_console.blend. No external assets, no addons.
"""
import bpy
import math
import os
import random
from mathutils import Vector

TAU = 2.0 * math.pi
ROOT = os.path.dirname(os.path.abspath(__file__))
SOUND_DIR = os.path.join(ROOT, "sounds")
RENDER_DIR = os.path.join(ROOT, "renders")
os.makedirs(RENDER_DIR, exist_ok=True)

USER_PROMPT = "Recrea en Blender la consola de recepcion/procesamiento de senales de Voices of the Void con mecanicas, animaciones y sonidos"

# --------------------------------------------------------------------------- scene reset
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
for col in list(bpy.data.collections):
    bpy.data.collections.remove(col)
for act in list(bpy.data.actions):
    bpy.data.actions.remove(act)
if bpy.context.scene.sequence_editor:
    bpy.context.scene.sequence_editor_clear()

scene = bpy.context.scene
scene.render.fps = 24
scene.frame_start = 1
scene.frame_end = 288
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0

# --------------------------------------------------------------------------- collections
COLS = {}
for cname in ("MESH", "SCREENS", "UI_OVERLAYS", "LIGHTS", "SOUND", "RIG"):
    c = bpy.data.collections.new("SIG_" + cname)
    scene.collection.children.link(c)
    COLS[cname] = c


def link(ob, cname):
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    COLS[cname].objects.link(ob)
    return ob


# --------------------------------------------------------------------------- shared action
ACTION = bpy.data.actions.new("SignalFlow_12s")


def bind(idblock, id_type, label):
    idblock.animation_data_create()
    idblock.animation_data.action = ACTION
    idblock.animation_data.action_slot = ACTION.slots.new(id_type, label)
    return idblock


def kobj(ob, path, frame, value, index=None):
    if index is None:
        setattr(ob, path, value)
        ob.keyframe_insert(data_path=path, frame=frame)
    else:
        arr = getattr(ob, path)
        arr[index] = value
        ob.keyframe_insert(data_path=path, index=index, frame=frame)


def ksock(sock, frame, value):
    sock.default_value = value
    sock.keyframe_insert(data_path="default_value", frame=frame)


def kvis(ob, entries):
    for frame, visible in entries:
        ob.hide_render = not visible
        ob.keyframe_insert(data_path="hide_render", frame=frame)
        ob.hide_viewport = not visible
        ob.keyframe_insert(data_path="hide_viewport", frame=frame)
    # leave the object visible in the saved file; the F-curves drive state at playback
    ob.hide_render = False
    ob.hide_viewport = False


# --------------------------------------------------------------------------- materials
def principled(name, color, metallic=0.5, rough=0.6, noise=False, rust=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    N = m.node_tree.nodes
    L = m.node_tree.links
    bs = next(n for n in N if n.type == 'BSDF_PRINCIPLED')
    out = next(n for n in N if n.type == 'OUTPUT_MATERIAL')
    bs.inputs['Base Color'].default_value = color
    bs.inputs['Metallic'].default_value = metallic
    bs.inputs['Roughness'].default_value = rough
    if noise:
        tex = N.new('ShaderNodeTexNoise')
        tex.inputs['Scale'].default_value = 140.0 if not rust else 70.0
        tex.inputs['Detail'].default_value = 3.0
        ramp = N.new('ShaderNodeValToRGB')
        lo = ramp.color_ramp.elements[0]
        hi = ramp.color_ramp.elements[1]
        lo.position = 0.28
        hi.position = 0.78
        lo.color = (color[0] * 0.5, color[1] * 0.5, color[2] * 0.5, 1)
        hi.color = (min(1, color[0] * 1.3), min(1, color[1] * 1.3), min(1, color[2] * 1.3), 1)
        L.new(tex.outputs['Fac'], ramp.inputs['Fac'])
        L.new(ramp.outputs['Color'], bs.inputs['Base Color'])
    L.new(bs.outputs['BSDF'], out.inputs['Surface'])
    return m


MAT = {}
MAT['body'] = principled("SIG_mat_body", (0.125, 0.145, 0.125, 1), 0.55, 0.72, True)
MAT['panel'] = principled("SIG_mat_panel", (0.080, 0.095, 0.088, 1), 0.60, 0.62, True)
MAT['dark'] = principled("SIG_mat_dark", (0.028, 0.032, 0.030, 1), 0.25, 0.85)
MAT['rust'] = principled("SIG_mat_rust", (0.13, 0.07, 0.035, 1), 0.20, 0.95, True, True)
MAT['metal'] = principled("SIG_mat_metal", (0.30, 0.32, 0.30, 1), 0.85, 0.42)
MAT['cable'] = principled("SIG_mat_cable", (0.028, 0.028, 0.032, 1), 0.10, 0.90)
MAT['label'] = principled("SIG_mat_label", (0.50, 0.52, 0.44, 1), 0.0, 0.9)

ANIM_MATS = {}


def emission_mat(name, color, strength=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    N = m.node_tree.nodes
    L = m.node_tree.links
    for n in list(N):
        N.remove(n)
    out = N.new('ShaderNodeOutputMaterial')
    em = N.new('ShaderNodeEmission')
    em.inputs['Color'].default_value = color
    em.inputs['Strength'].default_value = strength
    L.new(em.outputs['Emission'], out.inputs['Surface'])
    bind(m, 'MATERIAL', name)
    ANIM_MATS[name] = m
    return m, em.inputs['Strength']


def screen_mat(name, dark, bright, strength=1.6):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    N = m.node_tree.nodes
    L = m.node_tree.links
    for n in list(N):
        N.remove(n)
    out = N.new('ShaderNodeOutputMaterial')
    em = N.new('ShaderNodeEmission')
    em.inputs['Strength'].default_value = strength
    L.new(em.outputs['Emission'], out.inputs['Surface'])
    tex = N.new('ShaderNodeTexNoise')
    tex.noise_dimensions = '4D'
    tex.inputs['Scale'].default_value = 95.0
    tex.inputs['Detail'].default_value = 1.5
    ramp = N.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.34
    ramp.color_ramp.elements[0].color = dark
    ramp.color_ramp.elements[1].position = 0.72
    ramp.color_ramp.elements[1].color = bright
    L.new(tex.outputs['Fac'], ramp.inputs['Fac'])
    L.new(ramp.outputs['Color'], em.inputs['Color'])
    bind(m, 'MATERIAL', name)
    ANIM_MATS[name] = m
    return m, em.inputs['Strength'], tex.inputs['W']


def sine_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    N = m.node_tree.nodes
    L = m.node_tree.links
    for n in list(N):
        N.remove(n)
    out = N.new('ShaderNodeOutputMaterial')
    em = N.new('ShaderNodeEmission')
    em.inputs['Strength'].default_value = 2.2
    L.new(em.outputs['Emission'], out.inputs['Surface'])
    uv = N.new('ShaderNodeTexCoord')
    sep = N.new('ShaderNodeSeparateXYZ')
    L.new(uv.outputs['UV'], sep.inputs['Vector'])
    mul = N.new('ShaderNodeMath'); mul.operation = 'MULTIPLY'
    mul.inputs[1].default_value = TAU * 2.6
    L.new(sep.outputs['X'], mul.inputs[0])
    sin = N.new('ShaderNodeMath'); sin.operation = 'SINE'
    L.new(mul.outputs[0], sin.inputs[0])
    amp = N.new('ShaderNodeValue'); amp.outputs[0].default_value = 0.12
    mm = N.new('ShaderNodeMath'); mm.operation = 'MULTIPLY'
    L.new(sin.outputs[0], mm.inputs[0]); L.new(amp.outputs[0], mm.inputs[1])
    add = N.new('ShaderNodeMath'); add.operation = 'ADD'
    add.inputs[1].default_value = 0.5
    L.new(mm.outputs[0], add.inputs[0])
    noise = N.new('ShaderNodeTexNoise'); noise.noise_dimensions = '4D'
    noise.inputs['Scale'].default_value = 9.0
    jitter = N.new('ShaderNodeMath'); jitter.operation = 'MULTIPLY'
    jitter.inputs[1].default_value = 0.028
    L.new(noise.outputs['Fac'], jitter.inputs[0])
    add2 = N.new('ShaderNodeMath'); add2.operation = 'ADD'
    L.new(add.outputs[0], add2.inputs[0]); L.new(jitter.outputs[0], add2.inputs[1])
    diff = N.new('ShaderNodeMath'); diff.operation = 'SUBTRACT'
    L.new(sep.outputs['Y'], diff.inputs[0]); L.new(add2.outputs[0], diff.inputs[1])
    ab = N.new('ShaderNodeMath'); ab.operation = 'ABSOLUTE'
    L.new(diff.outputs[0], ab.inputs[0])
    cmp = N.new('ShaderNodeMath'); cmp.operation = 'LESS_THAN'
    cmp.inputs[1].default_value = 0.028
    L.new(ab.outputs[0], cmp.inputs[0])
    mix = N.new('ShaderNodeMixRGB')
    mix.inputs[1].default_value = (0.005, 0.05, 0.025, 1)
    mix.inputs[2].default_value = (0.35, 1.0, 0.55, 1)
    L.new(cmp.outputs[0], mix.inputs[0]); L.new(mix.outputs[0], em.inputs['Color'])
    bind(m, 'MATERIAL', name)
    ANIM_MATS[name] = m
    return m, amp.outputs[0], noise.inputs['W']


def level_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    N = m.node_tree.nodes
    L = m.node_tree.links
    for n in list(N):
        N.remove(n)
    out = N.new('ShaderNodeOutputMaterial')
    em = N.new('ShaderNodeEmission'); em.inputs['Strength'].default_value = 2.0
    L.new(em.outputs['Emission'], out.inputs['Surface'])
    uv = N.new('ShaderNodeTexCoord')
    sep = N.new('ShaderNodeSeparateXYZ')
    L.new(uv.outputs['UV'], sep.inputs['Vector'])
    level = N.new('ShaderNodeValue'); level.outputs[0].default_value = 0.5
    cmp = N.new('ShaderNodeMath'); cmp.operation = 'LESS_THAN'
    L.new(sep.outputs['Y'], cmp.inputs[0]); L.new(level.outputs[0], cmp.inputs[1])
    seg = N.new('ShaderNodeMath'); seg.operation = 'MULTIPLY'
    seg.inputs[1].default_value = 14.0
    L.new(sep.outputs['Y'], seg.inputs[0])
    fr = N.new('ShaderNodeMath'); fr.operation = 'FRACT'
    L.new(seg.outputs[0], fr.inputs[0])
    scmp = N.new('ShaderNodeMath'); scmp.operation = 'LESS_THAN'
    scmp.inputs[1].default_value = 0.72
    L.new(fr.outputs[0], scmp.inputs[0])
    both = N.new('ShaderNodeMath'); both.operation = 'MULTIPLY'
    L.new(cmp.outputs[0], both.inputs[0]); L.new(scmp.outputs[0], both.inputs[1])
    mix = N.new('ShaderNodeMixRGB')
    mix.inputs[1].default_value = (0.01, 0.06, 0.03, 1)
    mix.inputs[2].default_value = (0.35, 1.0, 0.5, 1)
    L.new(both.outputs[0], mix.inputs[0]); L.new(mix.outputs[0], em.inputs['Color'])
    bind(m, 'MATERIAL', name)
    ANIM_MATS[name] = m
    return m, level.outputs[0]


# Bright/dim variants give visible CRT flicker via hide_render (socket F-curves
# are stored in the action but Blender 5.2 does not evaluate node sockets live).
MAT['crt'], S_crt, W_crt = screen_mat("SIG_mat_crt_green", (0.002, 0.014, 0.006, 1), (0.12, 0.58, 0.22, 1))
MAT['crt_dim'], S_crt_dim, W_crt_dim = screen_mat("SIG_mat_crt_dim", (0.001, 0.006, 0.003, 1), (0.04, 0.22, 0.08, 1), 1.2)
MAT['crt_bright'], S_crt_bright, W_crt_bright = screen_mat("SIG_mat_crt_bright", (0.004, 0.02, 0.008, 1), (0.25, 0.95, 0.40, 1), 2.4)
MAT['sine'], AMP_sine, W_sine = sine_mat("SIG_mat_sine_graph")
MAT['level'], LEVEL_bar = level_mat("SIG_mat_level_bar")
MAT['led_green'], S_led_green = emission_mat("SIG_mat_led_green", (0.15, 1.0, 0.35, 1), 3.0)
MAT['led_red'], S_led_red = emission_mat("SIG_mat_led_red", (1.0, 0.08, 0.05, 1), 3.0)
MAT['led_amber'], S_led_amber = emission_mat("SIG_mat_led_amber", (1.0, 0.6, 0.1, 1), 3.0)
MAT['ui_red'], _ = emission_mat("SIG_mat_ui_red", (1.0, 0.12, 0.08, 1), 3.6)
MAT['ui_amber'], _ = emission_mat("SIG_mat_ui_amber", (1.0, 0.72, 0.2, 1), 3.4)
MAT['ui_green'], _ = emission_mat("SIG_mat_ui_green", (0.35, 1.0, 0.5, 1), 3.6)
MAT['ui_blue'], _ = emission_mat("SIG_mat_ui_blue", (0.25, 0.55, 1.0, 1), 1.8)

# --------------------------------------------------------------------------- font
FONT = None
for fp in (r"C:\Windows\Fonts\arial.ttf", r"C:\Windows\Fonts\segoeui.ttf"):
    if os.path.exists(fp):
        FONT = bpy.data.fonts.load(fp)
        break

# --------------------------------------------------------------------------- geometry helpers
def box(name, loc, dims, mat, coll="MESH", parent=None, bevel=0.0, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1)
    ob = bpy.context.object
    ob.name = name
    ob.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        ob.data.materials.append(mat)
    link(ob, coll)
    if parent:
        ob.parent = parent
    ob.location = loc
    if rot:
        ob.rotation_euler = rot
    if bevel:
        b = ob.modifiers.new("SIG_bevel", 'BEVEL')
        b.width = bevel
        b.segments = 2
        ob.modifiers.new("SIG_wn", 'WEIGHTED_NORMAL')
    return ob


def plane(name, loc, dims, mat, coll="SCREENS", parent=None):
    bpy.ops.mesh.primitive_plane_add(size=1)
    ob = bpy.context.object
    ob.name = name
    ob.scale = (dims[0], dims[1], 1)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        ob.data.materials.append(mat)
    link(ob, coll)
    if parent:
        ob.parent = parent
    ob.location = loc
    return ob


def cyl(name, loc, radius, depth, mat, coll="MESH", parent=None, verts=24, rot=None, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth)
    ob = bpy.context.object
    ob.name = name
    if mat:
        ob.data.materials.append(mat)
    link(ob, coll)
    if parent:
        ob.parent = parent
    ob.location = loc
    if rot:
        ob.rotation_euler = rot
    if bevel:
        b = ob.modifiers.new("SIG_bevel", 'BEVEL')
        b.width = bevel
        b.segments = 2
    return ob


def text(name, body, loc, size, mat, coll="UI_OVERLAYS", parent=None, rot=None, align='CENTER'):
    cu = bpy.data.curves.new(name, 'FONT')
    cu.body = body
    cu.size = size
    cu.align_x = align
    cu.extrude = 0.0003
    cu.space_character = 1.0
    if FONT:
        cu.font = FONT
    ob = bpy.data.objects.new(name, cu)
    COLS[coll].objects.link(ob)
    ob.data.materials.append(mat)
    if parent:
        ob.parent = parent
    ob.location = loc
    if rot:
        ob.rotation_euler = rot
    return ob


def tube(name, pts, radius, mat, parent=None):
    cu = bpy.data.curves.new(name, 'CURVE')
    cu.dimensions = '3D'
    cu.resolution_u = 10
    sp = cu.splines.new('POLY')
    sp.points.add(len(pts) - 1)
    for p, co in zip(sp.points, pts):
        p.co = (co[0], co[1], co[2], 1)
    cu.bevel_depth = radius
    cu.bevel_resolution = 2
    ob = bpy.data.objects.new(name, cu)
    COLS["MESH"].objects.link(ob)
    ob.data.materials.append(mat)
    if parent:
        ob.parent = parent
    return ob


def look_at(ob, target):
    direction = Vector(target) - ob.location
    ob.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()


# --------------------------------------------------------------------------- cabinet (world space)
body = box("SIG_cabinet_body", (0, 0, 0.325), (1.20, 0.60, 0.49), MAT['body'], bevel=0.012)
plinth = box("SIG_cabinet_plinth", (0, 0, 0.04), (1.10, 0.54, 0.08), MAT['dark'], bevel=0.006)
front = box("SIG_cabinet_front_panel", (0, -0.302, 0.325), (1.16, 0.014, 0.45), MAT['panel'], bevel=0.004)
for i in range(7):
    box("SIG_vent_%02d" % i, (-0.34 + i * 0.028, -0.311, 0.17), (0.012, 0.004, 0.10), MAT['dark'])
for rx, rz, rw, rh in [(-0.55, 0.10, 0.05, 0.03), (0.55, 0.46, 0.035, 0.05), (0.49, 0.09, 0.06, 0.02)]:
    box("SIG_rust_%s_%s" % (rx, rz), (rx, -0.311, rz), (rw, 0.003, rh), MAT['rust'])
box("SIG_top_rail_front", (0, -0.29, 0.572), (1.20, 0.02, 0.012), MAT['metal'])
text("SIG_label_main", "ПРИЁМНИК СИГНАЛОВ  ПС-27", (0, -0.312, 0.46), 0.030, MAT['label'],
     coll="MESH", rot=(math.radians(90), 0, 0))
text("SIG_label_cams", "cams (blue) - cameras", (0, -0.312, 0.115), 0.018, MAT['ui_blue'],
     coll="MESH", rot=(math.radians(90), 0, 0))
for sx in (-0.55, 0.55):
    for sz in (0.14, 0.51):
        cyl("SIG_screw_front_%s_%s" % (sx, sz), (sx, -0.312, sz), 0.009, 0.006, MAT['metal'],
            verts=12, rot=(math.radians(90), 0, 0))

# --------------------------------------------------------------------------- sloped deck
deck = bpy.data.objects.new("SIG_deck_root", None)
COLS["RIG"].objects.link(deck)
deck.location = (0, 0, 0.660)
deck.rotation_euler.x = math.radians(18)
box("SIG_deck_surface", (0, 0, -0.015), (1.16, 0.62, 0.030), MAT['panel'], parent=deck, bevel=0.008)
for sx in (-0.55, 0.55):
    for sy in (-0.28, 0.28):
        cyl("SIG_screw_deck_%s_%s" % (sx, sy), (sx, sy, 0.003), 0.008, 0.006, MAT['metal'],
            parent=deck, verts=12)

# Deck layout (local y): slot reader 0.22..0.30, screens -0.095..0.205,
# controls -0.29..-0.12. Keeping these bands apart avoids intersecting parts.
SY = 0.055  # screen band centre

# CRT monitor (recessed in deck)
box("SIG_crt_bezel", (-0.27, SY, 0.020), (0.52, 0.30, 0.040), MAT['dark'], parent=deck, bevel=0.006)
crt = plane("SIG_crt_screen", (-0.27, SY, 0.041), (0.46, 0.26), MAT['crt'], parent=deck)
bind(crt, 'OBJECT', "SIG_crt_screen")
crt_dim = plane("SIG_crt_screen_dim", (-0.27, SY, 0.0406), (0.46, 0.26), MAT['crt_dim'], parent=deck)
bind(crt_dim, 'OBJECT', "SIG_crt_screen_dim")
crt_bright = plane("SIG_crt_screen_bright", (-0.27, SY, 0.0414), (0.46, 0.26), MAT['crt_bright'], parent=deck)
bind(crt_bright, 'OBJECT', "SIG_crt_screen_bright")
for dx in (-0.245, 0.245):
    box("SIG_crt_trim_v_%s" % dx, (-0.27 + dx, SY, 0.043), (0.012, 0.27, 0.006), MAT['metal'], parent=deck)
for dy in (-0.14, 0.14):
    box("SIG_crt_trim_h_%s" % dy, (-0.27, SY + dy, 0.043), (0.50, 0.012, 0.006), MAT['metal'], parent=deck)
text("SIG_label_oscillograph", "ОСЦИЛЛОГРАФ", (-0.27, -0.112, 0.010), 0.018, MAT['label'], parent=deck)

# transformer panel: sine graph + level bar
box("SIG_transformer_panel", (0.29, SY, 0.018), (0.50, 0.30, 0.036), MAT['body'], parent=deck, bevel=0.005)
box("SIG_sine_background", (0.29, 0.105, 0.038), (0.44, 0.14, 0.004), MAT['dark'], parent=deck)
sine = plane("SIG_sine_graph", (0.29, 0.105, 0.041), (0.42, 0.13), MAT['sine'], parent=deck)
box("SIG_level_background", (0.29, -0.030, 0.038), (0.44, 0.050, 0.004), MAT['dark'], parent=deck)
level = plane("SIG_level_bar", (0.29, -0.030, 0.041), (0.42, 0.042), MAT['level'], parent=deck)
text("SIG_label_level", "УРОВЕНЬ  СИГНАЛА", (0.29, -0.072, 0.038), 0.016, MAT['label'], parent=deck)
text("SIG_label_transformer", "ТРАНСФОРМАТОР  T-2", (0.29, 0.185, 0.038), 0.016, MAT['label'], parent=deck)
for sx in (0.075, 0.505):
    cyl("SIG_screw_panel_%s" % sx, (sx, 0.185, 0.038), 0.007, 0.005, MAT['metal'], parent=deck, verts=10)

# signal slot reader
box("SIG_slot_housing", (0, 0.264, 0.018), (0.50, 0.078, 0.036), MAT['panel'], parent=deck, bevel=0.003)
box("SIG_slot_recess", (0, 0.264, 0.038), (0.46, 0.050, 0.004), MAT['dark'], parent=deck)
text("SIG_label_slot", "СИГНАЛ / HASHCODE", (0, 0.297, 0.038), 0.014, MAT['label'], parent=deck)

# dials
def knob(name, loc, radius, mat):
    base = cyl(name + "_base", (loc[0], loc[1], 0.012), radius * 1.25, 0.014, MAT['dark'], parent=deck)
    k = cyl(name, (loc[0], loc[1], 0.030), radius, 0.038, mat, parent=deck, bevel=0.004)
    bpy.ops.mesh.primitive_cube_add(size=1)
    ptr = bpy.context.object
    ptr.name = name + "_pointer"
    ptr.dimensions = (radius * 0.16, radius * 0.85, 0.006)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ptr.data.materials.append(MAT['label'])
    link(ptr, "MESH")
    ptr.parent = k
    ptr.location = (0, radius * 0.45, 0.021)
    return k

dial_freq = knob("SIG_dial_freq", (-0.02, -0.205), 0.065, MAT['metal'])
bind(dial_freq, 'OBJECT', "SIG_dial_freq")
text("SIG_label_freq", "ЧАСТОТА  MHz", (-0.02, -0.292, 0.010), 0.017, MAT['label'], parent=deck)
jog = knob("SIG_jog_tune", (0.16, -0.205), 0.036, MAT['rust'])
bind(jog, 'OBJECT', "SIG_jog_tune")
text("SIG_label_jog", "НАСТРОЙКА", (0.16, -0.264, 0.010), 0.013, MAT['label'], parent=deck)
dial_a = knob("SIG_dial_gain", (-0.30, -0.20), 0.032, MAT['metal'])
bind(dial_a, 'OBJECT', "SIG_dial_gain")
dial_b = knob("SIG_dial_band", (0.30, -0.20), 0.032, MAT['metal'])
bind(dial_b, 'OBJECT', "SIG_dial_band")

# toggle switches
def switch(name, x, y):
    cyl(name + "_base", (x, y, 0.010), 0.020, 0.012, MAT['metal'], parent=deck, verts=16)
    lever = box(name, (x, y, 0.036), (0.008, 0.008, 0.055), MAT['metal'], parent=deck)
    return lever

sw_power = switch("SIG_switch_power", -0.535, -0.215)
sw_band = switch("SIG_switch_band", -0.44, -0.215)
sw_alert = switch("SIG_switch_alert", 0.44, -0.215)
sw_aux = switch("SIG_switch_aux", 0.535, -0.215)
for s in (sw_power, sw_band, sw_alert, sw_aux):
    bind(s, 'OBJECT', s.name)

# LEDs
def led(name, x, y, color_mat):
    cyl(name + "_housing", (x, y, 0.012), 0.020, 0.012, MAT['metal'], parent=deck, verts=16)
    lens = cyl(name, (x, y, 0.024), 0.014, 0.010, color_mat, parent=deck, verts=16)
    return lens

led_lock = led("SIG_led_lock", -0.555, 0.225, MAT['led_green'])
led_alert = led("SIG_led_alert", 0.56, 0.225, MAT['led_red'])
led_power = led("SIG_led_power", -0.555, -0.10, MAT['led_amber'])
for l in (led_lock, led_alert, led_power):
    bind(l, 'OBJECT', l.name)

# cables
def sag_cable(name, a, b, lift):
    pts = []
    for i in range(13):
        t = i / 12.0
        x = a[0] + (b[0] - a[0]) * t
        y = a[1] + (b[1] - a[1]) * t
        z = a[2] + (b[2] - a[2]) * t + lift * math.sin(math.pi * t)
        pts.append((x, y, z))
    return tube(name, pts, 0.006, MAT['cable'], parent=deck)

sag_cable("SIG_cable_crt_1", (-0.50, -0.302, 0.004), (0.50, -0.302, 0.004), 0.010)
sag_cable("SIG_cable_crt_2", (-0.50, 0.215, 0.004), (-0.56, 0.285, 0.004), 0.006)
sag_cable("SIG_cable_power", (0.50, 0.215, 0.004), (0.56, 0.285, 0.004), 0.006)

# --------------------------------------------------------------------------- UI overlays on the CRT
ui_power = text("SIG_ui_power_msg", "It is not the time", (-0.27, 0.140, 0.046), 0.024, MAT['ui_amber'], parent=deck)
ui_nosig = text("SIG_ui_no_signal", "No hashcodes found: try again next day", (-0.27, -0.010, 0.046), 0.019, MAT['ui_amber'], parent=deck)
ui_hash_crt = text("SIG_ui_hash_crt", "HASH  482913", (-0.27, -0.055, 0.046), 0.030, MAT['ui_green'], parent=deck)
ui_hash_idle = text("SIG_ui_hash_idle", "------", (0, 0.264, 0.043), 0.042, MAT['ui_amber'], parent=deck)
ui_hash_lock = text("SIG_ui_hash_lock", "482913", (0, 0.264, 0.043), 0.042, MAT['ui_green'], parent=deck)
ui_alert_title = text("SIG_ui_alert_title", "!!!Automatic Alert System!!!", (-0.27, 0.140, 0.046), 0.022, MAT['ui_red'], parent=deck)
ui_entity = text("SIG_ui_alert_entity", "Invalid entity group", (-0.27, 0.000, 0.046), 0.020, MAT['ui_red'], parent=deck)
ui_creature = text("SIG_ui_alert_creature", "The Creature is currently active", (-0.27, 0.000, 0.046), 0.018, MAT['ui_red'], parent=deck)

# --------------------------------------------------------------------------- EMF meter (comp_emf) — extra
emf = bpy.data.objects.new("SIG_emf_meter_root", None)
COLS["RIG"].objects.link(emf)
emf.location = (0.98, -0.04, 0)
box("SIG_emf_body", (0, 0, 0.115), (0.20, 0.12, 0.23), MAT['rust'], parent=emf, bevel=0.008)
box("SIG_emf_face", (0, -0.062, 0.16), (0.17, 0.006, 0.13), MAT['label'], parent=emf)
box("SIG_emf_screen_bg", (0, -0.066, 0.16), (0.13, 0.004, 0.085), MAT['dark'], parent=emf)
# needle pivots at the bottom centre of the gauge
emf_needle = box("SIG_emf_needle", (0, -0.070, 0.120), (0.003, 0.003, 0.070), MAT['ui_red'], parent=emf)
emf_needle.location = (0, -0.070, 0.120 + 0.035)
cyl("SIG_emf_pivot", (0, -0.072, 0.120), 0.010, 0.006, MAT['metal'], parent=emf,
    verts=16, rot=(math.radians(90), 0, 0))
text("SIG_emf_label", "EMF", (0, -0.066, 0.208), 0.020, MAT['ui_red'], parent=emf,
     rot=(math.radians(90), 0, 0))
emf_led = cyl("SIG_emf_led", (0.055, -0.066, 0.078), 0.008, 0.006, MAT['led_green'], parent=emf,
              verts=12, rot=(math.radians(90), 0, 0))
for sx in (-0.075, 0.075):
    cyl("SIG_emf_screw_%s" % sx, (sx, -0.066, 0.218), 0.005, 0.004, MAT['metal'], parent=emf,
        verts=10, rot=(math.radians(90), 0, 0))
bind(emf_needle, 'OBJECT', "SIG_emf_needle")
bind(emf_led, 'OBJECT', "SIG_emf_led")
kvis(emf_led, [(1, False), (48, False), (60, True), (144, True), (145, False), (288, False)])
for f, v in [(1, 0.0), (48, 0.0), (60, -0.9), (72, 0.7), (84, -0.6), (96, 0.9), (108, -0.4),
             (120, 0.8), (132, -0.7), (144, -1.0), (145, 0.9), (160, 0.95), (192, 0.9),
             (193, 0.2), (205, -0.9), (215, 0.6), (230, -0.8), (240, 0.7), (241, 0.0), (288, 0.0)]:
    kobj(emf_needle, "rotation_euler", f, v, index=1)
emf["sound_trigger"] = "sig_beep_880.wav"
emf["sound_event"] = "EMF beeps: rate proportional to needle deflection / entity proximity"
emf["sound_start_frame"] = 60
emf["sound_end_frame"] = 240

# --------------------------------------------------------------------------- lights + camera
world = bpy.data.worlds.new("SIG_world")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
bg.inputs['Color'].default_value = (0.018, 0.024, 0.034, 1)
bg.inputs['Strength'].default_value = 0.22


def area(name, loc, target, energy, size, color):
    data = bpy.data.lights.new(name, 'AREA')
    data.energy = energy
    data.shape = 'DISK'
    data.size = size
    data.color = color
    ob = bpy.data.objects.new(name, data)
    COLS["LIGHTS"].objects.link(ob)
    ob.location = loc
    look_at(ob, target)
    return ob

key = area("SIG_light_key", (1.0, -1.3, 1.7), (0, 0, 0.45), 320, 2.0, (0.72, 0.84, 1.0))
fill = area("SIG_light_fill", (-1.2, -0.5, 1.1), (0, 0, 0.45), 110, 1.5, (0.55, 0.72, 0.95))

crt_light_data = bpy.data.lights.new("SIG_light_crt_glow", 'POINT')
crt_light_data.energy = 0
crt_light_data.color = (0.3, 1.0, 0.45)
crt_light = bpy.data.objects.new("SIG_light_crt_glow", crt_light_data)
COLS["LIGHTS"].objects.link(crt_light)
crt_light.location = (-0.27, -0.05, 0.72)
bind(crt_light, 'OBJECT', "SIG_light_crt_glow")

alert_light_data = bpy.data.lights.new("SIG_light_alert_red", 'POINT')
alert_light_data.energy = 0
alert_light_data.color = (1.0, 0.06, 0.04)
alert_light = bpy.data.objects.new("SIG_light_alert_red", alert_light_data)
COLS["LIGHTS"].objects.link(alert_light)
alert_light.location = (0, 0, 0.84)
bind(alert_light, 'OBJECT', "SIG_light_alert_red")

cam_data = bpy.data.cameras.new("SIG_camera")
cam = bpy.data.objects.new("SIG_camera", cam_data)
COLS["RIG"].objects.link(cam)
cam.location = (1.15, -1.85, 1.28)
look_at(cam, (0, 0, 0.42))
cam_data.lens = 42
scene.camera = cam

# --------------------------------------------------------------------------- animation
# tuning dial
for f, v in [(1, 0), (48, 0), (60, 0.7), (72, 1.9), (84, 1.3), (96, 3.1), (108, 2.5),
             (120, 4.3), (132, 3.7), (144, 5.0), (240, 5.0), (288, 5.0)]:
    kobj(dial_freq, "rotation_euler", f, v, index=2)
for f, v in [(1, 0), (48, 0), (144, 8.5), (240, 8.5), (288, 8.5)]:
    kobj(jog, "rotation_euler", f, v, index=2)
for f, v in [(1, 0), (48, 0), (96, 1.4), (144, 2.2), (240, 2.2), (288, 2.2)]:
    kobj(dial_a, "rotation_euler", f, v, index=2)
    kobj(dial_b, "rotation_euler", f, -v * 0.7, index=2)

# switches (lever tilt about local X)
for f, v in [(1, -0.7), (2, 0.7), (240, 0.7), (241, -0.7), (288, -0.7)]:
    kobj(sw_power, "rotation_euler", f, v, index=0)
for f, v in [(1, -0.6), (48, 0.6), (144, -0.6), (288, -0.6)]:
    kobj(sw_band, "rotation_euler", f, v, index=0)
for f, v in [(1, -0.6), (192, -0.6), (193, 0.6), (240, 0.6), (241, -0.6), (288, -0.6)]:
    kobj(sw_alert, "rotation_euler", f, v, index=0)
for f, v in [(1, 0.6), (288, 0.6)]:
    kobj(sw_aux, "rotation_euler", f, v, index=0)

# CRT emission: power-on flicker, tuning instability, lock, alert, collapse
crt_keys = [(1, 0.0), (2, 2.4), (3, 0.3), (4, 2.7), (6, 1.6), (8, 2.3), (12, 1.9), (20, 2.1), (48, 2.0)]
for f in range(54, 145, 6):
    crt_keys.append((f, 0.7 if (f // 6) % 2 else 1.7))
crt_keys += [(145, 3.0), (160, 2.7), (192, 2.7)]
for f in range(196, 241, 5):
    crt_keys.append((f, 3.0 if (f // 5) % 2 else 0.6))
crt_keys += [(241, 2.0), (246, 1.5), (252, 0.7), (256, 3.2), (258, 0.15), (263, 0.0), (288, 0.0)]
for f, v in crt_keys:
    ksock(S_crt, f, v)
# visible flicker: exactly one of dim / normal / bright CRT planes is shown
# state = 0 off, 1 dim, 2 normal, 3 bright
crt_state = [(1, 0), (2, 3), (3, 1), (4, 3), (6, 2), (12, 2), (48, 2)]
for f in range(54, 145, 6):
    crt_state.append((f, 1 if (f // 6) % 2 else 3))
crt_state += [(145, 3), (150, 2), (192, 2)]
for f in range(196, 241, 5):
    crt_state.append((f, 1 if (f // 5) % 2 else 3))
crt_state += [(241, 2), (246, 2), (252, 1), (256, 3), (258, 0), (288, 0)]
for plane, state in ((crt, 2), (crt_dim, 1), (crt_bright, 3)):
    kvis(plane, [(f, s == state) for f, s in crt_state])
# static scroll: faster during tuning
for f, v in [(1, 0), (48, 8), (144, 60), (192, 70), (240, 84), (288, 95)]:
    ksock(W_crt, f, v)
# CRT collapse to a point on shutdown
for f, s in [(1, 1.0), (240, 1.0), (248, 0.55), (254, 0.12), (259, 0.008), (288, 0.008)]:
    for sc_plane in (crt, crt_dim, crt_bright):
        kobj(sc_plane, "scale", f, (s, s, 1.0))

# sine wave amplitude / jitter
for f, v in [(1, 0.16), (48, 0.16), (60, 0.26), (72, 0.34), (84, 0.20), (96, 0.31), (108, 0.22),
             (120, 0.29), (132, 0.21), (144, 0.17), (150, 0.16), (192, 0.16), (193, 0.26),
             (200, 0.35), (215, 0.38), (230, 0.32), (240, 0.36), (241, 0.22), (260, 0.08), (288, 0.04)]:
    ksock(AMP_sine, f, v)
for f, v in [(1, 0), (48, 2), (144, 22), (192, 24), (240, 34), (288, 40)]:
    ksock(W_sine, f, v)

# level bar
for f, v in [(1, 0.0), (48, 0.0), (60, 0.55), (72, 0.20), (84, 0.72), (96, 0.36), (108, 0.82),
             (120, 0.50), (132, 0.86), (144, 0.90), (150, 0.93), (192, 0.93), (193, 0.30),
             (210, 0.62), (230, 0.44), (240, 0.55), (241, 0.10), (288, 0.0)]:
    ksock(LEVEL_bar, f, v)

# LEDs: socket F-curves live in the action; hide_render gives the visible state.
for f, v in [(1, 0.0), (144, 0.0), (145, 5.0), (192, 5.0), (193, 0.0), (288, 0.0)]:
    ksock(S_led_green, f, v)
for f, v in [(1, 0.0), (192, 0.0)] + [(f, 3.2 if (f // 6) % 2 else 0.0) for f in range(193, 241, 6)] + [(241, 0.0), (288, 0.0)]:
    ksock(S_led_red, f, v)
for f, v in [(1, 0.0), (2, 2.0), (240, 2.0), (241, 0.0), (288, 0.0)]:
    ksock(S_led_amber, f, v)
kvis(led_lock, [(1, False), (144, False), (145, True), (192, True), (193, False), (288, False)])
kvis(led_alert, [(1, False), (192, False)] +
     [(f, (f // 6) % 2 == 0) for f in range(193, 241, 6)] + [(241, False), (288, False)])
kvis(led_power, [(1, False), (2, True), (240, True), (241, False), (288, False)])

# coloured lights follow the screens
for f, v in crt_keys:
    kobj(crt_light.data, "energy", f, v * 22.0)
for f, v in [(1, 0.0), (192, 0.0)] + [(f, 90.0 if (f // 6) % 2 else 0.0) for f in range(193, 241, 6)] + [(241, 0.0), (288, 0.0)]:
    kobj(alert_light.data, "energy", f, v)

# message visibility
for ui in (ui_power, ui_nosig, ui_hash_crt, ui_hash_idle, ui_hash_lock,
           ui_alert_title, ui_entity, ui_creature):
    bind(ui, 'OBJECT', ui.name)
kvis(ui_power, [(1, True), (40, True), (41, False), (288, False)])
kvis(ui_nosig, [(1, False), (100, True), (140, True), (141, False), (288, False)])
kvis(ui_hash_crt, [(1, False), (144, False), (145, True), (192, True), (193, False), (288, False)])
kvis(ui_hash_idle, [(1, True), (144, True), (145, False), (288, False)])
kvis(ui_hash_lock, [(1, False), (144, False), (145, True), (192, True), (193, False), (288, False)])
kvis(ui_alert_title, [(1, False), (192, False), (193, True), (240, True), (241, False), (288, False)])
kvis(ui_entity, [(1, False), (192, False), (193, True), (214, True), (215, False), (288, False)])
kvis(ui_creature, [(1, False), (214, False), (215, True), (240, True), (241, False), (288, False)])

# linear interpolation for flicker/visibility so states read as hard edits
for ad in (crt.animation_data, led_lock.animation_data, led_alert.animation_data,
           ui_entity.animation_data, ui_hash_lock.animation_data, alert_light.animation_data):
    if not ad or not ad.action:
        continue
    for layer in ad.action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for kp in fc.keyframe_points:
                        kp.interpolation = 'LINEAR'

# --------------------------------------------------------------------------- sound markers / VSE
SFX = [
    ("SIG_sfx_transformer_hum", "sig_transformer_hum.wav", 1, 240, "Zumbido 50 Hz sube al encender"),
    ("SIG_sfx_crt_whine", "sig_crt_whine.wav", 1, 240, "Agudo ~15.7 kHz del CRT (bajo volumen)"),
    ("SIG_sfx_relay_on", "sig_relay_click.wav", 2, 4, "Clic de relé al dar corriente"),
    ("SIG_sfx_static", "sig_static_filtered.wav", 48, 97, "Ruido de sintonía 2-6 s"),
    ("SIG_sfx_relay_lock", "sig_relay_click.wav", 145, 4, "Clic de relé al bloquear"),
    ("SIG_sfx_beep", "sig_beep_880.wav", 145, 6, "Beep 880 Hz de bloqueo / hashcode"),
    ("SIG_sfx_relay_alert", "sig_relay_click.wav", 193, 4, "Clic de relé al disparar alerta"),
    ("SIG_sfx_alarm", "sig_alarm_two_tone.wav", 193, 48, "Alarma two-tone 600/900 Hz"),
    ("SIG_sfx_relay_off", "sig_relay_click.wav", 241, 4, "Clic de relé al apagar"),
    ("SIG_sfx_shutdown", "sig_station_turnoff.wav", 241, 34, "Apagado descendente + colapso del CRT"),
]
for name, wav, start, dur, desc in SFX:
    e = bpy.data.objects.new(name, None)
    COLS["SOUND"].objects.link(e)
    e.location = (0, 0, 0)
    e["sound_file"] = wav
    e["frame_start"] = start
    e["frame_end"] = start + dur - 1
    e["description"] = desc
    e.empty_display_size = 0.04

# object -> sound trigger custom properties
def snd(ob, key, wav, start, end=None, desc=""):
    ob["sound_trigger"] = wav
    ob["sound_start_frame"] = start
    if end is not None:
        ob["sound_end_frame"] = end
    ob["sound_event"] = desc or key

snd(body, "hum", "sig_transformer_hum.wav", 1, 240, "power_on -> transformer hum")
snd(crt, "whine", "sig_crt_whine.wav", 1, 240, "power_on -> CRT whine + flicker")
snd(dial_freq, "static", "sig_static_filtered.wav", 48, 144, "tuning -> filtered noise")
snd(led_lock, "lock", "sig_beep_880.wav", 145, None, "lock -> 880 Hz beep + hashcode")
snd(led_alert, "alarm", "sig_alarm_two_tone.wav", 193, 240, "alert -> two-tone alarm")
sw_power["sound_trigger_on"] = "sig_relay_click.wav"
sw_power["sound_trigger_off"] = "sig_station_turnoff.wav"

se = scene.sequence_editor_create()
CH = {"hum": 1, "whine": 2, "click": 3, "beep": 4, "alarm": 5}
def add_strip(name, wav, start, channel, dur=None, volume=1.0):
    s = se.strips.new_sound(name=name, filepath=os.path.join(SOUND_DIR, wav),
                            channel=channel, frame_start=start)
    if dur:
        s.frame_final_duration = dur
    s.volume = volume
    return s

add_strip("SIG_snd_hum", "sig_transformer_hum.wav", 1, CH["hum"], 240, 0.80)
add_strip("SIG_snd_whine", "sig_crt_whine.wav", 1, CH["whine"], 240, 0.30)
add_strip("SIG_snd_click_on", "sig_relay_click.wav", 2, CH["click"], volume=1.0)
add_strip("SIG_snd_static", "sig_static_filtered.wav", 48, CH["click"], 97, 0.95)
add_strip("SIG_snd_click_lock", "sig_relay_click.wav", 145, CH["click"], volume=1.0)
add_strip("SIG_snd_beep", "sig_beep_880.wav", 145, CH["beep"], volume=0.9)
add_strip("SIG_snd_click_alert", "sig_relay_click.wav", 193, CH["click"], volume=1.0)
add_strip("SIG_snd_alarm", "sig_alarm_two_tone.wav", 193, CH["alarm"], 48, 0.85)
add_strip("SIG_snd_click_off", "sig_relay_click.wav", 241, CH["click"], volume=1.0)
add_strip("SIG_snd_shutdown", "sig_station_turnoff.wav", 241, CH["hum"], 34, 1.0)
# EMF proximity beeps (rate suggested by needle deflection, one every 12 frames)
for f in range(60, 241, 12):
    add_strip("SIG_snd_emf_%03d" % f, "sig_beep_880.wav", f, 6, 6, 0.18)

# --------------------------------------------------------------------------- render settings
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 960
scene.render.resolution_y = 540
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.film_transparent = False
try:
    scene.eevee.taa_render_samples = 48
except Exception:
    pass
scene.view_settings.view_transform = 'AgX'
try:
    scene.view_settings.look = 'AgX - Medium High Contrast'
except Exception:
    pass
scene.view_settings.exposure = -0.2

# --------------------------------------------------------------------------- renders
scene.render.use_sequencer = False
shots = [(28, "01_power_on"), (168, "02_lock"), (215, "03_alert")]
for frame, label in shots:
    scene.frame_set(frame)
    scene.render.filepath = os.path.join(RENDER_DIR, label + ".png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED", label, "frame", frame, "->", scene.render.filepath)
# extra shot: both devices
cam2_data = bpy.data.cameras.new("SIG_camera_wide")
cam2 = bpy.data.objects.new("SIG_camera_wide", cam2_data)
COLS["RIG"].objects.link(cam2)
cam2.location = (1.95, -2.50, 1.55)
look_at(cam2, (0.25, 0, 0.40))
cam2_data.lens = 42
scene.camera = cam2
scene.frame_set(168)
scene.render.filepath = os.path.join(RENDER_DIR, "04_emf_meter.png")
bpy.ops.render.render(write_still=True)
print("RENDERED 04_emf_meter frame 168")
scene.camera = cam
scene.render.use_sequencer = True
scene.frame_set(1)

# --------------------------------------------------------------------------- bbox report + save
def bounds(objects):
    mn = [1e9] * 3
    mx = [-1e9] * 3
    for ob in objects:
        if ob.type != 'MESH':
            continue
        for corner in ob.bound_box:
            w = ob.matrix_world @ Vector(corner)
            for i in range(3):
                mn[i] = min(mn[i], w[i])
                mx[i] = max(mx[i], w[i])
    return mn, mx

console_objs = [o for o in bpy.data.objects if o.name.startswith("SIG_") and
                not o.name.startswith("SIG_emf")]
cmn, cmx = bounds(console_objs)
print("CONSOLE BBOX min", [round(v, 3) for v in cmn], "max", [round(v, 3) for v in cmx],
      "size", [round(cmx[i] - cmn[i], 3) for i in range(3)])
allmn, allmx = bounds(list(bpy.data.objects))
print("SCENE BBOX min", [round(v, 3) for v in allmn], "max", [round(v, 3) for v in allmx],
      "size", [round(allmx[i] - allmn[i], 3) for i in range(3)])
print("ACTION", ACTION.name, "slots", len(ACTION.slots), "objects", len(bpy.data.objects))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "signal_console.blend"))
print("SAVED", os.path.join(ROOT, "signal_console.blend"))
