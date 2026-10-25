"""Independent content, construction and engineering-expression checks."""
from course_geometry import *
import re,hashlib
from course_sections import step_body,radial_body,half_body,area_at_y,span_area
from course_gears import involute_outline

checks=[]
def check(name,condition,detail=None):
    checks.append(dict(check=name,passed=bool(condition),detail=detail))
def load(path):return json.loads(path.read_text(encoding='utf8'))
scenes={p.stem:load(p) for p in (APP/'assets/course_scenes').glob('*.json')}
courses={p.stem:load(p) for p in (APP/'模型/course').glob('*.json')}
coverage=load(APP/'模型/course_coverage.json');index=load(ROOT/'学习资料/题集识别/题集索引.json')
check('69 original questions',len(coverage['questions'])==69 and {q['question'] for q in coverage['questions']}=={q['id'] for q in index['questions']})
check('43 source pages',index['source']['sha256']==coverage['source_sha256'])
check('16 registered chapters',len(load(APP/'模型/course_registry.json')['chapters'])==16)
check('all demands have executable methods',all(r['demonstrations'] for q in coverage['questions'] for r in q['requirements']))
check('no unclassified method',all(ref['status']!='待核实' for q in coverage['questions'] for r in q['requirements'] for ref in r['demonstrations']))
for chapter,c in courses.items():
    for lesson in [c['concept']]+[t['lesson'] for t in c['tasks']]:
        ids=[b['id'] for g in lesson['groups'] for b in g['beats']]
        check(lesson['id']+' stable unique IDs',len(ids)==len(set(ids)))
        for g in lesson['groups']:
            es=scenes[g['scene']]['entities']
            for b in g['beats']:
                check(b['id']+' no source narration',not re.search(r't\d\d-q\d\d|第[一二三四五六七八九0-9]+套',b['text']))
                check(b['id']+' anchors resolve',all(k in es for k in b.get('anchor',[])))
                check(b['id']+' explicit evidence record',all(k in b['teaching'] for k in ['learner_question','visual_evidence','resolved_uncertainty']))
                check(b['id']+' action references resolve',all(k in es for k in b.get('action',{}).get('parts',{})))
                for k,p in b.get('action',{}).get('parts',{}).items():
                    if p.get('visibility',0)>0:check(b['id']+' nonempty '+k,any(es[k].get(field) for field in ['paths','world','triangles','model','labels','image','brace']))
for id,s in scenes.items():
    for key,e in s['entities'].items():
        if e.get('triangles'):
            check(id+'/'+key+' finite triangular mesh',len(e['triangles'])%3==0 and np.isfinite(e['triangles']).all())
        for v,paths in e.get('paths',{}).items():
            for i,line in enumerate(paths):
                check(f'{id}/{key}/{v}/{i} finite ink',len(line['points'])>=2 and np.isfinite(line['points']).all())
                if line.get('world_points'):
                    error=max(np.linalg.norm(np.array(project(w,v))-p) for w,p in zip(line['world_points'],line['points']))
                    check(f'{id}/{key}/{v}/{i} projection correspondence',error<.0001,error)
    if s['provenance'].get('sha256'):
        file=ROOT/s['provenance']['source'];check(id+' untouched archive',hashlib.sha256(file.read_bytes()).hexdigest()==s['provenance']['sha256'])

# Analytic intersection equations independently checked at every sampled point.
for name in ['inner','shell']:
    s=scenes['intersection_'+name];errors=[]
    curves=s['entities']['intersection']['world']
    for i,line in enumerate(curves):
        R,r=s['parameters']['pairs'][0 if name=='inner' else i]
        for x,y,z in line['points']:errors.extend([abs(x*x+y*y-r*r),abs(y*y+z*z-R*R)])
    check(name+' intersection on both cylinders',max(errors)<1e-7,max(errors))
shell=scenes['intersection_shell']['entities']['body']['triangles']
top=np.array(shell).reshape((-1,3,3))
caps=top[np.max(abs(top[:,:,2]-50),axis=1)<1e-4]
check('vertical shell bore remains open at top',all(np.linalg.norm(t.mean(axis=0)[:2])>15.9 for t in caps))
for kind in ['sphere','cone','cylinder','prism']:
    s=scenes['cut_'+kind];errors=[]
    for line in s['entities']['intersection']['world']:
        for x,y,z in line['points']:
            if kind=='sphere':errors.append(abs(x*x+y*y+z*z-900))
            elif kind=='cylinder':errors.append(abs(x*x+y*y-900))
            elif kind=='cone':
                radius=30*(x+52)/52 if x<0 else (30 if x<=20 and abs(y*y+z*z-900)<.001 else 19)
                errors.extend([abs(y*y+z*z-radius*radius),abs(z-12)])
            else:errors.append(abs(z-.43*x-28))
    check(kind+' cut curve on surface and section',max(errors)<1e-6,max(errors))
    solids=s['solids'];check(kind+' actual removed material',solids['removed']['volume']>0 and solids['retained']['volume']>0)

