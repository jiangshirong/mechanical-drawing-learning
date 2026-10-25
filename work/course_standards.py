from course_geometry import *
from course_solids import hatches

def thread_scene(kind):
    s=Scene('thread_'+kind,['t05-q06','t03-q06'],views=('front','top'))
    R=10;r=8;length=42
    outer=cylinder(R,length)
    nut=cylinder(17,24,inner=R)
    s.data['parameters']={'major_diameter':20,'minor_diameter':16,'length':42,'schematic_thread':True}
    if kind=='external':
        add_body(s,'model',outer,project_views=False)
        s.ink('major','front',[[[-R,0],[-R,-length],[R,-length],[R,0]]])
        s.ink('minor','front',[[[-r,0],[-r,-length]],[[r,0],[r,-length]]],'thin',visible=False)
        s.ink('end_major','top',[circle(R)],visible=False)
        s.ink('end_minor','top',[circle(r,start=.15*pi,end=1.65*pi)],'thin',visible=False)
    else:
        add_body(s,'model',nut,project_views=False)
        s.ink('outline','front',[rect(-17,-24,34,24)])
        s.ink('minor','front',[[[-r,0],[-r,-24]],[[r,0],[r,-24]]],visible=False)
        s.ink('major','front',[[[-R,0],[-R,-24]],[[R,0],[R,-24]]],'thin',visible=False)
        s.ink('end_minor','top',[circle(r)],visible=False)
        s.ink('end_major','top',[circle(R,start=.15*pi,end=1.65*pi)],'thin',visible=False)
    s.ink('axis','front',[[[0,5],[0,-length-5]]],'axis')
    s.ink('termination','front',[[[-R,-32 if kind=='external' else -24],[R,-32 if kind=='external' else -24]]],visible=False)
    # A faint geometric helix is only a 3D explanatory surface trace, never an engineering projection.
    helix=[[R*cos(t),R*sin(t),(length if kind=='external' else 24)*t/(TAU*10)] for t in np.linspace(0,TAU*10,640)]
    s.entity('helix',world=[helix],visible=False,color='e2ac63')
    return s

def engaged_thread():
    s=Scene('thread_engaged',['t03-q06'],views=('front',))
    add_body(s,'female',cylinder(18,30,inner=10),project_views=False)
    add_body(s,'male',cylinder(10,40,centre=(0,0,14)),project_views=False)
    s.ink('body','front',[rect(-18,-30,36,30)])
    s.ink('female_free','front',[[[-8,0],[-8,-14]],[[8,0],[8,-14]]])
    s.ink('male_major','front',[[[-10,-14],[-10,-54],[10,-54],[10,-14]]],visible=False)
    s.ink('male_minor','front',[[[-8,-14],[-8,-54]],[[8,-14],[8,-54]]],'thin',visible=False)
    s.ink('female_minor_wrong','front',[[[-8,-14],[-8,-30]],[[8,-14],[8,-30]]],visible=False,ink='a74d45')
    s.ink('female_major','front',[[[-10,0],[-10,-14]],[[10,0],[10,-14]]],'thin',visible=False)
    s.ink('boundary','front',[[[-18,-30],[-10,-30]],[[10,-30],[18,-30]]],visible=False)
    return s

