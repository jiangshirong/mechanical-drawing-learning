from course_geometry import *

def plane_sheet(normal,d,extent=55):
    n=unit(normal);u=unit(cross(n,[0,0,1] if abs(n[2])<.9 else [0,1,0]));v=cross(n,u);c=mul(n,d)
    pts=[add(c,add(mul(u,x*extent),mul(v,y*extent))) for x,y in [(-1,-1),(1,-1),(1,1),(-1,1)]]
    return pts+[pts[0]],tri_quad(*pts)

def basic_scenes():
    bodies={'prism':Manifold.cube([42,30,40],True).translate([0,0,20]),'cylinder':cylinder(22,44),'cone':Manifold.cylinder(48,24,0,96),'sphere':Manifold.sphere(25,96)}
    result=[]
    for name,b in bodies.items():
        s=Scene('basic_'+name,['t01-q03','t07-q03','t04-q03','t05-q04']);add_body(s,'body',b)
        if name=='prism':lines=[[[21,15,0],[21,15,40]]]
        elif name=='cylinder':lines=[[[22,0,0],[22,0,44]],[[0,-22,0],[0,-22,44]]]
        elif name=='cone':lines=[[[24,0,0],[0,0,48]],[[-24,0,0],[0,0,48]]]
        else:lines=[[[25*cos(t),0,25*sin(t)] for t in np.linspace(0,TAU,129)]]
        s.projected('generators',lines,visible=False,color='e2a05f')
        z=20 if name!='sphere' else 10
        r={'prism':21,'cylinder':22,'cone':24*(1-z/48),'sphere':sqrt(25**2-z*z)}[name]
        circle_=circle3(r,z)
        s.projected('level',[circle_],visible=False,color='d7893c')
        # Put the explanatory point on the side visible from the lesson camera.
        p=[r*cos(.8),-r*sin(.8),z]
        if name=='prism':p=[21,15,20]
        s.projected('point',[[add(p,[-.5,0,0]),add(p,[.5,0,0])],[add(p,[0,0,-.5]),add(p,[0,0,.5])]],visible=False)
        s.data['parameters']={'kind':name,'surface_point':p,'level':z,'radius':r};result.append(s)
    return result

