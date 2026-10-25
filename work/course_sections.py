"""Piecewise cuts and rotated sections, derived from the same source-compatible solid."""
from course_geometry import *
from course_solids import hatches

def area_at_y(body,y):return body.rotate([90,0,0]).slice(y)
def rings_paths(area):return [[list(map(float,p)) for p in ring]+[list(map(float,ring[0]))] for ring in area.to_polygons() if len(ring)>2]
def slab(x0,x1,y):return Manifold.cube([x1-x0,150-y,180]).translate([x0,y,-40])
def span_area(area,x0,x1):return area ^ CrossSection([rect(x0,-120,x1-x0,180)[:-1]])

def kept_front(body, transitions=()):
    """Visible rear contours are part of a section, unlike a removed section.

    The vertical seams introduced solely by a stepped clipping volume are not
    physical edges and must not become a dividing line in the unfolded view.
    Cut-face boundaries remain in the separately generated section contours.
    """
    result=[]
    for item in model_projection(body)['front']:
        if item['style']!='solid':continue
        xs=[p[0] for p in item['points']]
        if any(max(abs(x-t) for x in xs)<1e-5 for t in transitions):continue
        result.append(item)
    return result

def step_body():
    left=Manifold.cube([62,58,22]).translate([-62,-29,0])-Manifold.cube([54,50,30]).translate([-58,-25,6])
    left+=cylinder(17,12,centre=(-32,0,0));left-=cylinder(10,50,centre=(-32,0,-1))
    end=cylinder(14,34,centre=(16,-17,0))+cylinder(14,34,centre=(16,17,0))+Manifold.cube([28,34,34]).translate([2,-17,0])
    end+=Manifold.cube([7,54,6]).translate([-3,-27,0])
    end-=cylinder(13,38,centre=(-7,0,-1));body=left+end
    for y in [-17,17]:body-=cylinder(6.5,45,centre=(16,y,-1))
    for y in [-20,20]:body-=cylinder(2,12,centre=(-54,y,-1))
    return body,{'recess_floor':6,'left_height':22,'lug_height':34,'main_hole':[-32,0,10],'end_holes':[[16,-17,6.5],[16,17,6.5]],'fastener_holes':[[-54,-20,2],[-54,20,2]]}

def radial_body(combined=False):
    distance=48;x,y=-distance*cos(pi/6),-distance*sin(pi/6)
    body=cylinder(20,40)+Manifold.cube([32,40,12]).translate([0,-20,0])
    arm=Manifold.cube([distance,14,12]).translate([-distance,-7,0]).rotate([0,0,30])
    if combined:
        web=CrossSection([[[-distance+8,12],[0,12],[0,36]]]).extrude(5).rotate([90,0,0]).translate([0,2.5,0]).rotate([0,0,30]);arm+=web
    else:arm=arm.translate([0,0,20])
    body+=arm+cylinder(9,28 if combined else 10,centre=(x,y,0 if combined else 20))
    if not combined:
        body+=Manifold.cube([distance,14,10]).translate([-distance,-7,20]).rotate([0,0,-30])+cylinder(9,10,centre=(x,-y,20))
        body-=cylinder(4.5,50,centre=(x,-y,-1))
    body-=cylinder(8,50,centre=(0,0,-1))+cylinder(12.5,32,centre=(0,0,14))+cylinder(4.5,50,centre=(x,y,-1))
    for yy in [-13,13]:body-=cylinder(4,30,centre=(26,yy,-1))
    return body,{'centre_radius':20,'through_radius':8,'counterbore_radius':12.5,'counterbore_floor':14,'arm_distance':distance,'arm_angle_degrees':30,'arm_hole':[x,y,4.5],'right_holes':[[26,-13,4],[26,13,4]],'combined':combined}

def half_body():
    base=Manifold.cube([60,42,6]).translate([-30,-21,0])+cylinder(21,6,centre=(-30,0,0))
    base-=Manifold.cube([12,6,12]).translate([24,-3,-1])+cylinder(4,12,centre=(-36,0,-1))
    body=base+Manifold.cube([28,28,40]).translate([-14,-14,6])+Manifold.cube([8,28,20]).translate([-22,-14,6])
    body-=Manifold.cylinder(32,10,circular_segments=6).translate([0,0,18])+cylinder(5,70,centre=(0,0,-1))
    body-=Manifold.cylinder(80,5,circular_segments=6).rotate([90,0,0]).translate([0,40,36])
    body-=Manifold.cube([3,16,16]).translate([-1.5,-8,6])
    return body

