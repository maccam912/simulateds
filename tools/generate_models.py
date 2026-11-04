#!/usr/bin/env python3
"""Rebuild Linden Grove's original mesh library using Blender 4.2+.

Run: blender --background --python tools/generate_models.py -- [--gallery]
All authoring coordinates use Godot Y-up; front is +Z. No external assets.
"""
from __future__ import annotations
import bpy
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import sys
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'models'
OUT.mkdir(parents=True, exist_ok=True)
random.seed(912)
MATS = {}
MODELS = {}

def vec(p): return Vector((p[0], -p[2], p[1]))

def color(hexcode):
    values = [int(hexcode[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in values) + (1,)

def mat(name, rgb, roughness=.72, metallic=0, emission=0):
    if name in MATS: return MATS[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = color(rgb)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    if emission:
        bsdf.inputs['Emission Color'].default_value = color(rgb)
        bsdf.inputs['Emission Strength'].default_value = emission
    m.diffuse_color = color(rgb); m.use_backface_culling = True; MATS[name] = m
    return m

WOOD = mat('oak', 'a17c58')
DARKWOOD = mat('walnut', '72553e')
CREAM = mat('linen', 'eee7d5')
PORCELAIN = mat('porcelain', 'edece0', .27)
BRASS = mat('brushed_brass', 'c3a573', .38, .55)
METAL = mat('steel', '929f9c', .35, .55)
INK = mat('charcoal', '263d41')
LEAF = mat('leaf', '6b9153')
LEAF_DARK = mat('leaf_dark', '47724b')
LEAF_LIGHT = mat('leaf_light', '93ac64')
SOIL = mat('soil', '63513b')

def custom(name, rgb): return mat('custom_' + name, rgb)

def add_material(obj, material):
    obj.data.materials.clear(); obj.data.materials.append(material)
    return obj

def finish(obj, name, material, bevel=0):
    obj.name = name
    add_material(obj, material)
    if bevel:
        b = obj.modifiers.new('Soft manufactured edge', 'BEVEL'); b.width = bevel; b.segments = 2
        b.affect = 'EDGES'
        n = obj.modifiers.new('Weighted corner normals', 'WEIGHTED_NORMAL'); n.keep_sharp = True
    return obj

def box(name, p, size, material, bevel=.015):
    bpy.ops.mesh.primitive_cube_add(size=1, location=vec(p))
    o = bpy.context.object; o.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, name, material, min(bevel, min(size) * .35))

def ellipsoid(name, p, size, material, segments=16, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=vec(p))
    o = bpy.context.object; o.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for poly in o.data.polygons: poly.use_smooth = True
    return finish(o, name, material)

def cylinder(name, p, radius, depth, material, radius2=None, vertices=16):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=radius if radius2 is None else radius2, depth=depth, location=vec(p))
    o = bpy.context.object
    for poly in o.data.polygons: poly.use_smooth = len(poly.vertices) == 4
    return finish(o, name, material, .004)

def rod(name, a, b, radius, material, vertices=10):
    a, b = vec(a), vec(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=(b-a).length, location=(a+b)*.5)
    o = bpy.context.object; o.rotation_euler = (b-a).to_track_quat('Z', 'Y').to_euler()
    for poly in o.data.polygons: poly.use_smooth = len(poly.vertices) == 4
    return finish(o, name, material, radius*.15)

def torus(name, p, major, minor, material, stretch=(1,1,1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=24, minor_segments=8, location=vec(p))
    o = bpy.context.object; o.scale = (stretch[0], stretch[2], stretch[1])
    for poly in o.data.polygons: poly.use_smooth = True
    return finish(o, name, material)

def leaf(name, start, end, width, material=LEAF):
    a,b = vec(start),vec(end)
    o = ellipsoid(name, (0,0,0), (width, (b-a).length*.54, width*.29), material, 12, 6)
    o.location = (a+b)*.5; o.rotation_euler = (b-a).to_track_quat('Z','Y').to_euler()
    return o

def leg(x,z,height, material=WOOD, y0=.04, radius=.035):
    return rod('Turned leg', (x*1.04,y0,z*1.04), (x,height,z), radius, material, 12)

def clear():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

def merge_meshes():
    """Combine per material, retaining animated children and useful named surfaces."""
    groups = {}
    for o in list(bpy.context.scene.objects):
        if o.type != 'MESH': continue
        key = (o.parent.name if o.parent else '', o.data.materials[0].name)
        groups.setdefault(key,[]).append(o)
    for (parent, material), meshes in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in meshes:
            o.select_set(True); bpy.context.view_layer.objects.active = o
            for modifier in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=modifier.name)
        bpy.context.view_layer.objects.active = meshes[0]
        if len(meshes)>1: bpy.ops.object.join()
        meshes[0].name = material + ('_mesh' if parent else '')
        # Always export clean transforms, but keep the animated pivot origins.
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.context.view_layer.update()

def export(name, footprint, description, animated=False):
    merge_meshes()
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    bpy.context.view_layer.update()
    points=[o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
    minb=[min(p[i] for p in points) for i in range(3)]
    maxb=[max(p[i] for p in points) for i in range(3)]
    triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
    filepath=OUT/(name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(filepath), export_format='GLB', use_selection=False, export_yup=True, export_apply=True, export_cameras=False, export_lights=False, export_animations=False, export_extras=True)
    data=filepath.read_bytes()
    json_length=struct.unpack('<I',data[12:16])[0]
    document=json.loads(data[20:20+json_length])
    assert all('uri' not in buffer for buffer in document['buffers']), name
    if animated:
        expected={'Head','Torso','Arm_L','Arm_R','Leg_L','Leg_R'}
        assert expected <= {node.get('name') for node in document['nodes']}, name
        assert 1.60 < maxb[2] < 1.80, (name,maxb)
    MODELS[name]={'file':name+'.glb','footprint':footprint,'description':description,'triangles':triangles,'meshes':len(meshes),'materials':sorted({m.name for o in meshes for m in o.data.materials}),'bounds':{'min':[round(minb[0],4),round(minb[2],4),round(-maxb[1],4)],'max':[round(maxb[0],4),round(maxb[2],4),round(-minb[1],4)]},'sha256':hashlib.sha256(filepath.read_bytes()).hexdigest(),'animated_pivots':animated}

def build(name, footprint, description, fn, animated=False):
    clear(); fn(); export(name,footprint,description,animated)

def bed():
    wood=custom('bed_frame','947052'); duvet=custom('bedding','8eaaa8')
    # Only bedding takes the user's swatch; frame stays oak.
    wood=WOOD
    for x in [-.37,.37]:
        for z in [-.82,.82]: leg(x,z,.30,DARKWOOD)
    box('Frame',(0,.27,0),(.92,.22,1.92),wood,.025)
    box('Mattress',(0,.43,.01),(.87,.24,1.82),CREAM,.07)
    box('Duvet',(0,.565,.28),(.90,.13,1.21),duvet,.055)
    box('Folded linen edge',(0,.637,-.18),(.89,.025,.26),mat('duvet_fold','bdccc0'),.014)
    for x in [-.26,.0,.26]: box('Quilt stitch',(x,.632,.35),(.006,.004,.97),mat('duvet_stitch','b1c1b4'),.001)
    box('Pillow',(0,.596,-.61),(.69,.13,.36),mat('pillow','f5efdf'),.09)
    box('Pillow seam',(0,.606,-.797),(.55,.009,.006),CREAM,.002)
    box('Headboard',(0,.62,-.925),(.96,.94,.08),wood,.035)
    box('Inset headboard',(0,.72,-.875),(.78,.45,.025),DARKWOOD,.015)
    for x in [-.26,0,.26]: box('Headboard slat',(x,.72,-.856),(.22,.39,.025),wood,.012)
    box('Foot rail',(0,.38,.925),(.96,.3,.07),wood,.018)

def fridge():
    enamel=custom('enamel','d0dfd4')
    for x in [-.29,.29]:
        for z in [-.27,.27]: cylinder('Foot',(x,.035,z),.045,.07,INK)
    box('Body',(0,.87,0),(.78,1.68,.76),enamel,.055)
    box('Lower door',(0,.665,.402),(.735,1.08,.07),enamel,.028)
    box('Freezer door',(0,1.455,.402),(.735,.445,.07),enamel,.028)
    for y in [.97,1.45]:
        for yy in [-.11,.11]: rod('Handle mount',(-.245,y+yy,.44),(-.245,y+yy,.49),.014,METAL)
        rod('Handle',(-.245,y-.12,.49),(-.245,y+.12,.49),.017,METAL)
    box('Vent recess',(0,.13,.435),(.60,.085,.012),INK,.005)
    for x in range(10): box('Vent slat',(-.27+x*.06,.13,.445),(.015,.065,.008),METAL,.002)
    # A small domestic detail that stays legible without writing.
    box('Note',(.13,1.46,.443),(.17,.20,.006),mat('note','f1dfb0'),.002)
    ellipsoid('Magnet',(.13,1.55,.45),(.025,.025,.007),mat('magnet','c78469'),12,6)

def shower():
    panel=custom('wall_panel','9dbfba')
    box('Tray',(0,.075,0),(.94,.15,.94),PORCELAIN,.045)
    box('Tray inset',(0,.155,.02),(.76,.035,.75),mat('shower_floor','d5dfd8'),.04)
    cylinder('Drain',(0,.179,.06),.055,.005,METAL)
    box('Back tiled panel',(0,1.06,-.43),(.90,1.96,.07),panel,.013)
    for x in [-.225,0,.225]: box('Tile grout',(x,1.06,-.389),(.007,1.94,.006),CREAM,.001)
    for y in [.33,.66,.99,1.32,1.65]: box('Tile grout',(0,y,-.389),(.88,.007,.006),CREAM,.001)
    rod('Shower riser',(.19,.72,-.31),(.19,1.85,-.31),.014,METAL)
    rod('Shower neck',(.19,1.85,-.31),(.19,1.85,-.12),.018,METAL)
    cylinder('Shower head',(.19,1.83,-.10),.115,.035,METAL)
    rod('Mixer',(.06,.9,-.33),(.30,.9,-.33),.027,METAL)
    box('Soap shelf',(-.21,.96,-.27),(.20,.04,.18),PORCELAIN,.01)
    box('Soap',(-.21,1.005,-.27),(.11,.055,.075),mat('soap','d7b7a1'),.02)
    # Solid tinted half-screen avoids transparent sorting on mobile.
    glass=mat('frosted_glass','c0d9d5',.28)
    box('Privacy screen',(-.43,1.0,-.15),(.035,1.7,.53),glass,.012)
    for z in [-.43,.12]: rod('Screen post',(-.43,.16,z),(-.43,1.94,z),.016,METAL)
    rod('Screen top',(-.43,1.94,-.43),(-.43,1.94,.12),.018,METAL)

def toilet():
    enamel=custom('porcelain','e8e8dc')
    ellipsoid('Pedestal',(0,.20,.08),(.19,.23,.25),enamel)
    ellipsoid('Bowl',(0,.39,.16),(.28,.16,.34),enamel)
    cylinder('Dark bowl interior',(0,.495,.18),.18,.025,mat('bowl_interior','718c88'),vertices=24).scale.y=1.35
    torus('Seat',(0,.515,.16),.213,.041,enamel,(1,1,1.30))
    box('Cistern',(0,.66,-.27),(.55,.55,.24),enamel,.055)
    box('Tank lid',(0,.95,-.27),(.58,.055,.27),PORCELAIN,.023)
    cylinder('Flush button',(.17,.983,-.27),.026,.007,METAL)
    rod('Water pipe',(0,.2,-.35),(0,.6,-.35),.025,METAL)

def sofa():
    cloth=custom('upholstery','ce9071'); seam=mat('upholstery_piping','e2b18a')
    for x in [-.79,.79]:
        for z in [-.30,.30]: leg(x,z,.21,DARKWOOD,radius=.045)
    box('Lower frame',(0,.29,0),(1.91,.25,.87),cloth,.065)
    box('Back',(0,.64,-.32),(1.86,.75,.23),cloth,.085)
    for x in [-.89,.89]: box('Rolled arm',(x,.56,.02),(.22,.50,.87),cloth,.09)
    for x in [-.42,.42]:
        box('Seat cushion',(x,.485,.07),(.80,.19,.62),cloth,.066)
        box('Seat piping',(x,.475,.387),(.69,.012,.010),seam,.003)
        cushion=box('Back cushion',(x,.735,-.20),(.79,.44,.17),cloth,.07); cushion.rotation_euler.x=math.radians(-7)
    pillow=box('Accent pillow',(-.63,.76,.09),(.32,.34,.16),mat('sofa_pillow','c0cbb0'),.065); pillow.rotation_euler.y=.15; pillow.rotation_euler.z=.18
    box('Throw',( .60,.60,.13),(.28,.045,.65),mat('sofa_throw','ead7b5'),.02)
    box('Throw drape',(.60,.40,.445),(.28,.36,.035),mat('sofa_throw','ead7b5'),.02)
    for x in [.49,.54,.59,.64,.69]: rod('Throw fringe',(x,.22,.46),(x,.18,.46),.006,CREAM,6)

def tv():
    wood=custom('cabinet','957555')
    for x in [-.34,.34]:
        for z in [-.26,.26]: leg(x,z,.25,DARKWOOD)
    box('Console',(0,.34,0),(.89,.24,.69),wood,.025)
    box('Console shelf',(0,.32,.35),(.70,.12,.016),DARKWOOD,.005)
    box('CRT shell',(0,.75,-.025),(.70,.61,.54),INK,.07)
    box('Screen rim',(-.04,.78,.266),(.56,.43,.035),mat('screen_rim','526263'),.045)
    box('Curved screen',(-.04,.78,.291),(.49,.36,.035),mat('screen','93b8aa',.25,.12),.055)
    box('Screen glint',(-.16,.91,.311),(.16,.015,.004),mat('screen_glint','c7d7c1'),.006)
    for y in [.66,.75]:
        knob=cylinder('Tuner',(.28,y,.29),.027,.024,METAL,vertices=12); knob.rotation_euler.x=math.pi/2
    box('Power light',(.28,.57,.288),(.018,.012,.01),mat('indicator','aaca85',.4,0,.15),.003)
    for x in [-.15,.15]: rod('Aerial',(0,1.055,-.03),(x,1.31,-.07),.008,METAL,8)

def stereo():
    wood=custom('cabinet','987758')
    for x in [-.34,.34]:
        for z in [-.22,.22]: leg(x,z,.21,DARKWOOD)
    box('Stand',(0,.23,0),(.92,.12,.64),wood,.018)
    for x in [-.31,.31]:
        box('Speaker cabinet',(x,.56,0),(.255,.54,.45),wood,.018)
        box('Speaker cloth',(x,.56,.235),(.218,.49,.025),INK,.008)
        for y,r in [(.44,.082),(.68,.044)]:
            cone=cylinder('Speaker cone',(x,y,.254),r,.012,mat('speaker_cone','647472'),vertices=20); cone.rotation_euler.x=math.pi/2
            ellipsoid('Speaker cap',(x,y,.265),(r*.36,r*.36,.014),INK,12,6)
    box('Receiver',(0,.44,.02),(.33,.27,.41),mat('hi_fi_metal','526260',.42,.4),.016)
    box('Display',(0,.50,.233),(.16,.045,.01),mat('display','b4cf97',.5,0,.2),.004)
    for x in [-.115,.115]:
        knob=cylinder('Volume',(x,.39,.24),.035,.024,METAL,vertices=16); knob.rotation_euler.x=math.pi/2
    box('Turntable',(0,.61,.01),(.34,.07,.39),INK,.01)
    cylinder('Vinyl',(0,.653,.01),.125,.012,INK,vertices=32)
    cylinder('Record label',(0,.66,.01),.034,.005,mat('record_label','d8b37c'))
    rod('Tonearm',(.14,.68,-.13),(.065,.68,.03),.008,METAL,8)

def easel():
    wood=custom('woodwork','b38961')
    for x in [-.35,.35]: rod('Easel front leg',(x,.02,.28),(x*.30,1.65,-.08),.028,wood,8)
    rod('Easel back leg',(0,.02,-.38),(0,1.55,-.08),.027,wood,8)
    box('Canvas support',(0,.76,.18),(.83,.055,.13),wood,.008)
    box('Mast',(0,1.32,-.03),(.055,.96,.055),wood,.007)
    box('Canvas backing',(0,1.13,.095),(.74,.67,.055),CREAM,.009)
    box('Canvas',(0,1.13,.128),(.69,.62,.012),mat('canvas','f2e9d0'),.002)
    box('Top clamp',(0,1.49,.10),(.17,.06,.10),wood,.01)
    cylinder('Clamp bolt',(0,1.49,.168),.022,.018,BRASS).rotation_euler.x=math.pi/2
    cylinder('Paint jar',(-.29,.82,.17),.035,.09,mat('paint_jar','86a5a2'),vertices=12)
    rod('Brush',(-.29,.83,.17),(-.27,.97,.18),.006,DARKWOOD,6)

def bookshelf():
    wood=custom('woodwork','a27f5c')
    box('Back',(0,.83,-.30),(.82,1.58,.045),DARKWOOD,.008)
    for x in [-.42,.42]: box('Stile',(x,.85,0),(.07,1.70,.65),wood,.018)
    for y in [.11,.59,1.07,1.62]: box('Shelf',(0,y,0),(.87,.065,.65),wood,.014)
    box('Crown',(0,1.7,0),(.96,.08,.71),wood,.017)
    bookcolors=['9caf91','be8972','d7bb84','738f9d','b0a1ba','dfd5b5']
    for row,y in enumerate([.15,.63,1.11]):
        x=-.32
        for i in range(7 if row<2 else 5):
            width=.065+(i%3)*.014; h=.25+((i*5+row*3)%7)*.021
            book=mat('book_'+str(i%6),bookcolors[i%6])
            box('Book cover',(x,y+h/2,.065),(width,h,.38),book,.004)
            box('Book pages',(x,y+h/2,.259),(width*.74,h*.94,.012),CREAM,.002)
            for yy in [y+.035,y+h-.035]: box('Spine band',(x,yy,.268),(width*.8,.008,.004),BRASS,.001)
            x+=width+.017
    box('Book stack',(.22,1.19,.04),(.27,.09,.37),mat('book_3','738f9d'),.006)
    box('Book stack',(.20,1.29,.035),(.29,.09,.38),mat('book_1','be8972'),.006)

def garden_bed():
    wood=custom('frame','957252')
    box('Earth',(0,.22,0),(1.77,.27,.76),SOIL,.012)
    for z in [-.44,.44]:
        for y in [.095,.25]: box('Raised plank',(0,y,z),(1.94,.145,.065),wood,.011)
    for x in [-.94,.94]:
        for y in [.095,.25]: box('End plank',(x,y,0),(.065,.145,.84),wood,.011)
        for z in [-.41,.41]: box('Corner post',(x,.19,z),(.08,.38,.08),wood,.012)
    for z in [-.19,.19]:
        for i in range(13): ellipsoid('Cultivated soil',(-.78+i*.13,.365,z),(.077,.02,.075),SOIL,8,4)
    for x in [-.72,.72]:
        for z in [-.479,.479]:
            for y in [.10,.25]: ellipsoid('Nail',(x,y,z),(.009,.009,.004),METAL,8,4)

def plant():
    pot=custom('pot','bf8767')
    cylinder('Planter',(0,.21,0),.18,.38,pot,radius2=.25,vertices=20)
    torus('Pot rim',(0,.40,0),.237,.025,pot)
    cylinder('Soil',(0,.395,0),.218,.012,SOIL,vertices=20)
    for i in range(8):
        a=i*2.399; h=.60+(i%3)*.13; r=.23+(i%2)*.07
        end=(math.cos(a)*r,h,math.sin(a)*r)
        rod('Leaf stem',(0,.41,0),end,.009,LEAF_DARK,8)
        leaf('Broad leaf',(end[0]*.25,end[1]-.14,end[2]*.25),(end[0]*1.35,end[1]+.10,end[2]*1.35),.105,[LEAF,LEAF_LIGHT,LEAF_DARK][i%3])

def cup(x,y,z):
    cylinder('Cup',(x,y+.035,z),.045,.07,PORCELAIN,radius2=.053,vertices=16)
    cylinder('Tea',(x,y+.072,z),.041,.004,mat('tea','956d39'),vertices=16)
    handle=torus('Cup handle',(x+.06,y+.04,z),.025,.008,PORCELAIN); handle.rotation_euler.x=math.pi/2
    cylinder('Saucer',(x,y-.005,z),.083,.015,PORCELAIN,vertices=20)

def table(kind):
    wood=custom('woodwork','b8946b'); depth=.90 if kind=='table' else 1.83
    height=.66 if kind=='table' else .78
    for x in [-.76,.76]:
        for z in [-depth*.36,depth*.36]: leg(x,z,height-.04,wood,radius=.045)
    box('Apron',(0,height-.13,0),(1.62,.17,depth*.81),wood,.015)
    box('Tabletop',(0,height,0),(1.91,.10,depth),wood,.035)
    if kind=='table':
        box('Runner',(0,height+.057,0),(.43,.015,depth*.98),mat('table_runner','c8c9a4'),.008)
        cup(-.55,height+.067,.13); cup(.55,height+.067,-.13)
        cylinder('Tea pot',(0,height+.15,0),.1,.18,mat('teapot','89a3a0'),radius2=.085,vertices=20)
        cylinder('Lid',(0,height+.245,0),.088,.025,mat('teapot','89a3a0'))
        rod('Spout',(.07,height+.11,0),(.18,height+.21,0),.025,mat('teapot','89a3a0'))
    elif kind=='dining_table':
        box('Table runner',(0,height+.058,0),(.55,.014,1.76),mat('table_runner','c8c9a4'),.007)
        for x,z in [(-.62,0),(.62,0),(0,-.61),(0,.61)]:
            cylinder('Plate',(x,height+.065,z),.17,.018,PORCELAIN,vertices=24)
            torus('Plate rim',(x,height+.076,z),.145,.009,PORCELAIN)
            box('Napkin',(x+.24,height+.06,z),(.12,.008,.23),CREAM,.003)
            rod('Fork',(x-.22,height+.07,z-.09),(x-.22,height+.07,z+.10),.008,METAL,6)
    else:
        box('Board frame',(0,height+.067,0),(1.36,.035,1.36),DARKWOOD,.008)
        boardcolors=[mat('board_dark','648984'),mat('board_light','eee2c7')]
        for x in range(8):
            for z in range(8): box('Checker square',(-.56+x*.16,height+.089,-.56+z*.16),(.16,.009,.16),boardcolors[(x+z)%2],.001)
        for x,z,side in [(-.4,-.4,0),(-.08,-.4,0),(.24,-.4,0),(.40,.40,1),(.08,.40,1),(-.24,.40,1),(.08,.08,1)]:
            disk=mat('piece_red','c88d6d') if side else INK
            cylinder('Playing piece',(x,height+.115,z),.055,.045,disk,vertices=16)
            torus('Piece inset',(x,height+.14,z),.035,.006,disk)

# Vegetation is geometry, with several canopy clusters for soft silhouettes.
def tree_linden():
    bark=mat('bark','80654a')
    cylinder('Trunk',(0,.93,0),.17,1.86,bark,radius2=.095,vertices=12)
    for i in range(6):
        a=i*2.399; x=math.cos(a)*.68; z=math.sin(a)*.68; y=1.7+(i%3)*.32
        rod('Branch',(0,1.1,0),(x,y,z),.055,bark)
        ellipsoid('Canopy',(x,y+.40,z),(.73,.68,.72),[LEAF,LEAF_LIGHT,LEAF_DARK][i%3],12,6)
    ellipsoid('Crown',(0,2.6,0),(.83,.67,.78),LEAF,12,6)
    for a in range(5):
        q=a*math.tau/5; rod('Root',(0,.06,0),(math.cos(q)*.35,.02,math.sin(q)*.35),.05,bark)

def shrub():
    for x,z,y,r in [(-.23,0,.32,.32),(.23,.03,.37,.35),(0,-.12,.50,.36)]:
        ellipsoid('Leaf cluster',(x,y,z),(r,r*.85,r*.8),[LEAF,LEAF_LIGHT,LEAF_DARK][int(y*100)%3],12,6)
    for i in range(7):
        a=i*2.399; x=math.cos(a)*.31; z=math.sin(a)*.24
        ellipsoid('Berry',(x,.45+math.sin(a)*.12,z),(.026,.026,.026),mat('berry','bc7b65'),8,4)

def streetlamp():
    iron=mat('painted_iron','435750',.55,.28)
    cylinder('Foot',(0,.10,0),.16,.20,iron,radius2=.12)
    cylinder('Post',(0,1.27,0),.045,2.4,iron,radius2=.035)
    cylinder('Lantern base',(0,2.48,0),.17,.10,iron,radius2=.14,vertices=4)
    box('Warm lantern',(0,2.70,0),(.22,.36,.22),mat('lamp_glow','f6dfad',.6,0,.35),.015)
    for x in [-.13,.13]:
        for z in [-.13,.13]: rod('Lantern corner',(x,2.49,z),(x,2.9,z),.013,iron,8)
    cylinder('Lantern cap',(0,2.94,0),.24,.14,iron,radius2=.05,vertices=4)
    ellipsoid('Finial',(0,3.05,0),(.035,.055,.035),iron,12,6)

def mailbox():
    cylinder('Mailbox post',(0,.48,0),.06,.96,WOOD,vertices=8)
    box('House mailbox',(0,1.05,0),(.43,.36,.58),mat('mailbox_paint','809c8c'),.105)
    box('Mailbox door',(0,1.055,.298),(.35,.29,.025),mat('mailbox_door','9db3a0'),.075)
    box('Mail slot',(0,1.13,.316),(.20,.019,.008),INK,.003)
    box('Door pull',(0,.97,.337),(.11,.025,.035),BRASS,.006)
    rod('Flag staff',(.23,1.0,-.06),(.23,1.33,-.06),.014,BRASS)
    box('Mail flag',(.23,1.3,.015),(.018,.12,.14),mat('mail_flag','ce8d70'),.008)

def fence():
    paint=mat('fence_paint','ddd6b8')
    for x in [-.48,.48]:
        box('Fence post',(x,.47,0),(.085,.94,.085),paint,.012)
        cylinder('Post cap',(x,.97,0),.070,.06,paint,radius2=0,vertices=4)
    for y in [.31,.69]: box('Rail',(0,y,-.03),(1,.07,.055),paint,.008)
    for x in [-.30,-.10,.10,.30]:
        box('Picket',(x,.45,.025),(.11,.80,.04),paint,.009)
        cylinder('Picket tip',(x,.88,.025),.077,.08,paint,radius2=0,vertices=4)

def flower_patch():
    petals=[mat('flower_cream','ead9aa'),mat('flower_rose','cc8b83')]
    for i in range(9):
        a=i*2.399; r=.12+(.22 if i%2 else 0); x=math.cos(a)*r; z=math.sin(a)*r; h=.19+(i%3)*.07
        rod('Flower stalk',(x,0,z),(x,h,z),.007,LEAF_DARK,6)
        leaf('Leaf',(x,.08,z),(x+.08,.15,z+.025),.035)
        ellipsoid('Flower heart',(x,h,z),(.025,.018,.025),BRASS,8,4)
        for j in range(5):
            b=j*math.tau/5; ellipsoid('Petal',(x+math.cos(b)*.036,h,z+math.sin(b)*.036),(.028,.014,.027),petals[i%2],8,4)

def crop(kind):
    fruit=mat('fruit','c36f51' if kind=='tomato' else 'c17a87')
    h=.65 if kind=='tomato' else .25
    rod('Plant stalk',(0,0,0),(0,h,0),.012,LEAF_DARK,8)
    for i in range(7):
        a=i*2.399; y=.09+(i/7)*h*.83; r=.14+(i%2)*.055
        leaf('Crop leaf',(0,y,0),(math.cos(a)*r,y+.07,math.sin(a)*r),.055,[LEAF,LEAF_LIGHT][i%2])
    if kind=='tomato':
        for i in range(4):
            a=i*2.399; x=math.cos(a)*.11; z=math.sin(a)*.11; y=.19+(i%3)*.13
            ellipsoid('Tomato',(x,y,z),(.065,.061,.065),fruit,12,6)
            for j in range(4):
                b=j*math.pi*.5; leaf('Calyx',(x,y+.052,z),(x+math.cos(b)*.06,y+.06,z+math.sin(b)*.06),.013,LEAF_DARK)
    else:
        ellipsoid('Radish',(0,.04,0),(.095,.10,.095),fruit,12,6)

def window(kind):
    paint=mat('window_frame','e9dfc1') if kind!='picture' else WOOD
    glass=mat('window_glass','a6c8c8',.24,.1)
    width=.84 if kind!='shutters' else .60
    box('Glass',(0,1.39,.035),(width,.85,.035),glass,.008)
    for x in [-width*.5,width*.5]: box('Side casing',(x,1.39,.065),(.065,.98,.09),paint,.008)
    for y in [.92,1.86]: box('Casing',(0,y,.065),(width+.12,.065,.09),paint,.008)
    box('Window sill',(0,.89,.10),(width+.19,.07,.20),paint,.01)
    if kind!='picture':
        box('Mullion',(0,1.39,.085),(.035,.90,.04),paint,.005)
        box('Mullion',(0,1.39,.085),(width,.035,.04),paint,.005)
    if kind=='shutters':
        shutter=mat('shutter','829c86')
        for x in [-.43,.43]:
            box('Shutter',(x,1.39,0),(.18,.92,.05),shutter,.009)
            for y in range(8): box('Louver',(x,1.03+y*.10,.04),(.17,.04,.04),shutter,.004)
    box('Sky glint',(-width*.21,1.68,.059),(width*.27,.019,.008),mat('window_glint','d1ded0'),.004)

def door_frame():
    paint=mat('door_trim','eee4c9')
    for x in [-.46,.46]: box('Door jamb',(x,1.03,0),(.09,2.06,.20),paint,.011)
    box('Lintel',(0,2.06,0),(1,.10,.20),paint,.013)
    box('Threshold',(0,.025,0),(.90,.05,.27),DARKWOOD,.01)
    # An open leaf retains the passage through the one-tile doorway.
    wood=mat('door_wood','9b7955')
    box('Open door',(-.40,1.0,-.36),(.07,1.96,.75),wood,.014)
    for y in [.48,1.37]: box('Raised door panel',(-.355,y,-.36),(.02,.60,.56),wood,.009)
    ellipsoid('Door knob',(-.33,.99,-.67),(.03,.03,.03),BRASS,12,6)


def parent_preserve(obj,parent):
    bpy.context.view_layer.update()
    transform=obj.matrix_world.copy()
    obj.parent=parent; obj.matrix_parent_inverse=Matrix.Identity(4)
    obj.matrix_basis=parent.matrix_world.inverted() @ transform
    bpy.context.view_layer.update()

def pivot(name,p,fn):
    before=set(bpy.context.scene.objects)
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o); o.location=vec(p)
    fn()
    for child in set(bpy.context.scene.objects)-before-{o}:
        if child.parent is None: parent_preserve(child,o)
    return o

def resident(style=0):
    skin=mat('skin','ddb38e'); shirt=mat('shirt','688c8f'); trousers=mat('trousers','53616b'); shoes=mat('shoes','584e43'); hair=mat('hair','655243')
    # Deliberately slightly large head/hands support the distant isometric view.
    body=box('Body',(0,1.02,0),(.39,.47,.25),shirt,.10)
    box('Shirt hem',(0,.813,0),(.37,.045,.255),shirt,.015)
    box('Trousers waist',(0,.765,0),(.34,.15,.235),trousers,.045)
    cylinder('Neck',(0,1.29,0),.075,.15,skin)
    # Collar: two real pieces whose silhouette survives the normal play zoom.
    for side in [-1,1]:
        c=box('Collar',(side*.064,1.245,.128),(.105,.073,.018),CREAM,.012); c.rotation_euler.y=side*.38
    for y in [.99,1.10,1.19]: ellipsoid('Button',(0,y,.134),(.009,.009,.006),CREAM,8,4)
    torso = bpy.data.objects.new('Torso', None); bpy.context.collection.objects.link(torso); torso.location = vec((0,1.02,0))
    for child in list(bpy.context.scene.objects):
        if child.type == 'MESH' and child.parent is None: parent_preserve(child,torso)
    def head():
        ellipsoid('Head',(0,1.49,0),(.175,.215,.158),skin,20,12)
        for x in [-.175,.175]: ellipsoid('Ear',(x,1.48,-.005),(.034,.055,.028),skin,12,6)
        ellipsoid('Nose',(0,1.475,.159),(.032,.039,.041),skin,12,6)
        for x in [-.063,.063]:
            ellipsoid('Eye white',(x,1.515,.146),(.027,.024,.018),CREAM,12,6)
            ellipsoid('Eye',(x,1.515,.162),(.013,.017,.007),INK,10,6)
            rod('Brow',(x-.025,1.554,.151),(x+.025,1.559,.151),.008,hair,6)
        rod('Mouth',(-.033,1.408,.140),(.033,1.408,.140),.006,mat('lips','a96e5e'),8)
        if style==3:
            ellipsoid('Cropped hair',(0,1.634,-.03),(.158,.080,.137),hair,20,8)
        elif style==2:
            for i in range(18):
                a=i*2.399; y=1.58+(i%3)*.045; radius=.13 if i<12 else .075
                ellipsoid('Curl',(math.cos(a)*radius,y,math.sin(a)*radius-.02),(.075,.07,.071),hair,12,6)
        else:
            ellipsoid('Hair cap',(0,1.63,-.025),(.181,.110,.159),hair,20,10)
            ellipsoid('Side swept fringe',(-.065,1.61,.10),(.115,.065,.066),hair,16,8)
            for x in [-.16,.16]: ellipsoid('Side hair',(x,1.54,-.042),(.040,.10,.112),hair,12,8)
            if style==1:
                ellipsoid('Bob back',(0,1.48,-.11),(.18,.22,.08),hair,20,10)
                for x in [-.161,.161]: ellipsoid('Bob side',(x,1.45,-.015),(.055,.18,.12),hair,12,8)
    pivot('Head',(0,1.30,0),head)
    for side,label in [(-1,'L'),(1,'R')]:
        x=side*.253
        def arm(x=x):
            ellipsoid('Sleeve',(x,1.17,0),(.096,.15,.111),shirt,16,8)
            rod('Upper arm',(x,1.16,.005),(x*1.12,.92,.025),.065,skin,12)
            rod('Forearm',(x*1.12,.92,.025),(x*1.10,.745,.06),.053,skin,12)
            ellipsoid('Hand',(x*1.10,.70,.062),(.061,.086,.045),skin,12,8)
            ellipsoid('Thumb',(x*.92,.717,.079),(.025,.049,.028),skin,10,6)
        pivot('Arm_'+label,(x,1.20,0),arm)
        lx=side*.098
        def leg_part(x=lx):
            rod('Trouser leg',(x,.76,0),(x,.20,0),.086,trousers,12)
            box('Cuff',(x,.19,.002),(.17,.07,.18),trousers,.015)
            box('Shoe',(x,.08,.058),(.174,.15,.31),shoes,.055)
            box('Sole',(x,.024,.058),(.178,.035,.315),mat('shoe_sole','393b37'),.012)
        pivot('Leg_'+label,(lx,.755,0),leg_part)


def gallery():
    """Optional inspection artifact, kept out of the runtime asset list."""
    clear()
    names=['bed','sofa','fridge','bookshelf','shower','toilet','tv','stereo','easel','plant','table','dining_table','game_table','garden_bed','resident','tree_linden']
    for i,name in enumerate(names):
        before=set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(OUT/(name+'.glb')))
        objects=set(bpy.context.scene.objects)-before
        offset=Vector(((i%4)*3.1, -(i//4)*3.3,0))
        for o in objects:
            if o.parent is None: o.location+=offset
        # Labels are a gallery aid only, never included in game assets.
        bpy.ops.object.text_add(location=(offset.x-1.0,offset.y-1.35,.015))
        label=bpy.context.object; label.data.body=name.replace('_',' '); label.data.size=.19
        label.data.materials.append(INK)
    box('Ground',(4.7,-.05,4.8),(15,.1,16),mat('gallery_ground','e4e1cf'),.02)
    scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=40
    scene.cycles.use_denoising=True
    world=bpy.data.worlds.new('Gallery world'); world.use_nodes=True; world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.72,.80,1); world.node_tree.nodes['Background'].inputs[1].default_value=.6; scene.world=world
    bpy.ops.object.light_add(type='AREA',location=(2,-3,12)); bpy.context.object.data.energy=2200; bpy.context.object.data.shape='DISK'; bpy.context.object.data.size=8
    bpy.ops.object.camera_add(location=(18,-23,20)); camera=bpy.context.object
    target=Vector((4.65,-4.8,.5)); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.type='ORTHO'; camera.data.ortho_scale=20
    scene.camera=camera; scene.render.resolution_x=1800; scene.render.resolution_y=1500; scene.render.resolution_percentage=100
    scene.view_settings.view_transform='AgX'; scene.render.image_settings.file_format='PNG'; scene.render.filepath=str(OUT/'gallery.png')
    bpy.ops.render.render(write_still=True)


def main():
    build('bed',[1,2],'Oak slatted bed, quilt seams, linen pillow, blue sage duvet.',bed)
    build('fridge',[1,1],'Rounded enamel fridge, separate freezer, handles, vents and note.',fridge)
    build('shower',[1,1],'Tiled shower, tray, frosted side screen, mixer and showerhead.',shower)
    build('toilet',[1,1],'Porcelain bowl, open seat, cistern and flush button.',toilet)
    build('sofa',[2,1],'Terracotta upholstered sofa, cushions, piping, throw and pillow.',sofa)
    build('tv',[1,1],'Small CRT with curved screen, controls and oak console.',tv)
    build('stereo',[1,1],'Oak hi-fi with speakers, receiver and turntable.',stereo)
    build('easel',[1,1],'Tripod easel with canvas, shelf, clamp and paint jar.',easel)
    build('bookshelf',[1,1],'Oak shelving with individually bound books.',bookshelf)
    build('garden_bed',[2,1],'Raised timber bed, exposed soil, planks and corner posts.',garden_bed)
    build('plant',[1,1],'Broad-leaf houseplant in terracotta pot.',plant)
    for name in ['table','dining_table','game_table']:
        build(name,[2,1 if name=='table' else 2],{'table':'Tea table with cups and teapot.','dining_table':'Dining table with runner and four place settings.','game_table':'Game table with an eight-by-eight board and pieces.'}[name],lambda name=name:table(name))
    for name,fn,desc in [('tree_linden',tree_linden,'Branched linden tree with clustered modeled foliage.'),('shrub',shrub,'Rounded berry shrub.'),('streetlamp',streetlamp,'Painted iron neighborhood lantern.'),('mailbox',mailbox,'Post mailbox with flag and slot.'),('fence',fence,'One-metre cream picket fence segment.'),('flower_patch',flower_patch,'Small flowering border.')]:
        build(name,[1,1],desc,fn)
    for name in ['tomato','radish']: build('crop_'+name,[.4,.4],'Single '+name+' crop; runtime scales growth and tints fruit.',lambda name=name:crop(name))
    for name in ['cottage','picture','shutters']: build('window_'+name,[1,.2],'Window overlay; centered on wall, y=.89–1.90m.',lambda name=name:window(name))
    build('door_frame',[1,1],'Open doorway with frame, threshold, and open paneled door.',door_frame)
    for i,name in enumerate(['resident','resident_bob','resident_curls','resident_shaved']):
        build(name,[.6,.4],'Resident with independently animated head, arms, legs and appearance materials.',lambda i=i:resident(i),True)
    manifest={'schema':1,'collection':'Linden Grove','creator':'Original procedural models authored for Simulateds','license':'MIT (repository LICENSE)','source':'tools/generate_models.py','source_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'generator':'Blender '+bpy.app.version_string,'units':'metres; one simulation tile = 1 metre','coordinates':{'up':'+Y','front':'+Z','origin':'footprint center at ground y=0'},'materials':{'custom_prefix':'custom_','resident':['skin','hair','shirt','trousers','shoes']},'models':MODELS}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('MODELS_GENERATED',len(MODELS),sum(m['triangles'] for m in MODELS.values()),'triangles')
    if '--gallery' in sys.argv: gallery()

if __name__=='__main__': main()
