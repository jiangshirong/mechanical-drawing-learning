"""Seven archived plane questions. Unknown geometry is solved from constraints.
The common 0.15 mm/pixel diagram scale is teaching scale, never an exam dimension.
Known pixel readings are retained separately from calibrated coordinates.
"""
import copy, json, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; APP=ROOT/'机械制图学习'
INDEX=json.loads((ROOT/'学习资料/题集识别/题集索引.json').read_text(encoding='utf-8'))
Q={q['id']:q for q in INDEX['questions']}
SCALE=.15
def sub(a,b):return [x-y for x,y in zip(a,b)]
def add(a,b):return [x+y for x,y in zip(a,b)]
def mul(a,t):return [x*t for x in a]
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def lerp(a,b,t):return add(a,mul(sub(b,a),t))
def project(p,v):return [p[0],p[2]] if v=='front' else [p[0],p[1]] if v=='top' else [-p[1],p[2]]
def face(a,b,axis,value):return lerp(a,b,(value-a[axis])/(b[axis]-a[axis]))
def line_hit(a,b,c,d):
 u=sub(b,a);v=sub(d,c);w=sub(c,a);den=u[0]*v[1]-u[1]*v[0]
 t=(w[0]*v[1]-w[1]*v[0])/den
 return lerp(a,b,t),t
def reading(x,z,y):return [x*SCALE,y*SCALE,z*SCALE]
tasks=[]
def task(id,title,qid,points,vertices,known,views=('front','top'),statement=None,raw=None):
 q=Q[qid]
 t=dict(id=id,title=title,question_id=qid,statement=statement or q['heading'],source=dict(page=q['pages'][0],archive=q['regions'][0]['image'],image='res://assets/plane_questions/'+qid+'.png',sha256=INDEX['source']['sha256'],original_text=q['task']),scale_basis=dict(kind='teaching_scale',mm_per_pixel=SCALE,known_pixel_readings=raw or {},note='无尺寸端点按原图统一教学尺度重绘，待求结果由约束求解；不作为原题尺寸。'),points=points,vertices=vertices,lines={},known_points=[],known_lines=[],known_guides=[],views=list(views),refs={'O':[0,0]},groups=[])
 for n,p in points.items():
  for v in ['front','top','left']:t['refs'][n+'_'+v]=project(p,v)
 for i,n in enumerate(vertices):t['lines'][n+vertices[(i+1)%len(vertices)]]=[n,vertices[(i+1)%len(vertices)]]
 for v,names in known.items():
  t['known_points'] += [n+'_'+v for n in names]
  for line,ends in t['lines'].items():
   if all(n in names for n in ends):t['known_lines'].append(line+'_'+v)
 for n in vertices:
  if n+'_front' in t['known_points']:
   for v in ['top','left']:
    if n+'_'+v in t['known_points']:t['known_guides'].append([n+'_front',n+'_'+v])
 tasks.append(t);return t
def group(t,id,title):t['groups'].append(dict(id=id,title=title,beats=[]))
def beat(t,id,text,action=None,anchor=None,kind='normal',indicator='highlight',value=''):
 t['groups'][-1]['beats'].append(dict(id=t['id']+':'+id,text=text,action=action or {'type':'none'},anchor=anchor or ['O'],callout_kind=kind,indicator=indicator,value=value))
def ref(t,id,p):t['refs'][id]=p;return id
def problem(t,text):beat(t,'problem',text,dict(type='prepare',duration=1.8),t['known_points'][:2],kind='problem')
def line(t,id,text,a,b,dashed=False,**kw):beat(t,id,text,dict(type='line',id=id,a=a,b=b,dashed=dashed),[a,b],**kw)
def points(t,id,text,refs):beat(t,id,text,dict(type='points',points=[dict(ref=r,name=r.split('_')[0].lower()+{'front':'′','top':'','left':'″'}[r.split('_')[1]]) for r in refs]),refs)
def project_points(t,id,text,refs):
 targets=[]
 for target in refs:
  n,v=target.split('_');dest=t['refs'][target]
  if v=='top' and n+'_left' in t['known_points']:
   diag=ref(t,n+'45',[-t['points'][n][1],t['points'][n][1]])
   paths=[[n+'_front',target],[n+'_left',diag],[diag,target]]
  else:paths=[[n+('_front' if v=='top' else '_top'),target],[target,target],[target,target]]
  targets.append(dict(ref=target,name=n.lower()+{'front':'′','top':'','left':'″'}[v],paths=paths))
 beat(t,id,text,dict(type='project_points',targets=targets,duration=2.4),[x for k in targets for x in [k['paths'][0][0],k['ref']]])
