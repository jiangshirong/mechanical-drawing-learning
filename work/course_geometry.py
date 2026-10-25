"""Shared millimetre geometry for the whole-exam course.

No screen coordinates are used to solve spatial geometry. Drawing conventions
have explicit, separate paths; sampling errors are recorded in each scene.
"""
from math import sin, cos, pi, sqrt, atan2
from pathlib import Path
import json
import sys
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parent/'course_deps'))
from manifold3d import Manifold, CrossSection

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / '机械制图学习'
TAU = 2*pi

def add(a,b): return [x+y for x,y in zip(a,b)]
def sub(a,b): return [x-y for x,y in zip(a,b)]
def mul(a,t): return [x*t for x in a]
def lerp(a,b,t): return add(a,mul(sub(b,a),t))
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def cross(a,b): return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def unit(a): return mul(a,1/max(sqrt(dot(a,a)),1e-12))
def project(p,v): return [p[0],-p[2]] if v=='front' else ([p[0],p[1]] if v=='top' else [-p[1],-p[2]])
def path(points, style='solid', **kw): return dict(points=points,style=style,**kw)
def circle(r,c=(0,0),n=128,start=0,end=TAU):
    return [[c[0]+r*cos(start+(end-start)*i/n),c[1]+r*sin(start+(end-start)*i/n)] for i in range(n+1)]
def circle3(r,z=0,c=(0,0),n=128): return [[x,y,z] for x,y in circle(r,c,n)]
def rect(x,y,w,h): return [[x,y],[x+w,y],[x+w,y+h],[x,y+h],[x,y]]
def tri_quad(a,b,c,d): return [a,b,c,a,c,d]
def lathe(profile,n=96):
    triangles=[]
    for (r0,z0),(r1,z1) in zip(profile,profile[1:]):
        for i in range(n):
            a=TAU*i/n;b=TAU*(i+1)/n
            triangles+=tri_quad([r0*cos(a),r0*sin(a),z0],[r0*cos(b),r0*sin(b),z0],[r1*cos(b),r1*sin(b),z1],[r1*cos(a),r1*sin(a),z1])
    return triangles
def box(lo,hi):
    x,y,z=lo;X,Y,Z=hi
    p=[[x,y,z],[X,y,z],[X,Y,z],[x,Y,z],[x,y,Z],[X,y,Z],[X,Y,Z],[x,Y,Z]]
    tris=[]
    for a,b,c,d in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:tris+=tri_quad(p[a],p[b],p[c],p[d])
    lines=[[p[i],p[j]] for i,j in [(0,1),(1,2),(2,3),(3,0),(4,5),(5,6),(6,7),(7,4),(0,4),(1,5),(2,6),(3,7)]]
    return tris,lines
def sphere(r,n=96,m=48):
    rows=[[[r*sin(pi*j/m)*cos(TAU*i/n),r*sin(pi*j/m)*sin(TAU*i/n),r*cos(pi*j/m)] for i in range(n+1)] for j in range(m+1)]
    return sum((tri_quad(rows[j][i],rows[j][i+1],rows[j+1][i+1],rows[j+1][i]) for j in range(m) for i in range(n)),[])
def transform(points,axis='z',offset=(0,0,0)):
    return [add(p if axis=='z' else ([p[2],p[0],p[1]] if axis=='x' else [p[0],p[2],p[1]]),offset) for p in points]