def new_scenes():
    for name,source in [('half','t04-q04'),('stepped','t08-q08'),('rotated','t01-q06'),('combined','t03-q04')]:
        s=Scene('section_'+name,[source]);params={}
        if name=='half':body=half_body()
        elif name=='stepped':body,params=step_body()
        else:body,params=radial_body(name=='combined')
        add_body(s,'body',body)
        if name=='half':
            cut=body ^ slab(-100,100,0);front=area_at_y(body,0)
            side=body.rotate([0,-90,0]).slice(0)
            contours=[[[-float(p[1]),float(p[0])] for p in ring] for ring in side.to_polygons()]
            side_area=CrossSection(contours)
            right=side_area ^ CrossSection([rect(0,-100,100,150)[:-1]])
            left=[]
            for item in model_projection(body)['left']:
                if item['style']=='dashed':continue
                for a,b in zip(item['points'],item['points'][1:]):
                    if a[0]<=0 and b[0]<=0:left.append(path([a,b]))
                    elif (a[0]<0<b[0]) or (b[0]<0<a[0]):
                        hit=lerp(a,b,-a[0]/(b[0]-a[0]));left.append(path([a,hit] if a[0]<0 else [hit,b]))
            s.entity('section_outline',paths={'front':[path(p) for p in rings_paths(front)],'left':left+[path(p) for p in rings_paths(right)]},visible=False)
            s.data['entities']['section_outline']['paths']['front']+=kept_front(cut)
            s.entity('hatching',paths={'front':[path(p,'thin') for p in hatches(front.to_polygons())],'left':[path(p,'thin') for p in hatches(right.to_polygons())]},visible=False)
            s.ink('centre_line','left',[[[0,-52],[0,5]]],'axis',visible=False)
            add_body(s,'cut',cut,visible=False,project_views=False)
            params={'kind':'full_front_half_side','vertical_hex_hole':True,'cross_hex_hole':True,'symmetric_side_view':True}
        else:
            ranges=[(-70,-46,-20),(-46,-5,0),(-5,40,-17)] if name=='stepped' else [(0,21,0),(21,36,-13)]
            cut=Manifold();area=CrossSection()
            for x0,x1,y in ranges:
                cut+=body ^ slab(x0,x1,y);area+=span_area(area_at_y(body,y),x0,x1)
            if name in ['rotated','combined']:
                left=body ^ Manifold.cube([100,140,130]).translate([-100,-70,-30])
                left=left.split_by_plane([-.5,sqrt(3)/2,0],0)[0]
                add_body(s,'rotating_arm',left,visible=False,project_views=False)
                unfolded=left.rotate([0,0,-30]);area+=span_area(area_at_y(unfolded,0),-100,0)
                trace=[[-55*cos(pi/6),-55*sin(pi/6)],[0,0],[21,0],[21,-13],[36,-13]];params['unfold_angle']=-30
                rib=CrossSection([[[-40,-12],[0,-36],[0,-12]]])
                hatch_area=area-rib if name=='combined' else area
            else:trace=[[-68,-20],[-46,-20],[-46,0],[-5,0],[-5,-17],[38,-17]];hatch_area=area
            add_body(s,'cut',cut,visible=False,project_views=False)
            s.ink('section_outline','front',rings_paths(area),visible=False)
            remaining=cut+unfolded if name in ['rotated','combined'] else cut
            transitions=[r[0] for r in ranges[1:]]
            s.data['entities']['section_outline']['paths']['front']+=kept_front(remaining,transitions)
            s.ink('hatching','front',hatches(hatch_area.to_polygons()),'thin',visible=False)
            s.ink('cutting_path','top',[trace],'axis',visible=False)
            planes=[]
            for a,b in zip(trace,trace[1:]):
                if abs(a[0]-b[0])<.001:continue
                planes+=tri_quad([a[0],a[1],0],[b[0],b[1],0],[b[0],b[1],48],[a[0],a[1],48])
            s.entity('cutting_planes',mesh=planes,visible=False,opacity=.2,color='c69762')
        s.data['parameters']=params
        s.data['provenance'].update(note='按原题形状与孔槽关系构造相容模型；未注尺寸为教学尺度，非唯一标准实体',source_answer={'paper':int(source[1:3]),'page':{'half':8,'stepped':10,'rotated':10,'combined':9}[name]},section_rule='真实截面由同一实体求得；移去部分与规定表达分开；折转剖切连接处不作实体棱线')
        yield s
