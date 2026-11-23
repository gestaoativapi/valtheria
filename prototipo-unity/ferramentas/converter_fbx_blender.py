import bpy, os
C = "/home/claude/valtheria/cliente-godot/assets/"
OUT = "/home/claude/unity_proto/out/Modelos/"
def limpa(): bpy.ops.wm.read_factory_settings(use_empty=True)
def imp(f):
    antes = set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=f)
    return [o for o in bpy.data.objects if o not in antes]
def png(pasta):
    os.makedirs(pasta, exist_ok=True)
    for im in bpy.data.images:
        if im.size[0] == 0: continue
        nome = "".join(ch if ch.isalnum() or ch in "_-" else "_" for ch in im.name.rsplit(".",1)[0]) + ".png"
        im.filepath_raw = pasta + nome; im.file_format = 'PNG'; im.save()
def exp(f, anim, todas=False):
    png(OUT + "Texturas/")
    bpy.ops.export_scene.fbx(filepath=f, path_mode='RELATIVE', embed_textures=False, add_leaf_bones=False,
        bake_anim=anim, bake_anim_use_all_actions=todas, bake_anim_use_nla_strips=anim and not todas, bake_anim_force_startend_keying=True,
        apply_scale_options='FBX_SCALE_ALL', axis_forward='-Z', axis_up='Y')

# 1) cavaleiro: cabeça/mãos + armadura de cavaleiro no mesmo esqueleto, com as animações
limpa()
corpo = imp(C + "chars/body_male_knight.glb")
arm = [o for o in corpo if o.type == 'ARMATURE'][0]
roupa = imp(C + "chars/outfit_male_knight.glb")
for o in roupa:
    if o.type == 'MESH' and o.name.startswith("Male_Knight"):
        for m in o.modifiers:
            if m.type == 'ARMATURE': m.object = arm
        mw = o.matrix_world.copy(); o.parent = arm; o.matrix_world = mw
for o in list(bpy.data.objects):
    if o.type == 'ARMATURE' and o != arm: bpy.data.objects.remove(o, do_unlink=True)
for o in list(bpy.data.objects):
    if o.type == 'MESH' and (o.name.startswith("Icosphere") or o.parent is None): bpy.data.objects.remove(o, do_unlink=True)
# textura da sobreveste com o brasão humano (a mesma do jogo)
for im in bpy.data.images:
    if im.name.startswith("T_Knight_BaseColor"):
        im.filepath = C + "chars/knight_brasao_humano.webp"; im.reload()
for o in bpy.data.objects:
    if o.animation_data: o.animation_data_clear()
for a in list(bpy.data.actions): bpy.data.actions.remove(a)
QUERO = ["Idle","Walk","Jog_Fwd","Sprint","Sword_Attack","Sword_Regular_A","Sword_Regular_B","Sword_Regular_C","Hit_Chest","Hit_Head","Death01","Sword_Idle","Roll","Sword_Dash"]
for f in ["/home/claude/dl_ual/UAL1_Standard.glb", "/home/claude/dl_ual/UAL2_Standard.glb"]:
    for o in imp(f): bpy.data.objects.remove(o, do_unlink=True)
acts = {}
for a in bpy.data.actions:
    nome = a.name.split("|")[-1].replace("_Loop", "")
    if nome in QUERO and nome not in acts: acts[nome] = a
arm.animation_data_create()
for nome, a in acts.items():
    a.name = nome
    tr = arm.animation_data.nla_tracks.new(); tr.name = nome
    st = tr.strips.new(nome, int(a.frame_range[0]), a); st.name = nome
arm.animation_data.action = None
print("CAVALEIRO", sorted(acts), [o.name for o in bpy.data.objects])
exp(OUT + "cavaleiro.fbx", True)

# 2) lobisomem
limpa(); obs = imp(C + "monstros/werewolf.glb")
for o in list(bpy.data.objects):
    if o.type == 'MESH' and o.name.startswith("Icosphere"): bpy.data.objects.remove(o, do_unlink=True)
import mathutils
arm_l = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
alt = max((arm_l.matrix_world @ mathutils.Vector(c))[2] for o in bpy.data.objects if o.type == 'MESH' for c in o.bound_box)
print("LOBO_ALTURA", alt)
print("LOBO", [a.name for a in bpy.data.actions])
exp(OUT + "lobisomem.fbx", True, todas=True)
# 3) espada
limpa(); imp(C + "chars/w_sword.glb"); exp(OUT + "espada.fbx", False)
