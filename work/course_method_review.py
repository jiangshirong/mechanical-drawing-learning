"""Author corrections for prerequisites, sufficient givens, and visible derivation."""
import copy,math
from course_geometry import Scene,project,add

def crosses(points,r=.7):
    return [[add(p,[-r,0,0]),add(p,[r,0,0])] for p in points]+[[add(p,[0,0,-r]),add(p,[0,0,r])] for p in points]

def enhance(scene):
    s=Scene(scene['id']);s.data=copy.deepcopy(scene);e=s.data['entities'];sid=scene['id']
    if sid in ['basic_cylinder','basic_cone','basic_sphere']:
        p=s.data['parameters']['surface_point'];given='front' if sid=='basic_sphere' else 'top'
        q=project(p,given)
        s.ink('given_projection',given,[[[q[0]-.6,q[1]],[q[0]+.6,q[1]]],[[q[0],q[1]-.6],[q[0],q[1]+.6]]],visible=False)
        e['given_projection']['labels']=[dict(text='p′' if given=='front' else 'p',at=[q[0]+1.5,q[1]-1.5],view=given)]
        if sid=='basic_cylinder':s.projected('point_generator',[[[p[0],p[1],0],[p[0],p[1],48]]],visible=False)
        if sid=='basic_sphere':s.projected('point_generator',[[[p[0],-abs(p[1]),p[2]],[p[0],abs(p[1]),p[2]]]],views=['top'],visible=False)
    if sid in ['intersection_inner','intersection_shell']:
        samples={}
        pairs=s.data['parameters']['pairs']
        for n,(R,r) in enumerate(pairs):
            points=[[r*math.cos(t),r*math.sin(t),sign*math.sqrt(R*R-r*r*math.sin(t)**2)] for sign in ([1,-1] if sid=='intersection_inner' else [1]) for t in [0,math.pi/4,math.pi/2,3*math.pi/4,math.pi,5*math.pi/4,3*math.pi/2,7*math.pi/4]]
            samples['outer' if sid=='intersection_shell' and n==0 else 'inner']=points
            if sid=='intersection_shell':
                key='outer_points' if n==0 else 'inner_points'
                s.projected(key,crosses(points),visible=False,color='e1a149' if n==0 else 'f2d58c')
                e[key]['world']=[line for line in e[key]['world'] if line['points'][0][1]>=-1e-7]
        s.data['parameters']['method_samples']=samples
        if sid=='intersection_inner':
            pts=samples['inner'];s.projected('special',crosses(pts[::2]),visible=False);s.projected('intermediate',crosses(pts[1::2]),visible=False)
    if sid=='combination_slope':
        candidates=[]
        for key,entity in e.items():
            if not key.startswith('left_') or not key.endswith('_visible'):continue
            for paths in entity.get('paths',{}).values():
                for path in paths:
                    candidates += [p for p in path.get('world_points',[]) if p is not None and p[1]<-1 and p[2]>1]
        p=max(candidates,key=lambda p:(round(p[2],3),-p[1],-p[0]));p=[float(x) for x in p]
        s.data['parameters']['method_corner']=p
        for view in ['front','top']:
            q=project(p,view)
            s.ink('known_corner_'+view,view,[[[q[0]-1,q[1]],[q[0]+1,q[1]]],[[q[0],q[1]-1],[q[0],q[1]+1]]],visible=False)
            e['known_corner_'+view]['labels']=[dict(text='p′' if view=='front' else 'p',at=[q[0]+2,q[1]-2],view=view)]
        e['known_corner_front']['world']=[dict(points=line,style='solid') for line in crosses([p],1.)]
        s.entity('height_measure',visible=False,brace=dict(view='front',a=[p[0],0],b=project(p,'front'),label='高度'))
        s.entity('depth_measure',visible=False,brace=dict(view='top',a=[p[0],0],b=project(p,'top'),label='前后距离'))
        depth=s.data['parameters']['depth_bottom']/2;height=s.data['parameters']['height']
        s.ink('height_carrier','left',[[[-depth-4,-p[2]],[depth+4,-p[2]]]],'dashed',visible=False)
        s.ink('depth_carrier','left',[[[-p[1],4],[-p[1],-height-4]]],'dashed',visible=False)
        q=project(p,'left');s.entity('derived_corner',world=crosses([p],1.),paths={'left':[dict(points=[[q[0]-1,q[1]],[q[0]+1,q[1]]],style='solid'),dict(points=[[q[0],q[1]-1],[q[0],q[1]+1]],style='solid')]},labels=[dict(text='p″',at=[q[0]+2,q[1]-2],view='left')],visible=False)
    return s.data

