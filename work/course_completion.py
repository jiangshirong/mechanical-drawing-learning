"""Source-specific tasks which cannot be represented by a generic chapter example."""
from course_geometry import *
from course_solids import hatches
from course_reading import figure_scene
from PIL import Image
import copy


def shaft_section():
    s=Scene('shaft_section',['t06-q08'],views=('front','left'))
    r=8.5;width=5;depth=2.9
    body=cylinder(r,40,'x')-Manifold.cube([16,depth+1,width]).translate([12,-r-1,-width/2])
    add_body(s,'shaft',body)
    cut=CrossSection([circle(r)[:-1]])-CrossSection([rect(-r-2,-width/2,depth+2,width)[:-1]])
    s.ink('outer','left',[circle(r)],visible=False)
    s.ink('notch','left',[p.tolist()+[p[0].tolist()] for p in cut.to_polygons()],visible=False)
    s.ink('hatching','left',hatches(cut.to_polygons(),1.5),'thin',visible=False)
    s.entity('width',brace={'view':'left','a':[r+4,-width/2],'b':[r+4,width/2],'label':'5 mm'},visible=False)
    s.entity('depth',brace={'view':'left','a':[-r,-7],'b':[-r+depth,-7],'label':'2.9 mm'},visible=False)
    s.entity('cutting_plane',mesh=tri_quad([20,-13,-13],[20,13,-13],[20,13,13],[20,-13,13]),opacity=.2,visible=False)
    s.data['entities']['shaft_left']['initial']=0
    s.data['parameters']={'shaft_diameter':17,'keyway_width':5,'keyway_depth':2.9,'keyway_length':16,'section_x':20,'view_direction':[-1,0,0]}
    s.data['view_titles']={'front':'轴上的剖切位置','left':'A—A'}
    s.data['constraints']=['截面来自直径17的圆柱与宽5、深2.9的键槽','由右向左观察，朝正面开口的键槽在断面左侧']
    return s


def restore_scene():
    s=Scene('read_restore',['t01-q09'],views=('front','top','left'))
    # Given dimensions: overall housing length90, axis height50, main OD48,
    # bore36, tailOD35, flangeOD60, base55x96x10, ear centres68.
    base=Manifold.cube([55,96,10]).translate([0,-48,0])
    housing=cylinder(24,76,'x',(0,0,50))+cylinder(17.5,14,'x',(76,0,50))
    flange=cylinder(30,15,'x',(2,0,50))
    flange+=cylinder(12,15,'x',(2,-34,50))+cylinder(12,15,'x',(2,34,50))
    flange+=Manifold.cube([15,68,25]).translate([2,-34,37.5])
    support=Manifold.cube([10,40,40]).translate([12,-20,10])
    rib=CrossSection([[[22,10],[55,10],[76,26],[22,26]]]).extrude(8).rotate([90,0,0]).translate([0,4,0])
    body=base+housing+flange+support+rib
    body-=cylinder(18,68,'x',(0,0,50))+cylinder(21,12,'x',(0,0,50))+cylinder(10,25,'x',(68,0,50))
    for y in [-34,34]:
        body-=cylinder(5.5,12,centre=(39,y,-1))
        body-=cylinder(5,19,'x',(0,y,50))
    add_body(s,'body',body,project_views=False)
    cut=body.split_by_plane([0,1,0],0)[0]
    add_body(s,'cut',cut,project_views=False,visible=False)
    sec=body.rotate([90,0,0]).slice(0)
    s.ink('cut_outline','front',[p.tolist()+[p[0].tolist()] for p in sec.to_polygons()])
    s.ink('hatching','front',hatches(sec.to_polygons()),'thin')
    projection=model_projection(body)
    for view in ['front','top','left']:
        solid=[p for p in projection[view] if p['style']=='solid']
        hidden=[p for p in projection[view] if p['style']=='dashed']
        s.entity('outer_'+view,paths={view:solid},visible=view!='front')
        if view=='front':s.entity('holes',paths={view:hidden},visible=False)
    s.entity('axis',paths={'front':[path([[-6,-50],[98,-50]],'axis')]})
    s.data['parameters']={'housing_length':90,'axis_height':50,'outside_diameter':48,'bore_diameter':36,'tail_outside_diameter':35,'flange_diameter':60,'base':[55,96,10],'mount_centres':68}
    s.data['provenance']['note']='采用原图的已注总体尺寸与结构；未注圆角、铸造连接以教学尺度简化。外形由完整实体的投影生成，不把剖面边界当外轮廓。'
    return s