def outline(t,id,text,paths,point_refs=None):
 beat(t,id,text,dict(type='outline',paths=paths,points=[dict(ref=r,name=r.split('_')[0].lower()+{'front':'′','top':'','left':'″'}[r.split('_')[1]]) for r in point_refs or []]),[r for p in paths for r in p])
def erase(t,ids,point_refs=()):beat(t,'erase-'+'-'.join(ids),'擦去辅助线。',dict(type='erase',targets=ids,points=list(point_refs)),t['groups'][-1]['beats'][-1]['anchor'])
def cut(t,axis,value,names=('M','N')):
 hits=[]
 for i,n in enumerate(t['vertices']):
  a=t['points'][n];b=t['points'][t['vertices'][(i+1)%len(t['vertices'])]]
  if (a[axis]-value)*(b[axis]-value)<0:hits.append(face(a,b,axis,value))
 assert len(hits)==2,(t['id'],hits)
 for n,p in zip(names,hits):
  t['points'][n]=p
  for v in ['front','top','left']:t['refs'][n+'_'+v]=project(p,v)
 return hits
def cut_steps(t,axis,value,through=False,temporary=False):
 v='front' if axis==2 else 'top';other='top' if v=='front' else 'front'
 p,q=t['points']['M'],t['points']['N']
 ends=sorted([project(p,v),project(q,v)]);y=value
 a=ref(t,'level0',[min(ends[0][0],ends[1][0])-5,y]);b=ref(t,'level1',[max(ends[0][0],ends[1][0])+5,y])
 z=ref(t,'distance0',[t['refs'][a][0],0])
 line(t,'level','过a′画水平辅助线。' if through else ('距H面%d mm。'%value if axis==2 else '距V面%d mm。'%abs(value)),a,b,True,indicator='brace' if not through else 'highlight',value=str(abs(value))+' mm')
 if not through:t['groups'][-1]['beats'][-1]['anchor']=[z,a]
 points(t,'intersections','标出边界上的两个交点。',['M_'+v,'N_'+v])
 group(t,'other-view','求另一面投影')
 project_points(t,'other-points','求两交点的另一面投影。',['M_'+other,'N_'+other])
 line(t,'joined','连接两交点。','M_'+other,'N_'+other,temporary)
 if not temporary:erase(t,['level'])

# Known front/side figure readings; B's front abscissa is calibrated onto the
# explicitly collinear projection in t05. Other known coordinates remain read.
raw5={'A':[-141,136,-92],'B':[None,78,-194],'C':[-18,39,-34]}
a=reading(*raw5['A']);c=reading(*raw5['C']);b=face(a,c,2,78*SCALE);b[1]=-194*SCALE
t=task('third-edge','补第三投影：正面积聚','t05-q02',{'A':a,'B':b,'C':c},list('ABC'),{'front':list('ABC'),'left':list('ABC')},('front','top','left'),statement='已知平面的正面、侧面投影，补出水平投影。',raw=raw5)
t['constraints']={'front_collinear':True}
group(t,'vertices','补顶点');problem(t,'已知正面、侧面投影，补水平投影。')
for n in 'ABC':project_points(t,n+'-top','补出'+n.lower()+'。',[n+'_top'])
group(t,'boundary','连接边界');outline(t,'close','连接a、b、c。',[[n+'_top',m+'_top'] for n,m in [('A','B'),('B','C'),('C','A')]])

