"""Reproducible Blender assets and same-geometry orthographic line data.
Design coordinates: x right, y back, z up; numeric unit millimetre.
GLB uses Blender metre -> Godot (x,z,-y). Never touches another blend file.
"""
import bpy,bmesh,json,math,sys,hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets'/'examples';ASSETS.mkdir(parents=True,exist_ok=True)
QA=ROOT/'qa';QA.mkdir(exist_ok=True)
OUT=Path(__file__).resolve().parent
def dump(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2),encoding='utf-8')
def cube(name,center,dim):
 bpy.ops.mesh.primitive_cube_add(size=1,location=Vector(center)*.001);o=bpy.context.object;o.name=name;o.dimensions=Vector(dim)*.001
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return o
def prism(name,profile,a,b,axis='y'):
 def pos(p,d):return (p[0],d,p[1]) if axis=='y' else (d,p[0],p[1])
 n=len(profile);verts=[tuple(Vector(pos(p,d))*.001) for d in [a,b] for p in profile]
 faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update();o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o)
 bm=bmesh.new();bm.from_mesh(m);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(m);bm.free();return o
def boolean(o,tool,op):
 bpy.context.view_layer.objects.active=o
 mod=o.modifiers.new('parametric_'+op,'BOOLEAN');mod.operation=op;mod.solver='EXACT';mod.object=tool
 bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(tool,do_unlink=True)
def bore(o,name,center,r,length,axis='y'):
 bpy.ops.mesh.primitive_cylinder_add(vertices=128,radius=r*.001,depth=length*.001,location=Vector(center)*.001)
 t=bpy.context.object;t.name=name
 if axis=='y':t.rotation_euler[0]=math.pi/2
 elif axis=='x':t.rotation_euler[1]=math.pi/2
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);boolean(o,t,'DIFFERENCE')
def line_mesh(name,a,b,r=.65):
 a=Vector(a)*.001;b=Vector(b)*.001;d=b-a
 bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=r*.001,depth=d.length,location=(a+b)/2)
 o=bpy.context.object;o.name=name;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return o
def sphere(name,p,r=1.15):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=r*.001,location=Vector(p)*.001);o=bpy.context.object;o.name=name;return o
def arc(cx,cz,r,start=0,end=math.pi,n=96):return [(cx+r*math.cos(start+(end-start)*i/n),cz+r*math.sin(start+(end-start)*i/n)) for i in range(n+1)]
def feat(id,name,text,points,kind='edge'):
 return {'id':id,'name':name,'explanation':text,'points':points,'kind':kind}

def contour(id,name,text,points,views):
 f=feat(id,name,text,points,'contour');f['projection_only']=True;f['projection_views']=views;return f
def circle_y(cx,y,cz,r):return [[x,y,z] for x,z in arc(cx,cz,r,0,2*math.pi,128)]
def circle_x(x,cy,cz,r):return [[x,y,z] for y,z in arc(cy,cz,r,0,2*math.pi,128)]

