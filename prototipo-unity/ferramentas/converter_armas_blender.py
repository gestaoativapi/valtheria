import bpy, os
C = "/home/claude/valtheria/cliente-godot/assets/"
OUT = "/home/claude/unity_v38/out/Armas/"
def limpa(): bpy.ops.wm.read_factory_settings(use_empty=True)
for src, nome in [(C+"armas/escudo_ng.glb","escudo"), (C+"armas/machado_ng.glb","machado"), (C+"chars/w_dagger.glb","adaga")]:
    limpa()
    bpy.ops.import_scene.gltf(filepath=src)
    for o in list(bpy.data.objects):
        if o.type not in ('MESH','EMPTY'): bpy.data.objects.remove(o, do_unlink=True)
    os.makedirs(OUT+"Texturas", exist_ok=True)
    for im in bpy.data.images:
        if im.size[0] == 0: continue
        n = nome + "_" + "".join(ch if ch.isalnum() else "_" for ch in im.name.rsplit(".",1)[0]) + ".png"
        im.filepath_raw = OUT + "Texturas/" + n; im.file_format = 'PNG'; im.save()
    for m in bpy.data.materials:
        print(nome, "MAT", m.name, [ (n.type, n.image.name if getattr(n,'image',None) else None) for n in (m.node_tree.nodes if m.use_nodes else [])][:6])
        if m.use_nodes:
            for n in m.node_tree.nodes:
                if n.type == 'BSDF_PRINCIPLED':
                    print(nome, "COR", m.name, tuple(round(x,3) for x in n.inputs['Base Color'].default_value))
    bpy.ops.export_scene.fbx(filepath=OUT + nome + ".fbx", path_mode='RELATIVE', embed_textures=False, apply_scale_options='FBX_SCALE_ALL', axis_forward='-Z', axis_up='Y', bake_space_transform=True, object_types={'MESH','EMPTY'})
    print("OK", nome, [o.name for o in bpy.data.objects])