def clip_mesh(triangles,normal,d,keep_below=True):
    """Clip surface triangles by a plane; close cut with planar triangulation."""
    output=[];boundary=[];sign=1 if keep_below else -1
    for i in range(0,len(triangles),3):
        poly=triangles[i:i+3];cut=[]
        for a,b in zip(poly,poly[1:]+poly[:1]):
            da=(dot(a,normal)-d)*sign;db=(dot(b,normal)-d)*sign
            if da<=1e-8:cut.append(a)
            if (da<0<db) or (db<0<da):
                p=lerp(a,b,da/(da-db));cut.append(p);boundary.append(p)
        for j in range(1,len(cut)-1):output+= [cut[0],cut[j],cut[j+1]]
    unique={tuple(round(x,6) for x in p):p for p in boundary}
    if len(unique)>2:
        pts=list(unique.values());centre=mul([sum(p[k] for p in pts) for k in range(3)],1/len(pts))
        u=unit(cross(normal,[0,0,1] if abs(normal[2])<.9 else [0,1,0]));v=cross(normal,u)
        pts.sort(key=lambda p:atan2(dot(sub(p,centre),v),dot(sub(p,centre),u)))
        for a,b in zip(pts,pts[1:]+pts[:1]):output += [centre,a,b]
    return output

class Scene:
    def __init__(self,id,source=(),layout='dual',views=('front','top','left')):
        self.data=dict(id=id,source_questions=list(source),layout=layout,views=list(views),entities={},parameters={},constraints=[],provenance={'kind':'teaching_geometry','units':'mm','note':'未注尺寸为记录的教学尺度，不作为原题尺寸；投影由同一空间参数计算。'})
    def entity(self,id,world=(),paths=None,mesh=None,visible=True,color='6d9cba',**extra):
        e=dict(world=[path(p) if isinstance(p,list) else p for p in world],paths=paths or {},color=color,initial=1 if visible else 0,**extra)
        if mesh:e['triangles']=mesh
        self.data['entities'][id]=e
        return id
    def spatial(self,id,lines,**kw):
        paths={v:[path([project(p,v) for p in line]) for line in lines] for v in self.data['views']}
        return self.entity(id,lines,paths=paths,**kw)
    def ink(self,id,view,lines,style='solid',**kw):
        return self.entity(id,paths={view:[path(p,style) for p in lines]},**kw)
    def label(self,id,text,at,view='front',**kw):
        label=dict(text=text,at=at,view=view)
        for key in ['size','fixed','rotation']:
            if key in kw:label[key]=kw.pop(key)
        return self.entity(id,labels=[label],**kw)
    def projected(self,id,lines,views=None,**kw):
        return self.entity(id,world=lines,paths={v:[path([project(p,v) for p in line]) for line in lines] for v in (views or self.data['views'])},**kw)
    def save(self):return self.data

def existing_scene(model_id,scene_id=None,section=False):
    d=json.loads((APP/f'assets/examples/{model_id}/data.json').read_text(encoding='utf-8'))
    s=Scene(scene_id or model_id,[d['source']['question_id']]);s.data['parameters']=d['parameters'];s.data['provenance']={'kind':'existing_verified_model','data':f'assets/examples/{model_id}/data.json'}
    s.entity('model',model=f'assets/examples/{model_id}/model.glb')
    for view,details in d['views'].items():
        by={}
        for seg in details['segments']:
            key=(seg.get('feature','body'),seg.get('hidden',False));by.setdefault(key,[]).append(seg)
        for (feature,hidden),segments in by.items():
            merged=[];worlds=[]
            for seg in segments:
                a=[seg['a'][0],-seg['a'][1] if view!='top' else seg['a'][1]];b=[seg['b'][0],-seg['b'][1] if view!='top' else seg['b'][1]]
                if merged and sum((merged[-1][-1][k]-a[k])**2 for k in (0,1))<1e-7 and worlds[-1][-1]==seg.get('world_a'):merged[-1].append(b);worlds[-1].append(seg.get('world_b'))
                else:merged.append([a,b]);worlds.append([seg.get('world_a'),seg.get('world_b')])
            s.ink(f'{view}_{feature}_{"hidden" if hidden else "visible"}',view,merged,'dashed' if hidden else 'solid')
            for line,coords in zip(s.data['entities'][f'{view}_{feature}_{"hidden" if hidden else "visible"}']['paths'][view],worlds):line['world_points']=coords
    if section:
        s.entity('cut_model',model=f'assets/examples/{model_id}/section.glb',visible=False)
        sec=d['section'];s.data['section_source']=sec
    return s

