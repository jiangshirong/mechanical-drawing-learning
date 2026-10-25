"""Human prerequisite audit with a machine-readable change ledger."""
from pathlib import Path
import json,datetime
ROOT=Path(__file__).resolve().parents[1];APP=ROOT/'机械制图学习';MODEL=APP/'模型'
def load(p):return json.loads(p.read_text(encoding='utf8'))
reg=load(MODEL/'course_registry.json');before=load(ROOT/'work/method-review-before.json')
old={b['beat_id']:b for b in before};current={};summary=[]
for id,c in reg['chapters'].items():
 obj=load(MODEL/(id+'_learning.json')) if c['legacy'] else load(MODEL/'course'/f'{id}.json')
 gs=obj['concept'];gs=gs if isinstance(gs,list) else gs['groups']
 for g in gs:
  for b in g['beats']:current[b['id']]=dict(b,chapter=id)
 summary.append(dict(chapter=id,beats=sum(len(g['beats']) for g in gs)))
audit=[
('points','空间点与面距已知；补点明确给出两面。','垂足、面距、展开和45°转移均先实际建立；本轮保持。','feet:V；alignment:given'),
('line','端点或两面投影已知；分点给定比例。','补上空间AB先五等分、二维再对应刻度的证据；不增加第二种比例。','division:parts'),
('plane','空间模型已知，与给出两面求第三面分别处理。','三面分别投顶点、再连边；反向45°先示范a；正平条件先求c，再逐条平行线求b。','projection:surface；projection:other；complete:third-endpoints；complete:parallel-c'),
('basic_solids','形体已知，表面点还须有足够位置条件。','圆柱明确圆周投影和高度；圆锥明确母线和高度；球面明确正面投影及前半球条件，按高度圆及左右对应求点。','basic_solids:cylinder:given；basic_solids:sphere:given'),
('intersection_plane','截切位置和原表面已知，先求公共点。','补明棱柱须在同一个面上连接相邻交点；曲面各自使用已建立的母线或截面圆。','intersection_plane:prism:curve'),
('intersection_solids','两处相交表面的几何已知。','有壁厚变式先分别显示外壁/内壁公共点，再各自连线；内孔例的上下两组采样点均有依据。','intersection_solids:shell:outer-points；intersection_solids:shell:inner-points'),
('combination','两个视图已知、目标视图缺失。','先示范一个轮廓点：高度来自正面，前后距离来自水平，两线相交后才补完整主体。后续复用此方法。','combination:slope:point-height；combination:slope:point-depth'),
('section','形体、剖切位置及观察方向明确。','全剖先建立剖开/移去/投影，再引入其余剖法；规定画法作为新规则明确介绍，没有作为已有算法省略。保持。','section:full:cut；section:rotated:unfold'),
('removed_section','剖切位置及观察方向明确。','先区分截面与截面后方，再画边界及孔槽；回转孔槽的规定作为新规则说明。保持。','removed_section:key:range；removed_section:hole:through'),
('dimensions','先给简单孔板，再读具体零件。','定形、定位、总体尺寸和共同量取起点已先建立；后续基准识读沿尺寸链追溯。保持。','dimensions:meaning:datum'),
('threads','牙形、直径及连接件结构逐次给出。','牙顶、牙底、螺距先定义；粗细线和旋合按规定明确介绍，公差带先识别、后章再解释。保持。','threads:meaning:crest；threads:engaged:outer'),
('gears','已知模数、齿数，明确采用标准直齿圆柱齿轮。','三个圆先命名，尺寸关系作为采用的标准关系给出；成对齿轮复用公式，中心距另给相切依据。保持。','gears:single:scope；gears:pair:centres'),
('bearings','型号已知，代号与查表结果区分。','明确外径52和宽15是按304查表所得，用途保留；不让读者误认为由代号直接计算。','bearings:structure:size'),
('requirements','先尺寸允许范围，再基准与几何公差域。','零线、范围位置/宽度及控制轴线/表面均逐项定义；这些是首次教授的含义与规定，不省略为已学。保持。','requirements:hole:deviation；requirements:perpendicular:zone'),
('roughness','先认识表面起伏，再读符号和参数。','先给同参数比较规则；跨视图找表面依赖此前已学投影对应。保持。','roughness:meaning:profile；roughness:surface:III'),
('part_drawing','原图各视图、剖切位置、尺寸及要求可追溯。','调用此前已学剖视、断面、尺寸、螺纹与要求；换对象已说明，未引入未教的独立作图算法。保持。','part_drawing:overview:cut；part_drawing:shaft_section:context')]
diff=[]
for id,b in current.items():
 a=old.get(id)
 if a is None or a['text']!=b['text'] or a['action']!=b.get('action',{}):diff.append(dict(id=id,chapter=b['chapter'],before=None if a is None else dict(text=a['text'],action=a['action']),after=dict(text=b['text'],action=b.get('action',{}))))