def fastener_scene(stud=False):
    s=Scene('fastener_'+('stud' if stud else 'bolt'),['t02-q06' if stud else 't01-q07'],views=('front','top'))
    R=6;clear=7;z0=22
    lower=Manifold.cube([46,38,22]).translate([-23,-19,0])
    hole=cylinder(R if stud else clear,32,centre=(0,0,-1))
    lower-=hole
    upper=Manifold.cube([46,38,14]).translate([-23,-19,z0])-cylinder(clear,60,centre=(0,0,-1))
    washer=cylinder(13,2,centre=(0,0,36),inner=clear)
    nut=Manifold.cylinder(10,12,circular_segments=6).translate([0,0,38])-cylinder(R,60)
    shank=cylinder(R,58 if not stud else 44,centre=(0,0,-5 if not stud else 8))
    if not stud:shank+=Manifold.cylinder(8,12,circular_segments=6).translate([0,0,-8])
    for name,body,color in [('lower',lower,'6796ae'),('upper',upper,'8bb0be'),('washer',washer,'adb7c0'),('nut',nut,'c2af86'),('shank',shank,'b3c0c8')]:add_body(s,name,body,project_views=False,color=color)
    # Axial convention. The bolt/stud itself is not hatched.
    s.ink('plates','front',[rect(x,y,w,h) for x,w in [(-23,16),(7,16)] for y,h in [(-22,22),(-36,14)]])
    s.ink('clearance','front',[[[-clear,0 if not stud else -22],[-clear,-36]],[[clear,0 if not stud else -22],[clear,-36]]],visible=False)
    s.ink('shank_ink','front',[[[-R,0 if not stud else -8],[-R,-53],[R,-53],[R,0 if not stud else -8]]],visible=False)
    s.ink('head_ink','front',[rect(-12,0,24,8)],visible=False)
    s.ink('nut_ink','front',[rect(-12,-48,24,10),rect(-13,-38,26,2)],visible=False)
    s.ink('thread_minor','front',[[[-4.8,-27],[-4.8,-53]],[[4.8,-27],[4.8,-53]]],'thin',visible=False)
    for name,z,height,direction in [('lower_hatch',0,22,1),('upper_hatch',-22,14,-1)]:
        polys=[rect(-23,z-height,16,height)[:-1],rect(7,z-height,16,height)[:-1]]
        lines=hatches(polys)
        if direction<0:lines=[[[-p[0],p[1]] for p in line] for line in lines]
        s.ink(name,'front',lines,'thin',visible=False)
    s.ink('top','top',[circle(12,n=6),circle(clear,start=.2*pi,end=1.7*pi)],visible=False)
    if stud:
        s.data['entities']['head_ink']['paths']={'front':[[ ]]} if False else {'front':[path([[-R,-8],[R,-8]])]}
        s.ink('engagement','front',[[[-6,-8],[-6,-22]],[[6,-8],[6,-22]],[[ -6,-8],[6,-8]]],visible=False)
    s.data['parameters']={'nominal_diameter':12,'clearance_diameter':14,'lower_thickness':22,'upper_thickness':14,'washer':2,'kind':'stud' if stud else 'bolt'}
    return s

def gear_scene(pair=False):
    source='t01-q08' if pair else 't02-q07';s=Scene('gear_pair' if pair else 'gear_single',[source],views=('front','left'))
    m=4 if pair else 3;zs=[20,35] if pair else [20];a=m*sum(zs)/2 if pair else 0
    s.data['parameters']={'module':m,'teeth':zs,'centre_distance':a,'drawing_scale':.5 if pair else 1,'standard_full_depth':True}
    for i,z in enumerate(zs):
        d=m*z;da=m*(z+2);df=m*(z-2.5);x=i*a
        # Revolved envelope has the three named circles; teeth on mesh are explanatory.
        pts=[]
        for k in range(z):
            for phase,rr in [(0,df/2),(.16,df/2),(.31,da/2),(.69,da/2),(.84,df/2)]:
                t=TAU*(k+phase)/z;pts.append([rr*cos(t),rr*sin(t)])
        body=CrossSection([pts]).extrude(14)-cylinder(10,16,centre=(0,0,-1))
        body=body.rotate([90,0,0]).translate([x,0,0])
        add_body(s,f'gear{i}',body,project_views=False,color='7ca7bb' if i==0 else 'b9a77c')
        for kind,radius,style in [('addendum',da/2,'solid'),('pitch',d/2,'axis'),('root',df/2,'thin')]:
            s.ink(f'{kind}{i}','front',[circle(radius,(x,0))],style,visible=kind=='addendum')
        s.ink(f'bore{i}','front',[circle(10,(x,0))])
        s.ink(f'side{i}','left',[rect(-7,-da/2,14,da),[[-7,-d/2],[7,-d/2]],[[-7,d/2],[7,d/2]]],visible=False)
        s.label(f'label_d{i}',f'd = {d:g} mm',[x-d*.35,d/2+12],visible=False)
        s.label(f'label_da{i}',f'dₐ = {da:g} mm',[x-da*.35,-da/2-10],visible=False)
        s.label(f'label_df{i}',f'df = {df:g} mm',[x-df*.35,df/2+24],visible=False)
    if pair:
        s.ink('centre_distance','front',[[[0,0],[a,0]]],'axis',visible=False)
        s.label('centre_label',f'a = {a:g} mm',[a*.3,-max(zs)*m/2-12],visible=False)
    return s

