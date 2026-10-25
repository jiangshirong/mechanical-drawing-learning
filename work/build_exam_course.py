"""Author source for the 16-chapter course. Run from any working directory.

--content-only preserves expensive generated geometry; the default builds all.
The original point/line/plane author sources remain authoritative adapters.
"""
from course_geometry import *
import copy, hashlib, shutil, argparse
import course_solids,course_standards,course_reading,course_sections,course_sections_removed,course_thread_details,course_completion,course_coverage,course_sources
import course_visual_evidence,course_pedagogy

INDEX=json.loads((ROOT/'学习资料/题集识别/题集索引.json').read_text(encoding='utf-8'))
QUESTIONS={q['id']:q for q in INDEX['questions']}
SCENES={}
COURSES={}
CHAPTERS=[('points','点的三面投影'),('line','直线的投影'),('plane','平面的投影'),('basic_solids','基本体的投影'),('intersection_plane','截交线'),('intersection_solids','相贯线'),('combination','组合体分析与补视图'),('section','剖视图'),('removed_section','移出断面图'),('dimensions','尺寸与基准'),('threads','螺纹及螺纹连接'),('gears','圆柱齿轮'),('bearings','滚动轴承'),('requirements','尺寸与几何公差'),('roughness','表面粗糙度'),('part_drawing','综合读零件图')]

def learner_question(text,action=None,kind='normal'):
    """Authoring review prompt, never inserted into the learner's narration."""
    if kind=='problem':return '当前给出了什么，要补出或判断什么？'
    for words,question in [
        (('剖面线','材料','留空'),'哪些区域确实被切到，哪些是孔、槽或按规定不剖的部分？'),
        (('旋转','转到'),'哪个部分需要转正，转动时哪些尺寸和关系保持不变？'),
        (('截交','相贯','交点'),'这个交点同时满足哪些表面或投影条件？'),
        (('可见','遮挡','虚线','轮廓'),'从当前方向看，这条边界存在且可见吗？'),
        (('基准','公差','偏差'),'被控制的要素是什么，它相对哪个基准受到什么限制？'),
        (('模数','直径','齿数','中心距'),'题给参数决定哪个绘图尺寸，这个尺寸用于哪里？'),
        (('符号','表示','代号','标记','等级'),'当前强调的符号或数值分别表示什么？'),
        (('粗糙度','Ra ','表面质量'),'标注对应哪个实际表面，要求怎样比较？'),
        (('比例','等分','分点'),'应从哪端量取多少份，才能满足给定比例？'),
        (('孔','槽','螺纹'),'这个孔槽或连接部位在其他表达中应是什么形状？'),
        (('投影','对应','等高'),'用哪两个已知关系确定当前投影的位置？'),
        (('移去','剖开','剖切'),'应沿哪里剖开，哪些部分保留用于表达？'),
    ]:
        if any(w in text for w in words):return question
    if action:return '根据当前已知图形，下一笔或下一次空间变化应落在哪里？'
    return '当前图形提供了什么依据，可以作出这一步判断？'

def scene_state(id,**overrides):
    result=dict(scene=id,parts={key:dict(visibility=float(overrides.get(key,e.get('initial',1))),draw=1.0,move=[0,0,0],angle=0.0) for key,e in SCENES[id]['entities'].items()})
    figure=SCENES[id]['entities'].get('figure',{})
    if figure.get('rect'):result['view_box']=figure['rect']
    return result

