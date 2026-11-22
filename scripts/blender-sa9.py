"""Genera la máquina SA-9 (analizador de espectro) y exporta el GLB del juego.

Convenciones (ASSETS): 1 unidad = 1 m, Z arriba en Blender, frente hacia +Y.
El exportador glTF convierte a Y arriba y frente -Z, que es lo que espera el juego.
Origen de la máquina: suelo, centro de la huella.

Piezas móviles separadas, con nombres del manifiesto:
    knob_frequency    eje Y de Blender (Z en glTF) -> gira con rotation.z
    button_isolate    eje Z de Blender (Y en glTF) -> baja con position.y
    display_spectrum  pantalla de fósforo emisiva

Uso con BlenderMCP en 9876:
    python scripts/blender_mcp.py execute_code \
      "exec(open(r'<repo>/scripts/blender-sa9.py', encoding='utf-8').read())"
"""

from __future__ import annotations

import math
import os
from pathlib import Path

import bpy
from mathutils import Euler, Matrix, Vector

ROOT = Path(os.environ.get("ESTATICA_ROOT", Path.cwd()))
BLEND_PATH = ROOT / "blender" / "sa9-spectrum.blend"
GLB_PATH = ROOT / "public" / "assets" / "machines" / "sa9-spectrum.glb"

# ---------- cotas compartidas ----------
CAB_W = 1.16
CAB_D = 0.84
CAB_TOP = 0.65
PLINTH_H = 0.09
DECK_TILT = math.radians(16.0)
DECK_THICK = 0.06
DECK_Z = 0.818
HOOD_W = 1.12
HOOD_D = 0.29
HOOD_FRONT = -0.14
HOOD_BOTTOM = 0.87
HOOD_TOP = 1.34
SCREEN_Z = 1.13

TAN = math.tan(DECK_TILT)
SIN = math.sin(DECK_TILT)
COS = math.cos(DECK_TILT)
DECK_NORMAL = Vector((0.0, SIN, COS))
DECK_SLOPE = Vector((0.0, COS, -SIN))

MATERIALS = {
    "cabinet": dict(color=(0.235, 0.215, 0.170, 1.0), metallic=0.0, roughness=0.72),
    "metal": dict(color=(0.042, 0.046, 0.048, 1.0), metallic=0.9, roughness=0.36),
    "control": dict(color=(0.160, 0.045, 0.018, 1.0), metallic=0.0, roughness=0.45),
    "screen": dict(
        color=(0.008, 0.016, 0.014, 1.0),
        metallic=0.0,
        roughness=0.22,
        emission=(0.22, 0.95, 0.70, 1.0),
        emission_strength=1.7,
    ),
}


def deck_point(x: float, along: float, lift: float = 0.0) -> Vector:
    """Punto sobre la cubierta; `along` es la distancia por la pendiente desde el centro."""
    return (
        Vector((x, 0.0, DECK_Z))
        + DECK_SLOPE * along
        + DECK_NORMAL * lift
    )


