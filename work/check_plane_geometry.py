import json,math,hashlib,itertools,copy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];APP=ROOT/'机械制图学习'
q=json.loads((APP/'模型/plane_questions.json').read_text(encoding='utf-8'));c=json.loads((APP/'模型/plane_learning.json').read_text(encoding='utf-8'))
checks=[]
def check(name,test):
 checks.append(dict(check=name,passed=bool(test)))
 if not test:raise AssertionError(name)
def vsub(a,b):return [x-y for x,y in zip(a,b)]
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def equal(a,b):return max(abs(x-y) for x,y in zip(a,b))<1e-7
def coplane(t):
 p=t['points'];vs=t['vertices'];o=p[vs[0]];n=cross(vsub(p[vs[1]],o),vsub(p[vs[-1]],o));return all(abs(dot(n,vsub(a,o)))<1e-5 for a in p.values())
check('eight_tasks_seven_sources',len(q['tasks'])==8 and len({t['question_id'] for t in q['tasks']})==7)
check('four_methods',len(c['concept'])==4)
for t in q['tasks']:
 check(t['id']+'_coplanar',coplane(t))
 for n,p in t['points'].items():
  for view,expected in [('front',[p[0],p[2]]),('top',[p[0],p[1]]),('left',[-p[1],p[2]])]:check(t['id']+'_'+n+'_'+view,equal(t['refs'][n+'_'+view],expected))
 raw=(ROOT/'学习资料/题集识别'/t['source']['archive']).read_bytes();check(t['id']+'_original_image',(APP/t['source']['image'].removeprefix('res://')).read_bytes()==raw)
 for g in t['groups']:
  for b in g['beats']:
   check(b['id']+'_no_exam_number',not any(x in b['text'] for x in ['第1套','第2套','第3套','t0']))
   check(b['id']+'_has_text',bool(b['text']))
T={t['id']:t for t in q['tasks']}
for id,key,axis,val in [('in-horizontal','M',2,10),('in-horizontal','N',2,10),('in-frontal','M',1,-15),('in-frontal','N',1,-15),('in-point','M',2,15),('in-point','N',2,15),('in-point','P',1,-12),('in-point','P',2,15)]:check(id+key+str(axis),abs(T[id]['points'][key][axis]-val)<1e-8)
check('through_A_height',abs(T['through-vertex']['points']['N'][2]-T['through-vertex']['points']['A'][2])<1e-8)
for id in ['third-edge']:
 t=T[id];a,b,z=[t['refs'][n+'_front'] for n in 'ABC'];check(id+'_front_collapse',abs(cross(vsub([b[0],b[1],0],[a[0],a[1],0]),vsub([z[0],z[1],0],[a[0],a[1],0]))[2])<1e-8)
t=T['parallel-quad'];check('parallelogram_closure',equal(vsub(t['points']['B'],t['points']['A']),vsub(t['points']['C'],t['points']['D'])));check('AC_frontal',abs(t['points']['A'][1]-t['points']['C'][1])<1e-8)
old=next(x for x in json.loads((APP/'模型/line_practice.json').read_text(encoding='utf-8'))['tasks'] if x['id']=='parallelogram');check('shared_existing_parameter',all(equal(p,old['points'][n]) for n,p in t['points'].items()))
t=T['quad-missing'];check('ordinary_quad_not_parallelogram',not equal(vsub(t['points']['B'],t['points']['A']),vsub(t['points']['C'],t['points']['D'])))
e=t['points']['E'];f=t['constraints']['diagonal_fraction'];check('diagonal_intersection',equal(e,[a+f*(b-a) for a,b in zip(t['points']['A'],t['points']['C'])]))
intro=c['scenes']['intro'];edge=c['scenes']['edge-demo'];check('same_face_vertices',intro['vertices']==edge['vertices'])
for a,b in itertools.combinations(intro['vertices'],2):check('rigid_'+a+b,abs(math.dist(intro['points'][a],intro['points'][b])-math.dist(edge['points'][a],edge['points'][b]))<1e-7)
for n in edge['vertices']:
 a,b=[edge['refs'][x+'_front'] for x in ['A','B']];p=edge['refs'][n+'_front'];check('edge_'+n,abs((b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0]))<1e-7)
for g in c['concept']:
 for b in g['beats']:check('concept_'+b['id'],not any(x in b['text'] for x in ['套','t0','x=','y=']))
(APP/'qa/plane-geometry-check.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf-8');print(len(checks),'geometry/source checks')