def cut_scenes():
    result=[]
    # Pentagonal prism with an oblique cap and a higher land, from t01-q03(1).
    footprint=[[-30,0],[-10,-28],[23,-18],[23,18],[-10,28]]
    prism=CrossSection([footprint]).extrude(46)
    below=prism.split_by_plane([-.43,0,1],28/sqrt(1+.43**2))[1]
    high=prism ^ Manifold.cube([11,100,80]).translate([12,-50,0])
    pcut=below+high
    # Cylinder: two upper side cuts plus a wider through slot at the base.
    cyl=cylinder(30,58)
    ccut=cyl-(Manifold.cube([80,80,20]).translate([-80-12,-40,42])+Manifold.cube([80,80,20]).translate([12,-40,42]))
    ccut=ccut-Manifold.cube([40,80,20]).translate([-20,-40,-1])
    # Horizontal cone and stepped cylindrical continuation, clipped by z=12.
    cone=Manifold.cylinder(52,0,30,96).rotate([0,90,0]).translate([-52,0,0])
    cone=cone+cylinder(30,20,'x')+cylinder(19,30,'x',(20,0,0))
    kcut=cone.split_by_plane([0,0,1],12)[1]
    hemi=Manifold.sphere(30,128).split_by_plane([0,0,1],0)[0]
    hcut=hemi-Manifold.cube([24,80,40]).translate([-16,-40,11])
    specs=[('prism',prism,pcut,'t01-q03','left'),('cylinder',cyl,ccut,'t07-q03','left'),('cone',cone,kcut,'t04-q03','top'),('sphere',hemi,hcut,'t01-q03','left')]
    for name,whole,body,source,target in specs:
        s=Scene('cut_'+name,[source]);s.data['parameters']={'kind':name,'target_view':target,'sampling_segments':128,'scale_basis':'原图比例重绘；统一毫米教学尺度，无题给尺寸'}
        add_body(s,'retained',body,project_views=False);add_body(s,'removed',whole-body,project_views=False,color='8eacbb')
        for v,lines in model_projection(body).items():s.entity('result_'+v,paths={v:lines},visible=v!=target)
        if name=='sphere':
            s.data['entities']['result_top']['initial']=0
            s.ink('known_top','top',[circle(30)])
            s.data['parameters']['target_views']=['top','left']
        guides=[];curve=[]
        if name=='cylinder':
            for x,z in [(-12,42),(12,42),(-20,19),(20,19)]:
                y=sqrt(30*30-x*x);guides.append([[x,-y,z],[x,y,z]])
            curve=[]
            for xcut,z,upper in [(12,42,True),(20,19,False)]:
                current=[]
                for t in np.linspace(0,TAU,257):
                    p=[30*cos(t),30*sin(t),z]
                    valid=abs(p[0])>=xcut if upper else abs(p[0])<=xcut
                    if valid:current.append(p)
                    elif len(current)>1:curve.append(current);current=[]
                if len(current)>1:curve.append(current)
                for x in [-xcut,xcut]:
                    for y in [-sqrt(900-x*x),sqrt(900-x*x)]:curve.append([[x,y,z],[x,y,58 if upper else 0]])
            s.data['parameters'].update(radius=30,height=58,upper_half_width=12,slot_half_width=20,slot_height=19)
        elif name=='sphere':
            for x in [-16,8]:
                lim=sqrt(30**2-x*x-11**2)
                curve.append([[x,y,sqrt(max(0,900-x*x-y*y))] for y in np.linspace(-lim,lim,97)])
            rr=sqrt(900-121);ang0=np.arccos(8/rr);ang1=np.arccos(-16/rr)
            curve += [[[rr*cos(t),rr*sin(t),11] for t in np.linspace(a,b,40)] for a,b in [(ang0,ang1),(-ang1,-ang0)]]
            guides=[[[x,-sqrt(900-x*x-121),11],[x,sqrt(900-x*x-121),11]] for x in [-16,8]]
            s.data['parameters'].update(radius=30,slot_left=-16,slot_right=8,slot_floor=11)
        elif name=='cone':
            start=-52+12*52/30
            for sign in [-1,1]:curve.append([[x,sign*sqrt(max(0,(30*(x+52)/52)**2-12**2)),12] for x in np.linspace(start,0,129)])
            for x in np.linspace(start,0,5):
                rr=30*(x+52)/52;guides.append([[x,y,z] for y,z in circle(rr)])
            for x0,x1,radius in [(0,20,30),(20,50,19)]:
                for sign in [-1,1]:curve.append([[x0,sign*sqrt(radius**2-144),12],[x1,sign*sqrt(radius**2-144),12]])
            s.data['parameters'].update(cone_length=52,radius=30,cut_height=12)
        else:
            for a,b in zip(footprint,footprint[1:]+footprint[:1]):
                pa=[a[0],a[1],.43*a[0]+28];pb=[b[0],b[1],.43*b[0]+28]
                if a[0]<=12 and b[0]<=12:curve.append([pa,pb])
                elif (a[0]-12)*(b[0]-12)<0:
                    mid=lerp(pa,pb,(12-a[0])/(b[0]-a[0]));curve.append([pa,mid] if a[0]<12 else [mid,pb])
            guides=[[[x,y,0],[x,y,min(46,.43*x+28)]] for x,y in footprint]
        s.projected('guides',guides,visible=False,color='ce914b')
        s.projected('intersection',curve,visible=False,color='d88b37')
        for v in s.data['entities']['guides']['paths']:
            for item in s.data['entities']['guides']['paths'][v]:item['style']='dashed'
        s.data['constraints']=[{'kind':'surface_intersection','entity':'intersection','primitive':name}]
        result.append(s)
    return result

