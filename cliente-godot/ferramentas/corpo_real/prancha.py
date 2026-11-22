"""Prancha de proporções (frente e perfil) dos corpos gerados, renderizada no Blender (bpy, Cycles em CPU).
Uso: python3 prancha.py <pasta_objs> <saida.png> <m|f>"""
import bpy, sys, os, math
pasta, saida, gen = sys.argv[1], sys.argv[2], sys.argv[3]
bpy.ops.wm.read_factory_settings(use_empty=True)
cena = bpy.context.scene
cena.render.engine = "CYCLES"
cena.cycles.device = "CPU"
cena.cycles.samples = 24
cena.render.resolution_x, cena.render.resolution_y = 1800, 900
cena.render.film_transparent = False
mundo = bpy.data.worlds.new("w"); cena.world = mundo
mundo.use_nodes = True
mundo.node_tree.nodes["Background"].inputs[0].default_value = (0.16, 0.17, 0.2, 1)
mundo.node_tree.nodes["Background"].inputs[1].default_value = 0.6
pele = bpy.data.materials.new("pele"); pele.use_nodes = True
b = pele.node_tree.nodes["Principled BSDF"]
b.inputs["Base Color"].default_value = (0.82, 0.62, 0.5, 1)
b.inputs["Roughness"].default_value = 0.55
racas = ["anao", "humano", "elfo", "sombrio", "orc", "gigante"]
x = -6.0
for r in racas:
    for vista in (0, 1):
        bpy.ops.wm.obj_import(filepath=os.path.join(pasta, f"{r}_{gen}.obj"), forward_axis="NEGATIVE_Z", up_axis="Y")
        ob = bpy.context.selected_objects[0]
        ob.data.materials.append(pele)
        for p in ob.data.polygons: p.use_smooth = True
        ob.location = (x, 0, 0)
        ob.rotation_euler[2] = math.radians(90) if vista else 0.0   # mantém a rotação de eixo do importador (Y para cima)
        x += 0.95 if vista == 0 else 1.25
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cena.collection.objects.link(cam); cena.camera = cam
cam.data.type = "ORTHO"; cam.data.ortho_scale = 13.0
cx = (-6.0 + x - 1.25) / 2
cam.location = (cx, -20, 1.15); cam.rotation_euler = (math.radians(90), 0, 0)
sol = bpy.data.objects.new("sol", bpy.data.lights.new("sol", "SUN"))
sol.data.energy = 3.0; sol.rotation_euler = (math.radians(55), math.radians(-20), math.radians(-30))
cena.collection.objects.link(sol)
chao = bpy.data.lights.new("fill", "SUN"); chao.energy = 0.8
f = bpy.data.objects.new("fill", chao); f.rotation_euler = (math.radians(70), 0, math.radians(150)); cena.collection.objects.link(f)
cena.render.filepath = saida
bpy.ops.render.render(write_still=True)
print("ok", saida)
