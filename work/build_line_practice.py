"""Six archived drawings, seven tasks. Coordinates below are measured diagram
positions corrected for shared projection coordinates; not exam dimensions.
Only the horizontal-line task inherits dimensioned model parameters.
"""
import json, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; APP=ROOT/'机械制图学习'
index=json.loads((ROOT/'学习资料/题集识别/题集索引.json').read_text(encoding='utf-8'))
questions={q['id']:q for q in index['questions']}
tasks=[]
def project(p,v): return [p[0],p[2]] if v=='front' else [p[0],p[1]] if v=='top' else [-p[1],p[2]]
def interp(a,b,t):return [x+(y-x)*t for x,y in zip(a,b)]
def face(a,b,axis,value):return interp(a,b,(value-a[axis])/(b[axis]-a[axis]))
def task(id,title,qid,points,lines,views,known_points,known_lines,scale):
 q=questions[qid]
 t=dict(id=id,title=title,question_id=qid,statement=q['task'].split(' (')[0],source=dict(image='res://assets/line_practice/'+qid+'.png',archive=q['regions'][0]['image'],page=q['pages'][0],sha256=index['source']['sha256']),scale_basis=scale,points=points,lines=lines,views=views,known_points=known_points,known_lines=known_lines,refs={},groups=[])
 for name,p in points.items():
  for v in views:t['refs'][name+'_'+v]=project(p,v)
 tasks.append(t);return t
def group(t,id,title):t['groups'].append(dict(id=id,title=title,beats=[]))
def beat(t,id,text,action=None,anchor=None,kind='normal',indicator='highlight',value=''):
 g=t['groups'][-1]
 g['beats'].append(dict(id=t['id']+':'+id,text=text,action=action or {'type':'none'},anchor=anchor or ['O'],callout_kind=kind,indicator=indicator,value=value))
def line(t,id,text,a,b,dashed=False):beat(t,id,text,dict(type='line',id=id,a=a,b=b,dashed=dashed),[a,b])
def point(t,id,text,p,name):beat(t,id,text,dict(type='point',id=id,p=p,name=name),[p])
def ref(t,name,p):t['refs'][name]=p;return name
def problem(t,text):beat(t,'problem',text,{'type':'prepare'},kind='problem')
def cleanup(t,ids):
 if ids:beat(t,'erase-'+'-'.join(ids),'擦去这一步的辅助线。',dict(type='erase',targets=ids),[t['groups'][-1]['beats'][-1]['anchor'][0]])
def transfer(t,name,third=True):
 # Already learned in the point chapter: one continuous action, no micro-pauses.
 a=name+'_top';f=name+'_front';l=name+'_left';p=t['refs'][a];z=t['refs'][f][1]
 j=ref(t,name+'_45',[-p[1],p[1]]);h=ref(t,name+'_height',[max(0,-p[1])+7,z])
 beat(t,name+'-side','补出'+name.lower()+'″。',dict(type='side_point',top=a,front=f,side=l,diagonal=j,height=h,name=name.lower()+'″',duration=2.4),[a,f,l])
def linked(t,names,views):
 for v in views:line(t,'join-'+v+'-'+''.join(names),'连接'+('正面' if v=='front' else '水平' if v=='top' else '侧面')+'投影的端点。',names[0]+'_'+v,names[1]+'_'+v)

params=json.loads((APP/'assets/examples/line/data.json').read_text(encoding='utf-8'))['parameters']
t=task('horizontal','作水平线','t02-q01',{n:params[n] for n in ['A','B']},{'AB':['A','B']},['front','top','left'],[],[],{'kind':'dimensioned_model','model':'line'})
group(t,'A','定位A');problem(t,'已知A的位置，作水平线AB的三面投影。')
guides=[]
for id,text,a,b in [('A-x','A距W面10 mm。',[-10,-12],[-10,22]),('A-z','A距H面15 mm。',[-18,15],[3,15]),('A-y','A距V面5 mm。',[-18,-5],[3,-5])]:
 ref(t,id+'0',a);ref(t,id+'1',b);line(t,id,text,id+'0',id+'1',True);guides.append(id)
 if id=='A-z':point(t,'A-front','标出a′。','A_front','a′')
 if id=='A-y':point(t,'A-top','标出a。','A_top','a')