DESCS={
'points':('两点的三面投影',1,1,'t01-q01',[.07,.18,.93,.53]),
'line':('水平线的三面投影',2,7,'t02-q01',[.07,.18,.93,.48]),
'plane':('平行四边形补投影',2,7,'t02-q02',[.07,.50,.93,.92]),
'slope':('斜面开槽组合体',2,8,'t02-q03',[.10,.035,.94,.48]),
'base':('带孔底座组合体',2,8,'t02-q03',[.10,.49,.94,.96]),
'bracket':('主左视图补俯视图',7,35,'t07-q05',[.08,.025,.94,.52])}
LESSONS={
'points':[
 ('先认识三个投影面','H 是水平面，V 是正面，W 是侧面。点的位置由到三个面的距离共同确定。','A',0),
 ('放置 A、B 两点','A 距 H/V/W 分别为 12/15/10；B 在 A 左方5、后方10、上方8。左方改变左右坐标，后方改变深度，上方改变高度。','B',0),
 ('沿垂直方向投影','从空间点向每个投影面作垂线。投影丢掉垂直于该面的坐标，因此同一个点出现三个投影。','A',0),
 ('展开 H、W 面','将 H 面绕与 V 面的交线转下，将 W 面转向右侧。空间投影变成一张图纸上的三个区域。','A',1),
 ('核对点的位置','正面投影看左右与高度；水平投影看左右与前后；侧面投影看前后与高度。A、B 的位置关系可以逐项核对。','B',1)],
'line':[
 ('水平线是什么','AB 平行 H 面，两端高度相同，均为15。它并不同时平行 V 面。','AB',0),
 ('实长与方向','水平投影保留线段实长30。AB 与 V 面夹角30°，B 在 A 左前方，所以沿左方和前方共同移动。','AB',0),
 ('分别投向三个面','正面与侧面投影都成为水平线，但一般短于实长。不要把正面投影长度直接当成 AB 的空间长度。','AB',0),
 ('展开投影面','展开后，正面、水平投影的同名端点长对正；正面与侧面的同名端点高平齐。','AB',1),
 ('用数量关系复核','左右差=30cos30°≈25.98，前后差=30sin30°=15，高度差=0。三份投影来自同一组端点。','B',1)],
'plane':[
 ('看已知投影','原题给出四点正面投影，以及 a、d 的水平投影；还规定 AC 是正平线。图上未标尺寸，模型使用教学比例。','ABCD',0),
 ('利用 AC 正平线','AC 平行 V 面，A、C 到 V 面的距离相等，因此水平投影 ac 平行投影轴。先由 c′ 下引投影线，找到 c。','AC',0),
 ('利用平行四边形','对边平行且相等，空间点满足 B=A+C−D。已知 A、C、D 后，可以确定 B。','B',0),
 ('展开后连接四点','把得到的 a、b、c、d 按顺序连接，检查两组对边平行。辅助对角线 AC 不是实体外边。','ABCD',1),
 ('核对依据','参考与原始08sd2.doc答案第6页对照。模型比例是设定；AC 的等深度和平行四边形关系是题目条件。','AC',1)],
'slope':[
 ('从两个视图读结构','左侧是主视图，右侧是左视图。主视图告诉你长度和高度，左视图补充宽度及顶部凹槽。','body',0),
 ('先理解斜面','沿长度方向，高度从低处升到高处；沿宽度方向，侧面也有收窄。俯视图必须同时反映这两组条件。','slope',0),
 ('看槽的真实边界','槽从顶部去掉材料。它的底部在主视方向被前面的材料遮住，所以给定主视图用虚线表达。','slot',0),
 ('长对正、宽相等','由主视图传递左右位置，由左视图传递深度。淡色辅助线解释对齐，黑线仍表示正式表达。','slope',0),
 ('补俯视图的内部线','俯视图中斜面边界收向右侧，槽口边界与其衔接。逐条点击，观察线段对应哪处空间边界。','slot',0),
 ('与原始答案核对','完成图对照08sd2.doc答案第7页。二维线条由本模型生成；未标尺寸按原图比例设置，表示一种相容实体。','body',0)],
'base':[
 ('先认底座与上部','底座的轮廓、上部宽度和各台阶需要同时满足主、俯视图。图中没有数值尺寸，使用教学比例。','body',0),
 ('圆不总是圆','孔轴正对主视方向时，孔口投影为圆；从侧面或上面观察，它由两条边界线表达。','bore',0),
 ('辨认槽与台阶','俯视图的嵌套轮廓来自不同深度的台阶与开口。仅看主视图容易把这些结构压成同一位置。','slot',0),
 ('推导左视图','主视图传递高度，俯视图传递深度。不同深度的上部结构形成阶梯轮廓。','body',0),
 ('解释遮挡','实线表示可见轮廓，虚线表示被实体挡住的边界。选择孔缘，可以比较它在三个方向的表现。','bore',0),
 ('对照参考来源','原始08sd2.doc答案第7页提供左视图。教学模型展示一种满足原图结构的解释；原图扫描线型与未定尺寸在核验记录中单独说明。','body',0)],
'bracket':[
 ('从主、左视图定位结构','主视图确定左右与高度；左视图确定深度与高度。要补的是俯视图。','body',0),
 ('分清两个方向的孔','竖板上的孔沿前后方向贯通，前侧与槽相接；两叉上的孔沿左右方向贯通。它们在主、左视图中分别呈圆或虚线。','upright_hole',0),
 ('圆弧外形来自哪里','竖板顶部和底部端头具有不同方向的圆弧。俯视时只保留左右和深度坐标，不能照搬原来的圆弧。','round',0),
 ('投向水平面','从每个关键边界向 H 面投影；分别传递主视图的左右位置和左视图的深度位置。','base_hole',0),
 ('检查俯视图线条','保留外轮廓，判断两个孔的边界是否被材料遮住，再加中心线。三角网格的细分边不是工程图线。','body',0),
 ('核对与限制','参考表达已与08sd7.doc答案第8页的叉形俯视图核对。原题没有尺寸，模型按比例构造；孔与前侧槽相接的内部深度采用一种相容解释。','body',0)]}

