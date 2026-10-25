from course_geometry import *
from course_solids import hatches
from course_reading import figure_scene

def engaged_thread():
    s=Scene('thread_engaged',['t03-q06'],views=('front','left'))
    block=Manifold.cube([45,40,40]).translate([0,-20,-20])
    drill=cylinder(8,34,'x')+Manifold.cylinder(5,8,0,96).rotate([0,90,0]).translate([34,0,0])
    block-=drill+cylinder(10,24,'x')
    add_body(s,'female',block.split_by_plane([0,1,0],0)[0],project_views=False)
    add_body(s,'male',cylinder(10,43,'x',(-20,0,0)),project_views=False)
    s.ink('body','front',[[[0,-20],[45,-20],[45,20],[0,20]],[[0,-20],[0,-10]],[[0,10],[0,20]]])
    s.ink('female_free','front',[[[34,-8],[39,0],[34,8]]])
    s.ink('axis','front',[[[-25,0],[50,0]]],'axis')
    s.ink('male_major','front',[[[-20,-10],[23,-10],[23,10],[-20,10]]],visible=False)
    s.ink('male_minor','front',[[[-8,-8],[23,-8]],[[-8,8],[23,8]]],'thin',visible=False)
    s.ink('female_major','front',[[[23,-8],[34,-8]],[[23,8],[34,8]]],visible=False)
    s.ink('female_minor','front',[[[23,-10],[32,-10]],[[23,10],[32,10]]],'thin',visible=False)
    s.ink('boundary','front',[[[32,-10],[32,-8]],[[32,8],[32,10]]],visible=False)
    solid=CrossSection([rect(0,-20,45,40)[:-1]])-CrossSection([[[0,-10],[23,-10],[23,-8],[34,-8],[39,0],[34,8],[23,8],[23,10],[0,10]]])
    s.ink('hatching','front',hatches(solid.to_polygons()),'thin',visible=False)
    s.ink('end','left',[circle(10)],visible=False)
    s.ink('end_minor','left',[circle(8,start=.1*pi,end=1.6*pi)],'thin',visible=False)
    s.data['parameters']={'major_diameter':20,'minor_diameter':16,'thread_engagement':23,'blind_drill_depth':39,'thread_depth':32,'draw_rules':['旋合段按外螺纹','未旋合段按内螺纹','剖面线到粗实线','螺纹终止与钻孔底分开']}
    return s

def judge_scenes():
    source='t05-q06-p25.png'
    ranges=[(75,90,220,500),(240,90,365,500),(400,90,630,500),(665,90,920,500)]
    for i,crop in enumerate(ranges):
        s=figure_scene('thread_judge_'+str(i+1),source,crop,marks={},source=['t05-q06'])
        e=s.data['entities']['figure'];height=e['rect'][3];scale=100/height;e['rect']=[0,0,120*scale,100]
        x=75;R=10;r=8;length=32
        internal=i>=2
        main=[[[x-R,45],[x-R,45-length],[x+R,45-length],[x+R,45]]]
        if internal:
            main=[rect(x-18,12,36,32),[[x-r,12],[x-r,44]],[[x+r,12],[x+r,44]]]
            if i==3:main=[[[x-18,10],[x-18,50],[x+18,50],[x+18,10]],[[x-r,10],[x-r,37],[x,42],[x+r,37],[x+r,10]]]
        s.ink('correct_major','front',main,visible=False)
        s.ink('correct_minor','front',[[[x+(R if internal else r)*sign,12],[x+(R if internal else r)*sign,34 if i==3 else 44]] for sign in [-1,1]],'thin',visible=False)
        s.ink('correct_circle','front',[circle(r if internal else R,(x,78))],visible=False)
        s.ink('correct_arc','front',[circle(R if internal else r,(x,78),start=.1*pi,end=1.6*pi)],'thin',visible=False)
        if internal:
            poly=CrossSection([rect(x-18,12,36,32)[:-1]])-CrossSection([rect(x-r,10,2*r,40)[:-1]])
            s.ink('correct_hatch','front',hatches(poly.to_polygons(),3),'thin',visible=False)
        s.label('given_label','给定画法',[0,-8],size=18)
        s.label('correct_label','规定画法',[54,-8],size=18,visible=False)
        s.data['verified_answer']={'choice':i+1,'correct':i==1,'source':'原DOC第5套第8页','reason':['外螺纹小径细实线圆不能画成完整粗圆','大径粗实线、小径四分之三细圆','内螺纹剖面线应画到小径粗实线；大径细圆约四分之三','盲孔螺纹终止与钻孔底不同；端视图大径用四分之三细圆'][i]}
        yield s