cleanup(t,guides)
group(t,'top','作水平投影')
beat(t,'length','AB平行H面，可在水平投影上量取30 mm。',anchor=['A_top','B_top'],indicator='brace',value='30 mm')
beat(t,'angle','与V面夹角30°，B在A的左前方。',anchor=['A_top','B_top'],indicator='angle',value='30°')
line(t,'top-direction','从a向左前方画30°方向的辅助线。','A_top','B_top',True)
point(t,'B-top','量取30 mm，标出b。','B_top','b');linked(t,['A','B'],['top']);cleanup(t,['top-direction'])
group(t,'front','补正面投影')
line(t,'B-alignment','从b向上画对应辅助线。','B_top','B_front',True)
line(t,'B-level','B与A等高，从a′画水平辅助线。','A_front','B_front',True)
point(t,'B-front','在交点标出b′。','B_front','b′');linked(t,['A','B'],['front']);cleanup(t,['B-alignment','B-level'])
group(t,'side','补侧面投影');transfer(t,'A');transfer(t,'B');linked(t,['A','B'],['left'])

P={'A':[-34.8,-7.8,5.0],'B':[-10.4,-32.2,32.4]};P['C']=face(P['A'],P['B'],2,25)
t=task('third-height','补投影、按面距取点','t07-q01',P,{'AB':['A','B']},['front','top','left'],['A_front','B_front','A_top','B_top'],['AB_front','AB_top'],{'kind':'diagram_scale','mm_per_source_pixel':.2,'origin_pixel':[508,278],'note':'shared x corrected; not original dimensions'})
group(t,'third','补侧面投影');problem(t,'已知两面投影，补直线AB的侧面投影。');transfer(t,'A');transfer(t,'B');linked(t,['A','B'],['left'])
group(t,'height','按高度取点')
ref(t,'C-level0',[-43,25]);ref(t,'C-level1',[0,25]);line(t,'height-guide','C距H面25 mm，画等高辅助线。','C-level0','C-level1',True)
point(t,'C-front','与a′b′相交，标出c′。','C_front','c′')
line(t,'C-align','从c′向水平投影画对应线。','C_front','C_top',True);point(t,'C-top','在ab上标出c。','C_top','c');cleanup(t,['height-guide','C-align']);transfer(t,'C')

P={'A':[-32.8,-7.4,4.8],'B':[-9.6,-30.2,30]};P['C']=interp(P['A'],P['B'],.4)
t=task('ratio','按比例取点','t05-q01',P,{'AB':['A','B']},['front','top','left'],['A_front','B_front','A_top','B_top'],['AB_front','AB_top'],{'kind':'diagram_scale','mm_per_source_pixel':.2,'origin_pixel':[512,289]})
group(t,'divide','等比分点');problem(t,'已知两面投影，按AC∶CB＝2∶3确定C。')
for i in range(1,5):
 p=interp(t['refs']['A_front'],t['refs']['B_front'],i/5);n=ref(t,'division'+str(i),p)
beat(t,'ticks','将a′b′分成五等份。',dict(type='ticks',points=['division'+str(i) for i in range(1,5)],a='A_front',b='B_front'),['A_front','B_front'])
point(t,'C-front','取从a′起的第二个分点c′。','C_front','c′')
group(t,'transfer','求其余投影');line(t,'C-align','从c′向水平投影画对应线。','C_front','C_top',True);point(t,'C-top','在ab上标出c。','C_top','c');cleanup(t,['C-align']);transfer(t,'C')

P={'A':[-35.8,-12,11.9],'E':[-25.4,-8.4,8.5],'F':[-11.2,-17.5,17.5]}
P['T']=[P['A'][i]+P['F'][i]-P['E'][i] for i in range(3)]
P['B']=face(P['E'],P['F'],1,-10)
for mode in ['parallel','intersect']:
 t=task('through-'+mode,'过点作'+('平行线' if mode=='parallel' else '相交线'),'t04-q02',P,{'EF':['E','F']},['front','top'],['A_front','A_top','E_front','E_top','F_front','F_top'],['EF_front','EF_top'],{'kind':'diagram_scale','mm_per_source_pixel':.1,'origin_pixel':[780,323]})
 t['subquestion']=1 if mode=='parallel' else 2
 group(t,'construct','作'+('平行线' if mode=='parallel' else '相交线'));problem(t,'过已知A作EF的'+('平行线。' if mode=='parallel' else '相交线，交点B距V面10 mm。'))
 if mode=='parallel':
  line(t,'parallel-front','过a′画e′f′的平行线。','A_front','T_front');line(t,'parallel-top','过a画ef的平行线。','A_top','T_top')
 else:
  ref(t,'B-level0',[-31,-10]);ref(t,'B-level1',[0,-10]);line(t,'B-distance','在距X轴10 mm处画水平辅助线。','B-level0','B-level1',True)
  point(t,'B-top','与ef相交，标出b。','B_top','b');line(t,'B-align','从b求正面投影b′。','B_top','B_front',True);point(t,'B-front','在e′f′上标出b′。','B_front','b′');linked(t,['A','B'],['front','top']);cleanup(t,['B-distance','B-align'])

