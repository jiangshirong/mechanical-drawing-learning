"""Human-readable coverage, current capabilities, and authoring/evidence ledger.

Run after final QA so the delivery record contains observed results, not promises.
"""
from pathlib import Path
from collections import Counter
import hashlib,json,datetime,sys
from build_exam_course import learner_question
ROOT=Path(__file__).resolve().parents[1];APP=ROOT/'机械制图学习';MODEL=APP/'模型';QA=APP/'qa'
def load(p):return json.loads(p.read_text(encoding='utf8'))
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2),encoding='utf8')
def md(p,lines):p.write_text('\n'.join(lines)+'\n',encoding='utf8')
def clean(v):return str(v).replace('|','／').replace('\n','；')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
reg=load(MODEL/'course_registry.json');coverage=load(MODEL/'course_coverage.json')
courses={p.stem:load(p) for p in (MODEL/'course').glob('*.json')}
chapters=reg['chapters'];title=lambda id:chapters[id]['title']
all_lessons=[];summary=[]
for id,c in chapters.items():
    if c['legacy']:
        config=load(MODEL/(('points' if id=='points' else id)+'_learning.json'))
        groups=config['concept'];all_lessons.append((id,'concept',id,groups))
        tasks=[{'id':'t01-q01','title':'作点 A、B 的三面投影','groups':config['solution']}] if id=='points' else load(MODEL/('line_practice.json' if id=='line' else 'plane_questions.json'))['tasks']
        for t in tasks:all_lessons.append((id,'question',t['id'],t['groups']))
    else:
        config=courses[id];groups=config['concept']['groups'];tasks=config['tasks'];all_lessons.append((id,'concept',id,groups))
        for t in tasks:all_lessons.append((id,'question',t['id'],t['lesson']['groups']))
    summary.append(dict(id=id,title=c['title'],sections=[{'id':g['id'],'title':g['title']} for g in groups],concept_beats=sum(len(g['beats']) for g in groups),tasks=[{'id':t['id'],'title':t['title']} for t in tasks]))

records=[]
for chapter,mode,lesson,groups in all_lessons:
    for group in groups:
        for b in group['beats']:
            text=b.get('text','');a=b.get('action',{});teaching=b.get('teaching',{})
            evidence=teaching.get('visual_evidence',b.get('focus',b.get('anchor',[])))
            records.append(dict(chapter=chapter,mode=mode,lesson=lesson,section=group['id'],beat_id=b['id'],text=text,
                learner_question=teaching.get('learner_question',learner_question(text,a,b.get('callout_kind','normal'))),
                visual_evidence=evidence,scene=b.get('scene',group.get('scene','legacy-shared-geometry')),
                action=a,setup=b.get('setup',{}),prepare_with_text=b.get('prepare_with_text',False),resolved_uncertainty=teaching.get('resolved_uncertainty',text),source_questions=b.get('source_questions',[]),
                note='制作记录，不进入学习正文；参数占位符由既有模型数据填充。'))
save(MODEL/'course_authoring_records.json',{'schema_version':1,'beats':records})
counts=dict(chapters=len(chapters),concept_beats=sum(s['concept_beats'] for s in summary),task_entries=sum(len(s['tasks']) for s in summary),unique_task_ids=len({t['id'] for s in summary for t in s['tasks']}),new_scenes=len(list((APP/'assets/course_scenes').glob('*.json'))),questions=coverage['question_count'],requirements=coverage['requirement_count'],methods=len(coverage['methods']))