class Builder:
    """Acumula primitivas con su índice de material."""

    def __init__(self) -> None:
        self.verts: list[tuple[float, float, float]] = []
        self.faces: list[tuple[int, ...]] = []
        self.mats: list[str] = []

    def _push(self, verts, faces, mat: str) -> None:
        base = len(self.verts)
        self.verts.extend(tuple(v) for v in verts)
        for face in faces:
            self.faces.append(tuple(base + i for i in face))
            self.mats.append(mat)

    def box(
        self,
        size: tuple[float, float, float],
        loc: tuple[float, float, float],
        mat: str,
        rot: tuple[float, float, float] = (0.0, 0.0, 0.0),
    ) -> None:
        sx, sy, sz = (s / 2.0 for s in size)
        corners = [
            (-sx, -sy, -sz),
            (sx, -sy, -sz),
            (sx, sy, -sz),
            (-sx, sy, -sz),
            (-sx, -sy, sz),
            (sx, -sy, sz),
            (sx, sy, sz),
            (-sx, sy, sz),
        ]
        matrix = Matrix.Translation(Vector(loc)) @ Euler(rot, "XYZ").to_matrix().to_4x4()
        faces = [
            (0, 3, 2, 1),
            (4, 5, 6, 7),
            (1, 2, 6, 5),
            (0, 4, 7, 3),
            (2, 3, 7, 6),
            (0, 1, 5, 4),
        ]
        self._push([matrix @ Vector(c) for c in corners], faces, mat)

    def cyl(
        self,
        radius: float,
        depth: float,
        loc: tuple[float, float, float],
        mat: str,
        rot: tuple[float, float, float] = (0.0, 0.0, 0.0),
        segments: int = 12,
        radius_top: float | None = None,
    ) -> None:
        top = radius if radius_top is None else radius_top
        half = depth / 2.0
        verts: list[Vector] = []
        for z, r in ((-half, radius), (half, top)):
            for i in range(segments):
                a = 2.0 * math.pi * i / segments
                verts.append(Vector((r * math.cos(a), r * math.sin(a), z)))
        faces: list[tuple[int, ...]] = []
        for i in range(segments):
            j = (i + 1) % segments
            faces.append((i, j, segments + j, segments + i))
        faces.append(tuple(range(segments - 1, -1, -1)))
        faces.append(tuple(range(segments, segments * 2)))
        matrix = Matrix.Translation(Vector(loc)) @ Euler(rot, "XYZ").to_matrix().to_4x4()
        self._push([matrix @ v for v in verts], faces, mat)

    def prism(self, profile, x0: float, x1: float, mat: str) -> None:
        """Extruye un perfil (y, z) en X; el perfil debe ir en sentido antihorario."""
        count = len(profile)
        verts = [(x0, y, z) for (y, z) in profile] + [(x1, y, z) for (y, z) in profile]
        faces: list[tuple[int, ...]] = []
        faces.append(tuple(range(count - 1, -1, -1)))
        faces.append(tuple(range(count, count * 2)))
        for i in range(count):
            j = (i + 1) % count
            faces.append((i, j, count + j, count + i))
        self._push(verts, faces, mat)

    def deck_box(self, size, x: float, along: float, lift: float, mat: str) -> None:
        """Caja apoyada en la cubierta, alineada con su pendiente."""
        center = deck_point(x, along, lift + size[2] / 2.0)
        self.box(size, tuple(center), mat, rot=(-DECK_TILT, 0.0, 0.0))


def make_material(name: str) -> bpy.types.Material:
    spec = MATERIALS[name]
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = spec["color"]
    bsdf.inputs["Metallic"].default_value = spec["metallic"]
    bsdf.inputs["Roughness"].default_value = spec["roughness"]
    emission = spec.get("emission")
    if emission:
        socket = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        if socket:
            socket.default_value = emission
        strength = bsdf.inputs.get("Emission Strength")
        if strength:
            strength.default_value = spec.get("emission_strength", 1.0)
    return mat


def make_object(
    name: str,
    builder: Builder,
    location: Vector = Vector((0.0, 0.0, 0.0)),
    parent: bpy.types.Object | None = None,
    props: dict | None = None,
) -> bpy.types.Object:
    used = sorted(set(builder.mats), key=lambda key: list(MATERIALS).index(key))
    slots = {key: index for index, key in enumerate(used)}
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(builder.verts, [], builder.faces)
    mesh.validate(verbose=False)
    mesh.update()
    for key in used:
        mesh.materials.append(bpy.data.materials[key])
    for poly, key in zip(mesh.polygons, builder.mats):
        poly.material_index = slots[key]
    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    bpy.context.scene.collection.objects.link(obj)
    if parent:
        obj.parent = parent
        obj.matrix_parent_inverse = parent.matrix_world.inverted()
    for key, value in (props or {}).items():
        obj[key] = value
    return obj


# ---------- limpieza de la escena de arranque ----------
for stale in ("Cube", "Light", "Camera", "CAM_SA9", "KEY_SA9", "FILL_SA9_SIDE"):
    obj = bpy.data.objects.get(stale)
    if obj:
        bpy.data.objects.remove(obj, do_unlink=True)
for stale in ("sa9_spectrum", "sa9_body", "knob_frequency", "button_isolate", "display_spectrum"):
    obj = bpy.data.objects.get(stale)
    if obj:
        bpy.data.objects.remove(obj, do_unlink=True)