raw6={'A':[-118,153,-57],'B':[-170,33,-143],'C':[-44,63,-33]}
t=task('third-general','补第三投影：一般情况','t06-q02',{n:reading(*p) for n,p in raw6.items()},list('ABC'),{'front':list('ABC'),'left':list('ABC')},('front','top','left'),statement='已知平面的正面、侧面投影，补出水平投影。',raw=raw6)
group(t,'vertices','补顶点');problem(t,'已知正面、侧面投影，补水平投影。')
for n in 'ABC':project_points(t,n+'-top','补出'+n.lower()+'。',[n+'_top'])
group(t,'boundary','连接边界');outline(t,'close','连接a、b、c。',[[n+'_top',m+'_top'] for n,m in [('A','B'),('B','C'),('C','A')]])

raw3={'A':[-198,237,-125],'B':[-290,50,-6],'C':[-36,100,-9]}
t=task('in-horizontal','面内作水平线','t03-q01',{n:reading(*p) for n,p in raw3.items()},list('ABC'),{'front':list('ABC'),'top':list('ABC')},statement='在平面ABC内作一条水平线，使其距H面10 mm。',raw=raw3)
cut(t,2,10);t['constraints']={'constant_axis':2,'value':10}
group(t,'known','定位交点');problem(t,'在平面ABC内作水平线，距H面10 mm。');cut_steps(t,2,10)

raw8={'A':[-300,109,-108],'B':[-128,45,-45],'C':[-30,198,-197]}
for id,title,through in [('in-frontal','面内作正平线',False),('through-vertex','过顶点作水平线',True)]:
 t=task(id,title,'t08-q03',{n:reading(*p) for n,p in raw8.items()},list('ABC'),{'front':list('ABC'),'top':list('ABC')},statement='在平面ABC内作距V面15 mm的正平线。' if not through else '在平面ABC内过顶点A作水平线。',raw=raw8)
 t['source']['subpart']=2 if through else 1
 if through:
  n=face(t['points']['B'],t['points']['C'],2,t['points']['A'][2]);t['points']['M']=t['points']['A'].copy();t['points']['N']=n
  for key in ['M','N']:
   for v in ['front','top','left']:t['refs'][key+'_'+v]=project(t['points'][key],v)
  t['constraints']={'constant_axis':2,'value':t['points']['A'][2],'through':'A'}
 else:cut(t,1,-15);t['constraints']={'constant_axis':1,'value':-15}
 group(t,'known','定位交点');problem(t,'过平面ABC的顶点A作水平线。' if through else '在平面ABC内作正平线，距V面15 mm。')
 cut_steps(t,2 if through else 1,t['points']['A'][2] if through else -15,through)
 if through:
  # M is A, retain the given label instead of drawing a second coincident point.
  for g in t['groups']:
   for b in g['beats']:
    if b['action']['type']=='points':b['action']['points']=[x for x in b['action']['points'] if not x['ref'].startswith('M_')]
    if b['action']['type']=='project_points':b['action']['targets']=[x for x in b['action']['targets'] if not x['ref'].startswith('M_')];b['text']='求交点的水平投影。'

raw4={'A':[-210,200,-149],'B':[-297,18,-30],'C':[-50,63,-37]}
t=task('in-point','按两项面距取点','t04-q01',{n:reading(*p) for n,p in raw4.items()},list('ABC'),{'front':list('ABC'),'top':list('ABC')},statement='在平面ABC内作一点，使其距H面15 mm、距V面12 mm。',raw=raw4)
m,n=cut(t,2,15);t['points']['P']=face(m,n,1,-12)
for v in ['front','top','left']:t['refs']['P_'+v]=project(t['points']['P'],v)
t['constraints']={'point':'P','height':15,'depth':12}
group(t,'height','作面内辅助线');problem(t,'在平面ABC内，按两项面距确定点P。');cut_steps(t,2,15,temporary=True)
group(t,'point','定位P')
ref(t,'depth0',[min(m[0],n[0])-5,-12]);ref(t,'depth1',[max(m[0],n[0])+5,-12]);ref(t,'depthAxis',[t['refs']['depth0'][0],0])
line(t,'depth','距V面12 mm。','depth0','depth1',True,indicator='brace',value='12 mm');t['groups'][-1]['beats'][-1]['anchor']=['depthAxis','depth0']
points(t,'P-top','在交点标出p。',['P_top']);project_points(t,'P-front','求p′。',['P_front'])
erase(t,['level','joined','depth'],['M_front','N_front','M_top','N_top'])