class Author:
    def __init__(self,id):
        self.id=id;self.groups=[];self.current=None;self.initial=None;self.used=set();self.tasks=[]
    def group(self,id,title,scene,text,problem=False,initial=None):
        self.used.add(scene);self.current=dict(id=id,title=title,scene=scene,beats=[]);self.groups.append(self.current)
        target=scene_state(scene,**(initial or {}))
        if self.initial is None:self.initial=copy.deepcopy(target)
        self.beat('context',text,action=target,kind='problem' if problem else 'normal',question='当前要认识或解决什么？',gain=title)
        return self
    def beat(self,id,text,show=(),hide=(),focus=(),action=None,kind='normal',question=None,gain=None):
        if isinstance(show,str):show=[show]
        if isinstance(hide,str):hide=[hide]
        if isinstance(focus,str):focus=[focus]
        act=copy.deepcopy(action or {})
        if show or hide:
            parts=act.setdefault('parts',{})
            for key in show:parts[key]={'visibility':1.0,'draw':1.0}
            for key in hide:parts[key]={'visibility':0.0}
            # Trace new lines, then remove only the temporary construction aids.
            if show:
                first={key:{'visibility':1.0,'draw':0.0} for key in show}
                act['keyframes']=[{'at':.02,'parts':first}]
        if act:act.setdefault('duration',2.0)
        evidence=list(dict.fromkeys([*show,*focus,*act.get('parts',{})]))
        for frame in act.get('keyframes',[]):evidence+=list(k for k in frame.get('parts',{}) if k not in evidence)
        b=dict(id=self.id+':'+self.current['id']+':'+id,text=text,scene=self.current['scene'],kind=kind,anchor=list(focus or show),focus=list(focus or show),action=act,
               teaching=dict(learner_question=question or learner_question(text,act,kind),visual_evidence=evidence,evidence_scene=self.current['scene'],resolved_uncertainty=gain or text),source_questions=SCENES[self.current['scene']]['source_questions'])
        self.current['beats'].append(b);return self
    def zoom(self,pixels):
        scene=SCENES[self.current['scene']]
        ratio=120/scene['provenance']['output_size'][0]
        self.current['beats'][-1]['action'].update(view_box=[x*ratio for x in pixels],duration=1.4)
        return self
    def task(self,id,title,source,groups=None,statement=None):
        selected=copy.deepcopy([g for g in self.groups if groups is None or g['id'] in groups])
        initial=scene_state(selected[0]['scene'])
        setup=selected[0]['beats'][0].get('action',{})
        if setup.get('scene')==selected[0]['scene']:
            initial=copy.deepcopy(setup)
            initial.pop('duration',None);initial.pop('keyframes',None)
        selected[0]['beats'][0]['kind']='problem'
        selected[0]['beats'][0]['text']=statement or title+'。'
        for g in selected:
            for b in g['beats']:b['id']=id+':'+b['id'];b['source_questions']=[source]
        image=copy_source(source)
        self.tasks.append(dict(id=id,title=title,source_questions=[source],statement=QUESTIONS[source]['task'],source_image=image,lesson=dict(id=id,initial=initial,groups=selected,characters_per_second=16)))
        return self
    def finish(self):
        title=dict(CHAPTERS)[self.id]
        course=dict(schema_version=1,id=self.id,title=title,scenes={key:f'assets/course_scenes/{key}.json' for key in sorted(self.used)},observe=copy.deepcopy(self.initial),concept=dict(id=self.id,initial=self.initial,groups=self.groups,characters_per_second=16,busy_policy='finish'),tasks=self.tasks)
        observations=[]
        for g in self.groups:
            state=scene_state(g['scene'])
            for beat in g['beats']:
                action=beat.get('action',{})
                if action.get('scene'):state=copy.deepcopy(action)
                for key,value in action.get('parts',{}).items():state['parts'].setdefault(key,{}).update(value)
            state.pop('duration',None);state.pop('keyframes',None)
            observations.append({'id':g['id'],'title':g['title'],'state':state})
        course['observations']=observations
        course['observe']=observations[0]['state']
        if self.id=='section':course['concept']['resume_aliases']={old:'section:full:'+new for old,new in [('why_cut','context'),('cut_plane','cut'),('remove_front','remove'),('material_void','hatch'),('project_section','outline'),('rib_convention','rib')]}
        COURSES[self.id]=course;return course

def copy_source(source):
    q=QUESTIONS[source];rel=q['regions'][0]['image'];src=ROOT/'学习资料/题集识别'/rel;dst=APP/'assets/course_sources'/src.name
    dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
    return str(dst.relative_to(APP)).replace('\\','/')