def fastener(stud=False):
    key='stud' if stud else 'bolt';s=Scene('fastener_'+key,['t02-q06' if stud else 't01-q07'],views=('front','top','left'))
    s.data['views']=['front','top']
    s.data['view_layout']={'front':[0,0,1,.62],'top':[0,.62,1,.38]}
    s.data['view_titles']={'front':'连接的剖视画法','top':'端面投影'}
    R=6;minor=4.8;clear=7;lower_h=28 if stud else 22;upper_h=14;plate_top=lower_h+upper_h;nut_z=plate_top+2;end=nut_z+15
    lower=Manifold.cube([46,38,lower_h]).translate([-23,-19,0])
    if stud:
        drill=cylinder(minor,lower_h-6+1,centre=(0,0,6))+Manifold.cylinder(3,0,minor,96).translate([0,0,3])
        lower-=drill+cylinder(R,lower_h-8+1,centre=(0,0,8))
    else:lower-=cylinder(clear,lower_h+2,centre=(0,0,-1))
    upper=Manifold.cube([46,38,upper_h]).translate([-23,-19,lower_h])-cylinder(clear,end+2)
    washer=cylinder(13,2,centre=(0,0,plate_top),inner=clear)
    nut=Manifold.cylinder(10,12,circular_segments=6).translate([0,0,nut_z])-cylinder(R,end+2)
    base=14 if stud else 0
    shank=cylinder(R,end-base,centre=(0,0,base))
    if not stud:shank+=Manifold.cylinder(8,12,circular_segments=6).translate([0,0,-8])
    for name,body,color in [('lower',lower,'6796ae'),('upper',upper,'8bb0be'),('washer',washer,'adb7c0'),('nut',nut,'c2af86'),('shank',shank,'b3c0c8')]:add_body(s,name,body,project_views=False,color=color)
    # Prescribed axial representation: thread mesh silhouettes are not used.
    if stud:
        material=CrossSection([rect(-23,-lower_h,46,lower_h)[:-1]])-CrossSection([[[-R,-lower_h],[R,-lower_h],[R,-14],[minor,-14],[minor,-6],[0,-3],[-minor,-6],[-minor,-14],[-R,-14]]])
        plate_paths=[[[ -23,0],[-23,-lower_h],[-R,-lower_h]],[[R,-lower_h],[23,-lower_h],[23,0],[-23,0]]]
        free_hole=[[[ -minor,-14],[-minor,-6],[0,-3],[minor,-6],[minor,-14]]]
    else:
        material=CrossSection([rect(-23,-lower_h,16,lower_h)[:-1],rect(7,-lower_h,16,lower_h)[:-1]])
        plate_paths=[rect(-23,-lower_h,16,lower_h),rect(7,-lower_h,16,lower_h)];free_hole=[]
    upper_area=CrossSection([rect(-23,-plate_top,16,upper_h)[:-1],rect(7,-plate_top,16,upper_h)[:-1]])
    plate_paths+=[rect(-23,-plate_top,16,upper_h),rect(7,-plate_top,16,upper_h)]
    for view in ['front','left']:
        s.ink('plates_'+view,view,plate_paths)
        s.ink('axis_'+view,view,[[[0,12],[0,-end-6]]],'axis')
    def both(id,lines,style='solid'):
        s.entity(id,paths={v:[path(line,style) for line in lines] for v in ['front','left']},visible=False)
    both('clearance',[[[-clear,-(lower_h if stud else 0)],[-clear,-plate_top]],[[clear,-(lower_h if stud else 0)],[clear,-plate_top]]]+free_hole)
    both('shank_ink',[[[-R,-base],[-R,-end+1],[-R+1,-end],[R-1,-end],[R,-end+1],[R,-base]]]+([[[-R,-base],[R,-base]]] if stud else []))
    both('head_ink',[[[-12,0],[-12,6],[-10,8],[10,8],[12,6],[12,0]]]+[[[x,0],[x,8]] for x in [-6,6]] if not stud else [[[-R,-lower_h],[-minor,-lower_h]],[ [minor,-lower_h],[R,-lower_h]]])
    both('nut_ink',[[[-12,-nut_z],[-12,-nut_z-8],[-10,-nut_z-10],[10,-nut_z-10],[12,-nut_z-8],[12,-nut_z]],rect(-13,-nut_z,26,2)]+[[[x,-nut_z],[x,-nut_z-10]] for x in [-6,6]])
    threads=[[[x,-lower_h+3],[x,-end+1]] for x in [-minor,minor]]
    if stud:threads +=[[[x,-14],[x,-lower_h]] for x in [-minor,minor]]+[[[x,-8],[x,-14]] for x in [-R,R]]
    both('thread_minor',threads,'thin')
    if stud:
        both('engagement',[[[-R,-8],[-minor,-8]],[[minor,-8],[R,-8]]])
    else:both('engagement',[[[-R,-lower_h+3],[R,-lower_h+3]]])
    both('lower_hatch',hatches(material.to_polygons()),'thin')
    both('upper_hatch',[[[-p[0],p[1]] for p in line] for line in hatches(upper_area.to_polygons())],'thin')
    s.ink('top','top',[circle(13),circle(12,n=6),circle(R),circle(minor,start=.1*pi,end=1.6*pi)],visible=False)
    s.data['entities']['top']['paths']['top'][-1]['style']='thin'
    s.data['parameters']={'nominal_diameter':12,'minor_diameter':9.6,'clearance_diameter':14,'lower_thickness':lower_h,'upper_thickness':14,'washer':2,'nut_height':10,'end_height':end,'kind':key,'blind_hole':stud,'stud_bottom':base,'drill_tip':3 if stud else None,'thread_depth_floor':8 if stud else None}
    s.data['constraints']=['通孔不与杆部等径','旋合处按外螺纹画法','相邻件剖面线不同向','紧固件按纵向不剖处理','顶视图由垫圈圆、螺母六边形和外螺纹端视组成']
    return s

def all_scenes():
    yield engaged_thread()
    yield from judge_scenes()
    yield fastener();yield fastener(True)