raw1={'A':[-254,103,-145],'B':[-163,207,-205],'C':[-12,170,None],'D':[-54,42,-51]}
pts={n:reading(*p) for n,p in raw1.items() if n!='C'}
cf=[raw1['C'][0]*SCALE,raw1['C'][1]*SCALE]
ef,fraction=line_hit(project(pts['A'],'front'),cf,project(pts['B'],'front'),project(pts['D'],'front'))
_,bd_fraction=line_hit(project(pts['B'],'front'),project(pts['D'],'front'),project(pts['A'],'front'),cf)
pts['E']=lerp(pts['B'],pts['D'],bd_fraction);pts['C']=add(pts['A'],mul(sub(pts['E'],pts['A']),1/fraction))
t=task('quad-missing','补四边形投影','t01-q02',pts,list('ABCD'),{'front':list('ABCD'),'top':list('ABD')},statement='已知平面四边形ABCD的正面投影及部分水平投影，补全水平投影。',raw=raw1)
t['known_lines']=[x for x in t['known_lines'] if x!='DA_top' and x!='AB_top']+['DA_top','AB_top']
t['constraints']={'coplanar':'ABCD','diagonal_fraction':fraction,'bd_fraction':bd_fraction}
group(t,'intersection','确定对角线交点');problem(t,'给出平面四边形ABCD，补全水平投影。')
line(t,'AC-front','画对角线a′c′。','A_front','C_front',True);line(t,'BD-front','画对角线b′d′。','B_front','D_front',True);points(t,'E-front','标出交点e′。',['E_front'])
group(t,'carrier','作承载线');line(t,'BD-top','连接b、d，作为辅助线。','B_top','D_top',True);project_points(t,'E-top','求交点e。',['E_top'])
ref(t,'carrierEnd',project(lerp(pts['A'],pts['C'],1.12),'top'));line(t,'AC-top','过a、e画辅助线。','A_top','carrierEnd',True)
group(t,'boundary','补顶点和边界');project_points(t,'C-top','在对应位置确定c。',['C_top']);outline(t,'close','连接b、c、d。',[['B_top','C_top'],['C_top','D_top']]);erase(t,['AC-front','BD-front','BD-top','AC-top'],['E_front','E_top'])

line_source=json.loads((APP/'模型/line_practice.json').read_text(encoding='utf-8'))
old=next(x for x in line_source['tasks'] if x['id']=='parallelogram')
p=copy.deepcopy(old['points']);p['B']=sub(add(p['A'],p['C']),p['D'])
t=task('parallel-quad','补平行四边形投影','t02-q02',p,list('ABCD'),{'front':list('ABCD'),'top':list('AD')},statement='已知AC为正平线，补全平行四边形ABCD的水平投影。')
t['scale_basis']=copy.deepcopy(old['scale_basis']);t['scale_basis']['geometry_source']='模型/line_practice.json#parallelogram'
t['constraints']={'parallelogram':'ABCD','AC_frontal':True}
t['refs'].update(copy.deepcopy(old['refs']));t['groups']=copy.deepcopy(old['groups'])
for g in t['groups']:
 for b in g['beats']:b['id']=b['id'].replace('parallelogram:','parallel-quad:')

def finalize(t):
 # Add actual projection coordinates only by projecting the one space dataset.
 for n,p in t['points'].items():
  for v in ['front','top','left']:t['refs'][n+'_'+v]=project(p,v)
 coords=list(t['refs'].values());lo=[min(p[i] for p in coords) for i in range(2)];hi=[max(p[i] for p in coords) for i in range(2)]
 t['bounds']=[lo[0]-7,lo[1]-7,hi[0]+7,hi[1]+7]
 if 'left' not in t['views']:
  used=[p for k,p in t['refs'].items() if not k.endswith('_left')];t['bounds']=[min(x[0] for x in used)-7,min(x[1] for x in used)-7,max(x[0] for x in used)+7,max(x[1] for x in used)+7]
 return t
