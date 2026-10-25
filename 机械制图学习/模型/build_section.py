"""One representative full-section exercise, t01-q05 / PDF3.
All model, contour, cut and hatch coordinates derive from P (teaching proportions).
"""
import bpy,bmesh,math,json,hashlib,sys
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from build_models import ROOT,QA,OUT,ASSETS,dump,cube,prism,boolean as apply_boolean,bore,feat,contour,project_data

def boolean(o,tool,op):
 apply_boolean(o,tool,op)
 bm=bmesh.new();bm.from_mesh(o.data)
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=0.00000002)
 bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free()

P=dict(left_x=-52.0,right_x=52.0,left_radius=30.0,right_radius=40.0,
       left_height=50.0,right_height=65.0,base_height=15.0,bore_radius=15.0,
       counterbore_radius=25.0,counterbore_floor=32.0,rib_half_width=8.0,
       rib_start_x=-26.0,rib_end_x=16.0,rib_start_z=31.0,rib_end_z=46.0)

def circle_z(cx,z,r,n=128):
 return [[cx+r*math.cos(2*math.pi*i/n),r*math.sin(2*math.pi*i/n),z] for i in range(n+1)]

def plate(profile,height):
 n=len(profile);verts=[(x*.001,y*.001,z*.001) for z in [0,height] for x,y in profile]
 faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 m=bpy.data.meshes.new('base');m.from_pydata(verts,[],faces);m.update()
 o=bpy.data.objects.new('body',m);bpy.context.collection.objects.link(o)
 bm=bmesh.new();bm.from_mesh(m);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(m);bm.free()
 return o

def cylinder(name,x,r,h):
 bottom=P['base_height']-1
 bpy.ops.mesh.primitive_cylinder_add(vertices=128,radius=r*.001,depth=(h-bottom)*.001,location=(x*.001,0,(h+bottom)*.0005))
 o=bpy.context.object;o.name=name;return o

def material(name,color):
 m=bpy.data.materials.new(name);m.diffuse_color=color;return m

def sharp_curves(o):
 result=[];bm=bmesh.new();bm.from_mesh(o.data);bm.normal_update()
 for e in bm.edges:
  if len(e.link_faces)==2 and e.calc_face_angle()<math.radians(24):continue
  a,b=[list((o.matrix_world@v.co)*1000) for v in e.verts]
  if (Vector(a)-Vector(b)).length<.03:continue
  result.append(feat('body','实际棱线','实体表面的交界。',[a,b]))
 bm.free();return result

def seg(a,b,tag='cut'):
 return {'a':list(a),'b':list(b),'world_a':[a[0],0,a[1]],'world_b':[b[0],0,b[1]],'feature':tag,'hidden':False}

def hatch(polygons,spacing=4.0):
 # x-z=c gives consistent 45-degree fine lines, clipped to real material only.
 out=[]
 for poly in polygons:
  lo=math.floor(min(x-z for x,z in poly)/spacing);hi=math.ceil(max(x-z for x,z in poly)/spacing)
  for i in range(lo,hi+1):
   c=i*spacing;hits=[]
   for a,b in zip(poly,poly[1:]+poly[:1]):
    da=a[0]-a[1]-c;db=b[0]-b[1]-c
    if (da<=0<db) or (db<=0<da):
     t=da/(da-db);hits.append([a[j]+t*(b[j]-a[j]) for j in [0,1]])
   hits.sort(key=lambda p:p[0])
   for a,b in zip(hits[::2],hits[1::2]):
    if (Vector(a)-Vector(b)).length>.05:out.append(seg(a,b,'cut'))
 return out

def checks(o):
 bm=bmesh.new();bm.from_mesh(o.data)
 result=dict(name=o.name,vertices=len(bm.verts),faces=len(bm.faces),
  open_edges=sum(not e.is_manifold for e in bm.edges),volume_m3=bm.calc_volume(signed=False),
  finite=all(math.isfinite(c) for v in bm.verts for c in v.co))
 bm.free();return result

