"""Extract point knowledge from the compilation's two pure point questions."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
path=root/'机械制图学习/模型/points_learning.json'
c=json.loads(path.read_text(encoding='utf-8'))
index=json.loads((root/'学习资料/题集识别/题集索引.json').read_text(encoding='utf-8'))
questions={q['id']:q for q in index['questions']}
groups={g['id']:g for g in c['concept']}
def beat(id,text,anchors,action=None,**extra):
    return dict(id=id,text=text,anchor=anchors,focus=anchors,action=action or {'type':'focus'},indicators=['highlight'],source_questions=['t08-q01'],**extra)
for key in ['planes','distances','feet','unfold']:
    for b in groups[key]['beats']: b['source_questions']=['t01-q01','t08-q01']
groups['alignment']['beats']=[b for b in groups['alignment']['beats'] if b['id'] in ['alignment:vertical','alignment:height','alignment:depth','alignment:given','alignment:transfer','alignment:turn','alignment:level','alignment:point','alignment:summary']]
for b in groups['alignment']['beats']:
    b['source_questions']=['t01-q01','t08-q01'] if b['id'] in ['alignment:vertical','alignment:height','alignment:depth'] else ['t01-q01']
    if b['id']=='alignment:transfer': b['text']='从 a 水平引到 45°线。交点到 Y_H 的水平距离，等于 a 到 X 的竖直距离 y。'
    if b['id']=='alignment:turn': b['text']='由交点向上引竖线，它到 Z 的距离始终为 y；这就固定侧面投影的前后位置。'
proof=dict(id='alignment:45-distance',text='45°线上横、纵两轴距相等，这里同为 {A_y} mm；转移的是 y，不是从 a 到交点的整段长度。',action={'type':'focus'},anchor=['O','A_top_axis','A_top_axis','A_turn'],focus=['O','A_top_axis','A_turn'],indicators=['equal'],scene='third_side',show_sheet=True,show_space=False,known=['front','top'],source_questions=['t01-q01'])
offset=next(i for i,b in enumerate(groups['alignment']['beats']) if b['id']=='alignment:transfer')
groups['alignment']['beats'].insert(offset+1,proof)
relative=groups['relative']
relative['title']='第1套：左、上、后'
relative['beats'][0]['setup']['B_visible']=False
relative['beats'][0]['action']['show_point']=True
for b in relative['beats']: b['source_questions']=['t01-q01']
common=dict(scene='relative8',show_sheet=True,show_space=False,paper_extent=[760,760])
relative8=dict(id='relative8',title='第8套：左、上、前',beats=[
    beat('relative8:given','第8套从已知 A 投影作 B。这里沿用前面的 A 演示位移；解题时从题给的 A 出发。',['A_front','A_top','A_left'],setup=dict(A=['A.x','A.y','A.z'],B=['A.x','A.y','A.z'],B_visible=False,unfolded=True),**common),
    beat('relative8:left','B 在 A 左方 20 mm：从 a′、a 向左量 20；侧面投影的左右位置由前后距离决定。',['A_front','B_front'],{'type':'move','point':'B','to':['shift:A.x:-20','A.y','A.z'],'show_point':True},**common),
    beat('relative8:up','B 在 A 上方 16 mm：从 a′、a″ 向上量 16；水平投影不随高度改变。',['A_front','B_front'],{'type':'move','point':'B','to':['shift:A.x:-20','A.y','shift:A.z:16']},**common),
    beat('relative8:front','B 在 A 前方 18 mm，距 V 增大：b 比 a 离 X 更远，b″ 比 a″ 离 Z 更远；正面投影不变。',['A_top','B_top'],{'type':'move','point':'B','to':['shift:A.x:-20','shift:A.y:-18','shift:A.z:16']},**common),
])
c['concept']=[groups[k] for k in ['planes','distances','feet','unfold','alignment']]+[relative,relative8]
for g in c['concept']: g['text']=''.join(b['text'] for b in g['beats'])
c['knowledge_scope']={
    'basis':'仅合订卷纯点题 t01-q01 与 t08-q01；含直线的题属于线的投影，面内取点属于平面章节。',
    'index_source':'学习资料/题集识别/题集索引.json','compilation_sha256':index['source']['sha256'],'questions_scanned':len(index['questions']),
    'direct_questions':[
        {'id':'t01-q01','pdf_page':1,'image':questions['t01-q01']['regions'][0]['image'],'facts':{'A_distances_mm':{'H':12,'V':15,'W':10},'B_relative_mm':{'left':5,'back':10,'up':8}}},
        {'id':'t08-q01','pdf_page':38,'image':questions['t08-q01']['regions'][0]['image'],'facts':{'A_given':'三面投影；图中没有绝对坐标尺寸','B_relative_mm':{'left':20,'front':18,'up':16}}}],
    'question_to_content':{
        't01-q01':['H/V/W和投影标记','三项面距到二维轴距','正投影保留的坐标','展开与对应关系','45度转移求侧面投影','左/上/后的位移及距V减小'],
        't08-q01':['从已知A同名投影出发','每个方向影响哪两个投影','左20/上16/前18的图上量取','前方使距V增大','对应关系检查']},
    'line_questions_excluded':['t02-q01','t02-q02','t03-q02','t04-q02','t05-q01','t06-q01','t07-q01','t07-q02','t08-q02'],
    'plane_questions_excluded':['t01-q02','t03-q01','t04-q01','t05-q02','t06-q02','t08-q03'],
    'removed_unexamined_topics':['特殊位置点','负坐标','无轴投影','重影点及可见性','非本两题所需的反向二求三分支'],
    'examples':'t01使用原模型A/B；t08仅20/16/18位移为原题事实，动画沿用t01的A作示意，不从t08无尺寸图臆造绝对坐标或标准答案。不增加练习或评分。',
    'extraction_note':'投影体系、正投影、展开和对应规律是完成原题所需的方法，不是题干逐字列出的条件。'}
path.write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print({'questions_scanned':len(index['questions']),'point_questions':['t01-q01','t08-q01'],'groups':len(c['concept']),'beats':sum(len(g['beats']) for g in c['concept'])})

# Apply the latest user copy policy last.
import runpy
runpy.run_path(str(Path(__file__).resolve().parent / "refine_points_copy.py"))