for mesh in list(bpy.data.meshes):
    if mesh.users == 0:
        bpy.data.meshes.remove(mesh)

for key in MATERIALS:
    make_material(key)

bpy.context.scene.unit_settings.system = "METRIC"
bpy.context.scene.unit_settings.scale_length = 1.0

root = bpy.data.objects.new("sa9_spectrum", None)
root.empty_display_type = "PLAIN_AXES"
root.empty_display_size = 0.3
bpy.context.scene.collection.objects.link(root)
root["asset_id"] = "sa9-spectrum"
root["asset_kind"] = "machine"
root["units"] = "meters"
root["forward"] = "-Y in Blender / -Z in glTF"

body = Builder()

# ---------- zócalo y patas ----------
body.box((CAB_W, CAB_D, PLINTH_H), (0.0, 0.0, PLINTH_H / 2.0), "metal")
body.box((CAB_W - 0.06, CAB_D - 0.06, 0.02), (0.0, 0.0, PLINTH_H), "metal")
for sx in (-1, 1):
    for sy in (-1, 1):
        body.box((0.14, 0.14, 0.04), (sx * 0.47, sy * 0.33, 0.02), "metal")

# ---------- chasis ----------
body.box(
    (CAB_W, CAB_D, CAB_TOP - PLINTH_H),
    (0.0, 0.0, (CAB_TOP + PLINTH_H) / 2.0),
    "cabinet",
)
for sx in (-1, 1):
    for sy in (-1, 1):
        body.box((0.05, 0.05, CAB_TOP - PLINTH_H - 0.02), (sx * 0.555, sy * 0.395, 0.37), "metal")

# Puerta frontal con rejilla y manilla
body.box((0.74, 0.02, 0.38), (0.10, 0.425, 0.34), "metal")
for i in range(5):
    body.box((0.44, 0.014, 0.018), (0.10, 0.438, 0.17 + i * 0.045), "metal")
body.box((0.04, 0.04, 0.20), (0.505, 0.445, 0.34), "metal")
for z in (0.27, 0.41):
    body.box((0.05, 0.03, 0.03), (0.505, 0.44, z), "metal")
body.box((0.14, 0.012, 0.08), (-0.42, 0.428, 0.50), "control")

# Rejillas laterales y asas
for sx in (-1, 1):
    for i in range(7):
        body.box((0.018, 0.30, 0.02), (sx * 0.582, 0.0, 0.24 + i * 0.05), "metal")
    body.cyl(0.018, 0.18, (sx * 0.60, 0.0, 0.55), "metal", rot=(math.pi / 2, 0.0, 0.0), segments=10)
    for y in (-0.09, 0.09):
        body.box((0.05, 0.03, 0.04), (sx * 0.59, y, 0.55), "metal")

# Panel trasero con conectores BNC
body.box((1.06, 0.02, 0.44), (0.0, -0.428, 0.40), "metal")
for x in (-0.30, 0.30):
    body.cyl(0.028, 0.04, (x, -0.446, 0.46), "metal", rot=(math.pi / 2, 0.0, 0.0), segments=10)
    body.cyl(0.016, 0.05, (x, -0.452, 0.46), "metal", rot=(math.pi / 2, 0.0, 0.0), segments=10)

# ---------- cubierta inclinada ----------
body.box((CAB_W, CAB_D + 0.02, DECK_THICK), (0.0, 0.0, DECK_Z), "cabinet", rot=(-DECK_TILT, 0.0, 0.0))
body.box((CAB_W, 0.05, 0.05), (0.0, 0.425, 0.70), "metal", rot=(-DECK_TILT, 0.0, 0.0))
cheek = [(-0.42, CAB_TOP), (0.42, CAB_TOP), (0.42, 0.6635), (-0.42, 0.9101)]
for x0, x1 in ((-0.575, -0.545), (0.545, 0.575)):
    body.prism(cheek, x0, x1, "cabinet")

