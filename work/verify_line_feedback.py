"""Focused checks for the three user-reported line-expression problems."""
from pathlib import Path
import json,bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]/'机械制图学习'
def read(id):return json.loads((ROOT/'assets/examples'/id/'data.json').read_text(encoding='utf-8'))
checks=[]
def check(name,ok,detail=None):checks.append({'check':name,'passed':bool(ok),'detail':detail})
d=read('bracket')
for x in [-19,19]:
 for z,want in [(24,'visible'),(19,'hidden'),(5,'hidden'),(0,'visible')]:
  s=[s for s in d['views']['front']['segments'] if abs(s['a'][1]-z)<.01 and abs(s['b'][1]-z)<.01 and min(s['a'][0],s['b'][0])-.001<=x<=max(s['a'][0],s['b'][0])+.001]
  actual='visible' if any(not v['hidden'] for v in s) else ('hidden' if s else 'absent')
  check(f'bracket_front_x{x}_z{z}',actual==want,actual)
 check(f'bracket_no_fake_horizontal_center_x{x}',not any(abs(s['a'][1]-12)<.01 and abs(s['b'][1]-12)<.01 and min(s['a'][0],s['b'][0])<=x<=max(s['a'][0],s['b'][0]) for s in d['views']['front']['segments']))
d=read('base')
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'模型/base.blend'))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH');o.data.calc_loop_triangles()
bv=BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[t.vertices for t in o.data.loop_triangles],all_triangles=True)
rendered=[c for c in d['curves'] if not c.get('projection_only',False)]
worst=0
for c in rendered:
 for a,b in zip(c['points'],c['points'][1:]):worst=max(worst,bv.find_nearest((Vector(a)+Vector(b))*.0005)[3]*1000)
check('base_every_3d_curve_on_real_surface',worst<.04,{'maximum_distance_mm':worst})
check('base_exit_at_recess_front_y12',all(abs(p[1]-12)<1e-6 for c in rendered if c['id']=='bore' and c['name']=='孔口' and c['points'][0][1]>0 for p in c['points']))
observer=(ROOT/'observer.gd').read_text(encoding='utf-8')
check('projection_only_not_drawn_or_picked_in_3d',observer.count('if curve.get("projection_only", false): continue')==1 and observer.count('if c.get("projection_only", false): continue')==1)
(ROOT/'qa/line-feedback-check.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'checks':len(checks),'failed':[c for c in checks if not c['passed']]},ensure_ascii=False))