for t in tasks:
 t['statement']={
  't01-q02':'作平面四边形ABCD的投影。',
  't02-q02':'已知直线AC为正平线，试补全平行四边形ABCD的水平投影。',
  't03-q01':'在平面ABC内作一条水平线，使其到H面的距离为10 mm。',
  't04-q01':'在平面ABC内作一点，使其到H面的距离为15 mm，到V面的距离为12 mm。',
  't05-q02':'已知平面的两面投影，完成其第三面投影。',
  't06-q02':'已知平面的两面投影，完成其第三面投影。',
  't08-q03':'在△ABC平面上作一距V面15 mm的正平线，并过顶点A作一水平线。'
 }[t['question_id']]
 finalize(t)

# Four method groups, using the same solved questions as geometry sources.
concept=[];scenes={t['id']:copy.deepcopy(t) for t in tasks}
def section(id,title):g=dict(id=id,title=title,beats=[]);concept.append(g);return g
def cb(g,scene,id,text,action=None,anchor=None,kind='normal'):
 g['beats'].append(dict(id=g['id']+':'+id,scene=scene,text=text,action=action or {'type':'none'},anchor=anchor or ['O'],callout_kind=kind,indicator='highlight',value=''))
original=json.loads((APP/'assets/examples/plane/data.json').read_text(encoding='utf-8'))['parameters']['points_teaching_mm']
intro=copy.deepcopy(tasks[-1]);intro.update(id='intro',points=original,groups=[],known_lines=[],known_points=[],known_guides=[],views=['front','top','left'],refs={'O':[0,0]});finalize(intro);scenes['intro']=intro
g=section('projection','平面的投影')
cb(g,'intro','surface','已知空间平面 ABCD，分别求它的三面投影。',dict(type='none'),['A_front','B_front'])
for view,point_id,boundary_id,plane,label in [('front','front','front-boundary','V','正面'),('top','other','top-boundary','H','水平'),('left','side-points','side-boundary','W','侧面')]:
 cb(g,'intro',point_id,'向 '+plane+' 面作垂线，依次得到'+label+'投影点。',dict(type='space_project',view=view,vertices=list('ABCD'),duration=4.8),['A_'+view,'C_'+view])
 cb(g,'intro',boundary_id,'按 A—B—C—D 的顺序连边，得到'+label+'投影。',dict(type='outline',paths=[[x+'_'+view,y+'_'+view] for x,y in [('A','B'),('B','C'),('C','D'),('D','A')]]),['A_'+view,'C_'+view])
# Rotate the current four-vertex face rigidly into an edge-on front projection.
# The exam supplies the collapsed-front case; this orientation remains a teaching example.
edge=copy.deepcopy(intro);edge['id']='edge-demo'
origin=original['A'];vx=sub(original['B'],origin);vx=mul(vx,1/math.sqrt(dot(vx,vx)))
normal=cross(vx,sub(original['D'],origin));normal=mul(normal,1/math.sqrt(dot(normal,normal)));vy=cross(normal,vx)
ex=[vx[0],0,vx[2]];ex=mul(ex,1/math.sqrt(dot(ex,ex)));ey=[0,-1,0]
edge['points']={n:add(origin,add(mul(ex,dot(sub(p,origin),vx)),mul(ey,dot(sub(p,origin),vy)))) for n,p in original.items()}
edge['known_points']=[n+'_'+v for v in ['front','top','left'] for n in 'ABCD'];edge['known_lines']=[l+'_'+v for v in ['front','top','left'] for l in edge['lines']]
edge['known_guides']=[];edge['constraints']={'front_collinear':True,'rigid_source':'intro','scope_source':'t05-q02'};scenes['edge-demo']=edge
cb(g,'edge-demo','edge-on','转到垂直V面的位置，正面投影积聚成线。',dict(type='prepare',duration=2.4),['A_front','C_front'])
cb(g,'edge-demo','vertices','积聚后，各顶点仍分别对应。',anchor=['A_front','B_front','C_front'])