def intersection_scenes():
    result=[]
    for name,source in [('inner','t06-q04'),('shell','t05-q04')]:
        s=Scene('intersection_'+name,[source]);R=30;r=16
        horizontal=cylinder(R,68,'x',(-34,0,0));vertical=cylinder(r,110,'z',(0,0,-40))
        if name=='inner':body=Manifold.cube([68,68,68],True)-(horizontal+vertical)
        else:
            outside=cylinder(36,68,'x',(-34,0,0));tube=cylinder(23,50,'z',(0,0,0))
            body=(outside+tube)-(horizontal+vertical)
            body=body.split_by_plane([0,0,1],0)[0]
        add_body(s,'body',body)
        # The known front projection excludes the unknown intersection; later ink
        # is computed from the shared cylinder equations, not read from a picture.
        if name=='inner':
            known=[path(rect(-34,-34,68,68))]
            known += [path([[x,z],[X,z]],'dashed') for z in [-30,30] for x,X in [(-34,-16),(16,34)]]
            known += [path([[x,z],[x,Z]],'dashed') for x in [-16,16] for z,Z in [(-34,-30),(30,34)]]
        else:
            known=[path([[-34,0],[-34,-36],[-23,-36],[-23,-50],[23,-50],[23,-36],[34,-36],[34,0],[-34,0]])]
            known += [path([[x,-30],[X,-30]],'dashed') for x,X in [(-34,-16),(16,34)]]
            known += [path([[x,-50],[x,-30]],'dashed') for x in [-16,16]]
        s.data['entities']['body_front']['paths']={'front':known}
        add_body(s,'cutaway',body.split_by_plane([0,1,0],0)[0],visible=False,project_views=False)
        curves=[]
        pairs=[(R,r)] if name=='inner' else [(36,23),(30,16)]
        for R_,r_ in pairs:
            for sign in ([1,-1] if name=='inner' else [1]):
                curves.append([[r_*cos(t),r_*sin(t),sign*sqrt(R_**2-(r_*sin(t))**2)] for t in np.linspace(0,TAU,193)])
        s.entity('intersection',world=curves,paths={'front':[path([project(p,'front') for p in curve[:97]],'dashed' if name=='inner' or i>0 else 'solid') for i,curve in enumerate(curves)]},visible=False,color='d88a38')
        # Candidate traces are computed on both surfaces; auxiliaries select the same world points.
        guides=[];points=[]
        for t in [0,pi/2,pi,3*pi/2,pi/4,3*pi/4]:
            p=[r*cos(t),r*sin(t),sqrt(R*R-r*r*sin(t)**2)];points.append(p)
            guides += [[[p[0],p[1],-34],p],[[p[0],-34,p[2]],p]]
        s.projected('guides',guides,visible=False,color='d49c55')
        s.projected('special',[[add(p,[-.7,0,0]),add(p,[.7,0,0])] for p in points[:4]],visible=False)
        s.projected('intermediate',[[add(p,[-.7,0,0]),add(p,[.7,0,0])] for p in points[4:]],visible=False)
        for item in s.data['entities']['guides']['paths'].values():
            for line in item:line['style']='dashed'
        s.data['parameters']={'horizontal_radius':R,'vertical_radius':r,'pairs':pairs,'vertical_axis':'z','horizontal_axis':'x'}
        s.data['constraints']=[{'kind':'two_cylinders','entity':'intersection','pairs':pairs}];result.append(s)
    return result

def combination_scenes():
    result=[existing_scene(n,'combination_'+n) for n in ['slope','base','bracket']]
    s=Scene('combination_missing',['t08-q07'])
    body=Manifold.cube([80,50,50]).translate([-40,-25,0])
    body-=Manifold.cube([56,60,14]).translate([-28,-30,37])
    # Through bottom dovetail: extruded in x, profile in y/z.
    groove=CrossSection([[[-15,0],[15,0],[8,13],[-8,13]]]).extrude(100).rotate([90,0,90]).translate([-50,0,0])
    body-=groove
    body-=cylinder(19,20,centre=(0,0,22))+cylinder(13,60,centre=(0,0,-1))
    add_body(s,'body',body);s.data['parameters']={'length':80,'depth':50,'height':50,'top_slot_width':56,'slot_floor':37,'counterbore_radius':19,'through_radius':13,'counterbore_floor':22}
    for view in ['top','left']:s.data['entities']['body_'+view]['initial']=0
    s.ink('known_top','top',[rect(-40,-25,80,50),circle(19),circle(13)])
    s.ink('known_left','left',[[[-25,-50],[25,-50],[25,0],[15,0],[8,-13],[-8,-13],[-15,0],[-25,0],[-25,-50]]])
    result.append(s);return result

