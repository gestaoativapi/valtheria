# Prancha frente/lado/costas de um ou mais .glb (Blender, Workbench com textura; sem efeito de luz de jogo)
import bpy, math, sys
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
saida, arquivos = args[0], args[1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
for i, f in enumerate(arquivos):
    bpy.ops.import_scene.gltf(filepath=f)
    for o in bpy.context.selected_objects:
        if o.parent is None: o.location.x += (i - (len(arquivos) - 1) / 2) * 0.9
sc = bpy.context.scene
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = 'ORTHO'; cam.data.ortho_scale = max(2.1, 0.95 * len(arquivos) + 0.4)
sc.render.engine = 'BLENDER_WORKBENCH'; sc.display.shading.color_type = 'TEXTURE'; sc.display.shading.light = 'STUDIO'
sc.display.shading.show_cavity = True
sc.render.resolution_x, sc.render.resolution_y = int(520 * max(1, len(arquivos) * 0.9)), 1000
sc.render.film_transparent = False
import os
outs = []
for nome, rot in [("costas", 180), ("lado", 90), ("frente", 0)]:
    a = math.radians(rot)
    cam.location = (4 * math.sin(a), -4 * math.cos(a), 0.92); cam.rotation_euler = (math.radians(90), 0, a)
    p = f"{saida}_{nome}.png"; sc.render.filepath = p; bpy.ops.render.render(write_still=True); outs.append(p)
print("PRANCHAS", outs)
