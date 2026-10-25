"""2026-10-25 concept review: situation -> evidence -> useful inference.

This author pass changes the explanations, not the independent original-question
solutions. Stable IDs survive text edits; removed beats explicitly migrate.
"""
import copy

class Review:
    def __init__(self,courses,scenes):self.courses=courses;self.scenes=scenes
    def lesson(self,c):return self.courses[c]['concept']
    def group(self,c,g):return next(x for x in self.lesson(c)['groups'] if x['id']==g)
    def beat(self,id):
        c,g,_=id.split(':',2)
        try:return next(b for b in self.group(c,g)['beats'] if b['id']==id)
        except StopIteration:raise ValueError('Unknown authored beat: '+id)
    def text(self,id,text,focus=None):
        b=self.beat(id);b['text']=text
        if focus is not None:b['focus']=b['anchor']=focus
        return b
    def texts(self,c,g,values):
        names={('basic_solids','prism','point'):'locate',('basic_solids','cone','generators'):'generator',('basic_solids','sphere','circle'):'silhouette'}
        for id,text in values.items():
            id=names.get((c,g,id),'connect' if c=='intersection_solids' and id=='curve' else id)
            self.text(f'{c}:{g}:{id}',text)
    def add(self,c,g,id,text,after=None,action=None,focus=(),kind='normal'):
        group=self.group(c,g);template=group['beats'][0]
        b=dict(id=f'{c}:{g}:{id}',text=text,scene=group['scene'],kind=kind,action=action or {},focus=list(focus),anchor=list(focus),source_questions=template['source_questions'])
        at=len(group['beats']) if after is None else next(i+1 for i,b in enumerate(group['beats']) if b['id'].endswith(':'+after))
        group['beats'].insert(at,b);return b
    def drop(self,c,g,ids,target):
        ids=[f'{c}:{g}:{i}' for i in ids];self.group(c,g)['beats'][:]=[b for b in self.group(c,g)['beats'] if b['id'] not in ids]
        self.lesson(c).setdefault('resume_aliases',{}).update({id:f'{c}:{g}:{target}' for id in ids})
    def show(self,id,show=(),hide=(),duration=1.8):
        b=self.beat(id);b['action']=drawing(show,hide,duration);b['focus']=b['anchor']=list(show)
    def state(self,scene,**overrides):
        return dict(scene=scene,parts={k:dict(visibility=float(overrides.get(k,e.get('initial',1))),draw=1.,move=[0,0,0],angle=0.) for k,e in self.scenes[scene]['entities'].items()})
    def intro_group(self,c,g,title,scene,text):
        self.courses[c]['scenes'][scene]=f'assets/course_scenes/{scene}.json'
        group=dict(id=g,title=title,scene=scene,beats=[dict(id=f'{c}:{g}:context',text=text,scene=scene,kind='normal',focus=[],anchor=[],action=self.state(scene),source_questions=self.scenes[scene]['source_questions'])])
        self.lesson(c)['groups'].insert(0,group);self.lesson(c)['initial']=self.state(scene)

def drawing(show=(),hide=(),duration=1.8):
    return dict(parts={**{k:dict(visibility=1.,draw=1.) for k in show},**{k:dict(visibility=0.) for k in hide}},keyframes=[dict(at=.02,parts={k:dict(visibility=1.,draw=0.) for k in show})] if show else [],duration=duration)

