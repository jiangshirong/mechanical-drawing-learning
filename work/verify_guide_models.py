"""Saved geometry and exported-asset consistency, independent of the running app."""
import bpy,bmesh,json,hashlib,struct,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]/'机械制图学习'
d=json.loads((ROOT/'assets/examples/section/data.json').read_text(encoding='utf-8'))
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'模型/section.blend'))
checks=[]
def check(name,value,detail=None):checks.append(dict(check=name,passed=bool(value),detail=detail))
volumes={};caps={};vertices={}
for name,sign in [('body',0),('section_body',1),('removed_body',-1)]:
    o=bpy.data.objects[name];bm=bmesh.new();bm.from_mesh(o.data)
    check(name+'_saved_closed',all(e.is_manifold for e in bm.edges))
    check(name+'_finite',all(math.isfinite(c) for v in bm.verts for c in v.co))
    check(name+'_build_version',o['example_version']==d['example_version']==2)
    volumes[name]=bm.calc_volume(signed=False)
    vertices[name]=[v.co.copy() for v in bm.verts]
    if sign:
        check(name+'_correct_side',all(sign*v.co.y>=-1e-8 for v in bm.verts))
        caps[name]=sum(f.calc_area() for f in bm.faces if all(abs(v.co.y)<1e-8 for v in f.verts))
    bm.free()
check('two_halves_equal_complete_volume',abs(volumes['section_body']+volumes['removed_body']-volumes['body'])<1e-10)
check('halves_equal_volume',abs(volumes['section_body']-volumes['removed_body'])<1e-10)
check('cut_faces_match',abs(caps['section_body']-caps['removed_body'])<5e-8,caps)
# Boolean operations can subdivide the same surface differently. Compare surfaces,
# not tessellation vertex IDs, in both directions after reflection.
for source,target in [('section_body','removed_body'),('removed_body','section_body')]:
    mesh=bpy.data.objects[target].data;mesh.calc_loop_triangles()
    tree=BVHTree.FromPolygons([v.co for v in mesh.vertices],[tuple(t.vertices) for t in mesh.loop_triangles],all_triangles=True)
    distance=max(tree.find_nearest(Vector((v.x,-v.y,v.z)))[3] for v in vertices[source])
    check(source+'_matches_other_surface',distance<2e-7,{'max_distance_mm':distance*1000})
for name,sha in d['asset_hashes'].items():
    raw=(ROOT/'assets/examples/section'/name).read_bytes()
    check(name+'_matches_definition',hashlib.sha256(raw).hexdigest()==sha)
    length,kind=struct.unpack_from('<II',raw,12)
    gltf=json.loads(raw[20:20+length])
    nodes=[n for n in gltf['nodes'] if 'mesh' in n]
    check(name+'_runtime_version',len(nodes)==1 and nodes[0].get('extras',{}).get('example_version')==2)
check('six_stable_unique_lessons',len(d['guide']['steps'])==len({s['id'] for s in d['guide']['steps']})==6)
check('rib_reason_exact','容易把肋板和底座、凸台看成一整块厚实材料' in d['guide']['steps'][5]['text'])
check('rib_cut_is_real',bool(d['section']['rib_polygon']) and caps['section_body']>sum(abs(sum(a[0]*b[1]-a[1]*b[0] for a,b in zip(p,p[1:]+p[:1])))*.5 for p in d['section']['polygons'])*1e-6)
(ROOT/'qa/guide-model-check.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'total':len(checks),'failures':[c for c in checks if not c['passed']]},ensure_ascii=False))
assert all(c['passed'] for c in checks)