# ---------- cabezal con CRT ----------
body.box((HOOD_W, HOOD_D, HOOD_TOP - HOOD_BOTTOM), (0.0, HOOD_FRONT - HOOD_D / 2.0, (HOOD_TOP + HOOD_BOTTOM) / 2.0), "cabinet")
body.box((HOOD_W + 0.02, HOOD_D + 0.02, 0.025), (0.0, HOOD_FRONT - HOOD_D / 2.0, HOOD_TOP + 0.012), "metal")
for sx in (-1, 1):
    for i in range(4):
        body.box((0.018, 0.18, 0.016), (sx * 0.566, HOOD_FRONT - HOOD_D / 2.0, 0.965 + i * 0.03), "metal")

# Bisel de la pantalla
body.box((0.80, 0.04, 0.05), (0.0, HOOD_FRONT + 0.005, SCREEN_Z + 0.165), "metal")
body.box((0.80, 0.04, 0.05), (0.0, HOOD_FRONT + 0.005, SCREEN_Z - 0.165), "metal")
for sx in (-1, 1):
    body.box((0.05, 0.04, 0.38), (sx * 0.375, HOOD_FRONT + 0.005, SCREEN_Z), "metal")
body.box((0.70, 0.02, 0.30), (0.0, HOOD_FRONT - 0.012, SCREEN_Z), "metal")
# Tira de LEDs bajo el bisel
body.box((0.44, 0.014, 0.016), (0.0, HOOD_FRONT + 0.02, 0.915), "screen")
# Placa de identificación del cabezal
body.box((0.30, 0.012, 0.04), (0.0, HOOD_FRONT + 0.012, 1.31), "control")

# ---------- panel de control sobre la cubierta ----------
body.deck_box((0.94, 0.42, 0.02), 0.0, 0.09, 0.0, "metal")
for sx in (-1, 1):
    for along in (-0.14, 0.32):
        screw = deck_point(sx * 0.44, along, 0.03)
        body.cyl(0.009, 0.012, tuple(screw), "metal", rot=(-DECK_TILT, 0.0, 0.0), segments=8)

# Mandos pequeños decorativos y palanca (estáticos)
for x, along, radius in ((-0.02, 0.0, 0.045), (0.12, 0.0, 0.045)):
    center = deck_point(x, along, 0.028)
    body.cyl(radius, 0.045, tuple(center), "control", rot=(-DECK_TILT, 0.0, 0.0), segments=14)
    body.cyl(0.012, 0.02, tuple(deck_point(x, along, 0.06)), "control", rot=(-DECK_TILT, 0.0, 0.0), segments=8)
toggle = deck_point(-0.02, 0.22, 0.03)
body.cyl(0.026, 0.02, tuple(toggle), "metal", rot=(-DECK_TILT, 0.0, 0.0), segments=10)
body.box((0.016, 0.05, 0.05), tuple(toggle + Vector((0.0, 0.008, 0.035))), "control", rot=(-DECK_TILT, 0.0, 0.0))
# Etiquetas en relieve
for x in (-0.30, 0.15, 0.33):
    body.deck_box((0.16, 0.012, 0.006), x, 0.24, 0.0, "metal")

sa9_body = make_object("sa9_body", body, parent=root, props={"kind": "static"})

# ---------- perilla de frecuencia (móvil, eje Z en glTF) ----------
knob = Builder()
knob.cyl(0.085, 0.062, (0.0, 0.0, 0.0), "control", rot=(math.pi / 2, 0.0, 0.0), segments=20)
knob.cyl(0.030, 0.075, (0.0, 0.0, 0.0), "control", rot=(math.pi / 2, 0.0, 0.0), segments=12)
knob.box((0.018, 0.016, 0.05), (0.0, 0.038, 0.058), "control")
for i in range(12):
    angle = 2.0 * math.pi * i / 12.0
    knob.box(
        (0.018, 0.052, 0.012),
        (0.086 * math.sin(angle), 0.0, 0.086 * math.cos(angle)),
        "control",
        rot=(0.0, angle, 0.0),
    )
knob_center = deck_point(-0.30, 0.05, 0.072)
knob_obj = make_object(
    "knob_frequency",
    knob,
    location=knob_center,
    parent=root,
    props={"kind": "knob", "axis": "z", "range_mhz": [1255, 1675]},
)