def export(o,path):
 bpy.ops.object.select_all(action='DESELECT');o.hide_set(False);o.select_set(True);bpy.context.view_layer.objects.active=o
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_extras=True)

def build():
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.context.scene.name='Mechanical_section';bpy.context.scene.unit_settings.system='METRIC'
 bpy.context.scene.unit_settings.length_unit='MILLIMETERS'
 p=P;lx=p['left_x'];rx=p['right_x'];lr=p['left_radius'];rr=p['right_radius'];bh=p['base_height'];r=p['bore_radius'];cr=p['counterbore_radius'];cf=p['counterbore_floor']
 # Use the convex hull of exactly the same polygonal cylinders as the bosses.
 points=sorted(set((x+radius*math.cos(2*math.pi*i/128),radius*math.sin(2*math.pi*i/128)) for x,radius in [(lx,lr),(rx,rr)] for i in range(128)))
 def cross(o,a,b):return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
 lower=[];upper=[]
 for point in points:
  while len(lower)>=2 and cross(lower[-2],lower[-1],point)<=0:lower.pop()
  lower.append(point)
 for point in reversed(points):
  while len(upper)>=2 and cross(upper[-2],upper[-1],point)<=0:upper.pop()
  upper.append(point)
 profile=lower[:-1]+upper[:-1]
 o=plate(profile,bh)
 for name,x,radius,height in [('left_boss',lx,lr,p['left_height']),('right_boss',rx,rr,p['right_height'])]:boolean(o,cylinder(name,x,radius,height),'UNION')
 rib_profile=[(p['rib_start_x'],bh),(p['rib_end_x'],bh),(p['rib_end_x'],p['rib_end_z']),(p['rib_start_x'],p['rib_start_z'])]
 boolean(o,prism('rib',rib_profile,-p['rib_half_width'],p['rib_half_width']),'UNION')
 for x in [lx,rx]:bore(o,'through_bore',(x,0,35),r,100,'z')
 bore(o,'counterbore',(rx,0,cf+40),cr,80,'z')
 o.name='body';o['part_id']='body';o['example_id']='section';o['example_version']=2;o.data.materials.append(material('solid',(.22,.62,.75,1)))
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=0.00000002);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free()
 curves=sharp_curves(o)
 for x,height,radius in [(lx,p['left_height'],lr),(rx,p['right_height'],rr)]:
  curves.append(feat('body','凸台圆周','实际圆形顶边。',circle_z(x,height,radius)))
  for xx in [x-radius,x+radius]:curves.append(contour('body','正面外轮廓','圆柱正面方向的相切轮廓。',[[xx,0,0],[xx,0,height]],['front']))
  for y in [-radius,radius]:curves.append(contour('body','侧面外轮廓','圆柱侧面方向的相切轮廓。',[[x,y,0],[x,y,height]],['left']))
 for x,z,radius in [(lx,0,r),(lx,p['left_height'],r),(rx,0,r),(rx,cf,r),(rx,cf,cr),(rx,p['right_height'],cr)]:curves.append(feat('bore','孔口与台阶','真实圆孔边界。',circle_z(x,z,radius)))
 for x,z0,z1,radius in [(lx,0,p['left_height'],r),(rx,0,cf,r),(rx,cf,p['right_height'],cr)]:
  for xx in [x-radius,x+radius]:curves.append(contour('bore','孔壁投影','孔壁的正面轮廓。',[[xx,0,z0],[xx,0,z1]],['front']))
  for y in [-radius,radius]:curves.append(contour('bore','孔壁投影','孔壁的侧面轮廓。',[[x,y,z0],[x,y,z1]],['left']))
 features=[feat('body','实体','完整实体由底座、两个圆形凸台和筋板组成。',[[lx-22,0,20]],'face'),
  feat('bore','孔与台阶','左侧贯通孔；右侧贯通孔顶部有较大的孔口。',[[rx,0,cf]],'face'),
  feat('rib','筋板','沿长度方向剖切时，按原答案保留轮廓，不画剖面线。',[[0,0,36]],'face'),
  feat('cut','剖切面','通过两个孔轴的纵向剖切面 Y=0。',[[0,0,8]],'face')]
 bpy.context.view_layer.update();bounds,views=project_data([o],features,curves,False)
 half=o.copy();half.data=o.data.copy();bpy.context.collection.objects.link(half);half.name='section_body';half['part_id']='body'
 # Remove the half between the front observer and the central cutting plane.
 bm=bmesh.new();bm.from_mesh(half.data)
 bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=1e-8,
  plane_co=(0,0,0),plane_no=(0,1,0),clear_inner=True,use_snap_center=True)
 boundary=[e for e in bm.edges if e.is_boundary]
 bmesh.ops.holes_fill(bm,edges=boundary,sides=0)
 bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(half.data);bm.free()
 removed=o.copy();removed.data=o.data.copy();bpy.context.collection.objects.link(removed);removed.name='removed_body';removed['part_id']='body'
 bm=bmesh.new();bm.from_mesh(removed.data)
 bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=1e-8,
  plane_co=(0,0,0),plane_no=(0,1,0),clear_outer=True,use_snap_center=True)
 bmesh.ops.holes_fill(bm,edges=[e for e in bm.edges if e.is_boundary],sides=0)
 bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(removed.data);bm.free()
 half_curves=sharp_curves(half)
 # Actual semicircular rims on the retained half, not mesh tessellation edges.
 for f in curves:
  if f.get('projection_only'):continue
  for a,b in zip(f['points'],f['points'][1:]):
   if a[1]>=-.0001 and b[1]>=-.0001:half_curves.append(feat(f['id'],f['name'],f['explanation'],[a,b]))
 west=[[lx-lr,0],[lx-r,0],[lx-r,p['left_height']],[lx-lr,p['left_height']]]
 middle=[[lx+r,0],[rx-r,0],[rx-r,cf],[rx-cr,cf],[rx-cr,p['right_height']],
  [rx-rr,p['right_height']],[rx-rr,bh],[lx+lr,bh],[lx+lr,p['left_height']],[lx+r,p['left_height']]]
 east=[[rx+r,0],[rx+rr,0],[rx+rr,p['right_height']],[rx+cr,p['right_height']],[rx+cr,cf],[rx+r,cf]]
 polygons=[west,middle,east];hatches=hatch(polygons)
 cut_segments=[]
 for poly in polygons:
  for a,b in zip(poly,poly[1:]+poly[:1]):cut_segments.append(seg(a,b))
 def rib_z(x):return p['rib_start_z']+(x-p['rib_start_x'])*(p['rib_end_z']-p['rib_start_z'])/(p['rib_end_x']-p['rib_start_x'])
 rib_outline=[[lx+lr,bh],[rx-rr,bh],[rx-rr,rib_z(rx-rr)],[lx+lr,rib_z(lx+lr)]]
 cut_segments.append(seg(rib_outline[-1],rib_outline[-2],'rib'))
 # Top and left views remain projections of the complete part, as in a sectional drawing.
 section_views=json.loads(json.dumps(views));section_views['front']={'segments':cut_segments,'points':[],'hatches':hatches}
 target=ASSETS/'section';target.mkdir(exist_ok=True)
 source=ROOT.parent/'学习资料/题集识别'
 data=dict(schema_version=1,example_version=1,id='section',title='全剖视：双孔连接件',abstract=False,units='mm',
  source=dict(paper=1,pdf_page=3,question_id='t01-q05',image='assets/source/section.png',pdf_sha256=hashlib.sha256((source/'原题合订本.pdf').read_bytes()).hexdigest()),
  confirmed_facts=['将主视图画成全剖视图','原题有两个孔轴、右侧阶梯孔和中间筋板','纵向筋板在原答案中不画剖面线'],
  parameters=p,teaching_assumptions=['原题未标注尺寸，参数按已知视图比例设定。','采用圆形凸台和圆孔；原DOC线图的圆弧存在折线近似。'],
  features=features,curves=curves,bounds=bounds,views=views,lessons=[],
  answer_source='08sd1.doc导出答案第9页，第五题',answer_image='assets/source/section-answer.png',
  section=dict(model='assets/examples/section/section.glb',views=section_views,curves=half_curves,
   polygons=polygons,hatches=hatches,rib_polygon=rib_outline,plane=dict(axis='y',coordinate=0,retained='y>=0'),
   convention='只改主视图为全剖；筋板纵向不画剖面线；剖视中不显示已用可见轮廓表达的隐藏线。'),
  verification='对应原题与原DOC答案；解析剖面来自同一组尺寸，几何和交互结果见qa。')
 data['center_lines']=[dict(view='front',a=[x,-4],b=[x,h+4]) for x,h in [(lx,p['left_height']),(rx,p['right_height'])]]
 data['center_lines'] += [dict(view='top',a=[lx-lr-4,0],b=[rx+rr+4,0])]
 data['center_lines'] += [dict(view='top',a=[x,-radius-4],b=[x,radius+4]) for x,radius in [(lx,lr),(rx,rr)]]
 data['center_lines'] += [dict(view='left',a=[0,-4],b=[0,p['right_height']+4])]
 data['guide']=json.loads((Path(__file__).parent/'section_guide.json').read_text(encoding='utf-8'))
 data['guide_source_sha256']=hashlib.sha256((Path(__file__).parent/'section_guide.json').read_bytes()).hexdigest()
 data['guide']['removed_curves']=sharp_curves(removed)
 data['example_version']=2
 export(o,target/'model.glb');export(half,target/'section.glb');export(removed,target/'removed.glb')
 data['asset_hashes']={name:hashlib.sha256((target/name).read_bytes()).hexdigest() for name in ['model.glb','section.glb','removed.glb']}
 dump(target/'data.json',data)
 before=checks(o);after=checks(half)
 removed_check=checks(removed)
 assert removed_check['open_edges']==0,removed_check
 assert abs((after['volume_m3']+removed_check['volume_m3'])/before['volume_m3']-1)<.00001
 assert before['open_edges']==after['open_edges']==0,(before,after)
 assert abs(after['volume_m3']/before['volume_m3']-.5)<.00001,(before,after)
 o.hide_set(True);o.hide_render=True
 removed.hide_set(True);removed.hide_render=True
 half.hide_set(False);half.hide_render=False
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'section.blend'))
 dump(QA/'section-geometry.json',dict(whole=before,cut=after,removed=removed_check,bounds=bounds,plane=data['section']['plane'],hatch_count=len(hatches),example_version=2))
 catalog_path=ROOT/'assets/catalog.json';catalog=json.loads(catalog_path.read_text(encoding='utf-8'))
 catalog=[v for v in catalog if v['id']!='section']
 catalog.append(dict(id='section',title=data['title'],data='assets/examples/section/data.json',model='assets/examples/section/model.glb'))
 dump(catalog_path,catalog)
 print('SECTION_BUILD_OK',before,after)

def refresh_guide():
 """Rebuild teaching copy only; refuse to combine it with changed geometry."""
 target=ASSETS/'section'
 path=target/'data.json'
 data=json.loads(path.read_text(encoding='utf-8'))
 for name,expected in data['asset_hashes'].items():
  assert hashlib.sha256((target/name).read_bytes()).hexdigest()==expected, name
 source=Path(__file__).parent/'section_guide.json'
 guide=json.loads(source.read_text(encoding='utf-8'))
 guide['removed_curves']=data['guide']['removed_curves']
 data['guide']=guide
 data['guide_source_sha256']=hashlib.sha256(source.read_bytes()).hexdigest()
 dump(path,data)
 print('SECTION_GUIDE_REFRESH_OK geometry unchanged')

if __name__=='__main__':
 if '--guide-only' in sys.argv:refresh_guide()
 else:build()
