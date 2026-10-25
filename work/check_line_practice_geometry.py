"""Independent constraint checks; does not generate or grade student answers."""
import json,math,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];APP=ROOT/'机械制图学习'
def sub(a,b):return [x-y for x,y in zip(a,b)]
def norm(a):return math.sqrt(sum(x*x for x in a))
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def close(a,b):return norm(sub(a,b))<1e-8
def on(p,a,b):return norm(cross(sub(p,a),sub(b,a)))<1e-8
lesson=json.loads((APP/'模型/line_practice.json').read_text(encoding='utf-8'))
T={t['id']:t for t in lesson['tasks']};checks=[]
def check(name,value):
 checks.append(dict(check=name,passed=bool(value)));assert value,name
P=T['horizontal']['points'];d=sub(P['B'],P['A'])
check('horizontal_length_30',abs(norm(d)-30)<1e-8)
check('horizontal_angle_30',abs(math.degrees(math.atan2(abs(d[1]),abs(d[0])))-30)<1e-8)
check('horizontal_left_front_equal_height',d[0]<0 and d[1]<0 and d[2]==0)
P=T['third-height']['points'];check('height_25_on_AB',P['C'][2]==25 and on(P['C'],P['A'],P['B']))
P=T['ratio']['points'];check('ratio_2_3',on(P['C'],P['A'],P['B']) and abs(norm(sub(P['C'],P['A']))/norm(sub(P['B'],P['C']))-2/3)<1e-8)
P=T['through-parallel']['points'];check('parallel',norm(cross(sub(P['T'],P['A']),sub(P['F'],P['E'])))<1e-8)
P=T['through-intersect']['points'];check('intersection_distance_V_10',P['B'][1]==-10 and on(P['B'],P['E'],P['F']))
P=T['parallelogram']['points'];check('parallelogram_closure_and_AC_frontal',close(sub(P['B'],P['A']),sub(P['C'],P['D'])) and P['A'][1]==P['C'][1])
P=T['transversal']['points'];check('transversal_parallel',norm(cross(sub(P['N'],P['M']),sub(P['B'],P['A'])))<1e-8)
check('transversal_two_true_intersections',on(P['M'],P['C'],P['D']) and on(P['N'],P['E'],P['F']))
for t in T.values():
 check(t['id']+'_archive_unchanged',(APP/t['source']['image'].removeprefix('res://')).read_bytes()==(ROOT/'学习资料/题集识别'/t['source']['archive']).read_bytes())
 refs=t['refs'];p=t['points']
 for n,a in p.items():
  check(t['id']+'_'+n+'_projection',refs[n+'_front']==[a[0],a[2]] and refs[n+'_top']==[a[0],a[1]] and ('left' not in t['views'] or refs[n+'_left']==[-a[1],a[2]]))
 ids=[b['id'] for g in t['groups'] for b in g['beats']]
 check(t['id']+'_unique_beats',len(set(ids))==len(ids))
(APP/'qa/line-practice-geometry.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(len(checks),'geometry/source checks passed')