def create(id):
 objects=[];features=[];curves=[];params={};facts=[];abstract=id in ['points','line','plane']
 if id=='points':
  pts={'A':[-10,-15,12],'B':[-15,-5,20]};params={'points_mm':pts};facts=['A距H12、V15、W10','B相对A：左5、后10、上8']
  for name,p in pts.items():objects.append(sphere(name,p));features.append(feat(name,name+' 点','空间点 '+name+'；选择任一投影能找到同一个空间点。',[p],'point'))
 elif id=='line':
  a=[-10,-5,15];b=[-10-30*math.cos(math.pi/6),-20,15];params={'A':a,'B':b,'length_mm':30,'angle_to_V_deg':30}
  facts=['A距H15、V5、W10','AB水平，实长30，与V夹角30°，B位于A左前方']
  objects=[sphere('A',a),sphere('B',b),line_mesh('AB',a,b)]
  features=[feat('A','A 点','起点位置由三面距离确定。',[a],'point'),feat('B','B 点','与 A 等高，向左25.98、向前15。',[b],'point'),feat('AB','水平线 AB','与 H 平行；水平投影显实长，另两投影水平但缩短。',[a,b])];curves=[features[-1]]
 elif id=='plane':
  a=[-38,-18,30];c=[10,-18,45];d=[-14,-12,20];b=[a[i]+c[i]-d[i] for i in range(3)]
  pts={'A':a,'B':b,'C':c,'D':d};params={'points_teaching_mm':pts};facts=['ABCD是平行四边形','AC为正平线，即A、C等深度']
  mesh=bpy.data.meshes.new('ABCD');mesh.from_pydata([tuple(Vector(p)*.001) for p in [a,b,c,d]],[],[(0,1,2,3)]);o=bpy.data.objects.new('ABCD',mesh);bpy.context.collection.objects.link(o);objects=[o]
  features=[feat('ABCD','平面 ABCD','半透明平面是抽象几何对象，不是有厚度的机械零件。',[a,b,c,d,a],'face'),feat('AC','正平线 AC','AC 是辅助对角线；A、C 到 V 面距离相同。',[a,c])]
  for name,p in pts.items():objects.append(sphere(name,p));features.append(feat(name,name+' 点','同名点在各投影中一一对应。',[p],'point'))
  curves=[feat('ABCD','平面边界','四边形的外边界。',[a,b,c,d,a])]
 else:
  if id=='slope':
   params={'length':80,'depth_bottom':60,'height':60,'slope_end_x':-8,'low_end_height':28,'depth_top':28,'slot_width':14,'slot_floor':42}
   o=prism('body',[(-40,0),(40,0),(40,60),(-8,60),(-40,28)],-40,40)
   tool=prism('taper',[(-30,0),(30,0),(14,60),(-14,60)],-50,50,'x');boolean(o,tool,'INTERSECT')
   boolean(o,cube('slot_tool',(0,0,72),(100,14,60)),'DIFFERENCE')
   features=[feat('body','组合体','整体由斜面、收窄侧面和顶部贯通槽组成。',[[0,0,25]],'face'),feat('slope','斜面','斜面投影在主视图中为斜线，在俯视图中由两侧边界围成。',[[-40,-22.53,28],[-8,-14,60]],'face'),feat('slot','顶部槽','宽14、槽底高42是教学设定。槽是去掉的真实材料。',[[8,0,42]],'face')]
  elif id=='base':
   params={'base_width':90,'base_depth':70,'base_height':12,'upright_width':64,'height':68,'bore_center_height':36,'bore_radius':12,'arch_radius':20,'arch_center_height':36}
   # Chamfered base, rectangular rear boss with open rear recess, curved front rib.
   profile=[(-45,-25),(-35,-35),(35,-35),(45,-25),(45,35),(-45,35)]
   n=len(profile);m=bpy.data.meshes.new('base');v=[(x*.001,y*.001,z*.001) for z in [0,12] for x,y in profile];f=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
   m.from_pydata(v,[],f);o=bpy.data.objects.new('body',m);bpy.context.collection.objects.link(o)
   bm=bmesh.new();bm.from_mesh(m);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(m);bm.free()
   boolean(o,cube('rear',(0,10,40),(64,30,56)),'UNION')
   boolean(o,cube('rear_slot',(0,22,46),(34,20,68)),'DIFFERENCE')
   archprof=[(-20,12),(20,12)]+arc(0,36,20,0,math.pi)
   boolean(o,prism('arch',archprof,-20,-5),'UNION');bore(o,'through_bore',(0,0,36),12,100)
   for yy in [-20,12]:curves.append(feat('bore','孔口','前部孔口与后槽前壁的真实出口。',circle_y(0,yy,36,12)))
   for yy in [-20,-5]:curves.append(feat('round','圆弧外边','圆弧轮廓属于前部拱形结构。',[[x,yy,z] for x,z in arc(0,36,20)]))
   for x,z in [(0,56),(20,36),(-20,36)]:curves.append(contour('round','圆弧轮廓母线','从正交方向观察曲面的切线边界。',[[x,-20,z],[x,-5,z]],['top'] if x else ['left']))
   for x,z in [(12,36),(-12,36),(0,24),(0,48)]:curves.append(contour('bore','孔的轮廓母线','圆柱孔的投影轮廓；光滑孔壁上没有实体棱线。',[[x,-20,z],[x,12,z]],['top'] if x else ['left']))
   features=[feat('body','底座与上部','台阶高度、深度与圆弧对应不同投影轮廓。',[[0,0,8]],'face'),feat('bore','贯通孔','孔轴沿前后方向；孔口为圆，其他方向一般用线表达。',[[0,-20,36]],'face'),feat('slot','后部开口','后部槽口和前部圆弧结构共同形成俯视图的嵌套边界。',[[0,20,30]],'face'),feat('round','拱形轮廓','圆弧外形与孔口属于不同边界。',[[0,-20,56]],'face')]
  else:
   params={'width':52,'upright_back':27,'upright_front':15,'upright_arc_center_z':38,'upright_radius':26,'upright_bore_radius':12,'base_end_y':-20,'base_radius':12,'base_bore_radius':7,'fork_width':24,'front_recess_back_y':21}
   o=prism('body',[(-26,0),(26,0)]+arc(0,38,26,0,math.pi),15,27)
   baseprof=[(-20,0),(15,0),(15,24),(-20,24)]+arc(-20,12,12,math.pi/2,3*math.pi/2)
   boolean(o,prism('base',baseprof,-26,26,'x'),'UNION')
   bore(o,'upright_hole',(0,21,38),12,30);bore(o,'base_hole',(0,-20,12),7,80,'x')
   # The source front view has vertical slot boundaries tangent to the round hole;
   # the supplied answer confirms the fork-shaped top outline.
   boolean(o,cube('fork_slot',(0,-11,18.5),(24,64,39)),'DIFFERENCE')
   for yy in [15,27]:
    ring=circle_y(0,yy,38,12) if yy==27 else [[x,yy,z] for x,z in arc(0,38,12)]
    curves.append(feat('upright_hole','竖板孔口','前侧槽与孔相接，后侧保留完整孔口。',ring))
    curves.append(feat('round','竖板圆弧','竖板顶部圆弧。',[[x,yy,z] for x,z in arc(0,38,26)]))
   for xx in [-26,26]:
    curves.append(feat('base_hole','底部孔口','沿左右方向贯通的孔。',circle_x(xx,-20,12,7)))
    curves.append(feat('round','底部圆弧端头','底部端头在左视图中呈半圆弧。',[[xx,y,z] for y,z in arc(-20,12,12,math.pi/2,3*math.pi/2)]))
   for x,z in [(12,38),(-12,38),(0,26),(0,50)]:curves.append(contour('upright_hole','竖板孔母线','孔的侧向投影边界。',[[x,21 if z<38 else 15,z],[x,27,z]],['top'] if x else ['left']))
   for y,z in [(-27,12),(-13,12),(-20,5),(-20,19)]:
    for xa,xb in [(-26,-12),(12,26)]:curves.append(contour('base_hole','底部孔母线','两叉上孔的侧向投影边界。',[[xa,y,z],[xb,y,z]],['top'] if z==12 else ['front']))
   curves.append(contour('round','竖板顶轮廓母线','竖板圆弧顶部在侧视方向成为水平轮廓。',[[0,15,64],[0,27,64]],['left']))
   for xa,xb in [(-26,-12),(12,26)]:
    curves.append(contour('round','圆弧端头母线','底部前端在俯视方向成为两条外边界。',[[xa,-32,12],[xb,-32,12]],['top']))
    for z in [0,24]:curves.append(contour('round','两叉上下轮廓','主视图中圆弧端头的可见上下轮廓，位于横孔轮廓之外。',[[xa,-20,z],[xb,-20,z]],['front']))
   features=[feat('body','开槽支座','竖板与向前伸出的两叉组成整体，俯视图呈开口轮廓。',[[20,20,24]],'face'),feat('upright_hole','竖板孔','轴沿前后；前侧槽与孔相接，后侧仍保留完整孔口。',[[0,27,38]],'face'),feat('base_hole','底部横孔','两叉上沿左右方向的孔；左视图显示孔口圆。',[[-26,-20,12]],'face'),feat('round','圆弧外形','竖板顶端与两叉端头的圆弧朝向不同。',[[0,15,64]],'face')]
  objects=[o]
  # Sharp feature edges of evaluated boolean mesh only; curved tessellation edges excluded.
  bm=bmesh.new();bm.from_mesh(o.data);bm.normal_update()
  for e in bm.edges:
   if len(e.link_faces)!=2 or e.calc_face_angle()>math.radians(24):
    pts=[list((o.matrix_world@v.co)*1000) for v in e.verts]
    if (Vector(pts[0])-Vector(pts[1])).length<.02:continue
    mid=(Vector(pts[0])+Vector(pts[1]))/2
    tag='body'
    if id=='slope':tag='slot' if abs(abs(mid.y)-7)<.1 or abs(mid.z-42)<.1 else ('slope' if -40<=mid.x<=-8 and mid.z>26 else 'body')
    elif id=='base':tag='slot' if abs(abs(mid.x)-17)<.15 else 'body'
    curves.append(feat(tag,'结构边界','两表面交界的真实棱线。',pts))
  bm.free()
 # Stable semantic mapping; decorative objects are not exported.
 for o in objects:
  o['part_id']=o.name;o['example_id']=id
  mat=bpy.data.materials.new(id+'_'+o.name);mat.diffuse_color=(.22,.62,.75,1) if o.name!='ABCD' else (.22,.62,.75,.65);o.data.materials.append(mat)
 return objects,features,curves,params,facts,abstract