lines=['# 全卷知识覆盖表','',f'范围：43页、8套、69道大题；按作答要求拆为 {counts["requirements"]} 条覆盖记录，关联 {counts["methods"]} 个方法条目。原题编号只用于本表及后台，不进入讲解正文。',
'','“方法条目”包含同一流程中的知识要求，不等同于互不相关的独立算法。每条记录都指向具体章节、小节及可运行题目；图形正确性、播放和渲染证据另见[全卷验收记录](全卷验收记录.md)。',
'','| 状态 | 含义 |','|---|---|']
for status,meaning in coverage['status_meanings'].items():lines.append(f'| {status} | {meaning} |')
lines+=['','“同法覆盖”表示迁移到指定代表流程，并不宣称已为那道同类题单独制作动画。原题条件、题给数值和OCR候选仍在[题集索引](../学习资料/题集识别/题集索引.json)及[机器可读覆盖表](模型/course_coverage.json)保留。']
for paper in range(1,9):
    lines+=['',f'## 第{paper}套','', '| 原题／作答要求 | PDF页 | 学习方法与答案字段 | 具体讲解／代表题 | 状态 |','|---|---|---|---|---|']
    for q in coverage['questions']:
        if not q['question'].startswith(f't{paper:02}-'):continue
        for n,r in enumerate(q['requirements'],1):
            refs=r['demonstrations'];dest='<br>'.join(f'{title(d["chapter"])} → {d["section"]} → `{d["task"]}`' for d in refs)
            fields='；字段：'+'、'.join(r['answer_fields']) if r.get('answer_fields') else ''
            lines.append(f'| {q["question"]}／{n} | {"、".join(map(str,q["pages"]))} | {clean(r["demand"]+fields)} | {dest} | {"、".join(dict.fromkeys(d["status"] for d in refs))} |')
lines+=['','## 追溯与冲突','',f'合订卷索引中的原PDF SHA-256：`{coverage["source_sha256"]}`。',
'','五处题干／答案／图形冲突及旧式304、G1/2、Q235-A、粗糙度标记的处理见[全卷来源核验](全卷来源核验.md)。无尺寸图的尺度是教学选择；与原图关系相容不意味着恢复了唯一实体。',
'','50道几何作图、8道综合读图、11道独立标准件与常用件题为大题层面的统计。综合题按小问同时关联剖视、基准、螺纹、公差、粗糙度等章节，不被锁在单一大题分类中。']
md(APP/'全卷知识覆盖表.md',lines)

lines=['# 当前课程能力清单','',f'当前课程为 {counts["chapters"]} 章、{counts["concept_beats"]} 个讲解小段、{counts["task_entries"]} 个题目入口，按稳定任务ID去重为 {counts["unique_task_ids"]} 个任务。基本体章节的4个题目链接复用截交线章节的同一流程；没有为这4个入口重复编写解法。',
'','| 章节 | 讲解小节 | 讲解小段 | 题目入口 |','|---|---|---:|---:|']
for s in summary:lines.append(f'| {s["title"]} | {"、".join(g["title"] for g in s["sections"])} | {s["concept_beats"]} | {len(s["tasks"])} |')
lines+=['','## 题目清单','']
for s in summary:
    lines.append('### '+s['title']);lines.append('')
    lines.extend('- '+t['title']+'（`'+t['id']+'`）' for t in s['tasks']);lines.append('')