def missing_scene():
    # The original printed layer is preserved. Added strokes follow the three
    # missing boundaries cross-checked against the original DOC answer p9.
    crop=(320,65,760,460);scale=120/440
    s=figure_scene('section_missing','t03-q05-p14.png',crop,source=['t03-q05'])
    def line(id,pts):
        s.ink(id,'front',[[[(x-crop[0])*scale,(y-crop[1])*scale] for x,y in pts]],visible=False)
    line('top_edge',[[440,85],[464,85]])
    line('base_edge',[[400,206],[464,206]])
    line('bore_step',[[464,173],[484,173]])
    # Cylindrical tower behind the notch: horizontal top and vertical edge.
    line('back_top',[[721,85],[749,85],[749,144]])
    line('back_inner',[[721,85],[721,144]])
    s.data['provenance']['answer_basis']='原DOC第三套第9页，原题像素坐标下的对应端点；保留题给线，不由错线建立实体。'
    s.data['constraints']=['顶面按两视图等高对应','正面半剖中外形一侧仍保留底座可见上边','剖后保留的孔台阶与槽后轮廓不能省略']
    return s


def all_scenes():
    yield shaft_section();yield restore_scene();yield missing_scene()
    s=figure_scene('section_local','t01-q09-p06.png',None,-90,source=['t01-q09'])
    file=APP/'assets/course_sources/section_local.png';im=Image.open(file).crop((880,220,1290,605));im.save(file)
    s.data['entities']['figure']['rect']=[0,0,120,385*120/410]
    s.data['provenance']['post_rotation_crop']=[880,220,1290,605];s.data['provenance']['output_size']=[410,385]
    factor=120/410
    s.ink('local_region','front',[[[x*factor,y*factor] for x,y in [[40,245],[150,245],[150,310],[40,310],[40,245]]]],'thin',visible=False,role='attention')
    s.ink('break_boundary','front',[[[x*factor,y*factor] for x,y in [[145,250],[142,263],[147,276],[143,289],[145,302]]]],'thin',visible=False,role='attention')
    yield s
    from course_thread_details import fastener
    for name,src,file,crop,stud in [('fastener_stud_task','t02-q06','t02-q06-p10.png',(320,75,560,750),True),('fastener_bolt_error','t08-q10','t08-q10-p42.png',(75,55,410,550),False)]:
        s=fastener(stud);s.data['id']=name;s.data['source_questions']=[src]
        known=figure_scene(name+'_known',file,crop,source=[src])
        image=known.data['entities']['figure']['image'];h=known.data['entities']['figure']['rect'][3]
        for e in s.data['entities'].values():e.get('paths',{}).pop('left',None)
        for key in list(s.data['entities']):
            if not any(s.data['entities'][key].get(field) for field in ['paths','world','triangles','model','labels','brace']):del s.data['entities'][key]
        s.entity('given_wrong',image=image,view='left',rect=[-20,-58,40,40*h/120])
        s.data['views']=['front','top','left']
        s.data['view_layout']={'front':[0,0,.55,.62],'top':[0,.62,.55,.38],'left':[.55,0,.45,1]}
        s.data['independent_views']=['left']
        s.data['view_titles']={'front':'改正后的画法','left':'给定画法','top':'端面投影'}
        s.data['provenance']['wrong_known_layer']=known.data['provenance'];s.data['provenance']['note']='给定错图是不可修改的独立图片；改正图线由连接规则与共享尺寸生成。'
        yield s