def hatches(poly,spacing=3):
    """CrossSection contours -> clipped 45-degree hatching by segment parity."""
    if not poly:return []
    points=[p for ring in poly for p in ring];values=[p[1]-p[0] for p in points];lines=[]
    for c in np.arange(min(values)+spacing,max(values),spacing):
        hits=[]
        for ring in poly:
            for a,b in zip(ring,list(ring[1:])+[ring[0]]):
                da=a[1]-a[0]-c;db=b[1]-b[0]-c
                if (da<=0<db) or (db<=0<da):hits.append(lerp(a,b,da/(da-db)))
        hits.sort(key=lambda p:p[0])
        for i in range(0,len(hits)-1,2):lines.append([hits[i],hits[i+1]])
    return lines

def section_scenes():
    result=[]
    s=existing_scene('section','section_full',True)
    s.entity('removed',model='assets/examples/section/removed.glb',visible=False)
    sheet,mesh=plane_sheet([0,1,0],0,100)
    s.entity('cutting_plane',world=[sheet],mesh=mesh,visible=False,color='cf9e61',opacity=.18)
    sec=s.data.pop('section_source')
    outlines=[[a['a'],a['b']] for a in sec['views']['front']['segments'] if not a.get('hidden',False)]
    # Section source uses mathematical z-up; diagram is y-down.
    s.ink('section_outline','front',[[[p[0],-p[1]] for p in line] for line in outlines],visible=False)
    # A full section also retains the visible silhouette behind the cut.
    # In this symmetric original model it projects to the same exterior outline:
    # top/bottom rims across the bores must not disappear with the front half.
    params=s.data['parameters']
    rim_levels=[0,-params['left_height'],-params['right_height']]
    for key,e in list(s.data['entities'].items()):
        if key.startswith('front_') and key.endswith('_visible'):
            for stroke in e['paths'].get('front',[]):
                # Keep rear end rims and the visible counterbore floor, not the
                # front base/rib edges removed by the imaginary cut.
                if key=='front_bore_visible' or any(all(abs(p[1]-z)<1e-5 for p in stroke['points']) for z in rim_levels):
                    s.data['entities']['section_outline']['paths']['front'].append(stroke)
    x=params['right_x'];r=params['counterbore_radius'];z=params['counterbore_floor']
    s.data['entities']['section_outline']['paths']['front'].append(path([[x-r,-z],[x+r,-z]]))
    h=[]
    for item in sec['hatches']:
        if isinstance(item,dict):a=item.get('a');b=item.get('b')
        else:a,b=item
        h.append([[a[0],-a[1]],[b[0],-b[1]]])
    s.ink('hatching','front',h,'thin',visible=False)
    s.data['parameters']['rib_rule']='容易把肋板和底座、凸台看成一整块厚实材料'
    result.append(s)
    # Parametric sectional examples; cut material and section curves use the same solid.
    for name,source in [('half','t04-q04'),('local','t01-q09'),('stepped','t08-q08'),('rotated','t01-q06'),('combined','t03-q04')]:
        s=Scene('section_'+name,[source])
        base=Manifold.cube([92,56,12]).translate([-46,-28,0])
        if name in ['half','local']:
            body=base+cylinder(22,44,centre=(4,0,12));body-=cylinder(12,70,centre=(4,0,-1));body-=cylinder(16,16,centre=(4,0,40))
            centres=[(4,0,12)]
        elif name=='stepped':
            body=base+Manifold.cube([92,56,22]).translate([-46,-28,12]);centres=[(-18,0,12),(30,-17,9),(30,17,9)]
            for x,y,radius in centres:body-=cylinder(radius,45,centre=(x,y,-1))
        else:
            centres=[(-32,-18,9),(0,0,12),(34,0 if name=='rotated' else 16,9)]
            body=base
            for x,y,radius in centres:body+=cylinder(radius+9,26,centre=(x,y,12))
            for x,y,radius in centres:body-=cylinder(radius,50,centre=(x,y,-1))
        add_body(s,'body',body)
        kept=body.split_by_plane([0,-1,0],0)[1]
        add_body(s,'cut',kept,visible=False,project_views=False,color='7ca6bb')
        # Actual section at chosen y. Step/rotation expression uses piecewise cutting planes.
        rings=[];outline=[];hatch=[]
        if name in ['half','local']:
            cross_section=body.rotate([90,0,0]).slice(0)
            rings=cross_section.to_polygons()
            for ring in rings:
                points=[[float(p[0]),float(p[1])] for p in ring];outline.append(points+[points[0]])
            hatch=hatches([[[float(p[0]),float(p[1])] for p in ring] for ring in rings])
            if name=='half':
                # Right half is sectional, left half retains the original outside view.
                section_area=cross_section ^ CrossSection([[[4,-100],[100,-100],[100,100],[4,100]]])
                rings=section_area.to_polygons();outline=[[[float(p[0]),float(p[1])] for p in ring]+[[float(ring[0][0]),float(ring[0][1])]] for ring in rings]
                hatch=hatches([[[float(p[0]),float(p[1])] for p in ring] for ring in rings])
            elif name=='local':
                section_area=cross_section ^ CrossSection([[[-8,18],[0,15],[8,20],[15,18],[20,25],[20,60],[-8,60]]])
                rings=section_area.to_polygons();outline=[[[float(p[0]),float(p[1])] for p in ring]+[[float(ring[0][0]),float(ring[0][1])]] for ring in rings]
                hatch=hatches([[[float(p[0]),float(p[1])] for p in ring] for ring in rings])
        else:
            cuts=[]
            for i,(x,y,radius) in enumerate(centres):
                # Unfold rotated plane using radial distance, retaining material thickness.
                xx=(-sqrt(x*x+y*y) if x<0 else sqrt(x*x+y*y)) if name in ['rotated','combined'] else x
                cuts.append((xx,radius))
            outline=[rect(-46,-34 if name=='stepped' else -38,92,34 if name=='stepped' else 38)]
            for x,radius in cuts:outline += [[[x-radius,0],[x-radius,-34 if name=='stepped' else -38]],[[x+radius,0],[x+radius,-34 if name=='stepped' else -38]]]
            area=CrossSection([outline[0][:-1]])
            for x,radius in cuts:area-=CrossSection([rect(x-radius,-50,2*radius,60)[:-1]])
            hatch=hatches(area.to_polygons())
            trace=[]
            if name=='stepped':trace=[[-46,0],[-2,0],[-2,-17],[46,-17]]
            else:trace=[[-46,-18],[0,0],[46,0 if name=='rotated' else 16]]
            s.ink('cutting_path','top',[trace],'axis',visible=False)
            s.projected('cutting_planes',[[[p[0],p[1],0],[p[0],p[1],44]] for p in trace],visible=False,color='db9451')
        s.ink('section_outline','front',outline,visible=False)
        s.ink('hatching','front',hatch,'thin',visible=False)
        s.data['parameters']={'centres':centres,'kind':name,'base':[92,56,12],'teaching_scene':True,'note':'概念演示的参数化结构；原题完整图另由题目层呈现'}
        result.append(s)
    return result