lines+=['## 可复用能力','',
'- 章节注册：知识章节、观察场景和原题任务分开；点、直线、平面保留独立播放器，经统一接口接入。',
'- 播放：16字/秒、标点停顿、文字→动作→结果停留；纯文字没有空动作。问题卡与已知图形准备同步。A/D或按钮在忙碌时完成当前阶段，再次输入才换段。',
'- 文字与焦点：原生选字和Ctrl+C、蓝灰问题卡、当前小段稳定布局；实体局部强调，文字变色并轻微周期放大；距离括号和角度由实际端点生成。',
'- 空间与图纸：共用毫米参数；正面、水平、侧面保持对应。空间可旋转，前后步进恢复讲解视角，退出恢复观察视野和对应点。',
'- 规定画法：螺纹、齿轮、轴承独立生成工程图线；不把真实网格全部棱线投成工程图。连接题先说明3D装配，作图阶段扩大二维图，错误原图单独对照。',
'- 阅读图纸：保留原始题图，按语义区域连续缩放；尺寸、基准、符号与实际表面对应。错误数字覆盖层不改原始图片。',
'- 保存：讲解只保存目标小段，重新进入恢复动作前状态；题目从头开始，只记所选任务。异常JSON或非法嵌套视野不覆盖原档。',
'- 兼容：原点线面目标ID与旧删段映射继续使用；全剖旧guide ID映射到剖视章节对应小段；旧模型资源保留。',
'- 导航：16章知识图谱；观察、题目、讲解均有图标。原题和参考依据仅在图谱连续输入qwer后的本次运行可见。题干“题”浮窗正常供学生查看。',
'','## 五类领域制作能力','', '| 领域 | 作者模块 | 实际负责内容 |','|---|---|---|',
'| 基本体及交线 | `work/course_solids.py` | 参数实体、截面、解析交线、取点与可见性 |',
'| 组合体投影 | `course_solids.py`、`course_geometry.py` | 既有模型复用、相容缺线模型、共享投影 |',
'| 剖切 | `course_sections.py`、`course_sections_removed.py` | 分部位真实取材、旋转部分、肋板规定、剖后轮廓与移出断面 |',
'| 标准件画法 | `course_standards.py`、`course_gears.py`、`course_thread_details.py` | 连接关系与规定图线、齿轮尺寸、轴承装配 |',
'| 图纸标注与识读 | `course_reading.py`、`course_completion.py` | 原图区域、标记、公差域、表面追踪、确切原题任务 |',
'','## 本轮范围边界','',
'练习入口继续隐藏，草稿及作图后台保留；没有评分、学习统计、账号、联网学习服务或发布。交线只处理本卷出现的结构，不是任意复杂模型求交工具。',
'','无尺寸模型记录教学尺度；曲面离散、轮廓可见性采样和简化齿根用于教学显示，不提供加工级CAD精度。图纸中的已注尺寸和必要公式仍按原题处理。',
'','原生全屏实际显示、操作系统鼠标拖选手感未验收。内部输入验证与实际渲染截图的证据分别保留；不把双击选字测试描述为系统拖曳手感验证。']
md(APP/'当前课程能力清单.md',lines)