def project_data(objects,features,curves,abstract):
 if abstract:
  points=[p for f in features for p in f['points']]
 else:
  points=[list((o.matrix_world@v.co)*1000) for o in objects for v in o.data.vertices]
 bounds=[[min(p[i] for p in points),max(p[i] for p in points)] for i in range(3)]
 if abstract:bounds=[[min(a,0),max(b,0)] for a,b in bounds]
 bv=None
 if not abstract:
  verts=[];polys=[]
  for o in objects:
   o.data.calc_loop_triangles();offset=len(verts);verts += [o.matrix_world@v.co for v in o.data.vertices]
   polys += [tuple(offset+i for i in t.vertices) for t in o.data.loop_triangles]
  bv=BVHTree.FromPolygons(verts,polys,all_triangles=True)
 views={};directions={'front':Vector((0,-1,0)),'top':Vector((0,0,1)),'left':Vector((-1,0,0))}
 def proj(p,k):return [p[0],p[2]] if k=='front' else ([p[0],p[1]] if k=='top' else [-p[1],p[2]])
 for key,view in directions.items():
  segments=[]
  for f in curves:
   if 'projection_views' in f and key not in f['projection_views']:continue
   for a,b in zip(f['points'],f['points'][1:]):
    if (Vector(proj(a,key))-Vector(proj(b,key))).length<.015:continue
    distance=(Vector(b)-Vector(a)).length
    # ≤0.5mm samples, including around narrow occlusion boundaries.
    count=max(1,math.ceil(distance/.5)) if not abstract else 1
    prev=Vector(a)
    for n in range(count):
     nxt=Vector(a).lerp(Vector(b),(n+1)/count);mid=(prev+nxt)*.5
     hidden=False
     if bv:
      p=mid*.001;origin=p+view*.5;hit=bv.ray_cast(origin,-view,.51)
      nearest=bv.find_nearest(p)
      if nearest[0] is None or nearest[3]>.00004:
       prev=nxt
       continue
      # Only an intersection BEFORE the candidate can hide it. At tangencies
      # the first hit may lie behind the candidate; that is not an occluder.
      hidden=hit[0] is not None and (origin-hit[0]).length<.5-.00018
     segments.append({'a':proj(prev,key),'b':proj(nxt,key),'world_a':list(prev),'world_b':list(nxt),'feature':f['id'],'hidden':hidden})
     prev=nxt
  views[key]={'segments':segments,'points':[{'feature':f['id'],'label':f['name'].split()[0],'uv':proj(f['points'][0],key),'world':f['points'][0]} for f in features if f['kind']=='point']}
 return bounds,views