def author_solids():
    a=Author('basic_solids')
    for kind,name in [('prism','棱柱'),('cylinder','圆柱'),('cone','圆锥'),('sphere','球')]:
        a.group(kind,name,'basic_'+kind,'先观察'+name+'的空间形状和三个投影。')
        if kind=='prism':
            a.beat('edges','两个平面的交界形成棱线。',show='generators')
            a.beat('locate','棱上的点，可以沿同一条棱求其余投影。',show='point',focus=['generators','point'])
        elif kind=='cylinder':
            a.beat('silhouette','圆柱侧面的轮廓线随观察方向改变，并不是两条实体棱。',show='generators')
            a.beat('circle','端面投影是圆，先用它确定表面点的前后位置。',show='level')
            a.beat('point','再结合高度，确定另外两面投影。',show='point')
        elif kind=='cone':
            a.beat('generator','圆锥顶点与底圆上的点相连，得到母线。',show='generators')
            a.beat('level','同一高度的横截圆，半径随高度变化。',show='level')
            a.beat('point','取点时，可借母线或横截圆求出位置。',show='point')
        else:
            a.beat('silhouette','各方向的外轮廓都是圆，圆内的点仍需确定深度。',show='generators')
            a.beat('level','用已知高度截出一个圆。',show='level')
            a.beat('point','点同时在球面和这个圆上，再求其余投影。',show='point')
    a.finish()
    a=Author('intersection_plane')
    for kind,name,source in [('prism','棱柱截切','t01-q03'),('cylinder','圆柱截切','t07-q03'),('cone','圆锥截切','t04-q03'),('sphere','球面开槽','t01-q03')]:
        a.group(kind,name,'cut_'+kind,'截去一部分后，怎样确定新的边界？',True)
        a.beat('remove','先辨认保留的部分和各个截平面。',action={'parts':{'removed':{'move':[0,-45,35],'visibility':0}},'duration':2.4},focus='retained')
        if kind=='prism':
            a.beat('guides','截平面先与各条棱相交。',show='guides')
            a.beat('curve','同一棱面上的两个交点，用直线段连接。',show='intersection')
        elif kind=='cylinder':
            a.beat('guides','先确定槽口与圆柱轮廓相交的位置。',show='guides')
            a.beat('curve','水平截面形成圆弧，竖直槽壁的交线另行连接。',show='intersection')
        elif kind=='cone':
            a.beat('guides','取几个横截圆，分别与截平面求交。',show='guides')
            a.beat('curve','把这些交点转到待求视图，连接成光滑曲线。',show='intersection')
        else:
            a.beat('guides','槽底和两侧槽壁分别与球面相交。',show='guides')
            a.beat('curve','各截平面对应一段圆弧；转到投影中再连接。',show='intersection')
        target=SCENES['cut_'+kind]['parameters']['target_view']
        targets=SCENES['cut_'+kind]['parameters'].get('target_views',[target])
        a.beat('answer','从观察方向判断遮挡，补齐轮廓和截交线。',show=['result_'+v for v in targets],hide=['guides','intersection']+(['known_top'] if kind=='sphere' else []),focus='result_'+target)
        a.beat('check','只保留实际存在的边界，截去部分的原轮廓也要删去。',focus='result_'+target)
        a.task('cut-'+kind,name,source,[kind],'完成'+name+'后的缺少投影。')
    a.finish()
    # Basic solid task links reuse the same authored tasks without duplicating a solution.
    for task in a.tasks:
        COURSES['basic_solids']['tasks'].append(copy.deepcopy(task))
    for key,val in a.finish()['scenes'].items():COURSES['basic_solids']['scenes'][key]=val
    a=Author('intersection_solids')
    for kind,title,source in [('inner','两圆柱孔相贯','t06-q04'),('shell','内外圆柱面相贯','t05-q04')]:
        a.group(kind,title,'intersection_'+kind,'两处圆柱面相交，交线应怎样确定？',True)
        a.beat('surfaces','移开遮挡看内部：交线上的点必须同时落在两处表面上。',show='cutaway',hide='body')
        a.beat('special','先找轮廓处和对称位置的特殊点。',show=['guides','special'])
        a.beat('middle','在曲线转弯处补取中间点。',show='intermediate')
        a.beat('connect','沿同一相贯支连接，不能跨过孔口乱连。',show='intersection')
        if kind=='shell':a.beat('inner_outer','外表面和内孔分别形成交线，两组交点分别连接。',focus='intersection')
        a.beat('visible','从正面看，内孔交线被材料挡住，画虚线。' if kind=='inner' else '外表面交线可见，内孔交线被遮挡，分别用实线和虚线。',show='body',hide=['guides','special','intermediate','cutaway'],focus=['body_front','intersection'])
        a.task('intersection-'+kind,title,source,[kind])
    a.finish()