md(APP/'全卷课程维护说明.md',[
'# 全卷课程维护说明','',
'## 运行与作者源','',
'通过本目录“开始学习.cmd”运行。运行课程离线读取现有Godot资源；Python、Manifold与PDF工具只用于制作，不是学生启动依赖。',
'','全卷作者入口：`python work/build_exam_course.py`；仅调整文案、步骤与注册信息时可加`--content-only`。几何、图片区域或规定画法改变后必须完整重建，不能只改`assets/course_scenes`或生成JSON。',
'','点章节保留原生成／修缮入口；直线讲解由`work/build_line_learning.py`维护，直线题目由`work/build_line_practice.py`维护，平面由`work/build_plane_lessons.py`维护。新课程生成器不会覆盖这些旧章节。',
'',f'`模型/course_registry.json`为运行注册表；`模型/course/*.json`为13章新课程；`assets/course_scenes/*.json`为{counts["new_scenes"]}个参数／图纸场景。原7个例题的GLB和data.json继续保留。',
'','## 播放器契约','',
'`course_host.gd`提供进入、前进、后退、跳节、退出接口，旧播放器仍处理各自数学与图形。`course_workspace.gd`组织导航、题目列表、文字与布局；`course_player.gd`只处理状态和时间；`course_state.gd`负责稳定状态与中间态。',
'','每段保存稳定ID、所属分节、正文、语义锚点、焦点、动作和来源。进入时从初态重放状态补丁，求得每小段的before/after，不保存动画时刻。动作支持可见性、描线进度、平移、旋转、视野框及连续关键帧。',
'','状态：typing→ready→playing→settled；纯文字直接settled，最后一段完成后complete。problem在逐字阶段同时准备已知图形。忙碌输入只结束当前阶段；keydown回声、长按和修饰键不连续推进。',
'','退出、跳节、换段先增加取消代次并杀死旧Tween；回调核对代次。节点按场景只创建一次，之后改显隐、材质和变换。不要为了下一步重建整场。',
'','新增或合并步骤必须提供resume_aliases；无效目标回到首段。题目每次从头开始。观察状态与课程目标分开，讲解中不回写观察相机。',
'','## 坐标与画法','',
'作者单位毫米。投影：正面(x,−z)、水平(x,y)、侧面(−y,−z)；3D渲染映射(x,z,−y)并乘0.001。既有GLB已用米，不重复缩放。',
'','实体网格与投影共享参数，但工程规定画法独立生成。相贯曲线同时满足两表面方程；旋转剖的倾斜部分作刚体转正，阶梯剖采用分部位取材，连接剖切平面处不加虚构实体边。剖视保留后方可见轮廓；断面只表达截面，回转孔槽按相应规定处理。',
'','`course_canvas.gd`按可见视图拟合并保持对应比例；原题对照图可声明independent_views，它是参考图，不能强行参加实体的尺寸对齐。读图view_box用原图裁剪后的毫米矩形；只改变视野，不改变题图尺寸含义。',
'','`course_space.gd`复用各场景节点池；2D线可携带world_points用于对应点，3D点选由当前实体三角形求交。真实几何、图纸规定和屏幕装饰分开。',
'','## 教学制作检查','',
'每种方法只首次细讲。数字、投影面、题号变化不另起整套教程；后续补点、转移与擦除串成连续动作。问题卡必须说明已知对象和目标。文字不能仅报动作名或复述刚看到的结果。',
'','[小段制作记录](模型/course_authoring_records.json)逐段列出学习者疑问、视觉证据、动作、所消除的不确定性和来源。新课程的记录来自作者源；旧章节按原语义锚点与动作补录。修改文案与场景时重新生成，不能让制作记录脱离运行课程。',
'','正文不放题号、来源、教学尺度声明或无助于判断的坐标算式；后台保留这些事实。齿轮题需要的公式与比例说明不删。题目原图中的题号作为原始资料保留。',
'','## 保存与验证入口','',
'统一观察存档保留版本1，新增`course:<chapter>`状态项；每个观察小节保存相机方向、纸面视野与对应点。已损坏存档保留并禁止覆盖，合法JSON中的坏数组、坏字典也按损坏处理。',
'','`work/check_exam_course.py`核对内容引用、共用坐标、解析交线、实体连通、旋转、齿轮与公差；`work/run_course_qa.py`走新章概念和题目，可加`--minimum`；`work/run_course_state_qa.py`验证跨进程恢复、自然播放、复制和损坏存档。',
'','`work/run_course_legacy_qa.py`走当前题目入口和既有点线面流程；旧测试中依赖已删除练习按钮、旧全剖入口的路径不再代表用户当前入口。`work/run_course_final_qa.py`顺序执行最终验证并记录源码前后哈希。',
'','测试统一使用独立qa存档、屏幕外不抢焦点窗口和Viewport内部输入。禁止系统鼠标移动。QA启动使用Dummy音频驱动，避免系统音频设备变化影响无声动画测试；学生正常启动不改音频驱动。先正常退出，再核对本次创建进程，不关闭用户的其他Godot进程。进程清点由制作端Python的psutil完成，仅对Godot读取命令行和创建时间，避免系统WMI查询阻塞；学生运行不依赖它。'])