g=section('in-line','面内作线');base=scenes['in-horizontal']
for group_data in base['groups']:
 for b in group_data['beats']:
  c=copy.deepcopy(b);c['id']='in-line:'+b['id'].split(':',1)[1];c['scene']='in-horizontal'
  if c['action']['type']=='prepare':c['text']='给出平面ABC，按已知面距在面内作线。'
  g['beats'].append(c)
# Compact V-distance comparison on the same triangle, not a second full lesson.
cut(base,1,-15,('F','G'));finalize(base)
cb(g,'in-horizontal','frontal','给定距V面的距离，从水平投影入手。',dict(type='outline',paths=[['F_top','G_top'],['F_front','G_front']],points=[dict(ref=n+'_'+v,name=n.lower()+('′' if v=='front' else '')) for v in ['top','front'] for n in ['F','G']]),['F_top','G_top'])

g=section('in-point','面内取点')
for part in scenes['in-point']['groups']:
 for b in part['beats']:
  c=copy.deepcopy(b);c['id']='in-point:'+b['id'].split(':',1)[1];c['scene']='in-point';g['beats'].append(c)
g=section('complete','补全面投影')
cb(g,'third-general','third-problem','只给正面、侧面投影，补出水平投影。',dict(type='prepare',duration=1.8),['A_front','A_left'],kind='problem')
transfers=[b['action'] for part in scenes['third-general']['groups'] for b in part['beats'] if b['action']['type']=='project_points']
cb(g,'third-general','third-endpoints','转移各顶点的水平投影。',dict(type='project_points',targets=[target for a in transfers for target in a['targets']],duration=3.6),['A_front','C_left'])
cb(g,'third-general','third-boundary','连接顶点，补出边界。',dict(type='outline',paths=[[x+'_top',y+'_top'] for x,y in [('A','B'),('B','C'),('C','A')]]),['A_top','C_top'])
for part in scenes['quad-missing']['groups']:
 for b in part['beats']:
  c=copy.deepcopy(b);c['id']='complete:'+b['id'].split(':',1)[1];c['scene']='quad-missing';g['beats'].append(c)
cb(g,'parallel-quad','parallel-context','若给出平行四边形，可利用对边平行补点。',dict(type='prepare',duration=2.4),['A_front','C_front'])
cb(g,'parallel-quad','parallel-complete','利用正平线和对边平行，补出顶点。',dict(type='outline',paths=[['A_top','B_top'],['B_top','C_top'],['C_top','D_top']],points=[dict(ref=n+'_top',name=n.lower()) for n in ['B','C']]),['A_top','C_top'])

for t in scenes.values():finalize(t)
assert len(tasks)==8 and len({t['question_id'] for t in tasks})==7
all_ids=[b['id'] for g in concept for b in g['beats']];assert len(set(all_ids))==len(all_ids)
source=dict(pdf_sha256=INDEX['source']['sha256'],questions=[dict(id=qid,text=Q[qid]['task'],image=Q[qid]['regions'][0]['image'],page=Q[qid]['pages'][0]) for qid in dict.fromkeys(t['question_id'] for t in tasks)])
for qid in dict.fromkeys(t['question_id'] for t in tasks):
 image=ROOT/'学习资料/题集识别'/Q[qid]['regions'][0]['image'];out=APP/'assets/plane_questions'/str(qid+'.png');out.parent.mkdir(exist_ok=True);out.write_bytes(image.read_bytes())
for name,data in [('plane_questions',dict(schema_version=1,chapter_id='plane',source=source,tasks=tasks)),('plane_learning',dict(schema_version=1,chapter_id='plane',source=source,concept=concept,scenes=scenes,presentation=dict(characters_per_second=16,punctuation_pause=.18)))]:
 if name=='plane_learning':
  from review_legacy_concepts import revise
  revise(data,'plane')
 (APP/'模型'/str(name+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(dict(tasks=len(tasks),question_beats=sum(len(g['beats']) for t in tasks for g in t['groups']),concept_groups=len(concept),concept_beats=sum(len(g['beats']) for g in concept)))