def author_combination():
    a=Author('combination')
    for model,title,source,target in [('slope','形体分析','t02-q03','left'),('base','线面分析','t02-q03','left'),('bracket','补俯视图','t07-q05','top'),('missing','补缺漏线','t08-q07','left')]:
        sc='combination_'+model;entities=SCENES[sc]['entities'];target_ids=[key for key in entities if (key.startswith(target+'_') or key=='body_'+target)]
        overrides={key:0 for key in target_ids}
        a.group(model,title,sc,'根据已知投影，确定缺少的图线。',True,overrides)
        if model=='slope':a.beat('parts','先分清主体、斜面和切去的槽。',focus=[x for x in entities if 'slot' in x or 'slope' in x])
        elif model=='base':a.beat('planes','外形不好分块时，追踪同一条边和同一个面。',focus=[x for x in entities if x.startswith('front')])
        elif model=='bracket':a.beat('known','正面给左右和高度，侧面给前后和高度。',focus=[x for x in entities if x.startswith('front') or x.startswith('left')])
        else:a.beat('missing','先找哪些孔槽在另一面出现，却在这里缺少边界。',focus=['body_front','body_top'])
        midpoint=max(1,len(target_ids)//2)
        if model=='missing':
            a.beat('outer','先补俯视图中的槽边和隐藏轮廓。',show='body_top',hide='known_top')
            a.beat('detail','再补左视图中的孔和台阶。',show='body_left',hide='known_left')
        else:
            a.beat('outer','先画外轮廓，保持相同位置量对应。',show=target_ids[:midpoint])
            if target_ids[midpoint:]:a.beat('detail','再补孔槽与相接边界。',show=target_ids[midpoint:])
        a.beat('visibility','逐条判断遮挡；有轮廓才画线，有遮挡才用虚线。',focus=target_ids)
        a.beat('check','相接处若没有折角或轮廓变化，就不凭空加线。',focus=target_ids)
        a.task('combination-'+model,title,source,[model])
    a.finish()

def author_sections():
    a=Author('section')
    for kind,title,source in [('full','全剖与肋板','t01-q05'),('half','半剖','t04-q04'),('local','局部剖','t01-q09'),('stepped','阶梯剖','t08-q08'),('rotated','旋转剖','t01-q06'),('combined','多部位剖切','t03-q04')]:
        sc='section_'+kind;es=SCENES[sc]['entities'];front=[x for x in es if x.startswith('front_') or x=='body_front']
        a.group(kind,title,sc,{'full':'内部结构被遮住时，怎样把它表达清楚？','half':'对称结构怎样同时表达内外形状？','local':'只需说明局部内部结构，该剖开多少？','stepped':'几个孔不在同一平面，怎样一起表达？','rotated':'两个孔的轴线方向不同，怎样在同一剖视中表达？','combined':'先确定各部位的剖切路径，再组合表达。'}[kind],True)
        if kind=='full':
            a.beat('cut','剖切平面经过两个孔的轴线，便于表达内部结构。',show='cutting_plane')
            a.beat('remove','移去观察者与剖切平面之间的部分。',action={'keyframes':[{'at':.01,'parts':{'model':{'visibility':0},'cut_model':{'visibility':1},'removed':{'visibility':1}}},{'at':.8,'parts':{'removed':{'move':[0,-85,20]}}}],'parts':{'model':{'visibility':0},'cut_model':{'visibility':1},'removed':{'visibility':0,'move':[0,-85,20]},'cutting_plane':{'visibility':0}}},focus='cut_model')
            a.beat('imagined','这是假想剖开，零件本身仍是完整的。')
            a.beat('outline','投射留下的部分，先画可见轮廓。',show='section_outline',hide=front)
            a.beat('hatch','被切到的实体材料画剖面线，孔中留空。',show='hatching')
            a.beat('rib','沿肋板长度方向剖切时，肋板不画剖面线。',focus='section_outline')
            a.beat('reason','否则容易把肋板和底座、凸台看成一整块厚实材料。',focus='section_outline')
            a.beat('rib_cross','留白不代表孔洞；横向切断肋板时仍要画剖面线。',focus='section_outline')
        elif kind=='local':
            a.beat('region','只剖开需要说明内部结构的局部，其余外形保留。',show='local_region')
            a.beat('boundary','剖开与未剖开的分界用波浪线，不与实体轮廓重合。',show='break_boundary',hide='local_region')
            a.beat('material','剖面线说明被切到的材料；未剖开处仍按外形表达。',focus='break_boundary')
        else:
            if kind in ['stepped','rotated','combined']:a.beat('path','先标出剖切位置和观察方向。',show=['cutting_path','cutting_planes'])
            a.beat('cut','剖开需要表达的部位，辨认被切材料与空腔。',show=['cut']+(['rotating_arm'] if kind in ['rotated','combined'] else []),hide='body')
            if kind in ['rotated','combined']:a.beat('unfold','将倾斜剖切部分转到与正面平行的位置。',action={'parts':{'rotating_arm':{'angle':-30}}},focus='rotating_arm')
            if kind=='half':text='以对称中心线分界，一半外形，一半剖视。'
            elif kind=='local':text='局部剖开处用波浪线分界，不与原轮廓线重合。'
            elif kind=='stepped':text='各平行剖切平面合并表达，转折处不画分界线。'
            else:text='先将倾斜剖切部分旋转到投影面平行的位置，再表达。'
            a.beat('outline',text,show=['section_outline','hatching']+(['centre_line'] if kind=='half' else []),hide=front+(['body_left'] if kind=='half' else [])+(['cutting_planes'] if kind in ['stepped','rotated','combined'] else []))
            if kind in ['rotated','combined']:a.beat('no_distortion','旋转的是剖切部分的表达关系，不把所有结构一起拉长。',focus='section_outline')
        a.task('section-'+kind,title,source,[kind])
    a.finish()
    a=Author('removed_section')
    for kind,title in [('key','键槽断面'),('hole','孔槽断面')]:
        a.group(kind,title,'removed_'+kind,'在指定位置画出移出断面。',True)
        a.beat('plane','先确定切到哪里，以及从哪一侧看。',show=['cutting_plane','cut_location','direction'])
        a.beat('range','断面只表达切到的截面，不带上后方的外轮廓。',focus='cutting_plane')
        a.beat('outline','按截面上的圆、键槽或孔画边界。',show='outline',hide='body_left')
        if kind=='key':a.beat('depth','键槽深3 mm，从轴的外圆表面向内量。',focus='outline')
        else:a.beat('through','剖切平面经过回转孔槽轴线时，按剖视表达孔槽边界。',focus='outline')
        a.beat('hatch','实体区域画剖面线，孔槽区域留空。',show='hatching',hide='cutting_plane')
        a.task('removed-'+kind,title,'t03-q07',[kind])
    a.group('compare','断面改错','removed_compare','两侧槽和钻孔的断面，哪些边界应该保留？',True)
    a.beat('shape','两侧是向外开口的槽，槽口不能封闭。',show=['correct','hatching','wrong_slots'],hide='body_left')
    a.beat('notches','删去把槽口封住的两条线。',hide='wrong_slots',focus='correct')
    a.beat('drill','切到回转孔槽轴线时，按剖视表达，补出孔后可见圆弧。',show='rear_arc')
    a.beat('correct','两侧开口、孔后圆弧都保留，才能说明真实结构。',focus=['correct','rear_arc'])
    a.task('removed-compare','移出断面判断','t08-q09',['compare'])
    a.finish()

def author_standards():
    a=Author('threads')
    for kind,title in [('external','外螺纹'),('internal','内螺纹')]:
        a.group(kind,title,'thread_'+kind,'先分清牙顶与牙底，再看图纸怎样简化它们。')
        a.beat('real','空间螺旋说明牙形；工程图不用逐牙描画。',show='helix')
        a.beat('major','外螺纹大径画粗实线，小径画细实线。' if kind=='external' else '内螺纹小径画粗实线，大径画细实线。',show=['major','minor'],hide='helix')
        a.beat('end','端面投影中，细实线圆只画约四分之三圈。',show=['end_major','end_minor'])
        a.beat('termination','有效螺纹的终止位置，用粗实线表示。',show='termination')
    a.group('engaged','旋合画法','thread_engaged','内外螺纹旋合后，哪些图线需要保留？',True)
    a.beat('outer','旋合部分按外螺纹画法表达。',show=['male_major','male_minor'])
    a.beat('female','未旋合的内螺纹仍按内螺纹画法表达。',show=['female_major','female_minor','boundary'])
    a.beat('end','端面只保留大径粗圆和小径四分之三细圆。',show=['end','end_minor'])
    a.beat('material','剖面线画到实际材料的粗实线边界。',show='hatching')
    a.beat('check','交界处对齐大径和小径，不重复叠画两套牙形。',focus=['male_major','female_major'])
    for kind,title in [('bolt','螺栓连接'),('stud','双头螺柱连接')]:
        a.group(kind,title,'fastener_'+kind,'观察连接件和孔的关系，再补齐连接图。',True)
        a.beat('parts','先区分被连接件、紧固件和垫圈。',focus=['lower','upper','washer','nut','shank'])
        a.beat('hole','螺栓穿过通孔，通孔与杆部之间留有间隙。' if kind=='bolt' else '螺柱一端旋入螺纹孔，另一端穿过被连接件的通孔。',show='clearance')
        a.beat('shank','画出杆部和头部。' if kind=='bolt' else '确定旋入端与紧固端的位置。',show=['shank_ink','head_ink'])
        a.beat('nut','补螺母、垫圈及露出的螺纹。',show=['nut_ink','thread_minor','engagement'])
        a.beat('hatch','相邻零件用不同方向或间距的剖面线区分。',show=['lower_hatch','upper_hatch'])
        a.beat('rule','沿紧固件轴线剖切时，杆、头和螺母按不剖处理。',show='top',focus='shank_ink')
    for name,title,lines in [('coarse','普通螺纹标记',['M表示普通螺纹。','8是公称直径，单位为毫米。','7H是内螺纹公差带；粗牙螺距省略。']),('fine','细牙及外螺纹',['M12表示公称直径12 mm的普通螺纹。','1.5是螺距，细牙螺纹需要标出。','6g是外螺纹公差带，小写字母用于外螺纹。']),('pipe','管螺纹',['G表示非螺纹密封的管螺纹。','1/2是管螺纹公称尺寸代号，不是实际外径的直接换算。'])]:
        a.group('mark_'+name,title,'thread_mark_'+name,'把螺纹标记分开读。')
        for i,text in enumerate(lines):a.beat('token'+str(i),text,focus='token'+str(i))
        if name=='fine':a.beat('internal','若公差带写成6H，大写字母说明它是内螺纹。',show='internal_compare')
        if name=='pipe':a.beat('internal','这处标注指向孔内壁，所以是内螺纹。',show='internal_example')
    a.task('thread-judge','判断内外螺纹画法','t05-q06',['external','internal'])
    a.task('thread-engaged','改正旋合螺纹','t03-q06',['engaged'])
    a.task('bolt-connect','补螺栓连接','t01-q07',['bolt'])
    a.task('stud-connect','改正双头螺柱连接','t02-q06',['stud'])
    a.task('bolt-correct','螺栓连接改错','t08-q10',['bolt'])
    for name,src in [('coarse','t02-q08'),('fine','t06-q08'),('pipe','t01-q09')]:a.task('thread-mark-'+name,'解释螺纹标记：'+{'coarse':'M8—7H','fine':'M12×1.5—6g','pipe':'G1/2'}[name],src,['mark_'+name])
    a.finish()
    a=Author('gears')
    for pair,title,source in [(False,'单齿轮','t02-q07'),(True,'齿轮啮合','t01-q08')]:
        sc='gear_pair' if pair else 'gear_single';p=SCENES[sc]['parameters'];m=p['module'];zs=p['teeth']
        a.group('pair' if pair else 'single',title,sc,'已知模数和齿数，怎样画出齿轮？' if not pair else '两个齿轮啮合，先确定尺寸和轴线位置。',True)
        a.beat('meaning','模数决定齿的大小，齿数决定分度圆上有多少个齿。',focus=['gear0'])
        last_label=[]
        for i,z in enumerate(zs):
            a.beat('pitch'+str(i),f'分度圆直径 d＝mz＝{m*z} mm。',show=['pitch'+str(i),'label_d'+str(i)],hide=last_label)
            a.beat('addendum'+str(i),f'齿顶圆直径 dₐ＝m(z＋2)＝{m*(z+2):g} mm。',show=['label_da'+str(i),'addendum'+str(i)],hide=['label_d'+str(i)])
            a.beat('root'+str(i),f'标准齿根圆直径 df＝m(z－2.5)＝{m*(z-2.5):g} mm。',show=['root'+str(i),'label_df'+str(i)],hide=['label_da'+str(i)])
            last_label=['label_df'+str(i)]
        if pair:a.beat('centres',f'中心距 a＝m(z₁＋z₂)/2＝{p["centre_distance"]:g} mm，两分度圆相切。',show=['centre_distance','centre_label'],hide=last_label)
        a.beat('convention','齿顶圆用粗实线，分度圆用细点画线，齿根圆用细实线。',show=['side'+str(i) for i in range(len(zs))]+['side_pitch'+str(i) for i in range(len(zs))],hide=last_label)
        a.beat('section','轴向剖视中，轮齿不画剖面线，齿根线改画粗实线。',show=['side_root'+str(i) for i in range(len(zs))]+['gear_hatch'+str(i) for i in range(len(zs))])
        if pair:a.beat('mesh','啮合区分清遮挡，端面不重复画两条相交的齿顶轮廓。',show=['meshing_contours','contact_visible','contact_hidden'],hide=['addendum0','addendum1'])
        if pair:a.beat('scale','按1∶2绘图，纸面长度减半；标注仍写实际尺寸。',focus=['centre_distance'])
        a.task('gear-pair' if pair else 'gear-single',title+'计算与作图',source,['pair' if pair else 'single'])
    a.finish()
    a=Author('bearings');a.group('structure','组成与代号','bearing','轴承怎样把轴支承在座孔中？')
    a.beat('rings','内圈装在轴上，外圈装在座孔中。',focus=['inner','outer'])
    a.beat('balls','滚动体在内外圈之间滚动。',focus=['ball'+str(i) for i in range(8)])
    a.beat('cage','保持架将滚动体分隔开。',focus='cage')
    a.beat('code','304是这里使用的向心球轴承代号。')
    a.beat('diameter','04表示内径20 mm，3表示尺寸系列。',show='diameter')
    a.beat('size','按给定外径52 mm、宽15 mm确定安装位置。',show=['outside','width'])
    a.group('assembly','孔轴装配','bearing','在孔与轴之间补出轴承装配结构。',True)
    a.beat('shaft','让内圈与轴的安装表面对应。',show=['shaft','shaft_ink'])
    a.beat('housing','让外圈与座孔对应，端面贴合指定定位面。',show=['housing','housing_ink'])
    a.beat('convention','用规定的简化画法表达轴承，不逐个描画滚动体。',show='convention')
    a.task('bearing-assembly','轴承代号与装配','t03-q08');a.finish()

def author_reading():
    a=Author('dimensions')
    a.group('datum','三个方向的基准','read_lid','找出长、宽、高三个方向的尺寸基准。',True)
    a.beat('reason','基准是确定其他位置的起点，要沿尺寸线寻找共同起点。',focus='front')
    a.beat('height','高度方向以底面为基准；两个径向方向以回转轴线为基准。',show='front')
    a.group('location','定形与定位','read_lid_plan','区分结构有多大，以及结构在哪里。')
    a.beat('shape','孔径和槽宽确定结构大小。',show='slot')
    a.beat('position','孔的分布圆和轴线关系确定位置。',show='thread_holes')
    a.beat('axes','回转零件的轴线同时承担两个径向位置基准。',show='datum_axes')
    a.beat('scale','尺寸数字表示实际大小，不能用屏幕上的长度代替。')
    a.task('dimensions-lid','基准与定位尺寸','t08-q11');a.finish()
    a=Author('requirements')
    for kind,title in [('hole','孔的尺寸公差'),('shaft','轴的尺寸公差')]:
        a.group(kind,title,'tolerance_'+kind,'尺寸后面的字母和数字，分别限制什么？')
        a.beat('size','直径数字是基本尺寸。',focus='token0')
        a.beat('deviation','字母是基本偏差代号，确定公差带相对零线的位置。',show='nominal',focus='token1')
        a.beat('grade','后面的数字是标准公差等级，决定允许变动的大小。',show='zone',focus='token2')
        a.beat('distinction','大写用于孔，小写用于轴；公差带代号由字母和等级共同组成。')
        a.task('tolerance-'+kind,title+'标记解释','t02-q08' if kind=='hole' else 't05-q08',[kind])
    for kind,title,text in [('perpendicular','轴线垂直度','带直径符号时，轴线应位于垂直于基准的圆柱形公差域内。'),('plane','表面垂直度','这里没有直径符号，被测表面限制在两平行平面之间。'),('parallel','平行度','被测表面应位于平行于基准的两平行平面之间。')]:
        a.group(kind,title,'tolerance_'+kind,'先找被测要素，再读要求相对哪个基准成立。')
        a.beat('datum','框格最后的字母指明基准。',show='datum',focus='token2')
        a.beat('zone',text,show='zone',focus=['token0','token1'])
        a.beat('actual','实际要素可以有误差，但必须全部落在公差域内。',show='actual')
        a.beat('units','数值表示公差域的大小，图中间距作放大示意。')
        a.task('tolerance-'+kind,title+'框格解释',{'perpendicular':'t02-q08','plane':'t06-q08','parallel':'t04-q07'}[kind],[kind])
    a.finish()
    a=Author('roughness');a.group('symbol','符号与数值','roughness','表面粗糙度标记同时说明表面要求和加工限制。')
    a.beat('basic','基本符号先指出被要求的表面。',show='basic')
    a.beat('removal','加横线，表示用去除材料的方法获得表面。',show=['removal','bar'])
    a.beat('retained','加圆圈，表示不去除材料。',show=['retained','circle'])
    a.beat('value','Ra是轮廓算术平均偏差；这里的要求值为6.3 μm。',show='value')
    a.beat('compare','同一参数下，要求值越小，表面越光滑。',show='compare')
    a.beat('rest','“其余”适用于未单独标注要求的表面。',show='remaining')
    a.group('surface','跨视图找表面','read_end_cover','找出Ⅰ、Ⅱ、Ⅲ对应表面的粗糙度。',True)
    a.beat('I','Ⅰ对应的表面没有单独数值，按“其余”要求不去除材料。',show='surface_I').zoom([210,75,630,440])
    a.beat('II','追踪Ⅱ所指的表面，对应 Ra 6.3。',show='surface_II',hide='surface_I')
    a.beat('III','Ⅲ沿投影对应到另一面的标注，要求为 Ra 25。',show='surface_III',hide='surface_II')
    a.group('errors','标注检查','read_shaft_errors','检查符号是否落在正确表面，以及方向是否符合规定。',True)
    a.beat('end','先看这处正确标注：尖端指向表面，数字从右方读。',show='correct_example').zoom([80,330,510,225])
    a.beat('direction','这两处数字转向了左方，方向有误。',show=['error_vertical','error_inverted'],hide='correct_example')
    a.beat('correct','保持所指表面，改正两处数字的阅读方向。',show=['correct_0','correct_1'],hide=['error_vertical','error_inverted'])
    a.task('roughness-surfaces','识别各表面的粗糙度','t05-q08',['surface'])
    a.task('roughness-errors','粗糙度标注改错','t07-q09',['errors'])
    a.task('roughness-quality','比较表面质量要求','t08-q11',['symbol']);a.finish()
    a=Author('part_drawing')
    a.group('overview','读图顺序','read_bearing_block','先看表达方法，再还原结构，最后读尺寸与技术要求。')
    a.beat('views','主视图用波浪线分界，采用局部剖视。',show='front_region').zoom([35,35,550,430])
    a.beat('side','左视图一半外形、一半剖视，采用半剖视。',show='side_region',hide='front_region').zoom([620,55,320,430])
    a.beat('top','俯视图在 A—A 位置剖开，采用全剖视。',show='top_region',hide='side_region').zoom([45,470,555,275])
    a.beat('cut','俯视剖切的高度，对应主视图中的 A—A 线。',show='cut_top',hide='top_region').zoom([35,35,550,430])
    a.beat('cut_side','左视剖切经过左右对称面，在俯视图中确定位置。',show='cut_side',hide='cut_top').zoom([45,470,555,275])
    a.beat('cut_front','主视局部剖经过前后对称面，在俯视图中确定位置。',show='cut_front',hide='cut_side')
    a.group('details','工艺结构与局部放大','read_shaft','先把局部放大图对应回原零件。')
    a.beat('detail','2∶1只改变图形的绘制大小，标注仍表示实际尺寸。',show='detail').zoom([130,30,210,155])
    a.beat('chamfer','两处端部倒角分别为 C2、C1.5。',show=['chamfer_left','chamfer_right'],hide='detail').zoom([40,255,615,185])
    a.beat('groove','一处退刀槽，尺寸2×2；它为刀具退出留出空间。',show='grooves',hide=['chamfer_left','chamfer_right']).zoom([445,280,220,180])
    a.beat('section','接下来，在指定位置补出键槽断面。',show='section',hide='grooves').zoom([400,20,250,480])
    a.group('lid','综合识读','read_lid','读懂釜盖的表达、孔槽及技术要求。',True)
    a.beat('front','主视图用全剖说明内部台阶，俯视图说明孔槽分布。',show='front')
    a.beat('holes','先读数量和螺纹代号，再核对分布位置。',show='holes')
    a.beat('slots','槽宽、槽形和上方沉孔要结合两个视图辨认。',show='slots')
    a.group('note','数量、深度与孔形','read_lid_note','区分螺纹深度、钻孔深度和沉孔尺寸。')
    a.beat('thread','6个M12螺孔均匀分布；螺纹深10 mm，底孔深18 mm。',show='hole_note')
    a.beat('slots','6处槽宽23 mm，槽上方锪平直径44 mm。',show='slot_note')
    a.group('material','材料与要求','material','标题栏中的材料代号也属于读图内容。')
    a.beat('Q','Q表示按屈服强度命名的结构钢。',focus='token0')
    a.beat('strength','235是牌号中的屈服强度等级数值，单位MPa。',focus='token1')
    a.beat('grade','A是质量等级；实际性能还与标准和厚度有关。',focus='token2')
    a.task('read-block','识别表达方法与剖切位置','t02-q08',['overview'])
    a.task('read-shaft','断面与工艺结构','t06-q08',['details'])
    a.task('read-lid','综合识读釜盖','t08-q11',['lid','note','material'])
    a.task('read-outline','从剖视恢复外形','t01-q09',['overview']);a.finish()

def build_registry():
    aliases={'slope':{'chapter':'combination','group':'slope'},'base':{'chapter':'combination','group':'base'},'bracket':{'chapter':'combination','group':'bracket'},'half_section':{'chapter':'section','group':'half'},'stepped_section':{'chapter':'section','group':'stepped'},'cutting':{'chapter':'section','group':'full'},'construction':{'chapter':'line','group':'point_on_line'}}
    chapters={}
    for i,(id,title) in enumerate(CHAPTERS):
        chapters[id]=dict(id=id,title=title,order=i+1,legacy=i<3,adapter=('legacy_'+id if i<3 else ('solids' if i<6 else 'projection' if i==6 else 'section' if i<9 else 'conventions' if i in [10,11,12] else 'reading')),course=f'模型/course/{id}.json' if i>=3 else None)
        if i<3:chapters[id].update(observe=f'assets/examples/{id}/data.json',concept=f'模型/{"points" if i==0 else id}_learning.json',questions=f'模型/{"points_learning" if i==0 else "line_practice" if i==1 else "plane_questions"}.json',controller='course_host.gd')
    write_json(APP/'模型/course_registry.json',dict(schema_version=1,chapters=chapters,aliases=aliases))
    # Rows represent learning stages. Connector gutters do not pass through cards.
    positions={'points':[430,50],'line':[430,180],'plane':[430,310],'basic_solids':[430,440],'intersection_plane':[120,580],'intersection_solids':[740,580],'combination':[430,740],'section':[430,880],'removed_section':[740,1010],'dimensions':[120,1010],'threads':[120,1160],'gears':[430,1160],'bearings':[740,1160],'requirements':[120,1310],'roughness':[740,1310],'part_drawing':[430,1480]}
    prerequisites=[('points','line'),('line','plane'),('plane','basic_solids'),('basic_solids','intersection_plane'),('basic_solids','intersection_solids'),('basic_solids','combination'),('combination','section'),('section','removed_section'),('dimensions','requirements'),('section','part_drawing'),('requirements','part_drawing'),('roughness','part_drawing')]
    graph=dict(schema_version=3,note='仅按本合订卷组织；实线为方法前置，虚线为推荐顺序；不锁定学习资格。',extent=[1040,1580],groups=[],nodes=[dict(id=id,title=title,example=id,position=positions[id]) for id,title in CHAPTERS],edges=[dict(**{'from':a,'to':b}) for a,b in prerequisites])
    for a,b in [('intersection_plane','combination'),('intersection_solids','combination'),('threads','part_drawing'),('gears','part_drawing'),('bearings','part_drawing')]:graph['edges'].append({'from':a,'to':b,'kind':'recommended'})
    routes={('dimensions','requirements'):[[120,1054],[275,1054],[275,1250],[120,1250],[120,1264]],('section','part_drawing'):[[430,924],[585,924],[585,1420],[430,1420],[430,1434]],('threads','part_drawing'):[[120,1204],[290,1204],[290,1400],[430,1400],[430,1434]],('bearings','part_drawing'):[[740,1204],[920,1204],[920,1420],[430,1420],[430,1434]]}
    for edge in graph['edges']:
        if (edge['from'],edge['to']) in routes:edge['route']=routes[edge['from'],edge['to']]
    write_json(APP/'assets/knowledge_map.json',graph)

def main():
    args=argparse.ArgumentParser();args.add_argument('--content-only',action='store_true');opts=args.parse_args()
    if not opts.content_only:
        for module in [course_solids,course_standards,course_reading,course_sections,course_sections_removed,course_thread_details,course_completion]:
            for scene in (module.new_scenes() if module==course_sections else module.all_scenes()):
                write_json(APP/f'assets/course_scenes/{scene.data["id"]}.json',scene.save());print(scene.data['id'],flush=True)
    for file in (APP/'assets/course_scenes').glob('*.json'):SCENES[file.stem]=json.loads(file.read_text(encoding='utf-8'))
    # Cheap teaching overlays are regenerated even when expensive solid meshes are reused.
    for scene in course_visual_evidence.teaching_scenes():SCENES[scene.data['id']]=scene.save()
    for id,scene in list(SCENES.items()):
        SCENES[id]=course_visual_evidence.enhance(scene)
        write_json(APP/f'assets/course_scenes/{id}.json',SCENES[id])
    author_solids();author_combination();author_sections();author_standards();author_reading()
    course_completion.augment(globals())
    course_pedagogy.apply(COURSES,SCENES)
    from course_method_review import apply as method_review
    method_review(COURSES,SCENES)
    course_sources.build(COURSES,SCENES,INDEX)
    for id,course in COURSES.items():write_json(APP/f'模型/course/{id}.json',course)
    build_registry();course_coverage.build(INDEX,COURSES)
    print(json.dumps({'new_chapters':len(COURSES),'scenes':len(SCENES),'concept_beats':sum(len(g['beats']) for c in COURSES.values() for g in c['concept']['groups']),'tasks':sum(len(c['tasks']) for c in COURSES.values())},ensure_ascii=False))

if __name__=='__main__':main()