with (APP/'全卷课程维护说明.md').open('a',encoding='utf8') as f:
    f.write('\n## 初学者审查与情境准备（2026-10-25）\n\n`work/course_pedagogy.py`维护13章讲解的情境、去重与视觉依据；`course_visual_evidence.py`生成从共用参数推导的教学辅助图。二者由总作者入口调用，`--content-only`重建这些轻量图层，保留原有昂贵实体网格。`review_legacy_concepts.py`由点、直线、平面各自作者入口调用。题目讲解与概念讲解分别维护，不因去重而删除原题。\n\n新例子的`setup`清掉上一例的答案，`prepare_with_text`使已知图准备、阅读定位与文字同时进行；真正构造仍等待D。同一实体的连续变化仍保留原节点。平面`sequence`把已经学过的面内辅助线过程连续播放，不另设逐句等待。\n\n教学审查见[初学者视角讲解审查](初学者视角讲解审查.md)。`work/run_course_beginner_qa.py`抓取每节入口、结果及关键自然动画中间态；截图供人工审查，不以程序通过代替教学判断。\n')
with (APP/'全卷课程维护说明.md').open('a',encoding='utf8') as f:
    f.write('\n## 首次方法与充分条件\n\n只在前文实际建立且输入条件一致时复用方法。已知空间模型向各面投影，与只给二维投影补图必须分开；首次反向转移须示范一个点。取点先核对条件是否足以唯一定位（例如球面前后两候选），查表所得尺寸明确说查表。新推导先显示约束、辅助线及交点，再画完整结果。详见[方法前置与推导审查](方法前置与推导审查.md)。\n\n`work/course_method_review.py`维护本轮13章修缮，`review_legacy_concepts.py`维护旧直线/平面；`work/check_method_derivations.py`核对条件与几何，`run_method_review_qa.py`检查自然中间态及重进。平面`space_project`逐顶点生成真实垂线、垂足，边界另行动画；恢复状态和退出要清理投影指示。\n')
if '--authoring-only' in sys.argv:
    print(json.dumps(counts,ensure_ascii=False));sys.exit(0)
reports={}
for name in ['course-geometry-content.json','course-beginner-geometry.json','course-method-geometry.json','course-check-normal.json','course-check-minimum.json','course-state-write.json','course-state-reopen.json']:
    rows=load(QA/name);assert all(r['passed'] for r in rows),name
    reports[name]={'checks':len(rows),'passed':True,'sha256':sha(QA/name)}
legacy=load(QA/'course-legacy-regression.json');reports.update({k:{'checks':v,'passed':True,'sha256':sha(QA/k)} for k,v in legacy['checks'].items()})
followup=load(QA/'course-points-brace-followup.json') if (QA/'course-points-brace-followup.json').exists() else None
if followup and followup['full_run_sha256']!=sha(QA/'course-final-run.json'):followup=None
if followup:
    for name,count in followup['checks'].items():
        rows=load(QA/name);assert len(rows)==count and all(r['passed'] for r in rows)
        reports[name]={'checks':count,'passed':True,'sha256':sha(QA/name),'rerun':'points brace follow-up'}
for suffix in ['normal','minimum']:
    path=QA/f'course-method-{suffix}.json';x=load(path);assert all(r['passed'] for r in x['checks'])
    reports[path.name]={'checks':len(x['checks']),'passed':True,'sha256':sha(path)}
    path=QA/f'course-extra-{suffix}.json';x=load(path);assert all(r['passed'] for r in x['checks'])
    reports[path.name]={'checks':len(x['checks']),'passed':True,'sha256':sha(path)}
    if followup:
        path=QA/f'course-beginner-legacy-{suffix}.json';x=load(path);assert all(r['passed'] for r in x['checks'])
        reports[path.name]={'checks':len(x['checks']),'passed':True,'sha256':sha(path)}
    path=QA/f'course-beginner-{suffix}.json';x=load(path);assert all(r['passed'] for r in x['checks'])
    reports[path.name]={'checks':len(x['checks']),'passed':True,'sha256':sha(path)}
final=load(QA/'course-final-run.json');assert final['unchanged'] and len(final['completed'])==6
old=load(QA/'navigation-dev-delivery.json')['assets'];assert all(sha(APP/k)==v for k,v in old.items())
processes=[]
for name in ['course-process-normal.json','course-process-minimum.json','course-state-process.json','course-extra-process.json','course-beginner-process-normal.json','course-beginner-process-minimum.json']:
    processes+=load(QA/name)