def write_json(path_,value):
    path_.parent.mkdir(parents=True,exist_ok=True)
    def native(item):
        if isinstance(item,np.generic): return item.item()
        if isinstance(item,np.ndarray): return item.tolist()
        raise TypeError(f'Unsupported course value: {type(item).__name__}')
    path_.write_text(json.dumps(value,ensure_ascii=False,separators=(',',':'),default=native),encoding='utf-8')

def mesh_triangles(body):
    mesh=body.to_mesh();vertices=np.asarray(mesh.vert_properties)[:,:3];faces=np.asarray(mesh.tri_verts)
    return np.round(vertices[faces].reshape((-1,3)),6).tolist()

def model_projection(body):
    """Visible/sharp and silhouette edges of a closed, tessellated solid.

    Manifold's BVH ray tests distinguish visible from occluded samples. Smooth
    faceting is excluded by a dihedral threshold; per-view silhouettes remain.
    These are educational approximations, not exact industrial hidden lines.
    """
    mesh=body.to_mesh();verts=np.asarray(mesh.vert_properties)[:,:3];faces=np.asarray(mesh.tri_verts)
    t=verts[faces];normals=np.cross(t[:,1]-t[:,0],t[:,2]-t[:,0]);normals/=np.maximum(np.linalg.norm(normals,axis=1)[:,None],1e-12)
    edges={}
    for i,f in enumerate(faces):
        for a,b in zip(f,[f[1],f[2],f[0]]):edges.setdefault(tuple(sorted((int(a),int(b)))),[]).append(i)
    result={}
    for view,direction in [('front',[0,-1,0]),('top',[0,0,1]),('left',[-1,0,0])]:
        direction=np.array(direction);paths=[]
        for (a,b),adj in edges.items():
            n=normals[adj]
            sharp=len(adj)==1 or np.dot(n[0],n[-1])<.94
            facing=n@direction
            silhouette=min(facing)<-1e-6 and max(facing)>1e-6
            if not sharp and not silhouette:continue
            p,q=verts[a],verts[b]
            if np.linalg.norm(np.array(project(p,view))-project(q,view))<.005:continue
            count=max(1,int(np.ceil(np.linalg.norm(q-p)/1.0)))
            for j in range(count):
                x=p+(q-p)*j/count;y=p+(q-p)*(j+1)/count;mid=(x+y)/2
                hits=body.ray_cast((mid+direction*.04).tolist(),(mid+direction*500).tolist())
                hidden=bool(hits)
                paths.append(path([project(x,view),project(y,view)],'dashed' if hidden else 'solid',world_points=[x.tolist(),y.tolist()]))
        # Merge collinear consecutive samples to reduce payload and draw overhead.
        merged=[]
        for item in paths:
            if merged and merged[-1]['style']==item['style'] and np.linalg.norm(np.array(merged[-1]['points'][-1])-item['points'][0])<1e-5:
                merged[-1]['points'].append(item['points'][1]);merged[-1]['world_points'].append(item['world_points'][1])
            else:merged.append(item)
        result[view]=merged
    return result

def add_body(s,id,body,visible=True,project_views=True,color='6d9cba'):
    assert str(body.status()).endswith('NoError'),body.status()
    s.entity(id,mesh=mesh_triangles(body),visible=visible,color=color)
    if project_views:
        for v,lines in model_projection(body).items():s.entity(id+'_'+v,paths={v:lines},visible=visible)
    s.data.setdefault('solids',{})[id]={'volume':body.volume(),'triangles':body.num_tri(),'projection_sampling_mm':1.0,'ray_offset_mm':.04}
    return id

def cylinder(r,h,axis='z',centre=(0,0,0),inner=0):
    b=Manifold.cylinder(h,r,circular_segments=96)
    if inner:b=b-Manifold.cylinder(h+2,inner,circular_segments=96).translate([0,0,-1])
    if axis=='x':b=b.rotate([0,90,0])
    elif axis=='y':b=b.rotate([90,0,0])
    return b.translate(centre)