def apply(courses,scenes):
    r=Review(courses,scenes)
    r.texts('basic_solids','prism',{'context':'点、线、面组成了立体。先看棱柱：怎样用投影说明它的形状？','edges':'棱柱相邻平面的交线是棱；同一条棱对应各面的线段。','point':'已知点在这条棱上，可在线的投影上定位它。'})
    r.texts('basic_solids','cylinder',{'context':'换成圆柱：侧面是曲面，图中的两条直线还是棱吗？','silhouette':'圆柱侧面没有这两条棱；它们是从当前方向看见的曲面边界。','circle':'沿轴线看，圆柱积聚成圆；侧面上的点必落在圆周上。','point':'先在圆周上确定前后、左右位置，再用高度确定空间点。'})
    r.texts('basic_solids','cone',{'context':'圆锥越靠近顶点越细。怎样确定它表面上的点？','generators':'从顶点连到底面圆周的直线叫母线，整条线都在锥面上。','level':'指定高度处的横截面是圆；高度不同，圆的大小也不同。','point':'已知点在这条母线上，再用高度定位；也可借同高度的圆定位。'})
    r.texts('basic_solids','sphere',{'context':'球面没有棱和顶点。确定表面点时，可以借一个圆吗？','circle':'球的投影轮廓是圆，但轮廓内的点也可能在球面上。','level':'用水平面截球，得到同一高度的圆。','point':'先在这个圆上确定点的位置，再求其他投影；后面求交线也会用到它。'})
    r.text('basic_solids:cylinder:circle','沿轴线看，圆柱轮廓是圆；侧面上的点都投影在圆周上。')
    r.text('basic_solids:cone:point','选定这条母线，再与同高度的圆相交，确定表面点。')
    r.beat('basic_solids:cone:point')['action']['parts']['point_generator']={'visibility':1.,'draw':1.}
    r.beat('basic_solids:cone:point')['focus']+=['point_generator']
    cuts={
        'prism':('已知棱柱的切割位置，怎样补出截切后的侧面投影？','斜切面与各条棱相交，先求这些交点。','在棱柱的同一个面上，连接相邻交点。'),
        'cylinder':('圆柱上方削去两侧，下方开槽，怎样补出侧面投影？','先找槽壁与圆柱的交点；俯视圆给出它们的前后位置。','水平截面上的交线是圆弧；竖直槽壁上的交线沿母线。'),
        'cone':('横放的圆锥与两段圆柱被水平面截切，怎样补水平投影？','在圆锥上取几个垂直轴线的圆，分别求它们与截平面的交点。','锥面上的公共点连成曲线；圆柱部分的交线沿轴向。'),
        'sphere':('半球上开一个槽，怎样求槽壁与球面的交线？','槽底、两侧槽壁分别与球面相交，先找它们交接处的点。','每个平面都从球上截出圆；只保留属于槽口边界的圆弧。')}
    for kind,(context,guide,curve) in cuts.items():
        r.texts('intersection_plane',kind,{'context':context,'remove':'移开被切去的材料，辨认截平面与原表面的公共边界。','guides':guide,'curve':curve,'answer':'从所求视图的方向看：可见边界画实线，被挡住的边界画虚线。','check':'切掉部分的旧轮廓不再保留；最后核对剩余外形。'})
        r.add('intersection_plane',kind,'points','标出同时在截平面和原表面上的点。',after='guides',action=drawing(['common_points']),focus=['common_points'])
        r.beat(f'intersection_plane:{kind}:answer')['action']['parts']['common_points']={'visibility':0.}
        if kind!='prism':r.drop('intersection_plane',kind,['check'],'answer')
    r.add('intersection_plane','prism','meaning','前面学过表面取点；截交线就是截平面与立体表面的公共点连成的边界。',after='context',focus=['retained','removed'])
    r.texts('intersection_solids','inner',{'context':'两个圆柱孔贯通后，孔壁在哪里相交？求这条相贯线。','surfaces':'这里参与相交的是两处孔壁，都是圆柱面，不是平面。','special':'先取轮廓处和对称位置的点，它们限定曲线的范围。','middle':'范围确定后，在中间补点，判断曲线怎样弯曲。','curve':'按孔壁上的相邻次序连接公共点，得到上下两处交线。','visible':'从正面看，孔内交线被外壁遮挡，画成虚线。'})
    r.add('intersection_solids','inner','one-point','先取竖孔圆周上的一个位置，它限定了一条竖直母线。',after='surfaces',action=drawing(['point_vertical']),focus=['point_vertical'])
    r.add('intersection_solids','inner','both-surfaces','再与横孔壁相交，这个点就同时属于两处孔壁。',after='one-point',action=drawing(['point_horizontal','common_point']),focus=['point_horizontal','common_point'])
    r.texts('intersection_solids','shell',{'context':'换成两根有壁厚的圆管：外表面相接，内孔也贯通。','surfaces':'外表面和内孔各有一条交线，必须分别求点。','special':'先分别确定外轮廓与孔壁上的特殊点。','middle':'补点方法相同；内外表面的点不能混连。','curve':'用两组公共点分别连出外表面交线和孔内交线。','inner_outer':'外表面交线说明接头外形，内表面交线说明孔怎样贯通。','visible':'可见的外表面交线用实线；被材料挡住的孔内交线用虚线。'})
    # The second example adds wall thickness, not another full point-selection lecture.
    r.drop('intersection_solids','shell',['special','middle'],'connect')
    r.drop('intersection_solids','shell',['inner_outer'],'surfaces')
    for kind in ['inner','shell']:
        r.beat(f'intersection_solids:{kind}:visible')['action'].setdefault('parts',{}).update({k:{'visibility':0.} for k in ['point_vertical','point_horizontal','common_point','guides','special','intermediate']})
    combination={
        'slope':{'context':'已知正面、水平投影，补侧面投影。先把这个组合体看成主体和切去的槽。','parts':'先认出主体、斜面和槽，再分别找它们在两个已知视图中的位置。','outer':'由正面取高度、水平投影取前后位置，补主体轮廓。','detail':'再补槽口和斜面的边界；每一条线都要对应实际表面。','visibility':'槽内被挡住的边界画虚线；外面看得见的边界画实线。','check':'相接处没有折角或外轮廓变化，就不另加一条线。'},
        'base':{'context':'这次的圆弧、孔和槽不便分块。仍补侧面投影，改为逐线、逐面追踪。','planes':'先认出同一圆弧面，再在另一个视图中找到它的范围。','outer':'把圆弧轮廓的高度和前后位置配对，补侧面外轮廓。','detail':'再追踪孔壁和槽面，补出它们在侧面的边界。'},
        'bracket':{'context':'现在已知正面、侧面投影，补水平投影。还是先外形、后孔槽。','known':'正面给左右位置，侧面给前后位置，两者共同定位俯视轮廓。','outer':'先补底座和立板的俯视轮廓。','detail':'再补底座孔与立板孔；从上面被挡住的孔边画虚线。'},
        'missing':{'context':'三个视图都在，但有缺线。怎样从其他视图找出漏掉的结构？','missing':'先看台阶孔和上下槽口，逐个核对它们在其他视图中的边界。','outer':'俯视图已有两个孔圆，还需补槽边及隐藏的轮廓。','detail':'左视图已有外形，还需补孔壁和孔径变化处的台阶。'}}
    for g,texts in combination.items():
        r.texts('combination',g,texts)
        if g!='slope':r.drop('combination',g,['visibility','check'],'detail')
        scene=scenes['combination_'+g];target='top' if g=='bracket' else 'left'
        if g!='missing':
            keys=[k for k in scene['entities'] if k.startswith(target+'_')]
            outer=[k for k in keys if '_body_' in k or (g=='base' and '_round_' in k)]
            detail=[k for k in keys if k not in outer]
            r.show(f'combination:{g}:outer',outer);r.show(f'combination:{g}:detail',detail)
            first={'slope':('parts',['feature_slope','feature_slot']),'base':('planes',['feature_round']),'bracket':('known',['feature_base_hole','feature_upright_hole'])}[g]
            b=r.beat(f'combination:{g}:{first[0]}');b['action']=drawing([k for k in first[1] if k in scene['entities']]);b['focus']=first[1]
    r.texts('section','full',{'context':'外形投影能说明形状，但内部孔槽常被虚线遮住。怎样把内部画清楚？','cut':'让假想剖切平面穿过两个孔的轴线，剖开内部。','remove':'从正面看，移去挡在剖切平面前面的部分。','imagined':'这是假想剖开，其他视图仍按完整零件表达。','outline':'把剩下部分向正面投影，剖切面后可见的轮廓也要画。','hatch':'切到材料的区域画剖面线；孔是空的，留白。','rib':'这块薄板是肋板。沿它的长度方向剖切，不画剖面线。'})
    r.texts('section','half',{'context':'这个零件内外形状对称。怎样在一张图中同时看见两者？','cut':'只移去面向观察者的四分之一，让另一半外形留下。','outline':'以对称中心线分界，一半画外形，一半画剖视，称为半剖。'})
    r.text('section:half:context','这个零件的侧面投影对称，怎样在侧视图中同时表达内外形状？')
    r.beat('section:half:cut')['action']={'keyframes':[{'at':.01,'parts':{'body':{'visibility':0.},'half_cut':{'visibility':1.},'half_removed':{'visibility':1.}}},{'at':.8,'parts':{'half_removed':{'move':[-30,-28,0]}}}],'parts':{'body':{'visibility':0.},'half_cut':{'visibility':1.},'half_removed':{'visibility':0.,'move':[-30,-28,0]}},'duration':2.3}
    r.beat('section:half:cut')['focus']=['half_cut','half_removed']
    r.show('section:half:outline',['half_outline','half_hatching','centre_line'],['body_left'])
    for beat in r.group('section','half')['beats']:
        beat['camera']={'yaw':-.65,'pitch':.42}
    r.texts('section','local',{'context':'只想说明这一处孔槽，外形还要保留，采用局部剖。','region':'仅在需要说明内部的区域假想剖开。','boundary':'波浪线区分剖开和未剖开的区域，它不是零件上的棱。'})
    r.texts('section','stepped',{'context':'几个孔错开了，一个平面切不到全部孔，怎样一起表达？','path':'用几个互相平行的剖切平面分别经过各孔轴线，路径连成阶梯。','cut':'按各段路径移去前面的材料，留下需要表达的孔。','outline':'沿同一方向投影，得到阶梯剖；路径转折不是实体边界，不画分界线。'})
    r.texts('section','rotated',{'context':'两个孔在倾斜相接的部分上，用相交的剖切平面分别经过它们。','path':'剖切路径相交，不是阶梯剖的平行错开。','cut':'剖开两个部分，保留孔和被切材料。','unfold':'绕两剖切平面的交线转正倾斜部分，使两部分能在一面表达。','outline':'按转正后的位置画旋转剖视图。'})
    r.texts('section','combined',{'context':'这个零件一侧倾斜、一侧孔位错开，需要组合两种剖切方法。','path':'倾斜处用旋转剖切，错开的孔用阶梯剖切。','cut':'先按各自路径剖开，辨认肋板和孔。','unfold':'只转正倾斜的部分，平行错开的部分保持方向。','outline':'合成剖视轮廓；肋板纵向剖切仍留白，不能当成孔。','no_distortion':'检查孔位、台阶和肋板，不能把整个零件一起拉伸。'})
    r.texts('section','missing',{'context':'给出的剖视图漏了线。除切到的截面，还应补哪些轮廓？','outside':'先补仍然可见的顶边和底座上边。'})
    r.texts('removed_section','key',{'context':'剖视还画后方轮廓；若只想说明轴在此处的形状，改画断面。','plane':'在键槽中部横切这根轴，并按箭头方向观察。','range':'只把切到的截面移到图外，称为移出断面。','outline':'横切得到圆形外边界；键槽与外部连通，槽口留开。'})
    r.texts('removed_section','hole',{'context':'换到带孔槽的位置：仍画断面，重点辨认孔槽与实体。','plane':'按指定位置切过孔槽，并确认观察方向。','outline':'先画轴的外圆，再画孔槽切出的边界。','through':'若剖切平面经过回转孔槽轴线，孔槽按剖视画法表达。'})
    r.drop('removed_section','hole',['range'],'through')
    r.texts('removed_section','compare',{'context':'这根轴有两侧槽和钻孔。比较断面，哪些线把结构画错了？','shape':'两侧槽通向外部；图中的封口线会把槽误画成孔。','drill':'剖切经过钻孔轴线，按剖视画法补出孔后可见圆弧。'})
    r.drop('removed_section','compare',['correct'],'drill')
    for g in ['key','hole','compare']:
        b=r.beat(f'removed_section:{g}:context')
        if 'body_left' in b['action']['parts']:b['action']['parts']['body_left']['visibility']=0.
    r.intro_group('dimensions','meaning','大小、位置与基准','dimension_method','前面解决形状怎样表达；尺寸还要说明结构有多大、放在哪里。')
    r.add('dimensions','meaning','size','这个直径决定孔有多大，属于定形尺寸。',action=drawing(['size']),focus=['size'])
    r.add('dimensions','meaning','datum','要说孔有多高，先选起点：这里从底面量起，底面就是基准。',action=drawing(['base','position'],['size']),focus=['base','position'])
    r.add('dimensions','meaning','overall','整体有多高由总体尺寸给出，不能与孔的位置尺寸混淆。',action=drawing(['overall'],['position']),focus=['overall'])
    r.texts('dimensions','block',{'context':'回到完整零件图：沿长、宽、高三个方向，分别找尺寸从哪里量起。','length':'左右位置从对称中心向两侧确定，主要基准是左右对称面。','height':'竖直尺寸从底面量起，高度主要基准是底面。','width':'前后位置相对对称中心确定，宽度主要基准是前后对称面。'})
    r.texts('dimensions','datum',{'context':'换成回转零件：怎样找到它的三个方向基准？','reason':'沿尺寸线找共同起点，不能只凭外形猜基准。','height':'高度从底面量；两个径向方向都从回转轴线确定位置。'})
    r.texts('dimensions','location',{'context':'看同一釜盖的俯视图，区分孔槽的大小和分布位置。','shape':'孔径、槽宽是定形尺寸，只决定大小。','position':'分布圆直径确定孔离中心多远，均布要求确定各孔的位置。','axes':'定位从轴线量起，所以轴线是径向基准。'})
    for id,box in [('dimensions:block:length',[35,15,550,450]),('dimensions:block:height',[40,170,540,300]),('dimensions:block:width',[620,45,320,410]),('dimensions:datum:height',[65,0,640,195])]:
        b=r.beat(id);factor=120/scenes[b['scene']]['provenance']['output_size'][0];b['action']['view_box']=[p*factor for p in box]
    r.intro_group('threads','meaning','先看牙形','thread_principle','有些零件靠螺纹连接。先看放大的轴向牙形，再学图纸的简化画法。')
    r.add('threads','meaning','crest','牙最凸出的部分叫牙顶，凹下去的部分叫牙底。',action=drawing(['crest','root','crest_name','root_name']),focus=['crest','root'])
    r.add('threads','meaning','pitch','沿轴向，相邻两牙对应点的距离叫螺距。',action=drawing(['pitch']),focus=['pitch'])
    r.texts('threads','external',{'context':'螺纹做在杆的外表面，叫外螺纹；它的大径经过牙顶，小径经过牙底。','real':'牙沿杆表面连续绕成螺旋；工程图用几条规定图线代替逐牙描画。','major':'外螺纹牙顶的大径画粗实线，牙底的小径画细实线。'})
    r.texts('threads','internal',{'context':'螺纹做在孔内，叫内螺纹；牙向孔内凸出，因此牙顶对应小径。','real':'内螺纹仍用规定线型表达，粗实线沿牙顶。','major':'内螺纹小径画粗实线，大径画细实线；与外螺纹的粗细位置相反。','end':'从孔口看，小径是完整粗圆，大径是约四分之三细圆。'})
    r.drop('threads','internal',['real','termination'],'major')
    r.texts('threads','engaged',{'context':'外螺纹旋入内螺纹后，两者重合的连接段怎样画？','outer':'重合的旋合段只按外螺纹画法，避免叠出两套线。','female':'孔内尚未旋合的一段，继续按内螺纹画法。'})
    r.drop('threads','engaged',['check'],'outer')
    r.texts('threads','bolt',{'context':'这两块零件都有通孔。用螺栓穿过它们，再用螺母夹紧。','parts':'杆与头是一件螺栓；另一侧依次放垫圈和螺母。','hole':'两块零件的孔都留间隙，螺纹与螺母旋合，不与板孔旋合。'})
    r.texts('threads','stud',{'context':'下面零件改成螺纹孔，不能穿入螺栓头，改用双头螺柱。','parts':'螺柱没有头，两端有螺纹：一端旋入基体，另一端装螺母。','hole':'下端与螺纹孔旋合；上方通孔留间隙，供螺柱穿过。','shank':'先确定旋入端、伸出端，再按旋合规则画图。'})
    r.drop('threads','stud',['hatch','rule'],'nut')
    r.beat('threads:stud:nut')['action']['parts'].update({k:{'visibility':1.,'draw':1.} for k in ['lower_hatch','upper_hatch','top']})
    r.texts('threads','mark_coarse',{'context':'规定图线不逐牙画，直径和牙型要从标记读出。先看 M8—7H。','token2':'7H 是内螺纹的公差带代号；粗牙螺距省略。公差带的作用后面再讲。'})
    r.texts('threads','mark_fine',{'context':'再看 M12×1.5—6g：多出的 1.5 是什么？','token1':'1.5 mm 是螺距；这里用细牙，所以需要标出。'})
    r.texts('threads','mark_pipe',{'context':'孔旁标的是 G1/2，不是 M；这里改用管螺纹标记。','token0':'G 是非螺纹密封管螺纹：连接的密封不靠螺纹本身保证。'})
    r.texts('gears','single',{'context':'齿轮靠轮齿啮合传递转动。已知模数 3、齿数 20，怎样简化画它？','meaning':'齿数 z 是一周的齿数；模数 m 规定齿的大小，用来计算主要圆。','pitch0':'分度圆是计算尺寸的基准圆，直径 d＝mz＝3×20＝60 mm。','addendum0':'齿顶圆经过齿的最外端：dₐ＝m(z＋2)＝66 mm。','root0':'齿根圆经过齿槽底部：df＝m(z－2.5)＝52.5 mm。','convention':'不逐齿画投影：齿顶粗实线、分度圆细点画线、齿根细实线。'})
    r.add('gears','single','scope','这里采用标准直齿圆柱齿轮的尺寸关系。先认三个圆，再代入参数。',after='meaning',focus=['gear0'])
    for suffix,world in [('pitch0','reference0'),('addendum0','tooth_tips0'),('root0','tooth_roots0')]:
        b=r.beat('gears:single:'+suffix);b['action']['parts'][world]={'visibility':1.};b['focus']+=[world]
        for other in ['reference0','tooth_tips0','tooth_roots0']:
            if other!=world:b['action']['parts'][other]={'visibility':0.}
    r.texts('gears','pair',{'context':'现在让两个齿轮啮合。已知共同模数 4、齿数 20 和 35，怎样确定轴距？','meaning':'两轮沿用刚才的尺寸关系；新增的问题是两条轴线相距多少。','pitch0':'分度圆：d₁＝4×20＝80 mm，d₂＝4×35＝140 mm。','addendum0':'齿顶圆：dₐ₁＝4×22＝88 mm，dₐ₂＝4×37＝148 mm。','root0':'齿根圆：df₁＝4×17.5＝70 mm，df₂＝4×32.5＝130 mm。','centres':'两分度圆相切，中心距等于两半径之和：a＝(80＋140)/2＝110 mm。','mesh':'两轮啮合处轮齿交错，按规定区分可见与被遮挡的边界。'})
    for name in ['pitch','addendum','root']:
        b=r.beat('gears:pair:'+name+'0');other=r.beat('gears:pair:'+name+'1')
        b['action']['parts'].update(copy.deepcopy(other['action']['parts']));b['action']['keyframes'][0]['parts'].update(copy.deepcopy(other['action']['keyframes'][0]['parts']))
        # Hide only labels from the preceding calculation, not the new pair.
        for label in ['label_d0','label_d1','label_da0','label_da1','label_df0','label_df1']:
            b['action']['parts'][label]={'visibility':float(label in {'pitch':['label_d0','label_d1'],'addendum':['label_da0','label_da1'],'root':['label_df0','label_df1']}[name])}
        b['focus']+=other['focus'];r.drop('gears','pair',[name+'1'],name+'0')
    # Do not re-teach the two drawing conventions already established on one wheel.
    for name in ['convention','section']:
        r.beat('gears:pair:mesh')['action']['parts'].update(r.beat('gears:pair:'+name)['action']['parts'])
    r.drop('gears','pair',['convention','section'],'mesh')
    r.beat('gears:pair:centres')['action']['parts']['label_df0']={'visibility':0.}
    r.beat('gears:pair:mesh')['action']['parts']['label_df0']={'visibility':0.}
    r.texts('bearings','structure',{'context':'轴需要转动，座孔要支承它。轴承放在两者之间，看看各部分怎样配合。','rings':'内圈套在轴上，外圈装进座孔；先分开看两只圈。','balls':'内外圈之间放滚动体，使相对运动通过滚动接触实现。','cage':'保持架把滚动体分隔开，装回后组成完整轴承。','code':'这只轴承用旧式代号 304；先读内径，再查其外形尺寸。','diameter':'末两位 04 对应内径 20 mm；3 表示这里的尺寸系列。','size':'外径 52 mm 决定座孔尺寸，宽 15 mm 决定轴向安装空间。'})
    r.text('bearings:structure:rings','分解示意这两只圈：内圈套在轴上，外圈装进座孔。')
    r.text('bearings:structure:cage','保持架把滚动体分隔开；合起来看各部分的相对位置。')
    r.beat('bearings:structure:rings')['action']={'parts':{'inner':{'move':[-22,0,0]},'outer':{'move':[16,0,0]},**{k:{'visibility':0.} for k in ['cage']+['ball'+str(i) for i in range(8)]}},'duration':1.7}
    r.show('bearings:structure:balls',['ball'+str(i) for i in range(8)])
    r.beat('bearings:structure:cage')['action']={'parts':{'inner':{'move':[0,0,0]},'outer':{'move':[0,0,0]},'cage':{'visibility':1.}},'duration':1.7}
    r.show('bearings:structure:code',['code','dimension_outline','dimension_bore'])
    r.beat('bearings:structure:diameter')['action']['parts']['diameter_witness']={'visibility':1.}
    r.beat('bearings:structure:size')['action']['parts'].update({'size_witness':{'visibility':1.},'code':{'visibility':0.}})
    r.texts('bearings','assembly',{'context':'已经认出内外圈。现在把轴承放到轴和座孔之间，确定安装接触面。','shaft':'轴从内圈孔中穿入，轴肩限制内圈的轴向位置。','housing':'外圈落在座孔中；轴和孔分别接触内圈、外圈。','convention':'装配图用简化符号表达轴承占据的空间，不逐个画滚动体。'})
    # Show real axial assembly, rather than just fading an assembled shaft in place.
    for name,offset in [('shaft',-30),('housing',26)]:
        b=r.beat('bearings:assembly:'+name);b['action']['keyframes']=[{'at':.01,'parts':{name:{'visibility':1.,'move':[offset,0,0]}}}];b['action']['parts'][name]={'visibility':1.,'move':[0,0,0]};b['action']['duration']=2.1
    r.texts('requirements','hole',{'context':'尺寸给出理想大小，制造总会有误差。图纸怎样限定允许的大小范围？','size':'⌀40 是基本尺寸；实际孔径允许在规定的上下限之间变化。','deviation':'用基本尺寸作零线。H 决定允许范围从零线开始，位于零线上方。','grade':'7 决定这段允许范围的宽度；H7 合起来才是公差带代号。','distinction':'测得尺寸必须落在允许范围内；示意图放大了偏差，不能据图读数值。'})
    r.show('requirements:hole:deviation',['nominal','zero_label','scale_note'],duration=1.3)
    r.text('requirements:hole:grade','在这个基本尺寸下，7 确定允许范围的宽度；H7 合起来才是公差带代号。')
    r.show('requirements:hole:grade',['zone','bounds','zone_label'],duration=1.3)
    r.show('requirements:hole:distinction',['measured'],duration=1.3)
    r.texts('requirements','shaft',{'context':'换看轴的 ⌀70d11：读法相同，但轴用小写字母。','deviation':'d 使公差带位于零线下方；允许的轴径比基本尺寸小。','distinction':'11 是公差等级。字母确定位置、等级确定宽度，仍要一起读取。'})
    r.drop('requirements','shaft',['size','grade'],'deviation')
    r.show('requirements:shaft:deviation',['nominal','zone','zero_label','zone_label','scale_note'])
    geometry={
        'perpendicular':('孔径合格，孔轴线仍可能歪斜。这个框格要求它垂直于基准 C。','先认基准面 C；它提供判断垂直方向的依据。','⌀0.05 指定直径 0.05 mm 的圆柱形允许区域，其轴线垂直于 C。','实际孔轴线可略有弯斜，但必须整条留在圆柱内。'),
        'plane':('现在控制的是整个表面的垂直度，不是孔的轴线。','A 指定基准面；被测表面的方向相对它确定。','0.03 前没有直径符号，这里的允许区域是相距 0.03 mm 的两个平行平面。','这两个界限平面垂直于 A；被测表面必须全部夹在它们之间。'),
        'parallel':('这个框格改为平行度：要求被测表面与基准 A 保持平行。','仍先找到 A，再判断哪个表面受到控制。','两个界限平面平行于 A，相距 0.01 mm。','实际表面的全部起伏，都必须容纳在这两个界限之间。')}
    for g,lines in geometry.items():
        r.texts('requirements',g,dict(zip(['context','datum','zone','actual'],lines)))
        r.beat(f'requirements:{g}:datum')['action']['parts']['datum_name']={'visibility':1.}
        r.beat(f'requirements:{g}:zone')['action']['parts']['zone_name']={'visibility':1.}
        r.text(f'requirements:{g}:units','若局部越过界限，即使大部分在里面，也不符合要求。')
        r.show(f'requirements:{g}:units',['outside','outside_name'],['actual'])
        if g!='perpendicular':r.drop('requirements',g,['units'],'actual')
    r.intro_group('roughness','meaning','表面的微小起伏','roughness_profile','公差限制尺寸、形状和方向；表面还存在更细小的凹凸，由粗糙度要求控制。')
    r.add('roughness','meaning','profile','图纸上的直线代表表面，放大后还能看见微小起伏。',action=drawing(['profile','profile_name']),focus=['profile'])
    r.add('roughness','meaning','compare','相同尺度下，起伏较小的表面更光滑；粗糙度参数用来限定这种差别。',action=drawing(['smoother','smoother_name']),focus=['smoother'])
    r.texts('roughness','symbol',{'context':'图纸不画这些微小凹凸，用符号、参数和数值标明要求。','basic':'符号的尖端指向被要求的表面；基本符号本身不限定加工方法。','value':'Ra 表示轮廓算术平均偏差，以微米计；这里的要求值是 6.3 μm。','compare':'比较同一个参数时，允许值越小，要求越严格。'})
    r.texts('roughness','surface',{'context':'回到零件图：Ⅰ、Ⅱ、Ⅲ处没有都写数值，怎样找各自的要求？','I':'先追踪Ⅰ所指表面；它没有单独标注，使用“其余”的不去除材料要求。','II':'Ⅱ的表面有单独标注 Ra 6.3，优先用这项要求。','III':'沿投影对应找到Ⅲ的同一表面，再读出另一视图中的 Ra 25。'})
    for name in ['I','II','III']:
        b=r.beat('roughness:surface:'+name);key='surface_'+name+'_note';b['action']['parts'][key]={'visibility':1.};b['focus']+=[key]
        b['action']['view_box']=[0,0,120,500*120/918]
    r.texts('roughness','errors',{'context':'已知粗糙度标注，检查它指向哪里，以及数字从哪个方向阅读。'})
    r.texts('roughness','quality',{'context':'同一张图中要求不同，怎样找要求最严格的表面？','value':'同为 Ra，6.3 小于“其余”的 12.5；Ra 6.3 对应的表面要求更严格。'})
    r.drop('roughness','quality',['answer'],'value')
    r.texts('part_drawing','overview',{'context':'现在把形状、尺寸和技术要求合起来读。先看这张图用了哪些视图与剖视。','views':'先找主视图：波浪线只剖开局部，用来说明内部。','side':'左视图一半外形、一半内部，是半剖。与主视图对照，还原左右结构。','top':'俯视图是 A—A 全剖，补充前后方向的孔槽关系。','cut':'要还原结构，先回到主视图，找到 A—A 切在什么高度。','cut_side':'再从俯视图确认：左视剖切经过左右对称面。','cut_front':'主视的局部剖经过前后对称面；剖切位置决定能看见哪些内部结构。'})
    r.add('part_drawing','overview','next','形状辨清后，再按“大小和位置 → 公差与表面要求”读；不要先逐个背数字。',focus=[])
    r.texts('part_drawing','restore',{'context':'接着练习反向理解：图上画的是剖视，完整零件的主视外形是什么？','whole':'把假想移去的材料放回去，孔槽仍然存在。'})
    r.texts('part_drawing','details',{'context':'换看轴类零件，先把局部放大图对应回轴上的同一位置。','detail':'局部放大 2∶1 是为看清细节；尺寸数字仍表示实际大小。','chamfer':'两端 C2、C1.5 表示 45°倒角，直角边尺寸分别为 2、1.5 mm。','groove':'这处 2×2 是退刀槽，给刀具退出留空间，不能当成轴断开了。','section':'这处标出的横切位置有键槽，后面用已学的断面方法表达。'})
    r.texts('part_drawing','lid',{'context':'最后换一张釜盖图，按同一顺序读：先表达方法，再结构、尺寸和技术要求。','front':'主视全剖给出厚度和内部台阶；俯视图给出孔槽的圆周分布。','holes':'先在俯视图数孔、找分布位置，再回主视图辨认孔的深度。','slots':'俯视图辨认开口槽，主视图核对槽上方的锪平结构。'})
    r.texts('part_drawing','note',{'context':'仍看这只釜盖，把孔槽旁的数量、深度和直径分别对应回结构。','thread':'6 个 M12 螺孔均布。螺纹深 10 mm，钻孔深 18 mm，孔底比螺纹更深。','slots':'6 处开口槽宽 23 mm；上方锪平直径 44 mm，提供平整支承面。'})
    r.texts('part_drawing','material',{'context':'形状与技术要求读完，最后查标题栏：釜盖材料标为 Q235-A。','Q':'Q 表示以屈服强度命名，说明这是按强度等级选用的结构钢。','grade':'A 是质量等级；不能把材料牌号当作尺寸或表面要求。'})
    r.texts('part_drawing','shaft_section',{'context':'回到带键槽的轴，用已学方法完成 A—A 断面，检验是否读懂结构。','slot':'按由右向左的方向，键槽开口在左侧；槽宽 5 mm、深 2.9 mm。'})
    normalize(r)