for suffix in ['normal','minimum']:
    processes+=load(QA/f'course-method-process-{suffix}.json')
    assert load(QA/f'course-method-formal-{suffix}.json')['unchanged']
processes+=legacy['processes']
if followup:
    processes+=followup['processes']
    for suffix in ['normal','minimum']:
        processes+=load(QA/f'course-beginner-process-legacy-{suffix}.json')
        assert load(QA/f'course-beginner-formal-legacy-{suffix}.json')['unchanged']
    assert followup['formal_before']==followup['formal_after']
assert all(p.get('normal_exit') and not p.get('remaining') for p in processes)
visual=load(QA/'course-beginner-visual-review.json');method_visual=load(QA/'course-method-visual-review.json');rebuild=load(QA/'course-reproducibility.json');assert rebuild['matches']
changed=[k for k,v in final['source_after'].items() if sha(APP/k)!=v]
if changed:
    assert followup and followup['full_run_sha256']==sha(QA/'course-final-run.json')
    assert set(changed)==set(followup['source_changes_from_full_run']),changed
    assert all(sha(APP/k)==v for k,v in followup['source_changes_from_full_run'].items())
    assert set(followup['checks'])=={'points-beats-check.json','points-beats-reopen.json'}
delivery=dict(date=datetime.date.today().isoformat(),counts=counts,coverage_status_counts=dict(Counter(ref['status'] for q in coverage['questions'] for r in q['requirements'] for ref in r['demonstrations'])),
    reports=reports,processes=processes,original_model_hashes=old,original_models_unchanged=True,formal_saves_unchanged=legacy['formal_before']==legacy['formal_after'],
    final_source_record='qa/course-final-run.json',reproducibility='qa/course-reproducibility.json',visual_review=visual,method_visual_review=method_visual,method_attempts='qa/course-method-attempts.json',
    interrupted_attempt={'record':'qa/course-interrupted-attempt.json','processes':'qa/course-interrupted-process.json','runtime':'qa/course-interrupted-runtime.log','status':'failed, excluded from pass counts','note':'运行中出现WASAPI设备失效消息，之后超时；正常关闭请求无响应，仅终止该次登记的测试进程。之后QA改用Dummy音频驱动，重新完成最终测试。不能仅凭该日志断言超时的唯一原因。'},
    focused_followup={'changes_after_full_walk':changed,'reason':followup['reason'] if followup else '完整回归后无生产变更','record':'qa/course-points-brace-followup.json' if followup else None,'checks':list(followup['checks']) if followup else [],'current_hashes':{k:sha(APP/k) for k in changed}},
    boundaries={'native_fullscreen_verified':False,'system_mouse_moved':False,'native_drag_feel_verified':False,'industrial_cad_accuracy_claimed':False},
    artifacts=['全卷知识覆盖表.md','当前课程能力清单.md','全卷课程维护说明.md','全卷来源核验.md','全卷验收记录.md','初学者视角讲解审查.md','方法前置与推导审查.md','模型/course_authoring_records.json'])
