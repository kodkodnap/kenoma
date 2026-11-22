"""Export the signal console to a clean, batched GLB for Godot (Kenoma)."""
import bpy
from pathlib import Path


root = Path(bpy.data.filepath).resolve().parent.parent
target = root / "godot" / "assets" / "models" / "signal-processing-console.glb"

# Literal VotV screens and texts are regenerated inside Godot.
for obj in list(bpy.data.objects):
    if obj.name.startswith("SIG_crt_screen") or obj.type == "FONT":
        bpy.data.objects.remove(obj, do_unlink=True)

# Keep the alignment anchors as empty nodes: Godot finds them by name.
anchor_names = ("SIG_dial_freq", "SIG_jog_tune", "SIG_slot_housing", "SIG_crt_bezel")
anchors = {}
for name in anchor_names:
    obj = bpy.data.objects.get(name)
    if obj is None:
        print("ALIGN MISSING", name)
        continue
    anchors[name] = obj.matrix_world.copy()
    bpy.data.objects.remove(obj, do_unlink=True)
    empty = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(empty)
    empty.matrix_world = anchors[name]
    print("ALIGN", name, tuple(round(v, 4) for v in empty.matrix_world.translation))

# One mesh per material set keeps the draw-call budget (~15 instead of ~74).
groups = {}
for obj in list(bpy.data.objects):
    if obj.type != "MESH":
        continue
    key = tuple(mat.name if mat else "" for mat in obj.data.materials)
    groups.setdefault(key, []).append(obj)

for group in groups.values():
    bpy.ops.object.select_all(action="DESELECT")
    for obj in group:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = group[0]
    bpy.ops.object.join()
    group[0].name = "SIG_batched_%02d" % len(bpy.data.objects)

bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=str(target), export_format="GLB", use_selection=False)
print("EXPORTED", target, "batches", len(groups))