# Mesh connectivity and cut material area are independent of playback poses.
full=scenes['section_full'];p=full['parameters'];paths=full['entities']['section_outline']['paths']['front']
for side in ['left','right']:
    x=p[side+'_x'];z=-p[side+'_height']
    check(side+' boss retains rear top rim in full section',any(abs(a[1]-z)<1e-5 and abs(b[1]-z)<1e-5 and min(a[0],b[0])<=x<=max(a[0],b[0]) for line in paths for a,b in zip(line['points'],line['points'][1:])))
x=p['left_x'];z=-p['base_height']
check('removed front base edge not carried across the bore',not any(abs(a[1]-z)<1e-5 and abs(b[1]-z)<1e-5 and min(a[0],b[0])<x<max(a[0],b[0]) for line in paths for a,b in zip(line['points'],line['points'][1:])))
for name,body in [('stepped',step_body()[0]),('rotated',radial_body()[0]),('combined',radial_body(True)[0]),('half',half_body())]:
    check(name+' one connected solid',len(body.decompose())==1)
    check(name+' nonempty section',area_at_y(body,0).area()>0)
    s=scenes['section_'+name]
    check(name+' hatch and contour generated',bool(s['entities']['hatching']['paths']) and bool(s['entities']['section_outline']['paths']))
for name in ['rotated','combined']:
    s=scenes['section_'+name];p=s['parameters']['arm_hole'][:2];d=s['parameters']['arm_distance']
    for t in np.linspace(0,1,11):
        angle=-pi*t/6;q=[p[0]*cos(angle)-p[1]*sin(angle),p[0]*sin(angle)+p[1]*cos(angle)]
        check(f'{name} rigid rotation {t:.1f}',abs(np.linalg.norm(q)-d)<1e-9)
    check(name+' unfolded hole lies on cutting projection plane',abs(q[1])<1e-7 and abs(q[0]+d)<1e-7)

for pair in [False,True]:
    s=scenes['gear_pair' if pair else 'gear_single'];p=s['parameters'];m=p['module'];z=p['teeth']
    for i,teeth in enumerate(z):
        data=np.array(s['entities']['pitch'+str(i)]['paths']['left'][0]['points']);centre=np.array([0,-i*p['centre_distance']])
        check(s['id']+' pitch '+str(i),max(abs(np.linalg.norm(data-centre,axis=1)-m*teeth/2))<1e-7)
        data=np.array(s['entities']['root'+str(i)]['paths']['left'][0]['points'])
        check(s['id']+' root '+str(i),max(abs(np.linalg.norm(data-centre,axis=1)-m*(teeth-2.5)/2))<1e-7)
    if pair:
        check('gear pair centre distance',p['centre_distance']==110 and p['drawing_scale']==.5)
        outlines=[CrossSection([involute_outline(m,n,pi/2 if i==0 else -pi/2+pi/n)]).translate([0,i*110]) for i,n in enumerate(z)]
        interference=(outlines[0]^outlines[1]).area();check('meshing gears do not interpenetrate',interference<.08,interference)

for name in ['bolt','stud']:
    p=scenes['fastener_'+name]['parameters'];check(name+' clearance greater than nominal',p['clearance_diameter']>p['nominal_diameter'])
    if name=='stud':check('stud not at blind drill bottom',p['stud_bottom']>p['thread_depth_floor']>p['drill_tip'])
    check(name+' top view uses nominal outside radius',abs(np.linalg.norm(scenes['fastener_'+name]['entities']['top']['paths']['top'][2]['points'][0])-p['nominal_diameter']/2)<1e-9)
p=scenes['bearing']['parameters'];check('304 given dimensions',p['d']==20 and p['D']==52 and p['B']==15)
p=scenes['shaft_section']['parameters'];check('shaft keyway exact original dimensions',p['shaft_diameter']==17 and p['keyway_width']==5 and p['keyway_depth']==2.9)
for id in ['tolerance_perpendicular','tolerance_plane','tolerance_parallel']:
    s=scenes[id];e=s['entities']['actual'];points=e.get('triangles',[]) or [p for l in e.get('world',[]) for p in l['points']]
    if id.endswith('perpendicular'):valid=all((x-35)**2+y*y<=25 for x,y,z in points)
    elif id.endswith('plane'):valid=all(30<=p[0]<=40 for p in points)
    else:valid=all(25<=p[2]<=35 for p in points)
    check(id+' actual feature within tolerance zone',valid)

write_json(APP/'qa/course-geometry-content.json',checks)
failures=[c for c in checks if not c['passed']]
print(json.dumps({'checks':len(checks),'failures':failures},ensure_ascii=False))
if failures:raise SystemExit(1)