def bearing_scene():
    s=Scene('bearing',['t03-q08'],views=('front','left'))
    # Source 304: d20 D52 B15. Original DOC gives 04=20mm and 3=series.
    s.data['parameters']={'original_code':'304','d':20,'D':52,'B':15,'modern_correspondence':'6304','basis':'原DOC第三套第11页；制造商6304尺寸表'}
    add_body(s,'inner',cylinder(15,15,inner=10),project_views=False,color='b9c8cf')
    add_body(s,'outer',cylinder(26,15,inner=22),project_views=False,color='87a6b8')
    for i in range(8):
        a=TAU*i/8;ball=Manifold.sphere(3.7,24).translate([18.5*cos(a),18.5*sin(a),7.5]);add_body(s,'ball'+str(i),ball,project_views=False,color='d6c9a8')
    cage=cylinder(22,2,centre=(0,0,6.5),inner=15)
    for i in range(8):cage-=cylinder(3.9,5,centre=(18.5*cos(TAU*i/8),18.5*sin(TAU*i/8),5))
    add_body(s,'cage',cage,project_views=False,color='bd9659')
    add_body(s,'shaft',cylinder(10,33,centre=(0,0,-18))+cylinder(14,10,centre=(0,0,-10)),visible=False,project_views=False)
    add_body(s,'housing',cylinder(35,23,centre=(0,0,-4),inner=26),visible=False,project_views=False)
    s.ink('outline','left',[circle(10),circle(26)])
    s.ink('convention','front',[rect(-26,-15,16,15),rect(10,-15,16,15),[[-26,-15],[-10,0]],[[-26,0],[-10,-15]],[[10,0],[26,-15]],[[10,-15],[26,0]]],visible=False)
    s.ink('shaft_ink','front',[[[-10,18],[-10,10],[-14,10],[-14,0],[-10,0],[-10,-15],[10,-15],[10,0],[14,0],[14,10],[10,10],[10,18]]],visible=False)
    s.ink('housing_ink','front',[rect(-35,-19,9,23),rect(26,-19,9,23)],visible=False)
    for name,text,at_ in [('diameter','d = 20 mm',[-22,32]),('outside','D = 52 mm',[-27,-30]),('width','B = 15 mm',[-23,-19])]:s.label(name,text,at_,visible=False)
    # Keep the original question's horizontal shaft axis; the 2D convention rotates with the model.
    for e in s.data['entities'].values():
        if 'triangles' in e:e['triangles']=[[p[2],p[1],-p[0]] for p in e['triangles']]
        for lines in e.get('paths',{}).values():
            for line in lines:line['points']=[[-p[1],p[0]] for p in line['points']]
        for label in e.get('labels',[]):label['at']=[-label['at'][1],label['at'][0]]
    for key,a,b,text in [('diameter',[22,-10],[22,10],'20 mm'),('outside',[-12,-26],[-12,26],'52 mm'),('width',[0,31],[15,31],'15 mm')]:
        s.data['entities'][key]['labels']=[];s.data['entities'][key]['brace']={'view':'front','a':a,'b':b,'label':text}
    return s

def symbol_scene(id,labels,source):
    s=Scene(id,source,'paper',('front',))
    x=0
    for i,(text,width) in enumerate(labels):
        s.ink('box'+str(i),'front',[rect(x,-12,width,24)],'thin')
        s.label('token'+str(i),text,[x+3,5],size=26)
        x+=width
    s.data['parameters']={'symbol_tokens':[v[0] for v in labels]}
    return s

