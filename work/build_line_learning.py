"""Author exam-scoped knowledge. Coordinates of supplemental scenes are teaching parameters."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / '机械制图学习'
index = json.loads((ROOT/'学习资料/题集识别/题集索引.json').read_text(encoding='utf-8'))
sources = ['t02-q01','t02-q02','t03-q02','t04-q02','t05-q01','t06-q01','t07-q01','t07-q02','t08-q02']
scenes = {}
def scene(name, points, lines, visible=None, drawn=(), derived=None, **extra):
    scenes[name] = dict(points=points, lines=lines, visible_points=visible if visible is not None else list(points), initial_lines=list(drawn), derived=derived or {}, provenance='teaching_example', **extra)
scene('bridge',{}, {'AB':['A','B']}, ['A','B'], parameter_source='points')
scene('third',{}, {'AB':['A','B']}, ['A','B'], ['AB'], parameter_source='points', known_views=['space','front','top'])
scene('horizontal',{}, {'AB':['A','B']}, ['A','B'], parameter_source='line')
scene('frontal',{'A':[-10,-12,12],'B':[-38,-12,34]}, {'AB':['A','B']})
scene('normal_H',{'A':[-18,-14,10],'B':[-18,-14,38]}, {'AB':['A','B']})
scene('normal_V',{'A':[-18,-6,24],'B':[-18,-34,24]}, {'AB':['A','B']})
general = {'A':[-10,-5,15],'B':[-40,-25,35]}
for name,axis,value in [('height','z',25),('distance_V','y',-10)]:
    scene(name,general,{'AB':['A','B'],'guide':['G0','G1']},['A','B'],['AB'],derived={
        'C':{'type':'face_point','line':'AB','axis':axis,'value':value},
        'G0':{'type':'level_start','point':'C','axis':axis},
        'G1':{'type':'axis_foot','point':'C','axis':axis}})
scene('ratio',general,{'AB':['A','B']},['A','B'],['AB'],derived={'C':{'type':'fraction','line':'AB','value':.4}})
ef = {'E':[-12,-8,10],'F':[-32,-22,30],'A':[-8,-26,12]}
scene('parallel',ef,{'EF':['E','F'],'AB':['A','B']},['A','E','F'],['EF'],derived={'B':{'type':'parallel_end','origin':'A','line':'EF'}})
scene('parallelogram',{'A':[-10,-12,10],'C':[-40,-12,30],'D':[-20,-6,6]}, {'AD':['A','D'],'DC':['D','C'],'AB':['A','B'],'BC':['B','C']},['A','C','D'],['AD','DC'],derived={'B':{'type':'parallelogram','a':'A','c':'C','d':'D'}})
scene('parallel_false',dict(ef,B=[-28,-16,32]),{'EF':['E','F'],'AB':['A','B']},drawn=['EF','AB'],known_views=['space','front'])
ab = {'A':[-10,-10,10],'B':[-40,-20,40]}
scene('intersection',dict(ab,E=[-10,-15,40],F=[-40,-15,10]),{'AB':['A','B'],'EF':['E','F']},['A','B','E','F'],['AB'],derived={'C':{'type':'intersection','first':'AB','second':'EF'}})
scene('apparent',dict(ab,E=[-10,-30,40],F=[-40,-30,10]),{'AB':['A','B'],'EF':['E','F']},['A','B','E','F'],['AB','EF'],derived={
    'P':{'type':'projected_intersection','first':'AB','second':'EF','on':'AB','view':'front'},
    'Q':{'type':'projected_intersection','first':'AB','second':'EF','on':'EF','view':'front'}})
scene('through',{'A':[-5,-25,25],'E':[-15,-5,10],'F':[-35,-25,30]},{'EF':['E','F'],'AB':['A','B'],'guide':['G0','G1']},['A','E','F'],['EF'],derived={
    'B':{'type':'face_point','line':'EF','axis':'y','value':-10},
    'G0':{'type':'level_start','point':'B','axis':'y'},'G1':{'type':'axis_foot','point':'B','axis':'y'}})
scene('both',{'A':[-5,-30,5],'B':[-25,-20,17],'C':[-20,-5,15],'D':[-20,-35,15],'E':[-40,-10,5],'F':[-40,-10,40]},
      {'AB':['A','B'],'CD':['C','D'],'EF':['E','F'],'MN':['M','N']},['A','B','C','D','E','F'],['AB','CD','EF'],derived={
          'M':{'type':'parallel_transversal','direction':'AB','first':'CD','second':'EF','endpoint':0},
          'N':{'type':'parallel_transversal','direction':'AB','first':'CD','second':'EF','endpoint':1}})
groups=[]
def group(id,title,source):
    g=dict(id=id,title=title,beats=[],source_questions=source);groups.append(g);return g
def beat(g,id,text,scene,action=None,anchor=None,indicator='highlight',**extra):
    g['beats'].append(dict(id=id,text=text,scene=scene,action=action or {'type':'focus'},anchor=anchor or ['front:AB'],focus=anchor or ['front:AB'],indicators=[indicator],show_sheet=True,source_questions=g['source_questions'],**extra))
    if action and action.get('id')=='guide':g['beats'][-1]['focus']=g['beats'][-1]['focus']+[action['views'][0]+':guide']
def line(id,views=None):return dict(type='line',id=id,views=views or ['space','front','top','left'])
def points(ids,views=None):return dict(type='points',ids=ids,views=views or ['space','front','top','left'])

def line_type(g,id,scene,face,relation,name,collapsed=None):
    focus=['space:AB']+([collapsed+':AB'] if collapsed else [])
    beat(g,id,f'将 AB 转到{relation} {face} 面的位置，此时称为{name}。',scene,
         anchor=focus,label_focus=[face],intro_only=True)
g=group('projection','直线的三面投影',['t02-q01','t07-q01'])
beat(g,'projection:connect','连接 A、B，得到空间线段 AB。','bridge',line('AB',['space']),['space:AB'])
beat(g,'projection:connect-front','连接 a′、b′，得到正面投影。','bridge',line('AB',['front']),['front:A','front:B'])
beat(g,'projection:connect-top','连接 a、b，得到水平投影。','bridge',line('AB',['top']),['top:A','top:B'])
beat(g,'projection:connect-left','连接 a″、b″，得到侧面投影。','bridge',line('AB',['left']),['left:A','left:B'])
beat(g,'projection:third-A','由 a、a′ 求 a″。','third',dict(type='side_point',id='A',duration=2.4),['front:A','top:A','left:A'])
beat(g,'projection:third-B','同样由 b、b′ 求 b″。','third',dict(type='side_point',id='B',duration=2.4),['front:B','top:B','left:B'])
beat(g,'projection:third-line','连接 a″、b″。','third',line('AB',['left']),['left:AB'])
beat(g,'projection:method','步骤是先画出端点的投影，再将端点连线。','third',anchor=['left:AB'])

g=group('parallel_plane','平行于投影面',['t02-q01','t02-q02'])
line_type(g,'parallel_plane:H','horizontal','H','平行','水平线')
beat(g,'parallel_plane:H-length','A、B 距 H 面相同。','horizontal',anchor=['space:A','space:B'],label_focus=['H'])
beat(g,'parallel_plane:H-angle','水平投影与 X 的夹角，反映直线与 V 面的夹角。','horizontal',anchor=['top:A','top:B','top:angle_axis'],indicator='angle',label_focus=['X','V'])
beat(g,'parallel_plane:H-others','正面、侧面投影均为水平线。','horizontal',anchor=['front:AB','left:AB'])
line_type(g,'parallel_plane:V','frontal','V','平行','正平线')
beat(g,'parallel_plane:V-length','两端距 V 面相同，水平投影平行 X。','frontal',anchor=['top:A','top:B'],label_focus=['V','X'])
g=group('normal_plane','垂直于投影面',['t03-q02','t07-q02'])
line_type(g,'normal_plane:H','normal_H','H','垂直','铅垂线',collapsed='top')
line_type(g,'normal_plane:V','normal_V','V','垂直','正垂线',collapsed='front')
g=group('point_on_line','线上取点',['t07-q01','t04-q02','t08-q02'])
beat(g,'point_on_line:height-guide','C 距 H 面 25 mm。','height',line('guide',['front']),['front:O','front:G1'],indicator='brace')
beat(g,'point_on_line:height-point','与直线投影的交点就是 c′。','height',points(['C'],['front']),['front:C'])
beat(g,'point_on_line:height-transfer','由 c′ 求出 C 的其余投影。','height',points(['C']),['space:C','top:C','left:C'])
g=group('division','等比分点',['t05-q01','t06-q01'])
beat(g,'division:parts','把线段分成五等份。','ratio',dict(type='ticks',value=1),['front:AB','space:AB'],indicator='ratio')
beat(g,'division:2-3','取从 A 起的第二个分点 C。','ratio',points(['C']),['space:C','front:C','top:C','left:C'],indicator='ratio')
g=group('parallel','平行关系',['t02-q02','t04-q02','t08-q02'])
beat(g,'parallel:through','过 a′ 画 e′f′ 的平行线。','parallel',dict(type='construct',lines=['AB'],points=['B'],views=['front']),['front:AB'])
beat(g,'parallel:through-top','过 a 画 ef 的平行线。','parallel',dict(type='construct',lines=['AB'],points=['B'],views=['top']),['top:AB'])
beat(g,'parallel:through-result','补出侧面投影，对应空间直线。','parallel',dict(type='construct',lines=['AB'],points=['B'],views=['left','space']),['left:AB','space:AB'])
beat(g,'parallel:rule','空间平行，同名投影也平行。','parallel',anchor=['front:EF','front:AB','top:EF','top:AB'])
beat(g,'parallel:complete-lines','利用对边平行，补出两条线。','parallelogram',dict(type='construct',lines=['AB','BC'],points=[]),['front:AB','front:BC','top:AB','top:BC'])
beat(g,'parallel:complete-point','交点确定第四个顶点。','parallelogram',points(['B']),['space:B','front:B','top:B'])
beat(g,'parallel:one-view','只看一面，不能判断空间平行。','parallel_false',anchor=['front:AB','front:EF'])
beat(g,'parallel:compare','再比较另一面的方向。','parallel_false',dict(type='construct',lines=['AB','EF'],points=['A','B','E','F'],views=['top','left']),['top:AB','top:EF'])
g=group('intersection','相交关系',['t03-q02','t04-q02','t07-q02','t08-q02'])
beat(g,'intersection:lines','画出第二条直线，找它们的共同点。','intersection',line('EF'),['space:AB','space:EF'])
beat(g,'intersection:common','同一个交点，在各面一一对应。','intersection',points(['C']),['space:C','front:C','top:C','left:C'])
beat(g,'intersection:apparent','这个正面交点，对应两条线上各自的空间点。','apparent',points(['P','Q'],['space','front']),['front:P','space:P','space:Q'])
beat(g,'intersection:check','前后位置不同，空间中没有共同点。','apparent',points(['P','Q']),['top:P','top:Q','space:P','space:Q'])
beat(g,'intersection:distance','交点 B 距 V 面 10 mm。','through',line('guide',['top']),['top:O','top:G1'],indicator='brace')
beat(g,'intersection:target','在 EF 上确定交点 B。','through',points(['B']),['space:B','top:B','front:B'])
beat(g,'intersection:through','连接 A、B，得到过 A 的相交线。','through',line('AB'),['space:AB','front:AB','top:AB'])
beat(g,'intersection:both-front','先作平行投影，确定两个交点。','both',dict(type='construct',lines=['MN'],points=['M','N'],views=['front']),['front:MN','front:CD','front:EF'])
beat(g,'intersection:both-top','核对两个交点的水平投影。','both',dict(type='construct',lines=['MN'],points=['M','N'],views=['top']),['top:MN','top:CD','top:EF'])
beat(g,'intersection:both-space','两交点对应，得到所求空间直线。','both',dict(type='construct',lines=['MN'],points=['M','N']),['space:MN','space:CD','space:EF'])
beat(g,'intersection:result','平行与两次相交，同时满足。','both',anchor=['space:MN','front:MN','top:MN'])
# Group by the learning goal; different given conditions are methods inside it.
point_group = next(g for g in groups if g['id']=='point_on_line')
division_group = next(g for g in groups if g['id']=='division')
point_group['beats'].extend(division_group['beats'])
point_group['source_questions'] = list(dict.fromkeys(point_group['source_questions']+division_group['source_questions']))
groups.remove(division_group)
contexts = {
    'third': '只给正面、水平投影，怎样补侧面投影？',
    'height': '给出线段 AB，要求确定线上点 C。\n可能通过两种方式给出点C的位置信息：\n  1. 给定点C离某面的距离\n  2. 给定AC和CB的长度比例',
    'ratio': 'AC∶CB＝2∶3。',
    'parallel': '另给点 A 和直线 EF，\n过 A 作 EF 的平行线。',
    'parallelogram': '已知平行四边形的 A、C、D，\n补出顶点 B。',
    'parallel_false': '换一组直线，比较一面投影平行与空间平行的区别。',
    'intersection': '两条直线怎样才算在空间相交？',
    'apparent': '只在正面投影相交，空间中一定相交吗？',
    'through': '另给 A 和 EF，过 A 作相交线；\n交点 B 的面距已知。',
    'both': '已知 AB、CD、EF，\n作平行 AB 且与 CD、EF 相交的线。',
}
problem_scenes={'third','height','parallel','parallelogram','through','both'}
previous_scene='bridge'
for g in groups:
    original=g['beats']
    g['beats']=[]
    for row in original:
        if row['scene']!=previous_scene:
            ref='space:AB' if 'AB' in scenes[previous_scene]['lines'] else 'space:EF'
            intro=dict(row)
            # Keep known lines through a geometric transformation. Answers to
            # later constructions still remain hidden in the target scene.
            retain = [key for key in scenes[previous_scene]['lines'] if key in scenes[row['scene']]['initial_lines'] and key != 'guide']
            if row['scene'] in ['horizontal','frontal','normal_H','normal_V','height','distance_V','ratio']:
                retain = list(dict.fromkeys(retain+['AB']))
            intro_only=row.get('intro_only',False)
            intro.update(id=row['id']+'-context',text=row['text'] if intro_only else contexts[row['scene']],scene=previous_scene,
                         action={'type':'scene','scene':row['scene'],'retain_lines':retain,'duration':1.8},anchor=[ref],focus=[ref],indicators=['highlight'],label_focus=[])
            if row['scene'] in problem_scenes:intro['callout_kind']='problem'
            if row['scene']=='height':intro['problem_conditions']=['1. 给定点C离某面的距离','2. 给定AC和CB的长度比例']
            if intro_only:
                intro['focus']=row['focus']
                intro['label_focus']=row.get('label_focus',[])
                intro.pop('intro_only',None)
            g['beats'].append(intro)
        if not row.get('intro_only',False): g['beats'].append(row)
        previous_scene=row['scene']

for g in groups:g['text']=''.join(b['text'] for b in g['beats'])
resume_aliases={'division':'division:parts-context'}
for id in ['parallel_plane:H','parallel_plane:V','normal_plane:H','normal_plane:V']:
    resume_aliases[id]=id+'-context'
for face in ['H','V']:resume_aliases['normal_plane:'+face+'-dot']='normal_plane:'+face+'-context'
for id in ['division:3-2','division:rule']:resume_aliases[id]='division:2-3'
resume_aliases['point_on_line:V-guide-context']='point_on_line:height-guide-context'
for suffix in ['guide','point','transfer']:resume_aliases['point_on_line:V-'+suffix]='point_on_line:height-'+suffix
config=dict(schema_version=1,chapter_id='line',knowledge_resume_aliases=resume_aliases,concept=groups,scenes=scenes,presentation=dict(characters_per_second=16,punctuation_pause=.18),knowledge_scope=dict(
    basis='合订卷九道相关题按知识方法归并；题号仅用于后台追溯。',source_sha256=index['source']['sha256'],direct_questions=[q for q in index['questions'] if q['id'] in sources],
    excluded_topics=['侧平线','侧垂线','一般位置线求实长','平面章节完整作图'],teaching_note='除读取原points/line模型的场景外，所有端点为教学参数。仅题给比例、距离及水平线实长/夹角作为原题条件，示意不冒充无尺寸题图的标准答案。'))
from review_legacy_concepts import revise
revise(config,'line')
(APP/'模型/line_learning.json').write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print({'groups':len(groups),'beats':sum(len(g['beats']) for g in groups),'scenes':len(scenes)})
