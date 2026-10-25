from pathlib import Path
import bpy,json,math,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]/'机械制图学习'
results=[]
for id in ['points','line','plane','slope','base','bracket']:
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/'模型'/f'{id}.blend'))
 d=json.loads((ROOT/'assets/examples'/id/'data.json').read_text(encoding='utf-8'))
 expected=json.loads((ROOT/'qa'/f'{id}-geometry.json').read_text(encoding='utf-8'))
 actual=[]
 for o in bpy.context.scene.objects:
  if o.type!='MESH':continue
  bm=bmesh.new();bm.from_mesh(o.data)
  actual.append({'name':o.name,'vertices':len(bm.verts),'open_edges':sum(not e.is_manifold for e in bm.edges)})
  bm.free()
 entry={'id':id,'reopened':True,'meshes':actual,'finite':all(math.isfinite(v) for o in bpy.context.scene.objects if o.type=='MESH' for p in o.data.vertices for v in p.co),'source_sha256':d['source']['pdf_sha256']}
 if id=='points':
  a=Vector(d['features'][0]['points'][0]);b=Vector(d['features'][1]['points'][0]);entry['distances_and_relative']=a==Vector((-10,-15,12)) and b-a==Vector((-5,10,8))
 if id=='line':
  a=Vector(d['features'][0]['points'][0]);b=Vector(d['features'][1]['points'][0]);v=b-a
  entry['length_30']=abs(v.length-30)<1e-4;entry['horizontal']=abs(v.z)<1e-6;entry['angle_V_30']=abs(math.degrees(math.asin(abs(v.y)/v.length))-30)<1e-4
 if id=='plane':
  pts={f['id']:Vector(f['points'][0]) for f in d['features'] if f['kind']=='point'}
  entry['parallelogram']=(pts['A']+pts['C']-pts['B']-pts['D']).length<1e-6;entry['AC_front_parallel']=abs(pts['A'].y-pts['C'].y)<1e-6
 if id in ['slope','base','bracket']:
  o=next(o for o in bpy.context.scene.objects if o.type=='MESH');o.data.calc_loop_triangles()
  bv=BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[t.vertices for t in o.data.loop_triangles],all_triangles=True)
  tests={'slope':[('slot_void',[20,0,80],[0,0,-1],42)],'base':[('bore_void',[0,-60,36],[0,1,0],None),('rear_slot_void',[0,20,100],[0,0,-1],12)],'bracket':[('upright_bore_void',[0,-60,38],[0,1,0],None),('cross_bore_void',[-60,-20,12],[1,0,0],None),('fork_void',[0,-20,100],[0,0,-1],None)]}[id]
  entry['void_checks']=[]
  for name,start,direction,height in tests:
   hit=bv.ray_cast(Vector(start)*.001,Vector(direction),.3)[0]
   entry['void_checks'].append({'check':name,'passed':hit is None if height is None else hit is not None and abs(hit.z*1000-height)<.01,'hit_mm':list(hit*1000) if hit else None})
 results.append(entry)
(ROOT/'qa/saved-model-check.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
print('SAVED_MODEL_CHECK',json.dumps(results,ensure_ascii=False))