def removed_scenes():
    result=[]
    for kind in ['key','hole']:
        s=Scene('removed_'+kind,['t03-q07'],views=('front','left'))
        body=cylinder(18,80,'x',(-40,0,0))
        if kind=='key':body-=Manifold.cube([50,10,8]).translate([-25,-5,15])
        else:body-=cylinder(5,45,centre=(0,0,-22))+cylinder(5,50,'x',(0,0,0))
        add_body(s,'body',body)
        cross_section=body.rotate([0,-90,0]).slice(0);rings=cross_section.to_polygons()
        lines=[list(map(list,ring))+[list(ring[0])] for ring in rings]
        s.ink('outline','left',lines,visible=False);s.ink('hatching','left',hatches(rings),'thin',visible=False)
        sheet,mesh=plane_sheet([1,0,0],0,24);s.entity('cutting_plane',world=[sheet],mesh=mesh,visible=False,color='bc8a4a')
        s.data['parameters']={'radius':18,'length':80,'key_depth':3 if kind=='key' else None,'key_width':10,'hole_radius':5}
        result.append(s)
    return result

def all_scenes():
    for factory in [basic_scenes,cut_scenes,intersection_scenes,combination_scenes,section_scenes,removed_scenes]:
        print('Building',factory.__name__,flush=True)
        yield from factory()