P={'A':[-70.6,-28,29.4],'C':[-6.4,-28,47.2],'D':[-40.2,-19.6,17.6]};P['B']=[P['A'][i]+P['C'][i]-P['D'][i] for i in range(3)]
t=task('parallelogram','补平行四边形投影','t02-q02',P,{'AB':['A','B'],'BC':['B','C'],'CD':['C','D'],'DA':['D','A']},['front','top'],[n+'_'+v for n in P for v in (['front','top'] if n in ['A','D'] else ['front'])],['AB_front','BC_front','CD_front','DA_front','DA_top'],{'kind':'diagram_scale','mm_per_source_pixel':.2,'origin_pixel':[724,412],'note':'front parallelogram closure corrected'})
group(t,'C','求c');problem(t,'已知AC为正平线，补齐水平投影。')
line(t,'C-height','AC两端距V相同，过a画水平辅助线。','A_top','C_top',True);line(t,'C-align','从c′向下画对应线。','C_front','C_top',True);point(t,'C-top','在交点标出c。','C_top','c');cleanup(t,['C-height','C-align'])
group(t,'B','求b并连线')
line(t,'B-guide1','过a画dc的平行辅助线。','A_top','B_top',True);line(t,'B-guide2','过c画ad的平行辅助线。','C_top','B_top',True);point(t,'B-top','在交点标出b。','B_top','b');linked(t,['A','B'],['top']);linked(t,['B','C'],['top']);linked(t,['C','D'],['top']);cleanup(t,['B-guide1','B-guide2'])

P={'A':[-50.25,-16.65,5.4],'B':[-37.35,-3,12.15],'C':[-23.25,-24.3,7.65],'D':[-23.25,-9.3,7.65],'E':[-10.35,-6.75,20.55],'F':[-10.35,-6.75,4.5]}
d=[P['B'][i]-P['A'][i] for i in range(3)];lam=(P['E'][0]-P['C'][0])/d[0]
P['M']=[P['C'][0],P['E'][1]-lam*d[1],P['C'][2]];P['N']=[P['E'][0],P['E'][1],P['M'][2]+lam*d[2]]
t=task('transversal','平行并与两线相交','t03-q02',P,{'AB':['A','B'],'CD':['C','D'],'EF':['E','F']},['front','top'],[n+'_'+v for n in ['A','B','C','D','E','F'] for v in ['front','top']],['AB_front','AB_top','CD_front','CD_top','EF_front','EF_top'],{'kind':'diagram_scale','mm_per_source_pixel':.15,'origin_pixel':[720,198]})
group(t,'front','从正面求交点');problem(t,'作MN平行AB，并与CD、EF相交。')
point(t,'M-front','CD的正面投影积聚，m′在此处。','M_front','m′');line(t,'front-guide','过m′作a′b′的平行辅助线。','M_front','N_front',True);point(t,'N-front','与e′f′相交，标出n′。','N_front','n′')
group(t,'top','求水平投影')
point(t,'N-top','EF的水平投影积聚，n在此处。','N_top','n');line(t,'top-guide','过n作ab的平行辅助线。','N_top','M_top',True);point(t,'M-top','与cd相交，标出m。','M_top','m');linked(t,['M','N'],['front','top']);cleanup(t,['front-guide','top-guide'])

for t in tasks:
 t['refs']['O']=[0,0]
 # Bounds include construction paths; origin conversion remains the shared one.
 xy=list(t['refs'].values());t['bounds']=[min(p[0] for p in xy)-14,min(p[1] for p in xy)-14,max(p[0] for p in xy)+14,max(p[1] for p in xy)+14]
 target=APP/'assets/line_practice'/ (t['question_id']+'.png');target.parent.mkdir(parents=True,exist_ok=True)
 target.write_bytes((ROOT/'学习资料/题集识别'/t['source']['archive']).read_bytes())
out=dict(schema_version=1,chapter_id='line',presentation=dict(characters_per_second=16,punctuation_pause=.18),tasks=tasks)
(APP/'模型/line_practice.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(dict(tasks=len(tasks),beats=sum(len(g['beats']) for t in tasks for g in t['groups'])))
