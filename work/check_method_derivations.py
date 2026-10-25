"""Check sufficient conditions and geometry behind the visible construction steps."""
import json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];APP=ROOT/'机械制图学习'
def load(p):return json.loads(p.read_text(encoding='utf8'))
checks=[]
def check(name,ok):checks.append(dict(check=name,passed=bool(ok)))
def distance(a,b):return math.sqrt(sum((x-y)**2 for x,y in zip(a,b)))
plane=load(APP/'模型/plane_learning.json');intro=plane['scenes']['intro'];groups=plane['concept']
beats={b['id']:b for g in groups for b in g['beats']}
order=[b['id'] for g in groups for b in g['beats']]
# A parallel translation in depth preserves the complete front polygon, but not the other views.
for p in intro['points'].values():
 q=[p[0],p[1]+7,p[2]]
 check('single front cannot determine depth '+str(p),[p[0],p[2]]==[q[0],q[2]] and [p[0],p[1]]!=[q[0],q[1]])
for id,boundary,view in [('projection:front','projection:front-boundary','front'),('projection:other','projection:top-boundary','top'),('projection:side-points','projection:side-boundary','left')]:
 b=beats[id];check(id+' projects known space vertices',b['action']['type']=='space_project' and b['action']['view']==view and b['action']['vertices']==list('ABCD'))
 check(id+' points precede boundary',order.index(id)<order.index(boundary))
 check(id+' boundary does not create hidden endpoints',not beats[boundary]['action'].get('points'))
first=beats['complete:third-endpoints']['action']['targets'][0]
check('reverse transfer first vertex separated',len(beats['complete:third-endpoints']['action']['targets'])==1 and len(beats['complete:third-remaining']['action']['targets'])==2)
task=plane['scenes'][beats['complete:third-endpoints']['scene']];refs=task['refs'];a=task['points']['A']
check('reverse 45 intersection equidistant',abs(abs(refs[first['paths'][1][1]][0])-abs(refs[first['paths'][1][1]][1]))<1e-8)
check('reverse transfer preserves horizontal abscissa and side depth',refs['A_top']==[a[0],a[1]])
q=plane['scenes']['parallel-quad']['points'];A,B,C,D=[q[n] for n in 'ABCD']
check('frontal diagonal supplies same depth',abs(A[1]-C[1])<1e-7)
check('parallelogram B satisfies two parallel constraints',distance(B,[A[i]+C[i]-D[i] for i in range(3)])<1e-7)
check('C constructed before B',order.index('complete:parallel-c')<order.index('complete:parallel-b')<order.index('complete:parallel-complete'))
scenes={p.stem:load(p) for p in (APP/'assets/course_scenes').glob('*.json')}
for id in ['basic_cylinder','basic_cone','basic_sphere']:
 s=scenes[id];p=s['parameters']['surface_point'];line=s['entities']['point_generator']['world'][0]['points']
 check(id+' surface point on displayed construction line',distance(p,line[0])+distance(p,line[-1])-distance(line[0],line[-1])<1e-7)
if True:
 s=scenes['basic_sphere'];p=s['parameters']['surface_point'];q=[p[0],-p[1],p[2]]
 check('front projection alone has two sphere candidates',p!=q and [p[0],p[2]]==[q[0],q[2]])
 check('front hemisphere condition chooses the displayed point',p[1]<0)
for id in ['intersection_inner','intersection_shell']:
 s=scenes[id];pairs=s['parameters']['pairs']
 for key,points in s['parameters']['method_samples'].items():
  R,r=pairs[0 if key=='outer' or id=='intersection_inner' else 1]
  for i,(x,y,z) in enumerate(points):check(id+key+str(i)+' satisfies both actual surfaces',abs(x*x+y*y-r*r)<1e-7 and abs(y*y+z*z-R*R)<1e-7)
s=scenes['combination_slope'];p=s['parameters']['method_corner']
def near_segment(p,a,b):
 d=[b[k]-a[k] for k in range(2)];den=sum(x*x for x in d)
 t=max(0,min(1,sum((p[k]-a[k])*d[k] for k in range(2))/den)) if den else 0
 return distance(p,[a[k]+t*d[k] for k in range(2)])
for view,target in [('front',[p[0],-p[2]]),('top',[p[0],p[1]])]:
 lines=[line['points'] for id,e in s['entities'].items() if id.startswith(view+'_') for line in e.get('paths',{}).get(view,[])]
 check('constructed corner comes from known '+view,min(near_segment(target,a,b) for line in lines for a,b in zip(line,line[1:]))<1e-4)
courses={p.stem:load(p) for p in (APP/'模型/course').glob('*.json')}
shell=[b['id'] for g in courses['intersection_solids']['concept']['groups'] for b in g['beats']]
check('both wall point sets precede curves',shell.index('intersection_solids:shell:outer-points')<shell.index('intersection_solids:shell:inner-points')<shell.index('intersection_solids:shell:connect'))
for c in ['basic_solids','combination']:
 for g in courses[c]['concept']['groups']:
  for b in g['beats']:
   if b['id'].endswith(':point-depth'):check('new derived point waits for action',not b.get('prepare_with_text'))
path=APP/'qa/course-method-geometry.json';path.write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf8')
bad=[c for c in checks if not c['passed']];print(json.dumps({'checks':len(checks),'failures':bad},ensure_ascii=False));assert not bad,bad