def build(id):
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.context.scene.name='Mechanical_'+id;bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.length_unit='MILLIMETERS'
 objects,features,curves,params,facts,abstract=create(id)
 bpy.context.view_layer.update();bounds,views=project_data(objects,features,curves,abstract)
 title,paper,page,qid,crop=DESCS[id];target=ASSETS/id;target.mkdir(exist_ok=True)
 data={'schema_version':1,'example_version':1,'id':id,'title':title,'abstract':abstract,'units':'mm','coordinates':'Blender x right, y back, z up; Godot=(x,z,-y)','source':{'paper':paper,'pdf_page':page,'question_id':qid,'crop':crop,'image':f'assets/source/{id}.png'},'confirmed_facts':facts,'parameters':params,'teaching_assumptions':[] if id in ['points','line'] else ['原题没有数值标注；模型按原图比例设定毫米尺寸。','展示与已知投影相容的一种几何解释，不宣称唯一实体。'],'features':features,'curves':curves,'bounds':bounds,'views':views,'lessons':[{'title':t,'text':txt,'feature':f,'unfold':u} for t,txt,f,u in LESSONS[id]],'objects':[{'name':o.name,'part_id':o['part_id']} for o in objects],'answer_source': '08sd2.doc答案第6页' if id in ['line','plane'] else ('08sd2.doc答案第7页' if id in ['slope','base'] else '题干条件＋解析投影推导'),'verification':'程序几何核验；原题/答案对照及真实UI结果见qa与覆盖记录'}
 if id=='points':data['answer_source']='08sd1.doc答案第7页'
 if id=='bracket':data['answer_source']='08sd7.doc答案第8页'
 data['center_marks']=[{'view':'front','uv':[0,36],'radius':20}] if id=='base' else ([{'view':'front','uv':[0,38],'radius':26},{'view':'left','uv':[20,12],'radius':12}] if id=='bracket' else [])
 data['source']['pdf_sha256']=hashlib.sha256((ROOT.parent/'学习资料'/'题集识别'/'原题合订本.pdf').read_bytes()).hexdigest()
 dump(target/'data.json',data)
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0]
 bpy.ops.export_scene.gltf(filepath=str(target/'model.glb'),export_format='GLB',use_selection=True,export_extras=True)
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(id+'.blend')))
 checks=[]
 for o in objects:
  bm=bmesh.new();bm.from_mesh(o.data)
  checks.append({'name':o.name,'vertices':len(bm.verts),'faces':len(bm.faces),'open_edges':sum(not e.is_manifold for e in bm.edges),'degenerate_faces':sum(f.calc_area()<1e-14 for f in bm.faces),'finite':all(math.isfinite(c) for v in bm.verts for c in v.co),'volume_m3':bm.calc_volume(signed=False),'role':'abstract_plane' if o.name=='ABCD' else ('abstract_marker' if abstract else 'solid')})
  bm.free()
 dump(QA/(id+'-geometry.json'),{'id':id,'checks':checks,'bounds_mm':bounds,'projection_segments':{k:len(v['segments']) for k,v in views.items()}})
 return {'id':id,'title':title,'data':f'assets/examples/{id}/data.json','model':f'assets/examples/{id}/model.glb'}

if __name__=='__main__':
 args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
 ids=args or list(DESCS)
 built=[build(id) for id in ids]
 if len(ids)==6:
  catalog_path=ROOT/'assets'/'catalog.json'
  extra=[item for item in json.loads(catalog_path.read_text(encoding='utf-8')) if item['id'] not in DESCS] if catalog_path.exists() else []
  dump(catalog_path,built+extra)
 print('MECHANICAL_BUILD_OK',','.join(ids))