def apply(courses,scenes):
    from course_pedagogy import Review,drawing,normalize
    r=Review(courses,scenes)
    for name in ['cylinder','cone','sphere']:
        p=scenes['basic_'+name]['parameters']['surface_point']
        r.add('basic_solids',name,'given',('已知前半球点 P 的正面投影 p′。' if name=='sphere' else '已知 P 在这条母线上，高度为 %g mm。'%p[2] if name=='cone' else '已知圆周上的投影 p，高度为 %g mm，求空间点 P。'%p[2]),after='silhouette' if name=='sphere' else 'generator' if name=='cone' else 'circle',action=drawing(['given_projection'] if name!='cone' else ['point_generator']),focus=['given_projection'] if name!='cone' else ['point_generator'])
        if name=='cylinder':
            r.show('basic_solids:cylinder:circle',[],[])
            r.beat('basic_solids:cylinder:circle')['action']={};r.text('basic_solids:cylinder:circle',r.beat('basic_solids:cylinder:circle')['text'],focus=['body_top'])
            r.add('basic_solids','cylinder','height','先按给定高度作水平圆。',after='given',action=drawing(['level']),focus=['level'])
        r.text('basic_solids:'+name+':point',{'cylinder':'过 p 引出母线，与同高度圆相交，确定 P。','cone':'母线与这个水平圆相交，交点就是 P。','sphere':'由 p′ 左右对正，取水平圆上靠前的交点。'}[name])
        r.beat('basic_solids:'+name+':point')['action'].setdefault('parts',{})['point_generator']={'visibility':1.,'draw':1.}
    r.text('basic_solids:sphere:level','按 p′ 的高度截球，得到一个水平圆。')
    r.text('basic_solids:cone:level','按给定高度作水平圆；这个圆也在锥面上。')
    r.text('bearings:structure:size','按304查表：外径52 mm、宽15 mm，用于确定座孔和轴向空间。')
    r.add('intersection_solids','shell','outer-points','先用外壁的圆周和母线，求外表面的公共点。',after='surfaces',action=drawing(['outer_points']),focus=['outer_points'])
    r.add('intersection_solids','shell','inner-points','换用内孔的圆周和母线，求孔内公共点。',after='outer-points',action=drawing(['inner_points']),focus=['inner_points'])
    r.beat('intersection_solids:shell:visible')['action']['parts'].update({k:{'visibility':0.} for k in ['outer_points','inner_points']})
    r.add('combination','slope','point-height','先定位一个轮廓点：从 p′ 取高度，作侧面等高线。',after='parts',action=drawing(['known_corner_front','known_corner_top','height_measure','height_carrier']),focus=['known_corner_front','height_carrier'])
    r.add('combination','slope','point-depth','从 p 取前后距离；两条对应线相交，确定 p″。',after='point-height',action={'parts':{k:{'visibility':1.,'draw':1.} for k in ['depth_measure','depth_carrier','derived_corner']},'keyframes':[{'at':.01,'parts':{'depth_measure':{'visibility':1.,'draw':0.},'depth_carrier':{'visibility':1.,'draw':0.},'derived_corner':{'visibility':0.}}},{'at':.65,'parts':{'depth_measure':{'draw':1.},'depth_carrier':{'draw':1.},'derived_corner':{'visibility':0.}}},{'at':.8,'parts':{'derived_corner':{'visibility':1.,'draw':1.}}}],'duration':2.4},focus=['depth_carrier','derived_corner'])
    r.beat('combination:slope:outer')['action']['parts'].update({k:{'visibility':0.} for k in ['known_corner_front','known_corner_top','height_measure','height_carrier','depth_measure','depth_carrier','derived_corner']})
    r.text('combination:slope:outer','其余轮廓点也这样配对，再连成主体轮廓。')
    normalize(r)