save(QA/'course-delivery.json',delivery)
lines=['# 全卷分层验收记录','',f'验收日期：{delivery["date"]}。可运行课程、覆盖表和作者源对应当前构建。','',
'## 内容与来源','',f'16章、{counts["concept_beats"]}个讲解小段、{counts["unique_task_ids"]}个去重任务；69道大题的{counts["requirements"]}条作答要求全部有方法归属。没有“待核实”覆盖项。四种覆盖状态的含义见[覆盖表](全卷知识覆盖表.md)，不能据此声称每道同类题都有独立动画。',
'','核对原图与原DOC答案，记录五处冲突。304、G1/2、Q235-A及旧式粗糙度保留原卷语境；外部标准目录只作为版本与名称的依据，不冒充标准全文逐条验证。',
'','## 几何与表达','',
'检查原模型未改、空间／二维共用参数、解析截交及相贯、连通实体、旋转中间态、剖后轮廓、普通四边形与平行四边形区别、紧固件间隙、齿轮主要圆／中心距／不相穿、公差域包含关系、断面方向和原题数字。数学采样断言数量较多，不把数量本身当作教学质量证明。',
'','## 播放、保存与兼容','', '| 记录 | 检查项数 | 结果 |','|---|---:|---|']
for k,v in reports.items():lines.append(f'| [ {k} ](qa/{k}) | {v["checks"]} | 通过 |')
lines+=['','新课程遍历13章讲解和49个题目入口；既有点、直线、平面分别回归。检查按钮／内部A/D、自然完成、即时完成、回退跳节、长按过滤、各阶段退出、重进恢复、非法ID、节点池与视野保持。统一兼容入口也实际进入了点、线、面播放器。',
'','原生选字通过内部双击命中、Ctrl+C检查；系统鼠标未移动，因此没有宣称完成系统拖曳手感验收。合法JSON但嵌套视野形状损坏的存档，同样保留并禁止覆盖。',
'','## 实际渲染','',
'查看正常窗口与1060×720渲染。逐节查看全部16章的入口和结果；重点修订与关键空间构造另看原尺寸及自然播放前、中、后状态。发现的问题修正后重取相应截图，实际查看过的图按哈希独立归档。查看清单与具体观察见[本轮渲染记录](qa/course-beginner-visual-review.json)，内容判断及逐章修改见[初学者审查](初学者视角讲解审查.md)。这不是初学者学习效果测验。',
'','随后按输入条件和方法前置复审，补足平面的逐顶点空间投影、反向转移、正平条件及平行约束，直线的空间分点证据、基本体的取点条件、相贯内外两组点和组合体首个轮廓点的定位。专项自然播放前中后截图及人工观察见[方法推导查看记录](qa/course-method-visual-review.json)；逐章判断见[方法前置与推导审查](方法前置与推导审查.md)。',
'','## 可复现与进程','',
'对照原DOC补全全剖后方顶缘后，重查整套课程、剖视题目及旋转中间态。最小窗口关闭整页缩放，按1060×720真实内容尺寸布局，保持20像素正文。整套最终运行期间生产源码与课程数据哈希不变。完整重建的场景、课程、注册表、覆盖表和资料图片内容哈希一致；原7例GLB/data与既有资产记录一致。',
'','前轮人工补看修正过点章节两处距离括号端点错误，历史专项记录保留在[括号专项](qa/course-points-brace-followup.json)。当前方法推导修订已再次纳入全卷完整回归；前轮局部复测不冒充当前完整运行。',
'',f'正式存档哈希对比：{"未变化" if delivery["formal_saves_unchanged"] else "存在运行期间的并发变化，不能声称完全未变；测试写入路径仍为独立qa文件"}。最后一轮登记的测试进程均正常退出，未留下登记进程；不会据此关闭用户的其他窗口。',
'','历史整卷验收曾出现音频设备失效消息并超时，正常关闭请求未响应，最终仅清理该次登记的测试进程。该次明确记为失败，不计入上表；历史记录保留在`qa/course-interrupted-attempt.json`和对应进程／运行日志中。本轮使用无声音频驱动，正常启动的音频配置未改变。初学者审查期间的过时断言、截图等待和测试脚本解析错误另记，均在修正后重跑，失败尝试不计为通过。',
'','本轮方法审查中发现的遮挡、旧断言和启动前进程清点阻塞，另记[尝试与处理](qa/course-method-attempts.json)。失败尝试不计入最终通过记录。',
'','## 未包含的验收','',
'未验证用户显示器上的原生全屏效果、系统鼠标拖选手感或加工级CAD精度。上述边界不以离屏截图、内部事件或采样数学核验替代。',
'','完整机器记录：[course-delivery.json](qa/course-delivery.json)。']
md(APP/'全卷验收记录.md',lines)
print(json.dumps(counts,ensure_ascii=False))