def augment(api):
    A=api['Author'];courses=api['COURSES'];scenes=api['SCENES'];scene_state=api['scene_state']
    # Exact four choices, not a duplicated explanation of thread definitions.
    a=A('threads')
    for i in range(1,5):
        sc='thread_judge_'+str(i);answer=scenes[sc]['verified_answer']
        a.group('judge'+str(i),'画法'+str(i),sc,'判断这幅螺纹画法是否正确。',True)
        a.beat('compare',answer['reason']+'。',show=[k for k in scenes[sc]['entities'] if k.startswith('correct_')])
        a.beat('result','这种画法正确。' if answer['correct'] else '这种画法有误，按右侧的规定画法改正。')
    a.task('thread-judge','判断螺纹画法','t05-q06')
    c=courses['threads'];c['tasks']=[t for t in c['tasks'] if t['id']!='thread-judge']+a.tasks
    c['scenes'].update({s:f'assets/course_scenes/{s}.json' for s in sorted(a.used)})
    for task_id,scene in [('stud-connect','fastener_stud_task'),('bolt-correct','fastener_bolt_error')]:
        task=next(t for t in c['tasks'] if t['id']==task_id);task['lesson']['initial']=scene_state(scene)
        for g in task['lesson']['groups']:
            g['scene']=scene
            for b in g['beats']:
                b['scene']=scene
                if b['action'].get('scene'):b['action']=scene_state(scene)
        c['scenes'][scene]=f'assets/course_scenes/{scene}.json'
    # Add the independent missing-section-line method to both explanations and questions.
    a=A('section');a.group('missing','剖视补线','section_missing','根据已知视图，补出剖后仍应保留的图线。',True)
    a.beat('outside','先补外形一侧的顶边与底座上边。',show=['top_edge','base_edge'])
    a.beat('bore','孔径发生变化的台阶，也有可见边界。',show='bore_step')
    a.beat('behind','再补槽后仍然存在的轮廓，不能只画切到的截面。',show=['back_top','back_inner'])
    a.task('section-missing','补剖视图缺线','t03-q05')
    c=courses['section'];c['concept']['groups']+=a.groups;c['tasks']+=a.tasks;c['scenes'].update({s:f'assets/course_scenes/{s}.json' for s in sorted(a.used)})
    # Three exact datums in the bearing-block question.
    a=A('dimensions');a.group('block','读出三个尺寸基准','read_bearing_block','沿三个方向的尺寸线，寻找主要尺寸基准。',True)
    a.beat('length','长度方向以左右对称面为主要基准。',show='axis_front')
    a.beat('height','高度方向以底面为主要基准。',show='base',hide='axis_front')
    a.beat('width','宽度方向以前后对称面为主要基准。',show='axis_side',hide='base')
    a.task('dimensions-block','识别主要尺寸基准','t02-q08')
    c=courses['dimensions'];c['concept']['groups']=a.groups+c['concept']['groups'];c['concept']['initial']=a.initial;c['tasks']+=a.tasks;c['scenes']['read_bearing_block']='assets/course_scenes/read_bearing_block.json'
    # Restore the correct question's exterior, and actually draw the shaft section.
    a=A('part_drawing');a.group('restore','从剖视恢复外形','read_restore','已知剖视图，怎样恢复主视图的外形？',True,{'body':0,'cut':1})
    a.beat('whole','先将假想移去的部分恢复，辨认完整零件。',show='body',hide='cut')
    a.beat('outer','沿完整零件的可见边界画外形。',show='outer_front',hide=['cut_outline','hatching'])
    a.beat('hidden','外形图中的孔仍在内部，用必要的虚线表达。',show='holes')
    a.task('read-outline','从剖视恢复外形','t01-q09')
    c=courses['part_drawing'];c['concept']['groups'][1:1]=a.groups;c['tasks']=[t for t in c['tasks'] if t['id']!='read-outline']+a.tasks;c['scenes']['read_restore']='assets/course_scenes/read_restore.json'
    c['concept'].setdefault('resume_aliases',{})['part_drawing:overview:restore']='part_drawing:restore:context'
    a=A('part_drawing');a.group('shaft_section','齿轮轴断面','shaft_section','在指定位置，画出带键槽的 A—A 断面。',True)
    a.beat('location','剖切位置在直径17 mm的轴段，观察方向由右向左。',show='cutting_plane')
    a.beat('circle','先画直径17 mm的圆。',show='outer')
    a.beat('slot','键槽宽5 mm、深2.9 mm，按观察方向画出槽口。',show=['notch','width','depth'],hide='outer')
    a.beat('material','实体材料画剖面线，槽内留空。',show='hatching',hide=['cutting_plane','width','depth'])
    c['concept']['groups']+=a.groups;c['scenes']['shaft_section']='assets/course_scenes/shaft_section.json'
    t=next(t for t in c['tasks'] if t['id']=='read-shaft');extra=__import__('copy').deepcopy(a.groups)
    for g in extra:
        for b in g['beats']:b['id']='read-shaft:'+b['id']
    t['lesson']['groups']+=extra
    # The question explicitly asks for the best requirement on this drawing.
    a=A('roughness');a.group('quality','比较同图中的要求','read_lid','找出图中表面质量要求最高的粗糙度。',True)
    a.beat('value','先比较同一参数的数值，Ra 6.3 小于其余表面的 Ra 12.5。',show='quality').zoom([65,0,700,195])
    a.beat('answer','所以要求最高的是 Ra 6.3；符号仍指向对应表面。',focus='quality')
    a.task('roughness-quality','比较表面质量要求','t08-q11')
    c=courses['roughness'];c['tasks']=[t for t in c['tasks'] if t['id']!='roughness-quality']+a.tasks;c['concept']['groups']+=a.groups;c['scenes']['read_lid']='assets/course_scenes/read_lid.json'
    # Rebuild observation endpoints after additions, preserving author IDs.
    task_questions={
        'cut-prism':'已知棱柱的切割位置，补出截切后的缺少投影。',
        'cut-cylinder':'已知圆柱的槽口与切割位置，补出缺少投影。',
        'cut-cone':'已知圆锥组合体的切割位置，求截交线并补全投影。',
        'cut-sphere':'已知球面的开槽位置，补出槽口和球面的交线。',
        'intersection-inner':'两个圆柱孔相交，怎样补出孔内的相贯线？',
        'intersection-shell':'带孔圆管与半圆柱壳相接，补出内、外表面的相贯线。',
        'combination-slope':'已知两个视图，怎样分解形体并补出第三视图？',
        'combination-base':'已知两个视图，怎样分析各线、面并补出第三视图？',
        'combination-bracket':'已知主视图和左视图，补出俯视图。',
        'combination-missing':'各视图有缺漏线，按孔槽和相接关系补齐。',
        'section-full':'内部有孔和肋板，怎样画出规定的全剖视图？',
        'section-half':'已知对称零件的视图，画出要求的全剖与半剖视图。',
        'section-local':'图中局部剖开了哪里？辨认内部结构与保留的外形。',
        'section-stepped':'几个孔不在同一剖切平面内，怎样用阶梯剖同时表达？',
        'section-rotated':'孔所在的部分彼此倾斜，怎样按规定画旋转剖视图？',
        'section-combined':'按已知剖切路径，表达不同位置的孔与肋板。',
        'section-missing':'根据已知视图，补出剖视图中缺少的轮廓。',
        'removed-key':'在指定位置画出带键槽的移出断面。',
        'removed-hole':'在指定位置画出带相交孔槽的移出断面。',
        'removed-compare':'已知槽口和钻孔结构，判断哪种移出断面正确。',
        'dimensions-lid':'从图中的尺寸线，找出主要基准与定位尺寸。',
        'dimensions-block':'沿长、宽、高三个方向，找出主要尺寸基准。',
        'thread-engaged':'图示内外螺纹已旋合，改正其规定画法。',
        'bolt-connect':'已知被连接件的位置，补齐螺栓、螺母和垫圈。',
        'stud-connect':'检查双头螺柱连接图，改正旋入端和紧固端的画法。',
        'bolt-correct':'检查螺栓连接图，改正孔、紧固件和剖面线的画法。',
        'thread-judge':'判断各幅螺纹图是否正确，并指出依据。',
        'thread-mark-coarse':'图中 M8—7H 各部分分别表示什么？',
        'thread-mark-fine':'图中 M12×1.5—6g 各部分分别表示什么？',
        'thread-mark-pipe':'图中 G1/2 表示什么？它指向内螺纹还是外螺纹？',
        'gear-single':'已知模数3、齿数20，计算主要圆的直径并画齿轮。',
        'gear-pair':'已知模数4、齿数20与35，计算中心距并按1∶2画啮合图。',
        'bearing-assembly':'解释304轴承的代号和尺寸，再辨认它与轴、孔的装配关系。',
        'tolerance-hole':'已知孔的尺寸公差标记，解释基本尺寸与公差带。',
        'tolerance-shaft':'已知轴的尺寸公差标记，解释基本尺寸与公差带。',
        'tolerance-perpendicular':'读出垂直度框格：控制哪个轴线，以什么为基准？',
        'tolerance-plane':'读出垂直度框格：控制哪个表面，允许怎样的偏差？',
        'tolerance-parallel':'读出平行度框格，说明被测表面与基准的关系。',
        'roughness-surfaces':'追踪图中的Ⅰ、Ⅱ、Ⅲ表面，分别读出粗糙度要求。',
        'roughness-errors':'检查图中的粗糙度标注，找出并改正错误。',
        'roughness-quality':'比较图中的粗糙度，找出表面质量要求最高的一处。',
        'read-block':'辨认各视图的表达方法，并找出剖切位置。',
        'read-shaft':'读出轴上的工艺结构，再画指定位置的键槽断面。',
        'read-lid':'从表达方法、尺寸和技术要求入手，读懂这张零件图。',
        'read-outline':'已知零件的剖视图，恢复主视图的完整外形。',
    }
    for c in courses.values():
        if c['id']=='threads':
            for lesson in [c['concept']]+[t['lesson'] for t in c['tasks']]:
                for g in lesson['groups']:
                    if g['scene'].startswith('fastener_'):
                        for b in g['beats']:
                            if b['id'].split(':')[-1] not in ['context','parts','hole']:b['display_layout']='paper'
        obs=[]
        for g in c['concept']['groups']:
            state=scene_state(g['scene'])
            for beat in g['beats']:
                act=beat.get('action',{})
                if 'scene' in act:state=__import__('copy').deepcopy(act)
                if 'view_box' in act:state['view_box']=act['view_box']
                for k,v in act.get('parts',{}).items():state['parts'].setdefault(k,{}).update(v)
            state.pop('duration',None);state.pop('keyframes',None)
            obs.append({'id':g['id'],'title':g['title'],'state':state})
        c['observations']=obs;c['observe']=obs[0]['state']
        for task in c['tasks']:
            groups=task['lesson']['groups']
            groups[0]['beats'][0]['text']=task_questions[task['id']]
            groups[0]['beats'][0]['teaching']['learner_question']=task_questions[task['id']]
            groups[0]['beats'][0]['teaching']['resolved_uncertainty']='明确本任务的已知对象和求解目标；待求图形暂不显示。'
            if len(groups)==1 and len(groups[0]['beats'])>=5:
                g=groups[0];parts=[('prepare','已知与目标',g['beats'][:1]),('draw','作图过程',g['beats'][1:-1]),('check','检查结果',g['beats'][-1:])]
                task['lesson']['groups']=[dict(g,id=g['id']+'-'+key,title=title,beats=beats) for key,title,beats in parts]
