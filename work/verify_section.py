from pathlib import Path
import bpy,bmesh,json,math
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]/'机械制图学习'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'模型/section.blend'))
d=json.loads((ROOT/'assets/examples/section/data.json').read_text(encoding='utf-8'))
checks=[]
def check(name,value,detail=None):checks.append(dict(check=name,passed=bool(value),detail=detail))
def area(poly):return abs(sum(a[0]*b[1]-a[1]*b[0] for a,b in zip(poly,poly[1:]+poly[:1])))*.5
objects={o.name:o for o in bpy.context.scene.objects if o.type=='MESH'}
volumes={}
for name in ['body','section_body']:
 o=objects[name];bm=bmesh.new();bm.from_mesh(o.data)
 check(name+'_closed',all(e.is_manifold for e in bm.edges))
 check(name+'_finite',all(math.isfinite(c) for v in bm.verts for c in v.co))
 volumes[name]=bm.calc_volume(signed=False)
 if name=='section_body':
  check('front_half_removed',all(v.co.y>=-1e-8 for v in bm.verts))
  cap_area=sum(f.calc_area()*1e6 for f in bm.faces if all(abs(v.co.y)<1e-8 for v in f.verts))
  expected=sum(area(p) for p in d['section']['polygons'])+area(d['section']['rib_polygon'])
  check('analytic_section_equals_mesh_cut',abs(cap_area-expected)<.05,dict(mesh_mm2=cap_area,analytic_mm2=expected))
 bm.free()
check('half_volume',abs(volumes['section_body']/volumes['body']-.5)<1e-5)
o=objects['body'];o.data.calc_loop_triangles()
bv=BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[tuple(t.vertices) for t in o.data.loop_triangles],all_triangles=True)
for name,x,expected in [('left_through',-52,None),('right_through',52,None),('counterbore_floor',72,32),('right_wall',82,65)]:
 hit=bv.ray_cast(Vector((x,0,100))*.001,Vector((0,0,-1)),.2)[0]
 check(name,hit is None if expected is None else hit is not None and abs(hit.z*1000-expected)<.02,list(hit*1000) if hit is not None else None)
rib=d['section']['rib_polygon']
def inside(point,poly):
 x,z=point;flag=False
 for a,b in zip(poly,poly[1:]+poly[:1]):
  if (a[1]>z)!=(b[1]>z) and x<(b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0]:flag=not flag
 return flag
check('no_hatching_in_rib',all(not inside([(s['a'][0]+s['b'][0])*.5,(s['a'][1]+s['b'][1])*.5],rib) for s in d['section']['hatches']))
check('no_hatching_in_bores',all(not (-67<x<-37 or (37<x<67) or (z>32 and 27<x<77)) for s in d['section']['hatches'] for x,z in [[(s['a'][0]+s['b'][0])*.5,(s['a'][1]+s['b'][1])*.5]]))
check('section_no_hidden_lines',all(not s['hidden'] for s in d['section']['views']['front']['segments']))
check('other_views_unchanged',all(d['views'][key]==d['section']['views'][key] for key in ['top','left']))
for s in d['section']['views']['front']['segments']:
 check('section_projection_coordinates',abs(s['world_a'][0]-s['a'][0])<1e-6 and abs(s['world_a'][2]-s['a'][1])<1e-6 and s['world_a'][1]==0)
(ROOT/'qa/section-saved-check.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(total=len(checks),failed=[c for c in checks if not c['passed']]),ensure_ascii=False))
assert all(c['passed'] for c in checks)
