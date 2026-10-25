"""Record the content review separately from behavioral/geometry assertions."""
from pathlib import Path
from collections import Counter
import hashlib,json,datetime

ROOT=Path(__file__).resolve().parents[1];APP=ROOT/'机械制图学习';QA=APP/'qa';MODEL=APP/'模型'
def load(p):return json.loads(p.read_text(encoding='utf8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
before=load(ROOT/'work/course-review-before.json');registry=load(MODEL/'course_registry.json')
review=[
('points','刚进入就报面名；投影点尚未出现，就解释其名字。','先提出把空间位置画到纸上的目标，再解释三个观察方向；投影点命名移到三个垂足出现之后。展开与相对位移先交代用途。','planes:purpose；planes:names；relative:purpose'),
('line','补相交约束时缺少选择作图起点的理由；结尾重复报告结果。','承接已会的端点投影；指出 CD 在正面积聚成点，说明为什么所求线必须经过它。比例仍只演示 2∶3，删去重复结论。','projection:purpose；intersection:both-clue'),
('plane','面内取点重新逐步讲一遍刚讲过的面内作线；四边形辅助线缺少依据。','已学面内作线合为连续动作；明确 P 要同时满足两项面距。按 E 同属两条对角线、A/E/C 共线解释补顶点，保留普通四边形与平行四边形的条件区别。','in-point:level；complete:E-top；complete:AC-top'),
('basic_solids','直接列立体和取点动作，未区分真实棱与曲面轮廓，也未说明后续用途。','从点线面转入立体；圆柱用“这两条线还是棱吗”建立区别；圆锥先认识母线和水平圆，再求共同点；球面取点衔接求交线。修正母线未经过所选点、所选点背向镜头的问题。','basic_solids:cylinder:silhouette；basic_solids:cone:point'),
('intersection_plane','看见材料移去和曲线出现，却不知道这些点从哪里来。','先明确截切对象、已知切割位置及所求视图；把棱交点、圆截面等依据显示出来，再标真实公共点和连接。后续类型只说明新的取点区别，删重复清理结论。','intersection_plane:prism:meaning；intersection_plane:cone:points'),
('intersection_solids','先展示复杂曲线，未解释怎样找到同时属于两表面的一个点。','先辨认参与相交的两处孔壁；以竖孔圆周限定母线，再与横孔壁求交，显示真实公共点。随后取特殊点和中间点；有壁厚的变式只增加内外两组曲线的区别。','intersection_solids:inner:one-point；intersection_solids:inner:both-surfaces'),
('combination','主体、孔槽、轮廓这些词缺少具体指向；动画按图线数量分批，未必按结构分批。','明确每例给哪两视图、补哪一面；空间里定位相同斜面/孔/槽，再按真实主体、圆弧、内部细节组织描线；说明分块不便时为什么改为追踪线面。','combination:slope:parts；combination:base:planes'),
('section','不同剖切方法突然换模型；半剖空间切法沿用全剖，文字与动画不符。','从虚线难读引出剖视，分别用对称、局部需求、孔位错开、倾斜相接解释选法。半剖真实移去四分之一，讲解镜头朝向剖开区域；阶梯与旋转各说明为什么不能直接普通投影。','section:half:cut；section:stepped:outline；section:rotated:unfold'),
('removed_section','未先建立它与剖视图表达范围的区别；整件投影容易被当成已完成断面。','先对照“截面”与“截面后方轮廓”；答案区在作断面前隐藏整件投影。孔槽变式只保留规定画法的新条件，不再重复整套定义。','removed_section:key:context；removed_section:hole:through'),
('dimensions','直接进入密集原图寻找基准，初学者不清楚尺寸各自解决什么问题。','新增简单板孔图：依次说明孔径、位置、总体大小及共同量取起点；再回原零件图。讲具体尺寸时放大相关区域，区分图上比例与真实尺寸。','dimensions:meaning:datum；dimensions:block:length'),
('threads','尚未认识牙顶、牙底和螺距，就开始背粗细线规定。','先用放大牙形建立这些对象，再对照实际螺旋牙形与规定线。说明外牙/内牙为什么粗细位置不同；连接先辨认通孔与螺纹孔，代号留到结构之后。删除内螺纹、旋合和螺柱的重复段。','threads:meaning:pitch；threads:external:real；threads:internal:major'),
('gears','公式和圆突然出现；两轮重复逐个计算，已有画法又讲一遍。','先说明传递转动、已知模数/齿数以及标准直齿范围。三个圆在齿轮实体与二维图同时对应；两轮同类尺寸合段计算，再进入新增的中心距问题。','gears:single:scope；gears:single:pitch0；gears:pair:centres'),
('bearings','只点名部件，未解释轴与座孔之间的支承关系；量尺寸时括号悬在空白区。','先提出转轴支承问题；分解内外圈、显示滚动体/保持架，再合回。轴和座孔沿轴向装入。尺寸增加对应的轴向轮廓、孔线和界线，隐藏与宽度相撞的代号。分解明确为教学示意。','bearings:structure:rings；bearings:structure:size；bearings:assembly:shaft'),
('requirements','把符号拆开读，却没先讲“允许范围”；后续三个小节重复同一不合格结论。','从制造误差引入尺寸范围，用零线、带位置、带宽解释 H7；轴只作差异对照。几何公差先找基准，再显示圆柱域或两平面；真实局部越界反例只讲一次，后续保留控制对象和方向的新区别。','requirements:hole:grade；requirements:perpendicular:units；requirements:plane:zone'),
('roughness','从符号起步，缺少它在控制什么的直观认识；读表面时旧高亮积累。','先显示同一尺度下的微小起伏，连接到符号与 Ra。再按原图找具体表面和对应标注，二者同时强调；换表面时清理无关高亮，最后比较同参数要求。','roughness:meaning:profile；roughness:surface:III'),
('part_drawing','逐项点名视图、结构和数值，却缺少读图顺序；换零件无过渡。','建立表达方法→结构→尺寸→技术要求的顺序；先追溯剖切位置，再解释看到的内部结构。明确“换看轴类零件”“仍看釜盖”等对象衔接；把孔数量、深度、螺纹与钻孔对应回结构。','part_drawing:overview:next；part_drawing:details:context；part_drawing:note:thread'),
]
changes=[]
for old in before:
    id=old['id'];f=MODEL/(id+'_learning.json') if registry['chapters'][id]['legacy'] else MODEL/'course'/f'{id}.json'
    current=load(f);lesson=current['concept'];groups=lesson if isinstance(lesson,list) else lesson['groups']
    a={b['id']:b for g in old['groups'] for b in g['beats']};b={b['id']:b for g in groups for b in g['beats']}
    changes.append(dict(chapter=id,title=old['title'],before=len(a),after=len(b),added=sorted(b.keys()-a.keys()),removed=sorted(a.keys()-b.keys()),
        text_changed=[dict(id=k,before=a[k]['text'],after=b[k]['text']) for k in a.keys()&b.keys() if a[k]['text']!=b[k]['text']],
        action_changed=[k for k in a.keys()&b.keys() if a[k].get('action')!=b[k].get('action')],source=str(f.relative_to(APP)),sha256=sha(f)))
content=dict(date=datetime.date.today().isoformat(),original_snapshot_sha256=sha(ROOT/'work/course-review-before.json'),chapters=changes)
(QA/'course-beginner-content-diff.json').write_text(json.dumps(content,ensure_ascii=False,indent=2),encoding='utf8')
old_count=sum(c['before'] for c in changes);new_count=sum(c['after'] for c in changes)
lines=['# 初学者视角讲解审查','',f'日期：{content["date"]}。范围为全部16章的「讲解」。已逐段阅读原有{old_count}个小段及动作定义；修订后为{new_count}段。题目入口、原卷条件和独立题目讲解保留。小段数减少不是目标，判断依据是每一步是否消除一个真实疑问。','',
'## 核心诊断','',
'后续按“已知条件是否足够、所调用的方法是否真正学过”进一步复审，最新逐章判断及补充推导见[方法前置与推导审查](方法前置与推导审查.md)。',
'原问题不只是缺少章节连接句：有些小节默认学习者已经知道当前图形代表什么、为什么选这条辅助线、符号在约束哪个对象。仅把句子缩短或让线动起来，不能填补这些前提。修订采用“对象与已知 → 当前疑问 → 图形依据 → 实际推导”，在已熟悉的方法处连续演示，不重新逐句报动作。','',
'## 逐章修改','', '| 章节 | 旧断点 | 已实施修改 | 定位小段 |','|---|---|---|---|']
for id,problem,fix,beats in review:lines.append(f'| {registry["chapters"][id]["title"]} | {problem} | {fix} | {beats} |')
lines+=['','## 画面中发现并修正的问题','',
'- 圆锥母线改为经过实际所选点；基本体表面点从讲解视角可见，空间与三面投影仍使用同一参数。',
'- 半剖真实移去四分之一，镜头面向切开的区域；只有相应侧面区域显示半剖答案。保留全剖的独立取材与肋板说明。',
'- 相贯先显示一个同时满足两孔壁方程的公共点及两条母线，再扩展为曲线。',
'- 螺纹实体由光圆柱改为理想螺旋牙形；工程图仍由规定画法生成，不能把全部网格边线当成图纸。',
'- 轴承尺寸有对应轮廓和尺寸界线；旧代号与宽度文字不重叠。',
'- 密集图纸按当前尺寸/结构放大；换读图位置时移除旧注意区域。问题准备与文字同步，纯阅读高亮不再占一次空的“下一步”。',
'- 点章节过渡段只指向当前可见的 A；不继承下一动作的平面指示，不提前圈出尚未作出的 B。',
'- 逐节复看又发现点章节两处旧括号端点错误：展开段原先量成 a′ 到 a 的总间距，对应关系段原先用了错误的轴上垂足。现分别量 a 到 X、a″ 到 Z，均为模型给出的前后面距；补充真实垂直方向、两端点和数值核对。',
'','## 验证与证据边界','',
'内容判断、图形几何、实际播放、实际渲染分别记录。程序通过只说明对应的断言成立，不能证明初学者已经理解；本轮没有组织真实学习者访谈或学习效果测验。','',
'- 内容对照：[逐段修订记录](qa/course-beginner-content-diff.json)，保留原文、新文和动作变化。',
'- 几何依据：[本轮几何检查](qa/course-beginner-geometry.json)，核对圆锥点、公共点、四分之一取材、真实牙形、公差域及连续面内作线。',
'- 实际播放：[正常窗口](qa/course-beginner-normal.json)、[1060×720](qa/course-beginner-minimum.json)，通过内部按钮/A/D逐段播放；关键构造使用真实计时抓取前、中、后状态。截图数量不等于人工逐张审查数量。',
'- 人工画面检查：[查看清单与具体发现](qa/course-beginner-visual-review.json)，查看全部16章各节入口与结果，另外展开重点修订段及关键动画中间态；实际查看过的截图按哈希独立归档。',
'- 保存、兼容与原有流程：[全卷验收记录](全卷验收记录.md)。新增/删除的小段迁移到有效稳定ID，重进恢复动作前；题目不保存动画时刻。',
'','测试使用独立存档、离屏不抢焦点窗口与Godot内部输入；没有移动系统鼠标。原生全屏、操作系统拖选手感、真实学习迁移效果仍不属于本轮已验证结果。教学模型不提供加工级CAD精度。','',
'## 维护位置','',
'新章修订由 `work/course_pedagogy.py` 维护，辅助视觉几何由 `work/course_visual_evidence.py` 生成；点线面通过 `work/review_legacy_concepts.py` 接入各自作者入口。不得只改生成JSON。入口准备、阅读焦点与实际构造分别处理；相机只在换段/前后操作时恢复，当前段内允许旋转，退出保留观察状态。','',
'轴承概念对照制造商的[结构介绍](https://www.nskeurope.com/tools-resources/abc-bearings/bearing-basics/)；齿轮尺寸关系对照[KHK技术资料](https://khkgears.net/gear-knowledge/gear-technical-reference/calculation-gear-dimensions/)。原卷旧式代号和来源冲突继续遵循[全卷来源核验](全卷来源核验.md)，没有用通用网页替换原题条件。']
(APP/'初学者视角讲解审查.md').write_text('\n'.join(lines)+'\n',encoding='utf8')
print(json.dumps({'before':old_count,'after':new_count,'text_changed':sum(len(c['text_changed']) for c in changes),'added':sum(len(c['added']) for c in changes),'removed':sum(len(c['removed']) for c in changes)},ensure_ascii=False))