def normalize(r):
    """Context changes and attention-only changes never consume a vacant D press."""
    for c in r.courses.values():
        lesson=c['concept'];records=[]
        for group in lesson['groups']:
            entities=r.scenes[group['scene']]['entities']
            for i,b in enumerate(group['beats']):
                action=b.get('action',{})
                if i==0 and action.get('scene'):
                    target=copy.deepcopy(action);target.pop('duration',None);target.pop('keyframes',None)
                    setup=copy.deepcopy(target)
                    # Hide the old answer at once; fade only this example's known objects.
                    for part in setup['parts'].values():part['visibility']=0.
                    b['setup']=setup;b['prepare_with_text']=True;action['duration']=.65
                else:
                    ids=set(action.get('parts',{}))
                    for frame in action.get('keyframes',[]):ids.update(frame.get('parts',{}))
                    only_attention=bool(ids) and all(entities.get(k,{}).get('role')=='attention' or (not entities.get(k,{}).get('world') and not entities.get(k,{}).get('triangles') and (entities.get(k,{}).get('labels') or k.endswith('_region') or (entities.get(k,{}).get('color')=='d68d48'))) for k in ids)
                    # Reading figures' ROI boxes are evidence pointers, not construction.
                    if entities.get('figure',{}).get('image'):
                        only_attention=not any(k.startswith('correct_') or k in ['top_edge','base_edge','bore_step','back_top','back_inner'] for k in ids)
                    if only_attention:b['prepare_with_text']=True;action['duration']=.65
                if entities.get('figure',{}).get('image') and i>0:
                    wanted={k for k,p in action.get('parts',{}).items() if p.get('visibility',0)>0}|set(b.get('focus',[]))
                    # Reading emphasis must not accumulate on unrelated old regions.
                    for key,e in entities.items():
                        if e.get('role')=='attention':action.setdefault('parts',{})[key]={'visibility':float(key in wanted),'draw':1.}
                    # Clearing old emphasis must not auto-play actual new ink.
                    # The earlier attention-only branch already sets concurrent
                    # preparation for reading, while corrections still wait for D.
                    b['action']=action
                b['teaching']={
                    'learner_question':b['text'] if '？' in b['text'] else f'在{group["title"]}中，这一步所指的对象和依据是什么？',
                    'visual_evidence':list(dict.fromkeys([*b.get('focus',[]),*action.get('parts',{})])),
                    'evidence_scene':b['scene'],
                    'resolved_uncertainty':b['text'],
                    'playback_reason':'已知情境或阅读定位与文字同步，不占独立动作' if b.get('prepare_with_text') else ('构造或空间变化后停留观察' if action else '解释当前证据，下一次输入直接换段')}
                records.append(b['id'])
        c['beginner_review']={'date':'2026-10-25','scope':'concept only; original question solutions kept independent','beats':records}
