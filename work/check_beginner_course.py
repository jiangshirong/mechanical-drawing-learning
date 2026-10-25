"""Independent geometric checks for teaching evidence added in the review."""
import json,math,hashlib
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1];APP=ROOT/'机械制图学习'
def load(p):return json.loads(p.read_text(encoding='utf8'))
scenes={p.stem:load(p) for p in (APP/'assets/course_scenes').glob('*.json')};checks=[]
def check(name,ok,detail=None):checks.append({'check':name,'passed':bool(ok),'detail':detail})
half=scenes['section_half']['parameters']['half_concept']
check('half cut conserves original material',abs(half['kept_volume']+half['removed_volume']-half['original_volume'])<1e-5)
pts=np.array(scenes['section_half']['entities']['half_removed']['triangles'])
check('removed portion restricted to viewing quarter',np.max(pts[:,0])<1e-5 and np.max(pts[:,1])<1e-5)
s=scenes['basic_cone'];p=np.array(s['parameters']['surface_point']);line=np.array(s['entities']['point_generator']['world'][0]['points'])
check('chosen cone point actually on demonstrated generator',np.linalg.norm(np.cross(p-line[0],line[1]-line[0]))<1e-6)
for id in ['basic_cylinder','basic_cone','basic_sphere']:
    p=scenes[id]['parameters']['surface_point'];check(id+' point faces explanatory camera',p[0]>0 and p[1]<0)
for id in ['intersection_inner','intersection_shell']:
    p=scenes[id]['parameters'];x,y,z=p['demonstration_common_point']
    check(id+' one demonstrated point belongs to both walls',abs(x*x+y*y-p['vertical_radius']**2)<1e-7 and abs(y*y+z*z-p['horizontal_radius']**2)<1e-7)
for id in ['tolerance_perpendicular','tolerance_plane','tolerance_parallel']:
    e=scenes[id]['entities'];outside=e['outside'];inside=e['actual']
    def samples(entity):return np.array(entity.get('triangles') or [p for line in entity.get('world',[]) for p in line['points']])
    column=2 if id.endswith('parallel') else 0;lo,hi=(25,35) if column==2 else (30,40)
    if id.endswith('perpendicular'):
        a=samples(inside);b=samples(outside);a=np.linalg.norm(a[:,:2]-[35,0],axis=1);b=np.linalg.norm(b[:,:2]-[35,0],axis=1)
        check(id+' full axis inside allowed cylinder',np.max(a)<=5)
        check(id+' real violation outside cylinder',np.max(b)>5)
    else:
        a=samples(inside)[:,column];b=samples(outside)[:,column]
        check(id+' entire surface fits',np.min(a)>=lo and np.max(a)<=hi)
        check(id+' real local bulge exceeds boundary',np.max(b)>hi)
for id in ['thread_external','thread_internal']:
    s=scenes[id];pts=np.array(s['entities']['model']['triangles']);radii=np.linalg.norm(pts[:,:2],axis=1)
    check(id+' tooth geometry has actual radial relief',np.any(abs(radii-8)<.001) and np.any(abs(radii-10)<.001))
    for line in s['entities']['helix']['world']:
        for p in line['points'][::64]:
            phase=p[2]/4.2-math.atan2(p[1],p[0])/(2*math.pi)
            check(id+' trace follows helical crest '+str(len(checks)),abs(phase-round(phase))<1e-6)
courses={p.stem:load(p) for p in (APP/'模型/course').glob('*.json')}
for c in ['section','roughness']:
    for g in courses[c]['concept']['groups']:
        for b in g['beats']:
            names=b.get('action',{}).get('parts',{})
            constructs=any((k.startswith('correct_') or k in ['top_edge','base_edge','bore_step','back_top','back_inner']) and v.get('visibility',0)>0 for k,v in names.items())
            if constructs and 'setup' not in b:check(b['id']+' new answer ink waits for D',not b.get('prepare_with_text',False))
for c in courses.values():
    valid={b['id'] for g in c['concept']['groups'] for b in g['beats']}
    for old,new in c['concept'].get('resume_aliases',{}).items():check(old+' migration reaches existing beat',new in valid)
    for g in c['concept']['groups']:
        b=g['beats'][0];check(b['id']+' starts own scene, no prior answer',b.get('setup',{}).get('scene')==g['scene'])
        if b.get('prepare_with_text'):check(b['id']+' preparation hides unknown objects',all(p['visibility']==0 for p in b['setup']['parts'].values()))
legacy=load(APP/'模型/plane_learning.json');ids={b['id'] for g in legacy['concept'] for b in g['beats']}
for old,new in legacy.get('knowledge_resume_aliases',{}).items():check(old+' plane migration',new in ids)
seq=next(b for g in legacy['concept'] for b in g['beats'] if b['id']=='in-point:level')['action']
check('familiar plane construction retains dependencies',seq['type']=='sequence' and [a['type'] for a in seq['actions']]==['line','points','project_points','line'])
path=APP/'qa/course-beginner-geometry.json';path.write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf8')
bad=[c for c in checks if not c['passed']];print(json.dumps({'checks':len(checks),'failures':bad},ensure_ascii=False));assert not bad