record=dict(date=datetime.date.today().isoformat(),before=len(old),after=len(current),chapters=summary,changes=diff,audit=[dict(chapter=c,givens=g,judgment=j,evidence=e) for c,g,j,e in audit])
(APP/'qa/course-method-content.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
lines=['# 方法前置与推导审查','',f'日期：{record["date"]}。逐章复审16章的讲解，重点检查已知是否足够、所调用的方法是否已建立、当前动画是否展示了关键约束。上一轮403段，本轮补足必要推导后为{len(current)}段；65个题目入口及61个去重任务保留。','',
'## 空间投影与补图分开','',
'已知空间平面的顶点，可以分别向三个面投影；只给一幅正面投影，缺少前后位置，不能唯一确定另外两面。现在先交代空间平面已知，每一面都依次画四条垂线、标出垂足，再单独连边。右侧待求投影点和边界在相应动作之前隐藏。','',
'补图另外说明给出的两面。反向使用45°线时先示范一个顶点，后续顶点才连续复用。平行四边形先用正平对角线的等面距条件求c，再过a、c分别作平行线确定b。','',
'## 逐章判断','', '| 章节 | 当前已知及前置 | 判断与实际调整 | 依据小段 |','|---|---|---|---|']
for c,g,j,e in audit:lines.append(f'| {reg["chapters"][c]["title"]} | {g} | {j} | {e} |')
lines+=['','## 验证与边界','',
'- [逐段改动](qa/course-method-content.json)保留403段基线与当前差异；作者源为`work/build_plane_lessons.py`、`review_legacy_concepts.py`、`course_method_review.py`及原领域入口。',
'- [几何检查](qa/course-method-geometry.json)验证单一正面投影的欠定反例、实际垂足、反向45°转移、球面候选点、平行四边形约束及两组相贯点。',
'- [正常窗口](qa/course-method-normal.json)与[1060×720](qa/course-method-minimum.json)通过内部按钮/A/D自然播放，捕获垂线第一段、更多垂足、连边以及各项推导的前中后状态。',
'- [人工查看记录](qa/course-method-visual-review.json)记录真实观察和修正。初次复看发现H面附近的文字遮住垂足、投影线偏暗，已重新安排文字并提高线条对比度。',
'- [整套回归](全卷验收记录.md)另外核对旧入口、保存恢复、即时完成、回退、跳节及退出。程序通过不等于学习者已经理解。',
'','全部测试使用独立存档、离屏不抢焦点窗口、Godot内部输入；没有操作系统鼠标移动。原生全屏、系统拖选手感和真实学习效果仍未验收。教学取点使用记录的模型参数，不作为原卷未给出的尺寸或唯一答案。']
(APP/'方法前置与推导审查.md').write_text('\n'.join(lines)+'\n',encoding='utf8')
print(json.dumps({'before':len(old),'after':len(current),'changed_or_added':len(diff)},ensure_ascii=False))