# ---------- pulsador de aislamiento (móvil, baja en Y) ----------
button = Builder()
button.cyl(0.050, 0.058, (0.0, 0.0, 0.0), "control", segments=16, radius_top=0.056)
button.cyl(0.030, 0.066, (0.0, 0.0, 0.0), "control", segments=12, radius_top=0.034)
button_center = deck_point(0.33, 0.05, 0.029)
button_obj = make_object(
    "button_isolate",
    button,
    location=button_center,
    parent=root,
    props={"kind": "button", "press_axis": "y"},
)

# ---------- pantalla de espectro ----------
screen = Builder()
screen.box((0.66, 0.02, 0.28), (0.0, 0.0, 0.0), "screen")
screen_obj = make_object(
    "display_spectrum",
    screen,
    location=Vector((0.0, HOOD_FRONT + 0.008, SCREEN_Z)),
    parent=root,
    props={"kind": "display", "resolution": [512, 218]},
)

# ---------- cámara y luces de revisión ----------
camera = bpy.data.objects.new("CAM_SA9", bpy.data.cameras.new("CAM_SA9"))
camera.location = (2.15, 2.75, 1.72)
direction = Vector((0.0, 0.02, 0.82)) - camera.location
camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
camera.data.lens = 50
bpy.context.scene.collection.objects.link(camera)
bpy.context.scene.camera = camera

key = bpy.data.objects.new("KEY_SA9", bpy.data.lights.new("KEY_SA9", "AREA"))
key.data.energy = 420
key.data.size = 3.0
key.location = (2.4, 2.6, 2.9)
key.rotation_euler = (Vector((0.0, 0.0, 0.8)) - key.location).to_track_quat("-Z", "Y").to_euler()
bpy.context.scene.collection.objects.link(key)

fill = bpy.data.objects.new("FILL_SA9_SIDE", bpy.data.lights.new("FILL_SA9_SIDE", "AREA"))
fill.data.energy = 160
fill.data.size = 2.4
fill.location = (-2.8, 1.4, 1.6)
fill.rotation_euler = (Vector((0.0, 0.0, 0.9)) - fill.location).to_track_quat("-Z", "Y").to_euler()
bpy.context.scene.collection.objects.link(fill)

world = bpy.context.scene.world or bpy.data.worlds.new("World")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.018, 0.020, 0.024, 1.0)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
bpy.context.scene.world = world

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in {
    item.identifier for item in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items
} else "BLENDER_EEVEE"
scene.render.resolution_x = 1280
scene.render.resolution_y = 960

# Vista 3D centrada en la máquina
for area in bpy.context.screen.areas if bpy.context.screen else ():
    if area.type == "VIEW_3D":
        for space in area.spaces:
            if space.type == "VIEW_3D":
                space.region_3d.view_location = (0.0, 0.0, 0.8)
                space.region_3d.view_distance = 3.2

# ---------- guardado y exportación ----------
bpy.context.view_layer.update()
for obj in bpy.data.objects:
    obj.select_set(False)
for obj in bpy.data.objects:
    if obj is root or obj.parent is root:
        obj.select_set(True)
bpy.context.view_layer.objects.active = root

BLEND_PATH.parent.mkdir(parents=True, exist_ok=True)
GLB_PATH.parent.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
bpy.ops.export_scene.gltf(
    filepath=str(GLB_PATH),
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_yup=True,
    export_extras=True,
    export_cameras=False,
    export_lights=False,
)

triangles = sum(len(mesh.polygons) for mesh in bpy.data.meshes if mesh.users)
print("SA9_OK")
print("blend:", BLEND_PATH)
print("glb:", GLB_PATH)
print("objects:", [obj.name for obj in bpy.data.objects if obj is root or obj.parent is root])
print("materials:", [mat.name for mat in bpy.data.materials if mat.name in MATERIALS])
print("faces (ngons):", triangles)
print("body_faces:", len(sa9_body.data.polygons))
print("knob_at:", tuple(round(v, 3) for v in knob_obj.location))
print("button_at:", tuple(round(v, 3) for v in button_obj.location))
print("screen_at:", tuple(round(v, 3) for v in screen_obj.location))
print("glb_bytes:", GLB_PATH.stat().st_size)
for obj in (sa9_body, knob_obj, button_obj, screen_obj):
    bm = __import__("bmesh").new()
    bm.from_mesh(obj.data)
    print("volume", obj.name, round(bm.calc_volume(signed=True), 5))
    bm.free()