def tolerance_scenes():
    result=[]
    for id,labels,src in [('tolerance_hole',[('⌀40',42),('H',22),('7',22)],['t02-q08']),('tolerance_shaft',[('⌀70',42),('d',22),('11',25)],['t05-q08']),('tolerance_perpendicular',[('⊥',25),('⌀0.05',65),('C',25)],['t02-q08']),('tolerance_parallel',[('∥',25),('0.01',55),('A',25)],['t04-q07']),('tolerance_plane',[('⊥',25),('0.03',55),('A',25)],['t06-q08'])]:
        s=symbol_scene(id,labels,src)
        s.ink('datum','front',[[[-10,60],[120,60]]],visible=False)
        if id=='tolerance_perpendicular':
            s.ink('zone','front',[[[30,60],[30,10]],[[40,60],[40,10]]],'thin',visible=False)
            s.ink('actual','front',[[[35,60],[34,45],[36,30],[35,10]]],visible=False)
        elif id in ['tolerance_parallel','tolerance_plane']:
            lines=[[[0,25],[110,25]],[[0,35],[110,35]]] if id.endswith('parallel') else [[[30,60],[30,10]],[[40,60],[40,10]]]
            s.ink('zone','front',lines,'thin',visible=False)
            s.ink('actual','front',[[[0,30],[30,32],[60,28],[110,31]]] if id.endswith('parallel') else [[[35,60],[34,45],[36,30],[35,10]]],visible=False)
        else:
            s.ink('nominal','front',[[[0,60],[110,60]]],'axis',visible=False)
            s.ink('zone','front',[rect(25,35 if id.endswith('hole') else 65,70,25)],'thin',visible=False)
        if id in ['tolerance_perpendicular','tolerance_plane','tolerance_parallel']:
            s.data['layout']='dual'
            datum=tri_quad([-5,-25,0],[115,-25,0],[115,25,0],[-5,25,0])
            s.data['entities']['datum']['triangles']=datum
            if id=='tolerance_perpendicular':
                s.data['entities']['zone']['triangles']=mesh_triangles(cylinder(5,50,centre=(35,0,0)))
                s.data['entities']['actual']['world']=[path([[35,0,0],[34,1,15],[36,-1,30],[35,0,50]])]
                s.data['parameters']['zone_kind']='cylinder';s.data['parameters']['magnification']=200
            elif id=='tolerance_plane':
                s.data['entities']['zone']['triangles']=sum((tri_quad([x,-20,0],[x,20,0],[x,20,50],[x,-20,50]) for x in [30,40]),[])
                s.data['entities']['actual']['triangles']=sum((tri_quad([x,-20,z],[x,20,z],[X,20,Z],[X,-20,Z]) for (x,z),(X,Z) in zip([(35,0),(34,15),(36,30)],[(34,15),(36,30),(35,50)])),[])
                s.data['parameters']['zone_kind']='parallel_planes_perpendicular_to_datum';s.data['parameters']['magnification']=10/.03
            else:
                s.data['entities']['zone']['triangles']=sum((tri_quad([0,-20,z],[110,-20,z],[110,20,z],[0,20,z]) for z in [25,35]),[])
                s.data['entities']['actual']['triangles']=sum((tri_quad([x,-20,z],[X,-20,Z],[X,20,Z],[x,20,z]) for (x,z),(X,Z) in zip([(0,30),(30,28),(60,32)],[(30,28),(60,32),(110,29)])),[])
                s.data['parameters']['zone_kind']='parallel_planes_parallel_to_datum';s.data['parameters']['magnification']=1000
            s.data['entities']['zone']['opacity']=.18;s.data['entities']['zone']['color']='86b6c6'
            s.data['entities']['actual']['color']='da9754'
            s.data['provenance']['note']='公差域的间距放大展示；形状、基准方向与实际要素的包含关系由同一参数生成，不把画面间距当作毫米实测值。'
        result.append(s)
    for id,tokens,src in [('thread_mark_coarse',[('M',20),('8',20),('—7H',55)],['t02-q08']),('thread_mark_fine',[('M12',45),('×1.5',50),('—6g',55)],['t06-q08']),('thread_mark_pipe',[('G',22),('1/2',45)],['t01-q09']),('material',[('Q',25),('235',50),('—A',35)],['t08-q11'])]:
        s=symbol_scene(id,tokens,src)
        if id=='thread_mark_fine':s.label('internal_compare','M12×1.5—6H',[5,45],size=26,visible=False)
        if id=='thread_mark_pipe':s.entity('internal_example',paths={'front':[path([[0,35],[67,35],[67,85],[0,85],[0,35]]),path([[0,47],[67,47]]),path([[0,73],[67,73]])]},labels=[{'text':'G1/2','view':'front','at':[25,65],'size':24}],visible=False)
        result.append(s)
    return result

def roughness_scene():
    s=Scene('roughness',['t01-q09','t05-q08','t07-q09','t08-q11'],'paper',('front',))
    for i,kind in enumerate(['basic','removal','retained']):
        x=42*i
        s.ink('surface'+str(i),'front',[[[x-10,15],[x+23,15]]])
        s.ink(kind,'front',[[[x,8],[x+5,15],[x+18,-10]]],visible=False)
        if i==1:s.ink('bar','front',[[[x+7,1],[x+24,1]]],visible=False)
        if i==2:s.ink('circle','front',[circle(4,(x+8,4))],visible=False)
    s.label('value','Ra 6.3',[47,-15],visible=False)
    s.label('remaining','其余',[0,55],visible=False)
    s.label('compare','Ra 1.6    Ra 3.2    Ra 6.3',[0,80],visible=False)
    return s

def all_scenes():
    from course_gears import gear_scene
    yield thread_scene('external');yield thread_scene('internal');yield engaged_thread()
    yield fastener_scene();yield fastener_scene(True);yield gear_scene();yield gear_scene(True);yield bearing_scene()
    yield from tolerance_scenes();yield roughness_scene()
